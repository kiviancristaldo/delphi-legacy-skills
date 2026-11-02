---
name: delphi-cleanup
description: Limpa e organiza código Delphi legado sem mudar comportamento. Primeiro levanta e mostra os itens priorizados (alta, média, baixa) com risco e benefício, e só executa o que o usuário escolher - remove with, código comentado e métodos sem uso, protege objetos com try/finally, ataca vazamentos, except vazio, senhas no código, warnings e hints. Também aponta riscos para decisão (units e DataModules grandes, muitas classes, métodos complexos, parâmetros var/out, código duplicado). Use quando o usuário pedir para limpar, organizar ou arrumar código legado ou algumas units, preparar o projeto antes de migrar ou refatorar, tirar os with, ou reduzir vazamentos de memória.
---

# Limpe e organize antes de reformar

Ninguém instala automação numa casa com roupa espalhada pelo chão. Limpeza é a etapa
mais barata e a que mais facilita as seguintes: menos código para ler, menos tokens para
a IA, menos lugares para bug se esconder.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Find-CodeSmells.ps1`: levantamento priorizado; não altera nada
- `referencias/regras-de-limpeza.md`: cada regra de limpeza, como corrigir e o risco
- `referencias/riscos-apontados.md`: como o script mede tamanho, complexidade, classes,
  assuntos de DataModule, var/out e duplicação (heurísticas e limites)
- `referencias/modelo-relatorio.md`: modelo do relatório final, com as decisões do usuário

## Regras principais
1. **Não saia fazendo.** Primeiro levante e mostre a lista priorizada; o usuário decide o que
   será feito e o que não será. Nada é alterado antes dessa decisão.
2. **Limpeza não muda comportamento.** Se uma correção muda o que o sistema faz (logar um
   erro que antes era engolido, tirar um `ProcessMessages`), ela é uma decisão do usuário e
   vai num commit separado, com teste.
3. **Um tipo de limpeza por vez, um tipo por commit.**
4. **Riscos são apontados, não corrigidos.** Unit ou DataModule grande, unit com muitas
   classes, método grande ou complexo, DataModule com muitos assuntos, parâmetros `var`/`out` e
   código duplicado entram na lista com a recomendação (testes, `delphi-safe-refactoring`).
   Quebrar, dividir ou unificar é refatoração, não limpeza: esta skill não faz.
5. **Escopo parcial não remove nada que possa ser usado fora dele** (veja o passo 1).

## Pré-condições
1. Projeto no Git, tudo commitado. Se não estiver, PARE.
2. O projeto compila. Se não, use antes a skill `delphi-compile-loop`.

## Processo
Faça uma pergunta por vez quando houver decisões, e espere a resposta antes da próxima.

### 1. Levantar
Descubra o escopo: o projeto todo ou só algumas units? Se o usuário citou units, forms ou
DataModules ("limpa a uPedidos"), o escopo é **parcial**.

Projeto todo:
```
powershell -ExecutionPolicy Bypass -File scripts/Find-CodeSmells.ps1 -Pasta <pasta do projeto> -Recursivo -Excluir '<pastas de terceiros>'
```
Escopo parcial (analisa só as units citadas, mas procura referências no projeto inteiro):
```
powershell -ExecutionPolicy Bypass -File scripts/Find-CodeSmells.ps1 -Pasta <pasta do projeto> -Recursivo -Arquivos "uPedidos.pas,Cadastros\uClientes.pas"
```
`-Pasta` precisa ser a raiz do sistema (onde estão todos os fontes), não a pasta das units.

**Escopo parcial: não retire componentes, métodos, units, campos, tipos ou qualquer coisa que
talvez seja chamada em outras partes do sistema.** O script já põe esses itens em
"Não remover: escopo parcial". Mesmo um item que a busca no projeto não encontrou pode ser
usado por:
- evento ligado num `.dfm` (inclusive DFM herdado ou de outro projeto) e métodos `published`;
- RTTI (`MethodAddress`, `FindComponent`, `FieldByName` com nome montado), relatórios
  (`.fr3`, `.rav`, QuickReport) e scripts;
- herança (`virtual`/`override`, form herdado) e pacotes (`.dpk`) ou outros projetos do grupo;
- DFM binário (o script não lê: converta para texto antes de confiar em "sem uso").
Só remova depois de uma busca no sistema inteiro (todos os projetos, DFMs e relatórios), e
apenas se o usuário pedir.

Os limites (tamanho de unit e método, complexidade, classes, componentes, assuntos, var/out,
janela de duplicação) são parâmetros do script. Os padrões e a forma de medir estão em
[referencias/riscos-apontados.md](referencias/riscos-apontados.md).

### 2. Recomendar testes antes
Antes de qualquer limpeza, recomende a skill `delphi-characterization-tests` e explique o porquê,
em poucas linhas:
- a limpeza não deveria mudar comportamento, mas `with`, `except` vazio, `ProcessMessages`,
  função que devolve objeto e remoção de "sem uso" podem mudar sem ninguém perceber;
- o teste de caracterização congela o comportamento atual: se algo mudar, o teste falha;
- os riscos apontados (métodos complexos, DataModules grandes) só devem ser refatorados com
  esses testes prontos.

Pergunte se o usuário quer criar os testes primeiro ou seguir sem. Registre a resposta no
relatório ("testes: aceitou / seguiu sem testes"). Se seguir sem, restrinja a sugestão inicial aos
itens de risco de corrigir baixo e avise, nos itens de risco médio ou alto, que ficam sem rede.

### 3. Mostrar a lista priorizada
Mostre ao usuário o resumo de `_modernizacao\limpeza.md`, agrupado por prioridade:
- **alta**: segurança, erro engolido e os maiores riscos (método crítico, unit/DataModule gigante,
  muitos assuntos, duplicação extensa, rotina com muitos var/out);
- **média**: limpezas com bom retorno (`with`, try/finally, função que devolve objeto,
  `ProcessMessages`) e riscos moderados;
- **baixa**: código comentado, sem uso, `.dpr` sem relatório de vazamento, var/out de evento.

Para cada tipo, mostre o código (A1, M2, B1...), a quantidade, o risco de corrigir, o benefício e a
recomendação, e alguns exemplos com `arquivo:linha`. Não despeje centenas de linhas: o detalhe
está no arquivo. Deixe claro o que é **limpeza** (a skill pode fazer) e o que é **risco apontado**
(vira recomendação; a skill não refatora).

### 4. Decisão do usuário
Peça a decisão, uma pergunta por vez, começando pela prioridade alta:
1. Quais códigos fazer agora? (ex.: "M1, M2 e B1")
2. Para itens que mudam comportamento (`except` vazio, `ProcessMessages`, senha): decidir caso
   a caso, mostrando o trecho.
3. Para riscos apontados: só registrar, ou já planejar com `delphi-safe-refactoring`?

Itens não escolhidos ficam no relatório como **"não feito, por decisão do usuário"**. Itens de
"Não remover: escopo parcial" ficam como "não removido: escopo parcial" (salvo se o usuário
pedir a busca no sistema inteiro e decidir remover).

### 5. Executar só o escolhido, um tipo por vez
Para cada tipo escolhido, na ordem combinada, siga
[referencias/regras-de-limpeza.md](referencias/regras-de-limpeza.md):
1. Confirme que o item é verdadeiro (todo item é candidato; descarte falsos positivos e anote).
2. Corrija um lote (uma unit ou até ~20 ocorrências do mesmo tipo).
3. Compile (skill `delphi-compile-loop` ou o script dela).
4. Rode os testes, se houver.
5. Commit com mensagem que diz o tipo: `chore: remove with em uPedidos`, `chore: try/finally em objetos locais`.

Nunca misture tipos de limpeza no mesmo commit: fica impossível revisar. Se aparecer algo
fora do escolhido, anote e pergunte; não corrija por conta própria.

### 6. Organizar (só se o usuário pedir)
Depois da limpeza mecânica, proponha (não aplique sem aprovação):
- pastas por assunto (`Cadastros\`, `Fiscal\`, `Financeiro\`, `Comum\`) em vez de tudo na raiz;
- nomes de units, classes e componentes no padrão do time (skill `delphi-coding-standards`);
- componentes de terceiros que não são mais usados, para remover do projeto.

Mover arquivos de pasta muda o `.dpr`/`.dproj` e o search path: faça pelo IDE ou ajuste os
caminhos `in '...'` do `.dpr` e compile em seguida.

### 7. Medir e relatar
Rode o script de novo (mesmo escopo e limites) e mostre antes × depois. Se existir o
diagnóstico da skill `delphi-legacy-modernizer`, rode-o com `-Comparar`.

## Entrega
Use [referencias/modelo-relatorio.md](referencias/modelo-relatorio.md):
1. Escopo (projeto todo ou parcial, com as units) e se o usuário aceitou os testes antes.
2. Tabela antes × depois por tipo de item.
3. O que foi feito, com os commits (um por tipo).
4. O que **não foi feito, por decisão do usuário**, e o que não foi removido por escopo parcial.
5. Riscos apontados com a recomendação para cada um (testes, `delphi-safe-refactoring`).
6. Falsos positivos encontrados.
7. Proposta de organização de pastas e nomes (se o usuário pediu).
