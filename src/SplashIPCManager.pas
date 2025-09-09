unit SplashIPCManager;

interface

uses
  System.SysUtils, Winapi.Windows, Vcl.ExtCtrls,
  SplashInterfaces, IPCShared, DebugManager;

type
  TSplashIPCManager = class(TInterfacedObject, ISplashIPCManager)
  private
    FIPCMonitor: TIPCMonitor;
    FIPCTimer: TTimer;
    FLastIPCUpdate: DWORD;
    FParentPID: DWORD;
    
    procedure IPCTimerTimer(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    
    // ISplashIPCManager implementation
    procedure StartMonitoring(AParentPID: DWORD);
    procedure StopMonitoring;
    function CheckForUpdate(out AProgress: Integer; out AStatus: string): Boolean;
    function GetIsParentAlive: Boolean;
    function GetShouldClose: Boolean;
    function IsTimeout(ASeconds: Integer): Boolean;
  end;

implementation

const
  PARENT_DEATH_DETECTION = 200; // Check for parent process every X msecs

{ TSplashIPCManager }

constructor TSplashIPCManager.Create;
begin
  inherited Create;
  FIPCMonitor := nil;
  FIPCTimer := nil;
  FLastIPCUpdate := GetTickCount;
end;

destructor TSplashIPCManager.Destroy;
begin
  StopMonitoring;
  inherited;
end;

procedure TSplashIPCManager.StartMonitoring(AParentPID: DWORD);
begin
  // Guard against multiple calls
  if (FIPCMonitor <> nil) or (FIPCTimer <> nil) then
  begin
    DebugLog('IPC monitoring already active - ignoring duplicate call');
    Exit;
  end;
  
  FParentPID := AParentPID;
  
  try
    // Create IPC monitor with parent PID
    FIPCMonitor := TIPCMonitor.Create(AParentPID);

    // Create timer for checking IPC updates
    FIPCTimer := TTimer.Create(nil);
    FIPCTimer.Interval := PARENT_DEATH_DETECTION;
    FIPCTimer.OnTimer := IPCTimerTimer;
    FIPCTimer.Enabled := True;
    
    FLastIPCUpdate := GetTickCount;
  except
    on E: Exception do
    begin
      DebugLogFormat('Failed to start IPC monitoring: %s', [E.Message]);
      StopMonitoring;
      raise;
    end;
  end;
end;

procedure TSplashIPCManager.StopMonitoring;
begin
  if FIPCTimer <> nil then
  begin
    FIPCTimer.Enabled := False;
    FreeAndNil(FIPCTimer);
  end;
  
  FreeAndNil(FIPCMonitor);
end;

function TSplashIPCManager.CheckForUpdate(out AProgress: Integer; out AStatus: string): Boolean;
begin
  Result := False;
  AProgress := -1;
  AStatus := '';
  
  if FIPCMonitor = nil then
    Exit;
    
  Result := FIPCMonitor.CheckForUpdate(AProgress, AStatus);
  if Result then
    FLastIPCUpdate := GetTickCount;
end;

function TSplashIPCManager.GetIsParentAlive: Boolean;
begin
  Result := True;
  if FIPCMonitor <> nil then
    Result := FIPCMonitor.IsParentAlive;
end;

function TSplashIPCManager.GetShouldClose: Boolean;
begin
  Result := False;
  if FIPCMonitor <> nil then
    Result := FIPCMonitor.ShouldClose;
end;

function TSplashIPCManager.IsTimeout(ASeconds: Integer): Boolean;
begin
  Result := False;
  if FIPCMonitor <> nil then
    Result := FIPCMonitor.IsTimeout(ASeconds);
end;

procedure TSplashIPCManager.IPCTimerTimer(Sender: TObject);
begin
  // This timer just keeps the IPC monitor active
  // The actual checking is done by calling CheckForUpdate
  // We just need to ensure parent is still alive
  if not GetIsParentAlive then
  begin
    DebugLog('Parent process died - IPC manager detected');
    FIPCTimer.Enabled := False;
  end;
end;

end.