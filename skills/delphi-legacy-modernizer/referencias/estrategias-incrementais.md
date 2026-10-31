# Estratégias incrementais em Delphi

Todas seguem a mesma ideia: o código novo nasce **ao lado** do antigo, os dois convivem,
uma chave decide qual roda e o antigo só sai quando o novo está provado.

## 1. Abstração por interface (branch by abstraction)
Quando: trocar a implementação de algo usado em muitos lugares (cálculo, acesso a dados, impressão).

```pascal
// 1. Interface com o que os chamadores precisam (não com o que o código antigo faz)
type
  ICalculoImpostos = interface
    ['{8C2F5E0A-3B1D-4E7A-9F21-6D0C4B8A1E55}']
    function CalcularICMS(const AItem: TItemNota): Currency;
  end;

// 2. Implementação que só chama o código antigo, sem mudar nada dele
  TCalculoImpostosLegado = class(TInterfacedObject, ICalculoImpostos)
    function CalcularICMS(const AItem: TItemNota): Currency;
  end;

// 3. Chamadores passam a usar a interface (mudança mecânica, coberta por testes)
// 4. Implementação nova, testada contra os mesmos testes de caracterização
  TCalculoImpostos = class(TInterfacedObject, ICalculoImpostos) ...

// 5. Uma fábrica decide qual usar
function NovoCalculoImpostos: ICalculoImpostos;
begin
  if Config.UsarCalculoNovo then
    Result := TCalculoImpostos.Create
  else
    Result := TCalculoImpostosLegado.Create;
end;
```
Gere o GUID da interface no IDE (Ctrl+Shift+G). Não reutilize o do exemplo.

## 2. Chave de configuração (feature flag)
Em Delphi desktop, a chave mais simples é uma entrada no `.ini` ou uma tabela de parâmetros
no banco (permite ligar por cliente/filial sem reinstalar). Regras:
- Padrão desligado (comportamento antigo).
- Ligar primeiro em um cliente/filial piloto.
- Registrar no log qual caminho rodou.
- Ter data para remover a chave e o caminho antigo.

## 3. Execução paralela (parallel run)
Quando: cálculos críticos (impostos, preços, comissões, estoque). O novo roda junto com o
antigo, o resultado oficial continua sendo o antigo e as diferenças vão para um log.
```pascal
ValorOficial := CalculoLegado.CalcularICMS(Item);
if Config.CompararCalculoNovo then
try
  ValorNovo := CalculoNovo.CalcularICMS(Item);
  if ValorNovo <> ValorOficial then
    Log.Divergencia('ICMS', Item.Codigo, ValorOficial, ValorNovo);
except
  on E: Exception do
    Log.Erro('Cálculo novo de ICMS falhou: ' + E.Message);   // nunca quebra o fluxo oficial
end;
Result := ValorOficial;
```
Quando o log ficar sem divergências por um período combinado, troque o oficial.

## 4. Estrangulamento (strangler fig) de telas e módulos
Quando: um módulo inteiro precisa ser refeito (por exemplo, a tela de pedidos de 12 mil linhas).
1. Extraia a regra de negócio da tela para classes (skill `delphi-safe-refactoring`), com testes.
2. Crie a tela nova usando essas classes.
3. O menu abre a tela nova ou a antiga conforme a chave de configuração.
4. Migre usuários aos poucos. A tela antiga continua existindo como plano B.
5. Remova a tela antiga quando ninguém mais usar.

## 5. Fachada sobre o DataModule gigante
Quando: o "DataModule Deus" é usado em todo lugar.
1. Crie uma unit fachada por assunto (`uRepoClientes`, `uRepoPedidos`) com métodos que
   expõem o que as telas precisam (`BuscarCliente(Codigo)`), chamando o DataModule por dentro.
2. Troque as telas para usarem a fachada, uma por vez.
3. Quando nenhuma tela acessa mais os datasets do DataModule diretamente, mova os datasets
   para DataModules menores atrás das fachadas.

## O que NÃO fazer
- Criar a interface "perfeita" antes de existir um segundo uso.
- Ligar o caminho novo para todos os clientes de uma vez.
- Deixar chaves de configuração eternas: cada uma tem data para morrer.
