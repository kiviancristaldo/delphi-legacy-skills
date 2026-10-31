unit Models.Produtos;

{ Model: a entidade, a coleção e a persistência do assunto.
  Sem tela. A regra de negócio fica no Controller.

  Propriedade dos objetos ("quem cria, libera"):
  - TListaProdutos é dona dos itens da sua lista.
  - Inserir/Alterar recebem um item do chamador e guardam uma CÓPIA; o chamador continua
    dono do objeto que passou e o libera.
  - BuscarNoBanco devolve um objeto novo (ou nil): quem chama libera.
  - ToJson devolve JSON novo: quem chama libera (ou entrega ao Horse, que libera). }

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  System.JSON,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  Connection.Database,
  Types.Produtos;

type
  TProduto = class
  private
    FId: Integer;
    FNome: string;
    FPreco: Currency;
    FCategoria: TCategoriaProduto;
    FAtivo: Boolean;
  public
    procedure Assign(AOrigem: TProduto);
    function Clone: TProduto;
    function ToJson: TJSONObject;
    class function FromJson(AJson: TJSONValue): TProduto;

    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Preco: Currency read FPreco write FPreco;
    property Categoria: TCategoriaProduto read FCategoria write FCategoria;
    property Ativo: Boolean read FAtivo write FAtivo;
  end;

  TListaProdutos = class
  private
    FItens: TObjectList<TProduto>;
    class procedure LerCampos(AQuery: TFDQuery; AProduto: TProduto);
    function IndiceDe(AId: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure CarregarDoBanco;
    class function BuscarNoBanco(AId: Integer): TProduto;
    procedure Inserir(AProduto: TProduto);
    /// False se o registro não existe no banco
    function Alterar(AProduto: TProduto): Boolean;
    function Excluir(AId: Integer): Boolean;

    function Itens: TObjectList<TProduto>;
    function ToJson: TJSONArray;
  end;

implementation

const
  SQL_SELECT = 'SELECT ID, NOME, PRECO, CATEGORIA, ATIVO FROM PRODUTOS';

{ TProduto }

procedure TProduto.Assign(AOrigem: TProduto);
begin
  FId := AOrigem.Id;
  FNome := AOrigem.Nome;
  FPreco := AOrigem.Preco;
  FCategoria := AOrigem.Categoria;
  FAtivo := AOrigem.Ativo;
end;

function TProduto.Clone: TProduto;
begin
  Result := TProduto.Create;
  Result.Assign(Self);
end;

function TProduto.ToJson: TJSONObject;
var
  Preco: Double;
begin
  Preco := FPreco;   // TJSONNumber não tem construtor para Currency
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(FId));
  Result.AddPair('nome', FNome);
  Result.AddPair('preco', TJSONNumber.Create(Preco));
  Result.AddPair('categoria', TJSONNumber.Create(Ord(FCategoria)));
  Result.AddPair('ativo', TJSONBool.Create(FAtivo));
end;

class function TProduto.FromJson(AJson: TJSONValue): TProduto;
var
  Categoria: Integer;
begin
  if not (AJson is TJSONObject) then
    raise EValidacaoProdutos.Create('Corpo da requisição inválido: esperado um objeto JSON.');

  Result := TProduto.Create;
  try
    Result.Id := AJson.GetValue<Integer>('id', 0);
    Result.Nome := AJson.GetValue<string>('nome', '');
    Result.Preco := AJson.GetValue<Double>('preco', 0);
    Categoria := AJson.GetValue<Integer>('categoria', 0);
    if (Categoria < Ord(Low(TCategoriaProduto))) or (Categoria > Ord(High(TCategoriaProduto))) then
      raise EValidacaoProdutos.Create('Categoria inválida.');
    Result.Categoria := TCategoriaProduto(Categoria);
    Result.Ativo := AJson.GetValue<Boolean>('ativo', True);
  except
    Result.Free;
    raise;
  end;
end;

{ TListaProdutos }

constructor TListaProdutos.Create;
begin
  inherited Create;
  FItens := TObjectList<TProduto>.Create(True);
end;

destructor TListaProdutos.Destroy;
begin
  FItens.Free;
  inherited;
end;

class procedure TListaProdutos.LerCampos(AQuery: TFDQuery; AProduto: TProduto);
begin
  AProduto.Id := AQuery.FieldByName('ID').AsInteger;
  AProduto.Nome := AQuery.FieldByName('NOME').AsString;
  AProduto.Preco := AQuery.FieldByName('PRECO').AsCurrency;
  AProduto.Categoria := TCategoriaProduto(AQuery.FieldByName('CATEGORIA').AsInteger);
  AProduto.Ativo := AQuery.FieldByName('ATIVO').AsString = 'S';
end;

function TListaProdutos.IndiceDe(AId: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FItens.Count - 1 do
    if FItens[I].Id = AId then
      Exit(I);
end;

procedure TListaProdutos.CarregarDoBanco;
var
  Conexao: TFDConnection;
  Query: TFDQuery;
  Produto: TProduto;
begin
  FItens.Clear;
  Conexao := TConnectionDatabase.NovaConexao;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conexao;
      Query.Open(SQL_SELECT + ' ORDER BY NOME');
      while not Query.Eof do
      begin
        Produto := TProduto.Create;
        try
          LerCampos(Query, Produto);
        except
          Produto.Free;
          raise;
        end;
        FItens.Add(Produto);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    Conexao.Free;
  end;
end;

class function TListaProdutos.BuscarNoBanco(AId: Integer): TProduto;
var
  Conexao: TFDConnection;
  Query: TFDQuery;
begin
  Result := nil;
  Conexao := TConnectionDatabase.NovaConexao;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conexao;
      Query.Open(SQL_SELECT + ' WHERE ID = :ID', [AId]);
      if not Query.IsEmpty then
      begin
        Result := TProduto.Create;
        try
          LerCampos(Query, Result);
        except
          FreeAndNil(Result);
          raise;
        end;
      end;
    finally
      Query.Free;
    end;
  finally
    Conexao.Free;
  end;
end;

procedure TListaProdutos.Inserir(AProduto: TProduto);
var
  Conexao: TFDConnection;
begin
  Conexao := TConnectionDatabase.NovaConexao;
  try
    // Firebird com generator. Outros bancos: veja referencias/arquitetura-em-camadas.md
    AProduto.Id := Conexao.ExecSQLScalar('SELECT GEN_ID(GEN_PRODUTOS_ID, 1) FROM RDB$DATABASE');
    Conexao.ExecSQL(
      'INSERT INTO PRODUTOS (ID, NOME, PRECO, CATEGORIA, ATIVO) VALUES (:ID, :NOME, :PRECO, :CATEGORIA, :ATIVO)',
      [AProduto.Id, AProduto.Nome, AProduto.Preco, Ord(AProduto.Categoria), IfThen(AProduto.Ativo, 'S', 'N')]);
  finally
    Conexao.Free;
  end;
  FItens.Add(AProduto.Clone);
end;

function TListaProdutos.Alterar(AProduto: TProduto): Boolean;
var
  Conexao: TFDConnection;
  Indice: Integer;
begin
  Conexao := TConnectionDatabase.NovaConexao;
  try
    Result := Conexao.ExecSQL(
      'UPDATE PRODUTOS SET NOME = :NOME, PRECO = :PRECO, CATEGORIA = :CATEGORIA, ATIVO = :ATIVO WHERE ID = :ID',
      [AProduto.Nome, AProduto.Preco, Ord(AProduto.Categoria), IfThen(AProduto.Ativo, 'S', 'N'), AProduto.Id]) > 0;
  finally
    Conexao.Free;
  end;
  Indice := IndiceDe(AProduto.Id);
  if Indice >= 0 then
    FItens[Indice].Assign(AProduto);
end;

function TListaProdutos.Excluir(AId: Integer): Boolean;
var
  Conexao: TFDConnection;
  Indice: Integer;
begin
  Conexao := TConnectionDatabase.NovaConexao;
  try
    Result := Conexao.ExecSQL('DELETE FROM PRODUTOS WHERE ID = :ID', [AId]) > 0;
  finally
    Conexao.Free;
  end;
  Indice := IndiceDe(AId);
  if Indice >= 0 then
    FItens.Delete(Indice);
end;

function TListaProdutos.Itens: TObjectList<TProduto>;
begin
  Result := FItens;
end;

function TListaProdutos.ToJson: TJSONArray;
var
  Produto: TProduto;
begin
  Result := TJSONArray.Create;
  for Produto in FItens do
    Result.AddElement(Produto.ToJson);
end;

end.
