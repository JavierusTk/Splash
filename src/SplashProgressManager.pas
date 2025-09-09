unit SplashProgressManager;

interface

uses
  System.SysUtils, System.Math, Winapi.Windows,
  SplashInterfaces, ProgressLearning, AdaptiveLearning, DebugManager, SplashConfig;

type
  TSplashProgressManager = class(TInterfacedObject, ISplashProgressManager)
  private
    // Learning systems
    FProgressHistory: TProgressHistory;
    FStatusMapper: TStatusProgressMapper;
    
    // Current phase tracking
    FCurrentPhase: string;
    FPhaseStartTime: DWORD;
    FPhaseStartProgress: Single;
    FPredictedEndProgress: Single;
    FPredictedDuration: Integer;
    
    // Configuration
    FConfiguration: TSplashConfiguration;
    
    procedure UpdateProgressFromHistory(const AStatus: string);
    procedure UpdateProgressFromAdaptive(const AStatus: string);
    procedure HandleExplicitProgress(AProgress: Integer);
    procedure HandleStatusOnlyProgress(const AStatus: string);
  public
    constructor Create(const AConfiguration: TSplashConfiguration);
    destructor Destroy; override;
    
    // ISplashProgressManager implementation
    procedure Initialize;
    procedure HandleStatusUpdate(const AStatus: string; AProgress: Integer);
    function GetPredictedProgress(const AStatus: string): Single;
    function GetPredictedDuration(const AStatus: string): Integer;
    function GetCurrentPhase: string;
    procedure StartSession;
    procedure EndSession;
    
    // Properties for internal use
    property PredictedEndProgress: Single read FPredictedEndProgress;
    property PredictedDuration: Integer read FPredictedDuration;
  end;

implementation

{ TSplashProgressManager }

constructor TSplashProgressManager.Create(const AConfiguration: TSplashConfiguration);
begin
  inherited Create;
  FConfiguration := AConfiguration;
  Initialize;
end;

destructor TSplashProgressManager.Destroy;
begin
  EndSession;
  FreeAndNil(FStatusMapper);
  FreeAndNil(FProgressHistory);
  inherited;
end;

procedure TSplashProgressManager.Initialize;
begin
  // Initialize progress learning
  FProgressHistory := TProgressHistory.Create;
  
  // Initialize adaptive learning mapper
  FStatusMapper := TStatusProgressMapper.Create;
  FStatusMapper.EnableDebugMode(IsDebugEnabled);
  
  // Initialize phase tracking
  FCurrentPhase := FConfiguration.StartingStatus;
  FPhaseStartTime := GetTickCount;
  FPhaseStartProgress := 0;
  FPredictedEndProgress := 0.1;
  FPredictedDuration := 1000; // Default 1 second
end;

procedure TSplashProgressManager.StartSession;
begin
  if FProgressHistory <> nil then
    FProgressHistory.StartSession;
    
  if FStatusMapper <> nil then
    FStatusMapper.StartSession;
end;

procedure TSplashProgressManager.EndSession;
begin
  // Save learning data
  if FProgressHistory <> nil then
  begin
    DebugLog('Saving ProgressHistory...');
    FProgressHistory.RecordPhaseEnd(FPhaseStartProgress); // End current phase if any
    FProgressHistory.SaveToFile; // Save to disk
  end;
  
  if FStatusMapper <> nil then
  begin
    DebugLog('Ending StatusMapper session...');
    FStatusMapper.EndSession; // This should save adaptive learning data
  end;
end;

procedure TSplashProgressManager.HandleStatusUpdate(const AStatus: string; AProgress: Integer);
var
  ProgressPhase: TProgressPhase;
begin
  // Update current phase
  FCurrentPhase := AStatus;
  FPhaseStartTime := GetTickCount;
  
  DebugLogFormat('HandleStatusUpdate called for "%s", AProgress=%d', [AStatus, AProgress]);
  
  // Use adaptive learning to handle progress mapping for learning purposes
  if AProgress = -1 then
  begin
    // Status-only update, let adaptive learning map it for its own learning
    FStatusMapper.MapStatusToProgress(AStatus, -1);
  end
  else
  begin
    // Explicit progress provided, feed to mapper for learning
    FStatusMapper.MapStatusToProgress(AStatus, AProgress);
  end;
  
  // Record phase in history
  if FProgressHistory <> nil then
    FProgressHistory.RecordPhaseStart(AStatus, AProgress);
  
  // Try to update progress from history first
  UpdateProgressFromHistory(AStatus);
  
  // Check if we got valid data from history
  ProgressPhase := nil;
  if FProgressHistory <> nil then
    ProgressPhase := FProgressHistory.GetPhaseByName(AStatus);
    
  // If no history data, fall back to adaptive learning
  if ProgressPhase = nil then
    UpdateProgressFromAdaptive(AStatus);
  
  // Handle explicit progress value or status-only update
  if AProgress >= 0 then
    HandleExplicitProgress(AProgress)
  else
    HandleStatusOnlyProgress(AStatus);
end;

function TSplashProgressManager.GetPredictedProgress(const AStatus: string): Single;
var
  CalculatedProgress: Integer;
  LearnedNode: AdaptiveLearning.TStatusNode;
begin
  Result := 0.1; // Default
  
  // Try history first
  if FProgressHistory <> nil then
  begin
    CalculatedProgress := FProgressHistory.GetPhaseProgressPercentage(AStatus);
    if CalculatedProgress > 0 then
    begin
      Result := CalculatedProgress / 100.0;
      Exit;
    end;
  end;
  
  // Fall back to adaptive learning
  if (FStatusMapper <> nil) and (FStatusMapper.ProgressGraph <> nil) then
  begin
    LearnedNode := FStatusMapper.ProgressGraph.GetNodeForStatus(AStatus, False);
    if LearnedNode <> nil then
      Result := LearnedNode.TypicalProgress / 100.0;
  end;
end;

function TSplashProgressManager.GetPredictedDuration(const AStatus: string): Integer;
var
  ProgressPhase: TProgressPhase;
begin
  Result := 1000; // Default 1 second
  
  if FProgressHistory <> nil then
  begin
    ProgressPhase := FProgressHistory.GetPhaseByName(AStatus);
    if ProgressPhase <> nil then
      Result := ProgressPhase.AverageDuration;
  end;
end;

function TSplashProgressManager.GetCurrentPhase: string;
begin
  Result := FCurrentPhase;
end;

procedure TSplashProgressManager.UpdateProgressFromHistory(const AStatus: string);
var
  ProgressPhase: TProgressPhase;
  CalculatedProgress: Integer;
begin
  if FProgressHistory = nil then
    Exit;
    
  ProgressPhase := FProgressHistory.GetPhaseByName(AStatus);
  
  if ProgressPhase <> nil then
  begin
    DebugLogFormat('ProgressPhase for "%s": Found', [AStatus]);
    FPredictedDuration := ProgressPhase.AverageDuration;
    
    // Use calculated progress percentage from timing data
    CalculatedProgress := FProgressHistory.GetPhaseProgressPercentage(AStatus);
    if CalculatedProgress > 0 then
    begin
      FPredictedEndProgress := CalculatedProgress / 100.0;
      DebugLogFormat('CALCULATED PROGRESS for "%s": %d%% (%.2f)', 
        [AStatus, CalculatedProgress, FPredictedEndProgress]);
    end;
    
    DebugLogFormat('LEARNED DURATION for "%s": %dms', [AStatus, FPredictedDuration]);
  end
  else
  begin
    DebugLogFormat('ProgressPhase for "%s": Not found', [AStatus]);
    // Will fall back to adaptive learning in caller
  end;
end;

procedure TSplashProgressManager.UpdateProgressFromAdaptive(const AStatus: string);
var
  LearnedNode: AdaptiveLearning.TStatusNode;
begin
  if (FStatusMapper = nil) or (FStatusMapper.ProgressGraph = nil) then
  begin
    FPredictedDuration := 1000; // Default
    Exit;
  end;
  
  LearnedNode := FStatusMapper.ProgressGraph.GetNodeForStatus(AStatus, False);
  if LearnedNode <> nil then
  begin
    FPredictedEndProgress := LearnedNode.TypicalProgress / 100.0;
    FPredictedDuration := 1000; // Default duration
    DebugLogFormat('ADAPTIVE Learning for "%s": %.2f', [AStatus, FPredictedEndProgress]);
  end
  else
  begin
    FPredictedDuration := 1000; // Unknown phase - default values
  end;
end;

procedure TSplashProgressManager.HandleExplicitProgress(AProgress: Integer);
begin
  // Explicit progress provided
  FPredictedEndProgress := AProgress / 100.0;
  
  // Special handling for 100% - make it instant
  if AProgress = 100 then
  begin
    FPredictedDuration := 100; // Override learned duration for instant completion
    FPredictedEndProgress := 1.0;
  end;
  
  DebugLogFormat('EXPLICIT Status: "%s", Progress: %d%% -> Predicted=%.2f, Duration=%dms', 
    [FCurrentPhase, AProgress, FPredictedEndProgress, FPredictedDuration]);
end;

procedure TSplashProgressManager.HandleStatusOnlyProgress(const AStatus: string);
var
  CalculatedProgress: Integer;
  LearnedNode: AdaptiveLearning.TStatusNode;
  NextStatus: string;
  NextNode: AdaptiveLearning.TStatusNode;
  PredictedNext: Integer;
begin
  // PRIORITIZE ProgressHistory over AdaptiveLearning for status-only updates
  if FProgressHistory <> nil then
  begin
    CalculatedProgress := FProgressHistory.GetPhaseProgressPercentage(AStatus);
    if CalculatedProgress > 0 then
    begin
      // Use calculated progress from timing data
      FPredictedEndProgress := CalculatedProgress / 100.0;
      
      // FINAL PHASE HANDLING: If this is 100% or a final status, ensure immediate completion
      if (CalculatedProgress >= 100) or 
         (LowerCase(AStatus) = 'listo') or 
         (LowerCase(AStatus) = 'ready') or 
         (LowerCase(AStatus) = 'complete') then
      begin
        FPredictedEndProgress := 1.0;  // Force 100%
        FPredictedDuration := 200;     // Short duration for final animation
      end;
      
      DebugLogFormat('STATUS-ONLY Progress for "%s": %d%% (%.2f) from timing data', 
        [AStatus, CalculatedProgress, FPredictedEndProgress]);
      Exit;
    end;
  end;
  
  // Fall back to AdaptiveLearning if timing data not available
  if (FStatusMapper <> nil) and (FStatusMapper.ProgressGraph <> nil) then
  begin
    LearnedNode := FStatusMapper.ProgressGraph.GetNodeForStatus(AStatus, False);
    
    if LearnedNode <> nil then
    begin
      // Find next expected phase
      NextStatus := LearnedNode.GetMostLikelyNext;
      if NextStatus <> '' then
      begin
        NextNode := FStatusMapper.ProgressGraph.GetNodeForStatus(NextStatus, False);
        if NextNode <> nil then
          PredictedNext := NextNode.TypicalProgress
        else
          PredictedNext := Min(100, 10);
      end
      else
      begin
        // No next phase known
        PredictedNext := Min(100, 5);
      end;
      
      FPredictedEndProgress := PredictedNext / 100.0;
    end
    else
    begin
      // Unknown phase - conservative progress
      PredictedNext := Min(100, 5);
      FPredictedEndProgress := PredictedNext / 100.0;
    end;
  end
  else
  begin
    // No learning available - basic forward movement
    FPredictedEndProgress := 0.1;
  end;
end;

end.