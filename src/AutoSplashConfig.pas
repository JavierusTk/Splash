unit AutoSplashConfig;

// =============================================================================
// AUTO-SPLASH CONFIGURATION UNIT
// =============================================================================
// This unit provides configuration options for the AutoSplash unit.
// You can modify these settings before the AutoSplash unit is loaded.
//
// Usage:
//   Note: Configuration is read when AutoSplash initializes, so Config changes
//   in the main program have no effect. To customize, create a separate unit:
//
//   unit MyAppConfig;
//   interface
//   implementation
//   uses AutoSplashConfig;
//   initialization
//     Config.AppName := 'My Application';
//     Config.Version := '2.0';
//     Config.ShowBeta := False;
//   end.
//
//   Then in your main program:
//   uses
//     MyAppConfig,     // Your config (must be first!)
//     AutoSplash,      // This reads Config during initialization
//     ...
//
// =============================================================================

interface

type
  TAutoSplashConfig = record
    // Application display name
    AppName: string;
    
    // Version string (e.g., '1.0', '2.5.1')
    Version: string;
    
    // Loading caption text
    LoadingCaption: string;
    
    // Learning indicator text (shown during adaptive learning)
    LearningIndicator: string;
    
    // Initial status message
    StartingStatus: string;
    
    // Show beta badge
    ShowBeta: Boolean;
    
    // Path to custom logo file (SVG, PNG, etc.)
    LogoFile: string;
    
    // Enable debug logging
    EnableDebug: Boolean;
    
    // Custom debug log file path (empty = default)
    DebugLogFile: string;
    
    // Minimum time to display splash (milliseconds)
    MinimumDisplayTime: Integer;
    
    // Class method to reset to defaults
    class function CreateDefault: TAutoSplashConfig; static;
  end;

var
  // Global configuration instance
  Config: TAutoSplashConfig;

implementation

{ TAutoSplashConfig }

class function TAutoSplashConfig.CreateDefault: TAutoSplashConfig;
begin
  Result.AppName := '';  // Will use default from SplashConfig
  Result.Version := '';  // Will use default from SplashConfig
  Result.LoadingCaption := '';  // Will use default
  Result.LearningIndicator := '';  // Will use default from SplashConfig
  Result.StartingStatus := '';  // Will use default
  Result.ShowBeta := False;  // Default to production mode
  Result.LogoFile := '';  // Use embedded logo
  Result.EnableDebug := False;  // No debug by default
  Result.DebugLogFile := '';  // Use default debug file
  Result.MinimumDisplayTime := 1000;  // 1 second minimum
end;

initialization
  // Initialize with default values
  Config := TAutoSplashConfig.CreateDefault;

end.