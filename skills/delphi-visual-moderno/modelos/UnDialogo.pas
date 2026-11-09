unit UnDialogo;

{ Mensagens e confirmações no visual moderno (no lugar de ShowMessage e
  MessageDlg). A caixa é montada em código: não há DFM.

    Informar('Cadastro gravado.');
    Avisar('Preencha o CPF.');
    MostrarErro('Não foi possível gravar: ' + E.Message);
    if Confirmar('Excluir o cliente ' + Nome + '?', 'Excluir', 'Excluir', 'Cancelar', True) then ...

  Equivalências para trocar chamadas antigas sem mudar o comportamento:
    ShowMessage(T)                                   -> Informar(T)
    MessageDlg(T, mtConfirmation, [mbYes, mbNo], 0) = mrYes -> Confirmar(T)
    MessageDlg(T, mtWarning, [mbOK], 0)              -> Avisar(T)
    MessageDlg(T, mtError, [mbOK], 0)                -> MostrarErro(T)
  Atenção: Confirmar devolve False também quando a janela é fechada no X ou
  com Esc, como o "Não" do MessageDlg. }

interface

uses
  System.SysUtils, System.Classes;

type
  TTipoDialogo = (tdInformacao, tdSucesso, tdAviso, tdErro, tdPergunta);

procedure Informar(const ATexto: string; const ATitulo: string = 'Informação');
procedure InformarSucesso(const ATexto: string; const ATitulo: string = 'Pronto');
procedure Avisar(const ATexto: string; const ATitulo: string = 'Atenção');
procedure MostrarErro(const ATexto: string; const ATitulo: string = 'Erro');

{ True = botão principal (ASim). APerigo pinta o botão principal de vermelho
  (para excluir, cancelar documento etc.) }
function Confirmar(const ATexto: string; const ATitulo: string = 'Confirmação';
  const ASim: string = 'Sim'; const ANao: string = 'Não'; APerigo: Boolean = False): Boolean;

{ Caixa genérica. ABotoes da esquerda para a direita; o último é o principal
  (Enter) e o primeiro é o de cancelar (Esc). Devolve o índice do botão
  clicado, ou -1 se a janela foi fechada sem botão. }
function ExibirDialogo(ATipo: TTipoDialogo; const ATitulo, ATexto: string;
  const ABotoes: array of string; APerigo: Boolean = False): Integer;

implementation

uses
  Winapi.Windows, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.ExtCtrls, UnTema, UnBotaoModerno;

const
  C_RESULTADO_BASE = 100;  // ModalResult do botão i = C_RESULTADO_BASE + i

function CorDoTipo(ATipo: TTipoDialogo): TColor;
begin
  case ATipo of
    tdSucesso: Result := Tema.Sucesso;
    tdAviso: Result := Tema.Aviso;
    tdErro: Result := Tema.Perigo;
  else
    Result := Tema.Destaque;
  end;
end;

function IconeDoTipo(ATipo: TTipoDialogo): string;
begin
  case ATipo of
    tdSucesso: Result := C_ICONE_SUCESSO;
    tdAviso: Result := C_ICONE_AVISO;
    tdErro: Result := C_ICONE_ERRO;
    tdPergunta: Result := C_ICONE_PERGUNTA;
  else
    Result := C_ICONE_INFO;
  end;
end;

function ExibirDialogo(ATipo: TTipoDialogo; const ATitulo, ATexto: string;
  const ABotoes: array of string; APerigo: Boolean): Integer;
var
  LForm: TForm;
  LTema: TTema;
  LCirculo: TShape;
  LIcone, LTitulo, LTexto: TLabel;
  LRodape: TPanel;
  LBotao, LPrincipal: TBotaoModerno;
  LIndice, LDireita, LAlturaConteudo: Integer;

  function E(AValor: Integer): Integer;
  begin
    Result := MulDiv(AValor, LForm.CurrentPPI, 96);
  end;

begin
  LTema := Tema;
  LForm := TForm.CreateNew(Application);
  try
    LForm.BorderStyle := bsDialog;
    LForm.BorderIcons := [biSystemMenu];
    LForm.Position := poMainFormCenter;
    LForm.Caption := ATitulo;
    LForm.Color := LTema.Superficie;
    LForm.StyleElements := [seBorder];
    LForm.Font.Name := LTema.FonteTexto;
    LForm.Font.Height := -E(13);
    LForm.ClientWidth := E(440);

    { Círculo colorido com o ícone do tipo }
    LCirculo := TShape.Create(LForm);
    LCirculo.Parent := LForm;
    LCirculo.Shape := stCircle;
    LCirculo.SetBounds(E(24), E(24), E(44), E(44));
    LCirculo.Brush.Color := CorDoTipo(ATipo);
    LCirculo.Pen.Color := CorDoTipo(ATipo);

    LIcone := TLabel.Create(LForm);
    LIcone.Parent := LForm;
    LIcone.AutoSize := False;
    LIcone.Transparent := True;
    LIcone.Alignment := taCenter;
    LIcone.Layout := tlCenter;
    LIcone.SetBounds(E(24), E(24), E(44), E(44));
    LIcone.Font.Name := FonteIcones;
    LIcone.Font.Height := -E(20);
    LIcone.Font.Color := clWhite;
    LIcone.StyleElements := [];
    LIcone.Caption := IconeDoTipo(ATipo);

    LTitulo := TLabel.Create(LForm);
    LTitulo.Parent := LForm;
    LTitulo.SetBounds(E(84), E(24), E(332), E(24));
    LTitulo.AutoSize := False;
    LTitulo.Font.Name := LTema.FonteTitulo;
    LTitulo.Font.Height := -E(17);
    LTitulo.Font.Color := LTema.Texto;
    LTitulo.StyleElements := [];
    LTitulo.Caption := ATitulo;

    { Texto com quebra de linha: a altura acompanha o tamanho da mensagem }
    LTexto := TLabel.Create(LForm);
    LTexto.Parent := LForm;
    LTexto.Left := E(84);
    LTexto.Top := E(54);
    LTexto.Width := E(332);
    LTexto.WordWrap := True;
    LTexto.AutoSize := True;
    LTexto.Font.Name := LTema.FonteTexto;
    LTexto.Font.Height := -E(13);
    LTexto.Font.Color := LTema.TextoSecundario;
    LTexto.StyleElements := [];
    LTexto.Caption := ATexto;

    LAlturaConteudo := LTexto.Top + LTexto.Height + E(24);
    if LAlturaConteudo < E(92) then
      LAlturaConteudo := E(92);

    LRodape := TPanel.Create(LForm);
    LRodape.Parent := LForm;
    LRodape.Align := alBottom;
    LRodape.Height := E(68);
    LRodape.BevelOuter := bvNone;
    LRodape.ShowCaption := False;
    LRodape.ParentBackground := False;
    LRodape.StyleElements := [];
    LRodape.Color := LTema.ConteudoFundo;

    LForm.ClientHeight := LAlturaConteudo + LRodape.Height;

    { Botões da direita para a esquerda: o último de ABotoes é o principal }
    LBotao := nil;
    LPrincipal := nil;
    LDireita := LForm.ClientWidth - E(20);
    for LIndice := High(ABotoes) downto Low(ABotoes) do
    begin
      if LIndice = High(ABotoes) then
      begin
        if APerigo then
          LBotao := CriarBotao(LRodape, ABotoes[LIndice], ebPerigo, nil)
        else
          LBotao := CriarBotao(LRodape, ABotoes[LIndice], ebPrimario, nil);
        LBotao.Default := True;
        LPrincipal := LBotao;
      end
      else
        LBotao := CriarBotao(LRodape, ABotoes[LIndice], ebSecundario, nil);
      if LIndice = Low(ABotoes) then
        LBotao.Cancel := True;
      LBotao.ModalResult := C_RESULTADO_BASE + LIndice;
      LBotao.SetBounds(LDireita - LBotao.Width, E(15), LBotao.Width, E(38));
      Dec(LDireita, LBotao.Width + E(10));
    end;

    if (Length(ABotoes) = 1) and (LBotao <> nil) then
      LBotao.Cancel := True;  // só "OK": Esc também fecha
    if LPrincipal <> nil then
      LForm.ActiveControl := LPrincipal;  // Enter já aciona o principal

    LForm.ShowModal;
    if LForm.ModalResult >= C_RESULTADO_BASE then
      Result := LForm.ModalResult - C_RESULTADO_BASE
    else
      Result := -1;
  finally
    LForm.Free;
  end;
end;

procedure Informar(const ATexto, ATitulo: string);
begin
  ExibirDialogo(tdInformacao, ATitulo, ATexto, ['OK']);
end;

procedure InformarSucesso(const ATexto, ATitulo: string);
begin
  ExibirDialogo(tdSucesso, ATitulo, ATexto, ['OK']);
end;

procedure Avisar(const ATexto, ATitulo: string);
begin
  ExibirDialogo(tdAviso, ATitulo, ATexto, ['OK']);
end;

procedure MostrarErro(const ATexto, ATitulo: string);
begin
  ExibirDialogo(tdErro, ATitulo, ATexto, ['OK']);
end;

function Confirmar(const ATexto, ATitulo, ASim, ANao: string; APerigo: Boolean): Boolean;
begin
  Result := ExibirDialogo(tdPergunta, ATitulo, ATexto, [ANao, ASim], APerigo) = 1;
end;

end.
