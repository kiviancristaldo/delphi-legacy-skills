---
name: ado-to-firedac
description: Migra projetos Delphi do ADO/dbGo (TADOConnection, TADOQuery, TADOTable, TADOStoredProc, TADODataSet, TADOCommand, unit ADODB/Data.Win.ADODB) para FireDAC usando o reFind e as regras oficiais da Embarcadero, com correção de um erro conhecido nas regras oficiais. Use quando o usuário pedir para tirar o ADO, migrar ADO/dbGo para FireDAC, trocar ConnectionString OLE DB, ou quando encontrar ADODB no uses.
---

# Migração ADO (dbGo) → FireDAC com reFind

Princípio: **a IA não edita o acesso a dados na mão.** Ela analisa o projeto, gera regras
para o reFind (ferramenta determinística da Embarcadero), aplica e depois resolve só o
que as regras não cobrem.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Get-InventarioAcessoDados.ps1`: inventário, não altera nada
- `scripts/Invoke-ReFind.ps1`: aplica as regras oficiais (corrigidas) + extras, lista pendências
- `modelos/regras-do-projeto.txt`: modelo de regras específicas do projeto
- `referencias/o-que-o-refind-faz.md`: cobertura das regras oficiais e o erro conhecido
- `referencias/connectionstring-para-firedac.md`: conversão de ConnectionString OLE DB
- `referencias/pendencias-manuais.md`: como resolver cada pendência

## Pré-condições (verifique e PARE se faltar alguma)
1. Projeto no Git, sem alterações pendentes.
2. Delphi 13 instalado (BDS 37.0). Para outra versão, use `-VersaoBDS`.
3. **Rede de segurança**: pergunte se já existem testes de caracterização e o teste de
   carga de forms (skill `delphi-characterization-tests`). Se não, recomende criar antes.
4. Saiba qual banco está por trás de cada Provider OLE DB (o inventário lista os Providers).

## Processo

### 1. Inventário
```
powershell -ExecutionPolicy Bypass -File scripts/Get-InventarioAcessoDados.ps1 -Origem ADO -Pasta <pasta do projeto> -Recursivo
```
Mostre: units afetadas, componentes por classe, Providers OLE DB, classes próprias
herdadas, propriedades que exigem revisão (`ConnectionString`, `Provider`, `LockType`...).

### 2. DFMs binários
Se houver, converta para texto: `convert.exe -t <arquivo.dfm>`. Commit separado.

### 3. Regras do projeto
Leia [referencias/o-que-o-refind-faz.md](referencias/o-que-o-refind-faz.md). Copie
`modelos/regras-do-projeto.txt` para `<projeto>\_migracao\regras-do-projeto.txt` e preencha
com o que o inventário mostrou (classes filhas, `#remove Provider` se houver, units próprias).
**Mostre ao usuário e espere a aprovação.**

### 4. Simular e aplicar
```
powershell -ExecutionPolicy Bypass -File scripts/Invoke-ReFind.ps1 -Origem ADO -Pasta <pasta> -Recursivo -RegrasExtras _migracao\regras-do-projeto.txt -Simular
```
O script corrige automaticamente o erro conhecido da regra oficial (`FireDAC.Stan.Params`
→ `FireDAC.Stan.Param`) e informa a correção. Confira as regras efetivas e rode sem `-Simular`.

Commit: `refactor: ADO -> FireDAC via reFind (regras oficiais corrigidas + projeto)`.

### 5. Conexão e pendências
1. **ConnectionString**: as regras oficiais NÃO convertem (a linha que removeria está
   comentada no arquivo oficial). Converta cada uma com
   [referencias/connectionstring-para-firedac.md](referencias/connectionstring-para-firedac.md).
   Sem isso o projeto compila, mas a conexão falha em tempo de execução.
2. Driver físico + `TFDGUIxWaitCursor`.
3. Demais itens de `_migracao\pendencias-ADO.txt` com
   [referencias/pendencias-manuais.md](referencias/pendencias-manuais.md).

Lotes pequenos. Se uma pendência mudar comportamento (lock, cursor, transação), pare e pergunte.

### 6. Compilar
Use a skill `delphi-compile-loop` até zerar erros.

### 7. Validar
1. Teste de carga de forms (propriedades ADO que sobraram no DFM só falham em execução).
2. Testes de caracterização.

## Entrega
1. Inventário antes × depois.
2. Tabela ConnectionString antiga → Params FireDAC (sem senhas no relatório).
3. Regras extras e correções aplicadas nas regras oficiais.
4. Pendências resolvidas e pendências para decisão do usuário.
5. Resultado da compilação e dos testes.
