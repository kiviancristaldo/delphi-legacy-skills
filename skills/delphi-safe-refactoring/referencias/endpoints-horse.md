# Endpoints com Horse

O servidor reaproveita as units de `Types`, `Connection`, `Models` e `Controllers`. A única
coisa nova é a unit de rotas, que traduz HTTP ↔ Controller.

## Instalação
Na pasta do servidor, com o [Boss](https://github.com/HashLoad/boss):
```
boss init
boss install horse
boss install jhonson
boss install handle-exception
```
- **Horse**: o framework ([HashLoad/horse](https://github.com/HashLoad/horse)). Os modelos usam
  callbacks `procedure(Req: THorseRequest; Res: THorseResponse)` (Horse 3.x).
- **Jhonson**: middleware que lê o corpo como JSON (`Req.Body<TJSONObject>`) e envia JSON (`Res.Send<TJSONObject>`).
- **HandleException**: transforma exceções não tratadas em resposta JSON com status 500.

## Estrutura
- `server\ServerProdutos.dpr`: registra os middlewares, chama `Routes.<Assunto>.Registry` e `THorse.Listen`.
- `server\Routes\Routes.<Assunto>.pas`: uma procedure por rota + `Registry`.
- A unit de espera do FireDAC no servidor é `FireDAC.ConsoleUI.Wait`.

## Convenção de rotas e status
| Método | Rota | Controller | Sucesso | Erros |
|---|---|---|---|---|
| GET | `/produtos` | `Carregar` + `ToJson` | 200 + array | |
| GET | `/produtos/:id` | `BuscarPorId` | 200 + objeto | 400 id inválido · 404 não existe |
| POST | `/produtos` | `Inserir` | 201 + objeto com id | 400 validação |
| PUT | `/produtos/:id` | `Alterar` | 200 + objeto | 400 validação · 404 não existe |
| DELETE | `/produtos/:id` | `Excluir` | 204 | 400 id inválido · 404 não existe |

- Rotas no plural e em minúsculas (`/produtos`, `/clientes`).
- Corpo de erro: `{"erro": "mensagem"}`.
- `EValidacao<Assunto>` → 400. Qualquer outra exceção → 500 pelo HandleException.
- O id da URL vale mais que o id do corpo no `PUT`.

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
