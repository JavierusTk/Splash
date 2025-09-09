unit DebugManager;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, System.IOUtils;

// Public Interface - Simple & Clean
procedure DebugLog(const AMessage: string);
procedure DebugLogFormat(const AFormat: string; const Args: array of const);

// Configuration (called once at startup)
procedure InitializeDebugSystem(const ACommandLine: string);
procedure FinalizeDebugSystem;

// Query debug status
function IsDebugEnabled: Boolean;

implementation

type
  TDebugManager = class
  private
    FEnabled: Boolean;
    FLogFilePath: string;
    FMutex: THandle;
    FInitialized: Boolean;
    
    procedure ParseCommandLine(const ACommandLine: string);
    procedure CreateLogDirectory;
    function GetDefaultLogPath: string;
    procedure WriteToLog(const AMessage: string);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Initialize(const ACommandLine: string);
    procedure Finalize;
    procedure Log(const AMessage: string);
    
    property Enabled: Boolean read FEnabled;
    property LogFilePath: string read FLogFilePath;
  end;

var
  GDebugManager: TDebugManager = nil;

{ TDebugManager }

constructor TDebugManager.Create;
begin
  inherited Create;
  FEnabled := False;
  FLogFilePath := '';
  FMutex := 0;
  FInitialized := False;
end;

destructor TDebugManager.Destroy;
begin
  Finalize;
  inherited;
end;

procedure TDebugManager.Initialize(const ACommandLine: string);
begin
  if FInitialized then
    Exit;
    
  ParseCommandLine(ACommandLine);
  
  if FEnabled then
  begin
    CreateLogDirectory;
    
    // Create mutex for thread-safe logging
    // Get app identifier from exe name for mutex naming
    FMutex := CreateMutex(nil, False, PChar(ChangeFileExt(ExtractFileName(ParamStr(0)), '') + '_DebugMutex_' + IntToStr(GetCurrentProcessId)));
    if FMutex = 0 then
      FEnabled := False; // Disable if mutex creation fails
  end;
  
  FInitialized := True;
  
  // Log initialization
  if FEnabled then
    Log('=== Debug System Initialized ===');
end;

procedure TDebugManager.Finalize;
begin
  if not FInitialized then
    Exit;
    
  if FEnabled then
  begin
    Log('=== Debug System Finalized ===');
    
    if FMutex <> 0 then
    begin
      CloseHandle(FMutex);
      FMutex := 0;
    end;
  end;
  
  FEnabled := False;
  FInitialized := False;
end;

procedure TDebugManager.ParseCommandLine(const ACommandLine: string);
var
  Params: TStringList;
  I: Integer;
  Param: string;
  DebugParam: string;
  ColonPos: Integer;
begin
  FEnabled := False;
  FLogFilePath := '';
  
  // Parse command line into parameters
  Params := TStringList.Create;
  try
    // Simple parameter parsing - split by spaces, handle quoted paths
    Params.DelimitedText := ACommandLine;
    
    for I := 0 to Params.Count - 1 do
    begin
      Param := UpperCase(Trim(Params[I]));
      
      // Check for /DEBUG or /DEBUG:filepath
      if (Param = '/DEBUG') then
      begin
        FEnabled := True;
        FLogFilePath := GetDefaultLogPath;
        Break;
      end
      else if Pos('/DEBUG:', Param) = 1 then
      begin
        FEnabled := True;
        DebugParam := Params[I]; // Use original case for file path
        ColonPos := Pos(':', DebugParam);
        if ColonPos > 0 then
        begin
          FLogFilePath := Trim(Copy(DebugParam, ColonPos + 1, Length(DebugParam)));
          // Remove quotes if present
          if (Length(FLogFilePath) >= 2) and 
             (FLogFilePath[1] = '"') and 
             (FLogFilePath[Length(FLogFilePath)] = '"') then
          begin
            FLogFilePath := Copy(FLogFilePath, 2, Length(FLogFilePath) - 2);
          end;
        end
        else
          FLogFilePath := GetDefaultLogPath;
        Break;
      end;
    end;
  finally
    Params.Free;
  end;
  
  // Validate file path
  if FEnabled and (FLogFilePath = '') then
    FLogFilePath := GetDefaultLogPath;
end;

function TDebugManager.GetDefaultLogPath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'progress_debug.log';
end;

procedure TDebugManager.CreateLogDirectory;
var
  LogDir: string;
begin
  if FLogFilePath = '' then
    Exit;
    
  LogDir := ExtractFilePath(FLogFilePath);
  if LogDir <> '' then
  begin
    try
      ForceDirectories(LogDir);
    except
      // If directory creation fails, fall back to default location
      FLogFilePath := GetDefaultLogPath;
    end;
  end;
end;

procedure TDebugManager.WriteToLog(const AMessage: string);
var
  LogFile: TextFile;
  Timestamp: string;
  FullMessage: string;
begin
  if not FEnabled or (FLogFilePath = '') then
    Exit;
    
  if FMutex <> 0 then
    WaitForSingleObject(FMutex, INFINITE);
    
  try
    try
      AssignFile(LogFile, FLogFilePath);
      
      if FileExists(FLogFilePath) then
        Append(LogFile)
      else
        Rewrite(LogFile);
        
      try
        Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
        FullMessage := Format('[%s] %s', [Timestamp, AMessage]);
        WriteLn(LogFile, FullMessage);
      finally
        CloseFile(LogFile);
      end;
    except
      // Ignore logging errors - don't let debug system crash the application
    end;
  finally
    if FMutex <> 0 then
      ReleaseMutex(FMutex);
  end;
end;

procedure TDebugManager.Log(const AMessage: string);
begin
  if FEnabled then
    WriteToLog(AMessage);
end;

// Global functions

procedure DebugLog(const AMessage: string);
begin
  if Assigned(GDebugManager) then
    GDebugManager.Log(AMessage);
end;

procedure DebugLogFormat(const AFormat: string; const Args: array of const);
begin
  if Assigned(GDebugManager) and GDebugManager.Enabled then
    GDebugManager.Log(Format(AFormat, Args));
end;

procedure InitializeDebugSystem(const ACommandLine: string);
begin
  if not Assigned(GDebugManager) then
    GDebugManager := TDebugManager.Create;
    
  GDebugManager.Initialize(ACommandLine);
end;

procedure FinalizeDebugSystem;
begin
  if Assigned(GDebugManager) then
  begin
    GDebugManager.Free;
    GDebugManager := nil;
  end;
end;

function IsDebugEnabled: Boolean;
begin
  Result := Assigned(GDebugManager) and GDebugManager.Enabled;
end;

initialization
  // Global manager will be created when InitializeDebugSystem is called

finalization
  FinalizeDebugSystem;

end.