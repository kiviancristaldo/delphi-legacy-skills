unit Routes.Produtos;

{ Endpoints Horse do assunto. Cada rota só traduz HTTP <-> Controller:
  lê parâmetros e corpo, chama o Controller e devolve JSON com o status certo.
  Nenhuma regra de negócio aqui.

  Requer os middlewares Jhonson (corpo/resposta JSON) e HandleException (erros 500)
  registrados no Server.dpr.

  GET    /produtos       lista
  GET    /produtos/:id   um produto (404 se não existir)
  POST   /produtos       inclui (201 + produto com id)
  PUT    /produtos/:id   altera (404 se não existir)
  DELETE /produtos/:id   exclui (204; 404 se não existir) }

interface

procedure Registry;

implementation

uses
  System.SysUtils,
  System.JSON,
  Horse,
  Horse.Commons,
  Types.Produtos,
  Models.Produtos,
  Controllers.Produtos;

procedure ResponderErro(Res: THorseResponse; AStatus: THTTPStatus; const AMensagem: string);
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  Json.AddPair('erro', AMensagem);
  Res.Send<TJSONObject>(Json).Status(AStatus);
end;

function LerId(Req: THorseRequest): Integer;
begin
  Result := StrToIntDef(Req.Params['id'], 0);
end;

procedure Listar(Req: THorseRequest; Res: THorseResponse);
var
  Controller: TControllerProdutos;
begin
  Controller := TControllerProdutos.Create;
  try
    Controller.Carregar;
    Res.Send<TJSONArray>(Controller.ToJson);
  finally
    Controller.Free;
  end;
end;

procedure Buscar(Req: THorseRequest; Res: THorseResponse);
var
  Controller: TControllerProdutos;
  Produto: TProduto;
begin
  Controller := TControllerProdutos.Create;
  try
    try
      Produto := Controller.BuscarPorId(LerId(Req));
    except
      on E: EValidacaoProdutos do
      begin
        ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
        Exit;
      end;
    end;
    if Produto = nil then
    begin
      ResponderErro(Res, THTTPStatus.NotFound, 'Produto não encontrado.');
      Exit;
    end;
    try
      Res.Send<TJSONObject>(Produto.ToJson);
    finally
      Produto.Free;
    end;
  finally
    Controller.Free;
  end;
end;

procedure Inserir(Req: THorseRequest; Res: THorseResponse);
var
  Controller: TControllerProdutos;
  Produto: TProduto;
begin
  try
    Produto := TProduto.FromJson(Req.Body<TJSONObject>);
  except
    on E: EValidacaoProdutos do
    begin
      ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
      Exit;
    end;
  end;
  try
    try
      Controller := TControllerProdutos.Create;
      try
        Controller.Inserir(Produto);
        Res.Send<TJSONObject>(Produto.ToJson).Status(THTTPStatus.Created);
      finally
        Controller.Free;
      end;
    except
      on E: EValidacaoProdutos do
        ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
      // outros erros sobem para o middleware HandleException (500)
    end;
  finally
    Produto.Free;
  end;
end;

procedure Alterar(Req: THorseRequest; Res: THorseResponse);
var
  Controller: TControllerProdutos;
  Produto: TProduto;
begin
  try
    Produto := TProduto.FromJson(Req.Body<TJSONObject>);
  except
    on E: EValidacaoProdutos do
    begin
      ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
      Exit;
    end;
  end;
  try
    try
      Produto.Id := LerId(Req);   // o id da URL vale mais que o do corpo
      Controller := TControllerProdutos.Create;
      try
        if Controller.Alterar(Produto) then
          Res.Send<TJSONObject>(Produto.ToJson)
        else
          ResponderErro(Res, THTTPStatus.NotFound, 'Produto não encontrado.');
      finally
        Controller.Free;
      end;
    except
      on E: EValidacaoProdutos do
        ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
    end;
  finally
    Produto.Free;
  end;
end;

procedure Excluir(Req: THorseRequest; Res: THorseResponse);
var
  Controller: TControllerProdutos;
begin
  Controller := TControllerProdutos.Create;
  try
    try
      if Controller.Excluir(LerId(Req)) then
        Res.Status(THTTPStatus.NoContent)
      else
        ResponderErro(Res, THTTPStatus.NotFound, 'Produto não encontrado.');
    except
      on E: EValidacaoProdutos do
        ResponderErro(Res, THTTPStatus.BadRequest, E.Message);
    end;
  finally
    Controller.Free;
  end;
end;

procedure Registry;
begin
  THorse.Get('/produtos', Listar);
  THorse.Get('/produtos/:id', Buscar);
  THorse.Post('/produtos', Inserir);
  THorse.Put('/produtos/:id', Alterar);
  THorse.Delete('/produtos/:id', Excluir);
end;

end.
