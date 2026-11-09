unit UnTema;

{ Tema visual "moderno" (menu lateral estilo web, cartões, botões arredondados).
  Todas as cores e fontes das units visuais (UnMenuLateral, UnLogin, UnSobre,
  UnBotaoModerno, UnDialogo, UnCadastroModerno) vêm daqui.

  Uso típico, no .dpr, ANTES do primeiro Application.CreateForm:
    DefinirTema(ComDestaque(TemaPadrao, cdVerde));
    DefinirIdentidade('CLÍNICA EXEMPLO', 'Sua Empresa', 'contato@suaempresa.com.br');

  Paletas inspiradas na escala Tailwind (slate/gray); o destaque padrão é azul. }

interface

uses
  Winapi.Windows, Vcl.Graphics, Vcl.Controls, Vcl.Forms;

type
  TTema = record
    Nome: string;
    { Faixa escura/lateral: menu, lateral do login e do Sobre }
    MenuFundo: TColor;
    MenuSobre: TColor;          // hover e campo de busca
    MenuBorda: TColor;          // linhas guia, avatar
    MenuTexto: TColor;
    MenuTextoForte: TColor;     // item aberto/hover, nomes
    MenuSubtexto: TColor;
    MenuDesabilitado: TColor;
    { Área de conteúdo }
    ConteudoFundo: TColor;
    Superficie: TColor;         // cartões, barra de topo, campos
    Borda: TColor;
    Texto: TColor;
    TextoSecundario: TColor;
    MarcaDagua: TColor;
    { Destaque: botão principal, item selecionado, foco }
    Destaque: TColor;
    DestaqueSobre: TColor;      // hover do botão principal
    DestaqueSuave: TColor;      // ícone do grupo que contém a opção ativa
    TextoSobreDestaque: TColor;
    { Estados }
    Sucesso: TColor;
    Aviso: TColor;
    Perigo: TColor;
    { Tipografia }
    FonteTexto: string;
    FonteTitulo: string;
    FonteFina: string;
    { Estilo VCL sugerido para os controles padrão (botões, edits, grades) das
      telas comuns; '' = não sugere. Ver referencias/cadastro.md. }
    EstiloVCL: string;
  end;

  TCorDestaque = (cdAzul, cdVerde, cdRoxo, cdLaranja, cdVermelho, cdCiano, cdRosa, cdGrafite);

  { Quem é o cliente e quem desenvolveu: aparece no menu, login e Sobre }
  TIdentidade = record
    Organizacao: string;
    Desenvolvedor: string;
    Contato: string;
  end;

{ Menu escuro + conteúdo claro: o visual de referência }
function TemaPadrao: TTema;
{ Tudo claro: menu branco com texto escuro }
function TemaClaro: TTema;
{ Tudo escuro }
function TemaEscuro: TTema;
{ Mesmo tema com outra cor de destaque }
function ComDestaque(const ATema: TTema; ACor: TCorDestaque): TTema;
{ Mesmo tema com a cor da marca do cliente (ex.: RGB(0, 120, 90)) }
function ComDestaqueRGB(const ATema: TTema; ACor, ACorSobre: TColor): TTema;

procedure DefinirTema(const ATema: TTema);
function Tema: TTema;

procedure DefinirIdentidade(const AOrganizacao, ADesenvolvedor, AContato: string);
function Identidade: TIdentidade;

{ Converte um valor desenhado em 96 dpi para o dpi do form do controle }
function Escalar(AControle: TControl; AValor: Integer): Integer;

{ Nome da fonte de ícones instalada: Segoe Fluent Icons (Windows 11) ou Segoe MDL2 Assets }
function FonteIcones: string;

const
  { Glifos da fonte de ícones (os mesmos códigos nas duas fontes) }
  C_ICONE_AGENDA = #$E787;
  C_ICONE_SISTEMA = #$E713;
  C_ICONE_PEDIDOS = #$E8A5;
  C_ICONE_DOCUMENTO = #$E8A5;
  C_ICONE_RELATORIOS = #$E9D2;
  C_ICONE_SOBRE = #$E946;
  C_ICONE_SAIR = #$E7E8;
  C_ICONE_CADASTROS = #$E8F1;
  C_ICONE_PESSOAS = #$E716;
  C_ICONE_MOVIMENTOS = #$E8AB;
  C_ICONE_PASTA = #$E8B7;
  C_ICONE_SAUDE = #$E95E;
  C_ICONE_INICIO = #$E80F;
  C_ICONE_CARRINHO = #$E7BF;
  C_ICONE_ESTOQUE = #$E8F1;
  C_ICONE_CALCULADORA = #$E8EF;
  C_ICONE_IMPRESSORA = #$E749;
  C_ICONE_EMAIL = #$E715;
  C_ICONE_BUSCA = #$E721;
  C_ICONE_INFO = #$E946;
  C_ICONE_SUCESSO = #$E73E;
  C_ICONE_AVISO = #$E7BA;
  C_ICONE_ERRO = #$EA39;
  C_ICONE_PERGUNTA = #$E9CE;
  C_ICONE_SALVAR = #$E74E;
  C_ICONE_EXCLUIR = #$E74D;
  C_ICONE_ADICIONAR = #$E710;
  C_ICONE_EDITAR = #$E70F;
  C_ICONE_FECHAR = #$E711;

implementation

uses
  System.SysUtils;

var
  GTema: TTema;
  GTemaDefinido: Boolean;
  GIdentidade: TIdentidade;

function TemaPadrao: TTema;
begin
  Result.Nome := 'Padrão';
  Result.MenuFundo := RGB(17, 24, 39);         // #111827
  Result.MenuSobre := RGB(31, 41, 55);         // #1F2937
  Result.MenuBorda := RGB(55, 65, 81);         // #374151
  Result.MenuTexto := RGB(209, 213, 219);      // #D1D5DB
  Result.MenuTextoForte := clWhite;
  Result.MenuSubtexto := RGB(156, 163, 175);   // #9CA3AF
  Result.MenuDesabilitado := RGB(75, 85, 99);  // #4B5563
  Result.ConteudoFundo := RGB(243, 244, 246);  // #F3F4F6
  Result.Superficie := clWhite;
  Result.Borda := RGB(229, 231, 235);          // #E5E7EB
  Result.Texto := RGB(17, 24, 39);             // #111827
  Result.TextoSecundario := RGB(107, 114, 128); // #6B7280
  Result.MarcaDagua := RGB(209, 213, 219);     // #D1D5DB
  Result.Destaque := RGB(37, 99, 235);         // #2563EB
  Result.DestaqueSobre := RGB(29, 78, 216);    // #1D4ED8
  Result.DestaqueSuave := RGB(96, 165, 250);   // #60A5FA
  Result.TextoSobreDestaque := clWhite;
  Result.Sucesso := RGB(22, 163, 74);          // #16A34A
  Result.Aviso := RGB(217, 119, 6);            // #D97706
  Result.Perigo := RGB(220, 38, 38);           // #DC2626
  Result.FonteTexto := 'Segoe UI';
  Result.FonteTitulo := 'Segoe UI Semibold';
  Result.FonteFina := 'Segoe UI Light';
  Result.EstiloVCL := 'Windows Modern';
end;

function TemaClaro: TTema;
begin
  Result := TemaPadrao;
  Result.Nome := 'Claro';
  Result.MenuFundo := clWhite;
  Result.MenuSobre := RGB(243, 244, 246);      // #F3F4F6
  Result.MenuBorda := RGB(229, 231, 235);      // #E5E7EB
  Result.MenuTexto := RGB(55, 65, 81);         // #374151
  Result.MenuTextoForte := RGB(17, 24, 39);    // #111827
  Result.MenuSubtexto := RGB(107, 114, 128);   // #6B7280
  Result.MenuDesabilitado := RGB(209, 213, 219); // #D1D5DB
  Result.DestaqueSuave := Result.Destaque;
end;

function TemaEscuro: TTema;
begin
  Result := TemaPadrao;
  Result.Nome := 'Escuro';
  Result.MenuFundo := RGB(2, 6, 23);           // #020617
  Result.MenuSobre := RGB(30, 41, 59);         // #1E293B
  Result.MenuBorda := RGB(51, 65, 85);         // #334155
  Result.MenuTexto := RGB(203, 213, 225);      // #CBD5E1
  Result.MenuSubtexto := RGB(148, 163, 184);   // #94A3B8
  Result.MenuDesabilitado := RGB(71, 85, 105); // #475569
  Result.ConteudoFundo := RGB(15, 23, 42);     // #0F172A
  Result.Superficie := RGB(30, 41, 59);        // #1E293B
  Result.Borda := RGB(51, 65, 85);             // #334155
  Result.Texto := RGB(241, 245, 249);          // #F1F5F9
  Result.TextoSecundario := RGB(148, 163, 184); // #94A3B8
  Result.MarcaDagua := RGB(51, 65, 85);        // #334155
  Result.EstiloVCL := 'Windows Modern Dark';
end;

function ComDestaqueRGB(const ATema: TTema; ACor, ACorSobre: TColor): TTema;
begin
  Result := ATema;
  Result.Destaque := ACor;
  Result.DestaqueSobre := ACorSobre;
  Result.DestaqueSuave := ACor;
end;

function ComDestaque(const ATema: TTema; ACor: TCorDestaque): TTema;
const
  { Destaque, hover e versão suave de cada cor }
  C_CORES: array[TCorDestaque, 0..2] of TColor = (
    ($00EB6325, $00D84E1D, $00FAA560),   // azul     #2563EB #1D4ED8 #60A5FA
    ($004AA316, $003D8015, $0080DE4A),   // verde    #16A34A #15803D #4ADE80
    ($00ED3A7C, $00D9286D, $00FA8BA7),   // roxo     #7C3AED #6D28D9 #A78BFA
    ($000C58EA, $000C41C2, $003C92FB),   // laranja  #EA580C #C2410C #FB923C
    ($002626DC, $001C1CB9, $007171F8),   // vermelho #DC2626 #B91C1C #F87171
    ($00B29108, $0090740E, $00EED322),   // ciano    #0891B2 #0E7490 #22D3EE
    ($007727DB, $005D18BE, $00B672F4),   // rosa     #DB2777 #BE185D #F472B6
    ($00695547, $00554133, $00B8A394));  // grafite  #475569 #334155 #94A3B8
begin
  Result := ATema;
  Result.Destaque := C_CORES[ACor, 0];
  Result.DestaqueSobre := C_CORES[ACor, 1];
  if ATema.MenuFundo = clWhite then
    Result.DestaqueSuave := C_CORES[ACor, 0]  // no menu claro a versão suave some
  else
    Result.DestaqueSuave := C_CORES[ACor, 2];
end;

procedure DefinirTema(const ATema: TTema);
begin
  GTema := ATema;
  GTemaDefinido := True;
end;

function Tema: TTema;
begin
  if not GTemaDefinido then
    DefinirTema(TemaPadrao);
  Result := GTema;
end;

procedure DefinirIdentidade(const AOrganizacao, ADesenvolvedor, AContato: string);
begin
  GIdentidade.Organizacao := AOrganizacao;
  GIdentidade.Desenvolvedor := ADesenvolvedor;
  GIdentidade.Contato := AContato;
end;

function Identidade: TIdentidade;
begin
  Result := GIdentidade;
end;

function Escalar(AControle: TControl; AValor: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := nil;
  if AControle <> nil then
    LForm := GetParentForm(AControle);
  if LForm <> nil then
    Result := MulDiv(AValor, LForm.CurrentPPI, 96)
  else
    Result := MulDiv(AValor, Screen.PixelsPerInch, 96);
end;

function FonteIcones: string;
begin
  if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then
    Result := 'Segoe Fluent Icons'
  else
    Result := 'Segoe MDL2 Assets';
end;

initialization
  GIdentidade.Organizacao := '';
  GIdentidade.Desenvolvedor := '';
  GIdentidade.Contato := '';

end.
