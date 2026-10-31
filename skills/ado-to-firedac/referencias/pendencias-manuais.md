# Pendências manuais depois do reFind (ADO → FireDAC)

Resolva em lotes pequenos. Itens ⚠️ podem mudar comportamento: explique e espere a confirmação.

## 1. Conexão (obrigatório)
Converta a ConnectionString: veja [connectionstring-para-firedac.md](connectionstring-para-firedac.md).
Depois remova do DFM as linhas `ConnectionString = ...` e `Provider = ...` que sobraram.

## 2. Driver físico e wait cursor (obrigatório)
- `Driver ID [MSSQL] is not registered` → `TFDPhysMSSQLDriverLink` ou unit `FireDAC.Phys.MSSQL`.
- `Object factory for class {...} missing ... TFDGUIxWaitCursor` → `TFDGUIxWaitCursor` ou unit `FireDAC.VCLUI.Wait`.

## 3. Parâmetros
- `Parameters.ParamByName('X').Value` → `Params.ParamByName('X').Value` (a regra já troca).
- `Parameters.Refresh`: sem equivalente direto. No `TFDStoredProc`, use `Prepare` (busca os parâmetros do banco).
- `Parameters.CreateParameter(...)` / `AddParameter`: compilam via `FireDAC.ADO.Migrate`.
  Depois, troque por `Params.Add` / `Params.CreateParam`.
- `ParamCheck := False` virou `ResourceOptions.ParamCreate := False`. Confira se a SQL tem `:`
  que não é parâmetro (por exemplo, hora `'10:30'` dentro do SQL).

## 4. ExecSQL, RowsAffected e comandos
- No ADO, `n := Qry.ExecSQL;` retornava o número de linhas. Se o compilador reclamar, use
  `Qry.ExecSQL; n := Qry.RowsAffected;`.
- `ADOConnection.Execute(SQL)` → `FDConnection.ExecSQL(SQL)`.
- `TADOCommand.Execute` → `TFDCommand.Execute`. A regra troca `CommandText` por `CommandText.Text` no PAS.

## 5. ⚠️ Cursores e travamento
- `CursorLocation = clUseServer` virou `FetchOptions.Mode = fmOnDemand`. `clUseClient` virou `fmAll`
  (traz tudo para a memória: pode mudar consumo de memória em tabelas grandes).
- `LockType = ltBatchOptimistic` virou `CachedUpdates = True`. Confira se o código chama
  `UpdateBatch` (helper) → no FireDAC nativo é `ApplyUpdates`.
- `LockType = ltPessimistic` virou `UpdateOptions.LockMode = lmPessimistic`. Teste a concorrência
  com dois clientes antes de liberar.

## 6. ⚠️ Recordset e recursos ADO puros
`Recordset`, `NextRecordset`, `Properties`, `Errors`, `State`, `OnInfoMessage`: sem equivalente direto.
- Múltiplos resultsets: `TFDQuery.NextRecordSet` + `FetchOptions.AutoClose := False`.
- Mensagens do servidor (`PRINT` no SQL Server): `TFDConnection.Messages` com
  `ResourceOptions.ServerOutput := True`.
- Código que manipula `_Recordset` diretamente (ADOInt) precisa ser reescrito. Pare e discuta.

## 7. SQL específico do OLE DB
- `{call proc(?)}` e `?` como parâmetro posicional: o FireDAC trabalha com `:param` nomeado.
  Converta para parâmetros nomeados e cubra com teste.
- O banco continua o mesmo, então o dialeto SQL não muda. Se o objetivo também for trocar
  de banco, isso é outra etapa: skill `sql-dialect-migration`.

## 8. Tratamento de erro
`EADOError` virou `EFDDBEngineException`. Prefira `E.Kind` (`ekUKViolated`, `ekFKViolated`,
`ekRecordLocked`, `ekServerGone`...) a comparar mensagens de texto do OLE DB.

## 9. Helpers da FireDAC.ADO.Migrate
Ajudam a compilar rápido, mas são uma ponte. Liste no relatório onde ainda são usados,
para serem trocados por código FireDAC nativo numa segunda etapa (com os testes passando).

## 10. Verificação final
- `_migracao\pendencias-ADO.txt` vazio ou só com falsos positivos explicados.
- Teste de carga de forms + testes de caracterização.
- Teste numa máquina limpa: o driver ODBC necessário precisa entrar no instalador.
