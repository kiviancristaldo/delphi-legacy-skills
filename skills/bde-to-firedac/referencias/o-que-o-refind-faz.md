# O que o reFind faz na migração BDE → FireDAC

Arquivo oficial: `Samples\Object Pascal\Database\FireDAC\Tool\reFind\BDE2FDMigration\FireDAC_Migrate_BDE.txt`
Executável: `reFind.exe`, na pasta `bin` do RAD Studio.

## Sintaxe das regras
| Regra | Efeito |
|---|---|
| `#unuse <unit>` | remove a unit do `uses` |
| `#remove <propriedade>` | remove a propriedade do PAS e do DFM |
| `#remove DFM: <propriedade>` | remove só do DFM |
| `#migrate <antigo> -> <novo>, <unit1>, <unit2>` | troca o identificador e acrescenta as units ao `uses` |
| `#migrate <Classe>:<antigo> -> <novo>` | troca só em objetos daquela classe |
| `<regex> -> <substituição>` | busca e troca com expressão regular Perl (PCRE) |
| linhas começando com `;` ou `//` | comentário |

## O que as regras oficiais cobrem
- **Units removidas**: `DBTables`, `BDE`, `BDEConst`, `BDEMTS` (e as versões `BDE.*`).
- **Propriedades removidas**: `SessionName`, `PrivateDir`, `Origin` (só DFM).
- **Componentes**: `TDatabase→TFDConnection`, `TTable→TFDTable`, `TQuery→TFDQuery`,
  `TStoredProc→TFDStoredProc`, `TUpdateSQL→TFDUpdateSQL`, `TSession→TFDManager`,
  `TBatchMove→TFDBatchMove`, `TBlobStream→TFDBlobStream`, `TParam(s)→TFDParam(s)`,
  `TDBDataSet/TBDEDataSet→TFDRDBMSDataSet`, `EDBEngineError→EFDDBEngineException`.
  Cada troca acrescenta as units FireDAC necessárias.
- **Propriedades e métodos**: `DatabaseName→ConnectionName`, `AliasName→ConnectionDefName`,
  `Session.*→FDManager.*`, `RequestLive→UpdateOptions.RequestLive`,
  `UpdateMode→UpdateOptions.UpdateMode`, `TransIsolation→TxOptions.Isolation`,
  `Unidirectional→FetchOptions.Unidirectional`, `UpdateRecordTypes→FilterChanges`,
  `TQuery:DataSource→MasterSource`, `TTable:ReadOnly→UpdateOptions.ReadOnly`,
  `TDatabase:Execute→ExecSQL`, métodos de alias (`AddAlias→AddConnectionDef` etc.).
- **Enumerações**: isolamento (`tiReadCommitted→xiReadCommitted`...), `TUpdateKind→TFDUpdateRequest`
  (`ukModify→arUpdate`...), `TUpdateAction→TFDErrorAction` (`uaFail→eaFail`...),
  modos de batch move e cursores de tela.

## O que as regras oficiais NÃO cobrem
1. **Configuração da conexão**: o alias BDE vira só um nome (`ConnectionName`). Você precisa
   criar o `TFDConnection` com `DriverID`/`Database`/usuário, ou um connection definition.
2. **Driver físico e wait cursor**: nenhuma regra acrescenta `TFDPhysXXXDriverLink` nem
   `TFDGUIxWaitCursor`.
3. **Classes próprias herdadas**: regras com restrição de classe (`TQuery:DataSource`)
   não valem para `TMinhaQuery`. Duplique a regra para cada classe filha.
4. **Assinatura de eventos**: `OnUpdateRecord` e `OnUpdateError` têm parâmetros diferentes
   no FireDAC. O reFind troca os tipos, mas não a assinatura.
5. **TBatchMove**: o `TFDBatchMove` usa componentes reader/writer. A API é diferente.
6. **Paradox/dBase**: não existe driver FireDAC.
7. **Params de TDatabase** (`'USER NAME=...'`, `'SERVER NAME=...'`): os nomes mudam
   (`User_Name`, `Database`, `Server`).
8. **Componentes de terceiros** que herdam do BDE (InfoPower `TwwTable/TwwQuery`, RxLib `TRxQuery`).

## Armadilha do próprio reFind
Com `/B:0` (o padrão), se já existir um arquivo `.bak`, o reFind **não substitui nada**,
e numa segunda rodada parece que funcionou. O `Invoke-ReFind.ps1` usa `/B:2` com Git e `/B:1` sem Git.
