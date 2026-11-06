# Guia de correções para Unicode

Os comportamentos marcados com **(D13)** foram conferidos no compilador do Delphi 13 (Win32,
Windows em codepage 1252). Detalhes dos tipos e conversões: [strings-e-codepages.md](strings-e-codepages.md).
Referência: *Delphi and Unicode*, Marco Cantù (Embarcadero, 2008).

## Tipos antes e depois
| Tipo | Delphi 2007 ou anterior | Delphi 2009 em diante |
|---|---|---|
| `string` | `AnsiString` (1 byte por caractere, codepage do Windows) | `UnicodeString` (UTF-16 LE, 2 bytes por elemento, codepage 1200) |
| `Char` | `AnsiChar` | `WideChar` |
| `PChar` | `PAnsiChar` | `PWideChar` (`Inc(P)` anda 2 bytes **(D13)**) |
| `AnsiString` | sem codepage | 1 byte, **com codepage** (padrão: a do sistema, `DefaultSystemCodePage`) |
| `AnsiChar`, `PAnsiChar` | iguais | iguais (continuam 1 byte) |
| `UTF8String` | apelido de `string`, sem conversão | tipo próprio, `AnsiString(65001)`: converte sozinho de/para `string` |
| `RawByteString` | n/d | `AnsiString($FFFF)`: aceita qualquer codepage sem converter; use como **parâmetro** |
| `ShortString` / `string[n]` | Ansi | continua Ansi (1 byte, codepage do sistema) |
| `WideString` | UTF-16, sem contagem de referência | igual: deixe só para COM/OLE; no resto, `string` |
| `TBytes` | `array of Byte` (no Delphi 7, `Types.TByteDynArray`) | `TArray<Byte>` (D13): o tipo certo para bytes |

## Sets de Char (W1050)
O compilador trata o set como set de `AnsiChar` e avisa com W1050. O que acontece de verdade **(D13)**:
- caractere acima de 255 dá `False` (`'š' in ['a'..'z']` é `False`; o byte baixo **não** é comparado);
- literal de 128 a 255 dentro do set é convertido pela codepage: `['€']` vira o byte 128. Resultado:
  `C in ['€']` é `False` para o `€` real (U+20AC) e `True` para U+0080;
- `CharInSet` faz **a mesma conta** (só tira o warning). Não corrige o caso do `€`.

```pascal
// antes
if C in ['0'..'9'] then
// depois: set só com ASCII (0..127) → CharInSet resolve
if CharInSet(C, ['0'..'9']) then
// set com caractere acima de 127 (acentos, €, aspas tipográficas) → IsInArray (uses System.Character)
if C.IsInArray(['€', 'ç', 'Ç']) then
// classificação Unicode
if C.IsLetter then      // aceita letras acentuadas de qualquer alfabeto
```
Cuidado: `C.IsDigit` aceita dígitos de outros alfabetos (U+0663, dígito árabe, dá `True` **(D13)**).
Para validar campo numérico (CPF, CNPJ, valor) mantenha `CharInSet(C, ['0'..'9'])`.

`set of Char` e `set of 'a'..'z'` também dão W1050: troque por `set of AnsiChar` ou `TSysCharSet`
e teste com `CharInSet`. Um set não guarda caracteres acima de 255: se precisa deles, mude o algoritmo.

## Move, FillChar, SizeOf e buffers
```pascal
// antes: copia N bytes, e no Unicode só metade do texto vai ('ABCD' → 41 00 42 00)
Move(S[1], Buffer, Length(S));
// depois
Move(S[1], Buffer, Length(S) * SizeOf(Char));   // ou ByteLength(S)
```
Se o buffer é de bytes para um protocolo/arquivo, não copie a string: converta com encoding.

Buffers `array[0..255] of Char`: `SizeOf(Buffer)` agora é 512 **(D13)**. APIs que pedem o
**número de caracteres** (`GetWindowText`, `GetModuleFileName`, `GetTempPath`...) devem receber
`Length(Buffer)`; passar `SizeOf` estoura o buffer.
```pascal
GetModuleFileName(0, Buffer, Length(Buffer));   // não SizeOf(Buffer)
```
`FillChar(Buffer, SizeOf(Buffer), 'A')` preenche **bytes**: num buffer de `Char` gera `#$4141`.
Para repetir caractere use `StringOfChar`.

Aritmética de ponteiro: `Inc(PChar)` anda 2 bytes. Para andar byte a byte use `PByte`.

## UTF-8 e ANSI convertidos à mão (UTF8Encode, Utf8ToAnsi)
No Delphi 7, `UTF8String` era só um apelido de `string`: `S := UTF8Encode(S)` deixava os bytes
UTF-8 dentro da string, prontos para gravar ou enviar. Hoje `UTF8Encode` devolve uma string com
codepage 65001, e guardá-la numa `string` **converte de volta**: `Length(UTF8Encode('ação'))`
numa `string` é 4, não 6 **(D13)**, e o compilador só dá W1057. `UTF8Decode` está obsoleto.
```pascal
// antes (Delphi 7): bytes UTF-8 numa string
Corpo := UTF8Encode(Texto);
// depois: bytes de verdade
Bytes := TEncoding.UTF8.GetBytes(Texto);    // sem BOM
Texto := TEncoding.UTF8.GetString(Bytes);
// ou, se precisa de string de 1 byte (API que recebe PAnsiChar em UTF-8)
Utf8 := UTF8String(Texto);   // e passe PAnsiChar(Utf8)
```
`Utf8ToAnsi`/`AnsiToUtf8` em código migrado costumam virar conversões duplas: remova e decida
o encoding na fronteira.

## Chr, #n e caracteres de 128 a 255
**(D13)**: `Chr(128)` é U+0080 (Unicode). O literal `#128` segue a codepage do compilador:
numa máquina 1252 vira `€` (U+20AC), a não ser que `{$HIGHCHARUNICODE ON}` esteja ativo
(aí vira U+0080). O mesmo código pode gerar caracteres diferentes conforme a máquina de build.
Use o próprio caractere no fonte (fonte em UTF-8) ou o código Unicode explícito (`#$20AC`).
Numa `AnsiString`, o literal `#128` continua sendo o byte 128 **(D13)**.

## Arquivos e fronteiras (o ponto mais importante)
Arquivos de integração, layouts bancários, EDI, SPED, comunicação com equipamentos: o layout
define o encoding (quase sempre ANSI/WIN1252 em sistemas antigos, às vezes UTF-8). Deixe explícito:
```pascal
// TStrings
Lista.SaveToFile(Arquivo, TEncoding.ANSI);    // ou TEncoding.UTF8
Lista.LoadFromFile(Arquivo, TEncoding.ANSI);

// Bytes
Bytes := TEncoding.ANSI.GetBytes(Texto);
Texto := TEncoding.ANSI.GetString(Bytes);

// Encoding de um codepage específico
Enc := TEncoding.GetEncoding(1252);
try
  Bytes := Enc.GetBytes(Texto);
finally
  Enc.Free;
end;
```
Comportamento do `TStrings` **(D13)**:
- sem encoding, `SaveToFile` grava ANSI (`DefaultEncoding` = codepage do sistema), como antes;
  caracteres fora da codepage são trocados por um parecido (`Ω` vira `O`) ou por `?` (`中`), sem erro;
- `SaveToFile(Arquivo, TEncoding.UTF8)` grava o BOM `EF BB BF`. Se o outro lado não aceita BOM:
  `Lista.WriteBOM := False` antes de gravar, ou grave os bytes:
  `TFile.WriteAllBytes(Arquivo, TEncoding.UTF8.GetBytes(Texto))` (`GetBytes` não inclui o BOM);
- `LoadFromFile` sem encoding usa o BOM; **sem BOM, lê como ANSI**: um UTF-8 sem BOM vira `Ã§`.
  Para arquivo UTF-8 sem BOM, passe `TEncoding.UTF8`;
- com encoding informado, o BOM do arquivo é ignorado; se os bytes não forem válidos no encoding
  pedido, levanta `EEncodingError`;
- para mudar o padrão de um `TStrings` sem mexer em cada chamada, use a propriedade
  `DefaultEncoding` (o white paper sugere um class helper; hoje a propriedade resolve).

`AssignFile`/`Writeln` com `TextFile`: grava na codepage do sistema (ANSI) **(D13)**. Se o layout
é UTF-8, use `SetTextCodePage(F, CP_UTF8)` logo depois do `Rewrite`/`Reset`, ou `TStreamWriter`
com encoding explícito.

## Hash, criptografia, Base64, assinatura
O resultado depende dos **bytes**. `MD5(S)` com `S` Unicode calcula sobre UTF-16 e muda o hash:
senhas gravadas no banco deixam de bater, assinaturas de arquivos mudam.
```pascal
Hash := CalcularMD5(TEncoding.ANSI.GetBytes(Senha));   // mesmo resultado da versão antiga
```
Grave golden masters de hashes de valores conhecidos **na versão antiga** e compare na nova.

## DLLs externas
A DLL não sabe que o Delphi mudou. Se ela espera `char*` (1 byte):
```pascal
// antes
function Enviar(Texto: PChar): Integer; stdcall; external 'fabricante.dll';
// depois
function Enviar(Texto: PAnsiChar): Integer; stdcall; external 'fabricante.dll';
...
Enviar(PAnsiChar(AnsiString(Texto)));
```
`PAnsiChar(S)` com `S: string` compila com W1044 e passa os bytes UTF-16: a DLL lê só o
primeiro caractere (o segundo byte é zero). Converta para `AnsiString` antes.
Vale também para DLL carregada com `LoadLibrary`/`GetProcAddress`: revise os tipos de ponteiro
de função (`TFunc = function(Texto: PChar)...`) e as declarações `external NOME_DA_CONSTANTE`.
Se o texto vem da DLL (buffer preenchido por ela), declare o buffer como `array of AnsiChar`
ou `TBytes` e converta depois. Confira a documentação do fabricante: algumas DLLs têm as
versões A e W.

## APIs do Windows
Chamadas sem sufixo (`MessageBox`, `ShellExecute`) passam a usar a versão W automaticamente:
nada a fazer (o `Winapi.Windows` aponta o nome sem sufixo para a W). Chamadas com sufixo A
explícito (`MessageBoxA`, `GetWindowTextA`) precisam de `PAnsiChar` ou troca para a versão sem
sufixo. Cuidado com buffers: veja "Move, FillChar, SizeOf e buffers".

## Maiúsculas e minúsculas
**(D13)**: `UpCase` e `UpperCase`/`LowerCase` só tratam ASCII (`'ù'` continua `'ù'`);
`AnsiUpperCase`, `C.ToUpper` e `S.ToUpper` tratam acentos. Apesar do nome, `AnsiUpperCase`
trabalha com `string` Unicode: não troque por `UpperCase` achando que "Ansi" é coisa antiga.

## Desempenho
Cada atribuição entre `string`, `AnsiString` e `UTF8String` é uma conversão com cópia. Dentro de
laço, misturar os tipos deixa o código ordens de grandeza mais lento (o white paper mede
concatenação em laço: cerca de mil vezes mais lento com tipos misturados). Converta uma vez,
na fronteira.

## Banco de dados
- Firebird com `CharacterSet=WIN1252`/`NONE`: com FireDAC, campos `VARCHAR` continuam
  `TStringField` (Ansi). Ao trocar para `UTF8`, viram `TWideStringField` e os campos persistentes
  dão "Type mismatch" (veja a skill `sql-dialect-migration`, impacto no Delphi).
- BDE não é Unicode: migre o acesso a dados (skill `bde-to-firedac`).

## Warnings
Todos os desta tabela vêm **ligados por padrão** no Delphi 13, menos W1059/W1060.

| Warning | Texto (D13) | Quando aparece | Correção |
|---|---|---|---|
| W1057 | `Implicit string cast from 'X' to 'Y'` | conversão implícita sem perda: Ansi/UTF8/Raw/ShortString → `string`, e `string` → `UTF8String` | normalmente segura; troque o tipo para `string` se não precisa ser Ansi. Exceção: `string := UTF8Encode(...)` (veja acima) |
| W1058 | `Implicit string cast with potential data loss from 'string' to 'X'` | `string` → `AnsiString`/tipo com codepage/`ShortString` | decida o encoding da fronteira; não cale com cast |
| W1059 / W1060 | `Explicit string cast ...` (com/sem perda) | cast explícito; **desligados por padrão** | ligue com `-W+EXPLICIT_STRING_CAST -W+EXPLICIT_STRING_CAST_LOSS` para revisar casts |
| W1062 | `Narrowing given wide string constant lost information` | literal com caractere que não existe na codepage do destino (`AnsiStr := 'Ω'`) | o caractere é trocado por um parecido ou por `?` (`'Ω'` vira `'O'` **(D13)**): use `string` ou outro encoding |
| W1050 | `WideChar reduced to byte char in set expressions` | `set of Char`, `C in [...]` | veja "Sets de Char" |
| W1044 | `Suspicious typecast of string to PAnsiChar` | `PAnsiChar(S)` com `S: string` | converta para `AnsiString` antes, ou use `PChar` com API W |
| W1000 | `Symbol 'TCharacter' is deprecated: 'Use TCharHelper'` | `TCharacter.IsDigit(C)`, `IsDigit(C)` (código do Delphi 2009) | `C.IsDigit`, `Char.IsDigit(S, I)`, `Char.ConvertFromUtf32` |
