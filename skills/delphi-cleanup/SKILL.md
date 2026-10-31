---
name: delphi-cleanup
description: Limpa e organiza código Delphi legado sem mudar comportamento - remove with, código comentado e métodos sem uso, protege objetos com try/finally, ataca vazamentos de memória, except vazio, senhas no código, warnings e hints, e organiza pastas e nomes. Use quando o usuário pedir para limpar, organizar ou arrumar código legado, preparar o projeto antes de migrar ou refatorar, tirar os with, ou reduzir vazamentos de memória.
---

# Limpe e organize antes de reformar

Ninguém instala automação numa casa com roupa espalhada pelo chão. Limpeza é a etapa
mais barata e a que mais facilita as seguintes: menos código para ler, menos tokens para
a IA, menos lugares para bug se esconder.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Find-CodeSmells.ps1`: encontra os candidatos, não altera nada
- `referencias/regras-de-limpeza.md`: cada regra, como corrigir e o risco

## Regra principal
**Limpeza não muda comportamento.** Se uma correção muda o que o sistema faz (logar um
erro que antes era engolido, tirar um `ProcessMessages`), ela é uma decisão do usuário e
vai num commit separado, com teste.

## Pré-condições
1. Projeto no Git, tudo commitado. Se não estiver, PARE.
2. O projeto compila. Se não, use antes a skill `delphi-compile-loop`.
3. Para itens de risco médio ou alto: testes de caracterização no trecho (skill
   `delphi-characterization-tests`).

## Processo

### 1. Levantar
```
powershell -ExecutionPolicy Bypass -File scripts/Find-CodeSmells.ps1 -Pasta <pasta do projeto> -Recursivo -Excluir '<pastas de terceiros>'
```
Mostre a tabela-resumo de `_modernizacao\limpeza.md` e proponha a ordem de ataque: primeiro
os itens de risco baixo (mais volume, menos risco), depois os médios, por último os altos
com decisão do usuário.

### 2. Limpar em lotes pequenos
Para cada tipo de item, siga [referencias/regras-de-limpeza.md](referencias/regras-de-limpeza.md):
1. Corrija um lote (uma unit ou até ~20 ocorrências do mesmo tipo).
2. Compile (skill `delphi-compile-loop` ou o script dela).
3. Rode os testes, se houver.
4. Commit com mensagem que diz o tipo: `chore: remove with em uPedidos`, `chore: try/finally em objetos locais`.

Nunca misture tipos de limpeza no mesmo commit: fica impossível revisar.

### 3. Organizar
Depois da limpeza mecânica, proponha (não aplique sem aprovação):
- pastas por assunto (`Cadastros\`, `Fiscal\`, `Financeiro\`, `Comum\`) em vez de tudo na raiz;
- nomes de units, classes e componentes no padrão do time (skill `delphi-coding-standards`);
- componentes de terceiros que não são mais usados, para remover do projeto.

Mover arquivos de pasta muda o `.dpr`/`.dproj` e o search path: faça pelo IDE ou ajuste os
caminhos `in '...'` do `.dpr` e compile em seguida.

### 4. Medir
Rode o script de novo e mostre antes × depois. Se existir o diagnóstico da skill
`delphi-legacy-modernizer`, rode com `-Comparar`.

## Entrega
1. Tabela antes × depois por tipo de item.
2. Commits feitos (um por tipo).
3. Itens de risco alto que ficaram para decisão, com a recomendação para cada um.
4. Proposta de organização de pastas e nomes (se o usuário pediu).
