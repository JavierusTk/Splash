unit AutoSplash;

// =============================================================================
// AUTO-START SPLASH SCREEN UNIT
// =============================================================================
// Simply add this unit to your uses clause to automatically launch the splash
// screen. The splash will start in the initialization section and close
// automatically in the finalization section or when the application starts.
//
// Usage:
//   uses
//     AutoSplash,  // Just add this line - splash starts automatically!
//     Forms,
//     ...
//
// Then anywhere in your code:
//   Splash.UpdateStatus('Loading database...');
//   Splash.UpdateProgress(50, 'Half way there...');
//
// =============================================================================

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, System.SyncObjs,
  IPCShared, AutoSplashConfig;

type
  // Interface for automatic cleanup via reference counting
  IAutoSplash = interface
    ['{8F4C6B3A-9E7D-4F8B-B3C5-7A8D9E5C4B2F}']
    procedure UpdateStatus(const AStatus: string);
    procedure UpdateProgress(AProgress: Integer; const AStatus: string);
    procedure Close;
    procedure SetMinimumDisplayTime(AMilliseconds: Integer);
    function IsActive: Boolean;
    procedure WaitForMinimumTime;
  end;

  // Implementation class
  TAutoSplash = class(TInterfacedObject, IAutoSplash)
  private
    FIPCManager: TIPCManager;
    FCriticalSection: TCriticalSection;
    FStartTime: DWORD;
    FMinimumDisplayTime: Integer;
    FIsActive: Boolean;
    FClosed: Boolean;
    
    procedure InternalClose;
  public
    constructor Create;
    destructor Destroy; override;
    
    // IAutoSplash implementation
    procedure UpdateStatus(const AStatus: string);
    procedure UpdateProgress(AProgress: Integer; const AStatus: string);
    procedure Close;
    procedure SetMinimumDisplayTime(AMilliseconds: Integer);
    function IsActive: Boolean;
    procedure WaitForMinimumTime;
  end;

var
  // Global splash interface - automatically initialized and cleaned up
  Splash: IAutoSplash = nil;

// Manual control functions (optional - for advanced users)
procedure StartSplash;
procedure StopSplash;

implementation

uses
  System.IOUtils, Vcl.Forms;

var
  GSplashInstance: TAutoSplash = nil;

{ TAutoSplash }

constructor TAutoSplash.Create;
var
  ExePath: string;
  CommandLine: string;
begin
  inherited Create;
  
  FCriticalSection := TCriticalSection.Create;
  FMinimumDisplayTime := 1000; // Default 1 second minimum
  FStartTime := GetTickCount;
  FIsActive := False;
  FClosed := False;
  FIPCManager := nil;
  
  try
    // Create IPC manager
    FIPCManager := TIPCManager.Create;
    
    // Check if SplashScreen.exe exists
    ExePath := ExtractFilePath(ParamStr(0)) + 'SplashScreen.exe';
    if not FileExists(ExePath) then
    begin
      // Try parent directory (for debugging scenarios)
      ExePath := ExtractFilePath(ParamStr(0)) + '..\SplashScreen.exe';
      if not FileExists(ExePath) then
      begin
        // Splash not found, continue without it
        FreeAndNil(FIPCManager);
        Exit;
      end;
    end;
    
    // Build command line with configuration
    CommandLine := '';
    
    // Add application name (use exe name if not configured)
    if Config.AppName <> '' then
      CommandLine := CommandLine + ' /APP:"' + Config.AppName + '"'
    else
      CommandLine := CommandLine + ' /APP:"' + ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '"';
      
    // Add version if configured
    if Config.Version <> '' then
      CommandLine := CommandLine + ' /VER:' + Config.Version;
      
    // Add loading caption if configured
    if Config.LoadingCaption <> '' then
      CommandLine := CommandLine + ' /LOAD:"' + Config.LoadingCaption + '"';
      
    // Add learning indicator if configured
    if Config.LearningIndicator <> '' then
      CommandLine := CommandLine + ' /LEARN:"' + Config.LearningIndicator + '"';
      
    // Add starting status if configured
    if Config.StartingStatus <> '' then
      CommandLine := CommandLine + ' /START:"' + Config.StartingStatus + '"';
      
    // Add beta flag if configured
    if Config.ShowBeta then
      CommandLine := CommandLine + ' /BETA';
      
    // Add logo file if configured
    if Config.LogoFile <> '' then
      CommandLine := CommandLine + ' /LOGO:"' + Config.LogoFile + '"';
      
    // Add debug flag if configured
    if Config.EnableDebug then
    begin
      if Config.DebugLogFile <> '' then
        CommandLine := CommandLine + ' /DEBUG:"' + Config.DebugLogFile + '"'
      else
        CommandLine := CommandLine + ' /DEBUG';
    end;
    
    // Set command line for IPC manager (it will add the /pid parameter)
    if CommandLine <> '' then
      FIPCManager.SetAdditionalParams(Trim(CommandLine));
    
    // Launch splash screen
    if FIPCManager.LaunchSplashScreen then
    begin
      FIsActive := True;
      
      // Give splash screen time to initialize
      Sleep(200);
      
      // Send initial status if configured
      if Config.StartingStatus <> '' then
        UpdateStatus(Config.StartingStatus);
    end
    else
    begin
      // Failed to launch, clean up
      FreeAndNil(FIPCManager);
    end;
  except
    // If anything fails, continue without splash
    FreeAndNil(FIPCManager);
  end;
end;

destructor TAutoSplash.Destroy;
begin
  InternalClose;
  FreeAndNil(FCriticalSection);
  inherited;
end;

procedure TAutoSplash.InternalClose;
begin
  if FClosed then
    Exit;
    
  FClosed := True;
  
  if Assigned(FIPCManager) then
  begin
    try
      WaitForMinimumTime;
      FIPCManager.CloseSplash;
      
      // Give splash time to close gracefully
      Sleep(100);
    finally
      FreeAndNil(FIPCManager);
      FIsActive := False;
    end;
  end;
end;

procedure TAutoSplash.UpdateStatus(const AStatus: string);
begin
  FCriticalSection.Enter;
  try
    if Assigned(FIPCManager) and FIsActive and not FClosed then
    begin
      try
        FIPCManager.UpdateStatus(AStatus);
      except
        // Ignore errors - don't let splash problems crash the app
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TAutoSplash.UpdateProgress(AProgress: Integer; const AStatus: string);
begin
  FCriticalSection.Enter;
  try
    if Assigned(FIPCManager) and FIsActive and not FClosed then
    begin
      try
        FIPCManager.UpdateProgress(AProgress, AStatus);
      except
        // Ignore errors - don't let splash problems crash the app
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TAutoSplash.Close;
begin
  FCriticalSection.Enter;
  try
    InternalClose;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TAutoSplash.SetMinimumDisplayTime(AMilliseconds: Integer);
begin
  FMinimumDisplayTime := AMilliseconds;
end;

function TAutoSplash.IsActive: Boolean;
begin
  FCriticalSection.Enter;
  try
    Result := FIsActive and not FClosed;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TAutoSplash.WaitForMinimumTime;
var
  ElapsedTime: DWORD;
  RemainingTime: Integer;
begin
  if FMinimumDisplayTime <= 0 then
    Exit;
    
  ElapsedTime := GetTickCount - FStartTime;
  if ElapsedTime < DWORD(FMinimumDisplayTime) then
  begin
    RemainingTime := FMinimumDisplayTime - Integer(ElapsedTime);
    if RemainingTime > 0 then
      Sleep(RemainingTime);
  end;
end;

{ Global functions }

procedure StartSplash;
begin
  if not Assigned(Splash) then
  begin
    GSplashInstance := TAutoSplash.Create;
    Splash := GSplashInstance;
  end;
end;

procedure StopSplash;
begin
  if Assigned(Splash) then
  begin
    Splash.Close;
    Splash := nil;
    GSplashInstance := nil;
  end;
end;

initialization
  // Automatically start splash screen when unit is loaded
  // This happens before the main program block executes
  StartSplash;

finalization
  // Automatically stop splash screen when program ends
  // This ensures clean shutdown even if the user forgets to close it
  StopSplash;

end.