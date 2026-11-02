# Strings, codepages e conversões no Delphi Unicode

Resumo de como os tipos de texto funcionam a partir do Delphi 2009, com base no white paper
*Delphi and Unicode*, de Marco Cantù (Embarcadero, dezembro de 2008), e **conferido no
compilador do Delphi 13** (Win32, Windows em codepage 1252). Onde o Delphi 13 se comporta
diferente do documento, vale o Delphi 13 e a diferença está anotada.

## UTF-16 e o que `Length` conta
- `string` = `UnicodeString`: UTF-16 little-endian, codepage 1200 (`DefaultUnicodeCodePage`),
  contagem de referência e cópia na escrita, como a `AnsiString` antiga. `WideString` continua
  existindo, sem contagem de referência e mais lenta: só para COM/OLE.
- `Length(S)` conta **elementos** (`WideChar`), não caracteres. Um caractere fora do BMP (emoji,
  símbolos musicais, alguns ideogramas) ocupa 2 elementos (par de surrogates):
  `Length('Surr. ' + Char.ConvertFromUtf32($1D11E))` = 8 **(D13)**.
- Laço `for I := 1 to Length(S)` e `for C in S` passam por cada elemento. `Copy`, `Delete` e
  truncamento por tamanho (campo de banco, layout fixo) podem cortar um par ao meio.
  Para tratar pares: `S[I].IsHighSurrogate`, `Char.IsSurrogatePair(S, I)`, `Char.ConvertToUtf32`.
- Em UTF-8, `Length` conta bytes: `Length(UTF8String('Cantù'))` = 6; em `string`, 5 **(D13)**.

## Metadados da string
Toda string com contagem de referência (`UnicodeString` e `AnsiString`) guarda, antes do
primeiro caractere: codepage, tamanho do elemento, contagem de referência e comprimento.
Funções para consultar:

| Função | `string` | `AnsiString` | `UTF8String` |
|---|---|---|---|
| `SizeOf(variável)` | 4 no Win32 (é um ponteiro; 8 no Win64) | 4 | 4 |
| `StringElementSize` | 2 | 1 | 1 |
| `StringCodePage` | 1200 | `DefaultSystemCodePage` (1252 aqui) | 65001 |
| `ByteLength` | `Length * 2` | `Length` | `Length` (bytes) |

**(D13)** Diferença do documento: ele diz que `ByteLength` só funciona com `UnicodeString`; no
Delphi 13 há uma sobrecarga para `RawByteString`, e com `AnsiString`/`UTF8String` o resultado
é o número de bytes, sem conversão. O exemplo do documento mostra `StringRefCount` = -1 para uma
variável que recebeu um literal; no teste com o Delphi 13 deu 1. Não use `StringRefCount` em lógica.

## AnsiString com codepage
- `AnsiString` agora carrega a codepage. A padrão é `DefaultSystemCodePage` (a do Windows),
  que pode ser trocada para o programa todo com `SetMultiByteConversionCodePage`. Evite: muda o
  comportamento de todas as conversões.
- Dá para declarar tipos com codepage fixa: `type Latin1String = type AnsiString(28591);`.
  O próprio RTL declara `UTF8String = type AnsiString(65001)` e
  `RawByteString = type AnsiString($FFFF)`.
- Atribuir entre tipos de codepage diferente **converte** (via `MultiByteToWideChar`/
  `WideCharToMultiByte`). A conversão pode perder caracteres sem erro **(D13)**:
  - `€` numa `Latin1String` vira `?` (63);
  - `ù` numa `AnsiString(1251)` (cirílico) vira `u` (a conversão troca por um parecido);
  - `Ω` numa `AnsiString(1252)` vira `O`; um ideograma vira `?`.
- `RawByteString` não converte ao receber: guarda os bytes e a codepage de origem. Use como
  **tipo de parâmetro** de rotinas que aceitam qualquer `AnsiString`. Como variável para guardar
  texto, a codepage fica indefinida e as conversões seguintes ficam imprevisíveis; o documento
  recomenda usá-la assim só para dados binários que o código antigo guardava em `AnsiString`
  (no código novo, prefira `TBytes`).
- `SetCodePage(var S: RawByteString; CodePage: Word; Convert: Boolean)` troca a codepage
  marcada; com `Convert = True` converte os bytes. Só aceita `RawByteString`.

## UTF8String
No Delphi 2007 e anteriores, `UTF8String` era só outro nome para `string`: nada impedia misturar
bytes UTF-8 com texto ANSI. Agora é um tipo próprio e converte sozinho de/para `string`
(W1057). Consequência na migração: código que guardava o resultado de `UTF8Encode` numa
`string` para enviar/gravar os bytes UTF-8 passa a guardar o texto original
(`Length` 4 em vez de 6 para `'ação'` **(D13)**). Veja o guia, seção "UTF-8 e ANSI convertidos à mão".

## Conversões implícitas e warnings
Medido no Delphi 13 (compilação padrão, sem opções):

| Atribuição | Warning |
|---|---|
| `AnsiString := string` | W1058 (possível perda) |
| `string := AnsiString` | W1057 |
| `UTF8String := string` | W1057 (o documento lista W1058; no Delphi 13 é W1057, pois UTF-8 representa tudo) |
| `string := UTF8String` | W1057 |
| `AnsiString := UTF8String` | W1057 + W1058 (passa por `string`) |
| `ShortString := string` | W1058 |
| `string := ShortString` | W1057 |
| `string := RawByteString` (ex.: `UTF8Encode`) | W1057 |
| `WideString := string` e o inverso | nenhum |
| `AnsiString(S)` / `string(A)` (cast explícito) | nenhum por padrão; W1060 / W1059 se ligados |
| `AnsiStr := 'Ω'` (literal fora da codepage) | W1058 + W1062 (o documento cita W2455; no Delphi 13 o número é W1062) |
| `set of Char`, `C in [...]` | W1050 (no Delphi 13 o texto sugere `CharInSet` ou `TCharHelper.IsInArray`) |
| `PAnsiChar(S)` com `S: string` | W1044 |
| `UpperCase(AnsiStr)` (função que só tem versão `string`) | W1057 |

O documento se contradiz sobre W1057/W1058 virem ligados: no Delphi 13 eles **vêm ligados**.
Os de cast explícito (W1059 `EXPLICIT_STRING_CAST`, W1060 `EXPLICIT_STRING_CAST_LOSS`) vêm
desligados; para auditar casts, compile uma vez com
`dcc32 -W+EXPLICIT_STRING_CAST -W+EXPLICIT_STRING_CAST_LOSS`.

## Desempenho das conversões
Conversão implícita aloca e copia. O documento mostra concatenação em laço misturando
`AnsiString` e `UTF8String` cerca de três ordens de grandeza mais lenta que com `string`, e
`AnsiUpperCase` sobre `AnsiString` mais lento que sobre `string` (duas conversões por chamada).
Regra: converta uma vez, na fronteira; nunca dentro de laço.

## Char, Chr e literais
- `Char` continua ordinal: `Inc`, `Dec`, `for C := ... to ...` e `High(Char)` (= `#$FFFF`) funcionam.
- `Chr(N)` aceita até 65535 e é sempre Unicode: `Chr(128)` = U+0080 **(D13)**.
- Literal `#N` de 128 a 255 segue a codepage do compilador: em 1252, `#128` = `€` (U+20AC)
  **(D13)**. Com `{$HIGHCHARUNICODE ON}`, `#128` = U+0080. Prefira `#$20AC` ou o próprio caractere.
- `UCS4Char` (4 bytes) e `UCS4String` (array dinâmico de `UCS4Char`, sem cópia na escrita)
  existem para trabalhar com code points, mas têm pouco suporte no RTL.

## TCharacter → helpers de Char
O documento apresenta a classe `TCharacter` (unit `Character`) e funções globais como
`IsDigit(C)`, `ToUpper(C)`, `ConvertFromUtf32`. No Delphi 13 a unit é `System.Character`, e
tanto `TCharacter` quanto as funções globais estão **obsoletas** (W1000, "Use TCharHelper")
**(D13)**. Use o helper de `Char`: `C.IsDigit`, `C.IsLetter`, `C.ToUpper`, `C.IsInArray([...])`,
`Char.IsDigit(S, I)`, `Char.ConvertFromUtf32(CP)`, `Char.ConvertToUtf32(S, I)`.
`UpCase`/`UpperCase` continuam só ASCII; `AnsiUpperCase` e os helpers tratam acentos.

## TEncoding e BOM
- `TEncoding` (unit `System.SysUtils`) tem instâncias prontas: `ANSI`, `ASCII`, `Default`,
  `Unicode` (UTF-16 LE), `BigEndianUnicode`, `UTF7`, `UTF8`. Não dê `Free` nelas; dê `Free` no
  que vier de `TEncoding.GetEncoding(codepage)`.
- `GetPreamble` devolve o BOM; `GetBytes`/`GetString` não incluem nem esperam BOM.
- BOMs: `EF BB BF` (UTF-8), `FF FE` (UTF-16 LE), `FE FF` (UTF-16 BE), `FF FE 00 00` (UTF-32 LE),
  `00 00 FE FF` (UTF-32 BE).
- `TStrings`: comportamento conferido no guia, seção "Arquivos e fronteiras". O documento sugere
  um class helper para mudar o encoding padrão de `SaveToFile`; no Delphi 13 use a propriedade
  `TStrings.DefaultEncoding` (e `WriteBOM` para gravar sem BOM).

## APIs do Windows
Cada API com texto tem versões A (`PAnsiChar`) e W (`PWideChar`). Até o Delphi 2007 o nome sem
sufixo apontava para a A; desde o 2009 aponta para a W (`Winapi.Windows`: `MessageBox` →
`MessageBoxW`). Chamadas sem sufixo continuam compilando e passam a ser Unicode; chamadas com
sufixo A explícito precisam de texto Ansi.

## Encoding dos fontes
O documento lembra que fontes com caracteres acima de 255 precisam ser gravados em formato
Unicode. Na migração de um Delphi 7 isso tem um efeito prático **(D13)**: um `.pas` sem BOM é
lido na codepage do compilador (`ç` em 1252 vira U+00E7 corretamente); com `--codepage:65001`,
o mesmo fonte ANSI gera U+FFFD. Mantenha todas as máquinas de build na mesma codepage ou converta
os fontes para UTF-8 com BOM numa mudança separada (e confira o diff).

## RTTI e componentes
Segundo o documento, VCL e RTL passaram a usar `string` em todas as propriedades; partes internas
como nomes de propriedades na RTTI (`TypInfo`) usam UTF-8. Componentes de terceiros sem versão
Unicode são o principal bloqueio da migração: confira antes de começar.

## Fora do escopo
Esta skill trata Windows (Win32/Win64). Os compiladores móveis antigos (NEXTGEN) não tinham
`AnsiString`; isso não foi verificado aqui porque o ambiente de teste não tem compiladores móveis.
