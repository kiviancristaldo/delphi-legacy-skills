---
name: delphi-64bit-ready
description: Prepara e migra aplicações Delphi VCL de 32 para 64 bits (plataforma Win64) - ponteiros guardados em Integer, Tag, SetWindowLong, mensagens Windows, assembler, Extended que perde precisão, DLLs e componentes sem versão 64 bits, registros gravados em arquivo e IFDEF WIN32. Use quando o usuário quiser compilar em 64 bits, adicionar a plataforma Win64, precisar de mais memória, ou tiver erros e crashes que só acontecem no executável 64 bits.
---

# Pronto para 64 bits

Em Win64, ponteiros, `NativeInt`, `THandle`, `WPARAM` e `LPARAM` passam a ter 8 bytes;
`Integer`, `Cardinal` e `Longint` **continuam com 4**. Todo lugar que guarda ponteiro em
`Integer` funciona por sorte no 32 e quebra no 64, muitas vezes só com mais memória em uso.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Find-PadroesMigracao.ps1`: lista os pontos de risco (use `-Tipo Win64`)
- `referencias/guia-64bits.md`: tamanhos de tipos e correções

## Pré-condições
1. Projeto compilando e testado em **Win32** na versão atual do Delphi. Migração de versão
   e Unicode vêm antes (skills `delphi-unicode-migration` e `delphi-compile-loop`).
2. BDE removido (não existe BDE 64 bits): skill `bde-to-firedac`.
3. Lista de DLLs externas e componentes de terceiros. **Para cada um, existe versão 64 bits?**
   Sem isso, PARE: é o maior risco da migração (DLLs de TEF, impressoras fiscais, balanças,
   `fbclient.dll`, OpenSSL, componentes de relatório).

## Processo
### 1. Levantar
```
powershell -ExecutionPolicy Bypass -File scripts/Find-PadroesMigracao.ps1 -Tipo Win64 -Pasta <pasta do projeto> -Recursivo -Excluir '<pastas de terceiros>'
```
Mostre a tabela de `_modernizacao\padroes-Win64.md`, junto com a lista de DLLs e componentes
e a situação de cada um (tem 64 bits? onde baixar? quem verifica?).

### 2. Corrigir mantendo o 32 bits funcionando
Todas as correções de [referencias/guia-64bits.md](referencias/guia-64bits.md) funcionam
também em Win32. Corrija primeiro, ainda compilando em Win32, e rode os testes: o 32 bits
continua sendo a versão de produção durante toda a migração.

### 3. Adicionar a plataforma Win64
No IDE: Projects → Target Platforms → Add Platform → Windows 64-bit. Compile com a skill
`delphi-compile-loop` usando `-Plataforma Win64`. Erros e warnings novos que aparecem só em
Win64 são o alvo.

### 4. Testar em 64 bits
1. Rode os testes de caracterização compilados em Win64.
2. **Extended**: em Win64, `Extended` tem a mesma precisão de `Double`. Cálculos de impostos e
   arredondamentos podem mudar na última casa. Compare golden masters de cálculos 32 × 64.
3. Teste com bastante memória em uso (abra muitas telas, relatórios grandes): ponteiros truncados
   costumam funcionar até o endereço passar de 4 GB.
4. Teste cada integração com DLL e equipamento em 64 bits.

### 5. Implantar
32 e 64 bits podem conviver por um tempo: pastas de instalação separadas, cada uma com suas DLLs
da mesma bitagem. Uma DLL de 32 bits na pasta do executável 64 bits causa erro ao carregar.

## Entrega
1. Tabela de pontos de risco: encontrados × corrigidos × pendentes.
2. Tabela de DLLs e componentes com a situação da versão 64 bits.
3. Resultado dos testes em Win32 e Win64, incluindo a comparação de cálculos.
