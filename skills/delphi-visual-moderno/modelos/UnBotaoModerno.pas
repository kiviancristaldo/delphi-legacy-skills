unit UnBotaoModerno;

{ Botão desenhado no visual moderno: cantos arredondados, hover, foco, ícone.
  Funciona como um TButton para o teclado: Default (Enter), Cancel (Esc),
  ModalResult, TabStop, Enter/Espaço com foco.

  É criado em código (não há pacote de design):
    LBotao := CriarBotao(pnlRodape, 'Gravar', ebPrimario, btGravarClick, C_ICONE_SALVAR);
    LBotao.SetBounds(...)  ou  LBotao.Align := alRight;

  Para os TButton/TBitBtn que já existem nos DFMs, prefira um estilo VCL
  moderno (ver referencias/cadastro.md): trocar componente muda o DFM e o
  comportamento de quem mexe no botão por código. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.Classes, System.Types, Vcl.Controls,
  Vcl.Graphics, Vcl.Forms;

type
  TEstiloBotao = (ebPrimario, ebSecundario, ebPerigo, ebLink);

  TBotaoModerno = class(TCustomControl)
  private
    FEstilo: TEstiloBotao;
    FIcone: string;
    FMouseSobre: Boolean;
    FPressionado: Boolean;
    FDefault: Boolean;
    FCancel: Boolean;
    FModalResult: TModalResult;
    procedure SetEstilo(AValor: TEstiloBotao);
    procedure SetIcone(const AValor: string);
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    function Esc(AValor: Integer): Integer;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    { Largura que cabe o texto e o ícone com folga }
    function LarguraIdeal: Integer;
    property Caption;
    property Estilo: TEstiloBotao read FEstilo write SetEstilo;
    property Icone: string read FIcone write SetIcone;
    property Default: Boolean read FDefault write FDefault;
    property Cancel: Boolean read FCancel write FCancel;
    property ModalResult: TModalResult read FModalResult write FModalResult;
    property OnClick;
    property TabStop;
    property TabOrder;
  end;

function CriarBotao(AParent: TWinControl; const ACaption: string; AEstilo: TEstiloBotao;
  AOnClick: TNotifyEvent; const AIcone: string = ''): TBotaoModerno;

implementation

uses
  System.UITypes, UnTema;

function CriarBotao(AParent: TWinControl; const ACaption: string; AEstilo: TEstiloBotao;
  AOnClick: TNotifyEvent; const AIcone: string): TBotaoModerno;
begin
  Result := TBotaoModerno.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Estilo := AEstilo;
  Result.Icone := AIcone;
  Result.OnClick := AOnClick;
  Result.Height := Result.Esc(38);
  Result.Width := Result.LarguraIdeal;
end;

{ TBotaoModerno }

constructor TBotaoModerno.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csDoubleClicks];
  DoubleBuffered := True;
  StyleElements := [];
  TabStop := True;
  Cursor := crHandPoint;
  Width := 110;
  Height := 38;
end;

function TBotaoModerno.Esc(AValor: Integer): Integer;
begin
  Result := Escalar(Self, AValor);
end;

procedure TBotaoModerno.SetEstilo(AValor: TEstiloBotao);
begin
  FEstilo := AValor;
  Invalidate;
end;

procedure TBotaoModerno.SetIcone(const AValor: string);
begin
  FIcone := AValor;
  Invalidate;
end;

function TBotaoModerno.LarguraIdeal: Integer;
begin
  Canvas.Font.Name := Tema.FonteTitulo;
  Canvas.Font.Height := -Esc(14);
  Result := Canvas.TextWidth(Caption) + Esc(40);
  if FIcone <> '' then
    Inc(Result, Esc(24));
  if Result < Esc(96) then
    Result := Esc(96);
end;

procedure TBotaoModerno.Paint;
var
  LTema: TTema;
  LFundo, LBorda, LTexto: TColor;
  LRet, LRetTexto: TRect;
  LTextoBotao: string;
  LLargura, LX: Integer;
begin
  LTema := Tema;
  { Fundo do pai nos cantos arredondados }
  if Parent <> nil then
    Canvas.Brush.Color := Parent.Brush.Color
  else
    Canvas.Brush.Color := LTema.ConteudoFundo;
  Canvas.FillRect(ClientRect);

  case FEstilo of
    ebPrimario:
      begin
        LFundo := LTema.Destaque;
        if FMouseSobre or FPressionado then
          LFundo := LTema.DestaqueSobre;
        LBorda := LFundo;
        LTexto := LTema.TextoSobreDestaque;
      end;
    ebPerigo:
      begin
        LFundo := LTema.Perigo;
        LBorda := LFundo;
        LTexto := clWhite;
      end;
    ebLink:
      begin
        LFundo := Canvas.Brush.Color;
        LBorda := LFundo;
        LTexto := LTema.Destaque;
      end;
  else
    begin
      LFundo := LTema.Superficie;
      if FMouseSobre or FPressionado then
        LFundo := LTema.ConteudoFundo;
      LBorda := LTema.Borda;
      LTexto := LTema.Texto;
    end;
  end;
  if not Enabled then
  begin
    LFundo := LTema.Borda;
    LBorda := LTema.Borda;
    LTexto := LTema.TextoSecundario;
    if FEstilo = ebLink then
      LFundo := Canvas.Brush.Color;
  end;

  LRet := ClientRect;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := LFundo;
  Canvas.Pen.Color := LBorda;
  Canvas.Pen.Width := 1;
  Canvas.RoundRect(LRet.Left, LRet.Top, LRet.Right, LRet.Bottom, Esc(10), Esc(10));

  { Anel de foco }
  if Focused and (FEstilo <> ebLink) then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := LTema.DestaqueSuave;
    Canvas.Pen.Width := Esc(2);
    InflateRect(LRet, -Esc(2), -Esc(2));
    Canvas.RoundRect(LRet.Left, LRet.Top, LRet.Right, LRet.Bottom, Esc(8), Esc(8));
    Canvas.Pen.Width := 1;
  end;

  { Ícone + texto centralizados juntos }
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := LTema.FonteTitulo;
  Canvas.Font.Height := -Esc(14);
  Canvas.Font.Color := LTexto;
  Canvas.Font.Style := [];
  if (FEstilo = ebLink) and FMouseSobre and Enabled then
    Canvas.Font.Style := [fsUnderline];
  Canvas.Font.Quality := fqClearType;
  LTextoBotao := Caption;
  LLargura := Canvas.TextWidth(LTextoBotao);
  if FIcone <> '' then
    Inc(LLargura, Esc(24));
  LX := (Width - LLargura) div 2;
  if FIcone <> '' then
  begin
    Canvas.Font.Name := FonteIcones;
    Canvas.Font.Height := -Esc(15);
    LRetTexto := Rect(LX, 0, LX + Esc(18), Height);
    Canvas.TextRect(LRetTexto, LX, (Height - Canvas.TextHeight(FIcone)) div 2, FIcone);
    Inc(LX, Esc(24));
    Canvas.Font.Name := LTema.FonteTitulo;
    Canvas.Font.Height := -Esc(14);
  end;
  LRetTexto := Rect(LX, 0, Width, Height);
  Canvas.TextRect(LRetTexto, LTextoBotao, [tfSingleLine, tfVerticalCenter, tfNoPrefix]);
  Canvas.Brush.Style := bsSolid;
end;

procedure TBotaoModerno.Click;
var
  LForm: TCustomForm;
begin
  if not Enabled then
    Exit;
  if FModalResult <> mrNone then
  begin
    LForm := GetParentForm(Self);
    if LForm <> nil then
      LForm.ModalResult := FModalResult;
  end;
  inherited Click;
end;

procedure TBotaoModerno.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = VK_SPACE) or (Key = VK_RETURN) then
  begin
    Key := 0;
    Click;
  end;
end;

procedure TBotaoModerno.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled then
  begin
    if CanFocus then
      SetFocus;
    FPressionado := True;
    Invalidate;
  end;
end;

procedure TBotaoModerno.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FPressionado := False;
  Invalidate;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TBotaoModerno.CMDialogKey(var Message: TCMDialogKey);
begin
  { Enter aciona o botão Default e Esc o Cancel, de qualquer controle do form }
  if Enabled and Visible and
    (((Message.CharCode = VK_RETURN) and FDefault) or ((Message.CharCode = VK_ESCAPE) and FCancel)) and
    (KeyDataToShiftState(Message.KeyData) = []) then
  begin
    Click;
    Message.Result := 1;
  end
  else
    inherited;
end;

procedure TBotaoModerno.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FMouseSobre := Enabled;
  Invalidate;
end;

procedure TBotaoModerno.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FMouseSobre := False;
  FPressionado := False;
  Invalidate;
end;

procedure TBotaoModerno.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  if Enabled then
    Cursor := crHandPoint
  else
    Cursor := crDefault;
  Invalidate;
end;

procedure TBotaoModerno.CMTextChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TBotaoModerno.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TBotaoModerno.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

end.
