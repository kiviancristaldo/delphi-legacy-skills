unit UnCadastroModerno;

{ Deixa uma tela comum (cadastro, consulta, relatório com filtros) no visual
  moderno sem mexer na regra dela: só aparência, aplicada em tempo de execução.

  No FormCreate da tela (depois do que já existia lá):
    ModernizarCadastro(Self, 'Clientes', 'Cadastro e consulta de clientes');

  Os botões, edits e grades padrão ficam modernos com um estilo VCL
  (AplicarEstiloVCL no .dpr). Esta unit cuida do que o estilo não faz:
  barra de topo, fontes, cores de fundo e títulos das grades. }

interface

uses
  Vcl.Forms;

type
  TOpcaoCadastro = (
    ocBarraTopo,  // barra branca no alto com título e subtítulo
    ocFontes,     // Segoe UI no lugar de MS Sans Serif/Tahoma/Arial (mesmo tamanho)
    ocCores,      // fundo e painéis no tom do tema (só sem estilo VCL)
    ocGrades,     // títulos e cores das grades
    ocAbas,       // abas do TPageControl viram uma barra de botões arredondados
    ocNavegador); // botões do TDBNavigator com ícones modernos
  TOpcoesCadastro = set of TOpcaoCadastro;

const
  C_CADASTRO_PADRAO = [ocBarraTopo, ocFontes, ocCores, ocGrades, ocAbas, ocNavegador];

procedure ModernizarCadastro(AForm: TForm; const ATitulo: string = '';
  const ASubtitulo: string = ''; AOpcoes: TOpcoesCadastro = C_CADASTRO_PADRAO);

{ Ativa o estilo VCL do tema (Tema.EstiloVCL) ou o informado. O estilo precisa
  estar incluído no projeto (Project > Options > Application > Appearance).
  Devolve False se não estiver: o sistema segue com o visual padrão do Windows. }
function AplicarEstiloVCL(const AEstilo: string = ''): Boolean;

implementation

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  System.Generics.Collections, Vcl.Graphics, Vcl.Controls, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.Themes, Vcl.ComCtrls, Vcl.DBCtrls,
  Vcl.Buttons, Vcl.Menus, Vcl.ImgList, UnTema;

const
  C_FONTES_ANTIGAS: array[0..4] of string = ('MS Sans Serif', 'Tahoma', 'Arial',
    'Microsoft Sans Serif', 'Verdana');

  { Glifos do navegador (Segoe Fluent Icons / Segoe MDL2 Assets) }
  C_GLIFO_PRIMEIRO = #$E892;
  C_GLIFO_ANTERIOR = #$E76B;
  C_GLIFO_PROXIMO = #$E76C;
  C_GLIFO_ULTIMO = #$E893;
  C_GLIFO_ATUALIZAR = #$E72C;

  { Glifo e cor (0 neutro, 1 destaque, 2 perigo, 3 sucesso) de cada botão do
    navegador, de nbFirst a nbRefresh }
  C_GLIFOS_NAV: array[nbFirst..nbRefresh] of string = (C_GLIFO_PRIMEIRO,
    C_GLIFO_ANTERIOR, C_GLIFO_PROXIMO, C_GLIFO_ULTIMO, C_ICONE_ADICIONAR,
    C_ICONE_EXCLUIR, C_ICONE_EDITAR, C_ICONE_SUCESSO, C_ICONE_FECHAR,
    C_GLIFO_ATUALIZAR);
  C_CORES_NAV: array[nbFirst..nbRefresh] of Integer = (0, 0, 0, 0, 1, 2, 1, 3, 2, 1);

type
  { Barra de abas no lugar das abas nativas de um TPageControl: um botão
    arredondado por TTabSheet visível. O TPageControl continua o mesmo (as
    abas só ficam escondidas); o clique troca ActivePage e chama OnChanging e
    OnChange como o clique na aba. Se o código trocar ActivePage, a barra
    acompanha (conferida por um timer). }
  TAbasModernas = class(TCustomControl)
  private
    FPaginas: TPageControl;
    FAbas: TList<TTabSheet>;
    FRetangulos: TList<TRect>;
    FSobre: Integer;
    FAtivaPintada: TTabSheet;
    FTimer: TTimer;
    function E(AValor: Integer): Integer;
    procedure CalcularRetangulos;
    function AbaEm(X, Y: Integer): Integer;
    procedure Selecionar(AAba: TTabSheet);
    procedure Conferir(Sender: TObject);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; APaginas: TPageControl); reintroduce;
    destructor Destroy; override;
  end;

{ TAbasModernas }

constructor TAbasModernas.Create(AOwner: TComponent; APaginas: TPageControl);
var
  LIndice: Integer;
begin
  inherited Create(AOwner);
  FPaginas := APaginas;
  FAbas := TList<TTabSheet>.Create;
  FRetangulos := TList<TRect>.Create;
  FSobre := -1;
  for LIndice := 0 to APaginas.PageCount - 1 do
    if APaginas.Pages[LIndice].TabVisible then
      FAbas.Add(APaginas.Pages[LIndice]);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  StyleElements := [];
  Cursor := crHandPoint;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 150;
  FTimer.OnTimer := Conferir;
end;

destructor TAbasModernas.Destroy;
begin
  FRetangulos.Free;
  FAbas.Free;
  inherited;
end;

function TAbasModernas.E(AValor: Integer): Integer;
begin
  Result := Escalar(Self, AValor);
end;

procedure TAbasModernas.CalcularRetangulos;
var
  LAba: TTabSheet;
  LX, LLargura, LFolga: Integer;
begin
  FRetangulos.Clear;
  Canvas.Font.Name := Tema.FonteTitulo;
  Canvas.Font.Height := -E(13);
  { Folga lateral de cada botão: diminui se não couberem todos na largura }
  LFolga := E(16);
  repeat
    LX := E(4);
    for LAba in FAbas do
      Inc(LX, Canvas.TextWidth(StripHotkey(LAba.Caption)) + 2 * LFolga + E(4));
    if (LX <= Width) or (LFolga <= E(6)) then
      Break;
    Dec(LFolga, E(2));
  until False;

  LX := E(4);
  for LAba in FAbas do
  begin
    LLargura := Canvas.TextWidth(StripHotkey(LAba.Caption)) + 2 * LFolga;
    FRetangulos.Add(Rect(LX, E(6), LX + LLargura, Height - E(6)));
    Inc(LX, LLargura + E(4));
  end;
end;

procedure TAbasModernas.Resize;
begin
  inherited;
  if FAbas <> nil then
    CalcularRetangulos;
end;

function TAbasModernas.AbaEm(X, Y: Integer): Integer;
var
  LIndice: Integer;
begin
  Result := -1;
  for LIndice := 0 to FRetangulos.Count - 1 do
    if PtInRect(FRetangulos[LIndice], Point(X, Y)) then
      Exit(LIndice);
end;

procedure TAbasModernas.Paint;
var
  LIndice: Integer;
  LRet: TRect;
  LAba: TTabSheet;
  LTexto: string;
  LCorTexto: TColor;
  LFundo: TRect;
begin
  if FRetangulos.Count <> FAbas.Count then
    CalcularRetangulos;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Tema.ConteudoFundo;
  Canvas.FillRect(ClientRect);

  { Trilho claro atrás dos botões, como um controle segmentado }
  if FRetangulos.Count > 0 then
  begin
    LFundo := Rect(0, E(2), FRetangulos.Last.Right + E(4), Height - E(2));
    Canvas.Pen.Color := Tema.Borda;
    Canvas.Brush.Color := Tema.Superficie;
    Canvas.RoundRect(LFundo.Left, LFundo.Top, LFundo.Right, LFundo.Bottom, E(14), E(14));
  end;

  Canvas.Font.Name := Tema.FonteTitulo;
  Canvas.Font.Height := -E(13);
  Canvas.Font.Quality := fqClearType;
  for LIndice := 0 to FAbas.Count - 1 do
  begin
    LAba := FAbas[LIndice];
    LRet := FRetangulos[LIndice];
    LTexto := StripHotkey(LAba.Caption);
    if LAba = FPaginas.ActivePage then
    begin
      Canvas.Pen.Color := Tema.Destaque;
      Canvas.Brush.Color := Tema.Destaque;
      Canvas.RoundRect(LRet.Left, LRet.Top, LRet.Right, LRet.Bottom, E(10), E(10));
      LCorTexto := Tema.TextoSobreDestaque;
    end
    else
    begin
      if LIndice = FSobre then
      begin
        Canvas.Pen.Color := Tema.ConteudoFundo;
        Canvas.Brush.Color := Tema.ConteudoFundo;
        Canvas.RoundRect(LRet.Left, LRet.Top, LRet.Right, LRet.Bottom, E(10), E(10));
        LCorTexto := Tema.Texto;
      end
      else
        LCorTexto := Tema.TextoSecundario;
      if not LAba.Enabled then
        LCorTexto := Tema.Borda;
    end;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := LCorTexto;
    Canvas.TextRect(LRet, LTexto, [tfCenter, tfVerticalCenter, tfSingleLine, tfNoPrefix]);
    Canvas.Brush.Style := bsSolid;
  end;
  FAtivaPintada := FPaginas.ActivePage;
end;

procedure TAbasModernas.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  LIndice: Integer;
begin
  inherited;
  LIndice := AbaEm(X, Y);
  if LIndice <> FSobre then
  begin
    FSobre := LIndice;
    if LIndice >= 0 then
      Cursor := crHandPoint
    else
      Cursor := crDefault;
    Invalidate;
  end;
end;

procedure TAbasModernas.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FSobre <> -1 then
  begin
    FSobre := -1;
    Invalidate;
  end;
end;

procedure TAbasModernas.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LIndice: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  LIndice := AbaEm(X, Y);
  if (LIndice >= 0) and FAbas[LIndice].Enabled then
    Selecionar(FAbas[LIndice]);
end;

procedure TAbasModernas.Selecionar(AAba: TTabSheet);
var
  LPermitir: Boolean;
begin
  if AAba = FPaginas.ActivePage then
    Exit;
  { Mesma sequência do clique na aba: OnChanging pode recusar, OnChange depois }
  LPermitir := True;
  if Assigned(FPaginas.OnChanging) then
    FPaginas.OnChanging(FPaginas, LPermitir);
  if not LPermitir then
    Exit;
  FPaginas.ActivePage := AAba;
  Invalidate;
  if Assigned(FPaginas.OnChange) then
    FPaginas.OnChange(FPaginas);
end;

procedure TAbasModernas.Conferir(Sender: TObject);
begin
  if FPaginas.ActivePage <> FAtivaPintada then
    Invalidate;
end;

function AplicarEstiloVCL(const AEstilo: string): Boolean;
var
  LNome: string;
begin
  LNome := AEstilo;
  if LNome = '' then
    LNome := Tema.EstiloVCL;
  Result := (LNome <> '') and TStyleManager.TrySetStyle(LNome, False);
end;

function FonteAntiga(const ANome: string): Boolean;
var
  LNome: string;
begin
  Result := False;
  for LNome in C_FONTES_ANTIGAS do
    if SameText(ANome, LNome) then
      Exit(True);
end;

function EstiloAtivo: Boolean;
begin
  Result := TStyleManager.IsCustomStyleActive;
end;

{ Abre espaço no alto: os controles soltos descem, respeitando as âncoras }
procedure AbrirEspacoNoTopo(AForm: TForm; AAltura: Integer);
var
  LIndice: Integer;
  LControle: TControl;
begin
  if AForm.WindowState <> wsMaximized then
    AForm.ClientHeight := AForm.ClientHeight + AAltura;
  for LIndice := 0 to AForm.ControlCount - 1 do
  begin
    LControle := AForm.Controls[LIndice];
    if LControle.Align <> alNone then
      Continue;  // os alinhados se acomodam sozinhos
    if not (akTop in LControle.Anchors) then
      Continue;  // ancorado só embaixo: o form cresceu e ele já desceu
    if akBottom in LControle.Anchors then
      LControle.SetBounds(LControle.Left, LControle.Top + AAltura,
        LControle.Width, LControle.Height - AAltura)
    else
      LControle.Top := LControle.Top + AAltura;
  end;
end;

procedure CriarBarraTopo(AForm: TForm; const ATitulo, ASubtitulo: string);
var
  LTema: TTema;
  LBarra: TPanel;
  LTitulo, LSubtitulo: TLabel;
  LLinha: TShape;
begin
  LTema := Tema;
  AbrirEspacoNoTopo(AForm, Escalar(AForm, 64));

  LBarra := TPanel.Create(AForm);
  LBarra.Name := 'pnlBarraTopoModerna';
  LBarra.Parent := AForm;
  LBarra.Top := -1000;  // fica acima de qualquer outro alTop
  LBarra.Align := alTop;
  LBarra.Height := Escalar(AForm, 64);
  LBarra.BevelOuter := bvNone;
  LBarra.ShowCaption := False;
  LBarra.ParentBackground := False;
  LBarra.StyleElements := [];
  LBarra.Color := LTema.Superficie;

  LTitulo := TLabel.Create(AForm);
  LTitulo.Parent := LBarra;
  LTitulo.SetBounds(Escalar(AForm, 24), Escalar(AForm, 9), Escalar(AForm, 600), Escalar(AForm, 25));
  LTitulo.Font.Name := LTema.FonteTitulo;
  LTitulo.Font.Height := -Escalar(AForm, 19);
  LTitulo.Font.Color := LTema.Texto;
  LTitulo.StyleElements := [];
  LTitulo.Caption := ATitulo;

  LSubtitulo := TLabel.Create(AForm);
  LSubtitulo.Parent := LBarra;
  LSubtitulo.SetBounds(Escalar(AForm, 24), Escalar(AForm, 36), Escalar(AForm, 600), Escalar(AForm, 16));
  LSubtitulo.Font.Name := LTema.FonteTexto;
  LSubtitulo.Font.Height := -Escalar(AForm, 12);
  LSubtitulo.Font.Color := LTema.TextoSecundario;
  LSubtitulo.StyleElements := [];
  LSubtitulo.Caption := ASubtitulo;

  LLinha := TShape.Create(AForm);
  LLinha.Parent := LBarra;
  LLinha.Align := alBottom;
  LLinha.Height := 1;
  LLinha.Brush.Color := LTema.Borda;
  LLinha.Pen.Color := LTema.Borda;
end;

procedure AjustarControles(AControle: TWinControl; AOpcoes: TOpcoesCadastro);
var
  LIndice: Integer;
  LFilho: TControl;
  LTema: TTema;
begin
  LTema := Tema;
  for LIndice := 0 to AControle.ControlCount - 1 do
  begin
    LFilho := AControle.Controls[LIndice];
    if LFilho.Name = 'pnlBarraTopoModerna' then
      Continue;

    if (ocFontes in AOpcoes) and (LFilho is TLabel) and not TLabel(LFilho).ParentFont and
      FonteAntiga(TLabel(LFilho).Font.Name) then
      TLabel(LFilho).Font.Name := LTema.FonteTexto;

    if (ocCores in AOpcoes) and not EstiloAtivo and (LFilho is TPanel) and
      (TPanel(LFilho).Color = clBtnFace) then
    begin
      TPanel(LFilho).ParentBackground := False;
      TPanel(LFilho).Color := LTema.ConteudoFundo;
    end;

    if (ocGrades in AOpcoes) and (LFilho is TDBGrid) then
    begin
      TDBGrid(LFilho).TitleFont.Name := LTema.FonteTitulo;
      TDBGrid(LFilho).TitleFont.Color := LTema.Texto;
      if ocFontes in AOpcoes then
        if FonteAntiga(TDBGrid(LFilho).Font.Name) then
          TDBGrid(LFilho).Font.Name := LTema.FonteTexto;
      if not EstiloAtivo then
        TDBGrid(LFilho).FixedColor := LTema.ConteudoFundo;
    end
    else if (ocGrades in AOpcoes) and (LFilho is TStringGrid) then
    begin
      if ocFontes in AOpcoes then
        if FonteAntiga(TStringGrid(LFilho).Font.Name) then
          TStringGrid(LFilho).Font.Name := LTema.FonteTexto;
      if not EstiloAtivo then
        TStringGrid(LFilho).FixedColor := LTema.ConteudoFundo;
    end;

    if LFilho is TWinControl then
      AjustarControles(TWinControl(LFilho), AOpcoes);
  end;
end;

type
  TControleAcesso = class(TControl);
  TPaginasAcesso = class(TPageControl);

{ Troca as abas nativas pela barra TAbasModernas logo acima do TPageControl.
  A área das páginas fica com a mesma altura de antes: o que a barra ocupa a
  mais que as abas empurra para baixo o que estava embaixo e aumenta o form. }
procedure ModernizarAbas(APaginas: TPageControl);
var
  LAtiva: TTabSheet;
  LBarra: TAbasModernas;
  LAntes, LDepois: TRect;
  LIndice, LAltura, LAbas, LDiferenca, LFundoOriginal: Integer;
  LControle: TControl;
  LForm: TCustomForm;
begin
  if APaginas.PageCount = 0 then
    Exit;
  LBarra := TAbasModernas.Create(APaginas.Owner, APaginas);
  LAltura := Escalar(APaginas, 44);

  LAtiva := APaginas.ActivePage;
  LAntes := TPaginasAcesso(APaginas).DisplayRect;
  for LIndice := 0 to APaginas.PageCount - 1 do
    APaginas.Pages[LIndice].TabVisible := False;
  { Sem abas, o estilo botão não desenha a moldura 3D em volta das páginas }
  APaginas.Style := tsFlatButtons;
  { Sem abas visíveis o TPageControl fica sem página ativa: volta a que estava }
  APaginas.ActivePage := LAtiva;
  LDepois := TPaginasAcesso(APaginas).DisplayRect;
  LAbas := LAntes.Top - LDepois.Top;
  LFundoOriginal := APaginas.Top + APaginas.Height;

  LBarra.Parent := APaginas.Parent;
  if APaginas.Align <> alNone then
  begin
    { Alinhado: a barra entra alinhada no alto, logo antes dele }
    LBarra.Height := LAltura;
    LBarra.Top := APaginas.Top - 1;
    LBarra.Align := alTop;
    Exit;
  end;

  LBarra.SetBounds(APaginas.Left, APaginas.Top, APaginas.Width, LAltura);
  LBarra.Anchors := APaginas.Anchors - [akBottom];
  APaginas.SetBounds(APaginas.Left, APaginas.Top + LAltura, APaginas.Width,
    APaginas.Height - LAbas);

  LDiferenca := LAltura - LAbas;
  if LDiferenca <= 0 then
    Exit;
  for LIndice := 0 to APaginas.Parent.ControlCount - 1 do
  begin
    LControle := APaginas.Parent.Controls[LIndice];
    if (LControle <> APaginas) and (LControle <> LBarra) and
      (LControle.Align = alNone) and (LControle.Top >= LFundoOriginal) then
      LControle.Top := LControle.Top + LDiferenca;
  end;
  LForm := GetParentForm(APaginas);
  if (LForm <> nil) and (APaginas.Parent = LForm) and (LForm.WindowState <> wsMaximized) then
    LForm.ClientHeight := LForm.ClientHeight + LDiferenca;
end;

{ Ícone de um botão do navegador desenhado com a fonte de ícones, no fundo da
  cor do navegador (vira a máscara na lista de imagens). }
function ImagemNavegador(ANavegador: TDBNavigator; const AGlifo: string;
  ACor: TColor; ATamanho: Integer): TBitmap;
var
  LRet: TRect;
  LTexto: string;
begin
  LTexto := AGlifo;
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize(ATamanho, ATamanho);
  Result.Canvas.Brush.Color := ColorToRGB(TControleAcesso(ANavegador).Color);
  Result.Canvas.FillRect(Rect(0, 0, ATamanho, ATamanho));
  Result.Canvas.Font.Name := FonteIcones;
  Result.Canvas.Font.Height := -(ATamanho - Escalar(ANavegador, 2));
  Result.Canvas.Font.Quality := fqAntialiased;
  Result.Canvas.Font.Color := ACor;
  Result.Canvas.Brush.Style := bsClear;
  LRet := Rect(0, 0, ATamanho, ATamanho);
  Result.Canvas.TextRect(LRet, LTexto, [tfCenter, tfVerticalCenter, tfSingleLine, tfNoPrefix]);
end;

{ Mesmo TDBNavigator (cliques, hints, eventos e confirmação de exclusão
  continuam), só com botões planos e ícones da fonte de ícones. Os botões
  desenham a partir de Images/ImageIndex (o Glyph é ignorado nesta VCL):
  cada navegador ganha uma lista própria com o ícone normal e o desabilitado. }
procedure ModernizarNavegador(ANavegador: TDBNavigator);
var
  LIndice, LTamanho, LPosicao: Integer;
  LBotao: TNavButton;
  LTipo: TNavigateBtn;
  LCor: TColor;
  LLista: TImageList;
  LImagem: TBitmap;
  LFundo: TColor;
begin
  ANavegador.Flat := True;
  TControleAcesso(ANavegador).ParentColor := True;
  LFundo := ColorToRGB(TControleAcesso(ANavegador).Color);
  LTamanho := ANavegador.Height - Escalar(ANavegador, 8);
  if LTamanho < Escalar(ANavegador, 12) then
    LTamanho := Escalar(ANavegador, 12);
  if LTamanho > Escalar(ANavegador, 20) then
    LTamanho := Escalar(ANavegador, 20);
  LLista := TImageList.Create(ANavegador);
  LLista.ColorDepth := cd32Bit;
  LLista.SetSize(LTamanho, LTamanho);
  for LIndice := 0 to ANavegador.ControlCount - 1 do
  begin
    if not (ANavegador.Controls[LIndice] is TNavButton) then
      Continue;
    LBotao := TNavButton(ANavegador.Controls[LIndice]);
    LTipo := TNavigateBtn(LBotao.Index);
    if not (LTipo in [Low(C_GLIFOS_NAV)..High(C_GLIFOS_NAV)]) then
      Continue;  // nbApplyUpdates/nbCancelUpdates ficam com a imagem original
    case C_CORES_NAV[LTipo] of
      1: LCor := Tema.Destaque;
      2: LCor := Tema.Perigo;
      3: LCor := Tema.Sucesso;
    else
      LCor := Tema.Texto;
    end;
    LImagem := ImagemNavegador(ANavegador, C_GLIFOS_NAV[LTipo], LCor, LTamanho);
    try
      LPosicao := LLista.AddMasked(LImagem, LFundo);
    finally
      LImagem.Free;
    end;
    LImagem := ImagemNavegador(ANavegador, C_GLIFOS_NAV[LTipo], Tema.MarcaDagua, LTamanho);
    try
      LLista.AddMasked(LImagem, LFundo);
    finally
      LImagem.Free;
    end;
    LBotao.Images := LLista;
    LBotao.ImageIndex := LPosicao;
    LBotao.DisabledImageIndex := LPosicao + 1;
  end;
end;

procedure ListarControles(AControle: TWinControl; APaginas: TList<TPageControl>;
  ANavegadores: TList<TDBNavigator>);
var
  LIndice: Integer;
  LFilho: TControl;
begin
  for LIndice := 0 to AControle.ControlCount - 1 do
  begin
    LFilho := AControle.Controls[LIndice];
    if LFilho is TPageControl then
      APaginas.Add(TPageControl(LFilho))
    else if LFilho is TDBNavigator then
      ANavegadores.Add(TDBNavigator(LFilho));
    if (LFilho is TWinControl) and not (LFilho is TDBNavigator) then
      ListarControles(TWinControl(LFilho), APaginas, ANavegadores);
  end;
end;

procedure ModernizarAbasENavegadores(AForm: TForm; AOpcoes: TOpcoesCadastro);
var
  LPaginas: TList<TPageControl>;
  LNavegadores: TList<TDBNavigator>;
  LPagina: TPageControl;
  LNavegador: TDBNavigator;
begin
  LPaginas := TList<TPageControl>.Create;
  try
    LNavegadores := TList<TDBNavigator>.Create;
    try
      { Primeiro lista, depois mexe: ModernizarAbas cria controles novos }
      ListarControles(AForm, LPaginas, LNavegadores);
      if ocNavegador in AOpcoes then
        for LNavegador in LNavegadores do
          ModernizarNavegador(LNavegador);
      if ocAbas in AOpcoes then
        for LPagina in LPaginas do
          ModernizarAbas(LPagina);
    finally
      LNavegadores.Free;
    end;
  finally
    LPaginas.Free;
  end;
end;

procedure ModernizarCadastro(AForm: TForm; const ATitulo, ASubtitulo: string;
  AOpcoes: TOpcoesCadastro);
var
  LTitulo: string;
begin
  if (ocFontes in AOpcoes) and FonteAntiga(AForm.Font.Name) then
    AForm.Font.Name := Tema.FonteTexto;  // quem usa ParentFont acompanha
  if (ocCores in AOpcoes) and not EstiloAtivo and (AForm.Color = clBtnFace) then
    AForm.Color := Tema.ConteudoFundo;
  AjustarControles(AForm, AOpcoes);
  if ocBarraTopo in AOpcoes then
  begin
    LTitulo := ATitulo;
    if LTitulo = '' then
      LTitulo := Trim(AForm.Caption);
    CriarBarraTopo(AForm, LTitulo, ASubtitulo);
  end;
  if (ocAbas in AOpcoes) or (ocNavegador in AOpcoes) then
    ModernizarAbasENavegadores(AForm, AOpcoes);
end;

end.
