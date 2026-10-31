# Delphi Legacy Skills

**Skills de IA para diagnosticar, testar, limpar, refatorar e modernizar sistemas Delphi legados.**

Funcionam no Claude Code, no Claude.ai e em outros agentes compatíveis com o padrão aberto
[Agent Skills](https://agentskills.io). Cada skill é uma pasta com um `SKILL.md` (as instruções),
referências e scripts PowerShell que fazem a parte repetitiva de forma determinística.

> Criado para a palestra *Como modernizar seu software legado na velocidade da luz*,
> Dia do ACBr 2026, por **Kivian Emerim** (MVP Embarcadero).

## Por que skills?
Sistema legado não é difícil por ser antigo. É difícil porque tem units de milhares de
linhas, DataModules com centenas de datasets, regra de negócio dentro do `OnClick`, código
duplicado, acoplamento e nenhum teste. Isso também custa caro para a IA, que gasta tokens
lendo arquivos gigantes e perde o contexto.

Uma skill guarda o **processo** de um dev experiente: o que verificar, em que ordem, o que
nunca fazer, quais ferramentas usar. A IA segue esse processo em vez de improvisar.

## As skills
Organizadas nas etapas da reforma: **Diagnostique → Proteja → Limpe → Organize → Refatore → Modernize**.

| Etapa | Skill | O que faz |
|---|---|---|
| Diagnostique | [`delphi-legacy-modernizer`](skills/delphi-legacy-modernizer) | Mede o legado (units e DataModules gigantes, duplicação, acoplamento, tokens), registra riscos e monta o plano por fases. **Comece por aqui.** |
| Proteja | [`delphi-characterization-tests`](skills/delphi-characterization-tests) | Testes de caracterização (golden master) com DUnitX: a rede de segurança antes de mexer |
| Limpe | [`delphi-cleanup`](skills/delphi-cleanup) | `with`, `except` vazio, vazamentos, código comentado e sem uso, senhas no código |
| Organize | [`delphi-coding-standards`](skills/delphi-coding-standards) | Modelo do padrão de código do time, para a IA escrever e revisar do seu jeito |
| Refatore | [`delphi-safe-refactoring`](skills/delphi-safe-refactoring) | Tira a regra da tela, quebra métodos, units e DataModules, elimina duplicação e acoplamento |
| Modernize: versão | [`delphi-unicode-migration`](skills/delphi-unicode-migration) | Delphi 2007 ou anterior → Unicode |
| | [`delphi-64bit-ready`](skills/delphi-64bit-ready) | Win32 → Win64 |
| | [`delphi-compile-loop`](skills/delphi-compile-loop) | Compila com MSBuild e corrige em ciclos até zerar erros, warnings e hints |
| Modernize: dados e integrações | [`bde-to-firedac`](skills/bde-to-firedac) · [`ado-to-firedac`](skills/ado-to-firedac) · [`dbx-to-firedac`](skills/dbx-to-firedac) | Acesso a dados → FireDAC com o reFind (corrige erros das regras oficiais) |
| | [`sql-dialect-migration`](skills/sql-dialect-migration) | Firebird → PostgreSQL / SQL Server |
| | [`acbr-upgrade`](skills/acbr-upgrade) | Atualização do ACBr com conferência, homologação e plano de volta |

## A ordem que funciona
```
1. delphi-legacy-modernizer        → diagnóstico, riscos e plano
2. delphi-characterization-tests   → congela o comportamento atual
3. delphi-cleanup                  → limpa sem mudar comportamento
4. versão do Delphi                → unicode / 64 bits + compile-loop
5. acesso a dados                  → bde/ado/dbx-to-firedac (mesmo banco!)
6. delphi-safe-refactoring         → refatora o que dói, com testes
7. banco e integrações             → sql-dialect-migration, acbr-upgrade
```
Regras de ouro: **testes antes de mexer**, **um tipo de mudança por vez**,
**nada de reescrever do zero**, **meça antes e depois**.

## Instalação

### Com o Skills CLI (Claude Code e outros agentes)
```bash
# uma skill
npx skills add kiviancristaldo/delphi-legacy-skills --skill delphi-legacy-modernizer

# ver todas
npx skills add kiviancristaldo/delphi-legacy-skills --list

# todas
npx skills add kiviancristaldo/delphi-legacy-skills --all
```

### Manual (Claude Code)
Copie a pasta da skill (de `skills/`) para:
- `<seu projeto>\.claude\skills\<nome-da-skill>\`: vale para o projeto e vai junto no Git (recomendado para o time);
- `%USERPROFILE%\.claude\skills\<nome-da-skill>\`: vale para todos os seus projetos.

A skill é usada automaticamente quando o pedido combina com a descrição, ou manualmente com `/nome-da-skill`.

### Claude.ai
Compacte a pasta da skill em `.zip` (a pasta inteira, com o `SKILL.md` dentro) e envie pela
área de Skills nas configurações do Claude.ai. Os scripts PowerShell precisam de Windows com
Delphi instalado. No Claude.ai, use as skills para análise, planos, conversão de SQL e
geração de testes e regras.

## Exemplos de pedidos
```
Faça um diagnóstico deste sistema e me diga por onde começar a modernizar.
Crie testes de caracterização para o cálculo do btnCalcularClick do frmPedido.
Tire os with da unit uPedidos sem mudar comportamento.
Separe a regra de negócio do frmPedido numa unit testável.
Migre este projeto de BDE para FireDAC.
Compile o projeto e zere os warnings de string.
Quais construções do Firebird precisam mudar para PostgreSQL?
```

## Requisitos
- Windows com Delphi 13 Florence (BDS 37.0). Para outras versões, use `-VersaoBDS` nos scripts
  (Delphi 12 = 23.0, Delphi 11 = 22.0).
- PowerShell 5.1 ou superior (já vem no Windows).
- Git: várias skills se recusam a alterar código sem commit.
- DUnitX (já vem com o Delphi) para os testes.

Os scripts **não alteram o projeto**, exceto `Invoke-ReFind.ps1` (que aplica o reFind, e só
com o Git limpo). Os relatórios ficam em `_modernizacao\` e `_migracao\` dentro do projeto.

## Achados nas regras oficiais do reFind (Delphi 13)
Montando o kit, encontramos dois erros nos arquivos em
`Samples\Object Pascal\Database\FireDAC\Tool\reFind`:
1. **DBX** (`FireDAC_Migrate_DBX.txt`): as regras de `TSQLConnection` estão escritas
   `TSQLConnecion`. Resultado: 12 regras de conexão nunca são aplicadas.
2. **ADO** (`FireDAC_Migrate_ADO.txt`): as regras de `Parameters` acrescentam ao `uses` a unit
   `FireDAC.Stan.Params`, que não existe (o nome certo é `FireDAC.Stan.Param`).

O `Invoke-ReFind.ps1` corrige os dois numa cópia das regras, sem alterar os arquivos da Embarcadero.

## Documentação
- [Como funciona uma skill](docs/como-funciona-uma-skill.md): estrutura, carregamento em 3 níveis, frontmatter.
- [Adaptando as skills ao seu projeto](docs/adaptando-ao-seu-projeto.md).
- [Contribuindo](CONTRIBUTING.md) · [Histórico de versões](CHANGELOG.md).

## Status
Versão inicial (0.1). Os scripts foram revisados, mas ainda não rodaram em muitos projetos
reais. Use primeiro numa cópia ou branch, e abra uma *issue* com a saída do console se algo
não funcionar.

## Créditos
- Skill `delphi-legacy-modernizer` inspirada na
  [`legacy-modernizer`](https://github.com/jeffallan/claude-skills/tree/main/skills/legacy-modernizer)
  de Jeff Allan (MIT), reescrita para Delphi.
- Regras de limpeza baseadas na palestra *O impacto e o poder dos softwares legados na era da
  IA e porque inovar hoje!* (Kivian Emerim, Dia do ACBr).
- reFind e regras de migração: Embarcadero (exemplos do RAD Studio).

## Licença
[MIT](LICENSE) © 2026 Kivian Emerim
