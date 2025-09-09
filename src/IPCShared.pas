unit IPCShared;

interface

uses
  Windows, SysUtils, TlHelp32;

const
  // IPC name prefixes
  SPLASH_MUTEX_PREFIX = 'CyberMAX25_SplashMutex_';
  SHARED_MEMORY_PREFIX = 'CyberMAX25_SharedProgress_';
  SHARED_MEMORY_SIZE = 1024; // Increased for WideChar text

type
  // Shared memory structure for progress communication
  PSharedProgress = ^TSharedProgress;
  TSharedProgress = packed record
    Progress: Integer;                    // 0-100
    StatusText: array[0..255] of WideChar; // Current status text (Unicode)
    ShouldClose: Boolean;                  // Signal to close splash
    UpdateFlag: Integer;                   // Increment on each update
  end;

  // IPC Manager for main application
  TIPCManager = class
  private
    FMutexHandle: THandle;
    FMappingHandle: THandle;
    FSharedData: PSharedProgress;
    FProcessID: DWORD;
    FMutexName: string;
    FMemoryName: string;
    FAdditionalParams: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    function LaunchSplashScreen: Boolean;
    procedure UpdateProgress(AProgress: Integer; const AStatus: string);
    procedure UpdateStatus(const AStatus: string); // Status-only update
    procedure CloseSplash;
    procedure SetAdditionalParams(const AParams: string);
    
    function GetIsConnected: Boolean;
    property IsConnected: Boolean read GetIsConnected;
    property ProcessID: DWORD read FProcessID;
  end;

  // IPC Monitor for splash screen
  TIPCMonitor = class
  private
    FMutexHandle: THandle;
    FMappingHandle: THandle;
    FSharedData: PSharedProgress;
    FLastUpdateFlag: Integer;
    FParentPID: DWORD;
    FLastActivityTime: DWORD;
    FMutexName: string;
    FMemoryName: string;
  public
    constructor Create(AParentPID: DWORD);
    destructor Destroy; override;
    
    function CheckForUpdate(out AProgress: Integer; out AStatus: string): Boolean;
    function ShouldClose: Boolean;
    function IsParentAlive: Boolean;
    function IsTimeout(ATimeoutSeconds: Integer = 30): Boolean;
    
    property ParentPID: DWORD read FParentPID;
  end;

// Helper function to check if a process exists
function ProcessExists(APid: DWORD): Boolean;

// Helper function to get current process ID
function GetCurrentPID: DWORD;

implementation

uses
  ShellAPI;

function ProcessExists(APid: DWORD): Boolean;
var
  hSnapshot: THandle;
  ProcessEntry: TProcessEntry32;
begin
  Result := False;
  
  // Method 1: Use process snapshot (most reliable)
  hSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if hSnapshot <> INVALID_HANDLE_VALUE then
  begin
    ProcessEntry.dwSize := SizeOf(ProcessEntry);
    if Process32First(hSnapshot, ProcessEntry) then
    begin
      repeat
        if ProcessEntry.th32ProcessID = APid then
        begin
          Result := True;
          Break;
        end;
      until not Process32Next(hSnapshot, ProcessEntry);
    end;
    CloseHandle(hSnapshot);
  end;
end;

function GetCurrentPID: DWORD;
begin
  Result := GetCurrentProcessId;
end;

{ TIPCManager }

constructor TIPCManager.Create;
begin
  inherited;
  FMutexHandle := 0;
  FMappingHandle := 0;
  FSharedData := nil;
  FAdditionalParams := '';
  
  // Get current process ID for unique naming
  FProcessID := GetCurrentPID;
  
  // Create unique names based on process ID
  FMutexName := SPLASH_MUTEX_PREFIX + IntToStr(FProcessID);
  FMemoryName := SHARED_MEMORY_PREFIX + IntToStr(FProcessID);
  
  // Create mutex for synchronization
  FMutexHandle := CreateMutex(nil, False, PChar(FMutexName));
  if FMutexHandle = 0 then
    raise Exception.Create('Failed to create mutex');
  
  // Create memory-mapped file
  FMappingHandle := CreateFileMapping(
    INVALID_HANDLE_VALUE,
    nil,
    PAGE_READWRITE,
    0,
    SHARED_MEMORY_SIZE,
    PChar(FMemoryName)
  );
  
  if FMappingHandle = 0 then
    raise Exception.Create('Failed to create shared memory');
  
  // Map the shared memory
  FSharedData := MapViewOfFile(
    FMappingHandle,
    FILE_MAP_ALL_ACCESS,
    0, 0,
    SHARED_MEMORY_SIZE
  );
  
  if FSharedData = nil then
    raise Exception.Create('Failed to map shared memory');
  
  // Initialize shared data
  ZeroMemory(FSharedData, SizeOf(TSharedProgress));
end;

destructor TIPCManager.Destroy;
begin
  if FSharedData <> nil then
  begin
    // Signal splash to close before unmapping
    FSharedData^.ShouldClose := True;
    UnmapViewOfFile(FSharedData);
  end;
  
  if FMappingHandle <> 0 then
    CloseHandle(FMappingHandle);
  
  if FMutexHandle <> 0 then
    CloseHandle(FMutexHandle);
  
  inherited;
end;

function TIPCManager.LaunchSplashScreen: Boolean;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  ExePath: string;
  CommandLine: string;
begin
  Result := False;
  
  // Get path to splash screen executable
  ExePath := ExtractFilePath(ParamStr(0)) + 'SplashScreen.exe';
  
  if not FileExists(ExePath) then
  begin
    // Splash screen not found, continue without it
    Exit;
  end;
  
  // Build command line with parent PID, app name, and additional params
  CommandLine := Format('"%s" /pid:%d /APP:"%s"', 
    [ExePath, FProcessID, ChangeFileExt(ExtractFileName(ParamStr(0)), '')]);
  if FAdditionalParams <> '' then
    CommandLine := CommandLine + ' ' + FAdditionalParams;
  
  // Initialize startup info
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_SHOW;
  
  // Create splash screen process
  Result := CreateProcess(
    nil,
    PChar(CommandLine),
    nil,
    nil,
    False,
    NORMAL_PRIORITY_CLASS,
    nil,
    nil,
    StartupInfo,
    ProcessInfo
  );
  
  if Result then
  begin
    // Close handles as we don't need them
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
    
    // Give splash screen time to initialize
    Sleep(100);
  end;
end;

procedure TIPCManager.UpdateProgress(AProgress: Integer; const AStatus: string);
var
  WideStr: WideString;
  Len: Integer;
begin
  if FSharedData = nil then Exit;
  
  WaitForSingleObject(FMutexHandle, INFINITE);
  try
    FSharedData^.Progress := AProgress;
    
    // Convert to WideString and copy safely
    WideStr := AStatus;
    Len := Length(WideStr);
    if Len > 255 then
      Len := 255;
    
    if Len > 0 then
      Move(WideStr[1], FSharedData^.StatusText[0], Len * SizeOf(WideChar));
    
    // Null terminate
    FSharedData^.StatusText[Len] := #0;
    
    Inc(FSharedData^.UpdateFlag);
  finally
    ReleaseMutex(FMutexHandle);
  end;
end;

procedure TIPCManager.UpdateStatus(const AStatus: string);
begin
  // Call UpdateProgress with -1 to indicate no explicit progress value
  UpdateProgress(-1, AStatus);
end;

procedure TIPCManager.CloseSplash;
begin
  if FSharedData = nil then Exit;
  
  WaitForSingleObject(FMutexHandle, INFINITE);
  try
    FSharedData^.ShouldClose := True;
  finally
    ReleaseMutex(FMutexHandle);
  end;
  
  // Give splash time to close gracefully
  Sleep(200);
end;

function TIPCManager.GetIsConnected: Boolean;
begin
  Result := FSharedData <> nil;
end;

procedure TIPCManager.SetAdditionalParams(const AParams: string);
begin
  FAdditionalParams := AParams;
end;

{ TIPCMonitor }

constructor TIPCMonitor.Create(AParentPID: DWORD);
begin
  inherited Create;
  FMutexHandle := 0;
  FMappingHandle := 0;
  FSharedData := nil;
  FLastUpdateFlag := -1;
  FParentPID := AParentPID;
  FLastActivityTime := GetTickCount;
  
  // Create names based on parent PID
  FMutexName := SPLASH_MUTEX_PREFIX + IntToStr(FParentPID);
  FMemoryName := SHARED_MEMORY_PREFIX + IntToStr(FParentPID);
  
  // Open existing mutex
  FMutexHandle := OpenMutex(MUTEX_ALL_ACCESS, False, PChar(FMutexName));
  if FMutexHandle = 0 then
    raise Exception.Create('Failed to open mutex');
  
  // Open existing memory-mapped file
  FMappingHandle := OpenFileMapping(
    FILE_MAP_ALL_ACCESS,
    False,
    PChar(FMemoryName)
  );
  
  if FMappingHandle = 0 then
    raise Exception.Create('Failed to open shared memory');
  
  // Map the shared memory
  FSharedData := MapViewOfFile(
    FMappingHandle,
    FILE_MAP_ALL_ACCESS,
    0, 0,
    SHARED_MEMORY_SIZE
  );
  
  if FSharedData = nil then
    raise Exception.Create('Failed to map shared memory');
end;

destructor TIPCMonitor.Destroy;
begin
  if FSharedData <> nil then
    UnmapViewOfFile(FSharedData);
  
  if FMappingHandle <> 0 then
    CloseHandle(FMappingHandle);
  
  if FMutexHandle <> 0 then
    CloseHandle(FMutexHandle);
  
  inherited;
end;

function TIPCMonitor.CheckForUpdate(out AProgress: Integer; out AStatus: string): Boolean;
var
  WideStr: WideString;
  Len: Integer;
begin
  Result := False;
  if FSharedData = nil then Exit;
  
  if WaitForSingleObject(FMutexHandle, 10) = WAIT_OBJECT_0 then
  begin
    try
      if FSharedData^.UpdateFlag <> FLastUpdateFlag then
      begin
        AProgress := FSharedData^.Progress;
        
        // Read Unicode text safely
        Len := 0;
        while (Len < 255) and (FSharedData^.StatusText[Len] <> #0) do
          Inc(Len);
        
        SetLength(WideStr, Len);
        if Len > 0 then
          Move(FSharedData^.StatusText[0], WideStr[1], Len * SizeOf(WideChar));
        
        AStatus := string(WideStr);
        
        FLastUpdateFlag := FSharedData^.UpdateFlag;
        FLastActivityTime := GetTickCount;  // Reset timeout
        Result := True;
      end;
    finally
      ReleaseMutex(FMutexHandle);
    end;
  end;
end;

function TIPCMonitor.ShouldClose: Boolean;
begin
  Result := False;
  if FSharedData = nil then Exit;
  
  if WaitForSingleObject(FMutexHandle, 10) = WAIT_OBJECT_0 then
  begin
    try
      Result := FSharedData^.ShouldClose;
    finally
      ReleaseMutex(FMutexHandle);
    end;
  end;
end;

function TIPCMonitor.IsParentAlive: Boolean;
begin
  Result := ProcessExists(FParentPID);
end;

function TIPCMonitor.IsTimeout(ATimeoutSeconds: Integer): Boolean;
var
  CurrentTime: DWORD;
  ElapsedMs: DWORD;
begin
  CurrentTime := GetTickCount;
  
  // Handle tick count wrap-around
  if CurrentTime >= FLastActivityTime then
    ElapsedMs := CurrentTime - FLastActivityTime
  else
    ElapsedMs := (High(DWORD) - FLastActivityTime) + CurrentTime;
  
  Result := ElapsedMs > DWORD(ATimeoutSeconds * 1000);
end;

end.