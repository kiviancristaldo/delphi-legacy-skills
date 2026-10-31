# Erros, warnings e hints mais comuns em migração

## Fatais e erros de projeto
| Código | Mensagem típica | Causa provável | Correção |
|---|---|---|---|
| F2613 | `Unit 'X' not found` | unit renomeada, removida, fora do search path ou nome errado no `uses` | procure o arquivo no disco; se existe, ajuste o search path; se não existe, descubra o substituto (ex.: `FireDAC.Stan.Params` → `FireDAC.Stan.Param`) |
| F1026 | `File not found: 'X.dcu'` | mesma família, compiladores/caminhos antigos | idem |
| F2051 | `Unit X was compiled with a different version of Y` | `.dcu` antigo no caminho | apague os `.dcu` antigos (pasta de saída de units) e recompile o pacote do componente |
| F2063 | `Could not compile used unit 'X'` | erro dentro de outra unit | corrija primeiro a unit citada |
| MSB.... | erros do MSBuild | `.dproj` corrompido ou de versão antiga | abra e salve o projeto no Delphi 13, ou recrie o `.dproj` a partir do `.dpr` |

## Erros
| Código | Mensagem típica | Causa provável em migração | Correção |
|---|---|---|---|
| E2003 | `Undeclared identifier: 'X'` | falta unit no uses, identificador renomeado (FireDAC, VCL), constante que mudou de unit | ache onde o identificador é declarado hoje; acrescente a unit |
| E2010 | `Incompatible types: 'X' and 'Y'` | `string`×`AnsiString`, `PChar`×`PAnsiChar`, `Integer`×`Pointer` (64 bits), tipos FireDAC × BDE | entenda o tipo esperado; nas strings, veja a seção Unicode |
| E2029 | `'X' expected but 'Y' found` | sintaxe, palavra reservada nova usada como identificador | renomeie o identificador ou use `&nome` |
| E2033 | `Types of actual and formal var parameters must be identical` | `var` com `string`×`AnsiString`, `Integer`×`NativeInt` | declare a variável com o tipo exato do parâmetro |
| E2034 / E2035 | `Too many / Not enough actual parameters` | método mudou de assinatura (eventos FireDAC, metadados) | veja a assinatura atual e ajuste a chamada |
| E2089 | `Invalid typecast` | cast entre tipos de tamanho diferente (64 bits) | use o tipo correto (`NativeInt`, `UIntPtr`) |
| E2250 | `There is no overloaded version of 'X' that can be called with these arguments` | tipos dos argumentos mudaram | confira os tipos de cada argumento |
| E2251 | `Ambiguous overloaded call to 'X'` | literal que casa com dois overloads (`Char`×`AnsiChar`) | tipe o argumento explicitamente |
| E2362 | `Cannot access protected symbol` | acesso a membro protegido que antes era público | use a API pública equivalente |

## Warnings (Unicode, os mais comuns vindos do Delphi 2007 ou anterior)
| Código | Mensagem típica | Risco | Correção |
|---|---|---|---|
| W1057 | `Implicit string cast from 'AnsiString' to 'string'` | baixo (pode haver conversão de codepage) | se a variável não precisa ser Ansi, mude para `string`; se precisa (API, arquivo, protocolo), faça cast explícito comentado |
| W1058 | `Implicit string cast with potential data loss from 'string' to 'AnsiString'` | **alto**: caracteres fora do codepage viram `?` | entenda o destino: arquivo/protocolo com encoding definido → use `TEncoding`; senão, mude o tipo para `string` |
| W1050 | `WideChar reduced to byte char in set expressions` | **alto**: `if C in ['a'..'z']` falha para caracteres > 255 | use `CharInSet(C, [...])` ou funções de `System.Character` (`C.IsLetter`) |
| W1044 | `Suspicious typecast of string to PAnsiChar` | **alto**: ponteiro para memória UTF-16 lido como bytes | use `PChar` com API `W`, ou converta para `AnsiString` antes |
| W1047 / W1048 | código inseguro / typecast inseguro | médio | revise; costuma vir de ponteiros e `absolute` |

## Warnings (64 bits e tipos)
| Código | Mensagem típica | Correção |
|---|---|---|
| W1024 | `Combining signed and unsigned types - widened both operands` | alinhe os tipos (normalmente `Integer`/`Cardinal`) |
| W1023 | `Comparing signed and unsigned types` | idem |
| W1071 | `Implicit integer cast with potential data loss` | troque o tipo da variável ou faça cast explícito comentado após checar o intervalo |
| W1035 | `Return value of function 'X' might be undefined` | **provável bug**: há caminho sem `Result :=` |
| W1036 | `Variable 'X' might not have been initialized` | **provável bug**: inicialize no ponto certo, não só para calar |

## Warnings (APIs obsoletas)
| Código | Mensagem típica | Correção |
|---|---|---|
| W1000 | `Symbol 'X' is deprecated` (às vezes com a sugestão do substituto) | troque pelo substituto indicado (ex.: `FileAge(arquivo)` → `FileAge(arquivo, DataHora)`) |
| W1002 / W1005 | símbolo/unit específico de plataforma | ok em projeto só Windows; não suprima sem o usuário decidir |

## Hints
| Código | Mensagem típica | Correção |
|---|---|---|
| H2164 | `Variable 'X' is declared but never used` | remova a declaração |
| H2077 | `Value assigned to 'X' never used` | remova a atribuição **se** o lado direito não tiver efeito colateral |
| H2443 | `Inline function 'X' has not been expanded because unit 'Y' is not specified in USES list` | acrescente a unit indicada ao uses |
| H2219 | `Private symbol 'X' declared but never used` | remova, se não for usado via RTTI |

## Dicas de diagnóstico
- O mesmo código em muitos arquivos quase sempre tem **uma causa só**: ache-a antes de corrigir arquivo por arquivo.
- Depois de mudar o search path, compile com Rebuild.
- `.dcu` antigos de componentes compilados em outra versão causam erros estranhos: limpe a pasta de saída.
