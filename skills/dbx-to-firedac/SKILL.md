---
name: dbx-to-firedac
description: Migra projetos Delphi do dbExpress (TSQLConnection, TSQLQuery, TSQLDataSet, TSQLTable, TSQLStoredProc, TSimpleDataSet, unit SqlExpr/Data.SqlExpr, dbxconnections.ini) para FireDAC usando o reFind e as regras oficiais da Embarcadero, com correção de um erro conhecido nas regras oficiais. Use quando o usuário pedir para tirar o dbExpress/DBX, migrar DBX para FireDAC, ou quando encontrar SqlExpr no uses.
---

# Migração dbExpress → FireDAC com reFind

Princípio: **a IA não edita o acesso a dados na mão.** Ela analisa o projeto, gera regras
para o reFind (ferramenta determinística da Embarcadero), aplica e depois resolve só o
que as regras não cobrem.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Get-InventarioAcessoDados.ps1`: inventário, não altera nada
- `scripts/Invoke-ReFind.ps1`: aplica as regras oficiais (corrigidas) + extras, lista pendências
- `modelos/regras-do-projeto.txt`: modelo de regras do projeto (já com os casos mais comuns do DBX)
- `referencias/o-que-o-refind-faz.md`: cobertura das regras oficiais e o erro conhecido
- `referencias/parametros-dbx-para-firedac.md`: Params da conexão e dbxconnections.ini
- `referencias/pendencias-manuais.md`: como resolver cada pendência

## Pré-condições (verifique e PARE se faltar alguma)
1. Projeto no Git, sem alterações pendentes.
2. Delphi 13 instalado (BDS 37.0). Para outra versão, use `-VersaoBDS`.
3. **Rede de segurança**: pergunte se já existem testes de caracterização e o teste de
   carga de forms (skill `delphi-characterization-tests`). Se não, recomende criar antes.

## Processo

### 1. Inventário
```
powershell -ExecutionPolicy Bypass -File scripts/Get-InventarioAcessoDados.ps1 -Origem DBX -Pasta <pasta do projeto> -Recursivo
```
Mostre: units afetadas, componentes por classe (atenção a `TSimpleDataSet` e `TSQLMonitor`,
que as regras oficiais não migram), arquivos `dbxconnections.ini`, propriedades do DFM
(`DriverName`, `VendorLib`, `LibraryName`, `GetDriverFunc`).

### 2. DFMs binários
Se houver, converta para texto: `convert.exe -t <arquivo.dfm>`. Commit separado.

### 3. Regras do projeto
Leia [referencias/o-que-o-refind-faz.md](referencias/o-que-o-refind-faz.md). Copie
`modelos/regras-do-projeto.txt` para `<projeto>\_migracao\regras-do-projeto.txt`. O modelo
já traz regras ativas para `VendorLib` e `DriverName='Firebird'`. Ajuste ao banco do projeto
e acrescente classes filhas e units próprias. **Mostre ao usuário e espere a aprovação.**

### 4. Simular e aplicar
```
powershell -ExecutionPolicy Bypass -File scripts/Invoke-ReFind.ps1 -Origem DBX -Pasta <pasta> -Recursivo -RegrasExtras _migracao\regras-do-projeto.txt -Simular
```
O script corrige automaticamente o erro conhecido da regra oficial (`TSQLConnecion` →
`TSQLConnection`, que fazia 12 regras de conexão nunca serem aplicadas) e informa a correção.
Confira as regras efetivas e rode sem `-Simular`.

Commit: `refactor: dbExpress -> FireDAC via reFind (regras oficiais corrigidas + projeto)`.

### 5. Conexão e pendências
1. Converta os Params da conexão e o `dbxconnections.ini` com
   [referencias/parametros-dbx-para-firedac.md](referencias/parametros-dbx-para-firedac.md).
2. Driver físico + `TFDGUIxWaitCursor`.
3. Demais itens de `_migracao\pendencias-DBX.txt` com
   [referencias/pendencias-manuais.md](referencias/pendencias-manuais.md).

Lotes pequenos. Se uma pendência mudar comportamento (transação, ClientDataSet), pare e pergunte.

### 6. Compilar
Use a skill `delphi-compile-loop` até zerar erros. Se faltar `FireDAC.DBX.Migrate`, o
`Invoke-ReFind.ps1` já informou onde está o fonte para colocar no search path.

### 7. Validar
1. Teste de carga de forms (`VendorLib`, `DriverName` e Params que sobraram só falham em execução).
2. Testes de caracterização.

## Entrega
1. Inventário antes × depois.
2. Conexões convertidas (sem senhas no relatório).
3. Regras extras e correções aplicadas nas regras oficiais.
4. Pendências resolvidas e pendências para decisão do usuário.
5. Resultado da compilação e dos testes.
