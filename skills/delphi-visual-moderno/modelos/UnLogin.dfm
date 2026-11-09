object f_Login: Tf_Login
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Entrar'
  ClientHeight = 400
  ClientWidth = 680
  Color = 16184563
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 2562065
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  StyleElements = []
  OnCreate = FormCreate
  OnKeyPress = FormKeyPress
  OnShow = FormShow
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
    object lblBoasVindas: TLabel
      Left = 32
      Top = 176
      Width = 184
      Height = 60
      AutoSize = False
      Caption = 'Bem-vindo(a)! Entre para acessar o sistema.'
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
    object lblTitulo: TLabel
      Left = 40
      Top = 40
      Width = 63
      Height = 32
      Caption = 'Entrar'
      Font.Charset = ANSI_CHARSET
      Font.Color = 2562065
      Font.Height = -24
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      StyleElements = []
    end
    object lblSubtitulo: TLabel
      Left = 40
      Top = 76
      Width = 360
      Height = 17
      AutoSize = False
      Caption = 'Informe seu operador e sua senha'
      Font.Charset = ANSI_CHARSET
      Font.Color = 8417899
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      StyleElements = []
    end
    object lblUsuario: TLabel
      Left = 40
      Top = 120
      Width = 360
      Height = 17
      AutoSize = False
      Caption = 'Operador'
      Font.Charset = ANSI_CHARSET
      Font.Color = 5325111
      Font.Height = -13
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      StyleElements = []
    end
    object lblSenha: TLabel
      Left = 40
      Top = 196
      Width = 360
      Height = 17
      AutoSize = False
      Caption = 'Senha'
      Font.Charset = ANSI_CHARSET
      Font.Color = 5325111
      Font.Height = -13
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      StyleElements = []
    end
    object lblCancelar: TLabel
      Left = 40
      Top = 340
      Width = 360
      Height = 17
      Cursor = crHandPoint
      Alignment = taCenter
      AutoSize = False
      Caption = 'Cancelar'
      Font.Charset = ANSI_CHARSET
      Font.Color = 8417899
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      StyleElements = []
      OnClick = lblCancelarClick
    end
    object pnlUsuario: TPanel
      Left = 40
      Top = 140
      Width = 360
      Height = 40
      BevelOuter = bvNone
      Color = 16184563
      ParentBackground = False
      ShowCaption = False
      StyleElements = []
      TabOrder = 0
      object shpUsuario: TShape
        Left = 0
        Top = 0
        Width = 360
        Height = 40
        Align = alClient
        Brush.Color = clWhite
        Pen.Color = 14407121
        Shape = stRoundRect
      end
      object d_usuario: TEdit
        Left = 12
        Top = 10
        Width = 336
        Height = 20
        BorderStyle = bsNone
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        MaxLength = 10
        ParentFont = False
        StyleElements = []
        TabOrder = 0
        OnEnter = d_usuarioEnter
        OnExit = d_usuarioExit
      end
    end
    object pnlSenha: TPanel
      Left = 40
      Top = 216
      Width = 360
      Height = 40
      BevelOuter = bvNone
      Color = 16184563
      ParentBackground = False
      ShowCaption = False
      StyleElements = []
      TabOrder = 1
      object shpSenha: TShape
        Left = 0
        Top = 0
        Width = 360
        Height = 40
        Align = alClient
        Brush.Color = clWhite
        Pen.Color = 14407121
        Shape = stRoundRect
      end
      object d_senha: TEdit
        Left = 12
        Top = 10
        Width = 336
        Height = 20
        BorderStyle = bsNone
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        MaxLength = 15
        ParentFont = False
        PasswordChar = #9679
        StyleElements = []
        TabOrder = 0
        OnEnter = d_senhaEnter
        OnExit = d_senhaExit
      end
    end
    object pnlEntrar: TPanel
      Left = 40
      Top = 284
      Width = 360
      Height = 42
      Cursor = crHandPoint
      BevelOuter = bvNone
      Caption = 'Entrar'
      Color = 15426341
      Font.Charset = ANSI_CHARSET
      Font.Color = clWhite
      Font.Height = -14
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentBackground = False
      ParentFont = False
      StyleElements = []
      TabOrder = 2
      OnClick = pnlEntrarClick
      OnMouseEnter = pnlEntrarMouseEnter
      OnMouseLeave = pnlEntrarMouseLeave
    end
  end
end
