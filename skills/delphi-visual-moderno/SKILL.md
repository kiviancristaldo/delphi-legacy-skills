---
name: delphi-visual-moderno
description: Dá a um sistema Delphi VCL um visual moderno estilo aplicação web - menu lateral escuro com grupos em acordeão e busca, tela de login e Sobre no mesmo padrão, tela inicial com barra de topo, mensagens/confirmações bonitas, telas de cadastro modernizadas (abas do TPageControl como botões arredondados, DBNavigator com ícones), temas (escuro, claro, cor da marca) - sem mudar regra de negócio nem permissões. Use sempre que o usuário pedir para deixar um sistema/tela Delphi bonito, moderno, com cara de web/SaaS, trocar o TMainMenu por menu lateral/sidebar, refazer login ou Sobre, padronizar o visual de vários sistemas, trocar ShowMessage/MessageDlg por caixas bonitas, deixar abas ou navigator mais bonitos, aplicar tema claro/escuro ou a cor de um cliente, mesmo que não use a palavra "design".
---

# Visual moderno para sistemas Delphi VCL

Um conjunto de units prontas e testadas (em `modelos/`) que dão a qualquer sistema VCL o
visual de uma aplicação web: faixa lateral escura, conteúdo claro com cartões, Segoe UI, ícones da
fonte Segoe Fluent/MDL2, destaque azul (ou a cor que o cliente quiser). Foi criado e aprovado num
sistema real em produção e generalizado para servir a outros projetos.

A ideia central: **o visual muda, o comportamento não.** Menu, login e permissões continuam vindo do
que o sistema já tem; as units novas só desenham.

## As peças

| Unit | O que faz | Referência |
|---|---|---|
| `UnTema` | Paletas (`TemaPadrao`, `TemaClaro`, `TemaEscuro`), cor de destaque, identidade (organização, desenvolvedor, contato), ícones `C_ICONE_*`, `Escalar` (DPI) | [temas.md](referencias/temas.md), [icones.md](referencias/icones.md) |
| `UnMenuLateral` | Menu lateral montado do `TMainMenu` existente: acordeão, busca sem acento, item ativo, rodapé com usuário e Sair | [menu-lateral.md](referencias/menu-lateral.md) |
| `UnLogin` (+dfm) | Tela de login; a regra fica no sistema via `IAutenticacaoLogin` | [login-e-sobre.md](referencias/login-e-sobre.md) |
| `UnSobre` (+dfm) | Sobre com data de compilação (cabeçalho do .exe), desenvolvedor e contato | [login-e-sobre.md](referencias/login-e-sobre.md) |
| `UnBotaoModerno` | Botão desenhado (principal, secundário, perigo, link) com Default/Cancel/ModalResult | [cadastro.md](referencias/cadastro.md) |
| `UnDialogo` | `Informar`, `Avisar`, `MostrarErro`, `Confirmar`, `ExibirDialogo` | [dialogos.md](referencias/dialogos.md) |
| `UnCadastroModerno` | `ModernizarCadastro(Form)`: barra de topo, fontes, cores, grades, abas do `TPageControl` como barra de botões arredondados e `TDBNavigator` com ícones; `AplicarEstiloVCL` | [cadastro.md](referencias/cadastro.md) |

Dependências entre elas: todas usam `UnTema`; `UnDialogo` usa `UnBotaoModerno`. Requisitos:
Delphi 10.3 ou mais novo (usa `CurrentPPI`, generics, `StyleElements`), VCL (não FMX), Windows 10+.

## Como trabalhar

### 1. Entender o pedido e o projeto
Descubra o que o usuário quer (tudo, ou só o menu, só o login, só as mensagens...) e levante, antes
de editar:
- **Form principal** (o `MainForm` do `.dpr`): tem `TMainMenu`? (Sem ele, com `TNavigationView`,
  `TButtonGroup` ou botões soltos, crie um `TMainMenu` com os mesmos itens e mova o código de cada
  opção para o `OnClick` do item, sem mudar o corpo.) `FormStyle = fsMDIForm`? (MDI usa a
  barra de menu para a lista de janelas: **pare e pergunte**.) Controles soltos (logo, versão,
  `TStatusBar`, `TBevel` embaixo do menu)?
- **Permissões**: onde o sistema liga/desliga `TMenuItem.Visible`/`Enabled` (rotina tipo `Menu`,
  `TemAcesso`, `Acesso`) e quando ela roda (normalmente no `FormShow`, depois do login).
- **Login**: a unit do login, a consulta, as mensagens, as globais que preenche, como avisa sucesso
  (`ModalResult`, flag em edit escondido, `Tag`...) e o que o principal faz quando o usuário desiste.
- **Acesso a dados** (BDE `TQuery`, FireDAC `TFDQuery`, ADO, dbExpress): as regras de login portadas
  usam a mesma camada.
- **Estilo VCL**: `TStyleManager.TrySetStyle` no `.dpr` ou `Custom_Styles` no `.dproj`. Com estilo
  ativo, todo controle custom precisa de `StyleElements = []` (as units já fazem isso).
- **Codificação** de cada `.pas`/`.dfm` (cp1252 ou UTF-8 com BOM) e final de linha.
- **Vários sistemas** que compartilham pasta comum (`Comum`, `Shared`, `Lib`)? As units vão para lá,
  uma vez só.

Mostre ao usuário um resumo curto do que encontrou e do que vai aplicar.

### 2. Instalar as units
Copie de `modelos/` só as units necessárias (e as dependências) para a pasta comum do projeto
(ou a pasta do sistema, se for um só). Os arquivos estão em UTF-8 com BOM: deixe assim, qualquer
Delphi moderno lê, mesmo que o resto do projeto esteja em cp1252. Registre no `.dpr` e no `.dproj`:

```
perl <skill>/scripts/registra-unit.pl Sistema.dpr Sistema.dproj <unit-âncora> <caminho relativo da unit>
```

Forms (`UnLogin`, `UnSobre`) entram no `.dpr` com o comentário do form: `UnLogin in '..\Comum\UnLogin.pas' {f_Login},`.

### 3. Tema e identidade
No `.dpr`, antes do primeiro `Application.CreateForm`:

```pascal
DefinirTema(TemaPadrao);                       // ou ComDestaque(TemaPadrao, cdVerde), TemaClaro...
DefinirIdentidade('Nome do Cliente', 'Sua Empresa', 'contato@suaempresa.com.br');
```

Sem chamada, vale `TemaPadrao` (o visual de referência) e a identidade padrão (tudo vazio: o Sobre mostra
"—" no desenvolvedor e esconde o contato). Chame `DefinirIdentidade` com os dados de quem desenvolve. Se o usuário falar de cor da marca, tema claro ou
escuro, ou quiser que o usuário final escolha, leia [temas.md](referencias/temas.md).

### 4. Aplicar cada parte pedida
Siga a referência de cada peça. Resumo do que cada uma exige:
- **Menu lateral** ([menu-lateral.md](referencias/menu-lateral.md)): tirar `Menu = MainMenu1` do DFM,
  envolver o conteúdo em `pnlConteudo` com barra de topo, `MontarMenuLateral` no `FormCreate`,
  `AtualizarPermissoes` logo depois da rotina de permissão, Esc limpa a busca.
- **Login** ([login-e-sobre.md](referencias/login-e-sobre.md)): a unit de login antiga vira a
  implementação de `IAutenticacaoLogin` com a **mesma** regra; o principal chama `FazerLogin`.
- **Sobre**: `ExibirSobre(nome, descrição, ícone)` no lugar do form antigo.
- **Mensagens** ([dialogos.md](referencias/dialogos.md)): trocar `ShowMessage`/`MessageDlg` só onde o
  usuário pediu (ou no sistema todo, se pediu), usando a tabela de equivalência.
- **Cadastros** ([cadastro.md](referencias/cadastro.md)): estilo VCL moderno para os controles padrão
  + `ModernizarCadastro(Self, ...)` no `FormCreate` de cada tela (crie o evento se a tela só tem
  `OnShow`). Abas e navigator entram por padrão (`ocAbas`, `ocNavegador`); tela com barra própria
  usa só `[ocFontes, ocCores, ocGrades]`. Se o projeto tem testes de caracterização que fecham
  diálogos, adapte o fechador antes de trocar as mensagens ([armadilhas.md](referencias/armadilhas.md)).

### 5. Compilar e testar
Compile cada sistema (skill `delphi-compile-loop`, se existir; senão MSBuild com `rsvars.bat`).
Meta: nenhum erro e nenhum warning novo nas units tocadas. Se houver testes (DUnitX, testes de
caracterização), rode; se os projetos de teste são gerados a partir do `.dpr`, regenere-os antes.
A tela de login pede senha: **não digite senha**; peça ao usuário para entrar e conferir.

### 6. Entregar
Diga, por sistema: o que mudou na tela, o que continua igual (permissões, regra do login, mensagens),
o resultado da compilação/testes e o que ficou para o usuário conferir na tela. Commit só com
autorização, num branch próprio, um assunto por commit.

## Regras que protegem o sistema
- **Permissões e regras ficam onde estão.** O menu lateral só lê `Visible`/`Enabled` do `TMainMenu`;
  o login só chama a regra do sistema. Nunca recrie regra de acesso nas units visuais.
- **Comportamento igual, inclusive nos detalhes**: mesmas mensagens e ordem de checagem no login, o
  mesmo tratamento de desistência (há sistemas que só fecham, outros que encerram a aplicação),
  o mesmo `ShortString`/tamanho de variáveis globais. Melhorias (SQL com parâmetro, login sem
  diferenciar maiúsculas) só com o usuário sabendo — liste-as na entrega.
- **Nomes que a IDE gera** para eventos (`FormCreate`, `Sender`, `Key`) e nomes existentes de
  componentes não mudam.
- **Codificação e final de linha** de cada arquivo existente são preservados; edite acentos em
  arquivos cp1252 só com conversão (iconv) e confira o resultado.
- Problemas que já aconteceram e como evitar: [armadilhas.md](referencias/armadilhas.md). Leia antes
  de aplicar num sistema com estilo VCL, form `bsSingle`, globais `string[n]` ou testes gerados.

## Scripts
- `scripts/registra-unit.pl` — inclui uma unit no `.dpr` e no `.dproj` antes de uma unit-âncora.
- `scripts/sem-estilo-dfm.pl` — põe `StyleElements = []` nos painéis/labels de `pnlConteudo`;
  `--redimensionavel` tira `BorderStyle`/`BorderIcons` que impedem maximizar.
- `scripts/edita-linhas.pl` — troca/apaga linhas por número conferindo o conteúdo esperado,
  preservando o final de linha (útil em arquivos cp1252 onde o editor não deve reescrever tudo).
