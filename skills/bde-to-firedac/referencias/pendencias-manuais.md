# Pendências manuais depois do reFind (BDE → FireDAC)

Resolva em lotes pequenos. Antes de qualquer item marcado ⚠️, explique ao usuário e
espere a confirmação: eles podem mudar comportamento.

## 1. Conexão (obrigatório)
O BDE usava alias (`DatabaseName = 'MEUBANCO'`). Depois do reFind, os datasets têm
`ConnectionName = 'MEUBANCO'`. Crie um `TFDConnection` num DataModule central:

```pascal
object FDConnection1: TFDConnection
  ConnectionName = 'MEUBANCO'      // o mesmo nome que os datasets usam
  Params.Strings = (
    'DriverID=FB'
    'Database=C:\Dados\MEUBANCO.FDB'
    'User_Name=SYSDBA'
    'Password=masterkey'
    'CharacterSet=WIN1252')
  LoginPrompt = False
end
```
Se o projeto tinha um `TDatabase`, ele já virou `TFDConnection`. Revise os Params:

| BDE (TDatabase.Params) | FireDAC |
|---|---|
| `USER NAME=` | `User_Name=` |
| `PASSWORD=` | `Password=` |
| `SERVER NAME=` | `Database=` (Firebird: `servidor:caminho`) ou `Server=` + `Database=` |
| `LANGDRIVER=` | `CharacterSet=` (Firebird) |
| alias do BDE Administrator | connection definition em `FDConnectionDefs.ini` ou Params |

Senha fixa no DFM é um problema de segurança. Pergunte ao usuário onde ela deve ficar.

## 2. Driver físico e wait cursor (obrigatório)
Sem eles, o erro aparece em tempo de execução:
- `[FireDAC][Phys]... Driver ID [FB] is not registered` → falta o driver: coloque
  `TFDPhysFBDriverLink` no DataModule ou a unit `FireDAC.Phys.FB` no uses.
- `Object factory for class {...} missing. ... drop component [TFDGUIxWaitCursor]` → falta
  `TFDGUIxWaitCursor` ou a unit `FireDAC.VCLUI.Wait`.

| Banco | Unit do driver | DriverID |
|---|---|---|
| Firebird | `FireDAC.Phys.FB` | `FB` |
| InterBase | `FireDAC.Phys.IB` | `IB` |
| SQL Server | `FireDAC.Phys.MSSQL` | `MSSQL` |
| PostgreSQL | `FireDAC.Phys.PG` | `PG` |
| Oracle | `FireDAC.Phys.Oracle` | `Ora` |
| SQLite | `FireDAC.Phys.SQLite` | `SQLite` |
| MySQL | `FireDAC.Phys.MySQL` | `MySQL` |

## 3. ⚠️ Eventos de cached updates
O reFind troca os tipos (`TUpdateKind→TFDUpdateRequest`, `TUpdateAction→TFDErrorAction`),
mas a assinatura do evento é outra. O compilador vai apontar o erro. Assinatura FireDAC:

```pascal
procedure TDM.qryPedidosUpdateRecord(ASender: TDataSet; ARequest: TFDUpdateRequest;
  var AAction: TFDErrorAction; AOptions: TFDUpdateRowOptions);
```
Ajuste os `case UpdateKind of` para `case ARequest of arInsert, arUpdate, arDelete`.
Para o `OnUpdateError`, use a assinatura que o próprio IDE gera ao criar o evento num
`TFDQuery`, e migre o corpo. Os nomes dos valores mudaram (`uaAbort→eaExitFailure`).

## 4. ⚠️ Master-detail com TQuery
`TQuery.DataSource` virou `MasterSource`. No FireDAC, confira também `MasterFields`: os
parâmetros da query detalhe devem corresponder aos campos do mestre. Cubra com um teste
de caracterização antes de mexer.

## 5. TTable em banco SQL
`TFDTable` funciona, mas em bancos SQL o recomendado é `TFDQuery`. **Não troque durante a
migração**: primeiro migre e valide, depois refatore com os testes passando.

## 6. ⚠️ TBatchMove
Precisa ser reescrito: `TFDBatchMove` + `TFDBatchMoveDataSetReader` + `TFDBatchMoveDataSetWriter`
(ou TextReader/TextWriter). O reFind só troca o nome da classe e os modos.

## 7. Tratamento de erro
`EDBEngineError` virou `EFDDBEngineException`. Códigos numéricos de erro do BDE (`Errors[i].ErrorCode`
com valores BDE como `$2601`) não valem mais. Prefira `E.Kind` (`ekUKViolated`, `ekFKViolated`,
`ekRecordLocked`...), que é independente do banco.

## 8. Paradox / dBase
Não existe driver FireDAC. Opções para discutir com o usuário:
1. Migrar os dados para Firebird/SQLite (recomendado). Use a skill `sql-dialect-migration` para o SQL.
2. Manter temporariamente via ODBC (não recomendado: lento e frágil).

## 9. Session
`Session.*` virou `FDManager.*`. Uso de `Session.NetFileDir`, `PrivateDir` e `ConfigMode`
não tem equivalente: remova com o usuário.

## 10. Verificação final
- Busque de novo os resíduos: `_migracao\pendencias-BDE.txt` deve estar vazio ou só com falsos positivos explicados.
- Rode o teste de carga de forms.
- Confirme que o executável não depende mais do BDE (não precisa do BDE instalado na máquina).
