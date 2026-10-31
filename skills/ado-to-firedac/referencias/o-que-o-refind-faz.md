# O que o reFind faz na migração ADO → FireDAC

Arquivo oficial: `Samples\Object Pascal\Database\FireDAC\Tool\reFind\ADO2FDMigration\FireDAC_Migrate_ADO.txt`

## ⚠️ Erro conhecido no arquivo oficial
As duas regras de `Parameters` acrescentam ao `uses` a unit **`FireDAC.Stan.Params`, que não
existe**. O nome certo é `FireDAC.Stan.Param`:
```
#migrate TCustomADODataSet, TADODataSet, TADOQuery, TADOTable, TADOStoredProc:Parameters -> Params, FireDAC.Stan.Params
#migrate TADOCommand:Parameters -> Params, FireDAC.Stan.Params
```
Sem correção, toda unit que usava `Parameters` passa a dar erro de unit não encontrada.
O `Invoke-ReFind.ps1` corrige numa cópia das regras (o arquivo da Embarcadero não é alterado).

## O que as regras oficiais cobrem
- **Units removidas**: `ADODB`, `ADOInt`, `OleDB` (e versões `Data.Win.*` / `Winapi.*`).
- **Componentes**: `TADOConnection→TFDConnection`, `TADOQuery→TFDQuery`, `TADOTable→TFDTable`,
  `TADOStoredProc→TFDStoredProc`, `TADODataSet→TFDQuery`, `TADOCommand→TFDCommand`,
  `TCustomADODataSet→TFDRdbmsDataSet`, `TADOBlobStream→TFDBlobStream`, `EADOError→EFDDBEngineException`.
  Acrescentam a unit auxiliar `FireDAC.ADO.Migrate` (helpers de compatibilidade).
- **Conexão**: `BeginTrans→StartTransaction`, `CommitTrans→Commit`, `RollbackTrans→Rollback`,
  `CommandTimeout→ResourceOptions.CmdExecTimeout`, `IsolationLevel→TxOptions.Isolation`,
  `CursorLocation→FetchOptions.Mode`, `KeepConnection→ResourceOptions.KeepConnection`,
  `DefaultDatabase→Params.Database`, eventos (`OnWillConnect→BeforeConnect`, `OnConnectComplete→AfterConnect`...).
- **Datasets**: `CommandText→SQL.Text` (só no PAS), `Parameters→Params`, `CursorType→FetchOptions.CursorKind`,
  `CacheSize→FetchOptions.RowsetSize`, `MaxRecords→FetchOptions.RecsMax`, `ParamCheck→ResourceOptions.ParamCreate`,
  `DataSource→MasterSource`, `Requery→Refresh`, `TADOStoredProc:ProcedureName→StoredProcName`.
- **LockType** (regex): `ltOptimistic→UpdateOptions.LockMode lmOptimistic`, `ltPessimistic→lmPessimistic`,
  `ltReadOnly→UpdateOptions.ReadOnly True`, `ltBatchOptimistic→CachedUpdates True`.
- **Enumerações**: `pdInput→ptInput`..., `clUseClient→fmAll`, `clUseServer→fmOnDemand`,
  `ctOpenForwardOnly→ckForwardOnly`..., isolamentos (`ilReadCommitted→xiReadCommitted`...).
- **Removidas**: `Attributes`, `EnableBCD`, `ExecuteOptions`, `MarshalOptions`, `TableDirect`, `CommandType`.

## O que as regras oficiais NÃO cobrem
1. **`ConnectionString` e `Provider`**: as linhas `#remove` estão comentadas no oficial.
   A string OLE DB precisa ser convertida em Params FireDAC à mão.
2. **`CommandText` no DFM**: a regra é só para PAS (`PAS:`). No DFM de `TADODataSet`/`TADOCommand`,
   confira o resultado no teste de carga de forms.
3. **Recordset, NextRecordset, Properties, Errors, State, OnInfoMessage, OnWillExecute**: sem
   equivalente direto (o próprio arquivo lista como "Not supported").
4. **Helpers** (`Execute`, `GetTableNames`, `OpenSchema`, `CancelBatch`, `UpdateBatch`, `Seek`, `Sort`...):
   continuam compilando via `FireDAC.ADO.Migrate`, mas o ideal é trocar pelo código FireDAC nativo depois.
5. **Classes próprias herdadas**: regras restritas a classes (`TADOQuery:...`) não valem para filhas.
6. **Driver físico e wait cursor**: nenhuma regra acrescenta.

## Armadilha do próprio reFind
Com `/B:0` (o padrão), se já existir `.bak`, o reFind não substitui nada. O script usa `/B:2`
com Git e `/B:1` sem Git.
