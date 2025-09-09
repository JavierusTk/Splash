unit ModernSplash;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.UITypes,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics,
  System.Skia, Vcl.Skia, Winapi.Windows,
  SplashConfig, SplashInterfaces;

type
  TfrmModernSplash = class(TForm)
    SkAnimatedPaintBox: TSkAnimatedPaintBox;
    AnimationTimer: TTimer;
    MainTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SkAnimatedPaintBoxAnimationDraw(ASender: TObject; 
      const ACanvas: ISkCanvas; const ADest: TRectF; 
      const AProgress: Double; const AOpacity: Single);
    procedure AnimationTimerTimer(Sender: TObject);
    procedure MainTimerTimer(Sender: TObject);
  private
    // Configuration
    FConfiguration: TSplashConfiguration;
    
    // Managers
    FRenderingManager: ISplashRenderingManager;
    FLifecycleManager: ISplashLifecycleManager;
    FIPCManager: ISplashIPCManager;
    FProgressManager: ISplashProgressManager;
    FAnimationController: ISplashAnimationController;
    FSimulationManager: ISplashSimulationManager;
    
    // State
    FAnimationTime: Single;
    FCurrentProgress: Single;
    FCurrentStatus: string;
    FLastIPCUpdate: DWORD;
    
    // Helper methods
    procedure CreateManagers;
    procedure DestroyManagers;
    procedure HandleIPCUpdate;
    procedure UpdateDisplayState(AProgress: Single; const AStatus: string);
  public
    procedure InitializeWithConfiguration(const AConfig: TSplashConfiguration);
    procedure StartIPCMonitoring(AParentPID: DWORD);
    procedure SetBeta(AIsBeta: Boolean);
  end;

var
  frmModernSplash: TfrmModernSplash;

implementation

{$R *.dfm}

uses
  SplashRenderingManager, SplashLifecycleManager, SplashIPCManager,
  SplashAnimationController, SplashProgressManager, SplashSimulationManager,
  DebugManager;

const
  MAIN_TIMER_INTERVAL = 50;    // 50ms for main coordination
  ANIMATION_TIMER_INTERVAL = 16; // ~60 FPS for animation

{ TfrmModernSplash }

procedure TfrmModernSplash.FormCreate(Sender: TObject);
begin
  // Initialize default configuration
  FConfiguration := TSplashConfiguration.CreateDefault;
  
  // Initialize state
  FAnimationTime := 0;
  FCurrentProgress := 0;
  FCurrentStatus := FConfiguration.StartingStatus;
  FLastIPCUpdate := GetTickCount;
  
  // Create all managers
  CreateManagers;
  
  // Setup timers
  MainTimer.Interval := MAIN_TIMER_INTERVAL;
  MainTimer.Enabled := True;
  
  AnimationTimer.Interval := ANIMATION_TIMER_INTERVAL;
  AnimationTimer.Enabled := True;
  
  // Enable double buffering
  DoubleBuffered := True;
  
  // Start animation
  SkAnimatedPaintBox.Animation.Enabled := True;
  SkAnimatedPaintBox.Animation.Duration := 10000;
  
  DebugLog('ModernSplash form created and initialized');
end;

procedure TfrmModernSplash.FormDestroy(Sender: TObject);
begin
  DebugLog('ModernSplash form destroying');
  
  // Stop timers
  MainTimer.Enabled := False;
  AnimationTimer.Enabled := False;
  
  // Clean up managers
  DestroyManagers;
  
  DebugLog('ModernSplash form destroyed');
end;

procedure TfrmModernSplash.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  DebugLog('ModernSplash form closing');
  
  // Save any learning data through progress manager
  if FProgressManager <> nil then
    FProgressManager.EndSession;
  
  Action := caFree;
end;

procedure TfrmModernSplash.CreateManagers;
begin
  // Create rendering manager
  FRenderingManager := TSplashRenderingManager.Create;
  FRenderingManager.Initialize(FConfiguration);
  
  // Create lifecycle manager
  FLifecycleManager := TSplashLifecycleManager.Create;
  
  // Create IPC manager
  FIPCManager := TSplashIPCManager.Create;
  
  // Create animation controller
  FAnimationController := TSplashAnimationController.Create;
  FAnimationController.Initialize;
  
  // Create progress manager
  FProgressManager := TSplashProgressManager.Create(FConfiguration);
  FProgressManager.StartSession;
  
  // Create simulation manager
  FSimulationManager := TSplashSimulationManager.Create(nil); // Will need proper history
  
  DebugLog('All managers created successfully');
end;

procedure TfrmModernSplash.DestroyManagers;
begin
  // Interfaces will be automatically released
  FRenderingManager := nil;
  FLifecycleManager := nil;
  FIPCManager := nil;
  FAnimationController := nil;
  FProgressManager := nil;
  FSimulationManager := nil;
  
  DebugLog('All managers destroyed');
end;

procedure TfrmModernSplash.InitializeWithConfiguration(const AConfig: TSplashConfiguration);
var
  AppName: string;
begin
  FConfiguration := AConfig;
  
  // Update rendering manager with new configuration
  if FRenderingManager <> nil then
  begin
    FRenderingManager.Initialize(AConfig);
    FRenderingManager.SetBeta(AConfig.IsBeta);
  end;
  
  // Update form caption
  if AConfig.AppName <> '' then
    AppName := AConfig.AppName
  else
    AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
    
  FConfiguration.AppName := AppName;
  Caption := AppName + ' ' + AConfig.Version + AConfig.SubVersion;
  
  // Update initial status
  FCurrentStatus := AConfig.StartingStatus;
  
  DebugLogFormat('Splash initialized with config - App: "%s", Version: "%s%s"',
    [AppName, AConfig.Version, AConfig.SubVersion]);
end;

procedure TfrmModernSplash.StartIPCMonitoring(AParentPID: DWORD);
begin
  try
    // Initialize lifecycle manager with parent PID
    if FLifecycleManager <> nil then
      FLifecycleManager.Initialize(AParentPID);
    
    // Start IPC monitoring - allow failure in debug mode
    if FIPCManager <> nil then
    begin
      try
        FIPCManager.StartMonitoring(AParentPID);
        DebugLogFormat('IPC monitoring started for parent PID: %d', [AParentPID]);
      except
        on E: Exception do
        begin
          DebugLogFormat('WARNING: IPC monitoring failed: %s (continuing in standalone mode)', [E.Message]);
          // In debug mode, continue without IPC
          if not IsDebugEnabled then
          begin
            Close; // Close splash if IPC fails in production
            Exit;
          end;
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      DebugLogFormat('Failed to initialize monitoring: %s', [E.Message]);
      if not IsDebugEnabled then
        Close; // Close splash if initialization fails in production
    end;
  end;
end;

procedure TfrmModernSplash.SetBeta(AIsBeta: Boolean);
begin
  FConfiguration.IsBeta := AIsBeta;
  
  if FRenderingManager <> nil then
    FRenderingManager.SetBeta(AIsBeta);
    
  // Request redraw
  SkAnimatedPaintBox.Redraw;
end;

procedure TfrmModernSplash.SkAnimatedPaintBoxAnimationDraw(ASender: TObject; 
  const ACanvas: ISkCanvas; const ADest: TRectF; 
  const AProgress: Double; const AOpacity: Single);
var
  DisplayProgress: Single;
begin
  // Get animated progress value
  if FAnimationController <> nil then
    DisplayProgress := FAnimationController.DisplayProgress
  else
    DisplayProgress := FCurrentProgress;
  
  // Delegate all rendering to the rendering manager
  if FRenderingManager <> nil then
    FRenderingManager.RenderFrame(ACanvas, ADest, DisplayProgress, 
      FCurrentStatus, FAnimationTime);
end;

procedure TfrmModernSplash.AnimationTimerTimer(Sender: TObject);
begin
  // Update animation time (increment by actual time elapsed in seconds)
  // Timer fires every 16ms, so increment by 0.016 seconds
  FAnimationTime := FAnimationTime + (ANIMATION_TIMER_INTERVAL / 1000.0);
  
  // Update animation controller
  if FAnimationController <> nil then
    FAnimationController.UpdateAnimation(ANIMATION_TIMER_INTERVAL / 1000.0);
end;

procedure TfrmModernSplash.MainTimerTimer(Sender: TObject);
begin
  // Check lifecycle status
  if FLifecycleManager <> nil then
  begin
    if FLifecycleManager.ShouldClose then
    begin
      DebugLog('Lifecycle manager requested close');
      MainTimer.Enabled := False;
      Close;
      Exit;
    end;
  end;
  
  // Handle IPC updates
  HandleIPCUpdate;
end;

procedure TfrmModernSplash.HandleIPCUpdate;
var
  LProgress: Integer;
  LStatus: string;
  PredictedProgress: Single;
  PredictedDuration: Integer;
begin
  if FIPCManager = nil then Exit;
  
  // Check for IPC updates
  if FIPCManager.CheckForUpdate(LProgress, LStatus) then
  begin
    // We have a new update from parent process
    FLastIPCUpdate := GetTickCount;
    
    // Initialize with default or explicit progress
    if LProgress >= 0 then
      PredictedProgress := LProgress / 100.0
    else
      PredictedProgress := 0;
    
    // Update progress manager
    if FProgressManager <> nil then
    begin
      FProgressManager.HandleStatusUpdate(LStatus, LProgress);
      
      // Get predictions
      PredictedProgress := FProgressManager.GetPredictedProgress(LStatus);
      PredictedDuration := FProgressManager.GetPredictedDuration(LStatus);
      
      // Update animation controller with new phase
      if FAnimationController <> nil then
      begin
        FAnimationController.SetPhase(LStatus, FAnimationController.DisplayProgress,
          PredictedProgress, PredictedDuration);
      end;
    end;
    
    // Update display state
    UpdateDisplayState(PredictedProgress, LStatus);
    
    // Stop simulation if running
    if (FSimulationManager <> nil) and FSimulationManager.IsSimulating then
      FSimulationManager.StopSimulation;
  end
  else
  begin
    // No update received - check if we should start simulation
    if FSimulationManager <> nil then
    begin
      if not FSimulationManager.IsSimulating and 
         (GetTickCount - FLastIPCUpdate > 1000) then
      begin
        if FSimulationManager.ShouldShowSimulation then
          FSimulationManager.StartSimulation;
      end;
      
      // Update simulation if running
      if FSimulationManager.IsSimulating then
      begin
        FSimulationManager.UpdateSimulation;
        UpdateDisplayState(FSimulationManager.SimulatedProgress / 100.0,
          FSimulationManager.SimulatedStatus);
      end;
    end;
  end;
end;

procedure TfrmModernSplash.UpdateDisplayState(AProgress: Single; const AStatus: string);
begin
  FCurrentProgress := AProgress;
  FCurrentStatus := AStatus;
  
  // Animation controller will handle smooth transitions
  if FAnimationController <> nil then
    FAnimationController.SetTarget(AProgress, 1000);
end;

end.