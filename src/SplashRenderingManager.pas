unit SplashRenderingManager;

interface

uses
  System.Classes, System.SysUtils, System.Types, System.UITypes, System.Math,
  System.Skia, Vcl.Skia, System.IOUtils,
  SplashInterfaces, SplashConfig, SplashStyleProvider, SplashLayoutCalculator;

type
  TSplashRenderingManager = class(TInterfacedObject, ISplashRenderingManager)
  private
    FConfiguration: TSplashConfiguration;
    FStyleProvider: ISplashStyleProvider;
    FLayoutCalculator: ISplashLayoutCalculator;
    FSvgLogo: ISkSVGDOM;
    FIsBeta: Boolean;
    FLastPaintedBarWidth: Single;
    
    // Drawing methods
    procedure DrawContainer(const ACanvas: ISkCanvas; const ARect: TRectF);
    procedure DrawLogo(const ACanvas: ISkCanvas; const ARect: TRectF);
    procedure DrawBrandText(const ACanvas: ISkCanvas; const ARect: TRectF);
    procedure DrawBetaBadge(const ACanvas: ISkCanvas; const ARect: TRectF; AAnimationTime: Single);
    procedure DrawProgressSection(const ACanvas: ISkCanvas; const ARect: TRectF; 
      AProgress: Single; const AStatus: string; AAnimationTime: Single);
    procedure DrawVersionInfo(const ACanvas: ISkCanvas; const ARect: TRectF);
    
    // Animation helpers
    procedure DrawLoadingDots(const ACanvas: ISkCanvas; const AX, AY, AAnimationTime: Single);
    procedure DrawStatusDots(const ACanvas: ISkCanvas; const AX, AY, AAnimationTime: Single);
    procedure DrawBetaShimmer(const ACanvas: ISkCanvas; const ABadgeRect: TRectF; const AAnimationTime: Single);
    
    // Helper methods
    function CreateGradientShader(const AStartColor, AEndColor: TAlphaColor; 
      const AStart, AEnd: TPointF): ISkShader;
    function LoadSvgLogo: ISkSVGDOM;
    
    // Default SVG logo
    const
      C_SVG_LOGO: string =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 60 60">' +
        '  <path fill="#7C3AED" fill-rule="evenodd" clip-rule="evenodd" d="' +
        'M 60 30 A 30 30 0 1 1 0 30 A 30 30 0 1 1 60 30 Z ' +
        'M 60.064883061 30 A 18.064883061 18.064883061 0 1 0 23.935116939 30 ' +
        'A 18.064883061 18.064883061 0 1 0 60.064883061 30 Z" />' +
        '  <path fill="#FF9800" d="' +
        'M 42.000 20.000 L 44.200 27.000 L 51.600 27.000 L 45.600 31.400 L 47.800 38.200 ' +
        'L 42.000 34.000 L 36.200 38.200 L 38.400 31.400 L 32.400 27.000 L 39.800 27.000 Z" />' +
        '</svg>';
  public
    constructor Create;
    destructor Destroy; override;
    
    // ISplashRenderingManager implementation
    procedure Initialize(const AConfig: TSplashConfiguration);
    procedure RenderFrame(const ACanvas: ISkCanvas; const ARect: TRectF; 
      AProgress: Single; const AStatus: string; AAnimationTime: Single);
    procedure SetBeta(AIsBeta: Boolean);
    function GetSvgLogo: ISkSVGDOM;
  end;

implementation

uses
  DebugManager;

{ TSplashRenderingManager }

constructor TSplashRenderingManager.Create;
begin
  inherited Create;
  FStyleProvider := TSplashStyleProvider.Create;
  FLayoutCalculator := TSplashLayoutCalculator.Create;
  FLastPaintedBarWidth := 0;
end;

destructor TSplashRenderingManager.Destroy;
begin
  FStyleProvider := nil;
  FLayoutCalculator := nil;
  inherited;
end;

procedure TSplashRenderingManager.Initialize(const AConfig: TSplashConfiguration);
begin
  FConfiguration := AConfig;
  FIsBeta := AConfig.IsBeta;
  
  // Clear cached logo if new config has different logo
  if (AConfig.LogoFile <> '') then
    FSvgLogo := nil;
end;

procedure TSplashRenderingManager.RenderFrame(const ACanvas: ISkCanvas; const ARect: TRectF; 
  AProgress: Single; const AStatus: string; AAnimationTime: Single);
begin
  // Clear canvas with background color
  ACanvas.Clear(FStyleProvider.GetBackgroundColor);
  
  // Draw container
  DrawContainer(ACanvas, ARect);
  
  // Draw all visual elements
  DrawLogo(ACanvas, ARect);
  DrawBrandText(ACanvas, ARect);
  
  if FIsBeta then
    DrawBetaBadge(ACanvas, ARect, AAnimationTime);
    
  DrawProgressSection(ACanvas, ARect, AProgress, AStatus, AAnimationTime);
  DrawVersionInfo(ACanvas, ARect);
end;

procedure TSplashRenderingManager.SetBeta(AIsBeta: Boolean);
begin
  FIsBeta := AIsBeta;
end;

function TSplashRenderingManager.GetSvgLogo: ISkSVGDOM;
begin
  if FSvgLogo = nil then
    FSvgLogo := LoadSvgLogo;
  Result := FSvgLogo;
end;

procedure TSplashRenderingManager.DrawContainer(const ACanvas: ISkCanvas; const ARect: TRectF);
var
  LPaint: ISkPaint;
  LContainerRect, LShadowRect: TRectF;
begin
  LContainerRect := FLayoutCalculator.GetContainerRect(ARect);
  LShadowRect := (FLayoutCalculator as TSplashLayoutCalculator).GetShadowRect(ARect);
  
  // Draw shadow
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := $197C3AED; // Semi-transparent purple for shadow
  LPaint.AntiAlias := True;
  ACanvas.DrawRoundRect(LShadowRect, FStyleProvider.GetContainerRadius, 
    FStyleProvider.GetContainerRadius, LPaint);
  
  // Draw white container
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := (FStyleProvider as TSplashStyleProvider).GetWhiteColor;
  LPaint.AntiAlias := True;
  ACanvas.DrawRoundRect(LContainerRect, FStyleProvider.GetContainerRadius, 
    FStyleProvider.GetContainerRadius, LPaint);
end;

procedure TSplashRenderingManager.DrawLogo(const ACanvas: ISkCanvas; const ARect: TRectF);
var
  LDest: TRectF;
  LSvg: ISkSVGDOM;
begin
  LSvg := GetSvgLogo;
  if LSvg = nil then
    Exit;

  LDest := FLayoutCalculator.GetLogoRect(ARect);
  
  // Set SVG container size
  LSvg.SetContainerSize(TSizeF.Create(Round(FStyleProvider.GetLogoSize), 
    Round(FStyleProvider.GetLogoSize)));

  // Render SVG
  ACanvas.Save;
  try
    ACanvas.Translate(LDest.Left, LDest.Top);
    LSvg.Render(ACanvas);
  finally
    ACanvas.Restore;
  end;
end;

procedure TSplashRenderingManager.DrawBrandText(const ACanvas: ISkCanvas; const ARect: TRectF);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LTextBounds: TRectF;
  LBrandPos: TPointF;
  LVersionOffset: Single;
begin
  LBrandPos := FLayoutCalculator.GetBrandTextPosition(ARect);
  LVersionOffset := (FLayoutCalculator as TSplashLayoutCalculator).GetVersionNumberOffset;
  
  // Draw brand name
  LFont := FStyleProvider.GetFont('brand');
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Shader := CreateGradientShader(
    FStyleProvider.GetPurpleColor,
    (FStyleProvider as TSplashStyleProvider).GetPurpleLightColor,
    TPointF.Create(0, 180),
    TPointF.Create(0, 230)
  );
  
  LFont.MeasureText(FConfiguration.AppName, LTextBounds);
  ACanvas.DrawSimpleText(FConfiguration.AppName, 
    LBrandPos.X - LTextBounds.Width / 2 - 30, 
    LBrandPos.Y, LFont, LPaint);
  
  // Draw version number
  LFont := FStyleProvider.GetFont('version');
  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  LPaint.Shader := CreateGradientShader(
    FStyleProvider.GetOrangeColor,
    (FStyleProvider as TSplashStyleProvider).GetOrangeLightColor,
    TPointF.Create(0, 180),
    TPointF.Create(0, 240)
  );
  
  LFont.MeasureText(FConfiguration.Version, LTextBounds);
  ACanvas.DrawSimpleText(FConfiguration.Version, 
    LBrandPos.X + LVersionOffset - LTextBounds.Width / 2,
    LBrandPos.Y, LFont, LPaint);
end;

procedure TSplashRenderingManager.DrawBetaBadge(const ACanvas: ISkCanvas; const ARect: TRectF; 
  AAnimationTime: Single);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LBadgeRect: TRectF;
  LTextBounds: TRectF;
  LBetaText: string;
begin
  LBadgeRect := FLayoutCalculator.GetBetaBadgeRect(ARect);
  LBetaText := (FStyleProvider as TSplashStyleProvider).GetBetaText;
  
  // Draw badge background
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := $19FF9800; // Semi-transparent orange
  LPaint.AntiAlias := True;
  ACanvas.DrawRoundRect(LBadgeRect, 16, 16, LPaint);
  
  // Draw badge border
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Stroke;
  LPaint.Color := $4DFF9800; // Semi-transparent orange border
  LPaint.StrokeWidth := 1;
  LPaint.AntiAlias := True;
  ACanvas.DrawRoundRect(LBadgeRect, 16, 16, LPaint);
  
  // Draw shimmer effect
  DrawBetaShimmer(ACanvas, LBadgeRect, AAnimationTime);
  
  // Draw beta text
  LFont := FStyleProvider.GetFont('beta');
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FStyleProvider.GetOrangeColor;
  LPaint.AntiAlias := True;
  
  LFont.MeasureText(LBetaText, LTextBounds);
  ACanvas.DrawSimpleText(LBetaText, 
    LBadgeRect.Left + (LBadgeRect.Width - LTextBounds.Width) / 2,
    LBadgeRect.Top + (LBadgeRect.Height + LTextBounds.Height) / 2 - 2,
    LFont, LPaint);
end;

procedure TSplashRenderingManager.DrawProgressSection(const ACanvas: ISkCanvas; const ARect: TRectF; 
  AProgress: Single; const AStatus: string; AAnimationTime: Single);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LProgressRect, LProgressFillRect: TRectF;
  LTextBounds: TRectF;
  LLoadingPos, LStatusPos: TPointF;
  LDotsPos: TPointF;
begin
  LLoadingPos := (FLayoutCalculator as TSplashLayoutCalculator).GetLoadingTextPosition(ARect);
  LStatusPos := FLayoutCalculator.GetStatusTextPosition(ARect);
  
  // Draw loading caption
  LFont := FStyleProvider.GetFont('loading');
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FStyleProvider.GetTextColor;
  LPaint.AntiAlias := True;
  
  LFont.MeasureText(FConfiguration.LoadingCaption, LTextBounds);
  ACanvas.DrawSimpleText(FConfiguration.LoadingCaption, 
    LLoadingPos.X - LTextBounds.Width / 2 - 15, 
    LLoadingPos.Y, LFont, LPaint);
  
  // Draw loading dots
  LDotsPos := (FLayoutCalculator as TSplashLayoutCalculator).GetLoadingDotsPosition(ARect, LTextBounds.Width);
  DrawLoadingDots(ACanvas, LDotsPos.X, LDotsPos.Y, AAnimationTime);
  
  // Draw progress bar background
  LProgressRect := FLayoutCalculator.GetProgressBarRect(ARect);
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := $197C3AED; // Semi-transparent purple
  LPaint.AntiAlias := True;
  ACanvas.DrawRoundRect(LProgressRect, 3, 3, LPaint);
  
  // Draw progress bar fill
  if AProgress > 0 then
  begin
    LProgressFillRect := TRectF.Create(
      LProgressRect.Left,
      LProgressRect.Top,
      LProgressRect.Left + (LProgressRect.Width * AProgress),
      LProgressRect.Bottom
    );
    
    FLastPaintedBarWidth := LProgressRect.Width * AProgress;
    
    LPaint := TSkPaint.Create;
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.AntiAlias := True;
    LPaint.Shader := CreateGradientShader(
      FStyleProvider.GetPurpleColor,
      FStyleProvider.GetOrangeColor,
      TPointF.Create(LProgressRect.Left, LProgressRect.Top),
      TPointF.Create(LProgressRect.Right, LProgressRect.Top)
    );
    ACanvas.DrawRoundRect(LProgressFillRect, 3, 3, LPaint);
  end
  else
    FLastPaintedBarWidth := 0;
  
  // Draw status text
  LFont := FStyleProvider.GetFont('status');
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FStyleProvider.GetTextColor;
  LPaint.AntiAlias := True;
  
  LFont.MeasureText(AStatus, LTextBounds);
  ACanvas.DrawSimpleText(AStatus, 
    LStatusPos.X - LTextBounds.Width / 2, 
    LStatusPos.Y, LFont, LPaint);
  
  // Draw status dots
  LDotsPos := (FLayoutCalculator as TSplashLayoutCalculator).GetStatusDotsPosition(ARect, LTextBounds.Width);
  DrawStatusDots(ACanvas, LDotsPos.X, LStatusPos.Y, AAnimationTime);
end;

procedure TSplashRenderingManager.DrawVersionInfo(const ACanvas: ISkCanvas; const ARect: TRectF);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  LVersionText: string;
  LVersionPos: TPointF;
begin
  LVersionText := FConfiguration.GetVersionText;
  if FIsBeta then
    LVersionText := LVersionText + (FStyleProvider as TSplashStyleProvider).GetBetaSuffix;
    
  LVersionPos := (FLayoutCalculator as TSplashLayoutCalculator).GetVersionInfoPosition(ARect);
  
  LFont := FStyleProvider.GetFont('version-info');
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.Color := FStyleProvider.GetTextColor;
  LPaint.AntiAlias := True;
  
  ACanvas.DrawSimpleText(LVersionText, LVersionPos.X, LVersionPos.Y, LFont, LPaint);
end;

procedure TSplashRenderingManager.DrawLoadingDots(const ACanvas: ISkCanvas; const AX, AY, AAnimationTime: Single);
const
  DOT_SIZE = 3.0;
  DOT_SPACING = 4.0;
  ANIMATION_DURATION = 1.4;
  ANIMATION_DELAYS: array[0..2] of Single = (-0.32, -0.16, 0.0);
var
  LPaint: ISkPaint;
  I: Integer;
  LDotX, LDotY: Single;
  LAnimTime, LScale, LOpacity: Single;
  LCurrentRadius: Single;
begin
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.AntiAlias := True;
  LPaint.Color := FStyleProvider.GetTextColor;
  
  for I := 0 to 2 do
  begin
    LDotX := AX + (I * (DOT_SIZE * 2 + DOT_SPACING));
    LDotY := AY;
    
    LAnimTime := (AAnimationTime + ANIMATION_DELAYS[I]) / ANIMATION_DURATION;
    LScale := 1.0 + 0.3 * Abs(Sin(LAnimTime * 2 * Pi));
    LOpacity := 0.5 + 0.5 * Abs(Sin(LAnimTime * 2 * Pi));
    LCurrentRadius := DOT_SIZE * LScale;
    
    LPaint.Color := (Trunc(LOpacity * 255) shl 24) or (FStyleProvider.GetTextColor and $00FFFFFF);
    ACanvas.DrawCircle(LDotX, LDotY, LCurrentRadius, LPaint);
  end;
end;

procedure TSplashRenderingManager.DrawStatusDots(const ACanvas: ISkCanvas; const AX, AY, AAnimationTime: Single);
const
  DOT_SPACING = 8.0;
  ANIMATION_DURATION = 1.5;
  ANIMATION_DELAYS: array[0..2] of Single = (0.0, 0.2, 0.4);
var
  LPaint: ISkPaint;
  LFont: ISkFont;
  I: Integer;
  LDotX: Single;
  LAnimTime, LOpacity: Single;
begin
  LFont := FStyleProvider.GetFont('status');
  LPaint := TSkPaint.Create;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.AntiAlias := True;
  
  for I := 0 to 2 do
  begin
    LDotX := AX + (I * DOT_SPACING);
    LAnimTime := (AAnimationTime + ANIMATION_DELAYS[I]) / ANIMATION_DURATION;
    LOpacity := 0.5 + 0.5 * Abs(Sin(LAnimTime * 2 * Pi));
    
    LPaint.Color := (Trunc(LOpacity * 255) shl 24) or (FStyleProvider.GetTextColor and $00FFFFFF);
    ACanvas.DrawSimpleText('.', LDotX, AY, LFont, LPaint);
  end;
end;

procedure TSplashRenderingManager.DrawBetaShimmer(const ACanvas: ISkCanvas; 
  const ABadgeRect: TRectF; const AAnimationTime: Single);
const
  SHIMMER_DURATION = 3.0;
var
  LPaint: ISkPaint;
  LShimmerRect: TRectF;
  LAnimProgress: Single;
  LShimmerX: Single;
  LShimmerWidth: Single;
  LGradientStart, LGradientEnd: TPointF;
  LShader: ISkShader;
begin
  LAnimProgress := Frac(AAnimationTime / SHIMMER_DURATION);
  LShimmerWidth := ABadgeRect.Width;
  LShimmerX := ABadgeRect.Left + (-LShimmerWidth) + (LAnimProgress * 3 * LShimmerWidth);
  
  LShimmerRect := TRectF.Create(
    LShimmerX,
    ABadgeRect.Top,
    LShimmerX + LShimmerWidth,
    ABadgeRect.Bottom
  );
  
  LGradientStart := TPointF.Create(LShimmerRect.Left, LShimmerRect.Top);
  LGradientEnd := TPointF.Create(LShimmerRect.Right, LShimmerRect.Top);
  
  LShader := TSkShader.MakeGradientLinear(
    LGradientStart, 
    LGradientEnd,
    [$00FF9800, $33FF9800, $00FF9800],
    [0.0, 0.5, 1.0],
    TSkTileMode.Clamp
  );
  
  ACanvas.Save;
  try
    ACanvas.ClipRoundRect(TSkRoundRect.Create(ABadgeRect, 16, 16), TSkClipOp.Intersect, True);
    
    LPaint := TSkPaint.Create;
    LPaint.Style := TSkPaintStyle.Fill;
    LPaint.Shader := LShader;
    LPaint.AntiAlias := True;
    
    ACanvas.DrawRect(LShimmerRect, LPaint);
  finally
    ACanvas.Restore;
  end;
end;

function TSplashRenderingManager.CreateGradientShader(const AStartColor, AEndColor: TAlphaColor; 
  const AStart, AEnd: TPointF): ISkShader;
begin
  Result := TSkShader.MakeGradientLinear(AStart, AEnd, AStartColor, AEndColor, TSkTileMode.Clamp);
end;

function TSplashRenderingManager.LoadSvgLogo: ISkSVGDOM;
var
  SS: TStringStream;
  FS: TFileStream;
  LogoPath: string;
begin
  Result := nil;
  
  // Try to load custom logo if specified
  if (FConfiguration.LogoFile <> '') then
  begin
    LogoPath := FConfiguration.LogoFile;
    if FileExists(LogoPath) then
    begin
      try
        FS := TFileStream.Create(LogoPath, fmOpenRead);
        try
          Result := TSkSVGDOM.MakeFromStream(FS);
        finally
          FS.Free;
        end;
      except
        on E: Exception do
          DebugLogFormat('Error loading custom logo from "%s": %s', [LogoPath, E.Message]);
      end;
    end;
  end;
  
  // Fall back to embedded logo
  if Result = nil then
  begin
    SS := TStringStream.Create(C_SVG_LOGO, TEncoding.UTF8);
    try
      Result := TSkSVGDOM.MakeFromStream(SS);
    finally
      SS.Free;
    end;
  end;
end;

end.