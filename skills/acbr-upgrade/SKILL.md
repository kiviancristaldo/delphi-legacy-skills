---
name: acbr-upgrade
description: Atualiza a versão do ACBr usada num sistema Delphi com segurança - inventário dos componentes e propriedades ACBr usados, conferência contra os fontes novos (classes, units e propriedades que mudaram), configuração de SSL/certificado/schemas, homologação dos documentos fiscais e plano de volta. Use quando o usuário for atualizar o ACBr, estiver com ACBr antigo, tiver erros de propriedade/unit ACBr depois de atualizar, ou precisar adequar o sistema a mudanças fiscais que exigem ACBr novo.
---

# Atualizando o ACBr com segurança

O ACBr evolui junto com a legislação: atualizar é obrigatório, não opcional. O risco não está
em compilar (o compilador avisa), está no que **compila e se comporta diferente**: uma
propriedade de configuração que mudou de nome e ficou no padrão, um schema novo, uma
biblioteca SSL diferente.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `scripts/Test-CompatibilidadeACBr.ps1`: confere o projeto contra os fontes novos do ACBr
- `referencias/roteiro-de-atualizacao.md`: checklist completo, homologação e plano de volta

## Regra principal
**Nunca invente API do ACBr.** Nomes de classes, propriedades e métodos vêm dos fontes
novos (o script indexa), do changelog e do Fórum ACBr. Se não encontrar o substituto de algo,
diga isso e sugira perguntar no fórum, com o trecho de código e a versão.

## Pré-condições
1. Projeto no Git, compilando com a versão atual do ACBr.
2. Fontes da versão **atual** e da **nova** do ACBr disponíveis (pastas separadas), atualizados
   pelo repositório oficial do Projeto ACBr.
3. Ambiente de **homologação** da SEFAZ/TEF disponível e um certificado de teste.
4. Testes de caracterização das rotinas que montam documentos (skill `delphi-characterization-tests`):
   o golden master do XML gerado **antes** de atualizar é a melhor rede de segurança.

## Processo
### 1. Inventário e compatibilidade
```
powershell -ExecutionPolicy Bypass -File scripts/Test-CompatibilidadeACBr.ps1 -Pasta <pasta do projeto> -FontesACBr <fontes NOVOS do ACBr> -Recursivo
```
Mostre: componentes ACBr usados, units ausentes, propriedades com nome não encontrado.
Para cada item ausente, procure o substituto nos fontes novos e no changelog. Monte uma tabela
antes → depois e **mostre ao usuário antes de alterar**.

### 2. Atualizar em um branch
1. Branch `acbr-<versão>`.
2. Atualize os fontes/pacotes do ACBr e recompile os pacotes no Delphi.
3. Ajuste o código conforme a tabela aprovada. Propriedades de DFM: edite o DFM em modo
   texto ou abra o form no IDE e reconfigure.
4. Compile com a skill `delphi-compile-loop`.

### 3. Validar
1. Teste de carga de forms (propriedade que não existe mais só falha ao abrir o form).
2. Golden master do XML: compare os XMLs gerados antes e depois. Diferenças esperadas (versão
   de schema, tags novas exigidas) são documentadas; inesperadas são investigadas.
3. Homologação: emita, consulte, cancele e inutilize em homologação para cada documento usado
   (NF-e, NFC-e, CT-e, MDF-e...). Confira DANFE/impressão e TEF conforme o caso. Detalhes em
   [referencias/roteiro-de-atualizacao.md](referencias/roteiro-de-atualizacao.md).
4. Bibliotecas externas: OpenSSL/libxml2/DLLs exigidas pela versão nova, na bitagem certa (32/64).

### 4. Liberar com plano de volta
Primeiro para um cliente piloto, com o executável anterior guardado e o passo a passo para
voltar. Só depois para todos.

## Entrega
1. Inventário ACBr (componentes, units, propriedades configuradas).
2. Tabela de mudanças antes → depois, com a fonte de cada informação (fonte, changelog, fórum).
3. Resultado da compilação, do teste de forms, do golden master de XML e da homologação.
4. Plano de liberação e de volta.
