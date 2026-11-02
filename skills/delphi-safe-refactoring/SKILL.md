---
name: delphi-safe-refactoring
description: Refatora código Delphi legado com segurança e transforma telas feitas no estilo RAD (DataModule com queries, TDBEdit/TDBGrid ligados direto no banco, regra de negócio no OnClick e no BeforePost) em camadas Types, Connection, Models, Controllers e View, com endpoints REST em Horse reaproveitando o mesmo Controller. Também quebra métodos, units e DataModules gigantes, elimina duplicação e acoplamento. Use quando o usuário pedir para refatorar, separar em camadas, aplicar MVC/POO/SOLID, tirar a regra da tela ou do DFM, sair do RAD, criar API/endpoints Horse para um cadastro, dividir um DataModule ou remover duplicação.
---

# Refatoração segura e transformação em camadas

Refatorar é **mudar a estrutura sem mudar o comportamento**. Esta skill tem dois modos:

| Modo | Quando | Resultado |
|---|---|---|
| **A. Refatoração pontual** | método gigante, duplicação, globais, acoplamento, DataModule inchado | o mesmo código, organizado, em passos pequenos |
| **B. Transformação em camadas** | uma tela de cadastro/consulta feita no RAD (DataModule + DB-aware) | `Types`, `Connection`, `Models`, `Controllers`, View só de tela e, se pedido, endpoints Horse |

Se o pedido não deixar claro, pergunte qual modo (uma pergunta só).

Arquivos desta skill (caminhos relativos à pasta da skill):
- `referencias/catalogo-de-refatoracoes.md` e `referencias/dividir-datamodule.md`: modo A
- `referencias/arquitetura-em-camadas.md`: o padrão alvo do modo B (camadas, regras, quem libera o quê)
- `referencias/mapeamento-dbaware.md`: campo → propriedade → componente, DB-aware → comum, TFDMemTable
- `referencias/endpoints-horse.md`: rotas, status HTTP, memória no Horse, alternativa DataSnap
- `referencias/validacao.md`: codificação, `.dfm`, compilação, sobras e testes
- `modelos/`: exemplo completo de um cadastro de Produtos em camadas (`Types.Produtos`,
  `Connection.Database`, `Models.Produtos`, `Controllers.Produtos`, `View.Produtos.pas.modelo`,
  `Routes.Produtos`, `ServerProdutos.dpr`)
- `scripts/Normalize-Encoding.ps1`, `scripts/Test-Dfm.ps1`, `scripts/Test-Endpoints.ps1`

## Regras dos dois modos
1. **Rede de segurança antes.** O trecho precisa de testes de caracterização passando (skill
   `delphi-characterization-tests`). Se não houver, crie antes ou pare e explique. No modo B ela
   entra depois do levantamento (B1, que mostra o que caracterizar) e antes do plano (B2); veja B1.5.
2. **Git.** Árvore limpa **no início** da tarefa (alterações alheias à tarefa: PARE e avise).
   Durante a tarefa, as alterações dela são esperadas, inclusive quando outra skill é chamada no meio
   (`delphi-compile-loop`, `delphi-characterization-tests`). Cada etapa termina num ponto de commit
   (um objetivo por commit): proponha a mensagem e **commite só com autorização** do usuário.
   Pergunte uma vez, no B0 (ou antes do primeiro passo do modo A), se pode commitar ao fim de cada
   etapa; a resposta vale para a tarefa toda. Sem autorização, deixe pronto e liste os commits sugeridos.
3. **Comportamento igual.** Bug encontrado no caminho não é corrigido junto: anote e mostre no fim.
4. **Uma pergunta por vez.** Cada decisão do usuário numa mensagem própria, com opções e a sua
   recomendação. Perguntas agrupadas costumam ser respondidas pela metade.
5. **Units gigantes custam tokens.** Localize o trecho e leia só o intervalo necessário.
6. **Não mexa** em fontes de componentes de terceiros.

---

## Modo A: refatoração pontual
1. Escolha as refatorações no [catálogo](referencias/catalogo-de-refatoracoes.md) (ou o roteiro de
   [dividir DataModule](referencias/dividir-datamodule.md)) e mostre a sequência de passos antes de começar.
2. Para cada passo: faça só ele → compile (`delphi-compile-loop`) → rode os testes → commit
   (se autorizado; regra 2).
   Vermelho: desfaça o passo e divida em passos menores. Nunca "conserte" o teste.
3. Ao final, rode o diagnóstico da skill `delphi-legacy-modernizer` com `-Comparar` e mostre a evolução.

---

## Modo B: transformação em camadas
Padrão de [arquitetura-em-camadas.md](referencias/arquitetura-em-camadas.md). Use os arquivos
de `modelos/` como base, adaptando nomes, campos e regras ao assunto real.

### B0. Preparação (uma pergunta por mensagem; pule o que o usuário já respondeu)
1. Qual form (`.pas` + `.dfm`) será transformado.
2. O **assunto**, que dá nome às units (`Produtos` → `Types.Produtos`, `Models.Produtos`,
   `Controllers.Produtos`, `Routes.Produtos`). Sugira um a partir do nome do form.
3. Se quer **endpoints** agora: Horse (padrão), DataSnap (se o projeto já usa) ou nenhum.
4. Se pode **commitar** ao fim de cada etapa (rede de segurança, camadas, View, servidor). Recomendação: sim.
5. Anote a **codificação** do `.pas` legado (com BOM = UTF-8; sem BOM = ANSI cp1252). Será usada na etapa B8.

### B1. Levantamento (somente leitura)
Leia e anote, sem alterar nada:
- **Form**: componentes DB-aware e seus `DataField`; `TDataSource` e o dataset de cada um; colunas do
  grid; o que cada handler faz (`Open`, `Append`, `Edit`, `Post`, `Cancel`, `Delete`) e as validações escritas ali.
- **DataModule**: conexão e driver; SQL das queries (tabela, colunas, chave, `ORDER BY`); TFields
  persistentes (tipo, `Size`, `Required`, `DisplayFormat`, `DisplayLabel`); eventos com regra
  (`BeforePost`, `OnNewRecord`, `AfterInsert`, `OnValidate`, `BeforeDelete`, `OnGetText`).
- **Banco**: constraints (NOT NULL, CHECK, tamanhos, default) e geração de id (generator, identity),
  lendo scripts DDL do projeto ou um arquivo de banco local. Não conecte em servidor sem perguntar.
- **Quem mais usa o DataModule e as queries** (busca no projeto inteiro): decide se o DM fica.
- **Infraestrutura existente**: já há `Connection.Database`, Controllers, Horse/Boss? Siga o que existir.
- **Fora do escopo** (lista no fim desta skill). Achou algum? Descreva e pergunte agora, antes de seguir.

### B1.5. Rede de segurança (antes do plano)
Se o levantamento não achou testes de caracterização do form, crie-os agora com a skill
`delphi-characterization-tests` (pergunte antes; regra 1). Escreva-os num nível que **sobreviva à
troca da tela**, porque em B9 eles precisam continuar passando contra o form transformado:
- **Estado do banco** depois de cada operação (inserir, alterar, excluir): golden master de um
  `SELECT` com `ORDER BY` explícito, não do dataset da tela.
- **Carga do form** genérica: crie o form, ache o grid **pela classe** (`TDBGrid`), não pelo nome, e
  compare o conteúdo do dataset dele pelos **nomes dos campos** (o `TFDMemTable` novo usa os mesmos).
- **Regras do DataModule** (`AfterInsert`, `BeforePost`, geração de id) chamadas direto no DataModule,
  que continua existindo se outra tela o usa.
- Evite testes que dependam de nomes de componentes DB-aware (`DBEdit1`), de `DataSource` ou do DataModule na tela.
Aprove os golden masters, rode tudo verde e proponha o commit `test: caracterização de <assunto>`.

### B2. Plano: mostre e espere a confirmação
De forma compacta:
- tabela `coluna | TField | propriedade no Model (tipo) | componente antes → depois`;
- units a criar e alterar (e o destino do DataModule);
- **regras que vão para o Controller e de onde cada uma veio**;
- rotas que serão criadas (se houver endpoints);
- diferenças de comportamento inevitáveis (ex.: coluna que aceitava nulo passa a gravar vazio);
- comportamentos que o DB-aware dava de graça e que a tela vai reimplementar ou perder (tabela em
  `mapeamento-dbaware.md`): gravar ao trocar de linha, Esc restaurando o campo, edição no grid,
  confirmação de exclusão, botões habilitados pelo estado. Os que mudam o jeito de usar a tela são pergunta;
- efeito em **outras telas** que usam as mesmas queries do DataModule (ex.: um lookup que mostra os
  registros que esta tela grava e precisa ser reaberto para ver as mudanças): é pergunta;
- itens fora do escopo encontrados.

As diferenças que só precisam de registro ficam no plano. As que precisam de decisão você pergunta,
**uma por mensagem**. A última pergunta é a confirmação do plano. Nada é escrito antes dela.

### B3. Types e Connection
- `Types.<Assunto>`: enums, constantes e `EValidacao<Assunto>`.
- `Connection.Database`: crie a partir do modelo **somente se ainda não existir**. Conexão nova por
  operação, com pool; configuração em `.ini`. Senha nunca no código.

### B4. Models
Entidade (propriedades, `Assign`, `Clone`, `ToJson`, `FromJson`) e coleção (`CarregarDoBanco`,
`BuscarNoBanco`, `Inserir`, `Alterar`, `Excluir`, `Itens`, `ToJson`), com o SQL e a ordenação do legado.
Geração de id conforme o banco (tabela em `arquitetura-em-camadas.md`). Legado com `max(id)+1` e banco
sem generator: é pergunta no B2 (veja "Legado com max(id)+1" no mesmo arquivo). Nulos e datas como
parâmetro: veja `mapeamento-dbaware.md`.

### B5. Controllers
Cria e libera a coleção; `ValidarId` e `ValidarPreenchimento` com **todas** as regras do levantamento,
cada uma com comentário de origem; validação fora do `try` do banco; erro de banco relançado com contexto.
Nenhuma regra nova sem o usuário pedir: sugestões vão para o relatório.

### B6. View
Mesmo nome de unit e classe; mesmo layout, captions, ordem de tabulação e fluxo de botões.
- `.dfm`: DB-aware → componentes comuns; grid ligado a `MTB_<Assunto>` (`TFDMemTable`) com
  `DS_<Assunto>.OnDataChange`; remova as propriedades que só existem nas versões DB.
- `.pas`: declarações iguais ao `.dfm`; `FController`; `AtualizarView` (lista → grid),
  `CarregarRegistroSelecionado` (grid → campos), conversões de texto na tela.
- `uses`: tira `Vcl.DBCtrls` e o DataModule; põe as units do FireDAC do MemTable e as camadas.
Siga `modelos/View.Produtos.pas.modelo` e a tabela "Comportamentos que o DB-aware dava de graça".

### B7. Endpoints (se pedidos)
`Routes.<Assunto>` com GET lista, GET por id, POST, PUT, DELETE chamando o **mesmo** Controller,
e o projeto do servidor (`modelos/ServerProdutos.dpr` + `modelos/ServerProdutos.dproj.modelo`, que já
traz o search path dos pacotes do Boss). Status, formato de erro, ordem dos middlewares e regras de
memória em [endpoints-horse.md](referencias/endpoints-horse.md). Não instale pacotes Boss sem o
usuário pedir; informe os comandos.

### B8. Projeto, codificação e validação
1. Registre as units novas no `.dpr` (`uses ... in`) e no `.dproj` (`DCCReference`).
2. Depois da **última** edição: `scripts/Normalize-Encoding.ps1` com a codificação anotada em B0.
3. `scripts/Test-Dfm.ps1` nos `.dfm` alterados.
4. Compile com a skill `delphi-compile-loop` até zerar erros, na plataforma do projeto (ou a do cliente
   do banco, se diferente) e sem refazer as perguntas dela: meta "zerar erros", mais warnings e hints
   que vierem do código novo (o código novo não deve introduzir nenhum).
5. Procure sobras: `TDB` (exceto `TDBGrid`), `DataField`, nome do DataModule e das queries no form.
Detalhes em [validacao.md](referencias/validacao.md).

### B9. Testes
1. Testes de caracterização do legado continuam passando (por isso eles foram escritos no nível do
   banco e do grid, em B1.5). Se algum dependia de um nome de componente que mudou, ajuste só a forma
   de achar o componente; nunca o valor esperado.
2. Teste DUnitX do Controller contra uma **cópia** do banco (inserir, buscar, alterar, cada validação, excluir).
3. Endpoints: `scripts/Test-Endpoints.ps1` contra o servidor rodando com banco de cópia, chamado
   com `& .\scripts\Test-Endpoints.ps1` e um `-CorpoInvalido` que viole uma regra real (veja endpoints-horse.md).
4. Banco em servidor: pergunte antes, porque os testes gravam dados.
5. A plataforma dos testes segue o cliente do banco: com Firebird/cliente 32 bits, compile os testes
   em Win32 (o executável Win64 não carrega `fbclient.dll` de 32 bits).

### B10. Relatório
- Arquivos criados, alterados e removidos.
- Regras migradas (origem → Controller).
- Resultado de: codificação, `.dfm`, compilação, testes, endpoints.
- Diferenças de comportamento e sugestões não aplicadas.
- Roteiro manual para o usuário testar a tela: navegar no grid, incluir, alterar, cancelar,
  excluir, disparar uma validação.
- Commits: os feitos (só os autorizados, regra 2) e os sugeridos que ficaram por fazer.

## Fora do escopo do modo B (descreva o que achou e pergunte como seguir)
- Master-detail (`MasterSource`/`MasterFields`, mais de uma tabela editada no mesmo form).
- Lookups (`TDBLookupComboBox`, campos lookup/calculados além de formatação).
- `TClientDataSet` + `TDataSetProvider`, cached updates, `TDBNavigator` controlando o dataset.
- SQL de outras tabelas disparado pelo form ou por triggers que ele depende.
- Imagens e blobs (`TDBImage`).
- Herança visual: o form herda de outro form do projeto que já tem componentes DB (mexer na base
  muda as outras telas que herdam dela). Proponha herdar de `TForm` copiando o layout.
- Componentes DB de terceiros sem equivalente comum claro.

## Créditos
Arquitetura baseada no curso de Delphi de Kivian Emerim (projeto Lista de Compras). Fluxo de
levantamento, plano e validação inspirado na skill
[c4d-rad-to-poo](https://github.com/Code4Delphi/c4d-rad-to-poo), do Code4Delphi.
