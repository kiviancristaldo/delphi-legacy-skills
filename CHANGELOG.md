# Histórico de versões

## Não lançado
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
