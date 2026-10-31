# Pendências manuais depois do reFind (dbExpress → FireDAC)

Resolva em lotes pequenos. Itens ⚠️ podem mudar comportamento: explique e espere a confirmação.

## 1. Conexão (obrigatório)
Converta `DriverName`, `Params` e `dbxconnections.ini`: veja
[parametros-dbx-para-firedac.md](parametros-dbx-para-firedac.md).

## 2. Driver físico e wait cursor (obrigatório)
As regras trocam `Data.DbxFirebird` por `FireDAC.Phys.FB` no uses, o que registra o driver.
Se o projeto não tinha a unit do driver no uses (era carregado pelo ini), acrescente.
- `Driver ID [FB] is not registered` → `TFDPhysFBDriverLink` ou unit `FireDAC.Phys.FB`.
- `Object factory for class {...} missing ... TFDGUIxWaitCursor` → `TFDGUIxWaitCursor` ou unit `FireDAC.VCLUI.Wait`.

## 3. ⚠️ Transações
O padrão DBX:
```pascal
var TD: TTransactionDesc;
TD.TransactionID := 1;
TD.IsolationLevel := xilREADCOMMITTED;
SQLConnection1.StartTransaction(TD);
try
  ...
  SQLConnection1.Commit(TD);
except
  SQLConnection1.Rollback(TD);
  raise;
end;
```
Depois do reFind, compila via `FireDAC.DBX.Migrate` (`TFDDBXTransactionDesc`). Numa segunda
etapa, com testes passando, troque pelo nativo:
```pascal
FDConnection1.StartTransaction;
try
  ...
  FDConnection1.Commit;
except
  FDConnection1.Rollback;
  raise;
end;
```
O mesmo vale para `BeginTransaction`/`CommitFreeAndNil` (`TDBXTransaction`).

## 4. ⚠️ TClientDataSet + TDataSetProvider
É o padrão clássico do dbExpress (o DBX era unidirecional). Depois da migração, o provider
passa a apontar para um `TFDQuery` e **continua funcionando**. Não remova o ClientDataSet
durante a migração. Simplificar para `TFDQuery` com `CachedUpdates` é uma refatoração posterior,
com testes.

## 5. TSimpleDataSet
Não é migrado. Opções para discutir com o usuário:
1. Trocar por `TFDQuery` com `CachedUpdates = True` e `ApplyUpdates` onde havia `ApplyUpdates(0)`.
2. Trocar por `TClientDataSet` + `TDataSetProvider` + `TFDQuery` (mais próximo do comportamento atual).

## 6. TSQLMonitor
Sem equivalente direto. Use `TFDMoniFlatFileClientLink` (log em arquivo) ou
`TFDMoniRemoteClientLink` (FDMonitor) e ligue `MonitorBy` nos Params da conexão.

## 7. Execute / ExecuteDirect
Com a correção do script, `TSQLConnection.Execute`/`ExecuteDirect` viram `ExecSQL`. Confira:
- `Execute(SQL, Params, @Cursor)` com retorno de cursor precisa ser reescrito com um `TFDQuery`.
- `ExecuteDirect(SQL)` → `FDConnection.ExecSQL(SQL)`, sem diferença de comportamento.

## 8. Metadados
`GetTableNames`, `GetFieldNames`, `GetProcedureNames` existem no `TFDConnection` com
assinaturas diferentes (catálogo, schema, padrão, lista). O compilador aponta; ajuste com
os parâmetros vazios onde o DBX não usava schema.

## 9. Tratamento de erro
`TDBXError` virou `EFDDBEngineException`. Prefira `E.Kind` (`ekUKViolated`, `ekFKViolated`,
`ekRecordLocked`...) a comparar mensagens do driver.

## 10. Verificação final
- `_migracao\pendencias-DBX.txt` vazio ou só com falsos positivos explicados
  (por exemplo, `VendorLib` no `TFDPhysFBDriverLink` está correto).
- Teste de carga de forms + testes de caracterização.
- A pasta de instalação não precisa mais de `dbxfb.dll`, `dbxconnections.ini` e `dbxdrivers.ini`.
