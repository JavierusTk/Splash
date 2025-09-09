unit SplashLayoutCalculator;

interface

uses
  System.Types, SplashInterfaces;

type
  TSplashLayoutCalculator = class(TInterfacedObject, ISplashLayoutCalculator)
  private
    const
      // Layout constants
      CONTAINER_PADDING = 20;
      SHADOW_OFFSET = 4;
      LOGO_Y = 70;
      BRAND_TEXT_Y = 200;
      BETA_BADGE_Y = 250;
      LOADING_TEXT_Y = 320;
      PROGRESS_BAR_Y = 345;
      STATUS_TEXT_Y = 365;
      PROGRESS_BAR_MARGIN = 100;
      VERSION_INFO_RIGHT_MARGIN = 120;
      VERSION_INFO_BOTTOM_MARGIN = 25;
      BETA_BADGE_WIDTH = 100;
      BETA_BADGE_HEIGHT = 30;
      DOT_SPACING = 8.0;
      DOT_SIZE = 3.0;
      DOT_OFFSET = 5.0;
  public
    // ISplashLayoutCalculator implementation
    function GetContainerRect(const AFormRect: TRectF): TRectF;
    function GetLogoRect(const AFormRect: TRectF): TRectF;
    function GetBrandTextPosition(const AFormRect: TRectF): TPointF;
    function GetProgressBarRect(const AFormRect: TRectF): TRectF;
    function GetStatusTextPosition(const AFormRect: TRectF): TPointF;
    function GetBetaBadgeRect(const AFormRect: TRectF): TRectF;
    
    // Additional helper methods
    function GetShadowRect(const AFormRect: TRectF): TRectF;
    function GetLoadingTextPosition(const AFormRect: TRectF): TPointF;
    function GetVersionInfoPosition(const AFormRect: TRectF): TPointF;
    function GetVersionNumberOffset: Single;
    function GetLoadingDotsPosition(const AFormRect: TRectF; ATextWidth: Single): TPointF;
    function GetStatusDotsPosition(const AFormRect: TRectF; ATextWidth: Single): TPointF;
  end;

implementation

{ TSplashLayoutCalculator }

function TSplashLayoutCalculator.GetContainerRect(const AFormRect: TRectF): TRectF;
begin
  Result := TRectF.Create(
    CONTAINER_PADDING,
    CONTAINER_PADDING,
    AFormRect.Width - CONTAINER_PADDING,
    AFormRect.Height - CONTAINER_PADDING
  );
end;

function TSplashLayoutCalculator.GetShadowRect(const AFormRect: TRectF): TRectF;
begin
  Result := TRectF.Create(
    CONTAINER_PADDING + SHADOW_OFFSET,
    CONTAINER_PADDING + SHADOW_OFFSET,
    AFormRect.Width - CONTAINER_PADDING + SHADOW_OFFSET,
    AFormRect.Height - CONTAINER_PADDING + SHADOW_OFFSET
  );
end;

function TSplashLayoutCalculator.GetLogoRect(const AFormRect: TRectF): TRectF;
var
  LCenterX: Single;
  LLogoSize: Single;
begin
  LCenterX := AFormRect.Width / 2;
  LLogoSize := 84; // Logo size from style provider
  
  Result := TRectF.Create(
    LCenterX - LLogoSize / 2,
    LOGO_Y - LLogoSize / 2,
    LCenterX + LLogoSize / 2,
    LOGO_Y + LLogoSize / 2
  );
end;

function TSplashLayoutCalculator.GetBrandTextPosition(const AFormRect: TRectF): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width / 2,
    BRAND_TEXT_Y
  );
end;

function TSplashLayoutCalculator.GetProgressBarRect(const AFormRect: TRectF): TRectF;
var
  LProgressHeight: Single;
begin
  LProgressHeight := 6; // Progress bar height from style provider
  
  Result := TRectF.Create(
    PROGRESS_BAR_MARGIN,
    PROGRESS_BAR_Y,
    AFormRect.Width - PROGRESS_BAR_MARGIN,
    PROGRESS_BAR_Y + LProgressHeight
  );
end;

function TSplashLayoutCalculator.GetStatusTextPosition(const AFormRect: TRectF): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width / 2,
    STATUS_TEXT_Y
  );
end;

function TSplashLayoutCalculator.GetBetaBadgeRect(const AFormRect: TRectF): TRectF;
begin
  Result := TRectF.Create(
    AFormRect.Width / 2 - BETA_BADGE_WIDTH / 2,
    BETA_BADGE_Y,
    AFormRect.Width / 2 + BETA_BADGE_WIDTH / 2,
    BETA_BADGE_Y + BETA_BADGE_HEIGHT
  );
end;

function TSplashLayoutCalculator.GetLoadingTextPosition(const AFormRect: TRectF): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width / 2,
    LOADING_TEXT_Y
  );
end;

function TSplashLayoutCalculator.GetVersionInfoPosition(const AFormRect: TRectF): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width - VERSION_INFO_RIGHT_MARGIN,
    AFormRect.Height - VERSION_INFO_BOTTOM_MARGIN
  );
end;

function TSplashLayoutCalculator.GetVersionNumberOffset: Single;
begin
  // Offset for version number next to brand text
  Result := 130;
end;

function TSplashLayoutCalculator.GetLoadingDotsPosition(const AFormRect: TRectF; ATextWidth: Single): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width / 2 + ATextWidth / 2 + DOT_OFFSET,
    LOADING_TEXT_Y - 5
  );
end;

function TSplashLayoutCalculator.GetStatusDotsPosition(const AFormRect: TRectF; ATextWidth: Single): TPointF;
begin
  Result := TPointF.Create(
    AFormRect.Width / 2 + ATextWidth / 2 + DOT_OFFSET,
    STATUS_TEXT_Y
  );
end;

end.