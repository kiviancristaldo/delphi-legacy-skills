# Como funciona uma skill

Uma skill é **só uma pasta com arquivos de texto**. Não tem DLL, compilação nem instalação.
A única coisa obrigatória é o `SKILL.md`.

```text
bde-to-firedac/
├── SKILL.md                  ← obrigatório: nome, descrição e instruções
├── referencias/              ← conhecimento consultado só quando precisa
│   ├── o-que-o-refind-faz.md
│   └── pendencias-manuais.md
├── scripts/                  ← tarefas determinísticas (executadas, não lidas)
│   ├── Get-InventarioAcessoDados.ps1
│   └── Invoke-ReFind.ps1
└── modelos/                  ← arquivos para copiar e preencher
    └── regras-do-projeto.txt
```
Comparação para quem é de Delphi: o `SKILL.md` é a `.dpr`, as referências são as units, os
scripts são as ferramentas externas.

## Os 3 níveis de carregamento
| Nível | O que é carregado | Quando |
|---|---|---|
| 1. Metadados | só `name` e `description` | sempre, em toda conversa (pouquíssimo texto) |
| 2. Corpo do `SKILL.md` | as instruções | quando o pedido combina com a descrição |
| 3. Arquivos extras | referências, modelos, scripts | só se as instruções mandarem e a tarefa precisar |

Por isso dá para instalar dezenas de skills sem deixar a IA lenta: ela lê o índice de todos
os livros, abre só o livro certo e só o capítulo que precisa. Os scripts são **executados**:
o código deles não ocupa o contexto, só o resultado.

## O SKILL.md
```markdown
---
name: bde-to-firedac
description: Migra projetos Delphi do BDE (TTable, TQuery, ...) para FireDAC usando o
  reFind ... Use quando o usuário pedir para remover/tirar o BDE, migrar BDE para FireDAC,
  ou quando encontrar DBTables/BDE no uses, Paradox ou dBase.
---

# Migração BDE → FireDAC com reFind
## Pré-condições
...
## Processo
...
## Entrega
...
```

- **`name`**: letras minúsculas, números e hífen. No Claude Code vira o comando `/bde-to-firedac`.
- **`description`**: o campo mais importante. É o que a IA lê para decidir se usa a skill. Ela
  precisa dizer **o que faz** e **quando usar**, com as palavras que o seu time usa.
  - ❌ `Ajuda com banco de dados`
  - ✅ `Migra projetos Delphi do BDE ... Use quando o usuário pedir para tirar o BDE ...`
- **Corpo**: instruções como você explicaria para um dev júnior bom: passos numerados,
  pontos de parada ("se não estiver commitado, PARE"), regras e o formato da entrega.
  Mantenha abaixo de ~500 linhas; o detalhe vai para `referencias/`.

## Onde a skill fica (Claude Code)
| Onde | Caminho | Quem usa |
|---|---|---|
| Pessoal | `~/.claude/skills/<nome>/` | você, em todos os projetos |
| Projeto | `.claude/skills/<nome>/` no repositório | todo o time (vai junto no Git) |
| Plugin | dentro de um plugin | quem instalar o plugin |

## Recursos extras do Claude Code
Campos opcionais no frontmatter, que funcionam no Claude Code (não em todo agente):
- `disable-model-invocation: true`: a skill só roda quando chamada com `/nome` (use em skills que alteram muita coisa);
- `user-invocable: false`: só a IA aciona (bom para conhecimento de fundo, como o padrão de código);
- `argument-hint` e `$ARGUMENTS`: a skill recebe parâmetros (`/migrar-unit uFinanceiro.pas`);
- `` !`comando` ``: injeta a saída de um comando no texto da skill antes de a IA ler;
- `shell: powershell`: esses comandos rodam em PowerShell (útil no Windows);
- `context: fork`: roda a skill num subagente separado.

Para manter as skills portáveis entre agentes, este kit usa só `name` e `description`.

Referência oficial: [Skills no Claude Code](https://code.claude.com/docs/en/skills).
