unit SplashConfig;

interface

uses
  System.SysUtils, Winapi.Windows, DebugManager, SplashLocalization;

type
  TSplashConfiguration = record
    AppName: string;
    Version: string; 
    SubVersion: string;
    LoadingCaption: string;
    LearningIndicator: string;  // Text shown when learning system is active
    IsBeta: Boolean;
    StartingStatus: string;
    LogoFile: string;
    
    // Factory method
    class function CreateDefault: TSplashConfiguration; static;
    
    // Parameter parsing
    class function ParseFromCommandLine(const ACommandLine: string): TSplashConfiguration; static;
    class procedure ParseVersionString(const AVersionStr: string; out AVersion: string; out ASubVersion: string); static;
    
    // Helper methods
    function GetFullVersion: string;
    function GetVersionText: string;
  end;

// Get application identifier for data storage and mutex names
// Returns configured AppName if set, otherwise uses exe filename
function GetAppIdentifier: string;

implementation

{ TSplashConfiguration }

class function TSplashConfiguration.CreateDefault: TSplashConfiguration;
begin
  Result.AppName := '';  // Empty = use exe name
  Result.Version := '1';
  Result.SubVersion := '.0';
  Result.LoadingCaption := GetLocalizedLoadingCaption;     // Localized default
  Result.LearningIndicator := GetLocalizedLearningIndicator; // Localized default
  Result.IsBeta := True;  // Keeping current default behavior
  Result.StartingStatus := GetLocalizedStartingStatus;      // Localized default
  Result.LogoFile := '';  // Empty means use embedded logo
end;

class function TSplashConfiguration.ParseFromCommandLine(const ACommandLine: string): TSplashConfiguration;
var
  Params: TArray<string>;
  I: Integer;
  Param: string;
  ColonPos: Integer;
  ParamName, ParamValue: string;
begin
  // Start with default values
  Result := CreateDefault;
  
  DebugLogFormat('ParseFromCommandLine: Parsing "%s"', [ACommandLine]);
  
  // Split command line into parameters (simple space-based splitting)
  Params := ACommandLine.Split([' ']);
  
  for I := 0 to High(Params) do
  begin
    Param := Trim(Params[I]);
    
    // Skip non-parameter arguments or empty strings
    if (Param = '') or (Param[1] <> '/') then
      Continue;
      
    // Handle parameters with values (/PARAM:VALUE)
    ColonPos := Pos(':', Param);
    if ColonPos > 0 then
    begin
      ParamName := UpperCase(Copy(Param, 1, ColonPos));
      ParamValue := Copy(Param, ColonPos + 1, Length(Param)); // Skip ':' 
      
      // Remove quotes if present
      if (Length(ParamValue) >= 2) and 
         (ParamValue[1] = '"') and 
         (ParamValue[Length(ParamValue)] = '"') then
      begin
        ParamValue := Copy(ParamValue, 2, Length(ParamValue) - 2);
      end;
      
      if ParamName = '/APP:' then
      begin
        Result.AppName := ParamValue;
        DebugLogFormat('Parsed APP: "%s"', [ParamValue]);
      end
      else if ParamName = '/VER:' then
      begin
        ParseVersionString(ParamValue, Result.Version, Result.SubVersion);
        DebugLogFormat('Parsed VER: "%s" -> Version="%s", SubVersion="%s"', 
          [ParamValue, Result.Version, Result.SubVersion]);
      end
      else if ParamName = '/LOAD:' then
      begin
        Result.LoadingCaption := ParamValue;
        DebugLogFormat('Parsed LOAD: "%s"', [ParamValue]);
      end
      else if ParamName = '/LEARN:' then
      begin
        Result.LearningIndicator := ParamValue;
        DebugLogFormat('Parsed LEARN: "%s"', [ParamValue]);
      end
      else if ParamName = '/START:' then
      begin
        Result.StartingStatus := ParamValue;
        DebugLogFormat('Parsed START: "%s"', [ParamValue]);
      end
      else if ParamName = '/LOGO:' then
      begin
        Result.LogoFile := ParamValue;
        DebugLogFormat('Parsed LOGO: "%s"', [ParamValue]);
      end;
    end
    else
    begin
      // Handle flag parameters (no values)
      if UpperCase(Param) = '/BETA' then
      begin
        Result.IsBeta := True;
        DebugLog('Parsed BETA: true');
      end;
    end;
  end;
  
  DebugLogFormat('Final config - App: "%s", Version: "%s%s", Loading: "%s", Learn: "%s", Beta: %s, Start: "%s", Logo: "%s"',
    [Result.AppName, Result.Version, Result.SubVersion, Result.LoadingCaption, 
     Result.LearningIndicator, BoolToStr(Result.IsBeta, True), Result.StartingStatus, Result.LogoFile]);
end;

class procedure TSplashConfiguration.ParseVersionString(const AVersionStr: string; 
  out AVersion: string; out ASubVersion: string);
var
  DotPos: Integer;
begin
  // Parse version string like "11.22xxx" into Version="11" and SubVersion=".22xxx"
  DotPos := Pos('.', AVersionStr);
  if DotPos > 0 then
  begin
    AVersion := Copy(AVersionStr, 1, DotPos - 1);  // Before the dot
    ASubVersion := Copy(AVersionStr, DotPos, Length(AVersionStr)); // From the dot onwards
  end
  else
  begin
    // No dot found, entire string is the version
    AVersion := AVersionStr;
    ASubVersion := '';
  end;
end;

function TSplashConfiguration.GetFullVersion: string;
begin
  Result := Version + SubVersion;
end;

function TSplashConfiguration.GetVersionText: string;
begin
  Result := 'v' + GetFullVersion;
end;

function GetAppIdentifier: string;
var
  ExeName: string;
  GlobalConfig: TSplashConfiguration;
begin
  // Get global config - note we can't directly access a global variable here
  // so we parse from command line to get the /APP: parameter if present
  GlobalConfig := TSplashConfiguration.ParseFromCommandLine(GetCommandLine);
  
  // Use configured AppName if explicitly set
  if GlobalConfig.AppName <> '' then
    Result := GlobalConfig.AppName
  else
  begin
    // Use exe name without extension as default
    ExeName := ExtractFileName(ParamStr(0));
    Result := ChangeFileExt(ExeName, '');
    if Result = '' then
      Result := 'Application'; // Fallback if something goes wrong
  end;
end;

end.