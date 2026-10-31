# Guia de correções para Unicode

## Tipos antes e depois
| Tipo | Delphi 2007 ou anterior | Delphi 2009 em diante |
|---|---|---|
| `string` | `AnsiString` (1 byte por caractere, codepage do Windows) | `UnicodeString` (UTF-16, 2 bytes) |
| `Char` | `AnsiChar` | `WideChar` |
| `PChar` | `PAnsiChar` | `PWideChar` |
| `AnsiString`, `AnsiChar`, `PAnsiChar` | iguais | iguais (continuam 1 byte) |
| `ShortString` / `string[n]` | Ansi | continua Ansi |
| `RawByteString` | n/d | AnsiString sem conversão de codepage |
| `TBytes` | n/d (XE+) | `array of Byte`: o tipo certo para bytes |

## Sets de Char (W1050)
```pascal
// antes
if C in ['0'..'9'] then
// depois
if CharInSet(C, ['0'..'9']) then
// ou, melhor para letras com acento:
if C.IsDigit then   // uses System.Character
```
`C in ['a'..'z']` com `C: WideChar` só compara o byte baixo: caracteres acima de 255 dão resultado errado.

## Move, FillChar e SizeOf
```pascal
// antes: copia N bytes, e no Unicode só metade do texto vai
Move(S[1], Buffer, Length(S));
// depois
Move(S[1], Buffer, Length(S) * SizeOf(Char));   // ou ByteLength(S)
```
Se o buffer é de bytes para um protocolo/arquivo, não copie a string: converta com encoding.

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
Atenção: `TEncoding.UTF8` grava BOM com `SaveToFile`. Se o outro lado não aceita BOM, grave
os bytes sem preâmbulo: `TFile.WriteAllBytes(Arquivo, TEncoding.UTF8.GetBytes(Texto))`
(`GetBytes` não inclui o BOM).

`AssignFile`/`Writeln` com `TextFile`: grava na codepage do sistema (ANSI). Se o layout é UTF-8,
use `TStreamWriter` com encoding explícito.

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
Se o texto vem da DLL (buffer preenchido por ela), declare o buffer como `array of AnsiChar`
ou `TBytes` e converta depois. Confira a documentação do fabricante: algumas DLLs têm as
versões A e W.

## APIs do Windows
Chamadas sem sufixo (`MessageBox`, `ShellExecute`) passam a usar a versão W automaticamente:
nada a fazer. Chamadas com sufixo A explícito (`MessageBoxA`) precisam de `PAnsiChar` ou
troca para a versão sem sufixo.

## Banco de dados
- Firebird com `CharacterSet=WIN1252`/`NONE`: com FireDAC, campos `VARCHAR` continuam
  `TStringField` (Ansi). Ao trocar para `UTF8`, viram `TWideStringField` e os campos persistentes
  dão "Type mismatch" (veja a skill `sql-dialect-migration`, impacto no Delphi).
- BDE não é Unicode: migre o acesso a dados (skill `bde-to-firedac`).

## Warnings
| Warning | Significado | Correção |
|---|---|---|
| W1057 | conversão implícita Ansi → Unicode | normalmente segura; troque o tipo da variável para `string` se não precisa ser Ansi |
| W1058 | conversão Unicode → Ansi com possível perda | decida o encoding da fronteira; não cale com cast |
| W1050 | WideChar em set | `CharInSet` / `System.Character` |
| W1044 | cast suspeito de string para `PAnsiChar` | converta para `AnsiString` antes, ou use `PChar` com API W |
