program SplashScreen;

uses
  Vcl.Forms,
  System.SysUtils,
  Winapi.Windows,
  ModernSplashBase in 'src\ModernSplashBase.pas' {frmModernSplashBase},
  ModernSplash in 'src\ModernSplash.pas' {frmModernSplash},
  IPCShared in 'src\IPCShared.pas',
  ProgressLearning in 'src\ProgressLearning.pas',
  AdaptiveLearning in 'src\AdaptiveLearning.pas',
  DebugManager in 'src\DebugManager.pas',
  SplashConfig in 'src\SplashConfig.pas',
  SplashLocalization in 'src\SplashLocalization.pas',
  SplashInterfaces in 'src\SplashInterfaces.pas',
  SplashIPCManager in 'src\SplashIPCManager.pas',
  SplashAnimationController in 'src\SplashAnimationController.pas',
  SplashProgressManager in 'src\SplashProgressManager.pas',
  SplashSimulationManager in 'src\SplashSimulationManager.pas',
  SplashRenderingManager in 'src\SplashRenderingManager.pas',
  SplashStyleProvider in 'src\SplashStyleProvider.pas',
  SplashLayoutCalculator in 'src\SplashLayoutCalculator.pas',
  SplashLifecycleManager in 'src\SplashLifecycleManager.pas';

{$R *.res}

function GetParentPIDFromCommandLine: DWORD;
var
  I: Integer;
  Param: string;
begin
  Result := 0;

  // Parse command line for /pid:xxxxx parameter
  for I := 1 to ParamCount do
  begin
    Param := ParamStr(I);
    if Pos('/pid:', LowerCase(Param)) = 1 then
    begin
      Delete(Param, 1, 5); // Remove '/pid:'
      Result := StrToIntDef(Param, 0);
      Break;
    end;
  end;
end;

function GetFullCommandLine: string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ParamCount do
  begin
    if I > 1 then
      Result := Result + ' ';
    Result := Result + ParamStr(I);
  end;
end;

var
  ParentPID: DWORD;
  SplashConfiguration: TSplashConfiguration;

begin
  // Initialize debug system first (before any other operations)
  InitializeDebugSystem(GetFullCommandLine);

  DebugLog('=== SplashScreen.exe Started ===');
  DebugLogFormat('Command line: %s', [GetFullCommandLine]);

  // Parse splash configuration from command line
  SplashConfiguration := TSplashConfiguration.ParseFromCommandLine(GetFullCommandLine);

  Application.Initialize;
  Application.MainFormOnTaskbar := False;

  // Get parent PID from command line
  ParentPID := GetParentPIDFromCommandLine;
  DebugLogFormat('Parent PID: %d', [ParentPID]);

  if ParentPID = 0 then
  begin
    // If no parent PID provided, exit immediately
    // This prevents orphaned splash screens
    DebugLog('ERROR: No parent PID provided - terminating');
    Application.Terminate;
    Exit;
  end;

  // Check if parent process exists (skip in debug mode for testing)
  if not IsDebugEnabled then
  begin
    if not ProcessExists(ParentPID) then
    begin
      // Parent doesn't exist, don't show splash
      DebugLogFormat('ERROR: Parent process %d does not exist - terminating', [ParentPID]);
      Application.Terminate;
      Exit;
    end;
  end
  else
  begin
    DebugLogFormat('DEBUG: Skipping parent process check for testing', []);
  end;

  DebugLogFormat('Parent process %d verified - proceeding', [ParentPID]);

  Application.CreateForm(TfrmModernSplash, frmModernSplash);
  DebugLog('Splash form created successfully');

  // Initialize splash form with configuration
  frmModernSplash.InitializeWithConfiguration(SplashConfiguration);
  DebugLog('Splash form initialized with configuration');

  // Start IPC monitoring with parent PID
  frmModernSplash.StartIPCMonitoring(ParentPID);
  DebugLog('IPC monitoring started');

  DebugLog('Starting application message loop');
  Application.Run;

  DebugLog('Application terminated normally');
end.

