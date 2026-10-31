# Checklist da migração Firebird → PostgreSQL / SQL Server

## Antes
- [ ] Versão do Firebird e **dialeto** do banco (1 ou 3)
- [ ] Banco e versão de destino definidos
- [ ] Charset do banco Firebird (NONE, WIN1252, ISO8859_1, UTF8) e collation
- [ ] Sistema já em FireDAC (senão, migrar o acesso primeiro, ainda no Firebird)
- [ ] Testes de caracterização passando contra o Firebird
- [ ] DDL completo extraído e versionado
- [ ] Inventário do código (`Find-SqlFirebird.ps1`)

## Itens de maior risco (tratar primeiro)
- [ ] UDFs (`DECLARE EXTERNAL FUNCTION`): não existem no destino
- [ ] `EXECUTE BLOCK` no código Delphi
- [ ] Triggers com `INSERTING/UPDATING/DELETING`, `POSITION` ou lógica pesada (SQL Server: sem BEFORE, por comando)
- [ ] Procedures selecionáveis (`SUSPEND`)
- [ ] SQL com datas/números concatenados
- [ ] Busca sem diferenciar maiúsculas/acentos (`CONTAINING`, collation PT_BR)
- [ ] Datas fora do intervalo do destino (SQL Server `DATETIME` < 1753)
- [ ] Teste de mensagens de erro por texto

## Banco
- [ ] Domínios
- [ ] Tabelas (tipos convertidos pela tabela de equivalências)
- [ ] Generators → sequences / identity (decidir por tabela)
- [ ] Chaves primárias, únicas e estrangeiras
- [ ] Índices (incluindo descendentes e de expressão)
- [ ] Views
- [ ] Procedures (executáveis e selecionáveis)
- [ ] Triggers (sem as de autoincremento, se virou identity)
- [ ] Exceptions → mensagens em `RAISE`/`THROW`
- [ ] Permissões (`GRANT`) e usuários/roles

## Dados
- [ ] Ferramenta de cópia escolhida: `TFDBatchMove` (Delphi, FireDAC → FireDAC), ferramenta de ETL, ou scripts
- [ ] Conversão de charset na carga (WIN1252 → UTF8)
- [ ] Ordem de carga respeitando as FKs (ou FKs desligadas durante a carga)
- [ ] Sequences/identity ressincronizadas com o `MAX(id)` de cada tabela
- [ ] Contagem de linhas por tabela: origem = destino
- [ ] Soma das colunas de valor por tabela: origem = destino
- [ ] Amostra de textos com acento e de BLOBs conferida

## Código Delphi
- [ ] Conexão (DriverID, Params, `.ini`) e driver na instalação
- [ ] Construções do `Find-SqlFirebird.ps1` convertidas
- [ ] Teste de tipos de campo (`FieldDefs`) sem diferenças, ou `MapRules` aplicadas
- [ ] Leitura de generators centralizada
- [ ] Datas concatenadas → parâmetros
- [ ] Mensagens de erro → `E.Kind`
- [ ] Teste de carga de forms
- [ ] Testes de caracterização passando contra o banco novo

## Depois
- [ ] Plano de volta (o Firebird fica intacto até a validação)
- [ ] Rotina de backup do banco novo
- [ ] Desempenho das consultas mais pesadas (planos de execução mudam)
