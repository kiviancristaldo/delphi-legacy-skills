# Agente de testes do kit (para rodar no Claude Code, no Windows com Delphi)

Você é o agente de testes do kit `delphi-legacy-skills`. Seu trabalho é **executar** os testes
abaixo neste computador, registrar o resultado de cada um e entregar um relatório.
Não corrija as skills: só teste e relate. Quem corrige é quem mantém o kit, a partir do seu relatório.

## Regras
1. **Nunca altere os originais.** Trabalhe só dentro de `C:\TesteSkills`. As pastas de exemplos
   do Delphi e os projetos do usuário são somente leitura.
2. **Não instale nada sem perguntar** (Boss, pacotes npm, Firebird, componentes). Se um teste
   depender de algo que não está instalado, marque como `PULADO` com o motivo.
3. **Banco de dados:** só use bancos de cópia dentro de `C:\TesteSkills`. Nunca conecte em servidor
   remoto nem abra bancos fora de `C:\TesteSkills`. Se o Firebird local estiver instalado como serviço,
   use `localhost` apenas com os arquivos de cópia.
4. Rode os scripts com o **Windows PowerShell 5.1** (`powershell`, não `pwsh`), que é o mais restritivo.
   Exceção: script que recebe JSON na linha de comando (`Test-Endpoints.ps1`) se chama com `& script.ps1`
   dentro de uma sessão do PS 5.1, ou com `-CorpoArquivo`; via `powershell -File` as aspas do JSON somem.
5. Guarde a saída completa de cada comando em `C:\TesteSkills\logs\<nn>-<nome>.txt`.
6. Se algo falhar, **não tente contornar editando a skill**. Registre a falha com a saída e siga para o próximo teste.
7. Ao final, entregue `C:\TesteSkills\RELATORIO-TESTES.md` (formato no fim deste arquivo).

## Etapa 0: preparação
1. Crie `C:\TesteSkills` e `C:\TesteSkills\logs`.
2. Clone o kit em `C:\TesteSkills\delphi-legacy-skills` (ou use esta pasta, se você já está nela).
3. Copie as demos (copiar, nunca mover):
   - `C:\Users\Public\Documents\Embarcadero\Studio\37.0\Samples\Object Pascal\Database\FireDAC\Tool\reFind\BDE2FDMigration\Demo` → `C:\TesteSkills\MastApp`
   - `...\reFind\DBX2FDMigration\Demo` → `C:\TesteSkills\MeetingOrganizer`
4. Em cada cópia: `git init`, `git add .`, `git -c user.name=teste -c user.email=teste@local commit -m original`.
5. Registre a versão do PowerShell (`$PSVersionTable.PSVersion`), do Delphi (pasta `Studio\37.0` existe?)
   e se `boss`, `npx` e o Firebird (`isql.exe`) estão disponíveis.

## Etapa 1: sintaxe e instalação
| # | Teste | Comando | Passa se |
|---|---|---|---|
| 1.1 | Sintaxe dos scripts | `powershell -ExecutionPolicy Bypass -File C:\TesteSkills\delphi-legacy-skills\tools\Testar-Sintaxe.ps1` | todas as linhas `OK`, código de saída 0 |
| 1.2 | Lista das skills | `npx skills add kiviancristaldo/delphi-legacy-skills --list` (pergunte antes, se `npx` não estiver instalado) | 13 skills listadas |
| 1.3 | Smoke test dos scripts | `powershell -ExecutionPolicy Bypass -File C:\TesteSkills\delphi-legacy-skills\tools\Testar-Scripts.ps1` | todas as verificações `OK`, código de saída 0 (sem Delphi, as de build/DFM aparecem como `PULADO`) |

Se 1.1 ou 1.3 falharem, **continue mesmo assim**, mas registre cada script com erro: os testes que dependem dele vão falhar também.
O 1.1 só confere sintaxe; o 1.3 executa os scripts e pega erros de execução (por exemplo, incompatibilidades do PS 5.1).

Nos comandos abaixo, `$K` = `C:\TesteSkills\delphi-legacy-skills\skills`.

## Etapa 2: scripts de análise (não alteram nada)
| # | Teste | Comando | Passa se |
|---|---|---|---|
| 2.1 | Diagnóstico | `powershell -ExecutionPolicy Bypass -File $K\delphi-legacy-modernizer\scripts\Get-DiagnosticoLegado.ps1 -Pasta C:\TesteSkills\MastApp -Recursivo` | gera `_modernizacao\diagnostico.md` e o `.json`; abra 3 itens de "maiores métodos" e 2 blocos duplicados e confira se são verdadeiros |
| 2.2 | Diagnóstico comparando | mesmo comando com `-Comparar _modernizacao\diagnostico-<data>.json` | aparece a seção "Antes × depois" |
| 2.3 | Code smells | `...\delphi-cleanup\scripts\Find-CodeSmells.ps1 -Pasta C:\TesteSkills\MastApp -Recursivo`; depois o mesmo com `-Arquivos "DataMod.pas,SrchDlg.pas"` | gera `limpeza.md` agrupado em prioridade alta/média/baixa, com `arquivo:linha`; confira 5 itens (tamanho e complexidade de método, var/out, duplicação, assuntos do `DataMod`) e anote falsos positivos; no escopo parcial, `TSearchDlg.ShowModalCust` aparece em "Não remover: escopo parcial" e não em "Método possivelmente sem uso" |
| 2.4 | Padrões Unicode | `...\delphi-unicode-migration\scripts\Find-PadroesMigracao.ps1 -Tipo Unicode -Pasta C:\TesteSkills\MastApp -Recursivo` | gera `padroes-Unicode.md` |
| 2.5 | Padrões Win64 | mesmo script com `-Tipo Win64` | gera `padroes-Win64.md`; deve apontar `DBTables` (BDE) |
| 2.6 | SQL Firebird | `...\sql-dialect-migration\scripts\Find-SqlFirebird.ps1 -Pasta C:\TesteSkills\MeetingOrganizer -Destino PG -Recursivo` | gera o relatório; rode também com `-Destino MSSQL` |
| 2.7 | Inventário BDE | `...\bde-to-firedac\scripts\Get-InventarioAcessoDados.ps1 -Origem BDE -Pasta C:\TesteSkills\MastApp -Recursivo` | conta TTable/TQuery/TDatabase; confira a contagem com uma busca no `.dfm` |
| 2.8 | Inventário DBX | `...\dbx-to-firedac\scripts\Get-InventarioAcessoDados.ps1 -Origem DBX -Pasta C:\TesteSkills\MeetingOrganizer -Recursivo` | conta TSQLConnection/TSQLQuery etc. e acha o `dbxconnections.ini` |

Antes da etapa 3, faça commit dos relatórios gerados em cada cópia (`git add -A && git commit -m relatorios`).

## Etapa 3: scripts que alteram (só nas cópias)
| # | Teste | Comando | Passa se |
|---|---|---|---|
| 3.1 | reFind simulado | `...\bde-to-firedac\scripts\Invoke-ReFind.ps1 -Origem BDE -Pasta C:\TesteSkills\MastApp -Recursivo -Simular` | cria `_migracao\regras-efetivas-BDE.txt`; `git status` sem `.pas`/`.dfm` alterados |
| 3.2 | Trava do Git | altere qualquer `.pas` sem commit e rode 3.1 **sem** `-Simular` | o script **recusa** ("PARE") com código 3; depois desfaça com `git checkout -- .` |
| 3.3 | reFind real (BDE) | rode 3.1 sem `-Simular` | `.pas`/`.dfm` alterados, `pendencias-BDE.txt` gerado; anote o resumo do `git diff --stat` |
| 3.4 | reFind real (DBX) | `...\dbx-to-firedac\scripts\Invoke-ReFind.ps1 -Origem DBX -Pasta C:\TesteSkills\MeetingOrganizer -Recursivo` | a saída mostra "Correções aplicadas" (TSQLConnecion); confira no diff que propriedades de `TSQLConnection` foram migradas |
| 3.5 | Build (BDE migrado) | `...\delphi-compile-loop\scripts\Build-Delphi.ps1 -Projeto C:\TesteSkills\MastApp\mastapp.dproj` | gera `_build\build-result.json`; **compilar com erro é esperado** depois do reFind (pendências manuais). O teste é o script: os totais batem com os erros do log? |
| 3.6 | Build (DBX migrado) | idem para `C:\TesteSkills\MeetingOrganizer\Forms\MeetingOrganizer.dproj` | idem |

## Etapa 4: testes de caracterização (gera código)
Crie `C:\TesteSkills\Caracterizacao`, com uma unit simples de regra para servir de alvo:
```pascal
unit uRegras;
interface
function CalcularDesconto(AValor: Currency; AClienteVIP: Boolean): Currency;
implementation
function CalcularDesconto(AValor: Currency; AClienteVIP: Boolean): Currency;
begin
  if AClienteVIP and (AValor > 1000) then
    Result := AValor * 0.10
  else if AValor > 5000 then
    Result := AValor * 0.05
  else
    Result := 0;
end;
end.
```
Siga a skill `delphi-characterization-tests` (`$K\delphi-characterization-tests\SKILL.md`) para criar
o projeto de testes com os modelos da pasta `modelos\`, incluindo o `GoldenMaster.pas` e o
`ProjetoTestes.dproj.modelo`. Confira antes em que plataforma o DUnitX está compilado
(`lib\win32\release` e `lib\win64\release` do RAD Studio) e use `-Plataforma` de acordo.

| # | Teste | Passa se |
|---|---|---|
| 4.1 | Projeto de testes compila | `Run-Tests.ps1 -Projeto <...>Tests.dproj` compila (`.dproj` criado a partir de `ProjetoTestes.dproj.modelo`) |
| 4.2 | Testes passam | código de saída 0 |
| 4.3 | Golden master | a primeira execução cria `.received.txt`; `Approve-GoldenMaster.ps1` aprova; a segunda passa |
| 4.4 | Teste dos testes | troque `> 1000` por `>= 1000`, rode: **algum teste precisa falhar**; desfaça |

## Etapa 5: transformação em camadas (gera código)
Alvo: o cadastro de categorias do curso (`cursoEmbarcadero\Módulo Plataformas`, unit `unCategoria`),
copiado para `C:\TesteSkills\ListaCompras`. O repositório é `github.com/kiviancristaldo/cursoEmbarcadero`
(privado): se não estiver no computador, pergunte se pode cloná-lo em `C:\TesteSkills`; sem ele, PULADO.

1. Banco: só se o Firebird 3+ estiver instalado. Crie `C:\TesteSkills\ListaCompras\PRODUTOS.FDB` com o
   script `DATA\Database.sql.txt` do curso e insira 5 categorias e 10 produtos. Use
   `DEFAULT CHARACTER SET WIN1252` (os TFields persistentes do curso são `TStringField`; com UTF8 o
   FireDAC entrega `WideString` e dá "Type mismatch"). Aponte o DataModule da **cópia** para esse arquivo.
   Sem Firebird: PULADO nos itens que precisam de banco.
   - **Plataforma**: veja se o `fbclient.dll` instalado é 32 ou 64 bits. Com Firebird 32 bits, aplicativo,
     servidor e testes precisam ser **Win32**; se o DUnitX só vier compilado para Win64, use o fonte do
     DUnitX (github.com/VSoftTechnologies/DUnitX) no `.dproj` de testes.
2. Siga a skill `delphi-safe-refactoring`, modo B, para o form de categorias, com endpoints Horse.
   Como você é um agente de teste, responda você mesmo às perguntas da skill com as recomendações
   dela e **registre cada pergunta que a skill fez** (o teste é ver se ela pergunta).

| # | Teste | Passa se |
|---|---|---|
| 5.1 | Fluxo | a skill fez levantamento, rede de segurança, plano e perguntas uma por vez antes de escrever código. Atenção: o `unCategoria` **não** é um caso simples; ele cai em dois itens fora do escopo (herança visual de `TForm1` e `TDBNavigator`) e o legado usa `max(id)+1`. Paradas esperadas, no mínimo: assunto, autorização de commit, criar a caracterização, herança visual, TDBNavigator, geração do id, gravação automática ao trocar de linha e confirmação do plano |
| 5.2 | Camadas | existem `Types`, `Connection.Database`, `Models`, `Controllers` e a View sem `TDB*` (exceto `TDBGrid`) e sem referência ao DataModule |
| 5.3 | Codificação | `Normalize-Encoding.ps1` roda sem aviso |
| 5.4 | DFM | `Test-Dfm.ps1` nos `.dfm` alterados: todos `OK` |
| 5.5 | Compila | `Build-Delphi.ps1` no projeto do aplicativo: 0 erros |
| 5.6 | Servidor | só se o Horse estiver disponível (Boss): compila o servidor; **não instale sem perguntar** |
| 5.7 | Endpoints | servidor rodando com o banco de cópia: `& $K\delphi-safe-refactoring\scripts\Test-Endpoints.ps1 -BaseUrl http://localhost:9000 -Recurso categorias -Corpo '{"nome":"Teste skill","ordem":7}' -CorpoInvalido <corpo que viole uma regra real>` (chamado com `&` numa sessão do PS 5.1) com todas as chamadas `OK`; e um 500 provocado (excluir categoria com produtos) responde JSON `{"error": ...}`, não HTML |
| 5.8 | Trava de escopo | em outra cópia, peça a transformação da `unListaCompras` (tem `TDBLookupComboBox`): a skill tem que **parar e perguntar** |

## Etapa 6: limpeza da execução
Pare servidores que você abriu. Não apague `C:\TesteSkills`: o usuário vai querer ver os arquivos.

## Formato do relatório (`C:\TesteSkills\RELATORIO-TESTES.md`)
```markdown
# Relatório de testes do kit delphi-legacy-skills
Data · Windows · PowerShell · Delphi · ferramentas disponíveis (boss, npx, Firebird)

## Resumo
| Etapa | Passou | Falhou | Pulado |

## Resultados
| # | Teste | Resultado | Tempo | Observação | Log |
(uma linha por teste: PASSOU / FALHOU / PULADO)

## Falhas em detalhe
Para cada falha: comando exato, trecho relevante da saída (até 40 linhas), o que você acha que
causou (hipótese, não correção), e qual arquivo do kit está envolvido.

## Falsos positivos encontrados
Itens dos relatórios de análise que não eram problema de verdade.

## Perguntas que as skills fizeram (etapa 5)
```
