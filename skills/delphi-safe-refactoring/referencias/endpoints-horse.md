# Endpoints com Horse

O servidor reaproveita as units de `Types`, `Connection`, `Models` e `Controllers`. A única
coisa nova é a unit de rotas, que traduz HTTP ↔ Controller.

**Nomes, para não confundir com a documentação do Horse:** lá, "Controller" é a classe que registra
as rotas e fala HTTP, e "Service" tem a regra de negócio. Neste kit, quem fala HTTP é `Routes.<Assunto>`
e quem tem a regra é `Controllers.<Assunto>` (usado também pela tela VCL). A regra de ouro é a mesma:
só a camada HTTP usa units do Horse.

## Instalação
1. Crie a pasta do servidor e o `.dproj` a partir de `modelos/ServerProdutos.dproj.modelo` (já traz o
   search path dos pacotes).
2. Na pasta do servidor, com o [Boss](https://github.com/HashLoad/boss):
   ```
   boss init
   boss install horse
   boss install jhonson
   boss install handle-exception
   ```
   O Boss 3.x baixa os fontes em `modules\github_com_hashload_<pacote>\src` (ex.:
   `modules\github_com_hashload_horse\src`). Não conte com o Boss para atualizar o `.dproj`: confira o
   `DCC_UnitSearchPath`. Acrescente `modules\` ao `.gitignore`; o `boss.json` vai para o Git.
- **Horse**: o framework ([HashLoad/horse](https://github.com/HashLoad/horse)). Os modelos usam
  callbacks `procedure(Req: THorseRequest; Res: THorseResponse)` (Horse 3.x).
- **Jhonson**: middleware que lê o corpo como JSON (`Req.Body<TJSONObject>`) e envia JSON (`Res.Send<TJSONObject>`).
- **HandleException**: transforma exceções não tratadas em resposta JSON (status 500, ou o status de um `EHorseException`).

## Estrutura
- `server\ServerProdutos.dpr`: registra os middlewares, chama `Routes.<Assunto>.Registry` e `THorse.Listen`.
- `server\Routes\Routes.<Assunto>.pas`: uma procedure por rota + `Registry`.
- A unit de espera do FireDAC no servidor é `FireDAC.ConsoleUI.Wait`.

## Ordem dos middlewares
Registre todos os middlewares **antes** das rotas, e o **`Jhonson` antes do `HandleException`**:
```pascal
THorse.Use(Jhonson);
THorse.Use(HandleException);
Routes.Produtos.Registry;
```
O HandleException responde o erro com um `TJSONObject`, e quem o transforma em texto é o Jhonson,
que por isso precisa estar por fora. Esta é a ordem do README do handle-exception. Na ordem inversa
(que aparece numa skill da documentação do Horse), o 500 sai como página HTML
(`<HTML><BODY><B>500 Internal Server Error</B></BODY></HTML>`), sem JSON: testado com Horse 3.3 e
handle-exception 0.2.

## Convenção de rotas e status
| Método | Rota | Controller | Sucesso | Erros |
|---|---|---|---|---|
| GET | `/produtos` | `Carregar` + `ToJson` | 200 + array | |
| GET | `/produtos/:id` | `BuscarPorId` | 200 + objeto | 400 id inválido · 404 não existe |
| POST | `/produtos` | `Inserir` | 201 + objeto com id | 400 validação |
| PUT | `/produtos/:id` | `Alterar` | 200 + objeto | 400 validação · 404 não existe |
| DELETE | `/produtos/:id` | `Excluir` | 204 | 400 id inválido · 404 não existe |

- Rotas no plural e em minúsculas (`/produtos`, `/clientes`).
- Corpo de erro: `{"error": "mensagem"}`, com a **mesma chave** que o HandleException usa no 500.
  Assim o cliente da API lê o erro sempre do mesmo campo.
- `EValidacao<Assunto>` → 400. Qualquer outra exceção → 500 pelo HandleException.
- O id da URL vale mais que o id do corpo no `PUT`.
- **Mensagem interna no 500:** o HandleException devolve `E.Message`, e o Controller acrescenta o erro do
  banco (`[FireDAC][Phys][FB]violation of FOREIGN KEY constraint "FK_..." on table "..."`). Serve para
  desenvolvimento; em produção, use `HandleException(callback)` para registrar o detalhe em log e
  responder uma mensagem genérica. Pergunte ao usuário se a API vai ficar exposta fora da rede interna.

## Regras de memória no Horse
- O que vai para `Res.Send<TJSONObject>(...)`/`Res.Send<TJSONArray>(...)` passa a ser do Horse.
  Sempre envie um JSON **novo** (`Produto.ToJson`), nunca um objeto que você vai liberar depois.
- `Req.Body<TJSONObject>` pertence à requisição: não libere.
- O objeto criado com `FromJson` é seu: libere em `try/finally`.
- Cada rota cria e libera o seu Controller. Nada de Controller global: as requisições rodam
  em threads diferentes.

## Testando
1. Rode o servidor e confira `http://localhost:9000/produtos` no navegador.
2. Rode o script de teste da skill, num prompt do PowerShell, com `&`:
   ```
   & .\scripts\Test-Endpoints.ps1 -BaseUrl http://localhost:9000 -Recurso produtos -Corpo '{"nome":"Teste skill","preco":9.9,"categoria":0,"ativo":true}' -CorpoInvalido '{"nome":""}'
   ```
   Ele faz GET (lista), POST, GET por id, PUT, DELETE, GET de um id inexistente (espera 404) e
   POST inválido (espera 400), e mostra o status de cada chamada.
   - **Não** use `powershell -File ... -Corpo '{...}'` a partir do Windows PowerShell 5.1: as aspas
     duplas internas somem e o servidor recebe JSON inválido. Com `powershell -File` ou no `cmd.exe`,
     grave o JSON em arquivo e use `-CorpoArquivo corpo.json` / `-CorpoInvalidoArquivo invalido.json`.
   - `-CorpoInvalido` precisa violar uma **regra real** do Controller (o padrão, nome vazio, só serve
     quando o nome é obrigatório). Ex.: se o legado aceitava nome vazio mas limitava a 50 caracteres,
     mande um nome com 51.
3. Teste com o banco de **cópia**: o script grava e apaga um registro.
4. Confira também um **500** (ex.: excluir um registro que tem filhos, violando a chave estrangeira): o
   corpo tem que ser JSON com `error`. Página HTML no 500 = ordem dos middlewares invertida.

## Para ir além
Pool de conexões (`POOL_MaximumItems`), autenticação, CORS, testes de integração HTTP com DUnitX e
outros temas estão nas skills de IA do próprio Horse:
[HashLoad/horse/doc/skills](https://github.com/HashLoad/horse/blob/master/doc/skills/README.md).
Elas valem para o Horse em geral; quando divergirem deste kit na ordem dos middlewares, siga a seção
acima (testada com o handle-exception).

## Alternativa: DataSnap (como no curso)
Se o projeto já usa DataSnap, o Controller é o mesmo; só a "casca" muda:
```pascal
{$METHODINFO ON}
TServerMethodsProdutos = class(TComponent)
public
  function Produtos: TJSONArray;   // GET /datasnap/rest/TServerMethodsProdutos/Produtos
end;
{$METHODINFO OFF}

function TServerMethodsProdutos.Produtos: TJSONArray;
var
  Controller: TControllerProdutos;
begin
  Controller := TControllerProdutos.Create;
  try
    Controller.Carregar;
    Result := Controller.ToJson;   // o DataSnap libera o retorno
  finally
    Controller.Free;
  end;
end;
```
Pergunte ao usuário qual servidor ele quer. Padrão desta skill: Horse.
