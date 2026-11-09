# Telas de cadastro, consulta e relatório

Duas camadas, que se completam:

1. **Estilo VCL moderno** para os controles padrão (`TButton`, `TBitBtn`, `TEdit`, `TComboBox`,
   `TDBGrid`, `TPageControl`...). Muda o desenho de todos de uma vez, sem trocar componente nem DFM.
2. **`ModernizarCadastro`** para o que o estilo não faz: barra de topo, fontes, cores de fundo,
   títulos das grades.

## 1. Estilo VCL
Estilos do Delphi que combinam com os temas (nome usado no código à direita):

| Tema | Arquivo | Nome |
|---|---|---|
| `TemaPadrao` / `TemaClaro` | `WindowsModern.vsf` | `Windows Modern` |
| `TemaEscuro` | `WindowsModernDark.vsf` | `Windows Modern Dark` |
| destaque azul/verde/roxo/grafite | `WindowsModernBlue/Green/Purple/SlateGray.vsf` | `Windows Modern Blue` etc. |

Os arquivos ficam em `C:\Users\Public\Documents\Embarcadero\Studio\<versão>\Styles`. Para usar:
- inclua o estilo no projeto: Project > Options > Application > Appearance (marca o estilo; isso
  grava `<Custom_Styles>` no `.dproj` e embute o estilo no executável);
- no `.dpr`, depois de `Application.Initialize`: `AplicarEstiloVCL;` (usa `Tema.EstiloVCL`) ou
  `AplicarEstiloVCL('Windows Modern Blue');`. Devolve False se o estilo não foi incluído.

Cuidados:
- estilo é global: todas as telas mudam. Mostre ao usuário antes de aplicar em sistema grande;
- componentes desenhados à mão (menu lateral, login, Sobre, diálogos, botão moderno) já usam
  `StyleElements := []`; DFMs com cores próprias precisam de `StyleElements = []` nesses controles
  (`scripts/sem-estilo-dfm.pl` faz isso dentro do `pnlConteudo`);
- relatórios (FortesReport, QuickReport, FastReport) e prévias não são afetados no papel.

## 2. ModernizarCadastro
No `FormCreate` da tela, **depois** do que já existia lá:

```pascal
ModernizarCadastro(Self, 'Clientes', 'Cadastro e consulta de clientes');
// opções: ModernizarCadastro(Self, '', '', [ocFontes, ocGrades]);   // sem barra de topo
```

O que cada opção faz:
- `ocBarraTopo`: barra branca de 64 px com título (padrão: o `Caption` do form) e subtítulo. Os
  controles soltos descem 64 px respeitando âncoras (ancorados só embaixo ficam; esticados encolhem)
  e o form cresce 64 px se não estiver maximizado. Controles alinhados se acomodam sozinhos.
- `ocFontes`: troca MS Sans Serif/Tahoma/Arial/Verdana por Segoe UI mantendo o tamanho (quem tem
  `ParentFont` acompanha o form). Segoe UI tem largura parecida; confira labels muito justos.
- `ocCores`: sem estilo VCL ativo, o fundo do form e os `TPanel` cor `clBtnFace` vão para
  `Tema.ConteudoFundo`. Com estilo ativo não faz nada (o estilo manda).
- `ocGrades`: títulos das `TDBGrid` em Segoe UI Semibold, cor fixa no tom do tema (sem estilo).
- `ocAbas`: as abas de cada `TPageControl` viram uma barra de botões arredondados (controle
  segmentado; a aba ativa em destaque). As abas nativas só ficam escondidas (`TabVisible := False`)
  e a página ativa é mantida; o clique chama `OnChanging`/`OnChange` como o clique na aba, e a barra
  acompanha trocas de `ActivePage` feitas pelo código. A área das páginas mantém a altura; o que a
  barra ocupa a mais desce os controles de baixo e aumenta o form. Perde-se Ctrl+Tab entre abas.
  Abas criadas ou mostradas por código depois do `FormCreate` não entram na barra.
- `ocNavegador`: `TDBNavigator` plano, com ícones da fonte de ícones (setas escuras, incluir azul,
  excluir/cancelar vermelhos, gravar verde). É o mesmo componente: cliques, hints, `BeforeAction`,
  `OnClick` e confirmação de exclusão continuam. Nesta VCL os botões desenham por `Images`/`ImageIndex`
  (o `Glyph` é ignorado): cada navegador ganha uma `TImageList` própria com ícone normal e desabilitado.

Não mexe em eventos, `Visible`, `Enabled`, `TabOrder`, dados, nem em código que move controles.
Se a tela calcula posições na mão (`Top := ...` com números fixos) depois do `FormCreate`, prefira
`[ocFontes, ocCores, ocGrades]` sem a barra.

## Botões novos
Em tela nova ou rodapé novo, use o `TBotaoModerno` (criado em código):

```pascal
LGravar := CriarBotao(pnlRodape, 'Gravar', ebPrimario, btGravarClick, C_ICONE_SALVAR);
LGravar.Align := alRight;   LGravar.AlignWithMargins := True;
LGravar.Default := True;    // Enter
LCancelar := CriarBotao(pnlRodape, 'Cancelar', ebSecundario, btCancelarClick);
LCancelar.Cancel := True;   // Esc
```

Estilos: `ebPrimario` (ação principal, um por tela), `ebSecundario` (cancelar, voltar), `ebPerigo`
(excluir), `ebLink` (ações discretas). Não substitua `TButton`/`TBitBtn` existentes por ele: código
que mexe no botão antigo (`btGravar.Enabled := ...`) deixaria de funcionar; para esses, o estilo VCL.

## Layout que combina
- fundo `Tema.ConteudoFundo`, conteúdo em "cartões" (`TPanel` `Tema.Superficie`, sem bevel,
  margem 24 px), rótulo em cima do campo (`Tema.TextoSecundario`, Segoe UI 12 px);
- um botão principal por tela, à direita no rodapé; secundários à esquerda dele;
- títulos em Segoe UI Semibold, texto Segoe UI, números grandes em Segoe UI Light.
