unit UnMenuLateral;

{ Menu lateral no estilo de página web: barra escura, grupos que abrem e
  fecham, busca por nome e destaque da opção escolhida.

  As opções são montadas a partir de um TMainMenu desenhado na IDE: o texto
  (Caption), a ação (OnClick) e a permissão (Visible) continuam vindo de lá.
  Assim a rotina que liga e desliga TMenuItem.Visible conforme os acessos do
  operador vale também para o menu lateral, e incluir uma opção nova continua
  sendo só acrescentar um item no TMainMenu.

  Cores e fontes vêm do tema atual (UnTema), lido a cada pintura: trocar o
  tema e chamar AplicarTema recolore o menu. Os ícones (C_ICONE_*) ficam no
  UnTema. Como aplicar num sistema: skill delphi-visual-moderno. }

interface

uses
  Winapi.Windows, Winapi.Messages, System.Types, System.Classes,
  System.Generics.Collections, Vcl.Controls, Vcl.Graphics, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, UnTema;

type
  TMenuLateral = class;

  { Uma linha do menu: grupo (abre e fecha) ou opção (executa o OnClick) }
  TItemMenuLateral = class(TCustomControl)
  private
    FMenuLateral: TMenuLateral;
    FItemMenu: TMenuItem;
    FPai: TItemMenuLateral;
    FFilhos: TList<TItemMenuLateral>;
    FNivel: Integer;
    FTexto: string;
    FIcone: string;
    FAberto: Boolean;
    FPermitido: Boolean;
    FHabilitado: Boolean;
    FGrupoNoMenu: Boolean;
    FMouseSobre: Boolean;
    FAoClicar: TNotifyEvent;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    function Esc(AValor: Integer): Integer;
    function Selecionado: Boolean;
    function ContemSelecionado: Boolean;
    function CorIcone(AAberto: Boolean): TColor;
  protected
    procedure Paint; override;
    procedure Click; override;
  public
    constructor Create(AMenuLateral: TMenuLateral; AParent: TWinControl); reintroduce;
    destructor Destroy; override;
    function EhGrupo: Boolean;
  end;

  TMenuLateral = class(TCustomPanel)
  private
    FMarca: TPaintBox;
    FPainelBusca: TPanel;
    FFundoBusca: TPaintBox;
    FBusca: TEdit;
    FLista: TScrollBox;
    FPainelRodape: TPanel;
    FDivisoria: TPaintBox;
    FSair: TItemMenuLateral;
    FCaixaUsuario: TPaintBox;
    FItens: TList<TItemMenuLateral>;
    FSelecionado: TItemMenuLateral;
    FMenu: TMainMenu;
    FFonteIcones: string;
    FTitulo: string;
    FSubtitulo: string;
    FIconeMarca: string;
    FUsuario: string;
    FDescricaoUsuario: string;
    FReorganizando: Boolean;
    procedure CriarCabecalho;
    procedure CriarBusca;
    procedure CriarLista;
    procedure CriarRodape;
    procedure AdicionarItens(AItemMenu: TMenuItem; APai: TItemMenuLateral;
      ANivel: Integer; const AIgnorar: array of TMenuItem);
    function Buscando: Boolean;
    function ItemVisivel(AItem: TItemMenuLateral; const ABusca: string): Boolean;
    function DescendenteCombina(AItem: TItemMenuLateral; const ABusca: string): Boolean;
    function AlturaItem(AItem: TItemMenuLateral): Integer;
    function LocalizarItem(AItemMenu: TMenuItem): TItemMenuLateral;
    function PrimeiraOpcaoVisivel: TItemMenuLateral;
    procedure MarcarSelecionado(AItem: TItemMenuLateral);
    procedure ItemClicado(AItem: TItemMenuLateral);
    procedure Rolar(ADelta: Integer);
    procedure SetUsuario(const AValor: string);
    procedure SetTitulo(const AValor: string);
    procedure SetSubtitulo(const AValor: string);
    procedure MarcaPaint(Sender: TObject);
    procedure FundoBuscaPaint(Sender: TObject);
    procedure DivisoriaPaint(Sender: TObject);
    procedure CaixaUsuarioPaint(Sender: TObject);
    procedure PainelBuscaResize(Sender: TObject);
    procedure BuscaChange(Sender: TObject);
    procedure BuscaEnter(Sender: TObject);
    procedure BuscaKeyPress(Sender: TObject; var Key: Char);
    procedure ListaResize(Sender: TObject);
    procedure ListaMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Escala(AValor: Integer): Integer;
    { Cria as linhas a partir do menu; AIgnorar recebe os itens que não entram (separadores, Sair) }
    procedure Montar(AMenu: TMainMenu; const AIgnorar: array of TMenuItem);
    procedure DefinirIcone(AItemMenu: TMenuItem; const AIcone: string);
    procedure DefinirSair(AAoClicar: TNotifyEvent);
    procedure Abrir(AItemMenu: TMenuItem);
    { Relê TMenuItem.Visible: chamar depois de aplicar os acessos do operador }
    procedure AtualizarPermissoes;
    procedure Reorganizar;
    { Recolore tudo com o tema atual (depois de DefinirTema em tempo de execução) }
    procedure AplicarTema;
    { Apaga o texto da busca; devolve True se havia texto (o Esc foi usado aqui) }
    function LimparBusca: Boolean;
    { Atalhos (ShortCut) dos itens: o TMainMenu solto do form não os trata mais.
      Chamar no OnShortCut do form: Handled := FMenuLateral.TratarAtalho(Msg) }
    function TratarAtalho(var Msg: TWMKey): Boolean;
    property FonteIcones: string read FFonteIcones;
    property Titulo: string read FTitulo write SetTitulo;
    property Subtitulo: string read FSubtitulo write SetSubtitulo;
    property IconeMarca: string read FIconeMarca write FIconeMarca;
    property Usuario: string read FUsuario write SetUsuario;
    property DescricaoUsuario: string read FDescricaoUsuario write FDescricaoUsuario;
  end;

implementation

uses
  System.SysUtils;

const
  C_GLIFO_SETA_DIREITA = #$E76C;
  C_GLIFO_SETA_BAIXO = #$E70D;

function Normalizar(const ATexto: string): string;
var
  LIndice: Integer;
begin
  Result := AnsiUpperCase(Trim(ATexto));
  for LIndice := 1 to Length(Result) do
    case Ord(Result[LIndice]) of
      $C0..$C5: Result[LIndice] := 'A';
      $C7: Result[LIndice] := 'C';
      $C8..$CB: Result[LIndice] := 'E';
      $CC..$CF: Result[LIndice] := 'I';
      $D1: Result[LIndice] := 'N';
      $D2..$D6: Result[LIndice] := 'O';
      $D9..$DC: Result[LIndice] := 'U';
    end;
end;

procedure PintarTexto(ACanvas: TCanvas; ARet: TRect; const ATexto, AFonte: string;
  ATamanho: Integer; ACor: TColor; AFormato: TTextFormat);
var
  LTexto: string;
begin
  LTexto := ATexto;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Font.Name := AFonte;
  ACanvas.Font.Height := -ATamanho;
  ACanvas.Font.Color := ACor;
  ACanvas.Font.Style := [];
  ACanvas.Font.Quality := fqClearType;
  ACanvas.TextRect(ARet, LTexto, AFormato + [tfSingleLine, tfVerticalCenter, tfNoPrefix]);
  ACanvas.Brush.Style := bsSolid;
end;

procedure PintarRetanguloArredondado(ACanvas: TCanvas; const ARet: TRect;
  ARaio: Integer; ACor, ABorda: TColor);
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ACor;
  ACanvas.Pen.Color := ABorda;
  ACanvas.Pen.Width := 1;
  ACanvas.RoundRect(ARet.Left, ARet.Top, ARet.Right, ARet.Bottom, ARaio, ARaio);
end;

{ TItemMenuLateral }

constructor TItemMenuLateral.Create(AMenuLateral: TMenuLateral; AParent: TWinControl);
begin
  inherited Create(AMenuLateral);
  FMenuLateral := AMenuLateral;
  FFilhos := TList<TItemMenuLateral>.Create;
  FPermitido := True;
  FHabilitado := True;
  ControlStyle := ControlStyle + [csOpaque] - [csDoubleClicks, csSetCaption];
  DoubleBuffered := True;
  StyleElements := []; // cores próprias mesmo com estilo VCL ativo
  Cursor := crHandPoint;
  Parent := AParent;
end;

destructor TItemMenuLateral.Destroy;
begin
  FFilhos.Free;
  inherited;
end;

function TItemMenuLateral.Esc(AValor: Integer): Integer;
begin
  Result := FMenuLateral.Escala(AValor);
end;

function TItemMenuLateral.EhGrupo: Boolean;
begin
  Result := FFilhos.Count > 0;
end;

function TItemMenuLateral.Selecionado: Boolean;
begin
  Result := FMenuLateral.FSelecionado = Self;
end;

function TItemMenuLateral.ContemSelecionado: Boolean;
var
  LPai: TItemMenuLateral;
begin
  Result := False;
  if FMenuLateral.FSelecionado = nil then
    Exit;
  LPai := FMenuLateral.FSelecionado.FPai;
  while (LPai <> nil) and not Result do
  begin
    Result := LPai = Self;
    LPai := LPai.FPai;
  end;
end;

function TItemMenuLateral.CorIcone(AAberto: Boolean): TColor;
begin
  if not FHabilitado then
    Result := Tema.MenuDesabilitado
  else if Selecionado then
    Result := Tema.TextoSobreDestaque
  else if FMouseSobre then
    Result := Tema.MenuTextoForte
  else if ContemSelecionado then
    Result := Tema.DestaqueSuave
  else if AAberto then
    Result := Tema.MenuTextoForte
  else
    Result := Tema.MenuSubtexto;
end;

procedure TItemMenuLateral.Paint;
var
  LPilula, LRetTexto: TRect;
  LCorTexto: TColor;
  LAberto: Boolean;
  LXTexto, LGuia: Integer;
  LSeta: string;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Tema.MenuFundo;
  Canvas.FillRect(ClientRect);

  { Linha guia à esquerda das opções de dentro de um grupo, como num menu web }
  LPilula := Rect(Esc(12), Esc(2), Width - Esc(12), Height - Esc(2));
  if FNivel > 0 then
  begin
    LGuia := Esc(33);
    Canvas.Pen.Color := Tema.MenuBorda;
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(LGuia, 0);
    Canvas.LineTo(LGuia, Height);
    LPilula.Left := LGuia + Esc(10) + (FNivel - 1) * Esc(14);
  end;

  if Selecionado then
    PintarRetanguloArredondado(Canvas, LPilula, Esc(10), Tema.Destaque, Tema.Destaque)
  else if FMouseSobre then
    PintarRetanguloArredondado(Canvas, LPilula, Esc(10), Tema.MenuSobre, Tema.MenuSobre);

  LAberto := EhGrupo and (FAberto or FMenuLateral.Buscando);
  if not FHabilitado then
    LCorTexto := Tema.MenuDesabilitado
  else if Selecionado then
    LCorTexto := Tema.TextoSobreDestaque
  else if FMouseSobre or LAberto then
    LCorTexto := Tema.MenuTextoForte
  else if FNivel = 0 then
    LCorTexto := Tema.MenuTexto
  else
    LCorTexto := Tema.MenuSubtexto;

  LXTexto := LPilula.Left + Esc(12);
  if FNivel = 0 then
  begin
    if FIcone <> '' then
      PintarTexto(Canvas, Rect(LPilula.Left + Esc(8), 0, LPilula.Left + Esc(34), Height),
        FIcone, FMenuLateral.FonteIcones, Esc(16), CorIcone(LAberto), [tfCenter]);
    LXTexto := LPilula.Left + Esc(44);
  end;

  LRetTexto := Rect(LXTexto, 0, LPilula.Right - Esc(8), Height);
  if EhGrupo then
  begin
    if LAberto then
      LSeta := C_GLIFO_SETA_BAIXO
    else
      LSeta := C_GLIFO_SETA_DIREITA;
    PintarTexto(Canvas, Rect(LPilula.Right - Esc(30), 0, LPilula.Right - Esc(8), Height),
      LSeta, FMenuLateral.FonteIcones, Esc(10), CorIcone(LAberto), [tfCenter]);
    LRetTexto.Right := LPilula.Right - Esc(32);
  end;

  if FNivel = 0 then
    PintarTexto(Canvas, LRetTexto, FTexto, Tema.FonteTexto, Esc(14), LCorTexto, [tfEndEllipsis])
  else
    PintarTexto(Canvas, LRetTexto, FTexto, Tema.FonteTexto, Esc(13), LCorTexto, [tfEndEllipsis]);
end;

procedure TItemMenuLateral.Click;
begin
  inherited;
  FMenuLateral.ItemClicado(Self);
end;

procedure TItemMenuLateral.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FMouseSobre := FHabilitado;
  Invalidate;
end;

procedure TItemMenuLateral.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FMouseSobre := False;
  Invalidate;
end;

procedure TItemMenuLateral.WMMouseWheel(var Message: TWMMouseWheel);
begin
  { A roda do mouse rola a lista inteira, esteja o cursor sobre qual linha estiver }
  FMenuLateral.Rolar(Message.WheelDelta);
  Message.Result := 1;
end;

{ TMenuLateral }

constructor TMenuLateral.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItens := TList<TItemMenuLateral>.Create;
  FTitulo := Application.Title;
  FSubtitulo := Identidade.Organizacao;
  FIconeMarca := C_ICONE_AGENDA;
  FDescricaoUsuario := 'Operador';
  BevelOuter := bvNone;
  ShowCaption := False;
  ParentBackground := False;
  StyleElements := []; // com estilo VCL (ex.: Windows10) a VCL ignoraria as cores
  Color := Tema.MenuFundo;
  { Qualificado: dentro da classe, FonteIcones é a propriedade (lê o próprio campo) }
  FFonteIcones := UnTema.FonteIcones;
end;

destructor TMenuLateral.Destroy;
begin
  FSelecionado := nil;
  FreeAndNil(FItens);
  inherited;
end;

function TMenuLateral.Escala(AValor: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(Self);
  if LForm <> nil then
    Result := MulDiv(AValor, LForm.CurrentPPI, 96)
  else
    Result := AValor;
end;

procedure TMenuLateral.Montar(AMenu: TMainMenu; const AIgnorar: array of TMenuItem);
var
  LIndice: Integer;
begin
  FMenu := AMenu;
  Width := Escala(272);
  CriarCabecalho;
  CriarBusca;
  CriarRodape;
  CriarLista;
  for LIndice := 0 to AMenu.Items.Count - 1 do
    AdicionarItens(AMenu.Items[LIndice], nil, 0, AIgnorar);
  AtualizarPermissoes;
end;

procedure TMenuLateral.CriarCabecalho;
begin
  FMarca := TPaintBox.Create(Self);
  FMarca.Parent := Self;
  FMarca.Align := alTop;
  FMarca.Height := Escala(76);
  FMarca.OnPaint := MarcaPaint;
end;

procedure TMenuLateral.CriarBusca;
begin
  FPainelBusca := TPanel.Create(Self);
  FPainelBusca.Parent := Self;
  FPainelBusca.Top := Escala(1000);
  FPainelBusca.Align := alTop;
  FPainelBusca.Height := Escala(58);
  FPainelBusca.BevelOuter := bvNone;
  FPainelBusca.ShowCaption := False;
  FPainelBusca.ParentBackground := False;
  FPainelBusca.StyleElements := [];
  FPainelBusca.Color := Tema.MenuFundo;
  FPainelBusca.OnResize := PainelBuscaResize;

  FFundoBusca := TPaintBox.Create(Self);
  FFundoBusca.Parent := FPainelBusca;
  FFundoBusca.Align := alClient;
  FFundoBusca.OnPaint := FundoBuscaPaint;

  FBusca := TEdit.Create(Self);
  FBusca.Parent := FPainelBusca;
  FBusca.BorderStyle := bsNone;
  FBusca.StyleElements := [];
  FBusca.Color := Tema.MenuSobre;
  FBusca.Font.Name := Tema.FonteTexto;
  FBusca.Font.Height := -Escala(13);
  FBusca.Font.Color := Tema.MenuTextoForte;
  FBusca.TextHint := 'Buscar no menu...';
  FBusca.OnChange := BuscaChange;
  FBusca.OnEnter := BuscaEnter;
  FBusca.OnExit := BuscaEnter;
  FBusca.OnKeyPress := BuscaKeyPress;
end;

procedure TMenuLateral.CriarLista;
begin
  FLista := TScrollBox.Create(Self);
  FLista.Parent := Self;
  FLista.Align := alClient;
  FLista.BorderStyle := bsNone;
  FLista.ParentBackground := False;
  FLista.StyleElements := [];
  FLista.Color := Tema.MenuFundo;
  FLista.DoubleBuffered := True;
  FLista.HorzScrollBar.Visible := False;
  FLista.VertScrollBar.Tracking := True;
  FLista.OnResize := ListaResize;
  FLista.OnMouseWheel := ListaMouseWheel;
end;

procedure TMenuLateral.CriarRodape;
begin
  FPainelRodape := TPanel.Create(Self);
  FPainelRodape.Parent := Self;
  FPainelRodape.Align := alBottom;
  FPainelRodape.Height := Escala(9 + 44 + 64);
  FPainelRodape.BevelOuter := bvNone;
  FPainelRodape.ShowCaption := False;
  FPainelRodape.ParentBackground := False;
  FPainelRodape.StyleElements := [];
  FPainelRodape.Color := Tema.MenuFundo;

  FDivisoria := TPaintBox.Create(Self);
  FDivisoria.Parent := FPainelRodape;
  FDivisoria.Top := 0;
  FDivisoria.Align := alTop;
  FDivisoria.Height := Escala(9);
  FDivisoria.OnPaint := DivisoriaPaint;

  FSair := TItemMenuLateral.Create(Self, FPainelRodape);
  FSair.FTexto := 'Sair';
  FSair.FIcone := C_ICONE_SAIR;
  FSair.Top := Escala(100);
  FSair.Align := alTop;
  FSair.Height := Escala(44);

  FCaixaUsuario := TPaintBox.Create(Self);
  FCaixaUsuario.Parent := FPainelRodape;
  FCaixaUsuario.Align := alClient;
  FCaixaUsuario.OnPaint := CaixaUsuarioPaint;
end;

procedure TMenuLateral.AdicionarItens(AItemMenu: TMenuItem; APai: TItemMenuLateral;
  ANivel: Integer; const AIgnorar: array of TMenuItem);
var
  LItem: TItemMenuLateral;
  LIndice: Integer;
begin
  if AItemMenu.IsLine then
    Exit;
  for LIndice := Low(AIgnorar) to High(AIgnorar) do
    if AIgnorar[LIndice] = AItemMenu then
      Exit;

  LItem := TItemMenuLateral.Create(Self, FLista);
  LItem.FItemMenu := AItemMenu;
  LItem.FTexto := Trim(StripHotkey(AItemMenu.Caption));
  LItem.FNivel := ANivel;
  LItem.FGrupoNoMenu := AItemMenu.Count > 0;
  LItem.FPai := APai;
  if APai <> nil then
    APai.FFilhos.Add(LItem);
  FItens.Add(LItem);

  for LIndice := 0 to AItemMenu.Count - 1 do
    AdicionarItens(AItemMenu.Items[LIndice], LItem, ANivel + 1, AIgnorar);
end;

function TMenuLateral.LocalizarItem(AItemMenu: TMenuItem): TItemMenuLateral;
var
  LItem: TItemMenuLateral;
begin
  Result := nil;
  for LItem in FItens do
    if LItem.FItemMenu = AItemMenu then
      Exit(LItem);
end;

procedure TMenuLateral.DefinirIcone(AItemMenu: TMenuItem; const AIcone: string);
var
  LItem: TItemMenuLateral;
begin
  LItem := LocalizarItem(AItemMenu);
  if LItem <> nil then
  begin
    LItem.FIcone := AIcone;
    LItem.Invalidate;
  end;
end;

procedure TMenuLateral.DefinirSair(AAoClicar: TNotifyEvent);
begin
  FSair.FAoClicar := AAoClicar;
end;

procedure TMenuLateral.Abrir(AItemMenu: TMenuItem);
var
  LItem, LPai: TItemMenuLateral;
begin
  LItem := LocalizarItem(AItemMenu);
  if (LItem = nil) or not LItem.EhGrupo then
    Exit;
  LPai := LItem;
  while LPai <> nil do
  begin
    LPai.FAberto := True;
    LPai := LPai.FPai;
  end;
  Reorganizar;
end;

procedure TMenuLateral.AtualizarPermissoes;
var
  LIndice: Integer;
  LItem, LFilho: TItemMenuLateral;
  LAlgumFilho: Boolean;
begin
  { Pais antes dos filhos: opção dentro de grupo escondido também some }
  for LItem in FItens do
  begin
    LItem.FPermitido := LItem.FItemMenu.Visible and
      ((LItem.FPai = nil) or LItem.FPai.FPermitido);
    LItem.FHabilitado := LItem.FItemMenu.Enabled and
      ((LItem.FPai = nil) or LItem.FPai.FHabilitado);
    LItem.Cursor := crHandPoint;
    if not LItem.FHabilitado then
      LItem.Cursor := crDefault;
  end;

  { Filhos antes dos pais: grupo sem nenhuma opção liberada some (inclusive o
    grupo que só tinha itens deixados de fora, como separador e Sair) }
  for LIndice := FItens.Count - 1 downto 0 do
  begin
    LItem := FItens[LIndice];
    if LItem.FGrupoNoMenu and LItem.FPermitido then
    begin
      LAlgumFilho := False;
      for LFilho in LItem.FFilhos do
        LAlgumFilho := LAlgumFilho or LFilho.FPermitido;
      LItem.FPermitido := LAlgumFilho;
    end;
  end;

  if (FSelecionado <> nil) and not FSelecionado.FPermitido then
    FSelecionado := nil;
  Reorganizar;
end;

function TMenuLateral.Buscando: Boolean;
begin
  Result := (FBusca <> nil) and (Trim(FBusca.Text) <> '');
end;

function TMenuLateral.DescendenteCombina(AItem: TItemMenuLateral; const ABusca: string): Boolean;
var
  LFilho: TItemMenuLateral;
begin
  Result := False;
  for LFilho in AItem.FFilhos do
    if LFilho.FPermitido and ((Pos(ABusca, Normalizar(LFilho.FTexto)) > 0) or
      DescendenteCombina(LFilho, ABusca)) then
      Exit(True);
end;

function TMenuLateral.ItemVisivel(AItem: TItemMenuLateral; const ABusca: string): Boolean;
var
  LPai: TItemMenuLateral;
begin
  Result := AItem.FPermitido;
  if not Result then
    Exit;

  LPai := AItem.FPai;
  if ABusca = '' then
  begin
    { Sem busca: aparece se todos os grupos acima estiverem abertos }
    while Result and (LPai <> nil) do
    begin
      Result := LPai.FAberto;
      LPai := LPai.FPai;
    end;
    Exit;
  end;

  { Com busca: aparece se o texto combina, se combina com um grupo acima
    (mostra o grupo inteiro) ou se é o caminho até uma opção que combina }
  if Pos(ABusca, Normalizar(AItem.FTexto)) > 0 then
    Exit(True);
  while LPai <> nil do
  begin
    if Pos(ABusca, Normalizar(LPai.FTexto)) > 0 then
      Exit(True);
    LPai := LPai.FPai;
  end;
  Result := DescendenteCombina(AItem, ABusca);
end;

function TMenuLateral.AlturaItem(AItem: TItemMenuLateral): Integer;
begin
  if AItem.FNivel = 0 then
    Result := Escala(44)
  else
    Result := Escala(36);
end;

procedure TMenuLateral.Reorganizar;
var
  LItem: TItemMenuLateral;
  LBusca: string;
  LTopo, LDeslocamento, LLargura: Integer;
  LVisivel: Boolean;
begin
  if (FLista = nil) or FReorganizando then
    Exit;
  FReorganizando := True;
  FLista.DisableAlign;
  try
    LBusca := Normalizar(FBusca.Text);
    LDeslocamento := FLista.VertScrollBar.Position;
    LLargura := FLista.ClientWidth;
    LTopo := Escala(4);
    for LItem in FItens do
    begin
      LVisivel := ItemVisivel(LItem, LBusca);
      if LVisivel then
      begin
        if (LItem.FNivel = 0) and (LTopo > Escala(4)) then
          Inc(LTopo, Escala(2));
        LItem.SetBounds(0, LTopo - LDeslocamento, LLargura, AlturaItem(LItem));
        Inc(LTopo, LItem.Height);
      end;
      LItem.Visible := LVisivel;
    end;
    FLista.VertScrollBar.Range := LTopo + Escala(8);

    { A barra de rolagem pode ter aparecido ou sumido e mudado a largura útil }
    if FLista.ClientWidth <> LLargura then
      for LItem in FItens do
        LItem.Width := FLista.ClientWidth;
  finally
    FLista.EnableAlign;
    FReorganizando := False;
  end;

  for LItem in FItens do
    if LItem.Visible then
      LItem.Invalidate;
end;

function TMenuLateral.PrimeiraOpcaoVisivel: TItemMenuLateral;
var
  LItem: TItemMenuLateral;
begin
  Result := nil;
  for LItem in FItens do
    if LItem.Visible and not LItem.EhGrupo then
      Exit(LItem);
end;

procedure TMenuLateral.MarcarSelecionado(AItem: TItemMenuLateral);
var
  LItem: TItemMenuLateral;
begin
  FSelecionado := AItem;
  for LItem in FItens do
    if LItem.Visible then
    begin
      LItem.Invalidate;
      LItem.Update;
    end;
end;

procedure TMenuLateral.ItemClicado(AItem: TItemMenuLateral);
var
  LItem: TItemMenuLateral;
  LAbrir: Boolean;
begin
  if not AItem.FHabilitado then
    Exit;
  if AItem.EhGrupo then
  begin
    if Buscando then
      Exit;
    LAbrir := not AItem.FAberto;
    { Um grupo principal aberto por vez, como um acordeão }
    if AItem.FNivel = 0 then
      for LItem in FItens do
        if LItem.FNivel = 0 then
          LItem.FAberto := False;
    AItem.FAberto := LAbrir;
    Reorganizar;
    Exit;
  end;

  if AItem.FItemMenu = nil then
  begin
    if Assigned(AItem.FAoClicar) then
      AItem.FAoClicar(AItem);
    Exit;
  end;

  MarcarSelecionado(AItem);
  AItem.FItemMenu.Click;

  { A tela aberta é modal: na volta o mouse pode já não estar sobre a linha }
  AItem.FMouseSobre := PtInRect(AItem.ClientRect, AItem.ScreenToClient(Mouse.CursorPos));
  AItem.Invalidate;
end;

procedure TMenuLateral.Rolar(ADelta: Integer);
begin
  if FLista <> nil then
    FLista.VertScrollBar.Position := FLista.VertScrollBar.Position -
      MulDiv(ADelta, Escala(44), WHEEL_DELTA);
end;

procedure TMenuLateral.AplicarTema;
var
  LItem: TItemMenuLateral;
begin
  Color := Tema.MenuFundo;
  if FPainelBusca <> nil then
    FPainelBusca.Color := Tema.MenuFundo;
  if FBusca <> nil then
  begin
    FBusca.Color := Tema.MenuSobre;
    FBusca.Font.Color := Tema.MenuTextoForte;
  end;
  if FLista <> nil then
    FLista.Color := Tema.MenuFundo;
  if FPainelRodape <> nil then
    FPainelRodape.Color := Tema.MenuFundo;
  Invalidate;
  if FMarca <> nil then
    FMarca.Invalidate;
  if FFundoBusca <> nil then
    FFundoBusca.Invalidate;
  if FDivisoria <> nil then
    FDivisoria.Invalidate;
  if FCaixaUsuario <> nil then
    FCaixaUsuario.Invalidate;
  if FSair <> nil then
    FSair.Invalidate;
  for LItem in FItens do
    LItem.Invalidate;
end;

function TMenuLateral.LimparBusca: Boolean;
begin
  Result := Buscando;
  if Result then
    FBusca.Text := '';
end;

function TMenuLateral.TratarAtalho(var Msg: TWMKey): Boolean;
begin
  Result := (FMenu <> nil) and FMenu.IsShortCut(Msg);
end;

procedure TMenuLateral.SetUsuario(const AValor: string);
begin
  FUsuario := Trim(AValor);
  if FCaixaUsuario <> nil then
    FCaixaUsuario.Invalidate;
end;

procedure TMenuLateral.SetTitulo(const AValor: string);
begin
  FTitulo := AValor;
  if FMarca <> nil then
    FMarca.Invalidate;
end;

procedure TMenuLateral.SetSubtitulo(const AValor: string);
begin
  FSubtitulo := AValor;
  if FMarca <> nil then
    FMarca.Invalidate;
end;

procedure TMenuLateral.MarcaPaint(Sender: TObject);
var
  LCanvas: TCanvas;
  LLogo: TRect;
begin
  LCanvas := FMarca.Canvas;
  LCanvas.Brush.Color := Tema.MenuFundo;
  LCanvas.FillRect(FMarca.ClientRect);

  LLogo := Rect(Escala(20), Escala(20), Escala(56), Escala(56));
  PintarRetanguloArredondado(LCanvas, LLogo, Escala(12), Tema.Destaque, Tema.Destaque);
  PintarTexto(LCanvas, LLogo, FIconeMarca, FFonteIcones, Escala(18), Tema.TextoSobreDestaque, [tfCenter]);

  PintarTexto(LCanvas, Rect(Escala(68), Escala(18), FMarca.Width - Escala(12), Escala(40)),
    FTitulo, Tema.FonteTitulo, Escala(17), Tema.MenuTextoForte, [tfEndEllipsis]);
  PintarTexto(LCanvas, Rect(Escala(68), Escala(39), FMarca.Width - Escala(12), Escala(58)),
    FSubtitulo, Tema.FonteTexto, Escala(12), Tema.MenuSubtexto, [tfEndEllipsis]);
end;

procedure TMenuLateral.FundoBuscaPaint(Sender: TObject);
var
  LCanvas: TCanvas;
  LCaixa: TRect;
  LBorda: TColor;
begin
  LCanvas := FFundoBusca.Canvas;
  LCanvas.Brush.Color := Tema.MenuFundo;
  LCanvas.FillRect(FFundoBusca.ClientRect);

  if FBusca.Focused then
    LBorda := Tema.Destaque
  else
    LBorda := Tema.MenuBorda;
  LCaixa := Rect(Escala(16), Escala(8), FFundoBusca.Width - Escala(16), Escala(46));
  PintarRetanguloArredondado(LCanvas, LCaixa, Escala(10), Tema.MenuSobre, LBorda);
  PintarTexto(LCanvas, Rect(LCaixa.Left + Escala(8), LCaixa.Top, LCaixa.Left + Escala(32), LCaixa.Bottom),
    C_ICONE_BUSCA, FFonteIcones, Escala(13), Tema.MenuSubtexto, [tfCenter]);
end;

procedure TMenuLateral.DivisoriaPaint(Sender: TObject);
var
  LCanvas: TCanvas;
  LMeio: Integer;
begin
  LCanvas := FDivisoria.Canvas;
  LCanvas.Brush.Color := Tema.MenuFundo;
  LCanvas.FillRect(FDivisoria.ClientRect);
  LMeio := FDivisoria.Height div 2;
  LCanvas.Pen.Color := Tema.MenuSobre;
  LCanvas.Pen.Width := 1;
  LCanvas.MoveTo(Escala(16), LMeio);
  LCanvas.LineTo(FDivisoria.Width - Escala(16), LMeio);
end;

procedure TMenuLateral.CaixaUsuarioPaint(Sender: TObject);
var
  LCanvas: TCanvas;
  LAvatar: TRect;
  LMeio: Integer;
begin
  LCanvas := FCaixaUsuario.Canvas;
  LCanvas.Brush.Color := Tema.MenuFundo;
  LCanvas.FillRect(FCaixaUsuario.ClientRect);
  if FUsuario = '' then
    Exit;

  LMeio := FCaixaUsuario.Height div 2;
  LAvatar := Rect(Escala(22), LMeio - Escala(18), Escala(58), LMeio + Escala(18));
  LCanvas.Brush.Color := Tema.MenuBorda;
  LCanvas.Pen.Color := Tema.MenuBorda;
  LCanvas.Ellipse(LAvatar);
  PintarTexto(LCanvas, LAvatar, AnsiUpperCase(Copy(FUsuario, 1, 1)), Tema.FonteTitulo,
    Escala(15), Tema.MenuTextoForte, [tfCenter]);

  PintarTexto(LCanvas, Rect(Escala(70), LMeio - Escala(18), FCaixaUsuario.Width - Escala(12), LMeio),
    FUsuario, Tema.FonteTitulo, Escala(13), Tema.MenuTextoForte, [tfEndEllipsis]);
  PintarTexto(LCanvas, Rect(Escala(70), LMeio, FCaixaUsuario.Width - Escala(12), LMeio + Escala(18)),
    FDescricaoUsuario, Tema.FonteTexto, Escala(12), Tema.MenuSubtexto, [tfEndEllipsis]);
end;

procedure TMenuLateral.PainelBuscaResize(Sender: TObject);
var
  LEsquerda: Integer;
begin
  { Caixa desenhada de Escala(16) a Escala(46); o edit sem borda fica dentro dela }
  LEsquerda := Escala(16 + 34);
  FBusca.SetBounds(LEsquerda, Escala(8) + (Escala(38) - FBusca.Height) div 2,
    FPainelBusca.Width - LEsquerda - Escala(16 + 10), FBusca.Height);
end;

procedure TMenuLateral.BuscaChange(Sender: TObject);
begin
  FLista.VertScrollBar.Position := 0;
  Reorganizar;
end;

procedure TMenuLateral.BuscaEnter(Sender: TObject);
begin
  FFundoBusca.Invalidate;
end;

procedure TMenuLateral.BuscaKeyPress(Sender: TObject; var Key: Char);
var
  LItem: TItemMenuLateral;
begin
  if Key = #13 then
  begin
    Key := #0;
    LItem := PrimeiraOpcaoVisivel;
    if LItem <> nil then
      ItemClicado(LItem);
  end;
end;

procedure TMenuLateral.ListaResize(Sender: TObject);
begin
  Reorganizar;
end;

procedure TMenuLateral.ListaMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  Rolar(WheelDelta);
  Handled := True;
end;

end.
