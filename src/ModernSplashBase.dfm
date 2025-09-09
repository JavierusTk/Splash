object frmModernSplashBase: TfrmModernSplashBase
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Splash Screen'
  ClientHeight = 420
  ClientWidth = 650
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object SkAnimatedPaintBox: TSkAnimatedPaintBox
    Left = 0
    Top = 0
    Width = 650
    Height = 420
    Align = alClient
    OnAnimationDraw = SkAnimatedPaintBoxAnimationDraw
  end
  object AnimationTimer: TTimer
    Interval = 150
    OnTimer = AnimationTimerTimer
    Left = 24
    Top = 24
  end
end
