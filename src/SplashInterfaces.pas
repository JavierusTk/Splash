unit SplashInterfaces;

interface

uses
  System.Types, System.Skia, SplashConfig;

type
  // Interface for IPC communication management
  ISplashIPCManager = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    procedure StartMonitoring(AParentPID: DWORD);
    procedure StopMonitoring;
    function CheckForUpdate(out AProgress: Integer; out AStatus: string): Boolean;
    function GetIsParentAlive: Boolean;
    function GetShouldClose: Boolean;
    function IsTimeout(ASeconds: Integer): Boolean;
    property IsParentAlive: Boolean read GetIsParentAlive;
    property ShouldClose: Boolean read GetShouldClose;
  end;

  // Interface for animation control
  ISplashAnimationController = interface
    ['{B2C3D4E5-F6A7-5890-1234-567890ABCDEF}']
    procedure Initialize;
    procedure UpdateAnimation(ADeltaTime: Single);
    procedure SetTarget(AProgress: Single; ADuration: Integer);
    procedure SetPhase(const APhaseName: string; AStartProgress, AEndProgress: Single; ADuration: Integer);
    function GetDisplayProgress: Single;
    function GetAnimationSpeed: Single;
    function GetMinimumProgress: Single;
    procedure ResetPhaseAnimation;
    property DisplayProgress: Single read GetDisplayProgress;
    property AnimationSpeed: Single read GetAnimationSpeed;
    property MinimumProgress: Single read GetMinimumProgress;
  end;

  // Interface for progress management and learning coordination
  ISplashProgressManager = interface
    ['{C3D4E5F6-A7B8-6901-2345-678901ABCDEF}']
    procedure Initialize;
    procedure HandleStatusUpdate(const AStatus: string; AProgress: Integer);
    function GetPredictedProgress(const AStatus: string): Single;
    function GetPredictedDuration(const AStatus: string): Integer;
    function GetCurrentPhase: string;
    procedure StartSession;
    procedure EndSession;
    property CurrentPhase: string read GetCurrentPhase;
  end;

  // Interface for simulation management
  ISplashSimulationManager = interface
    ['{D4E5F6A7-B8C9-7012-3456-789012ABCDEF}']
    procedure StartSimulation;
    procedure StopSimulation;
    procedure UpdateSimulation;
    function GetSimulatedProgress: Integer;
    function GetSimulatedStatus: string;
    function GetIsSimulating: Boolean;
    function ShouldShowSimulation: Boolean;
    property IsSimulating: Boolean read GetIsSimulating;
    property SimulatedProgress: Integer read GetSimulatedProgress;
    property SimulatedStatus: string read GetSimulatedStatus;
  end;

  // Interface for rendering operations
  ISplashRenderer = interface
    ['{E5F6A7B8-C9D0-8123-4567-890123ABCDEF}']
    procedure RenderSplashContent(const ACanvas: ISkCanvas; const ARect: TRectF);
    procedure TakeScreenshot(const AQuality: string);
  end;

  // Interface for configuration management
  ISplashConfiguration = interface
    ['{F6A7B8C9-D0E1-9234-5678-901234ABCDEF}']
    function GetAppName: string;
    function GetVersion: string;
    function GetSubVersion: string;
    function GetLoadingCaption: string;
    function GetStartingStatus: string;
    function GetLearningIndicator: string;
    function GetIsBeta: Boolean;
    function GetLogoFile: string;
    property AppName: string read GetAppName;
    property Version: string read GetVersion;
    property SubVersion: string read GetSubVersion;
    property LoadingCaption: string read GetLoadingCaption;
    property StartingStatus: string read GetStartingStatus;
    property LearningIndicator: string read GetLearningIndicator;
    property IsBeta: Boolean read GetIsBeta;
    property LogoFile: string read GetLogoFile;
  end;

  // Interface for lifecycle management (new)
  ISplashLifecycleManager = interface
    ['{A7B8C9D0-E1F2-3456-7890-123456ABCDEF}']
    procedure Initialize(AParentPID: DWORD);
    procedure CheckLifecycleStatus;
    function ShouldClose: Boolean;
    function IsParentAlive: Boolean;
    function IsTimeout: Boolean;
    procedure RequestClose;
  end;

  // Interface for rendering management (new)
  ISplashRenderingManager = interface
    ['{B8C9D0E1-F234-5678-9012-3456789ABCDE}']
    procedure Initialize(const AConfig: TSplashConfiguration);
    procedure RenderFrame(const ACanvas: ISkCanvas; const ARect: TRectF; 
      AProgress: Single; const AStatus: string; AAnimationTime: Single);
    procedure SetBeta(AIsBeta: Boolean);
    function GetSvgLogo: ISkSVGDOM;
  end;

  // Interface for style provider (new)
  ISplashStyleProvider = interface
    ['{C9D0E1F2-3456-7890-1234-56789ABCDEF0}']
    function GetPurpleColor: Integer;
    function GetOrangeColor: Integer;
    function GetTextColor: Integer;
    function GetBackgroundColor: Integer;
    function GetLogoSize: Single;
    function GetProgressBarHeight: Single;
    function GetContainerRadius: Single;
    function GetFont(const AStyle: string): ISkFont;
  end;

  // Interface for layout calculator (new)
  ISplashLayoutCalculator = interface
    ['{D0E1F234-5678-9012-3456-789ABCDEF012}']
    function GetContainerRect(const AFormRect: TRectF): TRectF;
    function GetLogoRect(const AFormRect: TRectF): TRectF;
    function GetBrandTextPosition(const AFormRect: TRectF): TPointF;
    function GetProgressBarRect(const AFormRect: TRectF): TRectF;
    function GetStatusTextPosition(const AFormRect: TRectF): TPointF;
    function GetBetaBadgeRect(const AFormRect: TRectF): TRectF;
  end;

  // Interface for learning coordination (new)
  ISplashLearningCoordinator = interface
    ['{E1F23456-7890-1234-5678-9ABCDEF01234}']
    procedure RecordPhaseStart(const APhaseName: string);
    procedure RecordPhaseEnd(const APhaseName: string);
    function GetPredictedDuration(const APhaseName: string): Integer;
    function GetPredictedProgress(const APhaseName: string): Single;
    procedure SaveLearningData;
    procedure LoadLearningData;
  end;

  // Interface for progress tracking (simplified)
  ISplashProgressTracker = interface
    ['{F2345678-9012-3456-7890-ABCDEF012345}']
    procedure UpdateProgress(AValue: Single);
    procedure UpdateStatus(const AText: string);
    function GetCurrentProgress: Single;
    function GetCurrentStatus: string;
    property CurrentProgress: Single read GetCurrentProgress;
    property CurrentStatus: string read GetCurrentStatus;
  end;

  // Interface for animation engine (new)
  ISplashAnimationEngine = interface
    ['{03456789-0123-4567-890A-BCDEF0123456}']
    procedure Initialize;
    procedure SetTarget(ATarget: Single; ADuration: Integer);
    procedure Update(ADeltaTime: Single);
    function GetDisplayValue: Single;
    function GetAnimationSpeed: Single;
    property DisplayValue: Single read GetDisplayValue;
    property AnimationSpeed: Single read GetAnimationSpeed;
  end;

implementation

end.