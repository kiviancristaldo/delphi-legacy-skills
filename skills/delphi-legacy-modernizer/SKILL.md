---
name: delphi-legacy-modernizer
description: Planeja e conduz a modernização incremental de sistemas Delphi legados - diagnóstico do código (units e DataModules gigantes, métodos enormes, regra de negócio em eventos de tela, código duplicado, acoplamento, globais), registro de riscos, plano por fases com rollback e escolha da próxima skill. Use quando o usuário quiser modernizar, avaliar ou reduzir dívida técnica de um sistema Delphi, perguntar por onde começar, pedir análise de riscos ou um plano de migração/refatoração.
---

# Modernizador de legado Delphi

Esta é a skill de entrada do kit. Ela **não reescreve** o sistema: mede, encontra os
riscos, monta um plano incremental e decide qual skill especializada usar em cada passo.

Princípios (valem para toda a modernização):
- **Nada de reescrever do zero** (big bang). O sistema continua rodando e faturando enquanto muda.
- **Rede de segurança antes de mexer**: testes de caracterização primeiro.
- **Um tipo de mudança por vez**: versão do Delphi, acesso a dados, banco e refatoração
  são etapas separadas, cada uma com commit, teste e caminho de volta.
- **Decisões registradas**: todo risco aceito e toda escolha de arquitetura ficam por escrito.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Get-DiagnosticoLegado.ps1`: diagnóstico do código, não altera nada
- `referencias/avaliacao-e-riscos.md`: como ler o diagnóstico e montar o registro de riscos
- `referencias/estrategias-incrementais.md`: estrangulamento, abstração, execução paralela em Delphi
- `modelos/plano-de-modernizacao.md`: modelo do plano por fases

## Processo

### 1. Diagnosticar
```
powershell -ExecutionPolicy Bypass -File scripts/Get-DiagnosticoLegado.ps1 -Pasta <pasta do projeto> -Recursivo -Excluir '<pastas de terceiros>'
```
Pergunte quais pastas são de terceiros (ACBr, componentes, bibliotecas) para excluir.
O relatório fica em `_modernizacao\diagnostico.md`, e as métricas em JSON servem para
comparar antes e depois (`-Comparar`).

**Units gigantes custam caro para a IA**: o diagnóstico mostra os tokens estimados por unit.
Nunca leia uma unit grande inteira: localize o trecho (busca por nome do método) e leia só o intervalo.

### 2. Entender o contexto (pergunte ao usuário)
Não dá para avaliar risco só pelo código. Pergunte, no máximo 5 perguntas por vez:
- Quais módulos geram receita ou têm obrigação legal (fiscal: NF-e, NFC-e, SPED, TEF)?
- Quais integrações existem (ACBr, impressoras, balanças, arquivos, webservices, outros sistemas)?
- Versão do Delphi, componentes de terceiros, banco e acesso a dados atuais.
- O que dói hoje: bugs recorrentes, lentidão, telas que ninguém quer mexer?
- Objetivo e prazo: trocar versão do Delphi? trocar banco? reduzir bugs? acelerar entregas?

### 3. Registrar riscos
Monte o registro de riscos com [referencias/avaliacao-e-riscos.md](referencias/avaliacao-e-riscos.md):
cada risco com probabilidade, impacto, sinal no código (do diagnóstico) e mitigação.
**Valide o registro com o usuário antes de seguir.**

### 4. Planejar por fases
Use `modelos/plano-de-modernizacao.md`. Cada fase precisa de:
objetivo, skill que será usada, critério de pronto, **gatilho de rollback** e responsável.
Ordem recomendada (ajuste ao objetivo do usuário):

| Fase | Skill |
|---|---|
| 0. Diagnóstico e riscos | esta skill |
| 1. Rede de segurança nos módulos críticos | `delphi-characterization-tests` |
| 2. Limpeza sem mudar comportamento | `delphi-cleanup` |
| 3. Trocar a versão do Delphi | `delphi-unicode-migration`, `delphi-64bit-ready`, `delphi-compile-loop` |
| 4. Trocar o acesso a dados (mesmo banco) | `bde-to-firedac`, `ado-to-firedac` ou `dbx-to-firedac` |
| 5. Refatorar o que dói | `delphi-safe-refactoring` + `delphi-coding-standards` |
| 6. Trocar o banco (se for objetivo) | `sql-dialect-migration` |
| contínuo | `delphi-compile-loop`, `acbr-upgrade` |

Se o objetivo não inclui uma fase, ela sai do plano. Não empurre migrações que o usuário não pediu.

### 5. Executar incrementalmente
Para mudanças estruturais grandes (trocar um módulo inteiro, um cálculo fiscal, a camada de
dados), use as estratégias de [referencias/estrategias-incrementais.md](referencias/estrategias-incrementais.md):
interface + implementação nova em paralelo, chave de configuração para alternar, execução
paralela comparando resultados. Remova o caminho antigo só depois que o novo rodar em produção
por pelo menos um ciclo de release sem divergências.

### 6. Medir
Ao fim de cada fase, rode o diagnóstico com `-Comparar <json anterior>` e mostre a evolução.

## Nunca faça
- Reescrever o sistema inteiro ou um módulo inteiro de uma vez.
- Mudar código sem testes de caracterização no trecho afetado.
- Misturar tipos de mudança no mesmo commit (versão + banco + refatoração).
- Remover o código antigo antes de o novo estar provado em produção.
- Mexer em fontes de componentes de terceiros.

## Entrega
1. Resumo do diagnóstico em números (5 a 8 métricas que mais pesam).
2. Registro de riscos validado.
3. Plano por fases (`_modernizacao\plano.md`).
4. Próximo passo concreto: qual skill, em qual módulo, com qual critério de pronto.
