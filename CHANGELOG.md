# Histórico de versões

## Não lançado
- `delphi-cleanup`: processo novo, sem sair fazendo: levantamento → recomendação de testes de
  caracterização (registra se o usuário aceitou) → lista priorizada (alta, média, baixa, com risco
  de corrigir, benefício e recomendação) → decisão do usuário, uma pergunta por vez → execução só do
  escolhido, um tipo por commit → relatório com o que "não foi feito, por decisão do usuário".
  - `Find-CodeSmells.ps1` passa a apontar riscos (não corrige): units e DataModules grandes
    (linhas, componentes e componentes de dados do `.dfm`), units com muitas classes, métodos grandes
    ou com complexidade ciclomática alta, DataModules com muitos assuntos (grupos de datasets ligados
    por tabela, mestre-detalhe, DataSource ou Provider, inclusive com DFM herdado), parâmetros
    `var`/`out` (eventos da VCL à parte) e código duplicado (janelas juntadas num bloco só).
    Limites são parâmetros, com os mesmos padrões do `Get-DiagnosticoLegado`.
  - Relatório `_modernizacao\limpeza.md` agrupado por prioridade, com códigos (A1, M2, B1...) e
    `arquivo:linha` em cada item; a tabela-resumo mantém as colunas `Item | Quantidade`.
  - `-Arquivos "a.pas,b.pas"` (escopo parcial): analisa só essas units, procura referências no
    projeto inteiro e marca métodos e componentes sem uso como "Não remover: escopo parcial".
  - Ignora comentários e strings (função `Limpar-Linha` do `Find-PadroesMigracao`); DFM binário
    não é lido e gera aviso; novo item "Componente de dados possivelmente sem uso"; métodos
    `virtual`/`override` e eventos atribuídos em código (`OnXxx := Metodo`) deixam de aparecer como
    sem uso; `'Password: ' + Campo` (mensagem) deixa de ser acusado como senha.
  - Referências novas: `riscos-apontados.md` (heurísticas e limites) e `modelo-relatorio.md`.
- `tools/Testar-Scripts.ps1`: verificações das métricas novas do `Find-CodeSmells` (classes,
  complexidade, var/out, duplicação, assuntos do DataModule, prioridade e escopo parcial).
- `delphi-safe-refactoring`: novo modo de transformação em camadas (Types, Connection, Models,
  Controllers, View) com endpoints Horse, baseado no curso de Delphi da Kivian e inspirado na
  c4d-rad-to-poo; modelos de um cadastro completo; scripts de codificação, validação de .dfm e
  teste de endpoints.
- Badge do skills.sh no README.
- `docs/roteiro-de-testes.md`: roteiro de testes por skill, com ideias de vídeo.
- `tools/Testar-Sintaxe.ps1`: confere a sintaxe e o BOM de todos os scripts.
- Correções do relatório do agente de testes (Windows PowerShell 5.1, Delphi 13):
  - `Build-Delphi.ps1`: não aborta mais no PS 5.1 (`@($lista)` com `List[object]` num hashtable) e gera o JSON.
  - `GoldenMaster.pas`: golden master aprovado passa (registra asserção; antes caía em `FailsOnNoAsserts`).
  - Detecção de `.dfm` binário corrigida em 9 scripts (`Test-Dfm`, inventários, `Invoke-ReFind`,
    `Find-SqlFirebird`, `Test-CompatibilidadeACBr`, diagnóstico): o binário gravado pela IDE começa com o
    cabeçalho `FF 0A 00` antes de `TPF0`; o inventário nunca acusava DFM binário e o `Test-Dfm` reprovava todos.
  - `Test-Endpoints.ps1`: `-CorpoArquivo`/`-CorpoInvalidoArquivo`, validação do JSON e exemplos que funcionam no PS 5.1.
  - `delphi-characterization-tests`: modelo de `.dproj`, dica de plataforma quando falta o DUnitX, acentos no console.
  - `delphi-safe-refactoring`: `System.UITypes` no modelo da View; herança visual na lista de fora do escopo;
    plataforma dos testes conforme o cliente do banco; novos erros comuns em `validacao.md`.
  - Menos falsos positivos: `Find-PadroesMigracao` ignora comentários e strings e diferencia QuickReport de
    "Qry..."; `Find-CodeSmells` não acusa `Create` com dono; o diagnóstico conta as linhas do método até o
    `end;` e grava o JSON com data e hora; o inventário DBX conta `TSQLTimeStampField`; o resumo do
    `git diff --stat` do `Invoke-ReFind` não corta mais arquivos.
- `tools/Testar-Scripts.ps1`: smoke test que executa os scripts contra uma pasta de exemplo gerada na hora.
- Correções do teste da etapa 5 por um agente independente:
  - Política de git única: árvore limpa no início da tarefa; alterações da própria tarefa são esperadas
    quando uma skill chama outra no meio (`delphi-compile-loop`, `delphi-characterization-tests`);
    commits propostos e feitos só com autorização, pedida uma vez no B0.
  - `delphi-safe-refactoring`: nova etapa B1.5 (rede de segurança entre o levantamento e o plano, em nível
    que sobrevive à troca da tela); o plano passa a perguntar sobre comportamentos do DB-aware e o efeito em
    outras telas que usam as mesmas queries; o compile-loop chamado no B8 não refaz as perguntas.
  - `mapeamento-dbaware.md`: gravação automática ao trocar de linha, `AutoEdit`, edição no grid, Esc,
    `IsValidChar`, estado e confirmação do navegador, com o que perguntar ao usuário.
  - `arquitetura-em-camadas.md`: o que fazer quando o legado usa `max(id)+1` e o banco não tem generator
    (script idempotente, outras telas que inserem na mesma tabela, tabela vazia).
  - Servidor Horse: modelo `ServerProdutos.dproj.modelo` com o search path dos pacotes do Boss 3.x;
    corpo de erro `{"error": ...}` igual ao do HandleException; ordem `Jhonson` antes do `HandleException`
    documentada e testada (na ordem inversa o 500 sai em HTML); `Listen` com callback, acentos e `Flush`
    no console; aviso sobre a mensagem interna do banco no 500; nomes do kit × nomes da documentação do Horse.
  - Roteiro do agente de testes: paradas esperadas no `unCategoria` (não é um caso simples) e checagem do 500.

## 0.1.0 (novembro de 2026)
Versão inicial, apresentada no Dia do ACBr 2026.

- `delphi-legacy-modernizer`: diagnóstico, registro de riscos e plano por fases.
- `delphi-characterization-tests`: testes de caracterização e golden master com DUnitX.
- `delphi-cleanup`: limpeza sem mudança de comportamento.
- `delphi-coding-standards`: modelo de padrão de código do time.
- `delphi-safe-refactoring`: catálogo de refatorações seguras e divisão de DataModules.
- `delphi-unicode-migration` e `delphi-64bit-ready`: migração de versão.
- `delphi-compile-loop`: compilação com MSBuild e ciclo de correção.
- `bde-to-firedac`, `ado-to-firedac`, `dbx-to-firedac`: migração com reFind, com correção de
  dois erros das regras oficiais.
- `sql-dialect-migration`: Firebird → PostgreSQL / SQL Server.
- `acbr-upgrade`: atualização do ACBr com conferência e homologação.
