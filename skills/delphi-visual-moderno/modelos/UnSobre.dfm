object f_sobre: Tf_sobre
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Sobre'
  ClientHeight = 400
  ClientWidth = 680
  Color = 16184563
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 2562065
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poMainFormCenter
  StyleElements = []
  OnCreate = FormCreate
  OnKeyPress = FormKeyPress
  TextHeight = 15
  object pnlLateral: TPanel
    Left = 0
    Top = 0
    Width = 240
    Height = 400
    Align = alLeft
    BevelOuter = bvNone
    Color = 2562065
    ParentBackground = False
    ShowCaption = False
    StyleElements = []
    TabOrder = 0
    object shpLogo: TShape
      Left = 32
      Top = 40
      Width = 56
      Height = 56
      Brush.Color = 15426341
      Pen.Color = 15426341
      Shape = stRoundRect
    end
    object lblIcone: TLabel
      Left = 32
      Top = 40
      Width = 56
      Height = 56
      Alignment = taCenter
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -26
      Font.Name = 'Segoe MDL2 Assets'
      Font.Style = []
      ParentFont = False
      Transparent = True
      Layout = tlCenter
      StyleElements = []
    end
    object lblSistema: TLabel
      Left = 32
      Top = 116
      Width = 184
      Height = 56
      AutoSize = False
      Caption = 'Sistema'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWhite
      Font.Height = -20
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      WordWrap = True
      StyleElements = []
    end
    object lblDescricao: TLabel
      Left = 32
      Top = 176
      Width = 184
      Height = 60
      AutoSize = False
      Font.Charset = ANSI_CHARSET
      Font.Color = 11510684
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
      StyleElements = []
    end
    object lblOrganizacao: TLabel
      Left = 32
      Top = 352
      Width = 184
      Height = 17
      AutoSize = False
      Caption = ''
      Font.Charset = ANSI_CHARSET
      Font.Color = 11510684
      Font.Height = -12
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      StyleElements = []
    end
  end
  object pnlConteudo: TPanel
    Left = 240
    Top = 0
    Width = 440
    Height = 400
    Align = alClient
    BevelOuter = bvNone
    Color = 16184563
    ParentBackground = False
    ShowCaption = False
    StyleElements = []
    TabOrder = 1
    object pnlTopo: TPanel
      Left = 0
      Top = 0
      Width = 440
      Height = 64
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      ShowCaption = False
      StyleElements = []
      TabOrder = 0
      object lblTitulo: TLabel
        Left = 24
        Top = 9
        Width = 52
        Height = 25
        Caption = 'Sobre'
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -19
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblSubtitulo: TLabel
        Left = 24
        Top = 35
        Width = 200
        Height = 15
        Caption = 'Informa'#231#245'es do sistema'
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object shpLinhaTopo: TShape
        Left = 0
        Top = 63
        Width = 440
        Height = 1
        Align = alBottom
        Brush.Color = 15460325
        Pen.Color = 15460325
      end
    end
    object pnlCartao: TPanel
      Left = 24
      Top = 88
      Width = 392
      Height = 176
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      ShowCaption = False
      StyleElements = []
      TabOrder = 1
      object lblRotuloCompilacao: TLabel
        Left = 20
        Top = 12
        Width = 120
        Height = 15
        Caption = 'Data de compila'#231#227'o'
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblCompilacao: TLabel
        Left = 20
        Top = 29
        Width = 200
        Height = 19
        Caption = '--/--/----'
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -14
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object shpLinha1: TShape
        Left = 20
        Top = 58
        Width = 352
        Height = 1
        Brush.Color = 15460325
        Pen.Color = 15460325
      end
      object lblRotuloEmpresa: TLabel
        Left = 20
        Top = 68
        Width = 120
        Height = 15
        Caption = 'Desenvolvido por'
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblEmpresa: TLabel
        Left = 20
        Top = 85
        Width = 200
        Height = 19
        Caption = 'Sua Empresa'
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -14
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object shpLinha2: TShape
        Left = 20
        Top = 114
        Width = 352
        Height = 1
        Brush.Color = 15460325
        Pen.Color = 15460325
      end
      object lblRotuloContato: TLabel
        Left = 20
        Top = 124
        Width = 120
        Height = 15
        Caption = 'Contato'
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblContato: TLabel
        Left = 20
        Top = 141
        Width = 200
        Height = 19
        Cursor = crHandPoint
        Hint = 'Escrever um e-mail'
        Caption = 'contato@suaempresa.com.br'
        Font.Charset = ANSI_CHARSET
        Font.Color = 15426341
        Font.Height = -14
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        ParentShowHint = False
        ShowHint = True
        StyleElements = []
        OnClick = lblContatoClick
      end
    end
    object pnlFechar: TPanel
      Left = 300
      Top = 340
      Width = 116
      Height = 36
      Cursor = crHandPoint
      BevelOuter = bvNone
      Caption = 'Fechar'
      Color = 15426341
      Font.Charset = ANSI_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentBackground = False
      ParentFont = False
      StyleElements = []
      TabOrder = 2
      OnClick = pnlFecharClick
      OnMouseEnter = pnlFecharMouseEnter
      OnMouseLeave = pnlFecharMouseLeave
    end
  end
end
