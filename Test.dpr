program Test;

// =============================================================================
// MAIN APPLICATION WITH IPC-BASED SPLASH SCREEN
// =============================================================================

uses
  Vcl.Forms,
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  IPCShared in 'src\IPCShared.pas',
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

var
  IPCManager: TIPCManager;

procedure SimulateInitialization;
var
  UseStatusOnly: Boolean;
begin
  // Randomly decide whether to use status-only or progress+status
  // This simulates real-world variation where sometimes you know progress,
  // sometimes you don't
  Randomize;
  UseStatusOnly := TRUE; //Random(2) = 0;

  // Simulate unit initialization with progress updates
  // Sleep times are proportional to progress increments (50ms per 1%)

  // Initialize system (0% -> 10% = 10% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Inicializando sistema')
    else
      IPCManager.UpdateProgress(10, 'Inicializando sistema');
  end;
  Sleep(500); // 10% * 50ms = 500ms

  // Load configuration (10% -> 30% = 20% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Cargando configuración')
    else
      IPCManager.UpdateProgress(30, 'Cargando configuración');
  end;
  Sleep(1000); // 20% * 50ms = 1000ms

  // Sometimes add an extra step (simulating variation)
//  if Random(3) = 0 then
  begin
    if IPCManager <> nil then
      IPCManager.UpdateStatus('Verificando licencias');
    Sleep(300); // Extra step, doesn't affect main progress
  end;

  // Load databases (30% -> 45% = 15% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Loading Logistics DB')  // New status text
    else
      IPCManager.UpdateProgress(45, 'Loading Logistics DB');
  end;
  Sleep(750); // 15% * 50ms = 750ms

  // Register customers (45% -> 55% = 10% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Registering Customers')
    else
      IPCManager.UpdateProgress(55, 'Registering Customers');
  end;
  Sleep(500); // 10% * 50ms = 500ms

  // Sometimes skip a step (simulating conditional initialization)
//  if Random(4) > 0 then  // 75% chance to include this step
  begin
    // Load modules (55% -> 70% = 15% progress)
    if IPCManager <> nil then
    begin
      if UseStatusOnly then
        IPCManager.UpdateStatus('Cargando módulos')
      else
        IPCManager.UpdateProgress(70, 'Cargando módulos');
    end;
    Sleep(750); // 15% * 50ms = 750ms
  end;

  // Prepare interface (70% -> 90% = 20% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Preparando interfaz')
    else
      IPCManager.UpdateProgress(90, 'Preparando interfaz');
  end;
  Sleep(1000); // 20% * 50ms = 1000ms

  // Ready (90% -> 100% = 10% progress)
  if IPCManager <> nil then
  begin
    if UseStatusOnly then
      IPCManager.UpdateStatus('Listo')
    else
      IPCManager.UpdateProgress(100, 'Listo');
  end;
  Sleep(500); // 10% * 50ms = 500ms
end;

begin
  IPCManager := nil;

  try
    // Create IPC manager and launch splash screen BEFORE any initialization
    try
      IPCManager := TIPCManager.Create;
      if not IPCManager.LaunchSplashScreen then
      begin
        // Log or handle splash screen launch failure
        WriteLn('Warning: Could not launch splash screen');
      end;

      // Give splash screen time to initialize
      Sleep(200);
    except
      // If IPC fails, continue without splash
      FreeAndNil(IPCManager);
    end;

    // NOW the unit initialization happens here automatically
    // During this time, the splash screen animations continue running
    // in its separate process

    // Simulate the initialization process that would normally block
    SimulateInitialization;

    Application.Initialize;
    Application.MainFormOnTaskbar := True;

    // Create main form
    Application.CreateForm(TfrmMain, frmMain);

    // Signal splash to close
    if IPCManager <> nil then
    begin
      Sleep(1000); // Let user see the "Listo" message
      IPCManager.CloseSplash;
    end;

    // Run the main application
    Application.Run;

  finally
    FreeAndNil(IPCManager);
  end;
end.

