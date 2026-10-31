# Arquitetura alvo: camadas + endpoints

Padrão usado no curso de Delphi da Kivian Emerim (projeto Lista de Compras, repositório
`cursoEmbarcadero`), com ajustes de robustez para produção e servidor multithread.

## As camadas
```text
            ┌──────────────┐        ┌──────────────────────┐
            │  View (VCL/  │        │  Endpoints (Horse ou │
            │  FMX)        │        │  DataSnap)           │
            └──────┬───────┘        └──────────┬───────────┘
                   │  só chamam o Controller   │
                   └────────────┬──────────────┘
                        ┌───────▼────────┐
                        │  Controllers   │  regras de negócio, validação
                        └───────┬────────┘
                        ┌───────▼────────┐
                        │  Models        │  entidade, coleção, persistência, JSON
                        └───────┬────────┘
                ┌───────────────┼────────────────┐
        ┌───────▼───────┐               ┌────────▼───────┐
        │  Connection   │               │  Types         │  enums, constantes, exceções
        └───────────────┘               └────────────────┘
```

| Unit | Exemplo no curso | Exemplo nos modelos desta skill | Responsabilidade |
|---|---|---|---|
| `Types.<Assunto>` | `Types.Categoria` | `Types.Produtos` | enums, constantes e a exceção de validação do assunto. Sem dependências |
| `Connection.Database` | `TConnectionDatabase.GetConnection` | `TConnectionDatabase.NovaConexao` | conexão FireDAC por código. Uma só unit para o sistema todo |
| `Models.<Assunto>` | `TItemCompra` + `TListaCompras` | `TProduto` + `TListaProdutos` | a entidade (propriedades + JSON) e a coleção, que sabe carregar e gravar no banco |
| `Controllers.<Assunto>` | `TControllerListaCompras` | `TControllerProdutos` | a porta de entrada: valida, aplica as regras e chama o Model |
| View | `TView` (`HeaderFooterTemplate`) | `View.Produtos.pas.modelo` | só tela; guarda um `FController` e chama `AtualizarView` |
| Endpoints | `TServerMethods1` (DataSnap) | `Routes.Produtos` (Horse) | traduz HTTP ↔ Controller |

**O ponto central**: View e endpoints chamam o **mesmo** Controller. A regra de negócio que
estava no `OnClick` e no `BeforePost` passa a existir em um lugar só, e o mesmo sistema ganha
API sem duplicar regra.

## Estrutura de pastas sugerida
```text
src\
  Types\Types.Produtos.pas
  Connection\Connection.Database.pas
  Models\Models.Produtos.pas
  Controllers\Controllers.Produtos.pas
  Views\frmProdutos.pas / .dfm        (o form legado, transformado)
server\
  ServerProdutos.dpr
  Routes\Routes.Produtos.pas
tests\
  Test.Controllers.Produtos.pas
```
Se o projeto já tem outra organização, siga a do projeto.

## Regras de cada camada
**Types**: sem `uses` de banco, tela ou HTTP. Toda exceção de regra de negócio do assunto é
`EValidacao<Assunto>`: a View mostra a mensagem, o endpoint devolve 400.

**Connection.Database**: uma conexão nova por operação, com `Pooled=True`. Configuração em
`.ini` (nunca senha no código). A unit de espera do FireDAC (`FireDAC.VCLUI.Wait`,
`FireDAC.FMXUI.Wait` ou `FireDAC.ConsoleUI.Wait`) vai no `.dpr` de cada aplicativo.

**Models**
- Entidade: campos privados, propriedades, `Assign`, `Clone`, `ToJson`, `class function FromJson`.
- Coleção (`TLista<Assunto>`): dona dos itens (`TObjectList<T>.Create(True)`); `CarregarDoBanco`,
  `BuscarNoBanco(Id)`, `Inserir`, `Alterar`, `Excluir`, `Itens`, `ToJson`.
- SQL sempre com parâmetros; colunas explícitas no `INSERT`/`UPDATE`; `ORDER BY` igual ao legado.
- Não valida, não mostra mensagem, não conhece tela nem HTTP.

**Controllers**
- Cria e libera a coleção. Expõe o que a View e os endpoints precisam.
- `ValidarId` e `ValidarPreenchimento` concentram as regras levantadas do legado. Cada regra com
  um comentário dizendo de onde veio (TField `Required`/`Size`, `BeforePost`, handler do form, constraint).
- As validações ficam **fora** do `try` que envolve o banco, para a mensagem chegar limpa.
- Erro de banco é relançado com contexto (`'Não foi possível incluir o produto.' + sLineBreak + E.Message`).

**View**: mantém nome da unit e da classe; fala só com o Controller; converte texto da tela
para tipos (número, data); mantém layout e comportamento. Detalhes em
[mapeamento-dbaware.md](mapeamento-dbaware.md).

**Endpoints**: só traduzem HTTP ↔ Controller. Detalhes em [endpoints-horse.md](endpoints-horse.md).

## Propriedade dos objetos (quem cria, libera)
| Situação | Dono |
|---|---|
| Itens da coleção | a coleção |
| Objeto passado para `Inserir`/`Alterar` | quem chamou (a coleção guarda uma cópia) |
| Retorno de `BuscarNoBanco`/`BuscarPorId` | quem chamou |
| Retorno de `ToJson` | quem chamou, ou o Horse quando entregue a `Res.Send` |
| Corpo da requisição (`Req.Body<TJSONObject>`) | o Horse |

## O que mudou em relação ao curso (e por quê)
| No curso | Na skill | Motivo |
|---|---|---|
| Uma `TFDConnection` estática compartilhada | Conexão nova por operação, com pool | O servidor atende requisições em paralelo; uma `TFDConnection` não pode ser usada por duas threads ao mesmo tempo |
| Caminho do banco e senha no código | `.ini` ao lado do executável | segurança e troca de ambiente sem recompilar |
| Salvar = `DELETE` de tudo + reinserir | `INSERT`/`UPDATE`/`DELETE` por item | não perde dados em falha no meio, não quebra chaves estrangeiras |
| Próximo id com `max(id) + 1` | generator/sequence/identity | dois usuários ao mesmo tempo geravam o mesmo id |
| Model chamando o servidor REST direto | Model só acessa o banco; consumo de API fica num client separado, se necessário | uma responsabilidade por unit |
| DataSnap | Horse (DataSnap continua possível) | mais leve, middlewares, comunidade ativa |

## Geração de id por banco
| Banco | Como obter o id no `Inserir` |
|---|---|
| Firebird (generator) | `Conexao.ExecSQLScalar('SELECT GEN_ID(GEN_X, 1) FROM RDB$DATABASE')` antes do `INSERT` |
| Firebird 3+ (identity) / PostgreSQL | `INSERT ... RETURNING ID` aberto com `TFDQuery.Open` e lido em `FieldByName('ID')` |
| SQL Server / SQLite / MySQL (autoincremento) | `INSERT` e depois `Conexao.GetLastAutoGenValue('')` |

## Variação: separar a persistência (DAO/Repository)
Quando a coleção do Model passar de ~300 linhas ou quando o time quiser testar regras sem
banco, separe a persistência numa unit `DAO.<Assunto>` (ou `Repositories.<Assunto>`) atrás de
uma interface, como faz a skill [c4d-rad-to-poo](https://github.com/Code4Delphi/c4d-rad-to-poo)
do Code4Delphi. O Controller passa a receber essa interface, e os testes usam uma
implementação em memória. Proponha ao usuário; não aplique sem ele escolher.
