# O que o reFind faz na migração dbExpress → FireDAC

Arquivo oficial: `Samples\Object Pascal\Database\FireDAC\Tool\reFind\DBX2FDMigration\FireDAC_Migrate_DBX.txt`

## ⚠️ Erro conhecido no arquivo oficial
Todas as regras da seção `// TSQLConnection` estão escritas com a classe **`TSQLConnecion`**
(falta o "t"). Como a restrição de classe não casa com nada, estas trocas **nunca acontecem**:

| Regra (nunca aplicada) | Troca esperada |
|---|---|
| `CloseDataSets` | `ReleaseClients(rmDisconnect)` |
| `Execute`, `ExecuteDirect` | `ExecSQL` |
| `GetDefaultSchemaName` | `CurrentSchema` |
| `ActiveStatements` | `RefCount` |
| `ConnectionState` | `State` |
| `MultipleTransactionsSupported` | `ConnectionMetaDataIntf.TxSavepoints` |
| `DBXConnection` | `ConnectionIntf` |
| `SQLHourGlass` | `ResourceOptions.SilentMode` |
| `TransactionsSupported` | `ConnectionMetaDataIntf.TxSupported` |
| `ConnectionName` | `ConnectionDefName` |
| `KeepConnection` | `ResourceOptions.KeepConnection` |

O `Invoke-ReFind.ps1` corrige numa cópia das regras (o arquivo da Embarcadero não é alterado).

> Observação: a regra de `SQLHourGlass` troca um booleano "mostrar ampulheta" por
> `SilentMode`, que tem sentido inverso. Depois da migração, confira o valor atribuído.

## O que as regras oficiais cobrem
- **Units removidas**: `SqlExpr`, `DBXCommon`, `DBConnAdmin`, `DBXDynalink` (e versões `Data.*`).
- **Units de driver**: `Data.DbxFirebird→FireDAC.Phys.FB`, `Data.DbxInterbase→FireDAC.Phys.IB`,
  `Data.DbxMSSQL→FireDAC.Phys.MSSQL`, `Data.DbxOracle→FireDAC.Phys.Oracle`, `Data.DbxMySql→FireDAC.Phys.MySQL`,
  `Data.DbxSqlite→FireDAC.Phys.SQLite`, `Data.DbxDb2→FireDAC.Phys.DB2`, `Data.DbxOdbc→FireDAC.Phys.ODBC`,
  `Data.DbxInformix→FireDAC.Phys.Infx`, `Data.DbxSybaseASA→FireDAC.Phys.ASA`.
- **Componentes**: `TSQLConnection→TFDConnection`, `TSQLQuery→TFDQuery`, `TSQLDataSet→TFDQuery`,
  `TSQLTable→TFDTable`, `TSQLStoredProc→TFDStoredProc`, `TSQLBlobStream→TFDBlobStream`,
  `TDBXError→EFDDBEngineException`, `TParam(s)→TFDParam(s)`.
  Transações (`TTransactionDesc`, `TDBXTransaction`) viram tipos de compatibilidade da unit
  auxiliar `FireDAC.DBX.Migrate`.
- **Datasets**: `SQLConnection→Connection`, `DataSource→MasterSource`, `ParamCheck→ResourceOptions.ParamCreate`,
  `PrepareStatement→Prepare`, `SortFieldNames→IndexFieldNames`, `TSQLTable:DeleteRecords→ServerDeleteAll`.
- **Administração**: `GetConnectionAdmin.*→FDManager.*`, `AddConnection→AddConnectionDef`...
- **Enumerações**: isolamento, estado da conexão, tipos de metadados (`stTables→mkTables`...).
- **Removidas**: `Origin`, `AutoClone`, `LocaleCode`, `UniqueID`, `GetDriverFunc`, `LibraryName`,
  `ValidatePeerCertificate`, `MaxBlobSize`, `SchemaName`.

## O que as regras oficiais NÃO cobrem
1. **`VendorLib`**: não é removida. Fica no DFM do `TFDConnection` e dá erro ao carregar o form.
   O modelo de regras do projeto já traz `#remove VendorLib`.
2. **`DriverName`**: o `TFDConnection` também tem `DriverName`, mas os valores são outros
   (`'Firebird'` → `'FB'`). Compila e falha em execução. O modelo traz a regra para Firebird.
3. **Params da conexão** (`Params.Strings`): nomes e valores diferentes. Veja
   [parametros-dbx-para-firedac.md](parametros-dbx-para-firedac.md).
4. **`TSimpleDataSet`** e **`TSQLMonitor`**: não migrados (o arquivo lista o monitor como "not supported").
5. **`LoadParamsOnConnect`, `LoadParamsFromIniFile`, `dbxconnections.ini`**: sem equivalente direto.
6. **Classes próprias herdadas** de `TSQLQuery` etc.
7. **Driver físico e wait cursor**.

## Armadilha do próprio reFind
Com `/B:0` (o padrão), se já existir `.bak`, o reFind não substitui nada. O script usa `/B:2`
com Git e `/B:1` sem Git.
