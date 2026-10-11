# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Test implements a sophisticated dual-process splash screen system for Delphi applications. The main application (`Test.exe`) launches a separate splash screen process (`SplashScreen.exe`) and communicates via Inter-Process Communication (IPC) using memory-mapped files. The system features two independent adaptive learning systems that automatically calculate progress percentages from timing data, eliminating the need for hardcoded progress values.

## Documentation

- **[SPLASH_SYSTEM.md](SPLASH_SYSTEM.md)** - Complete system documentation covering architecture, usage, learning systems, troubleshooting, and technical specifications
- **[LEARNING_SYSTEM.md](LEARNING_SYSTEM.md)** - Detailed technical documentation of the Adaptive Progress Learning System that automatically learns loading patterns and calculates progress percentages

## Development Commands

### Building the Project

Build both projects (required for full functionality):
```bash
# Build splash screen executable first
delphi-compiler.exe W:\Public\Splash\SplashScreen.dproj

# Build main application
delphi-compiler.exe W:\Public\Splash\Test.dproj
```

### Running the Application
- Main application: `Test.exe` (automatically launches splash screen)
- Splash screen standalone: `SplashScreen.exe /pid:1234` (for testing)

### Debugging and Testing

Enable debug logging by ensuring these files exist:
- `progress_debug.log` - Automatic debug logging
- Learning data: `%APPDATA%\[AppName]\splash_history.json` and `splash_learning.json` (AppName from exe)

Reset learning data (if behavior becomes erratic):
```bash
# Delete learning files to reset adaptive systems
del "%APPDATA%\[YourAppName]\*.json"
```

## Architecture Overview

### Source Layout

Units live flat in `src/` (no subfolders), one manager per responsibility:

```
src/
├── ModernSplash.pas, ModernSplashBase.pas     # Thin form coordinator
├── SplashRenderingManager.pas                 # All visual rendering logic
├── SplashStyleProvider.pas                    # Colors, fonts, constants
├── SplashLayoutCalculator.pas                 # Element positioning
├── SplashLifecycleManager.pas                 # Process lifecycle management
├── SplashIPCManager.pas, IPCShared.pas        # IPC with the main application
├── ProgressLearning.pas, AdaptiveLearning.pas # Learning systems
└── SplashAnimationController.pas, SplashProgressManager.pas, SplashConfig.pas, ...
```

### Dual-Process Architecture

The system consists of two separate executables:

1. **Test.exe** (Main Application)
   - Creates `TIPCManager` to launch and communicate with splash screen
   - Sends status updates via shared memory: `IPCManager.UpdateStatus("Loading...")`
   - Performs actual initialization while splash runs independently
   - Signals splash closure when complete

2. **SplashScreen.exe** (Splash Process)  
   - Launched with parent PID parameter: `/pid:1234`
   - Runs `TIPCMonitor` to read shared memory updates
   - Automatically terminates if parent process dies
   - Handles all UI rendering and animations independently

### Key Components

**IPC System (`IPCShared.pas`)**
- Memory-mapped file communication between processes
- Shared structure: `TSharedProgress` (progress, status text, close signal)
- Mutex synchronization for thread-safe updates

**Learning Systems**
- `ProgressLearning.pas`: Timing-based learning (primary system)
  - Records duration of each status phase
  - Automatically calculates progress percentages from time ratios
  - Stores data in `splash_history.json`
- `AdaptiveLearning.pas`: Progress-based learning (secondary system)
  - Maps status messages to progress values  
  - Handles sequence variations and transitions
  - Stores data in `splash_learning.json`

**UI Components**
- `src/ModernSplash.pas` (+ `ModernSplashBase.pas`): Skia-powered splash form with 60 FPS animations

### Key Technologies

- **Skia for Delphi**: Used for modern graphics rendering with gradients, shadows, and path operations
- **VCL Framework**: Traditional Windows desktop application framework
- **Form Positioning**: Splash screen centered on screen with borderless style

### Critical Implementation Details

**Automatic Progress Calculation**
- System learns timing patterns and automatically calculates progress percentages
- Main app only needs to send status messages: `IPCManager.UpdateStatus("Loading config")`  
- Progress percentages derived from `(Phase Duration / Total Duration) × 100`
- No hardcoded progress values needed

**Animation Timing Fix**
- Animation time increments by actual elapsed time (16ms/frame = 0.016s)
- Dots animations cycle correctly: 1.5s for status dots, 1.4s for loading dots
- Smooth 60 FPS rendering with proper timing

**Two-Stage Animation System**
- **Primary Stage (0-75% of phase time)**: Fast, confident animation to calculated target percentage
  - Formula: `Speed = TargetGap / RemainingTime` 
  - Boost mechanism: Speeds up 2x when `RemainingTime < 0.2s` or `TargetGap > 0.2`
  - Target time: `PrimaryTargetTime = PredictedDuration × 0.75`
  - Goal: Ensure each phase reaches its cumulative target percentage
- **Creep Stage (75-100% of phase time)**: Gentle movement beyond target for seamless transitions
  - Formula: `Speed = CreepSpeed × (1.0 - CurrentOverrun / MaxOverrun)`
  - Controlled overrun: `MaxOverrun = Min(0.05, (1.0 - PredictedEndProgress) × 0.3)`
  - Dynamic gap calculation: Next phase adjusts based on actual current position
  - Goal: Smooth transitions between phases without visual jumps
- **Visual Alignment**: Progress bar allocation matches actual timing data proportionally
- **State Management**: Tracks target reached vs creep mode with ratchet mechanism (never backward)
- **Performance**: 60 FPS smooth updates with Skia graphics hardware acceleration

**Process Lifecycle**
- Splash screen auto-terminates if parent process dies unexpectedly
- Learning data persists in `%APPDATA%\[AppName]\` directory (AppName from exe filename)
- Each execution improves future progress predictions

**Data Storage**
- JSON format learning files with automatic percentage recalculation
- Timing history: phase durations, averages, standard deviations
- Progress mapping: status sequences, transitions, confidence scores