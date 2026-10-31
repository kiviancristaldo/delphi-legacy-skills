---
name: sql-dialect-migration
description: Migra banco e SQL de Firebird para PostgreSQL ou SQL Server em sistemas Delphi - tipos de dados, generators para sequences/identity, triggers, stored procedures (inclusive selecionáveis com SUSPEND), FIRST/SKIP para LIMIT/OFFSET ou TOP, funções e o SQL espalhado em .pas e .dfm. Use quando o usuário pedir para trocar Firebird por PostgreSQL/SQL Server, converter DDL/procedures/triggers, adaptar SQL do sistema Delphi ao novo banco ou levantar o que muda numa troca de banco.
---

# Migração de dialeto SQL: Firebird → PostgreSQL / SQL Server

Uma troca de banco tem três frentes. Esta skill cuida das três, nesta ordem:
1. **Banco**: DDL (tabelas, domínios, generators, índices), triggers e procedures.
2. **SQL dentro do sistema Delphi**: strings em `.pas`, `SQL.Strings` em `.dfm`, scripts `.sql`.
3. **Impacto no Delphi**: tipos de campo, conexão, IDs, datas, transações.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `referencias/firebird-para-postgresql.md`: tabela de equivalências e exemplos
- `referencias/firebird-para-sqlserver.md`: tabela de equivalências e exemplos
- `referencias/impacto-no-delphi.md`: o que muda no código Delphi/FireDAC
- `referencias/checklist.md`: checklist completo da migração
- `scripts/Find-SqlFirebird.ps1`: encontra construções específicas do Firebird no código

## Pré-condições
1. Destino definido: PostgreSQL (qual versão) ou SQL Server (qual versão). Se o usuário
   não disse, pergunte. Várias construções dependem da versão (ex.: `MERGE` no PostgreSQL 15+,
   `STRING_AGG` no SQL Server 2017+).
2. Versão do Firebird de origem (1.5, 2.5, 3, 4, 5) e dialeto do banco (1 ou 3).
   **No dialeto 1, `DATE` guarda data e hora**: vira timestamp no destino.
3. O sistema já usa FireDAC? Se ainda usa BDE/ADO/DBX, migre o acesso a dados primeiro
   (skills `bde-to-firedac`, `ado-to-firedac`, `dbx-to-firedac`), mantendo o Firebird.
   **Nunca troque componente de acesso e banco na mesma etapa.**
4. Testes de caracterização das consultas e regras principais (skill
   `delphi-characterization-tests`), rodando contra o Firebird **antes** de começar.

## Processo

### 1. Inventário
- Peça ao usuário o DDL completo (no Firebird: `isql -x banco.fdb > ddl.sql`, ou o extract
  da ferramenta que ele usa). Leia e conte: tabelas, domínios, generators, triggers,
  procedures (separe as selecionáveis, que têm `SUSPEND`), views, exceptions, índices, UDFs.
- No código Delphi:
  ```
  powershell -ExecutionPolicy Bypass -File scripts/Find-SqlFirebird.ps1 -Pasta <pasta do projeto> -Destino PG -Recursivo
  ```
  (`-Destino MSSQL` para SQL Server.) O relatório fica em `_migracao\sql-firebird-<Destino>.md`.
- Mostre o resumo e **aponte os itens de maior risco** (veja o checklist): UDFs, `EXECUTE BLOCK`,
  triggers multi-evento, SQL montado com datas concatenadas, procedures selecionáveis.

### 2. Converter o banco
Use a referência do destino. Ordem: domínios → tabelas → generators/identity → índices e
constraints → views → procedures → triggers. Gere scripts numerados
(`01_tabelas.sql`, `02_sequences.sql`...) numa pasta `_migracao\ddl-<destino>\`.

Regras:
- Converta **objeto por objeto** e marque cada um como convertido, adaptado (com mudança de
  semântica) ou pendente (precisa de decisão).
- Toda mudança de semântica vira um comentário `-- ATENÇÃO:` no script e uma linha no relatório.
- Nada de inventar regra de negócio: se uma trigger tem lógica obscura, converta literalmente e marque.

### 3. Converter o SQL do sistema
Para cada item do relatório do script, proponha a troca. Prefira:
1. SQL padrão, que funciona nos dois bancos (`CASE`, `COALESCE`, `CURRENT_TIMESTAMP`);
2. escapes do FireDAC para o que não é padrão (veja [impacto-no-delphi.md](referencias/impacto-no-delphi.md));
3. só então SQL específico do destino.

Datas concatenadas no SQL viram **parâmetros**. É mais seguro e resolve o formato de data de vez.

### 4. Dados
Discuta com o usuário como copiar os dados (veja o checklist). Depois da carga:
**ressincronize sequences/identity** com o maior ID de cada tabela.

### 5. Validar
1. Rode os testes de caracterização contra o banco novo.
2. Compare contagens de linhas e somas de colunas de valor por tabela (origem × destino).
3. Rode o teste de tipos de campo (veja impacto-no-delphi) para achar `Type mismatch for field`.

## Entrega
1. Inventário (objetos por tipo, ocorrências no código por construção).
2. Scripts DDL gerados, com a lista de `ATENÇÃO`.
3. Alterações no código Delphi (arquivo, antes → depois).
4. Pendências para decisão do usuário.
5. Resultado da validação.
