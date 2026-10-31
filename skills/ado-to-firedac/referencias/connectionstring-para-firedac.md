# ConnectionString OLE DB → Params FireDAC

Leia a `ConnectionString` (DFM, PAS, arquivo `.udl` ou `.ini`), identifique o Provider e monte
os Params. **Nunca copie senhas para o relatório ou para o chat.**

## SQL Server
Providers: `SQLOLEDB`, `SQLOLEDB.1`, `SQLNCLI`, `SQLNCLI11`, `MSOLEDBSQL`

| OLE DB | FireDAC |
|---|---|
| `Provider=SQLOLEDB.1` | `DriverID=MSSQL` |
| `Data Source=SERVIDOR\INSTANCIA` | `Server=SERVIDOR\INSTANCIA` |
| `Initial Catalog=Banco` | `Database=Banco` |
| `User ID=sa` | `User_Name=sa` |
| `Password=...` | `Password=...` |
| `Integrated Security=SSPI` | `OSAuthent=Yes` |
| `Application Name=X` | `ApplicationName=X` |
| `Persist Security Info=...`, `Use Procedure for Prepare`, `Auto Translate`, `Packet Size` | sem equivalente: remover |

Antes:
```
ConnectionString = 'Provider=SQLOLEDB.1;Integrated Security=SSPI;Initial Catalog=Vendas;Data Source=SRV01'
```
Depois:
```pascal
object FDConnection1: TFDConnection
  Params.Strings = (
    'DriverID=MSSQL'
    'Server=SRV01'
    'Database=Vendas'
    'OSAuthent=Yes')
  LoginPrompt = False
end
```
Driver: `TFDPhysMSSQLDriverLink` / unit `FireDAC.Phys.MSSQL`.

**Implantação**: o driver MSSQL do FireDAC usa um driver ODBC da Microsoft instalado na
máquina do cliente ("ODBC Driver 17/18 for SQL Server" ou o SQL Native Client). Isso muda
o instalador. Nas versões recentes do driver ODBC, a criptografia vem ligada por padrão e
servidores com certificado autoassinado recusam a conexão. Nesse caso, configure a
criptografia/confiança no certificado conforme a política do cliente (via `ODBCAdvanced`)
e documente a decisão.

## Access (Jet / ACE)
Providers: `Microsoft.Jet.OLEDB.4.0`, `Microsoft.ACE.OLEDB.12.0`

| OLE DB | FireDAC |
|---|---|
| `Provider=Microsoft.Jet.OLEDB.4.0` | `DriverID=MSAcc` |
| `Data Source=C:\Dados\base.mdb` | `Database=C:\Dados\base.mdb` |
| `Jet OLEDB:Database Password=...` | `Password=...` |

Driver: `TFDPhysMSAccessDriverLink` / unit `FireDAC.Phys.MSAcc`. Também depende do driver
ODBC do Access na máquina, com a mesma "bitagem" (32/64) do executável.

Excel ou arquivos texto via Jet (`Extended Properties=Excel 8.0`): não migre automaticamente.
Discuta com o usuário (`TFDBatchMove` com TextReader, ou componente de planilha).

## Oracle
Providers: `OraOLEDB.Oracle`, `MSDAORA`

| OLE DB | FireDAC |
|---|---|
| `Provider=OraOLEDB.Oracle` | `DriverID=Ora` |
| `Data Source=TNSNAME` | `Database=TNSNAME` |
| `User ID` / `Password` | `User_Name` / `Password` |

Driver: unit `FireDAC.Phys.Oracle` (usa o Oracle Client instalado).

## ODBC via OLE DB
Provider: `MSDASQL`. Normalmente `Data Source=<DSN>`.
→ Prefira o driver FireDAC nativo do banco real. Se precisar manter ODBC:
`DriverID=ODBC`, `DataSource=<DSN>`, unit `FireDAC.Phys.ODBC`.

## Onde colocar o resultado
Pergunte ao usuário. As opções, da melhor para a pior:
1. `FDConnectionDefs.ini` + `ConnectionDefName` no `TFDConnection` (troca de ambiente sem recompilar).
2. Params lidos de um `.ini` da aplicação no `BeforeConnect`.
3. Params fixos no DFM (só para desenvolvimento, nunca com senha).
