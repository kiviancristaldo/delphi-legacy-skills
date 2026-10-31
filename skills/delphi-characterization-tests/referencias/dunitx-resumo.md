# DUnitX: resumo rápido

## Estrutura de uma classe de teste
```pascal
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestFinanceiro = class
  public
    [Setup]    procedure Setup;      // antes de CADA teste
    [TearDown] procedure TearDown;   // depois de CADA teste
    [SetupFixture]    procedure SetupFixture;    // uma vez, antes de todos
    [TearDownFixture] procedure TearDownFixture; // uma vez, depois de todos

    [Test]
    procedure TesteSimples;

    [Test]
    [TestCase('Caso A', '10;20;30', ';')]   // nome, valores, separador
    [TestCase('Caso B', '0;0;0', ';')]
    procedure Soma(const A, B, Esperado: Integer);

    [Test]
    [Ignore('Motivo')]
    procedure AindaNaoImplementado;
  end;

initialization
  TDUnitX.RegisterTestFixture(TTestFinanceiro);
```

## Asserts mais usados
| Assert | Uso |
|---|---|
| `Assert.AreEqual(Esperado, Atual)` | inteiros, strings, booleanos |
| `Assert.AreEqual(Esperado, Atual, 0.001)` | `Double`/`Currency` (sempre com tolerância) |
| `Assert.IsTrue(Cond)` / `Assert.IsFalse(Cond)` | condições |
| `Assert.IsNull(Obj)` / `Assert.IsNotNull(Obj)` | objetos |
| `Assert.Contains(Texto, Trecho)` | string contém trecho |
| `Assert.WillRaise(procedure begin ... end, EMinhaExcecao)` | exceção esperada |
| `Assert.WillNotRaise(procedure begin ... end)` | não pode gerar exceção |
| `Assert.Fail('mensagem')` | falha explícita |

## Caracterizando exceções
O código atual gera exceção para entrada inválida? Isso também é comportamento e precisa
ser registrado:
```pascal
Assert.WillRaise(
  procedure begin CalcularDesconto(-1) end,
  EConvertError);
```

## Dicas
- `TestCase` só aceita tipos simples nos parâmetros (inteiro, string, double, boolean).
- Use `;` como separador por causa da vírgula decimal.
- Um `[TestFixture]` por unit de produção ajuda a localizar falhas.
- Objetos criados no teste vão em `try/finally`. Vazamento de memória em teste vira ruído.
