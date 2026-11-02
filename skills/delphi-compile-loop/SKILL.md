---
name: delphi-compile-loop
description: Compila um projeto Delphi (.dproj) pela linha de comando com MSBuild, lê erros, warnings e hints do compilador e corrige em ciclos até compilar com zero erros e, se o usuário quiser, zero warnings e zero hints. Use depois de migrar de versão do Delphi, migrar para FireDAC, aplicar reFind, converter para Unicode/64 bits, ou quando o usuário pedir para fazer o projeto compilar, limpar warnings/hints ou "zerar o compilador".
---

# Compile-loop: compilar, corrigir, compilar de novo

O compilador é o revisor mais confiável que existe. Esta skill põe ele no meio do ciclo:
toda correção é confirmada por uma nova compilação, nunca por suposição.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Build-Delphi.ps1`: compila e gera `_build\build-result.json`
- `referencias/erros-comuns.md`: causa e correção dos códigos mais frequentes
- `referencias/politica-de-correcao.md`: o que pode e o que não pode ser feito para silenciar o compilador

## Antes de começar
1. Projeto no Git. Se esta skill **abre** o trabalho e há alterações não commitadas, PARE e avise
   (sem ponto de volta, não dá para separar o que o ciclo mudou).
   **Chamada por outra skill no meio de uma tarefa** (ex.: `delphi-safe-refactoring` B8, migração
   para FireDAC): as alterações da própria tarefa são esperadas; siga. Pare só se houver alterações
   que não são da tarefa.
2. Descubra o `.dproj`. Se houver mais de um (ou um `.groupproj`), pergunte qual.
3. Pergunte a meta, se o usuário não disse: **só zerar erros**, ou também **warnings**, ou **tudo
   (incluindo hints)**. Padrão: zerar erros e warnings.
4. Configuração e plataforma: padrão `Debug`/`Win32`. Pergunte se é `Win64` (muda os warnings).
   Quando outra skill chama esta, use a meta e a plataforma que ela definiu (ou o padrão) sem
   perguntar de novo; mostre no resumo qual foi usada.
5. Leia [referencias/politica-de-correcao.md](referencias/politica-de-correcao.md). Ela vale durante toda a skill.

## O ciclo

### Compilar
```
powershell -ExecutionPolicy Bypass -File scripts/Build-Delphi.ps1 -Projeto <arquivo.dproj> [-Config Release] [-Plataforma Win64]
```
Por padrão o script faz **Rebuild** (no build incremental, units não recompiladas escondem
warnings). Use `-Incremental` só para ciclos rápidos no meio de uma fase de erros.
O resumo sai no console. Os detalhes ficam em `_build\build-result.json` (campo `itens`).

### Corrigir, nesta ordem
1. **Fatais e erros de projeto** (`F2613` unit não encontrada, `F1026`, erros do MSBuild):
   quase sempre são search path, unit renomeada ou unit que não existe mais. Um único
   fatal pode esconder centenas de erros: corrija e compile de novo antes de seguir.
2. **Erros** (`E....`): agrupe por código e corrija um grupo por vez. Comece pelo código com
   mais ocorrências: costuma ser a mesma causa repetida.
3. **Warnings** (`W....`): priorize os que indicam bug real: `W1035` (retorno indefinido),
   `W1036` (variável não inicializada), `W1058`/`W1057` (conversão de string), `W1050`
   (WideChar em set), `W1024`/`W1023` (signed/unsigned). Depois os demais.
4. **Hints** (`H....`): só se a meta incluir hints. Exemplos: `H2164` (variável não usada)
   e `H2077` (valor atribuído nunca usado). Nesses casos, confirme que a linha removida não
   tinha efeito colateral (chamada de função).

Para cada código, consulte [referencias/erros-comuns.md](referencias/erros-comuns.md).

### Compilar de novo e medir
Depois de cada lote, compile e compare os totais com a rodada anterior. Mostre ao usuário
uma linha por rodada:

| Rodada | Fatal | Erros | Warnings | Hints | O que foi feito |
|---|---|---|---|---|---|

### Condições de parada
Pare e pergunte ao usuário quando:
- a meta foi atingida;
- **duas rodadas seguidas sem reduzir** o total da categoria atual;
- a correção exigiria mudar comportamento (veja a política);
- passaram **10 rodadas** (o usuário pode autorizar mais);
- o erro está em código de terceiros (componentes, bibliotecas): não edite, relate.

### Commits
Sugira um commit ao fim de cada fase: `fix: projeto compila no Delphi 13`,
`fix: zera warnings de conversão de string`, `chore: remove hints`.
Commite só com autorização do usuário (dada uma vez para a tarefa vale até o fim dela). Quando
chamada por outra skill, quem decide os commits é a skill que chamou.

## Depois de compilar
Se existirem testes (skill `delphi-characterization-tests`), rode-os. Compilar não prova que
o comportamento continua igual. Se não existirem, diga isso claramente no relatório.

## Entrega
1. Tabela das rodadas (antes → depois).
2. Correções agrupadas por código, com 1 exemplo de cada.
3. Lista do que NÃO foi corrigido e por quê (terceiros, decisão de negócio, risco).
4. Qualquer `{$WARN ... OFF}` ou supressão adicionada: deve estar vazia, a menos que o usuário tenha autorizado.
