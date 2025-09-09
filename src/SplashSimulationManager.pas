unit SplashSimulationManager;

interface

uses
  System.SysUtils, Winapi.Windows, Vcl.ExtCtrls,
  SplashInterfaces, ProgressLearning, DebugManager;

type
  TSplashSimulationManager = class(TInterfacedObject, ISplashSimulationManager)
  private
    FProgressHistory: TProgressHistory;
    FProgressSimulator: TProgressSimulator;
    FSimulationTimer: TTimer;
    FIsSimulating: Boolean;
    FSimulatedProgress: Integer;
    FSimulatedStatus: string;
    
    procedure SimulationTimerTimer(Sender: TObject);
  public
    constructor Create(AProgressHistory: TProgressHistory);
    destructor Destroy; override;
    
    // ISplashSimulationManager implementation
    procedure StartSimulation;
    procedure StopSimulation;
    procedure UpdateSimulation;
    function GetSimulatedProgress: Integer;
    function GetSimulatedStatus: string;
    function GetIsSimulating: Boolean;
    function ShouldShowSimulation: Boolean;
  end;

implementation

{ TSplashSimulationManager }

constructor TSplashSimulationManager.Create(AProgressHistory: TProgressHistory);
begin
  inherited Create;
  FProgressHistory := AProgressHistory;
  FIsSimulating := False;
  FSimulatedProgress := 0;
  FSimulatedStatus := '';
  
  // Create progress simulator
  if FProgressHistory <> nil then
    FProgressSimulator := TProgressSimulator.Create(FProgressHistory);
    
  // Create simulation timer
  FSimulationTimer := TTimer.Create(nil);
  FSimulationTimer.Interval := 50; // Update simulation every 50ms
  FSimulationTimer.OnTimer := SimulationTimerTimer;
  FSimulationTimer.Enabled := False;
end;

destructor TSplashSimulationManager.Destroy;
begin
  StopSimulation;
  FreeAndNil(FSimulationTimer);
  FreeAndNil(FProgressSimulator);
  inherited;
end;

procedure TSplashSimulationManager.StartSimulation;
begin
  if FIsSimulating then
    Exit;
    
  if FProgressSimulator = nil then
  begin
    DebugLog('Cannot start simulation - no progress simulator available');
    Exit;
  end;
    
  FIsSimulating := True;
  FProgressSimulator.StartSimulation;
  FSimulationTimer.Enabled := True;
  
  DebugLog('Progress simulation started');
end;

procedure TSplashSimulationManager.StopSimulation;
begin
  if not FIsSimulating then
    Exit;
    
  FIsSimulating := False;
  FSimulationTimer.Enabled := False;
  
  if FProgressSimulator <> nil then
    FProgressSimulator.StopSimulation;
    
  DebugLog('Progress simulation stopped');
end;

procedure TSplashSimulationManager.UpdateSimulation;
begin
  if not FIsSimulating or (FProgressSimulator = nil) then
    Exit;
    
  // Get simulated values
  FSimulatedProgress := FProgressSimulator.GetSimulatedProgress;
  FSimulatedStatus := FProgressSimulator.GetSimulatedStatus;
  
  // Add estimation indicator
  if FSimulatedStatus <> '' then
    FSimulatedStatus := FSimulatedStatus + ' (estimado)';
  
  // Check if simulation is complete
  if FSimulatedProgress >= 100 then
    StopSimulation;
end;

function TSplashSimulationManager.GetSimulatedProgress: Integer;
begin
  Result := FSimulatedProgress;
end;

function TSplashSimulationManager.GetSimulatedStatus: string;
begin
  Result := FSimulatedStatus;
end;

function TSplashSimulationManager.GetIsSimulating: Boolean;
begin
  Result := FIsSimulating;
end;

function TSplashSimulationManager.ShouldShowSimulation: Boolean;
begin
  Result := False;
  
  if FProgressSimulator <> nil then
    Result := FProgressSimulator.ShouldShowSimulation;
end;

procedure TSplashSimulationManager.SimulationTimerTimer(Sender: TObject);
begin
  UpdateSimulation;
end;

end.