# Catálogo de refatorações para Delphi legado

Cada refatoração é uma sequência de passos pequenos. Compile e rode os testes entre os passos.

## 1. Tirar a regra de negócio do evento de tela
O caso mais comum e o que mais destrava testes.

Antes:
```pascal
procedure TfrmPedido.btnCalcularClick(Sender: TObject);
var
  Total, Desconto: Currency;
begin
  Total := StrToCurr(edtQuantidade.Text) * StrToCurr(edtPreco.Text);
  if chkClienteVIP.Checked and (Total > 1000) then
    Desconto := Total * 0.10
  else
    Desconto := 0;
  lblTotal.Caption := FormatCurr('#,##0.00', Total - Desconto);
end;
```
Passos:
1. **Extrair método no próprio form**: o cálculo vira `function TfrmPedido.CalcularTotal(...)`;
   o evento lê a tela, chama, escreve na tela. Compile e teste.
2. **Trocar dependências da tela por parâmetros**: o método passa a receber
   `AQuantidade, APreco: Currency; AClienteVIP: Boolean`. Compile e teste.
3. **Mover para uma unit sem tela** (`uPedidoRegras.pas`), como função ou classe. O form passa a usá-la.
   Compile e teste.
4. **Escrever testes diretos** da nova função (agora é possível sem abrir o form).

Depois:
```pascal
// uPedidoRegras.pas: sem Forms, sem Controls, testável
function CalcularTotalPedido(AQuantidade, APreco: Currency; AClienteVIP: Boolean): Currency;
var
  Total: Currency;
begin
  Total := AQuantidade * APreco;
  if AClienteVIP and (Total > 1000) then
    Result := Total - Total * 0.10
  else
    Result := Total;
end;

// frmPedido: só lê a tela, chama a regra e mostra o resultado
procedure TfrmPedido.btnCalcularClick(Sender: TObject);
begin
  lblTotal.Caption := FormatCurr('#,##0.00',
    CalcularTotalPedido(StrToCurr(edtQuantidade.Text), StrToCurr(edtPreco.Text), chkClienteVIP.Checked));
end;
```
Atenção: conversões (`StrToCurr`, `StrToFloat`) e mensagens de erro ficam na tela; a regra
recebe valores já convertidos. Se a conversão gerava exceção em casos inválidos, o teste de
caracterização deve continuar provando isso.

## 2. Quebrar método gigante ("se precisa de dois scrolls, refatore")
1. Identifique blocos com um objetivo (normalmente já separados por comentários ou linhas em branco).
2. Extraia cada bloco para um método privado com nome que diz o objetivo
   (`ValidarCliente`, `GravarItens`, `AtualizarEstoque`).
3. Variáveis locais usadas por um só bloco vão junto. Usadas por vários viram parâmetros ou
   retorno. Se precisar de mais de 4 parâmetros, considere um record.
4. O método original vira uma sequência legível de chamadas.

## 3. Eliminar código duplicado
1. Compare as cópias (o diagnóstico mostra onde estão) e liste as **diferenças** entre elas.
2. Escolha uma cópia como base e extraia para uma função comum, com parâmetros para as diferenças.
3. Troque **uma cópia por vez** pela chamada. Compile e teste a cada troca.
4. Se duas cópias tinham comportamento diferente por bug (uma corrigida, outra não), **pare e
   pergunte**: unificar muda o comportamento de uma delas.

## 4. Variáveis globais → parâmetros ou propriedades
```pascal
// antes: interface da unit
var
  EmpresaAtual: Integer;   // lida em 60 lugares
```
1. Crie um acesso único (`function EmpresaAtual: Integer` lendo a variável).
2. Troque as leituras pela função. Compile.
3. Onde der, passe o valor como parâmetro em vez de ler a função (torna o código testável).
4. A variável vira privada (`implementation`). O teste pode controlar o valor por um setter.

## 5. Quebrar acoplamento circular entre units
Unit A usa B e B usa A (pela `implementation`):
1. Descubra o que B precisa de A (geralmente um tipo, uma constante ou uma função utilitária).
2. Mova isso para uma unit nova C, sem dependências, usada pelas duas.
3. Se B precisa chamar algo de A, inverta: A passa para B um evento (`TNotifyEvent`, método
   anônimo) ou uma interface.
O MMX e o diagnóstico ajudam a encontrar os ciclos.

## 6. Retirar `with`
Veja a skill `delphi-cleanup` (regra 5). É pré-requisito para as outras refatorações no trecho.

## 7. SQL concatenado → parâmetros
```pascal
// antes
qry.SQL.Text := 'SELECT * FROM CLIENTES WHERE NOME LIKE ''' + edtBusca.Text + '%''';

// depois
qry.SQL.Text := 'SELECT * FROM CLIENTES WHERE NOME LIKE :NOME';
qry.ParamByName('NOME').AsString := edtBusca.Text + '%';
```
Fecha a porta para SQL injection e para erros de formato de data e decimal. Cubra com teste:
buscas com aspas simples (`D'Ávila`) passam a funcionar, e isso é uma mudança visível de comportamento.
Registre como melhoria, não como refatoração.

## 8. Acesso a dados espalhado nas telas → fachada
Telas que fazem `dm.qryClientes.Close; ... Open` passam a chamar métodos de uma unit fachada
(`TRepoClientes.Buscar(ACodigo)`), que por dentro usa o DataModule. Depois disso, dividir o
DataModule fica possível: veja [dividir-datamodule.md](dividir-datamodule.md).

## 9. Unit gigante → units por responsabilidade
1. Agrupe os métodos por assunto (o nome costuma denunciar: `Fiscal...`, `Estoque...`, `Imprimir...`).
2. Mova um grupo por vez para uma unit nova. A unit original passa a usar a nova (`uses`).
3. Chamadores externos continuam compilando porque a unit original ainda "repassa"; depois,
   ajuste os chamadores para usar a unit nova diretamente e remova o repasse.
