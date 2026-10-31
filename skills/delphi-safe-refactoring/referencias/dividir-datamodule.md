# Dividindo o DataModule gigante

Sintomas: um `dmPrincipal` com 80, 150, 300 datasets; aberto no início do sistema; usado por
todas as telas; com regras de negócio nos eventos `BeforePost`, `AfterScroll`, `OnCalcFields`.

## Por que dói
- Abrir o sistema cria (e às vezes abre) todos os datasets.
- Qualquer mudança no DM afeta todas as telas e gera conflito no Git.
- Impossível testar uma regra sem criar o DM inteiro, com banco.
- O `.dfm` gigante custa muitos tokens para a IA ler.

## Pré-condições
- Teste de carga de forms (skill `delphi-characterization-tests`) passando.
- Testes de caracterização das regras que estão nos eventos do DM.

## Roteiro
### 1. Mapear
Para cada dataset do DM, liste: quem usa (busque `dmPrincipal.qryX` em todas as units e
`DataSet = dmPrincipal.qryX` nos DFMs), se tem eventos com regra, de quais outros datasets
depende (master-detail, lookups). Agrupe por assunto: clientes, produtos, pedidos, fiscal.

### 2. Escolher o primeiro grupo
O grupo com **menos dependências** e **menos telas** usando. Nunca o mais central primeiro.

### 3. Criar o DM novo
1. Novo DataModule `dmClientes` com a mesma conexão (referência ao componente de conexão
   do DM principal, ou conexão compartilhada).
2. Recorte os datasets do grupo do `dmPrincipal` e cole no `dmClientes` pelo IDE (os campos
   persistentes e as propriedades vêm junto; os eventos precisam ser movidos no `.pas`).
3. Mova os handlers de eventos para o `.pas` do novo DM.

### 4. Ajustar os usuários
1. Troque `dmPrincipal.qryClientes` por `dmClientes.qryClientes` nas units (busca e troca
   revisada, unit por unit).
2. Troque `DataSet = dmPrincipal.qryClientes` por `DataSet = dmClientes.qryClientes` nos DFMs.
3. Garanta que `dmClientes` é criado antes de quem usa (`.dpr` ou criação sob demanda).

### 5. Validar
Compile, rode o teste de carga de forms e os testes de caracterização. Commit:
`refactor: move datasets de clientes para dmClientes`.

### 6. Repetir
Um grupo por vez. A cada grupo, o `dmPrincipal` encolhe. O objetivo final é que ele tenha só a
conexão e o que for realmente global.

## Depois (opcional, decisão separada)
- Criar os DMs sob demanda (cada tela cria o seu) em vez de todos no início.
- Colocar uma fachada na frente de cada DM (veja o catálogo, item 8) para tirar das telas o
  acesso direto aos datasets.
