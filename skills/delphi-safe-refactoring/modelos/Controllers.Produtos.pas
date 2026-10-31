unit Controllers.Produtos;

{ Controller: a ÚNICA porta de entrada do assunto.
  A View (VCL/FMX) e os endpoints (Horse ou DataSnap) chamam só o Controller,
  então a regra de negócio existe em um lugar só.

  - Valida (EValidacaoProdutos) antes de chamar o Model.
  - Não conhece tela nem HTTP: nada de ShowMessage, componentes ou THorseResponse aqui. }

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Types.Produtos,
  Models.Produtos;

type
  TControllerProdutos = class
  private
    FLista: TListaProdutos;
    procedure ValidarId(AId: Integer);
    procedure ValidarPreenchimento(AProduto: TProduto);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Carregar;
    function Itens: TObjectList<TProduto>;
    /// Objeto novo ou nil. Quem chama libera.
    function BuscarPorId(AId: Integer): TProduto;
    /// Grava e preenche AProduto.Id. O chamador continua dono de AProduto.
    procedure Inserir(AProduto: TProduto);
    /// False se o produto não existe
    function Alterar(AProduto: TProduto): Boolean;
    function Excluir(AId: Integer): Boolean;

    /// JSON novo. Quem chama libera (ou entrega ao Horse).
    function ToJson: TJSONArray;
  end;

implementation

constructor TControllerProdutos.Create;
begin
  inherited Create;
  FLista := TListaProdutos.Create;
end;

destructor TControllerProdutos.Destroy;
begin
  FLista.Free;
  inherited;
end;

procedure TControllerProdutos.ValidarId(AId: Integer);
begin
  if AId <= 0 then
    raise EValidacaoProdutos.Create('Produto não informado.');
end;

procedure TControllerProdutos.ValidarPreenchimento(AProduto: TProduto);
begin
  // Regras levantadas do legado: Required/Size dos TFields, BeforePost do DataModule,
  // validações dos OnClick e constraints do banco. Cite a origem de cada uma.
  if Trim(AProduto.Nome) = '' then
    raise EValidacaoProdutos.Create('Informe o nome do produto.');            // TField NOME.Required
  if Length(AProduto.Nome) > 60 then
    raise EValidacaoProdutos.Create('O nome pode ter no máximo 60 caracteres.'); // TField NOME.Size
  if AProduto.Preco < 0 then
    raise EValidacaoProdutos.Create('O preço não pode ser negativo.');          // qryProdutosBeforePost
end;

procedure TControllerProdutos.Carregar;
begin
  FLista.CarregarDoBanco;
end;

function TControllerProdutos.Itens: TObjectList<TProduto>;
begin
  Result := FLista.Itens;
end;

function TControllerProdutos.BuscarPorId(AId: Integer): TProduto;
begin
  ValidarId(AId);
  Result := TListaProdutos.BuscarNoBanco(AId);
end;

procedure TControllerProdutos.Inserir(AProduto: TProduto);
begin
  ValidarPreenchimento(AProduto);
  try
    FLista.Inserir(AProduto);
  except
    on E: Exception do
      raise Exception.Create('Não foi possível incluir o produto.' + sLineBreak + E.Message);
  end;
end;

function TControllerProdutos.Alterar(AProduto: TProduto): Boolean;
begin
  ValidarId(AProduto.Id);
  ValidarPreenchimento(AProduto);
  try
    Result := FLista.Alterar(AProduto);
  except
    on E: Exception do
      raise Exception.Create('Não foi possível alterar o produto.' + sLineBreak + E.Message);
  end;
end;

function TControllerProdutos.Excluir(AId: Integer): Boolean;
begin
  ValidarId(AId);
  try
    Result := FLista.Excluir(AId);
  except
    on E: Exception do
      raise Exception.Create('Não foi possível excluir o produto.' + sLineBreak + E.Message);
  end;
end;

function TControllerProdutos.ToJson: TJSONArray;
begin
  Result := FLista.ToJson;
end;

end.
