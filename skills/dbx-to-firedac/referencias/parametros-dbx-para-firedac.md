# Parâmetros dbExpress → FireDAC

## DriverName
| dbExpress (`DriverName`) | FireDAC (`DriverID` / `DriverName`) | Unit do driver |
|---|---|---|
| `Firebird` | `FB` | `FireDAC.Phys.FB` |
| `Interbase` | `IB` | `FireDAC.Phys.IB` |
| `MSSQL` | `MSSQL` | `FireDAC.Phys.MSSQL` |
| `Oracle` | `Ora` | `FireDAC.Phys.Oracle` |
| `MySQL` | `MySQL` | `FireDAC.Phys.MySQL` |
| `Sqlite` | `SQLite` | `FireDAC.Phys.SQLite` |
| `Db2` | `DB2` | `FireDAC.Phys.DB2` |
| `Odbc` | `ODBC` | `FireDAC.Phys.ODBC` |

## Params (Firebird/InterBase, o caso mais comum)
| dbExpress (`Params.Strings`) | FireDAC | Observação |
|---|---|---|
| `DriverName=Firebird` | `DriverID=FB` | |
| `Database=servidor:C:\dados\BANCO.FDB` | `Database=C:\dados\BANCO.FDB` + `Server=servidor` | as duas formas funcionam, a separada fica mais clara |
| `HostName=servidor` | `Server=servidor` | |
| `User_Name=SYSDBA` | `User_Name=SYSDBA` | mesmo nome |
| `Password=...` | `Password=...` | mesmo nome; nunca no DFM em produção |
| `RoleName=...` | `RoleName=...` | não deixe o texto literal `RoleName=RoleName` que o IDE gerava |
| `ServerCharSet=WIN1252` | `CharacterSet=WIN1252` | |
| `SQLDialect=3` | `SQLDialect=3` | |
| `IsolationLevel=ReadCommitted` | `TxOptions.Isolation = xiReadCommitted` | propriedade do componente, não Param |
| `CommitRetain=False` | `TxOptions.AutoCommit` / comportamento de transação | revisar com o usuário |
| `WaitOnLocks=True` | `UpdateOptions.LockWait = True` | propriedade do componente |
| `BlobSize=-1`, `LocaleCode`, `ErrorResourceFile`, `Trim Char`, `Interbase TransIsolation`, `GetDriverFunc`, `LibraryName`, `VendorLib` | remover | sem equivalente / não usados pelo FireDAC |

Para cliente Firebird específico (o antigo `VendorLib=fbclient.dll`): use
`TFDPhysFBDriverLink.VendorLib`. Essa é a propriedade certa no FireDAC, e não a do `TFDConnection`.

Exemplo, antes:
```
object SQLConnection1: TSQLConnection
  ConnectionName = 'MeuBanco'
  DriverName = 'Firebird'
  LoginPrompt = False
  Params.Strings = (
    'DriverName=Firebird'
    'Database=localhost:C:\Dados\SISTEMA.FDB'
    'RoleName=RoleName'
    'User_Name=sysdba'
    'Password=masterkey'
    'ServerCharSet=WIN1252'
    'SQLDialect=3'
    'BlobSize=-1'
    'CommitRetain=False'
    'WaitOnLocks=True'
    'IsolationLevel=ReadCommitted'
    'Trim Char=False')
  VendorLib = 'fbclient.dll'
end
```
Depois:
```
object SQLConnection1: TFDConnection
  ConnectionName = 'MeuBanco'
  Params.Strings = (
    'DriverID=FB'
    'Server=localhost'
    'Database=C:\Dados\SISTEMA.FDB'
    'User_Name=sysdba'
    'Password=masterkey'
    'CharacterSet=WIN1252'
    'SQLDialect=3')
  LoginPrompt = False
end
object FDPhysFBDriverLink1: TFDPhysFBDriverLink
  VendorLib = 'fbclient.dll'
end
object FDGUIxWaitCursor1: TFDGUIxWaitCursor
end
```
Mantenha o nome do componente (`SQLConnection1`): o código continua compilando. Renomear é outra etapa.

## dbxconnections.ini → FDConnectionDefs.ini
Cada seção `[Nome]` do `dbxconnections.ini` vira uma seção do `FDConnectionDefs.ini`,
com os parâmetros convertidos pela tabela acima:
```ini
[MeuBanco]
DriverID=FB
Server=localhost
Database=C:\Dados\SISTEMA.FDB
User_Name=sysdba
CharacterSet=WIN1252
```
No `TFDConnection`, use `ConnectionDefName = 'MeuBanco'`. O FireDAC procura o arquivo de
definições conforme `FDManager.ConnectionDefFileName`. Pergunte ao usuário onde o arquivo
vai ficar na instalação.

`LoadParamsOnConnect = True` + `ConnectionName` era o jeito DBX de ler do ini. No FireDAC,
`ConnectionDefName` faz isso. Remova `LoadParamsOnConnect`.
