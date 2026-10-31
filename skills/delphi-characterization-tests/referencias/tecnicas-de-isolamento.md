# Técnicas para testar código Delphi legado

Use na ordem: primeiro as que não mexem no código de produção.

## 1. Teste direto (sem mexer em nada)
Funções e métodos que só dependem dos parâmetros.

```pascal
[Test]
[TestCase('Valor zero', '0;0', ';')]
[TestCase('Abaixo do limite', '999,99;0', ';')]
[TestCase('No limite', '1000;100', ';')]
procedure CalculaDesconto(const AValor, AEsperado: Double);
...
procedure TTestFinanceiro.CalculaDesconto(const AValor, AEsperado: Double);
begin
  Assert.AreEqual(AEsperado, CalcularDesconto(AValor), 0.001);
end;
```
Use `;` como separador do `TestCase`: a vírgula conflita com o decimal brasileiro.

## 2. Testar pelo formulário (sem mexer em nada)
A regra de negócio está no `OnClick`? Não extraia ainda. Crie o form sem mostrar,
preencha os controles e chame o evento como um método comum.

```pascal
procedure TTestPedido.Total_ComDesconto;
var
  F: TFrmPedido;
begin
  F := TFrmPedido.Create(nil);
  try
    F.edtQuantidade.Text := '3';
    F.edtPreco.Text := '10,50';
    F.chkDesconto.Checked := True;
    F.btnCalcularClick(nil);          // o evento vira um método comum
    Assert.AreEqual('28,35', F.lblTotal.Caption);
  finally
    F.Free;
  end;
end;
```
Cuidados:
- O `OnCreate`/`OnShow` pode abrir conexão com o banco. Se abrir, veja a técnica 4.
- `Create(nil)` não dispara `OnShow`. Se a lógica depender dele, chame `F.FormShow(F)`.
- Forms com `Visible = True` ou auto-create no `.dpr` não importam aqui: o teste cria a instância.

## 3. Golden master (saídas grandes)
Para datasets, relatórios em texto, XML/JSON gerado, SQL montado dinamicamente:

```pascal
TGoldenMaster.Verify('Pedido_123_Itens', TGoldenMaster.DataSetToText(DM.qryItens));
TGoldenMaster.Verify('SQL_FiltroClientes', DM.MontarSQLFiltro('SP', True));
```
A primeira execução gera `approved\<nome>.received.txt`. Depois de aprovado, vira
`.approved.txt`, e qualquer diferença futura faz o teste falhar.

## 4. Dados: banco fixo ou TFDMemTable
- **Banco de teste fixo** (melhor para caracterizar SQL real): uma cópia pequena do banco
  com dados conhecidos, versionada em `Testes\dados\`. Cada teste começa a partir da cópia
  original (copie o arquivo no `[Setup]` para Firebird embarcado/SQLite).
- **TFDMemTable** (melhor para regras que só leem um dataset):
```pascal
Mem := TFDMemTable.Create(nil);
Mem.FieldDefs.Add('CODIGO', ftInteger);
Mem.FieldDefs.Add('VALOR', ftCurrency);
Mem.CreateDataSet;
Mem.AppendRecord([1, 100]);
Mem.AppendRecord([2, 250.5]);
Assert.AreEqual(350.5, SomarValores(Mem), 0.001);
```

## 5. Costuras mínimas (precisam de aprovação do usuário)
Só quando as técnicas acima não resolvem. Cada costura muda o código de produção o mínimo
possível e **não muda o comportamento** quando o teste não está rodando.

### Data/hora (`Now`, `Date`)
```pascal
// unit de produção
var
  AgoraFunc: TFunc<TDateTime> = nil;   // costura de teste

function Agora: TDateTime;
begin
  if Assigned(AgoraFunc) then
    Result := AgoraFunc()
  else
    Result := Now;
end;
```
Troque `Now` por `Agora` apenas nas linhas do alvo. No teste:
`AgoraFunc := function: TDateTime begin Result := EncodeDate(2026, 2, 28); end;`
e, no `[TearDown]`, `AgoraFunc := nil`.

### Diálogos (`ShowMessage`, `MessageDlg`, `Application.MessageBox`)
Eles travam o teste. Mesma ideia: uma variável procedural que, quando atribuída pelo
teste, registra a mensagem em vez de mostrar. O teste pode até verificar a mensagem.

### Variáveis globais e singletons
Não exige costura: salve o valor no `[Setup]` e restaure no `[TearDown]`.

### Extrair método (último recurso antes de testar)
Mover o corpo do `OnClick` para um método com parâmetros é uma refatoração, e refatorar
sem testes é exatamente o que queremos evitar. Só faça se a técnica 2 for impossível, e
de forma mecânica: copiar o bloco, trocar leituras de controles por parâmetros e manter
o `OnClick` chamando o novo método.
