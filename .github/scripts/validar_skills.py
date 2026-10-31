"""Valida as skills do repositório: frontmatter, nome da pasta, tamanho e links internos."""
import os
import re
import sys

RAIZ = os.path.join(os.path.dirname(__file__), '..', '..')
PASTA = os.path.join(RAIZ, 'skills')
erros = []

for nome in sorted(os.listdir(PASTA)):
    pasta = os.path.join(PASTA, nome)
    if not os.path.isdir(pasta):
        continue
    arq = os.path.join(pasta, 'SKILL.md')
    if not os.path.isfile(arq):
        erros.append(f'{nome}: falta SKILL.md')
        continue
    texto = open(arq, encoding='utf-8').read()
    m = re.match(r'---\n(.*?)\n---\n', texto, re.S)
    if not m:
        erros.append(f'{nome}: frontmatter ausente ou mal formado')
        continue
    campos = dict(re.findall(r'^(\w[\w-]*):\s*(.+)$', m.group(1), re.M))
    if campos.get('name') != nome:
        erros.append(f'{nome}: name ({campos.get("name")}) diferente do nome da pasta')
    if not re.fullmatch(r'[a-z0-9]+(-[a-z0-9]+)*', nome) or len(nome) > 64:
        erros.append(f'{nome}: nome deve ter minúsculas, números e hífen (até 64)')
    desc = campos.get('description', '')
    if not desc:
        erros.append(f'{nome}: description vazia')
    elif len(desc) > 1024:
        erros.append(f'{nome}: description com {len(desc)} caracteres (máx. 1024)')
    if len(texto.splitlines()) > 500:
        erros.append(f'{nome}: SKILL.md com mais de 500 linhas')
    for raiz, _, arquivos in os.walk(pasta):
        for a in arquivos:
            if a.endswith('.md'):
                caminho = os.path.join(raiz, a)
                for link in re.findall(r'\]\(([^)#]+)\)', open(caminho, encoding='utf-8').read()):
                    if not link.startswith('http') and not os.path.exists(os.path.join(raiz, link)):
                        erros.append(f'{os.path.relpath(caminho, RAIZ)}: link quebrado {link}')
            if a.endswith('.ps1'):
                if not open(os.path.join(raiz, a), 'rb').read(3) == b'\xef\xbb\xbf':
                    erros.append(f'{os.path.relpath(os.path.join(raiz, a), RAIZ)}: .ps1 sem BOM UTF-8')

if erros:
    print('\n'.join(erros))
    sys.exit(1)
print(f'OK: {len([d for d in os.listdir(PASTA) if os.path.isdir(os.path.join(PASTA, d))])} skills válidas')
