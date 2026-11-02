---
name: delphi-unicode-migration
description: Migra projetos do Delphi 2007 ou anterior (string = AnsiString) para Delphi Unicode (2009 até o 13), tratando string/Char/PChar, sets de Char, Move/SizeOf, AnsiString com codepage, UTF8String, arquivos texto e BOM, hash/criptografia, APIs Windows e DLLs externas, e os warnings W1057/W1058/W1050/W1044/W1062. Use quando o usuário for migrar do Delphi 7, 2005, 2006 ou 2007 para uma versão nova, mencionar Unicode, AnsiString, caracteres estranhos ou acentos quebrados depois da migração.
---

# Migração para Unicode (Delphi 2007 ou anterior → Delphi 13)

A partir do Delphi 2009, `string` é `UnicodeString` (UTF-16, 2 bytes por elemento), `Char` é
`WideChar` e `PChar` é `PWideChar`. Não existe diretiva para voltar ao comportamento antigo.
O código compila quase todo, e é aí que mora o perigo:
**o que quebra, quebra em silêncio**: arquivo de integração gravado diferente, hash que muda,
DLL que recebe metade do texto, `UTF8Encode` que deixa de converter.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Find-PadroesMigracao.ps1`: lista os pontos de risco (use `-Tipo Unicode`)
- `referencias/guia-unicode.md`: cada padrão com a correção, em Delphi
- `referencias/strings-e-codepages.md`: como os tipos de string funcionam no Delphi 13
  (codepage, conversões, warnings, surrogates, `Chr`/`#n`, encoding dos fontes), com o que
  foi conferido no compilador

Base técnica: white paper *Delphi and Unicode*, de Marco Cantù (Embarcadero, 2008, Delphi 2009),
conferido e atualizado com o compilador do Delphi 13 (as diferenças estão nas referências).

## Pré-condições
1. Projeto no Git, compilando na versão antiga (ou ao menos com os fontes íntegros).
2. Componentes de terceiros disponíveis para a versão nova. Se algum não existir, PARE e
   discuta o substituto com o usuário (risco do plano, skill `delphi-legacy-modernizer`).
3. Testes de caracterização das saídas que viram bytes: arquivos de integração, hashes,
   comunicação com DLLs, impressoras e equipamentos (skill `delphi-characterization-tests`).
   **Grave os arquivos gerados pela versão antiga** como golden master: é a única forma de
   provar que a versão nova gera os mesmos bytes.

## Processo
### 1. Levantar
```
powershell -ExecutionPolicy Bypass -File scripts/Find-PadroesMigracao.ps1 -Tipo Unicode -Pasta <pasta do projeto> -Recursivo -Excluir '<pastas de terceiros>'
```
Mostre a tabela de `_modernizacao\padroes-Unicode.md`. Os itens de risco alto são o roteiro.
A busca é por texto: complemente com os warnings do compilador (passo 4).

### 2. Fazer compilar
Abra/atualize o projeto na versão nova e use a skill `delphi-compile-loop` só para **erros**.
Units renomeadas com namespace (`SysUtils` → `System.SysUtils`) podem ser resolvidas pelos
"Unit scope names" do projeto. Não troque todos os `uses` de uma vez.

**Encoding dos fontes:** `.pas` sem BOM (como no Delphi 7) é lido na codepage do compilador.
Literais com acento só ficam certos se a máquina de build tiver a mesma codepage (1252) ou se
os fontes forem convertidos para UTF-8 com BOM. Não use `--codepage` diferente sem converter.

### 3. Tratar os pontos de risco
Na ordem: DLLs externas → arquivos e protocolos (integração, TEF, impressoras) →
hash/criptografia → `UTF8Encode`/`Utf8ToAnsi` → sets de Char → Move/SizeOf/buffers → APIs.
Para cada um, use [referencias/guia-unicode.md](referencias/guia-unicode.md). Regra de ouro:

**Decida o encoding de cada fronteira** (onde o texto vira bytes ou vem de bytes) e deixe-o
explícito no código (`TEncoding`, `TBytes`). Dentro do programa, tudo é `string`.
Não espalhe `AnsiString` pelo código para "voltar a funcionar": cada atribuição entre tipos
de string diferentes é uma conversão (lenta em laço e, no sentido Unicode → Ansi, com perda).

### 4. Warnings de string
Com a skill `delphi-compile-loop`, meta "zerar warnings" nos códigos W1057, W1058, W1050,
W1044 e W1062 (todos ligados por padrão no Delphi 13). Não silencie com cast: o cast explícito
só troca o aviso por W1059/W1060, que vêm **desligados** por padrão, e a perda continua.
W1057 não é sempre inofensivo: `string := UTF8Encode(S)` dá só W1057 e muda o resultado.
Código copiado do Delphi 2009 com `TCharacter.IsDigit(C)` dá W1000 (obsoleto): use `C.IsDigit`.

### 5. Validar
Rode os testes de caracterização, principalmente os golden masters de arquivos gerados.
Teste com dados que tenham acentos, `ç`, `º`, `ª`, `€`, aspas tipográficas e, se o sistema
recebe texto de fora, um caractere fora do BMP (emoji), que ocupa 2 elementos da string.

## Entrega
1. Tabela de pontos de risco: encontrados × tratados × pendentes.
2. Mapa das fronteiras de encoding decididas (arquivo/DLL/protocolo → encoding, com ou sem BOM).
3. Warnings de string antes × depois.
4. Resultado dos golden masters de arquivos.
