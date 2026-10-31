# Impacto da troca de banco no código Delphi (FireDAC)

## 1. Conexão e implantação
| Destino | DriverID | Unit do driver | O que vai na máquina do cliente |
|---|---|---|---|
| PostgreSQL | `PG` | `FireDAC.Phys.PG` | `libpq.dll` e dependências (mesma bitagem do exe) |
| SQL Server | `MSSQL` | `FireDAC.Phys.MSSQL` | driver ODBC da Microsoft para SQL Server |

Mantenha o `ConnectionDefName`/Params num `.ini`: troca de banco por ambiente sem recompilar.

## 2. ⚠️ Campos persistentes: "Type mismatch for field"
Datasets com campos persistentes (Fields Editor) guardam o tipo do campo no DFM. Se o banco
novo devolver outro tipo, o dataset dá erro ao abrir:
`Type mismatch for field 'NOME', expecting: String actual: WideString`.

Casos típicos:
| Antes (Firebird) | Depois | Campo Delphi muda de → para |
|---|---|---|
| `VARCHAR` em WIN1252 | PG `varchar` em UTF8 / SQL Server `NVARCHAR` | `TStringField` → `TWideStringField` |
| `BLOB SUB_TYPE TEXT` | PG `text` / `NVARCHAR(MAX)` | `TMemoField` → `TWideMemoField` |
| `SMALLINT` 0/1 | `BIT` / `boolean` | `TSmallintField` → `TBooleanField` |
| `NUMERIC` | `numeric` | `TBCDField` ↔ `TFMTBCDField` (depende de precisão e driver) |
| `INTEGER` com identity | `bigint`/identity | `TIntegerField` → `TLargeintField` / `TFDAutoIncField` |

**Como encontrar tudo de uma vez**: um teste golden master que, para cada dataset, grava
`FieldName`, `DataType`, `Size` e `Precision` dos `FieldDefs`. Rode contra o Firebird (aprova)
e contra o banco novo: a diferença é a lista exata do que ajustar.

**Como resolver**, da opção mais segura para a mais trabalhosa:
1. `FormatOptions.MapRules` no `TFDConnection`: mapeia o tipo novo para o tipo antigo
   (por exemplo `dtWideString → dtAnsiString` se os dados continuam cabendo em WIN1252). Uma
   configuração, nenhum DFM alterado. Avalie a perda de Unicode com o usuário.
2. Recriar os campos persistentes afetados (muda DFM e as declarações no `.pas`).

## 3. IDs e generators
- Código que lê o generator: `SELECT GEN_ID(GEN_X, 1) FROM RDB$DATABASE`. Centralize numa
  função (`function ProximoID(const ASequence: string): Int64`) e troque só ela por banco.
- `UpdateOptions.GeneratorName` + `UpdateOptions.AutoIncFields`: funcionam com sequences do PG.
  Com `IDENTITY` do SQL Server, o FireDAC reconhece o campo autoincremento. Revise datasets que
  preenchiam o ID no `BeforePost`/`OnNewRecord`.

## 4. ⚠️ Datas e números concatenados no SQL
O legado costuma montar SQL assim:
```pascal
Qry.SQL.Text := 'SELECT * FROM VENDAS WHERE DATA >= ''' + FormatDateTime('dd.mm.yyyy', Ini) + '''';
```
O formato aceito muda de banco para banco. Troque por parâmetro, que também fecha a porta para
SQL injection:
```pascal
Qry.SQL.Text := 'SELECT * FROM VENDAS WHERE DATA >= :INI';
Qry.ParamByName('INI').AsDate := Ini;
```
O script `Find-SqlFirebird.ps1` aponta `FormatDateTime` perto de SQL e literais `'dd.mm.yyyy'`.

## 5. SQL portável com escapes do FireDAC
O pré-processador do FireDAC traduz escapes para o dialeto do banco conectado. Isso ajuda
quando o sistema precisa rodar nos dois bancos durante a transição:
- `{fn NOW()}`, `{fn CURDATE()}`, `{fn CONCAT(a, b)}`, `{fn UCASE(s)}`: funções ODBC;
- `{IF PG} ... {FI}` / `{IF MSSQL} ... {FI}`: trecho condicional por driver;
- `{LIMIT(skip, rows)}`: paginação.

Confira a sintaxe exata na documentação "Preprocessing Command Text (FireDAC)" do Delphi
instalado antes de aplicar em massa, e cubra com teste.

## 6. Transações e travamento
- SQL Server: veja `READ_COMMITTED_SNAPSHOT` na referência do SQL Server.
- Datasets que ficam abertos em `dsEdit` por muito tempo seguram locks. No Firebird isso
  "funcionava"; nos outros bancos, aparece como travamento. Liste esses pontos.

## 7. Nomes de campo
- PG devolve nomes em minúsculas. `FieldByName('NOME')` continua funcionando (não diferencia
  maiúsculas), mas comparações de string com `FieldName` (`if Field.FieldName = 'NOME'`) quebram.
  Procure por `FieldName =` no código.
- Campos persistentes guardam `FieldName` no DFM: também não diferencia maiúsculas ao abrir.

## 8. Mensagens de erro
Código que testa texto de mensagem do Firebird (`Pos('violation of PRIMARY', E.Message)`) quebra.
Troque por `EFDDBEngineException.Kind` (`ekUKViolated`, `ekFKViolated`...), que funciona igual em todos os bancos.
