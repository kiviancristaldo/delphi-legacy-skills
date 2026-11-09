unit UnLogin;

{ Tela de login no visual moderno (faixa lateral + cartão claro).

  A tela cuida só do visual. A regra do login (consulta, senha, usuário ativo,
  variáveis globais) é de cada sistema, numa classe que implementa
  IAutenticacaoLogin. Assim o comportamento do login antigo é preservado:
  as mesmas mensagens, a mesma ordem de checagem, as mesmas globais.

  Uso, no UnOperador (ou equivalente) do sistema:
    function FazerLogin: Boolean;
    begin
      Result := ExecutarLogin(TLoginSistema.Create, 'Vendas', C_ICONE_CARRINHO);
    end;
  e no principal: if not FazerLogin then <o que o sistema fazia na desistência>. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  { O que a tela faz depois da tentativa de login }
  TResultadoLogin = (
    rlEntrou,           // login aceito: fecha a tela com sucesso
    rlCorrigirUsuario,  // volta o foco para o usuário
    rlCorrigirSenha,    // limpa a senha e volta o foco para ela
    rlEncerrar,         // fecha a tela sem login (ex.: usuário inativo)
    rlPermanecer);      // continua na tela, sem mexer nos campos

  { Regra de login de um sistema. As mensagens ao usuário são dadas aqui dentro,
    como no login antigo. }
  IAutenticacaoLogin = interface
    ['{6B1E2C3A-8F4D-4E7B-9A21-3C5D7E9F1A24}']
    function Autenticar(const AUsuario, ASenha: string): TResultadoLogin;
  end;

  Tf_Login = class(TForm)
    pnlLateral: TPanel;
    shpLogo: TShape;
    lblIcone: TLabel;
    lblSistema: TLabel;
    lblBoasVindas: TLabel;
    lblOrganizacao: TLabel;
    pnlConteudo: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    lblUsuario: TLabel;
    pnlUsuario: TPanel;
    shpUsuario: TShape;
    d_usuario: TEdit;
    lblSenha: TLabel;
    pnlSenha: TPanel;
    shpSenha: TShape;
    d_senha: TEdit;
    pnlEntrar: TPanel;
    lblCancelar: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure pnlEntrarClick(Sender: TObject);
    procedure pnlEntrarMouseEnter(Sender: TObject);
    procedure pnlEntrarMouseLeave(Sender: TObject);
    procedure lblCancelarClick(Sender: TObject);
    procedure d_usuarioEnter(Sender: TObject);
    procedure d_usuarioExit(Sender: TObject);
    procedure d_senhaEnter(Sender: TObject);
    procedure d_senhaExit(Sender: TObject);
  private
    FAutenticacao: IAutenticacaoLogin;
    FEntrou: Boolean;
    procedure AplicarTema;
    procedure Entrar;
  end;

{ Mostra a tela (modal) e devolve True se a regra do sistema aceitou o login.
  ARotuloUsuario: como o sistema chama o usuário ('Usuário', 'Operador', 'Login').
  AUsuarioMaiusculo: digita o usuário em maiúsculas (CharCase), para bancos que
  guardam o login assim. A senha nunca é convertida. }
function ExecutarLogin(const AAutenticacao: IAutenticacaoLogin; const ASistema: string;
  const AIcone: string = ''; const ARotuloUsuario: string = 'Usuário';
  AUsuarioMaiusculo: Boolean = False): Boolean;

var
  f_Login: Tf_Login;

implementation

uses
  UnTema;

{$R *.dfm}

function ExecutarLogin(const AAutenticacao: IAutenticacaoLogin; const ASistema,
  AIcone, ARotuloUsuario: string; AUsuarioMaiusculo: Boolean): Boolean;
var
  LForm: Tf_Login;
begin
  LForm := Tf_Login.Create(Application);
  try
    LForm.FAutenticacao := AAutenticacao;
    LForm.lblSistema.Caption := ASistema;
    LForm.Caption := 'Entrar - ' + ASistema;
    if AIcone <> '' then
      LForm.lblIcone.Caption := AIcone;
    LForm.lblUsuario.Caption := ARotuloUsuario;
    LForm.lblSubtitulo.Caption := 'Informe seu ' + LowerCase(ARotuloUsuario) + ' e sua senha';
    if AUsuarioMaiusculo then
      LForm.d_usuario.CharCase := ecUpperCase;
    LForm.ShowModal;
    Result := LForm.FEntrou;
  finally
    LForm.Free;
  end;
end;

procedure Tf_Login.FormCreate(Sender: TObject);
begin
  lblIcone.Font.Name := FonteIcones;
  lblIcone.Caption := C_ICONE_PESSOAS;
  lblSistema.Caption := Application.Title;
  lblOrganizacao.Caption := Identidade.Organizacao;
  AplicarTema;
end;

procedure Tf_Login.AplicarTema;
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
  lblSistema.Font.Name := LTema.FonteTitulo;
  lblBoasVindas.Font.Color := LTema.MenuSubtexto;
  lblOrganizacao.Font.Color := LTema.MenuSubtexto;
  pnlConteudo.Color := LTema.ConteudoFundo;
  lblTitulo.Font.Color := LTema.Texto;
  lblSubtitulo.Font.Color := LTema.TextoSecundario;
  lblUsuario.Font.Color := LTema.Texto;
  lblSenha.Font.Color := LTema.Texto;
  pnlUsuario.Color := LTema.ConteudoFundo;
  pnlSenha.Color := LTema.ConteudoFundo;
  shpUsuario.Brush.Color := LTema.Superficie;
  shpUsuario.Pen.Color := LTema.Borda;
  shpSenha.Brush.Color := LTema.Superficie;
  shpSenha.Pen.Color := LTema.Borda;
  d_usuario.Color := LTema.Superficie;
  d_usuario.Font.Color := LTema.Texto;
  d_senha.Color := LTema.Superficie;
  d_senha.Font.Color := LTema.Texto;
  pnlEntrar.Color := LTema.Destaque;
  pnlEntrar.Font.Color := LTema.TextoSobreDestaque;
  lblCancelar.Font.Color := LTema.TextoSecundario;
end;

procedure Tf_Login.FormShow(Sender: TObject);
begin
  FEntrou := False;
  d_usuario.SetFocus;
end;

procedure Tf_Login.Entrar;
begin
  if FAutenticacao = nil then
    Exit;
  case FAutenticacao.Autenticar(d_usuario.Text, d_senha.Text) of
    rlEntrou:
      begin
        FEntrou := True;
        Close;
      end;
    rlCorrigirUsuario:
      d_usuario.SetFocus;
    rlCorrigirSenha:
      begin
        d_senha.Text := '';
        d_senha.SetFocus;
      end;
    rlEncerrar:
      Close;
    rlPermanecer:
      ;
  end;
end;

procedure Tf_Login.FormKeyPress(Sender: TObject; var Key: Char);
begin
  { Enter entra de qualquer campo, como um botão Default }
  if Key = #13 then
  begin
    Key := #0;
    Entrar;
  end;
end;

procedure Tf_Login.pnlEntrarClick(Sender: TObject);
begin
  Entrar;
end;

procedure Tf_Login.pnlEntrarMouseEnter(Sender: TObject);
begin
  pnlEntrar.Color := Tema.DestaqueSobre;
end;

procedure Tf_Login.pnlEntrarMouseLeave(Sender: TObject);
begin
  pnlEntrar.Color := Tema.Destaque;
end;

procedure Tf_Login.lblCancelarClick(Sender: TObject);
begin
  Close;
end;

procedure Tf_Login.d_usuarioEnter(Sender: TObject);
begin
  shpUsuario.Pen.Color := Tema.Destaque;
end;

procedure Tf_Login.d_usuarioExit(Sender: TObject);
begin
  shpUsuario.Pen.Color := Tema.Borda;
end;

procedure Tf_Login.d_senhaEnter(Sender: TObject);
begin
  shpSenha.Pen.Color := Tema.Destaque;
end;

procedure Tf_Login.d_senhaExit(Sender: TObject);
begin
  shpSenha.Pen.Color := Tema.Borda;
end;

end.
