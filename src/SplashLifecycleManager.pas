unit SplashLifecycleManager;

interface

uses
  System.SysUtils, Winapi.Windows, Vcl.ExtCtrls,
  SplashInterfaces, IPCShared, DebugManager;

type
  TSplashLifecycleManager = class(TInterfacedObject, ISplashLifecycleManager)
  private
    FParentPID: DWORD;
    FIPCMonitor: TIPCMonitor;
    FLastUpdateTime: DWORD;
    FCloseRequested: Boolean;
    FTimeoutSeconds: Integer;
    FCheckTimer: TTimer;
    
    procedure CheckTimerTimer(Sender: TObject);
    function ProcessExists(APID: DWORD): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ISplashLifecycleManager implementation
    procedure Initialize(AParentPID: DWORD);
    procedure CheckLifecycleStatus;
    function ShouldClose: Boolean;
    function IsParentAlive: Boolean;
    function IsTimeout: Boolean;
    procedure RequestClose;
  end;

implementation

const
  DEFAULT_TIMEOUT_SECONDS = 30;
  CHECK_INTERVAL_MS = 200;

{ TSplashLifecycleManager }

constructor TSplashLifecycleManager.Create;
begin
  inherited Create;
  FCloseRequested := False;
  FTimeoutSeconds := DEFAULT_TIMEOUT_SECONDS;
  FLastUpdateTime := GetTickCount;
  FCheckTimer := nil;
end;

destructor TSplashLifecycleManager.Destroy;
begin
  if FCheckTimer <> nil then
  begin
    FCheckTimer.Enabled := False;
    FreeAndNil(FCheckTimer);
  end;
  FreeAndNil(FIPCMonitor);
  inherited;
end;

procedure TSplashLifecycleManager.Initialize(AParentPID: DWORD);
begin
  FParentPID := AParentPID;
  FLastUpdateTime := GetTickCount;
  
  // Create IPC monitor if we have a valid parent PID
  if AParentPID > 0 then
  begin
    try
      FIPCMonitor := TIPCMonitor.Create(AParentPID);
      
      // Create timer for periodic checks
      FCheckTimer := TTimer.Create(nil);
      FCheckTimer.Interval := CHECK_INTERVAL_MS;
      FCheckTimer.OnTimer := CheckTimerTimer;
      FCheckTimer.Enabled := True;
      
      DebugLogFormat('Lifecycle manager initialized with parent PID: %d', [AParentPID]);
    except
      on E: Exception do
      begin
        DebugLogFormat('Failed to initialize IPC monitor: %s', [E.Message]);
        FreeAndNil(FIPCMonitor);
        raise;
      end;
    end;
  end
  else
  begin
    DebugLog('WARNING: Lifecycle manager initialized without parent PID');
  end;
end;

procedure TSplashLifecycleManager.CheckLifecycleStatus;
begin
  // Check if parent is still alive
  if not IsParentAlive then
  begin
    DebugLog('Parent process died - requesting close');
    RequestClose;
    Exit;
  end;
  
  // Check for timeout
  if IsTimeout then
  begin
    DebugLog('Timeout reached - requesting close');
    RequestClose;
    Exit;
  end;
  
  // Check IPC for close signal if available
  if (FIPCMonitor <> nil) and FIPCMonitor.ShouldClose then
  begin
    DebugLog('Close signal received via IPC');
    RequestClose;
  end;
  
  // Update last update time - always assume we're still active
  FLastUpdateTime := GetTickCount;
end;

function TSplashLifecycleManager.ShouldClose: Boolean;
begin
  Result := FCloseRequested;
end;

function TSplashLifecycleManager.IsParentAlive: Boolean;
begin
  if FParentPID = 0 then
  begin
    Result := True; // No parent to check, assume alive
    Exit;
  end;
  
  Result := ProcessExists(FParentPID);
end;

function TSplashLifecycleManager.IsTimeout: Boolean;
var
  ElapsedSeconds: Integer;
begin
  if FTimeoutSeconds <= 0 then
  begin
    Result := False; // No timeout configured
    Exit;
  end;
  
  ElapsedSeconds := (GetTickCount - FLastUpdateTime) div 1000;
  Result := ElapsedSeconds >= FTimeoutSeconds;
end;

procedure TSplashLifecycleManager.RequestClose;
begin
  FCloseRequested := True;
  DebugLog('Close requested in lifecycle manager');
end;

procedure TSplashLifecycleManager.CheckTimerTimer(Sender: TObject);
begin
  CheckLifecycleStatus;
end;

function TSplashLifecycleManager.ProcessExists(APID: DWORD): Boolean;
var
  ProcessHandle: THandle;
begin
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION, False, APID);
  if ProcessHandle <> 0 then
  begin
    CloseHandle(ProcessHandle);
    Result := True;
  end
  else
    Result := False;
end;

end.