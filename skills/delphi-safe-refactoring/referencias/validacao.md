# Validação da transformação

## 1. Codificação dos arquivos
Ferramentas de edição de IA gravam UTF-8 sem BOM com quebra de linha LF. Projetos Delphi
legados costumam usar ANSI (cp1252) com CRLF; se o `.pas` original não tinha BOM, um arquivo
UTF-8 sem BOM é lido como ANSI pelo compilador e os acentos viram lixo.

**Antes** de editar, anote a codificação do `.pas` legado. **Depois** da última edição de cada arquivo:
```
powershell -ExecutionPolicy Bypass -File scripts/Normalize-Encoding.ps1 -Encoding Ansi -Arquivos "C:\proj\src\Models\Models.Produtos.pas,C:\proj\src\Views\frmProdutos.pas,C:\proj\src\Views\frmProdutos.dfm"
```
- `-Encoding Ansi` (sem BOM no legado) ou `-Encoding Utf8Bom` (legado com BOM).
- Arquivos `.dproj` são UTF-8 com BOM: o script mantém.
- Para editar de novo um arquivo já em ANSI: converta com `-Encoding Utf8Bom`, edite e volte para `Ansi`.
- Texto acentuado em `.dfm`: use escape (`'Pre'#231'o'`). O script avisa quando encontra caractere não ASCII num `.dfm`.

## 2. Os .dfm abrem?
Erro de sintaxe em `.dfm` só aparece ao abrir o form. O script testa cada `.dfm` numa cópia
temporária com o `convert.exe` do RAD Studio:
```
powershell -ExecutionPolicy Bypass -File scripts/Test-Dfm.ps1 -Arquivos "C:\proj\src\Views\frmProdutos.dfm"
```

## 3. Compilar
Use a skill `delphi-compile-loop` (ou o `Build-Delphi.ps1` dela). Erros comuns desta transformação:
| Erro | Causa provável |
|---|---|
| `Undeclared identifier: 'TFDMemTable'` | faltam as units FireDAC no `uses` do form |
| `Undeclared identifier: 'DataModule2'` | sobrou referência ao DataModule no form |
| Erro ao abrir o form: `Class TDBEdit not found` / `Property DataField does not exist` | `.dfm` e `.pas` divergentes (classe trocada só num deles) |
| `Object factory for class ... missing` | falta a unit de espera do FireDAC no `.dpr` |

Registre as units novas no `.dpr` (`uses ... in '...'`) e no `.dproj` (`DCCReference`).

## 4. Sobras do legado
Procure no form transformado; nada disto pode sobrar:
- `TDB` (exceto `TDBGrid`), `DataField`, `ValueChecked`;
- o nome do DataModule e das queries antigas;
- SQL na unit do form.
Procure também no projeto inteiro pelo DataModule: se outras telas ainda usam, ele fica.

## 5. Testes
1. **Testes de caracterização** feitos antes (skill `delphi-characterization-tests`) continuam passando.
2. **Teste do Controller** (DUnitX) contra uma **cópia** do banco: `Carregar`, `Inserir` (confere o id),
   `BuscarPorId`, `Alterar`, cada regra de `ValidarPreenchimento` (espera `EValidacao<Assunto>`),
   `Excluir`, `BuscarPorId` devolvendo `nil`. Para banco em servidor, pergunte antes: o teste grava dados.
3. **Endpoints**: `scripts/Test-Endpoints.ps1` (veja [endpoints-horse.md](endpoints-horse.md)).
4. **Roteiro manual da tela** para o usuário: navegar no grid, incluir, alterar, cancelar, excluir,
   disparar uma validação. O comportamento tem que ser igual ao do legado.
