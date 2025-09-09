unit ProgressLearning;

interface

uses
Dialogs,
  System.SysUtils, System.Classes, System.JSON, System.IOUtils, System.Math,
  System.Generics.Collections, Winapi.Windows, DebugManager, SplashConfig;

const
  MAX_HISTORY_ENTRIES = 10; // Keep last 10 executions
  HISTORY_FILENAME = 'splash_history.json';
  
type
  // Function type for getting real painted bar width
  TGetPaintedBarWidthFunc = function: Single of object;

  TProgressPhase = class
  private
    FName: string;
    FProgress: Integer; // 0-100
    FDurations: TList<Integer>; // Last N durations in milliseconds
    FAverageDuration: Integer;
    FStandardDeviation: Double;
  public
    constructor Create(const AName: string; AProgress: Integer);
    destructor Destroy; override;
    
    procedure AddDuration(ADuration: Integer);
    procedure CalculateStatistics;
    function ToJSON: TJSONObject;
    procedure FromJSON(AJson: TJSONObject);
    procedure SetProgress(AProgress: Integer);
    
    property Name: string read FName;
    property Progress: Integer read FProgress write SetProgress;
    property AverageDuration: Integer read FAverageDuration;
    property StandardDeviation: Double read FStandardDeviation;
  end;

  TProgressHistory = class
  private
    FPhases: TObjectList<TProgressPhase>;
    FCurrentPhaseIndex: Integer;
    FPhaseStartTime: DWORD;
    FSessionDataSaved: Boolean;
    FGetPaintedBarWidth: TGetPaintedBarWidthFunc; // Callback for getting real painted width

    function GetHistoryFilePath: string;
  public
    FTotalDuration: Integer;
    FExecutionCount: Integer;
    FLastExecutionTime: TDateTime;
    FSessionStartTime: DWORD;

    constructor Create;
    destructor Destroy; override;

    procedure StartSession;
    procedure RecordPhaseStart(const APhaseName: string; AProgress: Integer);
    procedure RecordPhaseEnd(ADisplayProgress: Single = -1);
    procedure SetPaintedBarWidthCallback(ACallback: TGetPaintedBarWidthFunc);

    procedure LoadFromFile;
    procedure SaveToFile;

    function GetPhaseByName(const AName: string): TProgressPhase;
    function GetPhaseByProgress(AProgress: Integer): TProgressPhase;
    function EstimateTimeRemaining(ACurrentProgress: Integer): Integer;
    function GetEstimatedPhase(AElapsedTime: Integer): TProgressPhase;
    
    // New methods for automatic percentage calculation
    function CalculateTotalSessionDuration: Integer;
    function CalculatePhasePercentage(const APhaseName: string): Integer;
    function GetPhaseProgressPercentage(const AName: string): Integer;
    procedure RecalculateProgressPercentages;

    property Phases: TObjectList<TProgressPhase> read FPhases;
    property TotalDuration: Integer read FTotalDuration;
    property ExecutionCount: Integer read FExecutionCount;
  end;

  TProgressSimulator = class
  private
    FHistory: TProgressHistory;
    FStartTime: DWORD;
    FLastProgress: Integer;
    FIsLearning: Boolean;

    function InterpolateProgress(AElapsedTime: Integer): Integer;
  public
    constructor Create(AHistory: TProgressHistory);
    
    function GetSimulatedProgress: Integer;
    function GetSimulatedStatus: string;
    function ShouldShowSimulation: Boolean;
    
    procedure StartSimulation;
    procedure StopSimulation;
    
    property IsLearning: Boolean read FIsLearning write FIsLearning;
  end;

implementation

{ TProgressPhase }

constructor TProgressPhase.Create(const AName: string; AProgress: Integer);
begin
  inherited Create;
  FName := AName;
  FProgress := AProgress;
  FDurations := TList<Integer>.Create;
  FAverageDuration := 0;
  FStandardDeviation := 0;
end;

destructor TProgressPhase.Destroy;
begin
  FDurations.Free;
  inherited;
end;

procedure TProgressPhase.AddDuration(ADuration: Integer);
begin
  // Add new duration
  FDurations.Add(ADuration);
  
  // Keep only last MAX_HISTORY_ENTRIES
  while FDurations.Count > MAX_HISTORY_ENTRIES do
    FDurations.Delete(0);
    
  CalculateStatistics;
end;

procedure TProgressPhase.CalculateStatistics;
var
  Sum, SumSquares: Int64;
  I: Integer;
begin
  if FDurations.Count = 0 then
  begin
    FAverageDuration := 0;
    FStandardDeviation := 0;
    Exit;
  end;
  
  // Calculate average
  Sum := 0;
  for I := 0 to FDurations.Count - 1 do
    Sum := Sum + FDurations[I];
  FAverageDuration := Sum div FDurations.Count;
  
  // Calculate standard deviation
  if FDurations.Count > 1 then
  begin
    SumSquares := 0;
    for I := 0 to FDurations.Count - 1 do
      SumSquares := SumSquares + Sqr(FDurations[I] - FAverageDuration);
    FStandardDeviation := Sqrt(SumSquares / (FDurations.Count - 1));
  end
  else
    FStandardDeviation := 0;
end;

function TProgressPhase.ToJSON: TJSONObject;
var
  DurationsArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('name', FName);
    Result.AddPair('progress', TJSONNumber.Create(FProgress));
    Result.AddPair('averageDuration', TJSONNumber.Create(FAverageDuration));
    Result.AddPair('standardDeviation', TJSONNumber.Create(FStandardDeviation));
    
    DurationsArray := TJSONArray.Create;
    for I := 0 to FDurations.Count - 1 do
      DurationsArray.Add(FDurations[I]);
    Result.AddPair('durations', DurationsArray);
  except
    Result.Free;
    raise;
  end;
end;

procedure TProgressPhase.FromJSON(AJson: TJSONObject);
var
  DurationsArray: TJSONArray;
  I: Integer;
begin
  FName := AJson.GetValue<string>('name', '');
  FProgress := AJson.GetValue<Integer>('progress', 0);
  FAverageDuration := AJson.GetValue<Integer>('averageDuration', 0);
  FStandardDeviation := AJson.GetValue<Double>('standardDeviation', 0);
  
  FDurations.Clear;
  if AJson.TryGetValue<TJSONArray>('durations', DurationsArray) then
  begin
    for I := 0 to DurationsArray.Count - 1 do
      FDurations.Add(DurationsArray.Items[I].AsType<Integer>);
  end;
end;

procedure TProgressPhase.SetProgress(AProgress: Integer);
begin
  FProgress := AProgress;
end;

{ TProgressHistory }

constructor TProgressHistory.Create;
begin
  inherited;
  FPhases := TObjectList<TProgressPhase>.Create(True);
  FTotalDuration := 0;
  FExecutionCount := 0;
  FCurrentPhaseIndex := -1;
  FPhaseStartTime := 0;
  FSessionStartTime := 0;
  FSessionDataSaved := False;
  
  DebugLog('TProgressHistory.Create: Constructor called, about to load from file');
  LoadFromFile;
  DebugLogFormat('TProgressHistory.Create: LoadFromFile completed, phases count: %d, executionCount: %d', 
    [FPhases.Count, FExecutionCount]);
end;

destructor TProgressHistory.Destroy;
begin
  DebugLog('TProgressHistory.Destroy: Destroying, saving data');
  SaveToFile;
  FPhases.Free;
  inherited;
end;

function TProgressHistory.GetHistoryFilePath: string;
var
  AppDataPath: string;
  AppDataRoot: string;
begin
  // Use Windows APPDATA environment variable for consistency
  AppDataRoot := GetEnvironmentVariable('APPDATA');
  if AppDataRoot = '' then
    AppDataRoot := TPath.Combine(TPath.GetHomePath, 'AppData', 'Roaming');
    
  AppDataPath := TPath.Combine(AppDataRoot, GetAppIdentifier);
  ForceDirectories(AppDataPath);
  Result := TPath.Combine(AppDataPath, HISTORY_FILENAME);
  DebugLogFormat('GetHistoryFilePath: %s', [Result]);
end;

procedure TProgressHistory.StartSession;
begin
  FSessionStartTime := GetTickCount;
  FCurrentPhaseIndex := -1;
  FPhaseStartTime := FSessionStartTime;
end;

procedure TProgressHistory.RecordPhaseStart(const APhaseName: string; AProgress: Integer);
var
  Phase: TProgressPhase;
begin
  DebugLogFormat('RecordPhaseStart: "%s", Progress=%d, CurrentPhases=%d', 
    [APhaseName, AProgress, FPhases.Count]);

  // End previous phase if any
  if FCurrentPhaseIndex >= 0 then
    RecordPhaseEnd;
  
  // Find or create phase
  Phase := GetPhaseByName(APhaseName);
  if Phase = nil then
  begin
    Phase := TProgressPhase.Create(APhaseName, AProgress);
    FPhases.Add(Phase);
    DebugLogFormat('Created new phase: "%s" (Total phases: %d)', [APhaseName, FPhases.Count]);
  end;
  
  FCurrentPhaseIndex := FPhases.IndexOf(Phase);
  FPhaseStartTime := GetTickCount;
end;

procedure TProgressHistory.RecordPhaseEnd(ADisplayProgress: Single = -1);
var
  Duration: Integer;
  BarWidthText: string;
  RealBarWidth: Single;
begin
  if (FCurrentPhaseIndex >= 0) and (FCurrentPhaseIndex < FPhases.Count) and 
     (FPhaseStartTime > 0) then
  begin
    Duration := GetTickCount - FPhaseStartTime;
    FPhases[FCurrentPhaseIndex].AddDuration(Duration);
    
    // Get real painted bar width from callback if available
    if Assigned(FGetPaintedBarWidth) then
    begin
      RealBarWidth := FGetPaintedBarWidth();
      BarWidthText := Format(', BarWidth=%.1fpx', [RealBarWidth]);
    end
    else
      BarWidthText := '';
    
    DebugLogFormat('RecordPhaseEnd: "%s", Duration=%dms, AvgDuration=%dms%s', 
      [FPhases[FCurrentPhaseIndex].Name, Duration, FPhases[FCurrentPhaseIndex].AverageDuration, BarWidthText]);
    
    // Mark this phase as ended to prevent double recording
    FPhaseStartTime := 0;
    FCurrentPhaseIndex := -1;
  end
  else
  begin
    DebugLog('RecordPhaseEnd: SKIPPED (already ended or invalid state)');
  end;
end;

procedure TProgressHistory.SetPaintedBarWidthCallback(ACallback: TGetPaintedBarWidthFunc);
begin
  FGetPaintedBarWidth := ACallback;
end;

procedure TProgressHistory.LoadFromFile;
var
  FilePath: string;
  JsonText: string;
  JsonRoot: TJSONObject;
  PhasesArray: TJSONArray;
  PhaseJson: TJSONObject;
  Phase: TProgressPhase;
  I: Integer;
begin
  DebugLog('LoadFromFile: Method called');
  
  // Debug: Check for fresh start test mode
  if FileExists(ExtractFilePath(ParamStr(0)) + 'FRESH_START_TEST') then
  begin
    DebugLog('LoadFromFile: FRESH_START_TEST mode - skipping file load');
    Exit;
  end;

  FilePath := GetHistoryFilePath;
  DebugLogFormat('LoadFromFile: History file path: %s', [FilePath]);
  DebugLogFormat('LoadFromFile: File exists: %s', [BoolToStr(TFile.Exists(FilePath), True)]);
  
  if not TFile.Exists(FilePath) then
  begin
    DebugLog('LoadFromFile: File does not exist, exiting');
    Exit;
  end;
    
  try
    JsonText := TFile.ReadAllText(FilePath);
    
    DebugLogFormat('LoadFromFile: JSON text length: %d', [Length(JsonText)]);
    
    JsonRoot := TJSONObject.ParseJSONValue(JsonText) as TJSONObject;
    if JsonRoot = nil then
    begin
      DebugLog('LoadFromFile: JSON parse failed - JsonRoot is nil');
      Exit;
    end;
      
    try
      try
        FTotalDuration := JsonRoot.GetValue<Integer>('totalDuration', 0);
        FExecutionCount := JsonRoot.GetValue<Integer>('executionCount', 0);
        FLastExecutionTime := JsonRoot.GetValue<TDateTime>('lastExecutionTime', Now);
        
        DebugLogFormat('LoadFromFile: Loaded totalDuration=%d, executionCount=%d', 
          [FTotalDuration, FExecutionCount]);
      except
        on E: Exception do
          DebugLogFormat('LoadFromFile: Exception loading values: %s', [E.Message]);
      end;
      
      FPhases.Clear;
      if JsonRoot.TryGetValue<TJSONArray>('phases', PhasesArray) then
      begin
        DebugLogFormat('LoadFromFile: Loading %d phases from JSON', [PhasesArray.Count]);
        
        for I := 0 to PhasesArray.Count - 1 do
        begin
          PhaseJson := PhasesArray.Items[I] as TJSONObject;
          Phase := TProgressPhase.Create('', 0);
          Phase.FromJSON(PhaseJson);
          FPhases.Add(Phase);
          
          DebugLogFormat('Loaded phase: "%s" with %d durations', [Phase.Name, Phase.FDurations.Count]);
        end;
      end
      else
      begin
        DebugLog('LoadFromFile: No phases array found in JSON');
      end;
    finally
      JsonRoot.Free;
    end;
  except
    // Ignore errors loading history
  end;
end;

procedure TProgressHistory.SaveToFile;
var
  FilePath: string;
  JsonRoot: TJSONObject;
  PhasesArray: TJSONArray;
  I: Integer;
begin
  FilePath := GetHistoryFilePath;
  DebugLogFormat('ProgressHistory.SaveToFile called - Path: %s', [FilePath]);

  // Only increment execution count on first save of this session
  if not FSessionDataSaved then
  begin
    Inc(FExecutionCount);
    FSessionDataSaved := True;
    DebugLogFormat('Execution count incremented to: %d (first save)', [FExecutionCount]);
  end
  else
  begin
    DebugLogFormat('Execution count NOT incremented (subsequent save), remains: %d', [FExecutionCount]);
  end;
  
  // Recalculate progress percentages based on timing data before saving
  RecalculateProgressPercentages;

  JsonRoot := TJSONObject.Create;
  try
    JsonRoot.AddPair('totalDuration', TJSONNumber.Create(FTotalDuration));
    JsonRoot.AddPair('executionCount', TJSONNumber.Create(FExecutionCount));
    JsonRoot.AddPair('lastExecutionTime', TJSONString.Create(DateTimeToStr(Now)));

    PhasesArray := TJSONArray.Create;
    for I := 0 to FPhases.Count - 1 do
      PhasesArray.Add(FPhases[I].ToJSON);
    JsonRoot.AddPair('phases', PhasesArray);

    TFile.WriteAllText(FilePath, JsonRoot.ToString);
    
    DebugLogFormat('ProgressHistory.SaveToFile SUCCESS - Saved to: %s', [FilePath]);
    DebugLogFormat('JSON CONTENT: %s', [JsonRoot.ToString]);
 finally
    JsonRoot.Free;
  end;
end;

function TProgressHistory.GetPhaseByName(const AName: string): TProgressPhase;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FPhases.Count - 1 do
  begin
    if SameText(FPhases[I].Name, AName) then
    begin
      Result := FPhases[I];
      Break;
    end;
  end;
end;

function TProgressHistory.GetPhaseByProgress(AProgress: Integer): TProgressPhase;
var
  I: Integer;
  BestPhase: TProgressPhase;
  BestDiff: Integer;
  Diff: Integer;
begin
  BestPhase := nil;
  BestDiff := MaxInt;
  
  for I := 0 to FPhases.Count - 1 do
  begin
    Diff := Abs(FPhases[I].Progress - AProgress);
    if Diff < BestDiff then
    begin
      BestDiff := Diff;
      BestPhase := FPhases[I];
    end;
  end;
  
  Result := BestPhase;
end;

function TProgressHistory.EstimateTimeRemaining(ACurrentProgress: Integer): Integer;
var
  I: Integer;
  RemainingDuration: Integer;
begin
  RemainingDuration := 0;
  
  for I := 0 to FPhases.Count - 1 do
  begin
    if FPhases[I].Progress > ACurrentProgress then
      RemainingDuration := RemainingDuration + FPhases[I].AverageDuration;
  end;
  
  Result := RemainingDuration;
end;

function TProgressHistory.GetEstimatedPhase(AElapsedTime: Integer): TProgressPhase;
var
  I: Integer;
  AccumulatedTime: Integer;
begin
  Result := nil;
  AccumulatedTime := 0;
  
  for I := 0 to FPhases.Count - 1 do
  begin
    AccumulatedTime := AccumulatedTime + FPhases[I].AverageDuration;
    if AccumulatedTime >= AElapsedTime then
    begin
      Result := FPhases[I];
      Break;
    end;
  end;
  
  // Return last phase if elapsed time exceeds all phases
  if (Result = nil) and (FPhases.Count > 0) then
    Result := FPhases[FPhases.Count - 1];
end;

// New automatic percentage calculation methods
function TProgressHistory.CalculateTotalSessionDuration: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FPhases.Count - 1 do
    Result := Result + FPhases[I].AverageDuration;
  
  // Update stored total duration
  FTotalDuration := Result;
end;

function TProgressHistory.CalculatePhasePercentage(const APhaseName: string): Integer;
var
  Phase: TProgressPhase;
  TotalDuration: Integer;
begin
  Result := 0;
  Phase := GetPhaseByName(APhaseName);
  if Phase = nil then
    Exit;
    
  TotalDuration := CalculateTotalSessionDuration;
  if TotalDuration = 0 then
    Exit;
    
  // Calculate percentage based on time ratio
  Result := Round((Phase.AverageDuration / TotalDuration) * 100);
  
  // Ensure reasonable bounds
  if Result < 1 then
    Result := 1;
  if Result > 100 then
    Result := 100;
end;

function TProgressHistory.GetPhaseProgressPercentage(const AName: string): Integer;
var
  I: Integer;
  CumulativePercentage: Integer;
  Phase: TProgressPhase;
  TotalDuration: Integer;
begin
  Result := 0;
  Phase := GetPhaseByName(AName);
  if Phase = nil then
  begin
    DebugLogFormat('GetPhaseProgressPercentage: Phase "%s" not found (Total phases: %d)', 
      [AName, FPhases.Count]);
    Exit;
  end;
    
  TotalDuration := CalculateTotalSessionDuration;
  if TotalDuration = 0 then
  begin
    DebugLogFormat('GetPhaseProgressPercentage: TotalDuration is 0 for phase "%s"', [AName]);
    Exit;
  end;
    
  // Calculate cumulative percentage up to and including this phase
  CumulativePercentage := 0;
  for I := 0 to FPhases.Count - 1 do
  begin
    CumulativePercentage := CumulativePercentage + Round((FPhases[I].AverageDuration / TotalDuration) * 100);
    if FPhases[I] = Phase then
    begin
      Result := CumulativePercentage;
      Break;
    end;
  end;
  
  // Ensure 100% for final phase
  if (Phase = FPhases[FPhases.Count - 1]) and (Result < 100) then
    Result := 100;
end;

procedure TProgressHistory.RecalculateProgressPercentages;
var
  I: Integer;
  CumulativePercentage: Integer;
  TotalDuration: Integer;
  PhasePercentage: Integer;
begin
  TotalDuration := CalculateTotalSessionDuration;
  if TotalDuration = 0 then
    Exit;
    
  // Update each phase with calculated percentage
  CumulativePercentage := 0;
  for I := 0 to FPhases.Count - 1 do
  begin
    PhasePercentage := Round((FPhases[I].AverageDuration / TotalDuration) * 100);
    CumulativePercentage := CumulativePercentage + PhasePercentage;
    
    // For the final phase, ensure it reaches 100%
    if I = FPhases.Count - 1 then
      CumulativePercentage := 100;
      
    FPhases[I].Progress := CumulativePercentage;
  end;
end;

{ TProgressSimulator }

constructor TProgressSimulator.Create(AHistory: TProgressHistory);
begin
  inherited Create;
  FHistory := AHistory;
  FStartTime := 0;
  FLastProgress := 0;
  FIsLearning := False;
end;

procedure TProgressSimulator.StartSimulation;
begin
  FStartTime := GetTickCount;
  FLastProgress := 0;
end;

procedure TProgressSimulator.StopSimulation;
begin
  FStartTime := 0;
end;

function TProgressSimulator.InterpolateProgress(AElapsedTime: Integer): Integer;
var
  Phase: TProgressPhase;
  I: Integer;
  AccumulatedTime: Integer;
  PhaseProgress: Double;
begin
  Result := 0;
  
  if FHistory.Phases.Count = 0 then
  begin
    // No history, use simple linear progress
    Result := Min(100, (AElapsedTime * 100) div 10000); // 10 seconds total
    Exit;
  end;
  
  AccumulatedTime := 0;
  
  for I := 0 to FHistory.Phases.Count - 1 do
  begin
    Phase := FHistory.Phases[I];
    
    if AccumulatedTime + Phase.AverageDuration >= AElapsedTime then
    begin
      // We're in this phase
      if Phase.AverageDuration > 0 then
      begin
        PhaseProgress := (AElapsedTime - AccumulatedTime) / Phase.AverageDuration;
        
        if I > 0 then
          Result := Round(FHistory.Phases[I-1].Progress + 
                         (Phase.Progress - FHistory.Phases[I-1].Progress) * PhaseProgress)
        else
          Result := Round(Phase.Progress * PhaseProgress);
      end
      else
        Result := Phase.Progress;
        
      Break;
    end;
    
    AccumulatedTime := AccumulatedTime + Phase.AverageDuration;
  end;
  
  // Cap at 100
  Result := Min(100, Max(0, Result));
end;

function TProgressSimulator.GetSimulatedProgress: Integer;
var
  ElapsedTime: Integer;
begin
  if FStartTime = 0 then
  begin
    Result := 0;
    Exit;
  end;
  
  ElapsedTime := GetTickCount - FStartTime;
  Result := InterpolateProgress(ElapsedTime);
  
  // Ensure progress never goes backward
  if Result < FLastProgress then
    Result := FLastProgress
  else
    FLastProgress := Result;
end;

function TProgressSimulator.GetSimulatedStatus: string;
var
  Phase: TProgressPhase;
  ElapsedTime: Integer;
begin
  Result := 'Cargando';
  
  if FStartTime = 0 then
    Exit;
    
  ElapsedTime := GetTickCount - FStartTime;
  Phase := FHistory.GetEstimatedPhase(ElapsedTime);
  
  if Phase <> nil then
    Result := Phase.Name;
end;

function TProgressSimulator.ShouldShowSimulation: Boolean;
begin
  // Show simulation if we have enough history data
  Result := (FHistory.ExecutionCount >= 3) and (FHistory.Phases.Count > 0);
end;

end.