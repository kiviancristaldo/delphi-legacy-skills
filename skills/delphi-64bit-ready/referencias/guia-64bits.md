# Guia de correções para 64 bits

## Tamanhos de tipos
| Tipo | Win32 | Win64 |
|---|---|---|
| `Integer`, `Cardinal`, `Longint`, `LongWord`, `DWORD` | 4 | **4** |
| `Int64`, `UInt64` | 8 | 8 |
| `Pointer`, objetos, `PChar`, `string` (referência) | 4 | **8** |
| `NativeInt`, `NativeUInt`, `IntPtr`, `UIntPtr` | 4 | **8** |
| `THandle`, `HWND`, `WPARAM`, `LPARAM`, `LRESULT` | 4 | **8** |
| `TComponent.Tag` | `NativeInt` | `NativeInt` |
| `Extended` | 10 bytes | **8 (igual a Double)** |
| `Currency` | 8 | 8 |

## Ponteiro em inteiro
```pascal
// antes: trunca o endereço no 64 bits
Lista.AddObject(Nome, TObject(Integer(Codigo)));
Codigo := Integer(Lista.Objects[I]);
Item.Tag := Integer(Cliente);
Cliente := TCliente(Item.Tag);

// depois
Lista.AddObject(Nome, TObject(NativeInt(Codigo)));
Codigo := NativeInt(Lista.Objects[I]);
Item.Tag := NativeInt(Cliente);
Cliente := TCliente(Item.Tag);
```
Melhor ainda, quando der: em vez de guardar objeto no `Tag`/`Objects`, use um
`TDictionary<TComponent, TCliente>` ou uma lista tipada (`TObjectList<T>`).

## Mensagens e API do Windows
```pascal
// antes
SetWindowLong(Handle, GWL_WNDPROC, Longint(@NovaProc));
SendMessage(Handle, WM_MINHA, 0, Integer(Dados));
// depois
SetWindowLongPtr(Handle, GWL_WNDPROC, LONG_PTR(@NovaProc));
SendMessage(Handle, WM_MINHA, 0, LPARAM(Dados));
```
Nos handlers de mensagem, leia `Msg.LParam`/`Msg.WParam` como `LPARAM`/`WPARAM` e converta
para ponteiro com `Pointer(Msg.LParam)`, nunca passando por `Integer`.

## Assembler
Win64 não aceita blocos `asm` dentro de rotinas Pascal. Opções:
1. Reescrever em Pascal (o compilador atual otimiza bem; é o caminho normal).
2. `{$IFDEF CPUX86} asm ... {$ELSE} versão Pascal {$ENDIF}`, mantendo o asm só no 32 bits.
Toda reescrita de asm precisa de teste de caracterização (normalmente são rotinas de hash,
criptografia ou conversão).

## Extended e arredondamento
Em Win64, `Extended` = `Double`. Cálculos encadeados podem divergir na última casa decimal.
- Para dinheiro, use `Currency` (exato com 4 casas) em vez de `Double`/`Extended`.
- Arredonde explicitamente no ponto definido pela regra (`RoundTo`, `SimpleRoundTo`, ou a
  função de arredondamento do projeto) e cubra com golden master de cálculos reais.

## Registros e arquivos binários
`packed record` com `Pointer`, `NativeInt`, `string` curta ou campos alinhados muda de tamanho.
Arquivos `file of TRegistro` gravados pelo 32 bits não são lidos corretamente pelo 64 bits.
Fixe o layout com tipos de tamanho fixo (`Int32`, `Int64`, `array[0..n] of AnsiChar`) e teste
a leitura de um arquivo gravado pela versão antiga.

## Diretivas condicionais
| Use | Para |
|---|---|
| `MSWINDOWS` | qualquer código Windows (32 e 64) |
| `WIN32` / `CPUX86` | só 32 bits |
| `WIN64` / `CPUX64` | só 64 bits |
`{$IFDEF WIN32}` envolvendo código que deveria rodar em qualquer Windows faz o trecho sumir
no 64 bits, sem erro de compilação.

## DLLs
- Cada DLL precisa de versão 64 bits, na mesma pasta do executável 64 bits.
- Convenções de chamada (`stdcall`, `cdecl`) são ignoradas no Win64 (existe uma só), mas os
  **tipos** dos parâmetros precisam bater com o cabeçalho 64 bits do fabricante.
- `LoadLibrary` de DLL 32 bits a partir do executável 64 bits falha (erro 193).
