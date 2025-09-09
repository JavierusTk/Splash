unit AdaptiveLearning;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils, System.Math,
  System.Generics.Collections, Winapi.Windows, System.DateUtils, DebugManager,
  SplashConfig;

const
  LEARNING_VERSION = 2;
  MIN_OBSERVATIONS_FOR_TRUST = 3;
  MIN_OBSERVATIONS_FOR_STABLE = 5;
  MAX_SEQUENCE_HISTORY = 10;
  PROGRESS_JUMP_THRESHOLD = 30; // Consider it a gap if progress jumps more than this
  OUTLIER_STDDEV_THRESHOLD = 2.0;
  DEFAULT_ESTIMATION_DURATION = 10000; // 10 seconds default total duration
  
type
  TProgressValue = record
    Value: Integer;
    Timestamp: TDateTime;
  end;
  
  TStatusTransition = class
  public
    ToStatus: string;
    Count: Integer;
    TotalDuration: Int64;
    
    function GetProbability(TotalTransitions: Integer): Double;
    function GetAverageDuration: Integer;
  end;
  
  TStatusNode = class
  private
    FStatusText: string;
    FObservedProgressValues: TList<TProgressValue>;
    FTransitions: TObjectDictionary<string, TStatusTransition>;
    FTotalDuration: Int64;
    FObservationCount: Integer;
    FFirstSeenIndex: Integer;
    FLastUpdateTime: TDateTime;
    FInCalculation: Boolean; // Recursion guard
    
    function CalculateRawMean: Double;
    function CalculateTypicalProgress: Integer;
    function CalculateVariance: Double;
    function CalculateConfidence: Double;
  public
    constructor Create(const AStatusText: string);
    destructor Destroy; override;
    
    procedure AddObservation(AProgress: Integer; ADuration: Integer);
    procedure AddTransition(const ANextStatus: string; ADuration: Integer);
    function GetMostLikelyNext: string;
    function IsOutlier(AProgress: Integer): Boolean;
    
    function ToJSON: TJSONObject;
    procedure FromJSON(AJson: TJSONObject);
    
    property StatusText: string read FStatusText;
    property TypicalProgress: Integer read CalculateTypicalProgress;
    property Variance: Double read CalculateVariance;
    property Confidence: Double read CalculateConfidence;
    property ObservationCount: Integer read FObservationCount;
    property FirstSeenIndex: Integer read FFirstSeenIndex write FFirstSeenIndex;
    property Transitions: TObjectDictionary<string, TStatusTransition> read FTransitions;
  end;
  
  TSequenceRecord = TList<string>;
  
  TProgressGraph = class
  private
    FNodes: TObjectDictionary<string, TStatusNode>;
    FSequenceHistory: TObjectList<TSequenceRecord>;
    FTotalExecutions: Integer;
    FLastUpdated: TDateTime;
    FCurrentSequence: TSequenceRecord;
    FCurrentIndex: Integer;
    
    function GetLearningFilePath: string;
    function FindPositionInTypicalSequence(const AStatus: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure StartNewSequence;
    procedure EndSequence;
    
    function GetNodeForStatus(const AStatus: string; CreateIfMissing: Boolean = True): TStatusNode;
    function PredictProgress(const AStatus: string; AElapsedTime: Integer): Integer;
    function InterpolateProgress(const APrevStatus, ANextStatus: string; 
                                AElapsedTime: Integer): Integer;
    function IsKnownStatus(const AStatus: string): Boolean;
    function GetConfidenceForStatus(const AStatus: string): Double;
    
    procedure RecordStatusTransition(const AFromStatus, AToStatus: string; 
                                    ADuration: Integer; AProgress: Integer = -1);
    
    procedure LoadFromFile;
    procedure SaveToFile;
    
    property TotalExecutions: Integer read FTotalExecutions;
    property Nodes: TObjectDictionary<string, TStatusNode> read FNodes;
  end;
  
  TStatusProgressMapper = class
  private
    FProgressGraph: TProgressGraph;
    FCurrentStatus: string;
    FPreviousStatus: string;
    FStatusStartTime: DWORD;
    FSessionStartTime: DWORD;
    FIsLearning: Boolean;
    FDebugMode: Boolean;
    
    procedure LogDebug(const AMessage: string);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure StartSession;
    procedure EndSession;
    
    function MapStatusToProgress(const AStatus: string; 
                                AProvidedProgress: Integer = -1): Integer;
    function GetProgressWithConfidence(const AStatus: string; 
                                      out AConfidence: Double): Integer;
    function ShouldShowEstimationIndicator(const AStatus: string): Boolean;
    
    procedure EnableDebugMode(AEnabled: Boolean);
    
    property IsLearning: Boolean read FIsLearning;
    property ProgressGraph: TProgressGraph read FProgressGraph;
  end;

implementation

{ TStatusTransition }

function TStatusTransition.GetProbability(TotalTransitions: Integer): Double;
begin
  if TotalTransitions > 0 then
    Result := Count / TotalTransitions
  else
    Result := 0;
end;

function TStatusTransition.GetAverageDuration: Integer;
begin
  if Count > 0 then
    Result := TotalDuration div Count
  else
    Result := 0;
end;

{ TStatusNode }

constructor TStatusNode.Create(const AStatusText: string);
begin
  inherited Create;
  FStatusText := AStatusText;
  FObservedProgressValues := TList<TProgressValue>.Create;
  FTransitions := TObjectDictionary<string, TStatusTransition>.Create([doOwnsValues]);
  FTotalDuration := 0;
  FObservationCount := 0;
  FFirstSeenIndex := -1;
  FLastUpdateTime := Now;
  FInCalculation := False;
end;

destructor TStatusNode.Destroy;
begin
  FObservedProgressValues.Free;
  FTransitions.Free;
  inherited;
end;

procedure TStatusNode.AddObservation(AProgress: Integer; ADuration: Integer);
var
  ProgressVal: TProgressValue;
begin
  if AProgress >= 0 then
  begin
    ProgressVal.Value := AProgress;
    ProgressVal.Timestamp := Now;
    FObservedProgressValues.Add(ProgressVal);
    
    // Keep only recent observations
    while FObservedProgressValues.Count > 20 do
      FObservedProgressValues.Delete(0);
  end;
  
  Inc(FObservationCount);
  Inc(FTotalDuration, ADuration);
  FLastUpdateTime := Now;
end;

procedure TStatusNode.AddTransition(const ANextStatus: string; ADuration: Integer);
var
  Transition: TStatusTransition;
begin
  if not FTransitions.TryGetValue(ANextStatus, Transition) then
  begin
    Transition := TStatusTransition.Create;
    Transition.ToStatus := ANextStatus;
    Transition.Count := 0;
    Transition.TotalDuration := 0;
    FTransitions.Add(ANextStatus, Transition);
  end;
  
  Inc(Transition.Count);
  Inc(Transition.TotalDuration, ADuration);
end;

function TStatusNode.GetMostLikelyNext: string;
var
  Transition: TStatusTransition;
  BestTransition: TStatusTransition;
  Pair: TPair<string, TStatusTransition>;
begin
  Result := '';
  BestTransition := nil;
  
  for Pair in FTransitions do
  begin
    Transition := Pair.Value;
    if (BestTransition = nil) or (Transition.Count > BestTransition.Count) then
    begin
      BestTransition := Transition;
      Result := Transition.ToStatus;
    end;
  end;
end;

function TStatusNode.CalculateRawMean: Double;
var
  I: Integer;
  Sum: Integer;
begin
  if FObservedProgressValues.Count = 0 then
  begin
    Result := -1;
    Exit;
  end;
  
  Sum := 0;
  for I := 0 to FObservedProgressValues.Count - 1 do
    Inc(Sum, FObservedProgressValues[I].Value);
  
  Result := Sum / FObservedProgressValues.Count;
end;

function TStatusNode.CalculateTypicalProgress: Integer;
var
  I: Integer;
  Sum: Integer;
  ValidCount: Integer;
begin
  // Recursion guard
  if FInCalculation then
  begin
    Result := -1;
    Exit;
  end;
  
  if FObservedProgressValues.Count = 0 then
  begin
    Result := -1;
    Exit;
  end;
  
  FInCalculation := True;
  try
  
  Sum := 0;
  ValidCount := 0;
  
  for I := 0 to FObservedProgressValues.Count - 1 do
  begin
    if not IsOutlier(FObservedProgressValues[I].Value) then
    begin
      Inc(Sum, FObservedProgressValues[I].Value);
      Inc(ValidCount);
    end;
  end;
  
    if ValidCount > 0 then
      Result := Sum div ValidCount
    else if FObservedProgressValues.Count > 0 then
      Result := FObservedProgressValues[FObservedProgressValues.Count - 1].Value
    else
      Result := -1;
  finally
    FInCalculation := False;
  end;
end;

function TStatusNode.CalculateVariance: Double;
var
  I: Integer;
  Mean: Double;
  SumSquares: Double;
begin
  if FObservedProgressValues.Count < 2 then
  begin
    Result := 0;
    Exit;
  end;
  
  Mean := CalculateRawMean;
  SumSquares := 0;
  
  for I := 0 to FObservedProgressValues.Count - 1 do
    SumSquares := SumSquares + Sqr(FObservedProgressValues[I].Value - Mean);
  
  Result := Sqrt(SumSquares / (FObservedProgressValues.Count - 1));
end;

function TStatusNode.CalculateConfidence: Double;
var
  ObservationFactor: Double;
  ConsistencyFactor: Double;
  Variance: Double;
begin
  // Base confidence on number of observations
  ObservationFactor := Min(1.0, FObservationCount / MIN_OBSERVATIONS_FOR_STABLE);
  
  // Adjust for consistency
  Variance := CalculateVariance;
  if Variance < 1 then
    ConsistencyFactor := 1.0
  else
    ConsistencyFactor := Max(0.3, 1.0 - (Variance / 50));
  
  Result := ObservationFactor * ConsistencyFactor;
end;

function TStatusNode.IsOutlier(AProgress: Integer): Boolean;
var
  Mean: Double;
  StdDev: Double;
begin
  if FObservedProgressValues.Count < 3 then
  begin
    Result := False;
    Exit;
  end;
  
  Mean := CalculateRawMean;
  StdDev := CalculateVariance;
  
  Result := Abs(AProgress - Mean) > (OUTLIER_STDDEV_THRESHOLD * StdDev);
end;

function TStatusNode.ToJSON: TJSONObject;
var
  ProgressArray: TJSONArray;
  TransitionsObj: TJSONObject;
  I: Integer;
  Pair: TPair<string, TStatusTransition>;
  TransitionData: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('statusText', FStatusText);
    Result.AddPair('typicalProgress', TJSONNumber.Create(CalculateTypicalProgress));
    Result.AddPair('variance', TJSONNumber.Create(CalculateVariance));
    Result.AddPair('confidence', TJSONNumber.Create(CalculateConfidence));
    Result.AddPair('observationCount', TJSONNumber.Create(FObservationCount));
    Result.AddPair('firstSeenIndex', TJSONNumber.Create(FFirstSeenIndex));
    Result.AddPair('averageDuration', TJSONNumber.Create(FTotalDuration div Max(1, FObservationCount)));
    
    // Save progress values
    ProgressArray := TJSONArray.Create;
    for I := 0 to FObservedProgressValues.Count - 1 do
      ProgressArray.Add(FObservedProgressValues[I].Value);
    Result.AddPair('progressValues', ProgressArray);
    
    // Save transitions
    TransitionsObj := TJSONObject.Create;
    for Pair in FTransitions do
    begin
      TransitionData := TJSONObject.Create;
      TransitionData.AddPair('count', TJSONNumber.Create(Pair.Value.Count));
      TransitionData.AddPair('avgDuration', TJSONNumber.Create(Pair.Value.GetAverageDuration));
      TransitionsObj.AddPair(Pair.Key, TransitionData);
    end;
    Result.AddPair('transitions', TransitionsObj);
  except
    Result.Free;
    raise;
  end;
end;

procedure TStatusNode.FromJSON(AJson: TJSONObject);
var
  ProgressArray: TJSONArray;
  TransitionsObj: TJSONObject;
  TransitionPair: TJSONPair;
  TransitionData: TJSONObject;
  Transition: TStatusTransition;
  ProgressVal: TProgressValue;
  I: Integer;
begin
  FStatusText := AJson.GetValue<string>('statusText', '');
  FObservationCount := AJson.GetValue<Integer>('observationCount', 0);
  FFirstSeenIndex := AJson.GetValue<Integer>('firstSeenIndex', -1);
  
  // Load progress values
  FObservedProgressValues.Clear;
  if AJson.TryGetValue<TJSONArray>('progressValues', ProgressArray) then
  begin
    for I := 0 to ProgressArray.Count - 1 do
    begin
      ProgressVal.Value := ProgressArray.Items[I].AsType<Integer>;
      ProgressVal.Timestamp := Now;
      FObservedProgressValues.Add(ProgressVal);
    end;
  end;
  
  // Load transitions
  FTransitions.Clear;
  if AJson.TryGetValue<TJSONObject>('transitions', TransitionsObj) then
  begin
    for TransitionPair in TransitionsObj do
    begin
      TransitionData := TransitionPair.JsonValue as TJSONObject;
      Transition := TStatusTransition.Create;
      Transition.ToStatus := TransitionPair.JsonString.Value;
      Transition.Count := TransitionData.GetValue<Integer>('count', 0);
      Transition.TotalDuration := TransitionData.GetValue<Integer>('avgDuration', 0) * Transition.Count;
      FTransitions.Add(TransitionPair.JsonString.Value, Transition);
    end;
  end;
end;

{ TProgressGraph }

constructor TProgressGraph.Create;
begin
  inherited;
  FNodes := TObjectDictionary<string, TStatusNode>.Create([doOwnsValues]);
  FSequenceHistory := TObjectList<TSequenceRecord>.Create(True);
  FTotalExecutions := 0;
  FLastUpdated := Now;
  FCurrentSequence := nil;
  FCurrentIndex := 0;
  
  LoadFromFile;
end;

destructor TProgressGraph.Destroy;
begin
  SaveToFile;
  FCurrentSequence.Free;
  FSequenceHistory.Free;
  FNodes.Free;
  inherited;
end;

procedure TProgressGraph.StartNewSequence;
begin
  if FCurrentSequence <> nil then
    EndSequence;
    
  FCurrentSequence := TSequenceRecord.Create;
  FCurrentIndex := 0;
end;

procedure TProgressGraph.EndSequence;
begin
  if FCurrentSequence = nil then
    Exit;
    
  if FCurrentSequence.Count > 0 then
  begin
    FSequenceHistory.Add(FCurrentSequence);
    
    // Keep only recent sequences
    while FSequenceHistory.Count > MAX_SEQUENCE_HISTORY do
      FSequenceHistory.Delete(0);
      
    Inc(FTotalExecutions);
    FLastUpdated := Now;
  end
  else
    FCurrentSequence.Free;
    
  FCurrentSequence := nil;
  SaveToFile;
end;

function TProgressGraph.GetNodeForStatus(const AStatus: string; 
                                        CreateIfMissing: Boolean): TStatusNode;
begin
  if not FNodes.TryGetValue(AStatus, Result) then
  begin
    if CreateIfMissing then
    begin
      Result := TStatusNode.Create(AStatus);
      Result.FirstSeenIndex := FCurrentIndex;
      FNodes.Add(AStatus, Result);
    end
    else
      Result := nil;
  end;
end;

function TProgressGraph.PredictProgress(const AStatus: string; 
                                       AElapsedTime: Integer): Integer;
var
  Node: TStatusNode;
  Position: Integer;
begin
  Node := GetNodeForStatus(AStatus, False);
  
  if (Node <> nil) and (Node.ObservationCount >= MIN_OBSERVATIONS_FOR_TRUST) then
  begin
    // Use learned progress value
    Result := Node.TypicalProgress;
    
    if Result < 0 then // No explicit progress learned
    begin
      // Estimate based on position in typical sequence
      Position := FindPositionInTypicalSequence(AStatus);
      if Position >= 0 then
        Result := (Position * 100) div Max(1, FNodes.Count)
      else
        Result := Min(95, (AElapsedTime * 100) div DEFAULT_ESTIMATION_DURATION);
    end;
  end
  else
  begin
    // Time-based estimation for unknown or new statuses
    Result := Min(95, (AElapsedTime * 100) div DEFAULT_ESTIMATION_DURATION);
  end;
  
  // Ensure progress is within bounds
  Result := Max(0, Min(100, Result));
end;

function TProgressGraph.InterpolateProgress(const APrevStatus, ANextStatus: string;
                                           AElapsedTime: Integer): Integer;
var
  PrevNode, NextNode: TStatusNode;
  PrevProgress, NextProgress: Integer;
  TimeRatio: Double;
begin
  PrevNode := GetNodeForStatus(APrevStatus, False);
  NextNode := GetNodeForStatus(ANextStatus, False);
  
  if (PrevNode <> nil) and (NextNode <> nil) then
  begin
    PrevProgress := PrevNode.TypicalProgress;
    NextProgress := NextNode.TypicalProgress;
    
    if (PrevProgress >= 0) and (NextProgress >= 0) and (NextProgress > PrevProgress) then
    begin
      // Interpolate between known points
      TimeRatio := Min(1.0, AElapsedTime / 1000); // Simple time-based ratio
      Result := PrevProgress + Round((NextProgress - PrevProgress) * TimeRatio);
    end
    else
      Result := PredictProgress(APrevStatus, AElapsedTime);
  end
  else
    Result := PredictProgress(APrevStatus, AElapsedTime);
    
  Result := Max(0, Min(100, Result));
end;

function TProgressGraph.IsKnownStatus(const AStatus: string): Boolean;
var
  Node: TStatusNode;
begin
  Node := GetNodeForStatus(AStatus, False);
  Result := (Node <> nil) and (Node.ObservationCount >= MIN_OBSERVATIONS_FOR_TRUST);
end;

function TProgressGraph.GetConfidenceForStatus(const AStatus: string): Double;
var
  Node: TStatusNode;
begin
  Node := GetNodeForStatus(AStatus, False);
  if Node <> nil then
    Result := Node.Confidence
  else
    Result := 0;
end;

procedure TProgressGraph.RecordStatusTransition(const AFromStatus, AToStatus: string;
                                               ADuration: Integer; AProgress: Integer);
var
  FromNode, ToNode: TStatusNode;
begin
  // Update or create nodes
  if AFromStatus <> '' then
  begin
    FromNode := GetNodeForStatus(AFromStatus, True);
    FromNode.AddTransition(AToStatus, ADuration);
  end;
  
  ToNode := GetNodeForStatus(AToStatus, True);
  ToNode.AddObservation(AProgress, ADuration);
  
  // Update current sequence
  if FCurrentSequence <> nil then
  begin
    if FCurrentSequence.IndexOf(AToStatus) < 0 then
      FCurrentSequence.Add(AToStatus);
    Inc(FCurrentIndex);
  end;
end;

function TProgressGraph.FindPositionInTypicalSequence(const AStatus: string): Integer;
var
  I, J: Integer;
  Sequence: TSequenceRecord;
  TotalPosition: Integer;
  Count: Integer;
begin
  Result := -1;
  TotalPosition := 0;
  Count := 0;
  
  // Average position across recent sequences
  for I := FSequenceHistory.Count - 1 downto Max(0, FSequenceHistory.Count - 5) do
  begin
    Sequence := FSequenceHistory[I];
    J := Sequence.IndexOf(AStatus);
    if J >= 0 then
    begin
      Inc(TotalPosition, J);
      Inc(Count);
    end;
  end;
  
  if Count > 0 then
    Result := TotalPosition div Count;
end;

function TProgressGraph.GetLearningFilePath: string;
var
  AppDataPath: string;
begin
  AppDataPath := TPath.Combine(TPath.GetHomePath, GetAppIdentifier);
  ForceDirectories(AppDataPath);
  Result := TPath.Combine(AppDataPath, 'splash_learning.json');
end;

procedure TProgressGraph.LoadFromFile;
var
  FilePath: string;
  JsonText: string;
  JsonRoot: TJSONObject;
  NodesObj: TJSONObject;
  NodePair: TJSONPair;
  NodeData: TJSONObject;
  Node: TStatusNode;
  SequencesArray: TJSONArray;
  SequenceArray: TJSONArray;
  Sequence: TSequenceRecord;
  I, J: Integer;
begin
  FilePath := GetLearningFilePath;
  if not TFile.Exists(FilePath) then
    Exit;
    
  try
    JsonText := TFile.ReadAllText(FilePath);
    JsonRoot := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
    if JsonRoot = nil then
      Exit;
      
    try
      // Check version
      if JsonRoot.GetValue<Integer>('version', 1) < LEARNING_VERSION then
      begin
        // Old version, start fresh
        Exit;
      end;
      
      FTotalExecutions := JsonRoot.GetValue<Integer>('totalExecutions', 0);
      FLastUpdated := StrToDateTimeDef(JsonRoot.GetValue<string>('lastUpdated', ''), Now);
      
      // Load nodes
      FNodes.Clear;
      if JsonRoot.TryGetValue<TJSONObject>('statusNodes', NodesObj) then
      begin
        for NodePair in NodesObj do
        begin
          NodeData := NodePair.JsonValue as TJSONObject;
          Node := TStatusNode.Create('');
          Node.FromJSON(NodeData);
          FNodes.Add(NodePair.JsonString.Value, Node);
        end;
      end;
      
      // Load sequence history
      FSequenceHistory.Clear;
      if JsonRoot.TryGetValue<TJSONArray>('sequences', SequencesArray) then
      begin
        for I := 0 to Min(SequencesArray.Count - 1, MAX_SEQUENCE_HISTORY - 1) do
        begin
          SequenceArray := SequencesArray.Items[I] as TJSONArray;
          Sequence := TSequenceRecord.Create;
          for J := 0 to SequenceArray.Count - 1 do
            Sequence.Add(SequenceArray.Items[J].AsType<string>);
          FSequenceHistory.Add(Sequence);
        end;
      end;
    finally
      JsonRoot.Free;
    end;
  except
    // Ignore errors loading history
  end;
end;

procedure TProgressGraph.SaveToFile;
var
  FilePath: string;
  JsonRoot: TJSONObject;
  NodesObj: TJSONObject;
  SequencesArray: TJSONArray;
  SequenceArray: TJSONArray;
  Pair: TPair<string, TStatusNode>;
  Sequence: TSequenceRecord;
  I: Integer;
  Status: string;
begin
  FilePath := GetLearningFilePath;
  DebugLogFormat('AdaptiveLearning.SaveToFile called - Path: %s', [FilePath]);
  
  JsonRoot := TJSONObject.Create;
  try
    JsonRoot.AddPair('version', TJSONNumber.Create(LEARNING_VERSION));
    JsonRoot.AddPair('totalExecutions', TJSONNumber.Create(FTotalExecutions));
    JsonRoot.AddPair('lastUpdated', TJSONString.Create(DateTimeToStr(Now)));
    
    // Save nodes
    NodesObj := TJSONObject.Create;
    for Pair in FNodes do
      NodesObj.AddPair(Pair.Key, Pair.Value.ToJSON);
    JsonRoot.AddPair('statusNodes', NodesObj);
    
    // Save sequence history
    SequencesArray := TJSONArray.Create;
    for I := 0 to FSequenceHistory.Count - 1 do
    begin
      Sequence := FSequenceHistory[I];
      SequenceArray := TJSONArray.Create;
      for Status in Sequence do
        SequenceArray.Add(Status);
      SequencesArray.Add(SequenceArray);
    end;
    JsonRoot.AddPair('sequences', SequencesArray);
    
    TFile.WriteAllText(FilePath, JsonRoot.ToString);
    DebugLogFormat('AdaptiveLearning.SaveToFile SUCCESS - Saved to: %s', [FilePath]);
  finally
    JsonRoot.Free;
  end;
end;

{ TStatusProgressMapper }

constructor TStatusProgressMapper.Create;
begin
  inherited;
  FProgressGraph := TProgressGraph.Create;
  FCurrentStatus := '';
  FPreviousStatus := '';
  FStatusStartTime := 0;
  FSessionStartTime := 0;
  FIsLearning := False;
  FDebugMode := False;
end;

destructor TStatusProgressMapper.Destroy;
begin
  EndSession;
  FProgressGraph.Free;
  inherited;
end;

procedure TStatusProgressMapper.StartSession;
begin
  FSessionStartTime := GetTickCount;
  FStatusStartTime := FSessionStartTime;
  FCurrentStatus := '';
  FPreviousStatus := '';
  FIsLearning := FProgressGraph.TotalExecutions < MIN_OBSERVATIONS_FOR_TRUST;
  FProgressGraph.StartNewSequence;
  
  LogDebug('Session started. Learning mode: ' + BoolToStr(FIsLearning, True));
end;

procedure TStatusProgressMapper.EndSession;
begin
  if FSessionStartTime > 0 then
  begin
    FProgressGraph.EndSequence;
    FSessionStartTime := 0;
    LogDebug('Session ended. Total executions: ' + IntToStr(FProgressGraph.TotalExecutions));
  end;
end;

function TStatusProgressMapper.MapStatusToProgress(const AStatus: string;
                                                  AProvidedProgress: Integer): Integer;
var
  Duration: Integer;
  ElapsedTime: Integer;
  Node: TStatusNode;
  Confidence: Double;
begin
  if FSessionStartTime = 0 then
    StartSession;
    
  Duration := 0;
  if FStatusStartTime > 0 then
    Duration := GetTickCount - FStatusStartTime;
    
  ElapsedTime := GetTickCount - FSessionStartTime;
  
  // Record transition
  FProgressGraph.RecordStatusTransition(FPreviousStatus, AStatus, Duration, AProvidedProgress);
  
  // Determine progress
  if AProvidedProgress >= 0 then
  begin
    // Explicit progress provided
    Result := AProvidedProgress;
    LogDebug(Format('Status "%s" with explicit progress: %d%%', [AStatus, Result]));
  end
  else
  begin
    // Need to predict/estimate progress
    Node := FProgressGraph.GetNodeForStatus(AStatus, False);
    
    if (Node <> nil) and (Node.ObservationCount >= MIN_OBSERVATIONS_FOR_TRUST) then
    begin
      // Use learned value
      Result := Node.TypicalProgress;
      Confidence := Node.Confidence;
      LogDebug(Format('Status "%s" using learned progress: %d%% (confidence: %.2f)', 
                     [AStatus, Result, Confidence]));
    end
    else if (FPreviousStatus <> '') and 
            (Abs(FProgressGraph.PredictProgress(FPreviousStatus, 0) - 
                 FProgressGraph.PredictProgress(AStatus, 0)) > PROGRESS_JUMP_THRESHOLD) then
    begin
      // Large gap detected, interpolate
      Result := FProgressGraph.InterpolateProgress(FPreviousStatus, AStatus, Duration);
      LogDebug(Format('Status "%s" interpolated progress: %d%% (gap detected)', [AStatus, Result]));
    end
    else
    begin
      // Time-based estimation
      Result := FProgressGraph.PredictProgress(AStatus, ElapsedTime);
      LogDebug(Format('Status "%s" estimated progress: %d%% (time-based)', [AStatus, Result]));
    end;
  end;
  
  // Update state
  FPreviousStatus := FCurrentStatus;
  FCurrentStatus := AStatus;
  FStatusStartTime := GetTickCount;
  
  Result := Max(0, Min(100, Result));
end;

function TStatusProgressMapper.GetProgressWithConfidence(const AStatus: string;
                                                        out AConfidence: Double): Integer;
begin
  Result := MapStatusToProgress(AStatus, -1);
  AConfidence := FProgressGraph.GetConfidenceForStatus(AStatus);
end;

function TStatusProgressMapper.ShouldShowEstimationIndicator(const AStatus: string): Boolean;
var
  Confidence: Double;
begin
  Confidence := FProgressGraph.GetConfidenceForStatus(AStatus);
  Result := (Confidence < 0.8) or FIsLearning;
end;

procedure TStatusProgressMapper.EnableDebugMode(AEnabled: Boolean);
begin
  FDebugMode := AEnabled;
end;

procedure TStatusProgressMapper.LogDebug(const AMessage: string);
begin
  if FDebugMode then
    DebugLog(AMessage);
end;

end.