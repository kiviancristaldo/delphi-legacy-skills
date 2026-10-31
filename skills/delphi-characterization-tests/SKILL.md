---
name: delphi-characterization-tests
description: Cria testes de caracterização (golden master) com DUnitX para código Delphi legado, registrando o comportamento ATUAL antes de refatorar, migrar de versão ou trocar o acesso a dados. Use quando o usuário pedir testes para código legado, rede de segurança antes de refatorar/migrar, "congelar o comportamento", testar um form/OnClick/unit sem testes, ou antes de usar as skills bde-to-firedac, ado-to-firedac, dbx-to-firedac e sql-dialect-migration.
---

# Testes de caracterização para Delphi legado

O objetivo NÃO é testar se o código está certo. É registrar **o que ele faz hoje**,
para que qualquer mudança de comportamento durante uma refatoração ou migração apareça
como teste falhando.

## Regras que nunca podem ser quebradas

1. **Registre o comportamento atual, mesmo que pareça bug.** Se um resultado parecer
   errado, mantenha o valor atual no teste e marque com `// COMPORTAMENTO SUSPEITO: <motivo>`.
   Liste todos esses casos no relatório final. Quem decide se é bug é o usuário.
2. **Não altere o código de produção**, exceto para criar uma "costura" (seam) mínima
   descrita em [referencias/tecnicas-de-isolamento.md](referencias/tecnicas-de-isolamento.md).
   Toda costura precisa ser mostrada ao usuário e aprovada ANTES de ser aplicada.
3. **Testes precisam ser determinísticos**: formato de número/data fixo (o projeto de
   testes já fixa `FormatSettings`), data/hora controlada, `ORDER BY` em toda consulta
   comparada, nada de rede, impressora ou diálogos modais.
4. Confirme que o projeto está versionado no Git com tudo commitado. Se não estiver, PARE e avise.

## Processo

### 1. Entender o alvo
Leia o código que será caracterizado (função, método, OnClick, DataModule) e anote:
- **Entradas**: parâmetros, campos do form, propriedades, variáveis globais, dados do banco, arquivos.
- **Saídas**: retorno, campos alterados, labels/grids, registros gravados, arquivos gerados, exceções.
- **Dependências que atrapalham**: `Now`/`Date`, `ShowMessage`/`MessageDlg`, banco real, arquivos, impressão.
- **Caminhos**: cada `if`, `case`, `while` e `try/except`. Cada caminho precisa de pelo menos um caso.

### 2. Escolher a técnica
Classifique o alvo e escolha a técnica em [referencias/tecnicas-de-isolamento.md](referencias/tecnicas-de-isolamento.md):

| Tipo de código | Técnica |
|---|---|
| Função/método sem dependências | Teste direto com `[TestCase]` |
| Regra presa no form (OnClick, OnExit) | Testar pelo form: criar sem mostrar, preencher, chamar o evento |
| Depende de dados | `TFDMemTable` com dados fixos, ou banco de teste fixo |
| Saída grande (dataset, relatório, texto) | Golden master com `TGoldenMaster.Verify` |
| Usa `Now`, diálogos ou globais | Costura mínima (pedir aprovação) |

### 3. Montar o projeto de testes (se ainda não existir)
Crie a pasta `Testes\` ao lado do projeto e copie os modelos desta skill:
- `modelos/ProjetoTestes.dpr.modelo` → `Testes\<Projeto>Tests.dpr`
- `modelos/GoldenMaster.pas` → `Testes\GoldenMaster.pas`
- `modelos/TesteCaracterizacao.pas.modelo` → uma unit de teste por alvo, por exemplo `Testes\Test.uFinanceiro.pas`

Substitua os marcadores `{{...}}` dos modelos. Adicione ao `.dpr` de testes as units de
produção necessárias (`uFinanceiro in '..\src\uFinanceiro.pas'`).
O `.dproj` é criado abrindo o `.dpr` no Delphi, ou pelo usuário em File > New > Other > DUnitX.
Os atributos e asserts do DUnitX estão resumidos em [referencias/dunitx-resumo.md](referencias/dunitx-resumo.md).

### 4. Gerar os casos
Para cada caminho anotado no passo 1, crie casos com:
- valores típicos de produção;
- limites: 0, negativos, vazio, `Null`, máximos, arredondamento (`x,005`);
- datas especiais: fim de mês, 29/02, virada de ano;
- strings com acento e `'` (aspas simples).

Nomeie os testes pelo comportamento: `Desconto_ClienteVIP_Acima1000_Retorna10Porcento`.

### 5. Primeira execução e aprovação
1. Compile e rode:
   `powershell -ExecutionPolicy Bypass -File scripts/Run-Tests.ps1 -Projeto Testes\<Projeto>Tests.dproj`
2. Para testes com valor esperado: rode primeiro com um valor qualquer, leia o valor real
   na mensagem de falha e use ele como esperado. É assim que se caracteriza.
3. Para golden master: a primeira execução falha de propósito e cria arquivos
   `approved\*.received.txt`. Mostre o conteúdo ao usuário. Depois que ele aprovar, rode
   `powershell -ExecutionPolicy Bypass -File scripts/Approve-GoldenMaster.ps1 -Pasta Testes\approved`
4. Rode de novo: tudo precisa passar.

### 6. Testar os testes (obrigatório)
Prove que a rede de segurança funciona: faça **temporariamente** uma mudança pequena no
código de produção (trocar `>` por `>=`, mudar uma constante, remover uma linha), rode os
testes e confirme que pelo menos um falha. Desfaça a mudança com `git checkout -- <arquivo>`.
Se nenhum teste falhar, faltam casos: volte ao passo 4.

### 7. Teste de carga de forms (antes de qualquer migração de acesso a dados)
Erros de DFM (propriedade que não existe mais, classe trocada) só aparecem em tempo de
execução. Gere um teste que cria e libera cada form e DataModule do projeto, conforme o
modelo `modelos/TesteFormsCarregam.pas.modelo`. As skills de migração para FireDAC usam esse teste.

## Entrega
Termine com:
1. Tabela: alvo | nº de testes | técnica | caminhos cobertos.
2. Lista de `COMPORTAMENTO SUSPEITO` encontrados.
3. Costuras aplicadas no código de produção (arquivo, linha, motivo).
4. Resultado do passo 6: qual mudança foi feita e qual teste falhou.
5. Sugestão de commit: `test: caracterização de <alvo>`.
