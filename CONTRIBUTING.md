# Contribuindo

Contribuições são bem-vindas: novas skills, correções, exemplos e relatos de uso em projetos reais.

## Relatando problemas
Abra uma *issue* com:
- a skill e o script usados;
- a versão do Delphi e do Windows;
- a saída do console (sem senhas, caminhos de clientes ou código proprietário).

## Criando ou alterando uma skill
1. Cada skill fica em `skills/<nome-da-skill>/` com um `SKILL.md`.
2. O frontmatter tem só `name` (igual ao nome da pasta, minúsculas e hífen) e `description`
   (o que faz + quando usar, até 1024 caracteres).
3. O `SKILL.md` fica abaixo de ~500 linhas; detalhes vão para `referencias/`.
4. Scripts:
   - PowerShell 5.1 compatível, salvos em UTF-8 **com BOM** (sem o BOM, o Windows PowerShell
     lê os acentos errado);
   - não alteram o projeto, a não ser que esse seja o objetivo declarado (e aí exigem Git limpo);
   - geram relatório em `_modernizacao\` ou `_migracao\`.
5. Nada de inventar API: nomes de classes, propriedades e funções precisam existir na versão
   citada (Delphi, FireDAC, ACBr).
6. Atualize a tabela do `README.md` e o `CHANGELOG.md`.

## Validação
O GitHub Actions valida o frontmatter de todas as skills a cada push. Para validar localmente:
```bash
python3 .github/scripts/validar_skills.py
```
