# Roteiro de testes do kit

Objetivo: provar que cada skill funciona num Delphi real antes de divulgar, e gravar o que
der certo como vídeo. Marque `[x]` conforme for testando e anote o que falhou numa *issue*.

**Regras para todos os testes**
- Sempre numa **cópia** do projeto, dentro de um repositório Git próprio (`git init` + commit inicial).
- Rode os scripts pelo **Windows PowerShell 5.1** (o padrão do Windows), que é o mais restritivo.
- Guarde a saída do console de cada teste: ela vira a *issue* se algo falhar, ou a prova no vídeo.

## Projetos de teste
Os três primeiros já vêm com o Delphi 13:

| Projeto | Onde | Bom para testar |
|---|---|---|
| **MastApp (BDE)** | `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Samples\Object Pascal\Database\FireDAC\Tool\reFind\BDE2FDMigration\Demo` | diagnóstico, limpeza, bde-to-firedac, compile-loop |
| **MeetingOrganizer (dbExpress)** | `...\reFind\DBX2FDMigration\Demo` (tem banco `.GDB` e o script `MeetingOrganizer.sql`) | dbx-to-firedac (correção `TSQLConnecion`), sql-dialect-migration |
| **MastApp (IBX)** | `...\reFind\IBX2FDMigration\Demo` | diagnóstico, refatoração |
| Um projeto ADO pequeno | criar ou usar um real | ado-to-firedac (não há demo ADO na pasta do reFind) |
| Um projeto real seu (cópia) | | todos, principalmente os números do diagnóstico para a palestra |
| Um projeto com ACBr | | acbr-upgrade |

Copie cada demo para uma pasta de trabalho (ex.: `C:\TesteSkills\MastApp`), nunca rode na pasta de exemplos.

---

## Fase 0: instalação e sintaxe
- [ ] `powershell -ExecutionPolicy Bypass -File tools\Testar-Sintaxe.ps1`: todos os scripts `OK`.
- [ ] `powershell -ExecutionPolicy Bypass -File tools\Testar-Scripts.ps1`: todas as verificações `OK`.
- [ ] `npx skills add kiviancristaldo/delphi-legacy-skills --list`: aparecem as 13 skills.
- [ ] Instalar todas num projeto de teste e **ler a saída inteira**: nenhuma linha `Skipped` ou `parse error`.
- [ ] Abrir o Claude Code no projeto, digitar `/` e ver as skills listadas.
- [ ] Badge do skills.sh no README mostrando instalações (aparece depois da primeira instalação).

## Fase 1: scripts isolados (sem IA)
Cada script roda sozinho. Confira se termina sem erro e se o relatório faz sentido.

| # | Script | Comando (na cópia do projeto) | Conferir |
|---|---|---|---|
| 1 | Diagnóstico | `...\delphi-legacy-modernizer\scripts\Get-DiagnosticoLegado.ps1 -Pasta . -Recursivo` | units e linhas batem com o explorador de arquivos; maiores métodos são mesmo os maiores; blocos duplicados são de fato iguais |
| 2 | Diagnóstico (comparar) | rodar de novo com `-Comparar _modernizacao\diagnostico-<data>.json` | aparece a tabela "Antes × depois" |
| 3 | Code smells | `...\delphi-cleanup\scripts\Find-CodeSmells.ps1 -Pasta . -Recursivo` | abrir 5 itens de cada tipo e ver se são verdadeiros; anotar os falsos positivos |
| 4 | Padrões Unicode | `...\delphi-unicode-migration\scripts\Find-PadroesMigracao.ps1 -Tipo Unicode -Pasta . -Recursivo` | idem |
| 5 | Padrões Win64 | mesmo script com `-Tipo Win64` | idem |
| 6 | Inventário BDE | `...\bde-to-firedac\scripts\Get-InventarioAcessoDados.ps1 -Origem BDE -Pasta .` | contagem de TTable/TQuery bate com o MastApp |
| 7 | reFind simulado | `...\bde-to-firedac\scripts\Invoke-ReFind.ps1 -Origem BDE -Pasta . -Simular` | arquivo `_migracao\regras-efetivas-BDE.txt` criado; nada alterado (`git status` limpo, exceto `_migracao`) |
| 8 | reFind real | mesmo comando sem `-Simular` | `git diff --stat` mostra .pas e .dfm alterados; `pendencias-BDE.txt` gerado |
| 9 | reFind sem commit | alterar um arquivo e rodar sem `-Simular` | **deve recusar** com "PARE" |
| 10 | DBX + correção | `Invoke-ReFind.ps1 -Origem DBX` no MeetingOrganizer | mensagem "Correções aplicadas" com 14 linhas; comparar com o resultado do `migrate.bat` original |
| 11 | Build | `...\delphi-compile-loop\scripts\Build-Delphi.ps1 -Projeto <x>.dproj` | totais de erros/warnings batem com o IDE; `_build\build-result.json` criado |
| 12 | Testes | `...\delphi-characterization-tests\scripts\Run-Tests.ps1 -Projeto Testes\<x>Tests.dproj` | compila e roda o DUnitX; código de saída 0 com tudo verde |
| 13 | SQL Firebird | `...\sql-dialect-migration\scripts\Find-SqlFirebird.ps1 -Pasta . -Destino PG -Recursivo` | encontra construções reais; rodar também com `-Destino MSSQL` |
| 14 | ACBr | `...\acbr-upgrade\scripts\Test-CompatibilidadeACBr.ps1 -Pasta . -FontesACBr <fontes novos> -Recursivo` | lista componentes ACBr usados; itens "não encontrado" são reais |

## Fase 2: skills com a IA (Claude Code)
Para cada teste: **conversa nova**, um pedido em linguagem natural, sem citar o nome da skill.
Conferir (1) se a skill certa foi acionada, (2) se seguiu o processo, (3) se parou onde deveria.

| # | Skill | Pedido | O que tem que acontecer |
|---|---|---|---|
| 1 | delphi-legacy-modernizer | "Por onde eu começo a modernizar este sistema?" | roda o diagnóstico, faz perguntas de contexto, monta o registro de riscos, sugere o plano |
| 2 | delphi-characterization-tests | "Crie testes para o cálculo do botão X antes de eu mexer nele" | cria projeto DUnitX, registra o comportamento atual, faz o "teste dos testes" |
| 3 | delphi-cleanup | "Limpa essa unit pra mim" | roda o script, ataca risco baixo primeiro, um commit por tipo, pergunta antes de mexer em `except` vazio |
| 4 | delphi-coding-standards | "Revise esta unit" | aponta desvios no formato arquivo:linha + regra + correção |
| 5 | delphi-safe-refactoring | "Tira a regra de negócio desse OnClick" | **recusa sem testes** ou cria os testes antes; passos pequenos com compilação entre eles |
| 6 | delphi-unicode-migration | "Vou migrar este projeto do Delphi 7" | pede o golden master dos arquivos gerados antes de mexer |
| 7 | delphi-64bit-ready | "Quero compilar em 64 bits" | levanta DLLs e componentes sem 64 bits **antes** de qualquer coisa |
| 8 | delphi-compile-loop | "Faz compilar e zera os warnings" | tabela de rodadas; nenhum `{$WARN OFF}` |
| 9 | bde-to-firedac | "Tira o BDE desse projeto" (MastApp) | inventário, regras do projeto mostradas para aprovação, `-Simular` antes, pendências, compile-loop |
| 10 | dbx-to-firedac | "Migra o dbExpress para FireDAC" (MeetingOrganizer) | menciona a correção do `TSQLConnecion`, converte os Params |
| 11 | ado-to-firedac | "Migra o ADO para FireDAC" | converte a ConnectionString sem expor senha |
| 12 | sql-dialect-migration | "Converte este banco Firebird para PostgreSQL" (use o `MeetingOrganizer.sql`) | pergunta versão e dialeto; scripts DDL numerados com `-- ATENÇÃO:` |
| 13 | acbr-upgrade | "Quero atualizar o ACBr" | **não inventa** nomes de propriedade; usa o script e manda para changelog/fórum o que não achar |

**Teste de acionamento**: repita 3 pedidos de cada linha com palavras diferentes. Se a skill
não for acionada, ajuste a `description` com as palavras usadas e teste de novo.

## Fase 3: números para a palestra
- [ ] Rodar o diagnóstico num projeto real (com autorização) e anotar 3 números de impacto:
      maior unit (linhas e tokens), maior evento de tela, % de duplicação.
- [ ] Rodar o MastApp do início ao fim: diagnóstico → bde-to-firedac → compile-loop, cronometrando.
- [ ] Atualizar o slide "O custo também é em tokens" com números reais, se forem mais fortes.

## Ideias de vídeo (um por teste que der certo)
Formato sugerido: 3 a 8 minutos, tela do Claude Code + IDE, começando pela dor e terminando no antes × depois.

| Vídeo | Conteúdo | Gancho |
|---|---|---|
| 1 | O que é uma skill (pasta, SKILL.md, 3 níveis) | "Um dev sênior numa pasta" |
| 2 | Diagnóstico de um legado real | "Quantos tokens custa o seu DataModule?" |
| 3 | Testes de caracterização + teste dos testes | "Teste que não falha não protege nada" |
| 4 | Tirando a regra do OnClick com segurança | "800 linhas num Button1Click" |
| 5 | MastApp: BDE → FireDAC em minutos | "O reFind tinha um erro, e a skill corrige" |
| 6 | Compile-loop: zerando warnings | "O compilador correto, não quieto" |
| 7 | Criando a skill do padrão de código do seu time | "Faça a IA escrever do seu jeito" |
| 8 | Instalando o kit com `npx skills add` | "Um comando, 13 skills" |

## Registro dos testes
| Data | Teste | Projeto | Resultado | Issue/observação |
|---|---|---|---|---|
| | | | | |
