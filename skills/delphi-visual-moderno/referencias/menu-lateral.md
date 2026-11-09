# Menu lateral e tela inicial

O `TMenuLateral` é criado em código no form principal e montado a partir do `TMainMenu` que já
existe. O `TMainMenu` continua no DFM (o usuário edita o menu no Menu Designer como sempre), só deixa
de ser exibido como barra.

## O que ele lê de cada `TMenuItem`
- `Caption` (o `&` sai; texto com acento entra na busca sem acento);
- `OnClick`/`Action`: clicar chama `TMenuItem.Click`, igual ao menu nativo;
- `Visible` → item some; `Enabled` → item aparece apagado e não abre;
- itens com filhos viram grupos (acordeão: um grupo principal aberto por vez);
- separador (`-`) é ignorado; grupo que ficou sem nenhum item liberado some sozinho;
- `ShortCut`: o menu solto do form não trata mais atalhos; se algum item tiver, ligue o `OnShortCut`
  do form (abaixo).

## Passos no form principal

1. **DFM**: tire a linha `Menu = MainMenu1` do form.
2. **Área de conteúdo**: o menu é `alLeft` criado em código; a VCL alinha `alTop`/`alBottom` antes de
   `alLeft`, então tudo que estava alinhado direto no form (logo, versão, `TStatusBar`) vai para dentro
   de um `pnlConteudo` `alClient`. O `TBevel` que só servia de linha embaixo da barra de menu sai
   (confira com grep que nenhum código o usa). Modelo de DFM abaixo.
3. **Uses**: `ExtCtrls` (se faltar), `UnTema`, `UnMenuLateral`.
4. **Campos** do DFM novo na classe e, no `private`: `FMenuLateral: TMenuLateral;` e
   `procedure MontarMenuLateral;`.
5. **FormCreate** (crie o evento se não existir: `OnCreate = FormCreate` no DFM): chame
   `MontarMenuLateral` no fim.
6. **Depois da rotina de permissão** (geralmente no `FormShow`, logo após o login):
   ```pascal
   Menu;                                    // rotina do sistema, intocada
   FMenuLateral.Usuario := g_operador;      // se o sistema tem usuário logado
   FMenuLateral.AtualizarPermissoes;
   ```
   Se a rotina roda em mais de um lugar (troca de usuário), chame nos dois. Se o usuário é
   `string[n]` (ShortString), converta explícito: `string(g_operador)`.
7. **Esc** (`FormKeyPress`, primeira coisa dentro do `if Key = #27`):
   ```pascal
   if FMenuLateral.LimparBusca then begin Key := #0; Exit; end;
   ```
8. **Atalhos**, só se algum item tiver `ShortCut`: `OnShortCut = FormShortCut` no DFM e
   ```pascal
   procedure TfrmPrincipal.FormShortCut(var Msg: TWMKey; var Handled: Boolean);
   begin
     Handled := FMenuLateral.TratarAtalho(Msg);
   end;
   ```

## MontarMenuLateral

```pascal
procedure TfrmPrincipal.MontarMenuLateral;
begin
  FMenuLateral := TMenuLateral.Create(Self);
  FMenuLateral.Parent := Self;
  FMenuLateral.Align := alLeft;
  FMenuLateral.Titulo := 'Vendas';                 // nome curto do sistema
  FMenuLateral.IconeMarca := C_ICONE_CARRINHO;      // ver icones.md
  FMenuLateral.DescricaoUsuario := 'Operador';      // texto embaixo do nome no rodapé
  FMenuLateral.Montar(MainMenu1, [N1, Sair1]);      // separadores soltos e o item de sair
  FMenuLateral.DefinirIcone(Cadastros1, C_ICONE_CADASTROS);   // só grupos principais
  FMenuLateral.DefinirIcone(Relatorios1, C_ICONE_RELATORIOS);
  FMenuLateral.DefinirIcone(Sobre1, C_ICONE_SOBRE);
  FMenuLateral.DefinirSair(Sair1Click);             // o Sair vai para o rodapé
  FMenuLateral.Abrir(Movimentos1);                  // grupo mais usado já aberto
  { Área de conteúdo no tom do tema (os valores do DFM são os do TemaPadrao) }
  pnlConteudo.Color := Tema.ConteudoFundo;
  pnlTopo.Color := Tema.Superficie;
  lblTitulo.Font.Color := Tema.Texto;
  lblSubtitulo.Font.Color := Tema.TextoSecundario;
  lblMarcaDagua.Font.Color := Tema.MarcaDagua;
  shpLinhaTopo.Brush.Color := Tema.Borda;
  shpLinhaTopo.Pen.Color := Tema.Borda;
end;
```

O subtítulo do cabeçalho do menu vem de `Identidade.Organizacao`; mude com `FMenuLateral.Subtitulo`.
Escolha `Abrir` pelo grupo que o usuário mais usa (pergunte se não for óbvio).

## DFM da área de conteúdo

Dentro do `object` do form, depois das propriedades. `StyleElements = []` é obrigatório se o projeto
usa estilo VCL (sem ele a VCL ignora as cores) e inofensivo se não usa.

```
  object pnlConteudo: TPanel
    Left = 0
    Top = 0
    Width = 843
    Height = 484
    Align = alClient
    BevelOuter = bvNone
    Color = 16184563
    ParentBackground = False
    ShowCaption = False
    StyleElements = []
    TabOrder = 0
    object lblMarcaDagua: TLabel          { ou o logo: TImage com Align = alClient, Center = True }
      Left = 0
      Top = 64
      Width = 843
      Height = 420
      Align = alClient
      Alignment = taCenter
      AutoSize = False
      Caption = 'Nome do Sistema'
      Font.Charset = ANSI_CHARSET
      Font.Color = 14407121
      Font.Height = -64
      Font.Name = 'Segoe UI Light'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
      StyleElements = []
    end
    object pnlTopo: TPanel
      Left = 0
      Top = 0
      Width = 843
      Height = 64
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      ShowCaption = False
      StyleElements = []
      TabOrder = 0
      object lblTitulo: TLabel
        Left = 28
        Top = 9
        Caption = 'In'#237'cio'
        Font.Charset = ANSI_CHARSET
        Font.Color = 2562065
        Font.Height = -19
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object lblSubtitulo: TLabel
        Left = 28
        Top = 35
        Caption = 'Escolha uma op'#231#227'o no menu ao lado'
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        StyleElements = []
      end
      object <label de versão existente>: TLabel    { mantém o nome: o código continua preenchendo }
        AlignWithMargins = True
        Width = 280
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 24
        Margins.Bottom = 0
        Align = alRight
        Alignment = taRightJustify
        AutoSize = False
        Font.Charset = ANSI_CHARSET
        Font.Color = 8417899
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        Layout = tlCenter
        StyleElements = []
      end
      object shpLinhaTopo: TShape
        Left = 0
        Top = 63
        Width = 843
        Height = 1
        Align = alBottom
        Brush.Color = 15460325
        Pen.Color = 15460325
      end
    end
    { TStatusBar existente: mova para cá, Align = alBottom }
  end
```

Cores no DFM (TColor decimal, BGR): fundo `16184563` #F3F4F6, linha `15460325` #E5E7EB, título
`2562065` #111827, secundário `8417899` #6B7280, marca d'água `14407121` #D1D5DB.

Se o DFM tem uma imagem grande (logo com `Picture.Data`), mova o bloco inteiro para dentro de
`pnlConteudo` com um script (Perl) em vez de editar à mão; reindentar não muda os dados.

## Form que não maximiza
Form com `BorderStyle = bsSingle` e `BorderIcons` sem `biMaximize` ignora `wsMaximized` e fica no
tamanho antigo, apertando o menu. `perl scripts/sem-estilo-dfm.pl UnPrincipal.dfm --redimensionavel`
tira as duas linhas (volta ao padrão: redimensiona e maximiza).
