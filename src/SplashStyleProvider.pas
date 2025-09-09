unit SplashStyleProvider;

interface

uses
  System.UITypes, System.Skia, SplashInterfaces;

type
  TSplashStyleProvider = class(TInterfacedObject, ISplashStyleProvider)
  private
    const
      // Colors
      COLOR_PURPLE = $FF7C3AED;
      COLOR_PURPLE_LIGHT = $FFA855F7;
      COLOR_ORANGE = $FFFF9800;
      COLOR_ORANGE_LIGHT = $FFFFAB40;
      COLOR_GRAY_TEXT = $FF6B7280;
      COLOR_GRAY_STATUS = $FF6B7280;
      COLOR_GRAY_VERSION = $FF9CA3AF;
      COLOR_GRAY_LIGHT = $FFF5F5F5;
      COLOR_WHITE = $FFFFFFFF;
      
      // Sizes
      LOGO_SIZE = 84;
      PROGRESS_HEIGHT = 6;
      BETA_BADGE_HEIGHT = 30;
      CONTAINER_RADIUS = 20.0;
      
      // Text constants
      BETA_TEXT = 'BETA';
      BETA_SUFFIX = '-beta';
      
      // Font sizes
      FONT_SIZE_BRAND = 48;
      FONT_SIZE_VERSION = 56;
      FONT_SIZE_LOADING = 16;
      FONT_SIZE_STATUS = 14;
      FONT_SIZE_BETA = 12;
      FONT_SIZE_VERSION_INFO = 12;
  public
    // ISplashStyleProvider implementation
    function GetPurpleColor: Integer;
    function GetOrangeColor: Integer;
    function GetTextColor: Integer;
    function GetBackgroundColor: Integer;
    function GetLogoSize: Single;
    function GetProgressBarHeight: Single;
    function GetContainerRadius: Single;
    function GetFont(const AStyle: string): ISkFont;
    
    // Additional helper methods
    function GetPurpleLightColor: TAlphaColor;
    function GetOrangeLightColor: TAlphaColor;
    function GetGrayStatusColor: TAlphaColor;
    function GetGrayVersionColor: TAlphaColor;
    function GetWhiteColor: TAlphaColor;
    function GetBetaBadgeHeight: Single;
    function GetBetaText: string;
    function GetBetaSuffix: string;
  end;

implementation

{ TSplashStyleProvider }

function TSplashStyleProvider.GetPurpleColor: Integer;
begin
  Result := Integer(COLOR_PURPLE);
end;

function TSplashStyleProvider.GetOrangeColor: Integer;
begin
  Result := Integer(COLOR_ORANGE);
end;

function TSplashStyleProvider.GetTextColor: Integer;
begin
  Result := Integer(COLOR_GRAY_TEXT);
end;

function TSplashStyleProvider.GetBackgroundColor: Integer;
begin
  Result := Integer(COLOR_GRAY_LIGHT);
end;

function TSplashStyleProvider.GetLogoSize: Single;
begin
  Result := LOGO_SIZE;
end;

function TSplashStyleProvider.GetProgressBarHeight: Single;
begin
  Result := PROGRESS_HEIGHT;
end;

function TSplashStyleProvider.GetContainerRadius: Single;
begin
  Result := CONTAINER_RADIUS;
end;

function TSplashStyleProvider.GetFont(const AStyle: string): ISkFont;
var
  LTypeface: ISkTypeface;
  LFontSize: Single;
begin
  // Determine font properties based on style
  if AStyle = 'brand' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Bold);
    LFontSize := FONT_SIZE_BRAND;
  end
  else if AStyle = 'version' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Bold);
    LFontSize := FONT_SIZE_VERSION;
  end
  else if AStyle = 'loading' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Normal);
    LFontSize := FONT_SIZE_LOADING;
  end
  else if AStyle = 'status' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Normal);
    LFontSize := FONT_SIZE_STATUS;
  end
  else if AStyle = 'beta' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Bold);
    LFontSize := FONT_SIZE_BETA;
  end
  else if AStyle = 'version-info' then
  begin
    LTypeface := TSkTypeface.MakeFromName('Courier New', TSkFontStyle.Normal);
    LFontSize := FONT_SIZE_VERSION_INFO;
  end
  else
  begin
    // Default font
    LTypeface := TSkTypeface.MakeFromName('Segoe UI', TSkFontStyle.Normal);
    LFontSize := FONT_SIZE_STATUS;
  end;
  
  Result := TSkFont.Create(LTypeface, LFontSize);
end;

function TSplashStyleProvider.GetPurpleLightColor: TAlphaColor;
begin
  Result := COLOR_PURPLE_LIGHT;
end;

function TSplashStyleProvider.GetOrangeLightColor: TAlphaColor;
begin
  Result := COLOR_ORANGE_LIGHT;
end;

function TSplashStyleProvider.GetGrayStatusColor: TAlphaColor;
begin
  Result := COLOR_GRAY_STATUS;
end;

function TSplashStyleProvider.GetGrayVersionColor: TAlphaColor;
begin
  Result := COLOR_GRAY_VERSION;
end;

function TSplashStyleProvider.GetWhiteColor: TAlphaColor;
begin
  Result := COLOR_WHITE;
end;

function TSplashStyleProvider.GetBetaBadgeHeight: Single;
begin
  Result := BETA_BADGE_HEIGHT;
end;

function TSplashStyleProvider.GetBetaText: string;
begin
  Result := BETA_TEXT;
end;

function TSplashStyleProvider.GetBetaSuffix: string;
begin
  Result := BETA_SUFFIX;
end;

end.