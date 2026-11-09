unit UnSobre;

{ Tela "Sobre" no visual moderno: faixa lateral com o sistema e cartão com a
  data de compilação, quem desenvolveu e o contato.

  Uso: ExibirSobre('Vendas', 'Controle de pedidos e estoque', C_ICONE_CARRINHO);
  Desenvolvedor, contato e organização vêm de DefinirIdentidade (UnTema). }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  Tf_sobre = class(TForm)
    pnlLateral: TPanel;
    shpLogo: TShape;
    lblIcone: TLabel;
    lblSistema: TLabel;
    lblDescricao: TLabel;
    lblOrganizacao: TLabel;
    pnlConteudo: TPanel;
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    shpLinhaTopo: TShape;
    pnlCartao: TPanel;
    lblRotuloCompilacao: TLabel;
    lblCompilacao: TLabel;
    shpLinha1: TShape;
    lblRotuloEmpresa: TLabel;
    lblEmpresa: TLabel;
    shpLinha2: TShape;
    lblRotuloContato: TLabel;
    lblContato: TLabel;
    pnlFechar: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure pnlFecharClick(Sender: TObject);
    procedure pnlFecharMouseEnter(Sender: TObject);
    procedure pnlFecharMouseLeave(Sender: TObject);
    procedure lblContatoClick(Sender: TObject);
  private
    procedure AplicarTema;
  end;

{ Mostra o Sobre (modal) com o nome, a descrição e o ícone do sistema }
procedure ExibirSobre(const ASistema, ADescricao: string; const AIcone: string = '');

{ Data e hora em que o executável foi compilado (gravadas pelo linker no cabeçalho) }
function DataCompilacao: TDateTime;

var
  f_sobre: Tf_sobre;

implementation

uses
  System.DateUtils, Winapi.ShellAPI, UnTema;

{$R *.dfm}

const
  C_DATA_MINIMA = 36526;  // 01/01/2000: abaixo disso o cabeçalho não tem data real

procedure ExibirSobre(const ASistema, ADescricao, AIcone: string);
var
  LForm: Tf_sobre;
begin
  LForm := Tf_sobre.Create(Application);
  try
    LForm.lblSistema.Caption := ASistema;
    LForm.lblDescricao.Caption := ADescricao;
    if AIcone <> '' then
      LForm.lblIcone.Caption := AIcone;
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

function DataCompilacao: TDateTime;
var
  LDos: PImageDosHeader;
  LNt: PImageNtHeaders;
begin
  LDos := PImageDosHeader(HInstance);
  LNt := PImageNtHeaders(NativeUInt(HInstance) + NativeUInt(LDos._lfanew));
  Result := UnixToDateTime(LNt.FileHeader.TimeDateStamp, False);
  { Linker antigo grava uma data fixa: aí vale a data do arquivo }
  if Result < C_DATA_MINIMA then
    if not FileAge(ParamStr(0), Result) then
      Result := 0;
end;

procedure Tf_sobre.FormCreate(Sender: TObject);
var
  LData: TDateTime;
begin
  lblIcone.Font.Name := FonteIcones;
  lblIcone.Caption := C_ICONE_SOBRE;
  lblSistema.Caption := Application.Title;
  lblOrganizacao.Caption := Identidade.Organizacao;
  lblEmpresa.Caption := Identidade.Desenvolvedor;
  if Identidade.Desenvolvedor = '' then
    lblEmpresa.Caption := '—';  // DefinirIdentidade não foi chamado
  lblContato.Caption := Identidade.Contato;
  { Sem contato configurado, a linha some e o cartão encolhe }
  if Identidade.Contato = '' then
  begin
    shpLinha2.Visible := False;
    lblRotuloContato.Visible := False;
    lblContato.Visible := False;
    pnlCartao.Height := shpLinha2.Top;
  end;
  LData := DataCompilacao;
  if LData > 0 then
    lblCompilacao.Caption := FormatDateTime('dd/mm/yyyy "às" hh:nn', LData)
  else
    lblCompilacao.Caption := 'não disponível';
  AplicarTema;
end;

procedure Tf_sobre.AplicarTema;
var
  LTema: TTema;
begin
  LTema := Tema;
  Color := LTema.ConteudoFundo;
  pnlLateral.Color := LTema.MenuFundo;
  shpLogo.Brush.Color := LTema.Destaque;
  shpLogo.Pen.Color := LTema.Destaque;
  lblIcone.Font.Color := LTema.TextoSobreDestaque;
  lblSistema.Font.Color := LTema.MenuTextoForte;
  lblDescricao.Font.Color := LTema.MenuSubtexto;
  lblOrganizacao.Font.Color := LTema.MenuSubtexto;
  pnlConteudo.Color := LTema.ConteudoFundo;
  pnlTopo.Color := LTema.Superficie;
  lblTitulo.Font.Color := LTema.Texto;
  lblSubtitulo.Font.Color := LTema.TextoSecundario;
  shpLinhaTopo.Brush.Color := LTema.Borda;
  shpLinhaTopo.Pen.Color := LTema.Borda;
  pnlCartao.Color := LTema.Superficie;
  lblRotuloCompilacao.Font.Color := LTema.TextoSecundario;
  lblRotuloEmpresa.Font.Color := LTema.TextoSecundario;
  lblRotuloContato.Font.Color := LTema.TextoSecundario;
  lblCompilacao.Font.Color := LTema.Texto;
  lblEmpresa.Font.Color := LTema.Texto;
  lblContato.Font.Color := LTema.Destaque;
  shpLinha1.Brush.Color := LTema.Borda;
  shpLinha1.Pen.Color := LTema.Borda;
  shpLinha2.Brush.Color := LTema.Borda;
  shpLinha2.Pen.Color := LTema.Borda;
  pnlFechar.Color := LTema.Destaque;
  pnlFechar.Font.Color := LTema.TextoSobreDestaque;
end;

procedure Tf_sobre.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #27) or (Key = #13) then
  begin
    Key := #0;
    Close;
  end;
end;

procedure Tf_sobre.pnlFecharClick(Sender: TObject);
begin
  Close;
end;

procedure Tf_sobre.pnlFecharMouseEnter(Sender: TObject);
begin
  pnlFechar.Color := Tema.DestaqueSobre;
end;

procedure Tf_sobre.pnlFecharMouseLeave(Sender: TObject);
begin
  pnlFechar.Color := Tema.Destaque;
end;

procedure Tf_sobre.lblContatoClick(Sender: TObject);
begin
  if Identidade.Contato <> '' then
    ShellExecute(Handle, 'open', PChar('mailto:' + Identidade.Contato), nil, nil, SW_SHOWNORMAL);
end;

end.
