# Riscos apontados: como o script mede

O `Find-CodeSmells.ps1` aponta riscos que a limpeza **não corrige**: eles entram na lista
priorizada com uma recomendação, e o usuário decide. Tudo é heurística por texto (não é o
compilador): os números servem para priorizar e precisam ser conferidos.

Regras gerais:
- comentários (`{ }`, `(* *)`, `//`) e o conteúdo de strings são ignorados ao contar decisões e
  procurar padrões; diretivas `{$...}` não contam como código (`{$IF}` não é um `if`);
- `.dfm` binário (começa com `FF 0A 00` ou `TPF0`) não é lido; o relatório avisa;
- o nível **médio** começa no limite e o **alto** no dobro do limite (na complexidade, no
  limite alto);
- todo limite é parâmetro do script; os padrões batem com o `Get-DiagnosticoLegado.ps1`
  (`delphi-legacy-modernizer`) onde os dois medem a mesma coisa.

| Risco | Parâmetro (padrão) | Média | Alta | Recomendação |
|---|---|---|---|---|
| Unit grande | `-LimiteLinhasUnit` (2000) | 2000+ linhas | 4000+ | dividir com `delphi-safe-refactoring` |
| DataModule grande | `-LimiteLinhasUnit`, `-LimiteComponentesDM` (60), `-LimiteDatasetsDM` (20) | qualquer um no limite | qualquer um no dobro | `dividir-datamodule.md` da `delphi-safe-refactoring` |
| Unit com muitas classes | `-LimiteClassesUnit` (5) | 5+ classes | 10+ | separar por assunto |
| Método grande ou complexo | `-LimiteLinhasMetodo` (80), `-LimiteComplexidade` (10), `-LimiteComplexidadeAlta` (20) | 80+ linhas ou complexidade > 10 | 160+ linhas ou complexidade > 20 | testes e depois extrair método |
| DataModule com muitos assuntos | `-LimiteAssuntosDM` (4), `-LimiteTabelasDM` (10) | 4+ assuntos ou 10+ tabelas | 8+ ou 20+ | dividir por assunto, com testes |
| Parâmetros var/out | `-LimiteVarOut` (3) | 1 ou 2 por rotina | 3+ por rotina | devolver resultado (função/record) |
| Código duplicado | `-JanelaDuplicacao` (8) | 2 cópias | 3+ cópias ou bloco de 24+ linhas | extrair método, com testes |

## Tamanho de unit e de DataModule
- **Linhas**: linhas físicas do `.pas` (como o diagnóstico).
- **DataModule**: a classe raiz do `.dfm` descende de `TDataModule`, seguindo a herança do
  projeto inteiro (`TMeuDM = class(TAbstractDataModule)` também conta).
- **Componentes**: todos os `object`/`inherited`/`inline` do `.dfm`, menos a raiz (inclui os
  campos persistentes `TField`, como no diagnóstico; o relatório mostra quantos são campos).
- **Componentes de dados**: classes terminadas em `Query`, `Table`, `DataSet`, `StoredProc`,
  `Connection`, `Command`, `ClientDataSet`, `Provider`, `MemTable`.
- DataModule aparece só como "DataModule grande/gigante", não também como "Unit grande".

## Classes por unit
Conta declarações `TNome = class...` (inclui `class(TPai);` numa linha só, `class sealed`,
genéricos `TNome<T> = class`). Não contam: declaração antecipada (`TNome = class;`), referência
de classe (`class of`), records e interfaces. Classes aninhadas contam.

## Tamanho e complexidade de métodos
**Limites do método** (igual ao diagnóstico): o cabeçalho (`procedure`, `function`,
`constructor`, `destructor`, `operator`, com ou sem `class`) começa na coluna 0 da
`implementation`; o método vai até o último `end;` na coluna 0 antes do próximo cabeçalho.
Rotinas aninhadas (indentadas) contam dentro da rotina de fora.

**Complexidade ciclomática** = 1 + pontos de decisão:

| Construção | Soma |
|---|---|
| `if` (inclusive `else if`) | 1 |
| `while`, `for` (inclusive `for ... in`), `repeat` | 1 cada |
| cada rótulo de `case` (`1:`, `2, 3:`, `'A'..'Z':`, `ctX:`) | 1 cada (o `else` do case não soma) |
| `and` / `or` dentro da condição de `if`, `while` ou `until` | 1 cada |
| `except` | 1 |
| cada `on E: Classe do` dentro do `except` | 1 |

Não somam: `and`/`or` fora de condição (expressões e máscaras de bits), `case` sem rótulos,
`Exit`, `Break`, `Continue`, `goto`, `IfThen(...)`. A condição de um `if` vai até o `then`; do
`while`, até o `do`; do `until`, até o `;` ou o `end`. Rótulos de case são reconhecidos no começo
da linha, dentro de `case ... of`, quando a linha não é `else`/`end` e tem `:` sem `=`.

Referência para os limites: 1 a 10 é simples, 11 a 20 é moderado, acima de 20 é difícil de
testar (faixas clássicas de McCabe). Por isso o padrão é média acima de 10 e alta acima de 20.

## Parâmetros var e out
Lidos do cabeçalho de cada rotina da `implementation` (inclusive cabeçalhos em várias linhas):
só o que está entre os parênteses dos parâmetros. O `var` da seção de variáveis locais e o
`const` não contam. `var A, B: Integer` são dois parâmetros.
- **Evento** (tem `Sender: TObject`, ou o método está ligado num DFM, ou é atribuído em código
  a uma propriedade `OnXxx :=`): prioridade baixa, informativo. A assinatura é da VCL e não
  pode mudar (`var Key: Char`, `var CanClose: Boolean`, `var Action: TReconcileAction`).
- Rotina comum com 1 ou 2: média. Com `-LimiteVarOut` (3) ou mais: alta.

Por que é risco: o efeito colateral fica escondido em quem chama, o teste precisa preparar e
conferir cada variável, e refatorar exige mudar todos os chamadores.

## Assuntos de um DataModule
Um **assunto** é um grupo de datasets ligados entre si. O script monta um grafo com os
componentes de dados de primeiro nível do `.dfm` e as tabelas que eles usam, e conta os grupos
desconectados. Dois componentes ficam no mesmo assunto quando:
- usam a mesma tabela (`TableName`, ou `FROM`/`JOIN`/`INTO`/`UPDATE` no SQL);
- um aponta para o outro em `MasterSource`, `DataSet`, `DataSource`, `ProviderName`,
  `LookupDataSet` (inclusive dentro dos campos), `UpdateObject`.

Detalhes:
- SQL lido de `SQL.Strings`, `CommandText`, `SelectSQL`/`InsertSQL`/... no `.dfm` (com as
  strings partidas em `'...' + '...'` e `#13#10` decodificadas) e de linhas do `.pas` que citam
  `SQL`, `CommandText` ou `TableName`. No `.pas`, a tabela vai para o componente citado na linha
  (`qryX.SQL.Text := ...`); se não houver, a tabela fica num grupo próprio "(SQL no código)".
- Conexões (`...Connection`, `...Database`, `...Session`, `...Transaction`) ficam fora: ligariam
  tudo num grupo só.
- `EXTRACT(YEAR FROM x)`, `SUBSTRING(x FROM n)`, `TRIM(...)`, `POSITION(...)` não são tabelas.
  Tabelas de sistema (`RDB$...`, `MON$...`, `SEC$...`, `DUAL`) não são assunto.
- DFM herdado (`inherited`): as ligações e o SQL do DFM do ancestral entram no grafo.
- DataSource solto (sem dataset) não é assunto.

O relatório lista cada assunto com os datasets e as tabelas, para o usuário julgar.

Limitações conhecidas: tabelas auxiliares (gerador de chave como `NEXTCUST`, tabela de log)
aparecem como assunto separado; SQL montado com variáveis (`'from ' + NomeTabela`) não é visto;
um DataModule com tabelas muito relacionadas mas sem ligação no DFM aparece com vários assuntos.

## Código duplicado
Mesma ideia do diagnóstico: janelas de `-JanelaDuplicacao` (8) linhas não triviais iguais
(sem `begin`, `end`, `try`, `finally`, `except`, `else` sozinhos e linhas vazias), com 150+
caracteres, depois de tirar comentários, juntar espaços e passar para minúsculas. Strings são
mantidas (duas mensagens diferentes não são duplicação). Diferenças em relação ao diagnóstico:
- janelas consecutivas que se repetem nos mesmos lugares viram **um bloco só**, com o intervalo
  de linhas de cada cópia (o diagnóstico mostra janelas sobrepostas);
- comentários `{ }` e `(* *)` também são ignorados.
A busca é no projeto inteiro (`-Pasta`); em escopo parcial, entram os blocos com pelo menos uma
cópia nas units do escopo.

## O que fica de fora
Units no `uses` sem uso (use o compilador ou o CnPack), campos e variáveis sem uso (hints do
compilador, skill `delphi-compile-loop`), acoplamento entre units e variáveis globais (diagnóstico
da `delphi-legacy-modernizer`).
