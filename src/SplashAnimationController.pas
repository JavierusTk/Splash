unit SplashAnimationController;

interface

uses
  System.SysUtils, System.Math, Winapi.Windows, Vcl.ExtCtrls,
  SplashInterfaces, DebugManager;

type
  TAnimationConstants = record
    const
      PROGRESS_THRESHOLD = 0.01;
      DEFAULT_DURATION = 1000;
      JUMP_THRESHOLD = 0.95;
      NEAR_COMPLETE = 0.98;
      CREEP_SPEED = 0.02;
      PRIMARY_TARGET_TIME = 0.75;
      MIN_PROGRESS_INCREMENT = 0.01;
      DEFAULT_FORWARD_GAP = 0.05;
      MIN_REMAINING_TIME = 0.1;
      BOOST_TIME_THRESHOLD = 0.2;
      BOOST_GAP_THRESHOLD = 0.2;
      BOOST_MULTIPLIER = 2.0;
      MAX_OVERRUN_PERCENT = 0.05;
      OVERRUN_BORROW_RATIO = 0.3;
      DEFAULT_ANIMATION_TIME = 0.6;
  end;

  TSplashAnimationController = class(TInterfacedObject, ISplashAnimationController)
  private
    // Smooth progress animation
    FDisplayProgress: Single;       // Currently displayed progress (0.0-1.0)
    FMinimumProgress: Single;       // Minimum allowed progress (ratchet)
    FTargetProgress: Single;        // Where we want to be
    FProgressSpeed: Single;         // Current animation speed
    FLastProgressUpdateTime: DWORD; // For delta time calculation
    FProgressAnimTimer: TTimer;     // Smooth animation timer
    
    // Phase prediction
    FCurrentPhase: string;          // Current status/phase
    FPhaseStartTime: DWORD;         // When phase started
    FPhaseStartProgress: Single;    // Progress when phase started
    FPredictedEndProgress: Single;  // Where we expect to be at phase end
    FPredictedDuration: Integer;    // Expected phase duration from learning
    
    // Two-stage animation state
    FHasReachedTarget: Boolean;     // Whether primary target has been reached
    FCreepSpeed: Single;            // Speed for secondary creep animation
    FPrimaryTargetTime: Single;     // Time when primary target should be reached (75% of phase)
    
    procedure ProgressAnimTimerTimer(Sender: TObject);
    function CalculateAnimationSpeed(ElapsedInPhase: DWORD): Single;
    procedure UpdateDisplayProgressInternal(DeltaTime: Single);
  public
    constructor Create;
    destructor Destroy; override;
    
    // ISplashAnimationController implementation
    procedure Initialize;
    procedure UpdateAnimation(ADeltaTime: Single);
    procedure SetTarget(AProgress: Single; ADuration: Integer);
    procedure SetPhase(const APhaseName: string; AStartProgress, AEndProgress: Single; ADuration: Integer);
    function GetDisplayProgress: Single;
    function GetAnimationSpeed: Single;
    function GetMinimumProgress: Single;
    procedure ResetPhaseAnimation;
  end;

implementation

{ TSplashAnimationController }

constructor TSplashAnimationController.Create;
begin
  inherited Create;
  Initialize;
end;

destructor TSplashAnimationController.Destroy;
begin
  FreeAndNil(FProgressAnimTimer);
  inherited;
end;

procedure TSplashAnimationController.Initialize;
begin
  // Initialize smooth progress animation
  FDisplayProgress := 0;
  FMinimumProgress := 0;
  FTargetProgress := 0;
  FProgressSpeed := 0;
  FLastProgressUpdateTime := GetTickCount;
  FPhaseStartTime := GetTickCount;
  FPhaseStartProgress := 0;
  FPredictedEndProgress := 0.1; // Start with some target to move towards
  FPredictedDuration := TAnimationConstants.DEFAULT_DURATION; // Default 1 second duration
  
  // Initialize two-stage animation state
  FHasReachedTarget := False;
  FCreepSpeed := TAnimationConstants.CREEP_SPEED; // 2% per second creep speed
  FPrimaryTargetTime := TAnimationConstants.PRIMARY_TARGET_TIME; // Reach target in 75% of phase time
  
  // Create progress animation timer (60 FPS)
  if FProgressAnimTimer = nil then
  begin
    FProgressAnimTimer := TTimer.Create(nil);
    FProgressAnimTimer.Interval := 16; // ~60 FPS
    FProgressAnimTimer.OnTimer := ProgressAnimTimerTimer;
    FProgressAnimTimer.Enabled := True;
  end;
end;

procedure TSplashAnimationController.UpdateAnimation(ADeltaTime: Single);
begin
  UpdateDisplayProgressInternal(ADeltaTime);
end;

procedure TSplashAnimationController.SetTarget(AProgress: Single; ADuration: Integer);
begin
  FTargetProgress := AProgress;
  
  // CRITICAL: Never allow backward progress
  if FTargetProgress < FMinimumProgress then
  begin
    // Target is behind us - ignore it and keep crawling forward
    FTargetProgress := FMinimumProgress + TAnimationConstants.MIN_PROGRESS_INCREMENT;
    FProgressSpeed := 0.0001; // Minimal speed
  end;
  
  // Set predicted end to match explicit progress
  FPredictedEndProgress := FTargetProgress;
  FPredictedDuration := ADuration;
  
  // Special handling for 100% - make it instant
  if AProgress >= 1.0 then
  begin
    FPredictedDuration := 100; // Override learned duration for instant completion
    // Jump immediately to near 100%
    if FDisplayProgress < TAnimationConstants.JUMP_THRESHOLD then
      FDisplayProgress := TAnimationConstants.JUMP_THRESHOLD;
  end;
end;

procedure TSplashAnimationController.SetPhase(const APhaseName: string; 
  AStartProgress, AEndProgress: Single; ADuration: Integer);
begin
  FCurrentPhase := APhaseName;
  FPhaseStartTime := GetTickCount;
  FPhaseStartProgress := FDisplayProgress;
  FPredictedEndProgress := AEndProgress;
  FPredictedDuration := ADuration;
  FHasReachedTarget := False; // Reset for new phase
  
  // Ensure we don't go backward
  if FPredictedEndProgress < FMinimumProgress then
    FPredictedEndProgress := FMinimumProgress + TAnimationConstants.MIN_PROGRESS_INCREMENT;
end;

function TSplashAnimationController.GetDisplayProgress: Single;
begin
  Result := FDisplayProgress;
end;

function TSplashAnimationController.GetAnimationSpeed: Single;
begin
  Result := FProgressSpeed;
end;

function TSplashAnimationController.GetMinimumProgress: Single;
begin
  Result := FMinimumProgress;
end;

procedure TSplashAnimationController.ResetPhaseAnimation;
begin
  // Reset phase timing and animation state
  FPhaseStartTime := GetTickCount;
  FPhaseStartProgress := FDisplayProgress;
  FHasReachedTarget := False; // Reset for new phase
end;

procedure TSplashAnimationController.ProgressAnimTimerTimer(Sender: TObject);
var
  DeltaTime: Single;
  ElapsedInPhase: DWORD;
begin
  // Calculate delta time since last update
  DeltaTime := (GetTickCount - FLastProgressUpdateTime) / 1000.0; // Seconds
  FLastProgressUpdateTime := GetTickCount;
  
  // Calculate elapsed time in current phase
  ElapsedInPhase := GetTickCount - FPhaseStartTime;
  
  // Calculate appropriate animation speed
  FProgressSpeed := CalculateAnimationSpeed(ElapsedInPhase);
  
  // Update the display progress
  UpdateDisplayProgressInternal(DeltaTime);
end;

function TSplashAnimationController.CalculateAnimationSpeed(ElapsedInPhase: DWORD): Single;
var
  PhaseElapsedSec: Single;
  PredictedDurationSec: Single;
  PrimaryTargetTimeLimit: Single;
  TargetGap: Single;
  HasReachedTarget: Boolean;
  RemainingTime: Single;
  MaxOverrun: Single;
  CurrentOverrun: Single;
  DefaultAnimationTime: Single;
  ForwardGap: Single;
begin
  if FPredictedDuration > 0 then
  begin
    // Calculate where we should be based on learned timing
    PhaseElapsedSec := ElapsedInPhase / 1000.0;
    PredictedDurationSec := FPredictedDuration / 1000.0;
    PrimaryTargetTimeLimit := PredictedDurationSec * FPrimaryTargetTime; // 75% of phase time
    
    // Check if we've reached the target progress
    TargetGap := FPredictedEndProgress - FDisplayProgress;
    HasReachedTarget := (TargetGap <= TAnimationConstants.PROGRESS_THRESHOLD); // Within 1% of target
    
    if not FHasReachedTarget and not HasReachedTarget then
    begin
      // STAGE 1: Primary Animation - Fast progress to target
      RemainingTime := Max(TAnimationConstants.MIN_REMAINING_TIME, PrimaryTargetTimeLimit - PhaseElapsedSec);
      Result := Max(TargetGap / RemainingTime, TAnimationConstants.MIN_REMAINING_TIME); // Ensure minimum progress
      
      // BOOST: If we're running out of time or significantly behind, speed up
      if (RemainingTime < TAnimationConstants.BOOST_TIME_THRESHOLD) or 
         (TargetGap > TAnimationConstants.BOOST_GAP_THRESHOLD) then
        Result := Result * TAnimationConstants.BOOST_MULTIPLIER; // Double speed when urgent
    end
    else if not FHasReachedTarget and HasReachedTarget then
    begin
      // TRANSITION: Just reached target - switch to creep mode
      FHasReachedTarget := True;
      Result := FCreepSpeed; // Start gentle creep
    end
    else if FHasReachedTarget then
    begin
      // STAGE 2: Creep Animation - Slow progress beyond target
      // Calculate how much we can "borrow" from next phase (up to 5% overrun)
      MaxOverrun := Min(TAnimationConstants.MAX_OVERRUN_PERCENT, 
                        (1.0 - FPredictedEndProgress) * TAnimationConstants.OVERRUN_BORROW_RATIO);
      CurrentOverrun := FDisplayProgress - FPredictedEndProgress;
      
      if CurrentOverrun < MaxOverrun then
        Result := FCreepSpeed * (1.0 - CurrentOverrun / MaxOverrun) // Slow down as we approach max overrun
      else
        Result := TAnimationConstants.MIN_PROGRESS_INCREMENT; // Very minimal movement when at max overrun
    end
    else
    begin
      // Fallback: shouldn't happen, but ensure some progress
      Result := TAnimationConstants.DEFAULT_FORWARD_GAP;
    end;
  end
  else
  begin
    // No prediction available - use default phase duration for speed calculation
    DefaultAnimationTime := TAnimationConstants.DEFAULT_ANIMATION_TIME;
    ForwardGap := TAnimationConstants.DEFAULT_FORWARD_GAP; // Move forward 5% when no target
    Result := ForwardGap / DefaultAnimationTime; // Smooth forward progress
  end;
  
  // Apply maximum speed limit to allow instant jumps if needed
  Result := Min(Result, 1.0); // Allow up to 100% jump per frame for instant updates
end;

procedure TSplashAnimationController.UpdateDisplayProgressInternal(DeltaTime: Single);
var
  OldProgress: Single;
begin
  OldProgress := FDisplayProgress;
  
  // Update display progress (never backward)
  FDisplayProgress := Max(FMinimumProgress, Min(1.0, FDisplayProgress + FProgressSpeed * DeltaTime));
  
  // Update ratchet to prevent backward movement
  FMinimumProgress := FDisplayProgress;
  
  // Log significant changes
  if Abs(OldProgress - FDisplayProgress) > 0.0001 then
  begin
    // Log every second to avoid spam (this would be controlled by caller in real implementation)
    DebugLogFormat('Animation: Display=%.2f (%.0f%%), Target=%.2f, Speed=%.4f, Duration=%dms', 
      [FDisplayProgress, FDisplayProgress * 100, FPredictedEndProgress, FProgressSpeed, FPredictedDuration]);
  end;
end;

end.