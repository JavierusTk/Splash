program TestAuto;

// =============================================================================
// TEST APPLICATION WITH AUTO-START SPLASH SCREEN
// =============================================================================
// This demonstrates the simplest way to use the splash screen system.
// Just add AutoSplash to the uses clause and the splash appears automatically!
// =============================================================================

uses
  // Optional: Configure the splash before loading it
  AutoSplashConfig in 'src\AutoSplashConfig.pas',
  AutoSplash in 'src\AutoSplash.pas',  // ← Just add this line! Splash starts automatically here
  
  // Standard units
  Vcl.Forms,
  System.SysUtils,
  
  // Application forms
  MainForm in 'MainForm.pas' {frmMain},
  
  // Required units for AutoSplash
  IPCShared in 'src\IPCShared.pas';

{$R *.res}

begin
  // Note: Configuration cannot be changed here because AutoSplash 
  // has already initialized. To configure, create a separate unit
  // that sets Config values in its initialization section and include
  // it BEFORE AutoSplash in the uses clause.
  
  // The splash is already running at this point!
  // You can update its status throughout your initialization
  
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // Update splash during initialization
  if Assigned(Splash) then
  begin
    Splash.UpdateStatus('Initializing application...');
    Sleep(500); // Simulate some work
    
    Splash.UpdateStatus('Loading configuration...');
    Sleep(800); // Simulate loading config
    
    Splash.UpdateStatus('Connecting to database...');
    Sleep(600); // Simulate database connection
    
    Splash.UpdateStatus('Loading user interface...');
    Sleep(400); // Simulate UI setup
  end;
  
  // Create the main form
  Application.CreateForm(TfrmMain, frmMain);
  
  // Update splash one more time
  if Assigned(Splash) then
  begin
    Splash.UpdateStatus('Ready!');
    Sleep(300); // Let user see the final message
  end;
  
  // Optional: Manually close the splash before Application.Run
  // (If not done, it will close automatically when the program ends)
  // Splash.Close;
  
  // Run the application
  Application.Run;
  
  // The splash will be closed automatically when the program ends
  // (handled by the finalization section of AutoSplash)
end.