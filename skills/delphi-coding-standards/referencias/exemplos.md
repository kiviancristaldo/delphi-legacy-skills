# Exemplos do padrão

## Classe de regra de negócio
```pascal
unit uPedidoRegras;

interface

uses
  System.SysUtils;

type
  EPedidoInvalido = class(Exception);

  TPedidoCalculo = class
  private
    FAliquotaDesconto: Currency;
  public
    constructor Create(AAliquotaDesconto: Currency);
    function CalcularTotal(AQuantidade, APreco: Currency; AClienteVIP: Boolean): Currency;
  end;

implementation

constructor TPedidoCalculo.Create(AAliquotaDesconto: Currency);
begin
  inherited Create;
  FAliquotaDesconto := AAliquotaDesconto;
end;

function TPedidoCalculo.CalcularTotal(AQuantidade, APreco: Currency; AClienteVIP: Boolean): Currency;
begin
  if AQuantidade <= 0 then
    raise EPedidoInvalido.Create('A quantidade precisa ser maior que zero.');
  Result := AQuantidade * APreco;
  if AClienteVIP and (Result > 1000) then
    Result := Result - Result * FAliquotaDesconto;
end;

end.
```
## Evento de tela fino
```pascal
procedure TfrmPedido.btnCalcularClick(Sender: TObject);
var
  Calculo: TPedidoCalculo;
begin
  Calculo := TPedidoCalculo.Create(0.10);
  try
    lblTotal.Caption := FormatCurr('#,##0.00',
      Calculo.CalcularTotal(StrToCurr(edtQuantidade.Text), StrToCurr(edtPreco.Text), chkClienteVIP.Checked));
  finally
    Calculo.Free;
  end;
end;
```

## Consulta com parâmetros e transação
```pascal
procedure TdmPedidos.BaixarEstoque(AProduto: Integer; AQuantidade: Currency);
begin
  conPrincipal.StartTransaction;
  try
    qryBaixa.ParamByName('PRODUTO').AsInteger := AProduto;
    qryBaixa.ParamByName('QTD').AsCurrency := AQuantidade;
    qryBaixa.ExecSQL;
    conPrincipal.Commit;
  except
    conPrincipal.Rollback;
    raise;
  end;
end;
```

## Revisão: formato de apontamento
```
uPedido.pas:142  [Memória] TStringList criado sem try/finally. → envolver em try/finally logo após o Create.
frmCliente.pas:88 [Estrutura] Regra de crédito dentro de btnSalvarClick. → mover para uClienteRegras.
dmVendas.pas:310 [Dados] SQL concatenado com edtBusca.Text. → usar parâmetro :NOME.
```
