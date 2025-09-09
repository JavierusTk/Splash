# Splash Screen System for Delphi

A sophisticated dual-process splash screen system for Delphi applications featuring automatic progress calculation through adaptive learning algorithms.

![Delphi](https://img.shields.io/badge/Delphi-RAD%20Studio%2012-red)
![Platform](https://img.shields.io/badge/Platform-Windows-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **🚀 Dual-Process Architecture**: Splash screen runs in a separate process, ensuring smooth 60 FPS animations even during blocking operations
- **🧠 Adaptive Learning**: Automatically learns loading patterns and calculates progress percentages from timing data
- **✨ Modern UI**: Skia-powered graphics with gradients, shadows, and smooth animations
- **📊 Zero Configuration**: Works out-of-the-box without predefined progress values
- **🔄 Self-Improving**: Becomes more accurate with each application run
- **💾 Persistent Learning**: Stores learning data between sessions for consistent user experience
- **🛡️ Robust IPC**: Inter-process communication using memory-mapped files with mutex synchronization
- **🎯 Auto-Termination**: Splash screen automatically closes if parent process dies unexpectedly

## Screenshots

The splash screen features a modern design with:
- Gradient logo and text
- Smooth progress bar animations
- Dynamic status messages
- Optional beta badge

## Requirements

- RAD Studio 12 (Delphi 29.0) or later
- Windows 7 or later
- [Skia for Delphi](https://github.com/skia4delphi/skia4delphi) (for graphics rendering)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/JavierusTk/splash-screen-delphi.git
cd splash-screen-delphi
```

2. Open `SplashGroup.groupproj` in RAD Studio

3. Install Skia for Delphi from GetIt Package Manager if not already installed

4. Build both projects:
   - First build `SplashScreen.dproj` (the splash screen executable)
   - Then build `Test.dproj` or `TestAuto.dproj` (the main applications)

## Usage

### Method 1: Auto-Start (Simplest) 🚀

Just add `AutoSplash` to your uses clause and the splash screen starts automatically:

```pascal
program MyApp;

uses
  AutoSplash,  // ← Just add this! Splash starts automatically
  Forms,
  MainForm;

begin
  Application.Initialize;
  
  // Update splash status anywhere in your code
  Splash.UpdateStatus('Loading database...');
  // ... your initialization code ...
  
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
  // Splash closes automatically
end.
```

#### With Configuration

Create a configuration unit (e.g., `MyAppConfig.pas`):
```pascal
unit MyAppConfig;
interface
implementation
uses AutoSplashConfig;
initialization
  Config.AppName := 'My Application';
  Config.Version := '2.0';
  Config.ShowBeta := False;
end.
```

Then in your main program:
```pascal
uses
  MyAppConfig,  // Your config (must be first!)
  AutoSplash,   // Reads Config during initialization
  Forms;
```

Note: Config changes in the main program have no effect since AutoSplash reads the configuration during unit initialization.

### Method 2: Manual Control (Traditional)

1. Copy the `src/IPCShared.pas` unit to your project
2. Add IPC manager initialization to your main application:

```pascal
uses
  IPCShared;

var
  IPCManager: TIPCManager;

begin
  // Create IPC manager and launch splash screen
  IPCManager := TIPCManager.Create;
  try
    IPCManager.LaunchSplashScreen;
    
    // Your initialization code here
    IPCManager.UpdateStatus('Loading configuration');
    // ... more initialization ...
    
    IPCManager.UpdateStatus('Loading modules');
    // ... more initialization ...
    
    // Close splash when ready
    IPCManager.CloseSplash;
    
    // Start your main application
    Application.Run;
  finally
    IPCManager.Free;
  end;
end.
```

### Command Line Parameters

The splash screen executable supports several command line parameters:

```bash
SplashScreen.exe /pid:1234 [options]
```

**Required:**
- `/pid:xxxxx` - Parent process ID (required for auto-termination)

**Optional:**
- `/APP:name` - Application name (default: exe filename without extension)
- `/VER:version` - Version string (default: "1.0")
- `/LOAD:text` - Loading caption (default: "Loading")
- `/START:text` - Starting status message
- `/BETA` - Show beta badge
- `/LOGO:path` - Path to custom logo file
- `/DEBUG` - Enable debug logging to `progress_debug.log`
- `/DEBUG:filepath` - Enable debug logging to custom file

### Advanced Features

#### Status Updates Only (Recommended)
Let the system automatically calculate progress:

```pascal
IPCManager.UpdateStatus('Initializing database');
IPCManager.UpdateStatus('Loading user preferences');
IPCManager.UpdateStatus('Preparing interface');
```

#### Manual Progress Control
Optionally provide explicit progress values:

```pascal
IPCManager.UpdateProgress(25, 'Loading configuration');
IPCManager.UpdateProgress(50, 'Connecting to database');
IPCManager.UpdateProgress(75, 'Loading modules');
```

## Architecture

### Clean Architecture (After Refactoring)

The system follows the Single Responsibility Principle with specialized managers:

- **TfrmModernSplash**: Thin form coordinator (~250 lines)
- **SplashRenderingManager**: All visual rendering logic
- **SplashStyleProvider**: Colors, fonts, and visual constants
- **SplashLayoutCalculator**: Element positioning and layout
- **SplashLifecycleManager**: Process lifecycle management
- **SplashAnimationController**: Animation timing and interpolation
- **SplashProgressManager**: Progress tracking and learning coordination

## How It Works

### Adaptive Learning System

The splash screen implements two learning systems that work together:

1. **Timing-Based Learning** (`ProgressLearning.pas`)
   - Records duration of each loading phase
   - Calculates average durations and standard deviations
   - Automatically assigns progress percentages based on time ratios
   - Formula: `Progress% = (PhaseDuration / TotalDuration) × 100`

2. **Progress-Based Learning** (`AdaptiveLearning.pas`)
   - Maps status messages to progress values
   - Learns typical sequences and transitions
   - Handles variations in loading order
   - Provides statistical confidence scoring

### Data Persistence

Learning data is stored in JSON format. The storage location is automatically determined by the executable name:
- `%APPDATA%\[YourAppName]\splash_history.json` - Timing history
- `%APPDATA%\[YourAppName]\splash_learning.json` - Progress mappings

For example:
- `MyApp.exe` stores data in `%APPDATA%\MyApp\`
- `Test.exe` stores data in `%APPDATA%\Test\`

### Animation System

The progress bar uses a two-stage animation system:

1. **Primary Stage (0-75% of phase time)**: Fast movement to reach target percentage
2. **Creep Stage (75-100% of phase time)**: Gentle movement for smooth transitions

This ensures each phase visually reaches its target while maintaining fluid transitions between phases.

## Project Structure

```
splash-screen-delphi/
├── src/                      # Source files
│   ├── IPCShared.pas        # Inter-process communication
│   ├── AutoSplash.pas       # Auto-start splash unit (NEW!)
│   ├── AutoSplashConfig.pas # Auto-splash configuration (NEW!)
│   ├── ModernSplashForm.pas # Splash screen UI
│   ├── ProgressLearning.pas # Timing-based learning
│   ├── AdaptiveLearning.pas # Progress-based learning
│   ├── DebugManager.pas     # Debug logging system
│   └── SplashConfig.pas     # Configuration management
├── Test.dpr                 # Manual control example
├── TestAuto.dpr             # Auto-start example (NEW!)
├── SplashScreen.dpr         # Splash screen project
├── SplashGroup.groupproj    # Group project file
├── SPLASH_SYSTEM.md         # Detailed system documentation
├── LEARNING_SYSTEM.md       # Learning system documentation
└── README.md                # This file
```

## Debugging

Enable debug logging to troubleshoot issues:

1. Run with debug flag: `YourApp.exe` (splash will inherit debug mode)
2. Check `progress_debug.log` in the application directory
3. Review learning data in `%APPDATA%\[YourAppName]\*.json`

To reset learning data (replace `YourAppName` with your exe name):
```batch
del "%APPDATA%\YourAppName\*.json"
```

Example for Test.exe:
```batch
del "%APPDATA%\Test\*.json"
```

## Documentation

- [SPLASH_SYSTEM.md](SPLASH_SYSTEM.md) - Complete system architecture and technical details
- [LEARNING_SYSTEM.md](LEARNING_SYSTEM.md) - Deep dive into the adaptive learning algorithms

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Skia for Delphi](https://github.com/skia4delphi/skia4delphi) for modern graphics rendering
- Inspired by modern application loading screens with intelligent progress tracking

## Support

For issues, questions, or suggestions, please [open an issue](https://github.com/JavierusTk/splash-screen-delphi/issues) on GitHub.