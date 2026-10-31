---
name: delphi-coding-standards
description: Padrão de código Delphi do time (nomes, estrutura de units, tratamento de erros, memória, acesso a dados, SQL, testes e commits) para seguir ao escrever, revisar ou refatorar código Delphi. Use sempre que for gerar ou alterar código Delphi neste projeto, revisar um pull request/commit Delphi, ou quando o usuário pedir para aplicar ou conferir o padrão da empresa.
---

# Padrão de código Delphi do time

> **Para o time:** este arquivo é um modelo. Ajuste as seções à realidade da empresa e
> apague o que não se aplica. Quanto mais específico (exemplos reais, nomes reais de units
> base e classes), melhor a IA segue. Cada vez que a IA errar o padrão, acrescente uma linha.

Ao **escrever** código: siga as regras abaixo sem precisar ser lembrado.
Ao **revisar**: aponte cada desvio com arquivo e linha, a regra violada e a correção sugerida.
Não reformate arquivos inteiros que não fazem parte da tarefa: o padrão vale para o código
novo ou alterado. Padronizar código antigo é uma tarefa separada (skill `delphi-cleanup`).

Exemplos detalhados: [referencias/exemplos.md](referencias/exemplos.md).

## Nomes
| Elemento | Padrão | Exemplo |
|---|---|---|
| Classes e tipos | `T` + PascalCase | `TPedidoCalculo` |
| Interfaces | `I` + PascalCase | `ICalculoImpostos` |
| Campos privados | `F` + PascalCase | `FValorTotal` |
| Parâmetros | `A` + PascalCase | `AValor` |
| Variáveis locais | PascalCase, sem prefixo | `Total` |
| Constantes | PascalCase ou MAIÚSCULAS, consistente no projeto | `AliquotaPadrao` |
| Exceções | `E` + PascalCase | `EPedidoInvalido` |
| Units | prefixo por camada | `uPedidoRegras`, `frmPedido`, `dmClientes` |
| Componentes | prefixo do tipo + nome | `btnSalvar`, `edtNome`, `qryClientes`, `dsClientes` |

Prefixos de componentes: `btn` botão, `edt` edit, `lbl` label, `cbx` combo, `chk` checkbox,
`grd` grid, `pnl` panel, `pgc` page control, `tab` tab sheet, `qry` query, `tbl` table,
`ds` data source, `con` conexão, `mem` memtable, `act` action, `tmr` timer.
**Nunca** deixe `Button1`, `Edit3`, `Query12` em código novo.

## Estrutura
- Regra de negócio **não** fica em evento de tela nem em evento de dataset. O evento chama uma
  classe/função de uma unit sem dependência de VCL.
- Método com mais de ~50 linhas ou que precisa de dois scrolls: quebre.
- Uma unit = um assunto. Units novas em pastas por assunto (`Cadastros\`, `Fiscal\`...).
- Sem variáveis globais novas. Sem `with`.
- `uses` da `interface` só com o necessário para a declaração; o resto vai para a `implementation`.

## Memória
- Todo objeto criado no método é liberado no mesmo método, com `try/finally` logo após o `Create`.
- Funções não devolvem objetos criados (exceto fábricas com nome claro).
- `ReportMemoryLeaksOnShutdown` ligado em Debug.

## Erros
- Nada de `except` vazio. Capture a classe específica ou registre e relance.
- Mensagens ao usuário em português claro; detalhes técnicos vão para o log.
- Exceções de regra de negócio têm classe própria (`EPedidoInvalido`).

## Acesso a dados
- FireDAC. Conexão central; datasets em DataModules por assunto.
- SQL **sempre** com parâmetros (`:PARAM`); nunca concatenar valores digitados.
- Datas e valores passados por parâmetro tipado (`AsDate`, `AsCurrency`).
- Transação explícita (`StartTransaction`/`Commit`/`Rollback`) em operações com mais de um comando.

## Dinheiro e números
- Valores monetários em `Currency`, não `Double`.
- Arredondamento na função padrão do projeto: `{{nome da função de arredondamento}}`.

## Testes
- Regra de negócio nova vem com teste DUnitX.
- Bug corrigido vem com o teste que reproduz o bug.

## Commits
- Um assunto por commit; mensagem no formato `tipo: descrição` (`feat`, `fix`, `refactor`, `test`, `chore`).
- Refatoração e mudança de comportamento nunca no mesmo commit.

## Específico do projeto
{{Units base que toda tela usa, classes de ancestral de form, componentes padrão, padrões de
log, de impressão, de integração com ACBr etc.}}
