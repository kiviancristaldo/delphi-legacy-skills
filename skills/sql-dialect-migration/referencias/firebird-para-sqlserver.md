# Firebird → SQL Server

## Tipos de dados
| Firebird | SQL Server | Atenção |
|---|---|---|
| `SMALLINT`, `INTEGER`, `BIGINT` | `SMALLINT`, `INT`, `BIGINT` | |
| `NUMERIC(p,s)`, `DECIMAL(p,s)` | `NUMERIC(p,s)` / `DECIMAL(p,s)` | evite `MONEY` |
| `FLOAT` | `REAL` | |
| `DOUBLE PRECISION` | `FLOAT` | |
| `CHAR(n)`, `VARCHAR(n)` | `VARCHAR(n)` com collation, ou `NVARCHAR(n)` | `NVARCHAR` muda o tipo de campo no Delphi (TWideStringField) |
| `BLOB SUB_TYPE 1` | `VARCHAR(MAX)` / `NVARCHAR(MAX)` | não use `TEXT`/`NTEXT` (obsoletos) |
| `BLOB SUB_TYPE 0` | `VARBINARY(MAX)` | não use `IMAGE` |
| `DATE` (dialeto 3) | `DATE` | |
| `DATE` (**dialeto 1**) | `DATETIME2` | no dialeto 1 o DATE tem hora |
| `TIME` | `TIME` | |
| `TIMESTAMP` | `DATETIME2(4)` | ⚠️ `DATETIME` só aceita datas a partir de 1753: datas "vazias" tipo 30/12/1899 ou 01/01/0001 do legado quebram. Use `DATETIME2` |
| `BOOLEAN` | `BIT` | |
| Domínio | não existe: use o tipo base + `CHECK` | |
| `COMPUTED BY (expr)` | coluna calculada `AS (expr)` (`PERSISTED` se for indexada) | |

## Identificadores e collation
- O SQL Server mantém o nome como foi criado e, por padrão, não diferencia maiúsculas nos
  nomes nem nos dados (depende da collation do banco).
- Collation sugerida para português: `Latin1_General_CI_AI` (não diferencia maiúsculas nem
  acentos, como a `PT_BR` do Firebird). Confirme com o usuário: muda resultado de busca e ordenação.
- Palavras reservadas usadas como nome (`USER`, `KEY`, `FILE`, `PERCENT`, `PLAN`...): use `[NOME]` ou renomeie.

## Generators
| Firebird | SQL Server |
|---|---|
| `CREATE GENERATOR GEN_X;` | `CREATE SEQUENCE GEN_X AS BIGINT START WITH 1;` |
| `GEN_ID(GEN_X, 1)` / `NEXT VALUE FOR GEN_X` | `NEXT VALUE FOR GEN_X` |
| `SELECT GEN_ID(GEN_X,1) FROM RDB$DATABASE` | `SELECT NEXT VALUE FOR GEN_X` |
| `SET GENERATOR GEN_X TO 100;` | `ALTER SEQUENCE GEN_X RESTART WITH 101;` |
| trigger de autoincremento | `ID INT IDENTITY(1,1)`, ou `DEFAULT NEXT VALUE FOR GEN_X` se o Delphi lê o generator |

Na carga com `IDENTITY`: `SET IDENTITY_INSERT tabela ON` durante o insert e depois
`DBCC CHECKIDENT ('tabela', RESEED, <maior id>)`. Com sequence: `ALTER SEQUENCE ... RESTART WITH <maior id + 1>`.

## ⚠️ Triggers: a maior diferença
O SQL Server **não tem trigger BEFORE** e dispara **uma vez por comando**, não por linha.
As linhas afetadas ficam nas pseudotabelas `inserted` e `deleted`.

```sql
-- Firebird
CREATE TRIGGER CLIENTES_BU FOR CLIENTES ACTIVE BEFORE UPDATE POSITION 0 AS
BEGIN
  NEW.DATA_ALTERACAO = CURRENT_TIMESTAMP;
END

-- SQL Server: AFTER + UPDATE com JOIN em inserted (funciona para N linhas)
CREATE TRIGGER CLIENTES_BU ON CLIENTES AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE c SET DATA_ALTERACAO = SYSDATETIME()
  FROM CLIENTES c
  JOIN inserted i ON i.ID = c.ID;
END
```
| Firebird | SQL Server |
|---|---|
| `NEW.X` / `OLD.X` | colunas de `inserted` / `deleted` (conjuntos de linhas!) |
| `BEFORE INSERT` que preenche valor | `DEFAULT` na coluna, ou `AFTER INSERT` com `UPDATE ... JOIN inserted` |
| `BEFORE` que valida e bloqueia | `AFTER` + `IF EXISTS (SELECT 1 FROM inserted WHERE ...) THROW ...` (desfaz o comando) |
| `INSERTING`/`UPDATING`/`DELETING` | `EXISTS(SELECT 1 FROM inserted)` / `EXISTS(SELECT 1 FROM deleted)` |
| `POSITION n` | `sp_settriggerorder` (só primeiro e último) |
| `EXCEPTION E_NOME;` | `THROW 50001, 'mensagem', 1;` |

⚠️ Trigger convertida com variáveis escalares (`SELECT @id = ID FROM inserted`) só funciona
para uma linha: é o erro mais comum nessa migração. Sempre escreva no estilo de conjunto.

## Stored procedures
**Selecionável** (`SUSPEND`) → função com valor de tabela. A chamada fica quase igual: `SELECT * FROM dbo.VENDAS_POR_CLIENTE(2026)`.
```sql
CREATE FUNCTION dbo.VENDAS_POR_CLIENTE (@ANO INT)
RETURNS TABLE AS RETURN
  SELECT CLIENTE_ID, CAST(SUM(VALOR) AS NUMERIC(15,2)) AS TOTAL
  FROM VENDAS
  WHERE YEAR(DATA) = @ANO
  GROUP BY CLIENTE_ID;
```
Com lógica linha a linha: função multi-statement (`RETURNS @r TABLE (...)` + `INSERT INTO @r`), ou
procedure que devolve um resultset (aí a chamada vira `EXEC`, e o Delphi muda).

**Executável** → `CREATE PROCEDURE`, chamada com `EXEC nome @p1 = ..., @p2 = ...`. Saída com `OUTPUT`.

| PSQL (Firebird) | T-SQL |
|---|---|
| `DECLARE VARIABLE x INTEGER;` | `DECLARE @x INT;` |
| `:var` / `var` | `@var` |
| `x = 1;` | `SET @x = 1;` |
| `SELECT ... INTO :x` | `SELECT @x = ... FROM ...` |
| `FOR SELECT ... DO BEGIN ... END` | prefira reescrever como conjunto; em último caso, cursor |
| `ROW_COUNT` | `@@ROWCOUNT` |
| `WHEN ANY DO` | `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH` |
| `WHEN SQLCODE -803` (chave duplicada) | `ERROR_NUMBER() IN (2627, 2601)` |
| `EXECUTE STATEMENT` | `EXEC sp_executesql` |
| `EXECUTE BLOCK` | um lote T-SQL ou procedure |
| `SET TERM ^ ;` | remover; separador de lote é `GO` (só no SSMS/sqlcmd) |

## SQL (DML e funções)
| Firebird | SQL Server |
|---|---|
| `SELECT FIRST 10 ...` | `SELECT TOP 10 ...` |
| `SELECT FIRST 10 SKIP 20 ... ORDER BY x` | `... ORDER BY x OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY` (exige `ORDER BY`) |
| `FROM RDB$DATABASE` | remover o `FROM` |
| `a || b` | `a + b` (NULL propaga) ou `CONCAT(a, b)` (⚠️ trata NULL como vazio) |
| `x CONTAINING 'abc'` | `x LIKE '%abc%'` (collation CI) |
| `x STARTING WITH 'abc'` | `x LIKE 'abc%'` |
| `'NOW'` / `CURRENT_TIMESTAMP` | `SYSDATETIME()` / `CURRENT_TIMESTAMP` |
| `'TODAY'` / `CURRENT_DATE` | `CAST(GETDATE() AS DATE)` |
| `data + 1` | `DATEADD(DAY, 1, data)` (`DATE`/`DATETIME2` + inteiro dá erro) |
| `DATEADD`, `DATEDIFF` | iguais (`DATEADD(DAY, n, d)`, `DATEDIFF(DAY, a, b)`) |
| `EXTRACT(YEAR FROM d)` | `YEAR(d)` / `DATEPART(YEAR, d)` |
| `EXTRACT(WEEKDAY FROM d)` (0 = domingo) | `DATEPART(WEEKDAY, d)` ⚠️ depende de `@@DATEFIRST` (padrão: 1 = domingo) |
| `SUBSTRING(s FROM 2 FOR 3)` | `SUBSTRING(s, 2, 3)` |
| `POSITION('x' IN s)` | `CHARINDEX('x', s)` |
| `CHAR_LENGTH(s)` | `LEN(s)` ⚠️ ignora espaços à direita (`DATALENGTH` conta bytes) |
| `LPAD(s, 5, '0')` | `RIGHT(REPLICATE('0', 5) + s, 5)` |
| `LIST(x, ',')` | `STRING_AGG(x, ',')` (SQL Server 2017+) |
| `IIF`, `COALESCE`, `NULLIF`, `CASE` | iguais |
| `UPDATE OR INSERT ... MATCHING (k)` | `MERGE` (ou `UPDATE` + `IF @@ROWCOUNT = 0 INSERT`) |
| `INSERT ... RETURNING id` | `INSERT ... OUTPUT INSERTED.ID VALUES (...)` (o `OUTPUT` vem antes do `VALUES`) |
| `RDB$RELATIONS`, `RDB$FIELDS` | `INFORMATION_SCHEMA.TABLES`, `sys.columns` |

## ⚠️ Concorrência
No Firebird (MVCC), leitura nunca espera escrita. No SQL Server, com o padrão `READ COMMITTED`,
**leituras podem ficar bloqueadas** esperando transações de escrita. Sistemas Delphi que
deixam transações abertas (dataset aberto em edição) passam a "travar". Recomende ao DBA:
```sql
ALTER DATABASE MeuBanco SET READ_COMMITTED_SNAPSHOT ON;
```
É o comportamento mais próximo do Firebird.
