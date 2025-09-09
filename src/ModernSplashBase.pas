unit ModernSplashBase;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.UITypes, System.Math,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics,
  System.Skia, Vcl.Skia, Winapi.Windows,
  IPCShared, ProgressLearning, AdaptiveLearning, DebugManager, SplashConfig,
  SplashInterfaces, SplashIPCManager, SplashAnimationController, 
  SplashProgressManager, SplashSimulationManager;

type
  
  TProgressLogger = class
    class procedure LogProgress(const AFormat: string; const Args: array of const);
    class procedure LogPhaseFound(const APhaseName: string; AFound: Boolean);
    class procedure LogStatusUpdate(const AStatus: string; AProgress: Integer; ADuration: Integer);
    class procedure LogCalculatedProgress(const AStatus: string; AProgress: Integer; 
      AEndProgress, AStartProgress, AGap: Single);
    class procedure LogExplicitProgress(const AStatus: string; AProgress: Integer;
      APredicted, ADisplay: Single; ADuration: Integer);
    class procedure LogAdaptiveLearning(const AStatus: string; AEndProgress: Single);
  end;

  TfrmModernSplashBase = class(TForm)
    SkAnimatedPaintBox: TSkAnimatedPaintBox;
    AnimationTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SkAnimatedPaintBoxAnimationDraw(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double; const AOpacity: Single);
    procedure AnimationTimerTimer(Sender: TObject);
  strict private
    // Core state
    FProgress: Single;
    FStatusText: string;
    FIsBeta: Boolean;
    FAnimationTime: Single;
    FDotsAnimation: Integer;
    FConfiguration: TSplashConfiguration;
    FSvgLogo: ISkSVGDOM;
    FLastIPCUpdate: DWORD;
    
    // Real painted dimensions
    FLastPaintedBarWidth: Single;   // Actual painted progress bar width in pixels
    
    // Manager interfaces
    FIPCManager: ISplashIPCManager;
    FAnimationController: ISplashAnimationController;
    FProgressManager: ISplashProgressManager;
    FSimulationManager: ISplashSimulationManager;
    
    // Main timer for coordination
    FMainTimer: TTimer;
    
    procedure MainTimerTimer(Sender: TObject);
    procedure HandleNewStatus(const AStatus: string; AProgress: Integer);
    function GetRealPaintedBarWidth: Single;
    function GetDisplayProgress: Single;
  strict protected
    // Main rendering method - must be overridden in descendant class
    procedure RenderSplashContent(const ACanvas: ISkCanvas; const ARect: TRectF); virtual; abstract;
    // Helper methods available to descendant classes
    function CreateGradientShader(const AStartColor, AEndColor: TAlphaColor; const AStart, AEnd: TPointF): ISkShader;
    function GetSvgLogo: ISkSVGDOM;
    // Access to internal state for descendants
    property Configuration: TSplashConfiguration read FConfiguration;
    property StatusText: string read FStatusText;
    property IsBeta: Boolean read FIsBeta;
    property DisplayProgress: Single read GetDisplayProgress;
    property AnimationTime: Single read FAnimationTime;
    property DotsAnimation: Integer read FDotsAnimation;
    property LastPaintedBarWidth: Single read FLastPaintedBarWidth write FLastPaintedBarWidth;
  public
    procedure UpdateProgress(const AText: string; AProgress: Single);
    procedure SetBeta(AIsBeta: Boolean);
    procedure TakeScreenshot(const AQuality: string);
    procedure StartIPCMonitoring(AParentPID: DWORD);
    procedure InitializeWithConfiguration(const AConfig: TSplashConfiguration);
  end;

var
  frmModernSplashBase: TfrmModernSplashBase;

implementation

{$R *.dfm}


const
  // Parent related
  PARENT_TIMEOUT = 30; // Seconds since last update from parent
  MAIN_TIMER_INTERVAL = 50; // Check IPC and update state every 50ms

procedure TfrmModernSplashBase.FormCreate(Sender: TObject);
var
  LProgressHistory: TProgressHistory;
begin
  // Initialize default configuration (will be overridden by InitializeWithConfiguration)
  FConfiguration := TSplashConfiguration.CreateDefault;
  
  FProgress := 0;
  FStatusText := FConfiguration.StartingStatus;
  FIsBeta := FConfiguration.IsBeta;
  FAnimationTime := 0;
  FDotsAnimation := 0;
  FLastIPCUpdate := GetTickCount;
  
  // Create managers
  FIPCManager := TSplashIPCManager.Create;
  FAnimationController := TSplashAnimationController.Create;
  FAnimationController.Initialize;
  
  // Create progress manager with shared history
  FProgressManager := TSplashProgressManager.Create(FConfiguration);
  FProgressManager.StartSession;
  
  // Create simulation manager (needs access to progress history)
  LProgressHistory := TProgressHistory.Create;
  LProgressHistory.StartSession;
  LProgressHistory.SetPaintedBarWidthCallback(GetRealPaintedBarWidth);
  FSimulationManager := TSplashSimulationManager.Create(LProgressHistory);
  
  // Create main coordination timer
  FMainTimer := TTimer.Create(Self);
  FMainTimer.Interval := MAIN_TIMER_INTERVAL;
  FMainTimer.OnTimer := MainTimerTimer;
  FMainTimer.Enabled := True;

  // Enable double buffering to reduce flicker
  DoubleBuffered := True;

  // Start animation with slower refresh rate
  SkAnimatedPaintBox.Animation.Enabled := True;
  SkAnimatedPaintBox.Animation.Duration := 10000; // 10 seconds loop
  AnimationTimer.Enabled := True;
end;

procedure TfrmModernSplashBase.AnimationTimerTimer(Sender: TObject);
begin
  FAnimationTime := FAnimationTime + 0.15; // Slower animation increment
  FDotsAnimation := (FDotsAnimation + 1) mod 120; // Slower dots animation
  // FLICKER FIX: Don't call Redraw - let TSkAnimatedPaintBox handle all redraws
  // The continuous animation will pick up the updated FDotsAnimation value
end;

procedure TfrmModernSplashBase.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // Log that FormClose was called
  DebugLog('FormClose called - Starting save process');
  
  // Save learning data through progress manager
  if FProgressManager <> nil then
    FProgressManager.EndSession;
  
  DebugLog('FormClose completed');
  
  Action := caFree;
end;

procedure TfrmModernSplashBase.FormDestroy(Sender: TObject);
begin
  // Log that FormDestroy was called
  DebugLog('FormDestroy called');
  
  // Clean up
  FConfiguration := TSplashConfiguration.CreateDefault;
  
  // Managers are interface-based, will be freed automatically
  FIPCManager := nil;
  FAnimationController := nil;
  FProgressManager := nil;
  FSimulationManager := nil;
  
  FreeAndNil(FMainTimer);
end;

procedure TfrmModernSplashBase.InitializeWithConfiguration(const AConfig: TSplashConfiguration);
var
  AppName: string;
begin
  // Store the configuration
  FConfiguration := AConfig;
  
  // Update form properties based on configuration
  FStatusText := AConfig.StartingStatus;
  FIsBeta := AConfig.IsBeta;
  
  // Update form caption
  if AConfig.AppName <> '' then
    AppName := AConfig.AppName
  else
    AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
  FConfiguration.AppName := AppName;  // Store app name for drawing
  Caption := AppName + ' ' + AConfig.Version + AConfig.SubVersion;
  
  DebugLogFormat('Splash initialized with config - App: "%s", Version: "%s%s", Loading: "%s", Learn: "%s", Beta: %s, Start: "%s", Logo: "%s"',
    [AppName, AConfig.Version, AConfig.SubVersion, AConfig.LoadingCaption, AConfig.LearningIndicator,
     BoolToStr(AConfig.IsBeta, True), AConfig.StartingStatus, AConfig.LogoFile]);
     
  // Clear the existing SVG logo if we have a custom logo file
  if (AConfig.LogoFile <> '') then
  begin
    FSvgLogo := nil; // This will force reload in GetSvgLogo
    DebugLogFormat('Custom logo specified: %s', [AConfig.LogoFile]);
  end;
end;

function TfrmModernSplashBase.CreateGradientShader(const AStartColor, AEndColor: TAlphaColor; const AStart, AEnd: TPointF): ISkShader;
begin
  Result := TSkShader.MakeGradientLinear(AStart, AEnd, AStartColor, AEndColor, TSkTileMode.Clamp);
end;

const
  // SVG with ONLY viewBox and two <path> elements (base-with-hole + star)
  C_SVG_LOGO: string =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 60">' +
    '  <path fill="#7C3AED" fill-rule="evenodd" clip-rule="evenodd" d="' +
    // Base: outer circle (CW) + inner hole (CCW); inner radius = 0.35 * farthest-corner
    // outer: center(30,30) r=30
    // inner: center(42,30) r=18.0648830607895
    'M 60 30 A 30 30 0 1 1 0 30 A 30 30 0 1 1 60 30 Z ' +
    'M 60.064883061 30 A 18.064883061 18.064883061 0 1 0 23.935116939 30 ' +
    'A 18.064883061 18.064883061 0 1 0 60.064883061 30 Z" />' +
    // Star: 20x20 box centered at (42,30) using the same polygon as the CSS
    '  <path fill="#FF9800" d="' +
    'M 42.000 20.000 L 44.200 27.000 L 51.600 27.000 L 45.600 31.400 L 47.800 38.200 ' +
    'L 42.000 34.000 L 36.200 38.200 L 38.400 31.400 L 32.400 27.000 L 39.800 27.000 Z" />' +
    '</svg>';

function TfrmModernSplashBase.GetSvgLogo: ISkSVGDOM;
var
  SS: TStringStream;
  FS: TFileStream;
  LogoPath: string;
begin
  if FSvgLogo = nil then
  begin
    // Check if a custom logo file is specified
    if (FConfiguration.LogoFile <> '') then
    begin
      LogoPath := FConfiguration.LogoFile;

      if FileExists(LogoPath) then
      begin
        DebugLogFormat('Loading custom SVG logo from: %s', [LogoPath]);
        try
          FS := TFileStream.Create(LogoPath, fmOpenRead);
          try
            FSvgLogo := TSkSVGDOM.MakeFromStream(FS);
            if FSvgLogo <> nil then
              DebugLogFormat('Custom SVG logo loaded successfully from: %s', [LogoPath])
            else
              DebugLogFormat('Failed to parse SVG from file: %s', [LogoPath]);
          finally
            FS.Free;
          end;
        except
          on E: Exception do
          begin
            DebugLogFormat('Error loading custom logo from "%s": %s', [LogoPath, E.Message]);
          end;
        end;
      end
      else
      begin
        DebugLogFormat('Custom logo file not found: %s', [FConfiguration.LogoFile]);
      end;
    end;
    
    // Fall back to embedded logo if custom logo failed or not specified
    if FSvgLogo = nil then
    begin
      DebugLog('Using embedded SVG logo');
      SS := TStringStream.Create(C_SVG_LOGO, TEncoding.UTF8);
      try
        FSvgLogo := TSkSVGDOM.MakeFromStream(SS);
      finally
        SS.Free;
      end;
    end;
  end;
  Result := FSvgLogo;
end;


procedure TfrmModernSplashBase.SkAnimatedPaintBoxAnimationDraw(ASender: TObject; const ACanvas: ISkCanvas; const ADest: TRectF; const AProgress: Double; const AOpacity: Single);
begin
  RenderSplashContent(ACanvas, ADest);
end;

procedure TfrmModernSplashBase.UpdateProgress(const AText: string; AProgress: Single);
begin
  if (FStatusText <> AText) or (Abs(FProgress - AProgress) > 0.01) then
  begin
    FStatusText := AText;
    FProgress := AProgress;
    
    // Update animation controller if available
    if FAnimationController <> nil then
      FAnimationController.SetTarget(AProgress, 1000); // Default 1 second duration
      
    // Let animation timer handle updates - no ProcessMessages needed
    // The animated paint box will pick up changes on next frame
  end;
end;

procedure TfrmModernSplashBase.SetBeta(AIsBeta: Boolean);
begin
  FIsBeta := AIsBeta;
  SkAnimatedPaintBox.Redraw;
end;

procedure TfrmModernSplashBase.TakeScreenshot(const AQuality: string);
var
  LSurface: ISkSurface;
  LImage: ISkImage;
  LCanvas: ISkCanvas;
  LFileName: string;
  LRect: TRectF;
begin
  // Only take screenshots in debug mode
  if not IsDebugEnabled then
    Exit;
    
  try
    // Create an off-screen surface with the same dimensions as the paintbox
    LRect := TRectF.Create(0, 0, SkAnimatedPaintBox.Width, SkAnimatedPaintBox.Height);
    LSurface := TSkSurface.MakeRaster(Round(LRect.Width), Round(LRect.Height));
    if Assigned(LSurface) then
    begin
      LCanvas := LSurface.Canvas;
      
      // Render all our drawing methods to the surface canvas
      RenderSplashContent(LCanvas, LRect);
      
      // Create image from surface and save
      LImage := LSurface.MakeImageSnapshot;
      if Assigned(LImage) then
      begin
        LFileName := 'splash_' + AQuality + '.png';
        LImage.EncodeToFile(LFileName);
      end;
    end;
  except
    on E: Exception do
      DebugLogFormat('TakeScreenshot failed for quality "%s": %s', [AQuality, E.Message]);
  end;
end;

procedure TfrmModernSplashBase.StartIPCMonitoring(AParentPID: DWORD);
begin
  try
    if FIPCManager <> nil then
      FIPCManager.StartMonitoring(AParentPID);
  except
    on E: Exception do
    begin
      DebugLogFormat('Failed to start IPC monitoring: %s', [E.Message]);
      Close; // Close splash if IPC fails
    end;
  end;
end;

procedure TfrmModernSplashBase.MainTimerTimer(Sender: TObject);
var
  LProgress: Integer;
  LStatus: string;
begin
  if FIPCManager = nil then Exit;

  // Check if parent process is still alive
  if not FIPCManager.IsParentAlive then
  begin
    DebugLog('Parent process died - closing splash');
    FMainTimer.Enabled := False;
    Close; // Parent died, close immediately
    Exit;
  end;

  // Check for timeout (30 seconds without updates)
  if FIPCManager.IsTimeout(PARENT_TIMEOUT) then
  begin
    DebugLog('Timeout reached - closing splash');
    FMainTimer.Enabled := False;
    Close; // Timeout reached, close splash
    Exit;
  end;

  // Check for close signal
  if FIPCManager.ShouldClose then
  begin
    DebugLog('Close signal received - closing splash');
    FMainTimer.Enabled := False;
    Close;
    Exit;
  end;

  // Check for progress updates
  if FIPCManager.CheckForUpdate(LProgress, LStatus) then
  begin
    // Handle the new status through progress manager
    HandleNewStatus(LStatus, LProgress);
    
    FLastIPCUpdate := GetTickCount;
      
    // Stop simulation if we're getting real updates
    if FSimulationManager.IsSimulating then
      FSimulationManager.StopSimulation;
  end
  else
  begin
    // No update received, check if we should start simulation
    if not FSimulationManager.IsSimulating and (GetTickCount - FLastIPCUpdate > 1000) then
    begin
      // No updates for 1 second, start simulation
      if FSimulationManager.ShouldShowSimulation then
      begin
        FSimulationManager.StartSimulation;
      end;
    end;
    
    // Update simulation if running
    if FSimulationManager.IsSimulating then
    begin
      FSimulationManager.UpdateSimulation;
      FProgress := FSimulationManager.SimulatedProgress / 100.0;
      FStatusText := FSimulationManager.SimulatedStatus;
    end;
  end;
  
  // Update animation
  FAnimationController.UpdateAnimation(MAIN_TIMER_INTERVAL / 1000.0);
end;

// Simulation and animation are now handled by managers

procedure TfrmModernSplashBase.HandleNewStatus(const AStatus: string; AProgress: Integer);
var
  PredictedProgress: Single;
  PredictedDuration: Integer;
begin
  // Update status text immediately
  FStatusText := AStatus;
  
  // Let progress manager handle the status update
  FProgressManager.HandleStatusUpdate(AStatus, AProgress);
  
  // Get predictions from progress manager
  PredictedProgress := FProgressManager.GetPredictedProgress(AStatus);
  PredictedDuration := FProgressManager.GetPredictedDuration(AStatus);
  
  // Update animation controller with new phase
  FAnimationController.SetPhase(AStatus, FAnimationController.DisplayProgress, 
                                PredictedProgress, PredictedDuration);
  
  // Update progress for display
  FProgress := FAnimationController.DisplayProgress;
end;

function TfrmModernSplashBase.GetRealPaintedBarWidth: Single;
begin
  Result := FLastPaintedBarWidth;
end;

function TfrmModernSplashBase.GetDisplayProgress: Single;
begin
  if FAnimationController <> nil then
    Result := FAnimationController.DisplayProgress
  else
    Result := FProgress;
end;

// Helper methods moved to managers


{ TProgressLogger }

class procedure TProgressLogger.LogProgress(const AFormat: string; const Args: array of const);
begin
  DebugLogFormat(AFormat, Args);
end;

class procedure TProgressLogger.LogPhaseFound(const APhaseName: string; AFound: Boolean);
begin
  if AFound then
    DebugLogFormat('ProgressPhase for "%s": Found', [APhaseName])
  else
    DebugLogFormat('ProgressPhase for "%s": Not found', [APhaseName]);
end;

class procedure TProgressLogger.LogStatusUpdate(const AStatus: string; AProgress: Integer; ADuration: Integer);
begin
  DebugLogFormat('HandleNewStatus called for "%s", AProgress=%d, Current FPredictedDuration=%dms', 
    [AStatus, AProgress, ADuration]);
end;

class procedure TProgressLogger.LogCalculatedProgress(const AStatus: string; AProgress: Integer; 
  AEndProgress, AStartProgress, AGap: Single);
begin
  DebugLogFormat('CALCULATED PROGRESS for "%s": %d%% (%.2f), StartProgress=%.2f, Gap=%.2f', 
    [AStatus, AProgress, AEndProgress, AStartProgress, AGap]);
end;

class procedure TProgressLogger.LogExplicitProgress(const AStatus: string; AProgress: Integer;
  APredicted, ADisplay: Single; ADuration: Integer);
begin
  DebugLogFormat('EXPLICIT Status: "%s", Progress: %d%% -> Predicted=%.2f, Display=%.2f, Duration=%dms', 
    [AStatus, AProgress, APredicted, ADisplay, ADuration]);
end;

class procedure TProgressLogger.LogAdaptiveLearning(const AStatus: string; AEndProgress: Single);
begin
  DebugLogFormat('ADAPTIVE Learning for "%s": %.2f', [AStatus, AEndProgress]);
end;

end.