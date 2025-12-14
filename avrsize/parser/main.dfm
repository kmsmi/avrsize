object Form8: TForm8
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Parser'
  ClientHeight = 93
  ClientWidth = 187
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object Button1: TButton
    Left = 45
    Top = 34
    Width = 98
    Height = 25
    Caption = 'Open *.pdsc file'
    TabOrder = 0
    OnClick = Button1Click
  end
  object OpenDialog1: TOpenDialog
    Left = 32
    Top = 24
  end
  object SaveDialog1: TSaveDialog
    Filter = 'json file|*.json'
    Left = 16
    Top = 16
  end
end
