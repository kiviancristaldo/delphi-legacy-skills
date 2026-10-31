# Adaptando as skills ao seu projeto

As skills deste kit são um ponto de partida. Elas ficam muito melhores com o conhecimento
específico do seu sistema.

## 1. Comece pelo que você já repete
Todo checklist de migração, documento de padrão, ou aquela explicação que você sempre dá
para quem chega no time, é uma skill em potencial.

## 2. Troque só o específico
Exemplos do que vale personalizar:
- `delphi-coding-standards`: preencha a seção "Específico do projeto" (units base, ancestrais
  de form, função de arredondamento, padrão de log).
- `bde/ado/dbx-to-firedac`: acrescente ao `modelos/regras-do-projeto.txt` as suas classes
  herdadas e componentes de terceiros.
- `delphi-legacy-modernizer`: ajuste os limites do diagnóstico (`-LimiteLinhasUnit`,
  `-LimiteLinhasMetodo`) e a lista de riscos típicos.
- `acbr-upgrade`: inclua os documentos fiscais e cenários de homologação que vocês usam.

## 3. Escreva a descrição com as palavras do time
Se todo mundo fala "tirar o BDE", essa frase precisa estar na `description`. Se a IA não
aciona a skill na hora certa, quase sempre o problema é a descrição.

## 4. Teste numa conversa nova
Faça o mesmo pedido com e sem a skill e compare. Confira se ela é acionada e se o resultado
segue o processo.

## 5. Evolua com os erros
Cada vez que a IA errar algo específico do seu sistema, acrescente uma linha nas regras ou
nas referências da skill. Ela melhora a cada uso.

## Versionando no projeto
Coloque as skills em `.claude/skills/` dentro do repositório do sistema: elas passam a ser
revisadas em pull request e todo o time usa a mesma versão.
