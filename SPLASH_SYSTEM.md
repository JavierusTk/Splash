# Test Splash Screen System

## Short Description

The Test Splash Screen is a sophisticated dual-process loading screen system for Delphi applications that features automatic progress calculation, adaptive learning, and smooth animations. It uses Inter-Process Communication (IPC) to display loading progress in a separate process, ensuring the UI remains responsive even during heavy initialization. The system automatically learns typical loading patterns and calculates progress percentages from timing data, eliminating the need for hardcoded progress values.

---

## Full Documentation

## Overview

The Test Splash Screen is an advanced loading screen system designed for Delphi VCL applications. It provides a modern, responsive user experience during application initialization through a unique dual-process architecture with adaptive learning capabilities.

### Key Features

- **Dual-Process Architecture**: Splash screen runs in a separate process, ensuring smooth animations even during blocking operations
- **Automatic Progress Calculation**: Learns from execution patterns and automatically calculates progress percentages
- **Adaptive Learning**: Two independent learning systems that improve accuracy over time
- **Modern UI**: Skia-powered graphics with gradients, shadows, and smooth animations
- **Zero Configuration**: Works out-of-the-box without predefined progress values
- **IPC Communication**: Robust inter-process communication using memory-mapped files
- **Self-Terminating**: Automatically closes if parent process dies unexpectedly

## Architecture

### System Components

```
┌─────────────────────────────────────┐
│       Test.exe (Main App)           │
│  ┌────────────────────────────┐     │
│  │      TIPCManager           │     │
│  │  - LaunchSplashScreen()    │     │
│  │  - UpdateStatus()          │     │
│  │  - UpdateProgress()        │     │
│  └──────────┬─────────────────┘     │
└─────────────┼───────────────────────┘
              │ Memory-Mapped File
              ▼
┌─────────────────────────────────────┐
│   SplashScreen.exe (Separate)       │
│  ┌────────────────────────────┐     │
│  │    TfrmModernSplash        │     │
│  │  - TIPCMonitor             │     │
│  │  - TProgressHistory        │     │
│  │  - TStatusProgressMapper   │     │
│  │  - Skia Rendering          │     │
│  └────────────────────────────┘     │
└─────────────────────────────────────┘
```

### Data Flow

1. **Main Application** starts and creates TIPCManager
2. **TIPCManager** launches SplashScreen.exe with parent PID
3. **SplashScreen.exe** creates shared memory mapping
4. **Main Application** sends status updates via shared memory
5. **SplashScreen** reads updates and calculates progress
6. **Learning Systems** analyze patterns and save data
7. **Main Application** signals completion
8. **SplashScreen** closes gracefully

## Learning Systems

### 1. ProgressHistory (Timing-Based)

Located in `ProgressLearning.pas`, this system tracks execution timing:

- **Records**: Duration of each status phase
- **Calculates**: Average duration and standard deviation
- **Predicts**: Expected time for each phase
- **Auto-Calculates**: Progress percentages from time ratios

**Data Storage**: `%APPDATA%\[AppName]\splash_history.json` (AppName is determined from exe filename)

```json
{
  "totalDuration": 6008,
  "phases": [{
    "name": "Inicializando sistema",
    "progress": 8,  // Automatically calculated: 484/6008 = 8%
    "averageDuration": 484,
    "durations": [484]
  }]
}
```

### 2. AdaptiveLearning (Progress-Based)

Located in `AdaptiveLearning.pas`, this system maps statuses to progress values:

- **Learns**: Status sequences and transitions
- **Tracks**: Progress values for each status
- **Handles**: Variations in initialization order
- **Confidence**: Statistical confidence scoring

**Data Storage**: `%APPDATA%\[AppName]\splash_learning.json` (AppName is determined from exe filename)

### Automatic Percentage Calculation

The system automatically calculates progress percentages based on timing ratios:

```
Phase Progress % = (Phase Duration / Total Duration) × 100
```

This eliminates the need for hardcoded progress values. The main application only needs to send status messages:

```pascal
// Instead of:
IPCManager.UpdateProgress(30, 'Loading configuration');

// You can simply use:
IPCManager.UpdateStatus('Loading configuration');
// Progress is automatically calculated as 30% based on learned timing
```

## Usage Guide

### Basic Integration

1. **Main Application** (`Test.dpr`):

```pascal
var
  IPCManager: TIPCManager;
begin
  // Create IPC manager and launch splash
  IPCManager := TIPCManager.Create;
  IPCManager.LaunchSplashScreen;
  
  // Send status updates during initialization
  IPCManager.UpdateStatus('Initializing system');
  // ... perform initialization ...
  
  IPCManager.UpdateStatus('Loading configuration');
  // ... load config ...
  
  IPCManager.UpdateStatus('Ready');
  
  // Close splash when done
  IPCManager.CloseSplash;
  IPCManager.Free;
end;
```

2. **Splash Screen** automatically:
   - Displays status messages
   - Calculates progress from learned patterns
   - Shows smooth animations
   - Saves learning data for next run

### Advanced Features

#### Mixed Mode Updates

You can mix status-only and explicit progress updates:

```pascal
IPCManager.UpdateStatus('Starting');           // Auto-calculated
IPCManager.UpdateProgress(50, 'Half way');     // Explicit 50%
IPCManager.UpdateStatus('Finishing');          // Auto-calculated
```

#### Custom Status Messages

Any status text is automatically learned:

```pascal
IPCManager.UpdateStatus('Loading customer database');
IPCManager.UpdateStatus('Connecting to server');
IPCManager.UpdateStatus('Synchronizing data');
```

## Animation System

### Two-Stage Progress Animation

The splash screen uses a sophisticated two-stage animation system for optimal visual-timing alignment:

#### Stage 1: Primary Animation (0-75% of phase time)
- **Fast Progress**: Quickly animates to calculated target percentage
- **Target Time**: Reaches target in 75% of predicted phase duration  
- **Speed Calculation**: `Speed = TargetGap / RemainingTime`
- **Boost Mechanism**: Speeds up 2x when running out of time or significantly behind
- **Goal**: Ensure each phase reaches its cumulative target percentage

#### Stage 2: Creep Animation (75-100% of phase time)
- **Slow Progress**: Gentle movement beyond target percentage
- **Controlled Overrun**: Maximum 5% overrun or 30% of remaining progress
- **Adaptive Speed**: `Speed = CreepSpeed × (1.0 - Overrun/MaxOverrun)`
- **Dynamic Transition**: Next phase adjusts based on actual current position
- **Goal**: Smooth transitions between phases without visual jumps

### Technical Features

- **60 FPS Updates**: Smooth visual transitions at high frame rate
- **State Tracking**: Monitors target reached vs creep mode
- **Ratchet Mechanism**: Progress never goes backward
- **Visual Alignment**: Progress bar allocation matches timing data proportionally
- **Gap Calculation**: Dynamically calculates remaining distance to target

### Visual Components

- **Progress Bar**: Gradient-filled with two-stage smooth animations
- **Status Text**: Updates with current operation
- **Logo**: Skia-rendered C-shaped design with star
- **Background**: Animated gradient effects

## File Structure

```
splash/
├── Core Components
│   ├── SplashScreen.dpr          # Splash screen executable entry
│   ├── ModernSplashForm.pas/dfm  # Main splash UI and logic
│   ├── Test.dpr                 # Main application entry
│   └── MainForm.pas/dfm          # Main application form
│
├── IPC System
│   └── IPCShared.pas             # Inter-process communication
│
├── Learning Systems
│   ├── ProgressLearning.pas      # Timing-based learning
│   └── AdaptiveLearning.pas      # Progress-based learning
│
├── Data Files (Runtime)
│   ├── %APPDATA%/[AppName]/
│   │   ├── splash_history.json   # Timing history
│   │   └── splash_learning.json  # Progress mappings
│   └── Win32/Debug/
│       └── progress_debug.log    # Debug logging
│
└── Resources
    ├── modern-splash-screen.html # HTML/CSS prototype
    └── *.png                     # Logo and screenshots
```

## Configuration

### Build Settings

The project uses specific compiler settings:

- **DCU Output**: `.\$(Platform)\$(Config)`
- **EXE Output**: `.\$(Platform)\$(Config)`
- **Platforms**: Win32 and Win64 supported

### Compilation

To compile the project:

```bash
# Compile splash screen
compilar SplashScreen.dproj

# Compile main application
compilar Test.dproj
```

### Runtime Configuration

No configuration files needed. The system self-configures through learning.

### Optional Debug Mode

Enable debug logging by creating `progress_debug.log`:

```pascal
// Automatically logs when file exists
// Located in: Win32\Debug\progress_debug.log
```

## Troubleshooting

### Common Issues

#### Splash Screen Doesn't Appear
- **Cause**: IPC initialization failed
- **Solution**: Check if antivirus is blocking process creation

#### Progress Jumps Erratically
- **Cause**: Learning data corruption or major app changes
- **Solution**: Delete `%APPDATA%\[AppName]\*.json` files to reset (AppName matches your exe name)

#### Splash Closes Immediately
- **Cause**: Parent process PID not provided or invalid
- **Solution**: Ensure LaunchSplashScreen is called properly

#### Progress Bar Stuck
- **Cause**: Main app not sending updates
- **Solution**: Add more UpdateStatus calls during initialization

### Debug Techniques

1. **Check Debug Log**: `Win32\Debug\progress_debug.log`
2. **Verify JSON Files**: Check learning data in AppData
3. **Use OutputDebugString**: Monitor real-time execution
4. **Test Standalone**: Run `SplashScreen.exe /pid:1234` manually

## Performance Characteristics

### Memory Usage
- **Splash Process**: ~15-20 MB
- **Shared Memory**: 1 KB
- **Learning Data**: ~10 KB JSON files

### CPU Usage
- **Animation**: <1% CPU at 60 FPS
- **Learning Calculations**: <1ms per update
- **IPC Overhead**: Negligible

### Timing
- **Splash Launch**: ~100-200ms
- **First Paint**: ~50ms after launch
- **Update Latency**: <1ms via shared memory
- **Close Time**: ~100ms fade out

## Technical Specifications

### IPC Protocol

Shared memory structure:
```pascal
TSharedProgress = packed record
  Progress: Integer;                    // 0-100
  StatusText: array[0..255] of WideChar; // Unicode status
  ShouldClose: Boolean;                  // Close signal
  UpdateFlag: Integer;                   // Update counter
end;
```

### Learning Data Format

Progress percentages are automatically calculated and stored:
```json
{
  "phases": [{
    "name": "Status Text",
    "progress": 25,        // Auto-calculated from timing
    "averageDuration": 1500,
    "standardDeviation": 120
  }]
}
```

### Animation Timing

- **Main Timer**: 50ms interval for IPC checks and lifecycle
- **Animation Timer**: 16ms interval (~60 FPS) for smooth animations
- **Dots Animation**: 1.5s cycle for status dots, 1.4s for loading dots
- **Beta Shimmer**: 3s cycle for badge effect
- **Progress Smoothing**: Dynamic speed based on target distance

Progress animation uses a two-stage approach with different speed calculations:

#### Primary Stage (0-75% of phase time):
```
Speed = TargetGap / RemainingTime
Boost = Speed × 2.0 (when RemainingTime < 0.2s or TargetGap > 0.2)
PrimaryTargetTime = PredictedDuration × 0.75
```

#### Creep Stage (75-100% of phase time):
```
MaxOverrun = Min(0.05, (1.0 - PredictedEndProgress) × 0.3)
CurrentOverrun = DisplayProgress - PredictedEndProgress  
Speed = CreepSpeed × (1.0 - CurrentOverrun / MaxOverrun)
```

#### Gap Calculation:
```
TargetGap = PredictedEndProgress - DisplayProgress
RemainingTime = Max(0.1, PrimaryTargetTime - PhaseElapsed)
```

## Best Practices

1. **Send Regular Updates**: Update status at least every 2 seconds
2. **Use Descriptive Messages**: Help users understand what's loading
3. **Avoid Duplicate Messages**: Each status should represent unique work
4. **Let Learning Adapt**: Don't hardcode progress unless necessary
5. **Handle Failures Gracefully**: Always call CloseSplash in finally blocks

## Implementation Examples

### Simple Application

```pascal
program SimpleApp;

uses
  IPCShared;

var
  IPC: TIPCManager;
begin
  IPC := TIPCManager.Create;
  try
    IPC.LaunchSplashScreen;
    
    IPC.UpdateStatus('Loading database');
    LoadDatabase;
    
    IPC.UpdateStatus('Initializing modules');
    InitModules;
    
    IPC.UpdateStatus('Ready');
    Sleep(500);
    
    IPC.CloseSplash;
  finally
    IPC.Free;
  end;
end;
```

### With Error Handling

```pascal
procedure InitializeWithSplash;
var
  IPC: TIPCManager;
begin
  IPC := TIPCManager.Create;
  try
    if IPC.LaunchSplashScreen then
    begin
      try
        IPC.UpdateStatus('Starting initialization');
        PerformInitialization;
        IPC.UpdateStatus('Complete');
      except
        on E: Exception do
        begin
          IPC.UpdateStatus('Error: ' + E.Message);
          Sleep(2000);
          raise;
        end;
      end;
    end
    else
    begin
      // Fallback: Initialize without splash
      PerformInitialization;
    end;
  finally
    IPC.CloseSplash;
    IPC.Free;
  end;
end;
```

## Features Summary

- Automatic percentage calculation from timing data
- Dual learning systems for adaptive progress
- IPC architecture for process separation

## License and Credits

Developed using:
- Delphi VCL Framework
- Skia4Delphi for graphics rendering
- Windows IPC mechanisms

---

*This documentation describes the complete Splash Screen system. For specific learning system details, see `LEARNING_SYSTEM.md`. For project overview, see `CLAUDE.md`.*