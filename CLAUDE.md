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
compilar SplashScreen

# Build main application
compilar Test
```

Build using group project (builds both automatically):
```bash
# Note: Group project may not work with compilar command
# Build individually instead as shown above
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

### Current Architecture (After Refactoring)

The system now follows the Single Responsibility Principle with specialized managers:

```
src/
├── Core/
│   └── ModernSplash.pas         # Thin form coordinator (~250 lines)
├── Rendering/
│   ├── SplashRenderingManager.pas   # All visual rendering logic
│   ├── SplashStyleProvider.pas      # Colors, fonts, constants
│   └── SplashLayoutCalculator.pas   # Element positioning
├── Lifecycle/
│   └── SplashLifecycleManager.pas   # Process lifecycle management
└── [Other components...]
```

Each manager has a single, well-defined responsibility, making the code more maintainable and testable.

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
- `ModernSplashForm.pas`: Skia-powered splash screen with 60 FPS animations
- `modern-splash-screen.html`: HTML/CSS design prototype and reference

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

## HTML Prototype Details

The `modern-splash-screen.html` file serves as a design reference and includes:

### Visual Design Elements
- **Logo**: C-shaped design with star accent, matching the Delphi implementation
- **Typography**: "CYBERMAX" in purple gradient, "25" in orange gradient
- **Progress Bar**: Animated gradient from purple to orange
- **Loading States**: Dynamic status text with animated dots
- **Beta Badge**: Optional badge with shimmer effect

### Technical Features
- **Responsive Design**: Adapts to mobile screens (breakpoint at 640px)
- **Dark Mode**: Full dark theme support with toggle button
- **CSS Animations**: Pure CSS for all animations (no JavaScript required)
- **Production Mode**: Add `class="production"` to body element to hide beta elements

### Loading Status Messages
The prototype demonstrates the same loading sequence as the Delphi version:
1. "Inicializando sistema" (10%)
2. "Cargando configuración" (30%)
3. "Proyectos Cargando bases de datos" (50%)
4. "Cargando módulos" (70%)
5. "Preparando interfaz" (90%)
6. "Listo" (100%)

### Implementation Notes
- Uses CSS custom properties for easy theming
- Gradient animations use CSS transforms for performance
- Loading dots are absolutely positioned to prevent text shifting
- Progress bar can be controlled via JavaScript by setting width style