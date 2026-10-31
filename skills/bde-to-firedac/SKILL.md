---
name: bde-to-firedac
description: Migra projetos Delphi do BDE (TTable, TQuery, TDatabase, TSession, TStoredProc, TUpdateSQL, TBatchMove, unit DBTables) para FireDAC usando o reFind e as regras oficiais da Embarcadero, mais regras do próprio projeto. Use quando o usuário pedir para remover/tirar o BDE, migrar BDE para FireDAC, ou quando encontrar DBTables/BDE no uses, Paradox ou dBase.
---

# Migração BDE → FireDAC com reFind

Princípio: **a IA não edita o acesso a dados na mão.** Ela analisa o projeto, gera regras
para o reFind (ferramenta determinística da Embarcadero), aplica e depois resolve só o
que as regras não cobrem. Assim a migração é repetível e revisável.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Get-InventarioAcessoDados.ps1`: inventário, não altera nada
- `scripts/Invoke-ReFind.ps1`: aplica as regras oficiais + extras, lista pendências
- `modelos/regras-do-projeto.txt`: modelo de regras específicas do projeto
- `referencias/o-que-o-refind-faz.md`: o que as regras oficiais cobrem e o que NÃO cobrem
- `referencias/pendencias-manuais.md`: como resolver cada pendência

## Pré-condições (verifique e PARE se faltar alguma)
1. Projeto no Git, sem alterações pendentes.
2. Delphi 13 instalado (BDS 37.0). Para outra versão, use `-VersaoBDS` nos scripts.
3. **Rede de segurança**: pergunte se já existem testes de caracterização e o teste de
   carga de forms (skill `delphi-characterization-tests`). Se não existirem, recomende
   criar antes. Se o usuário quiser seguir mesmo assim, registre isso no relatório.
4. Saiba qual será o banco depois da migração. **Paradox/dBase não têm driver FireDAC**:
   se o inventário mostrar tabelas locais, os dados precisam ir para um banco real
   (Firebird, SQLite, PostgreSQL...) e isso é um projeto à parte. Avise o usuário.

## Processo

### 1. Inventário
```
powershell -ExecutionPolicy Bypass -File scripts/Get-InventarioAcessoDados.ps1 -Origem BDE -Pasta <pasta do projeto> -Recursivo
```
Mostre ao usuário o resumo: units afetadas, componentes por classe, DFMs binários, classes
próprias herdadas de TQuery/TTable, componentes de terceiros e tabelas Paradox/dBase.

### 2. DFMs binários
Se houver, converta para texto: `convert.exe -t <arquivo.dfm>` (bin do RAD Studio).
Commit separado: `chore: DFMs convertidos para texto`.

### 3. Regras do projeto
Leia [referencias/o-que-o-refind-faz.md](referencias/o-que-o-refind-faz.md). Depois copie
`modelos/regras-do-projeto.txt` para `<projeto>\_migracao\regras-do-projeto.txt` e
preencha com o que o inventário mostrou, principalmente:
- regras com restrição de classe (`TQuery:DataSource -> MasterSource`) **duplicadas para
  cada classe própria** herdada (`TMinhaQuery:DataSource -> MasterSource`);
- units próprias ou de terceiros que só existiam por causa do BDE (`#unuse`);
- propriedades de componentes de terceiros que deixam de existir (`#remove`).

**Mostre o arquivo ao usuário e espere a aprovação.**

### 4. Simular e aplicar
```
powershell -ExecutionPolicy Bypass -File scripts/Invoke-ReFind.ps1 -Origem BDE -Pasta <pasta> -Recursivo -RegrasExtras _migracao\regras-do-projeto.txt -Simular
```
Confira `_migracao\regras-efetivas-BDE.txt`. Depois rode o mesmo comando sem `-Simular`.
O script recusa rodar com alterações não commitadas ou com DFM binário. Não contorne isso.

Commit: `refactor: BDE -> FireDAC via reFind (regras oficiais + projeto)`.

### 5. Conexão e pendências
Resolva o que está em `_migracao\pendencias-BDE.txt` seguindo
[referencias/pendencias-manuais.md](referencias/pendencias-manuais.md). O mínimo é:
1. Um `TFDConnection` configurado no lugar do alias BDE.
2. O driver físico (`TFDPhysFBDriverLink` ou a unit `FireDAC.Phys.FB`, por exemplo).
3. `TFDGUIxWaitCursor` (ou a unit `FireDAC.VCLUI.Wait`). Sem ele dá erro em tempo de execução.
4. Os handlers `OnUpdateRecord`/`OnUpdateError`, cuja assinatura muda.

Faça as mudanças em lotes pequenos e explique cada uma. Se uma pendência mudar
comportamento (cached updates, transação, master-detail), pare e pergunte.

### 6. Compilar
Use a skill `delphi-compile-loop` até zerar erros. Warnings e hints novos vindos da
migração entram no mesmo ciclo.

### 7. Validar
1. Rode o teste de carga de forms: erros de DFM só aparecem em tempo de execução.
2. Rode os testes de caracterização. Qualquer falha é mudança de comportamento: investigue
   antes de "corrigir o teste".

## Entrega
1. Inventário antes × depois (componentes por classe).
2. Regras extras criadas e por quê.
3. Pendências resolvidas à mão (arquivo, o que mudou).
4. Pendências que ficaram para decisão do usuário.
5. Resultado da compilação e dos testes.
