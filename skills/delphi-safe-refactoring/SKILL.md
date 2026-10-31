---
name: delphi-safe-refactoring
description: Refatora código Delphi legado com segurança, um passo pequeno por vez, sempre com testes e compilação entre os passos - tira regra de negócio de eventos de tela (OnClick/OnExit), quebra métodos e units gigantes, divide DataModules enormes, elimina código duplicado, reduz acoplamento e variáveis globais, troca SQL concatenado por parâmetros. Use quando o usuário pedir para refatorar, desacoplar, aplicar SOLID/responsabilidade única, separar a regra da tela, dividir um DataModule ou unit, ou remover duplicação.
---

# Refatoração segura em Delphi

Refatorar é **mudar a estrutura sem mudar o comportamento**. A segurança vem de três regras:
1. **Testes antes**: o trecho precisa estar coberto por testes de caracterização.
2. **Passos pequenos**: cada passo é mecânico, compila e passa nos testes antes do próximo.
3. **Um objetivo por commit**: refatoração nunca vem misturada com correção de bug ou funcionalidade nova.

Arquivos desta skill (caminhos relativos à pasta da skill):
- `referencias/catalogo-de-refatoracoes.md`: as refatorações com exemplos antes/depois em Delphi
- `referencias/dividir-datamodule.md`: roteiro para quebrar um DataModule gigante

## Pré-condições (verifique e PARE se faltar)
1. Projeto no Git, tudo commitado, compilando.
2. Testes de caracterização cobrindo o alvo, passando. Se não existirem, use antes a skill
   `delphi-characterization-tests` e volte.
3. Alvo definido. Se o usuário não sabe por onde começar, use o diagnóstico da skill
   `delphi-legacy-modernizer` e sugira os 3 alvos com melhor relação dor/risco.

## Processo

### 1. Planejar a sequência
Leia o alvo **por partes** (units grandes custam muitos tokens: localize o método e leia só
o intervalo). Escolha as refatorações no [catálogo](referencias/catalogo-de-refatoracoes.md) e
escreva a sequência de passos para o usuário **antes de começar**. Exemplo:
1. Extrair o cálculo do `btnCalcularClick` para `CalcularTotalPedido` no próprio form.
2. Mover `CalcularTotalPedido` para a nova unit `uPedidoCalculo` como função com parâmetros.
3. Trocar as leituras de `edtX.Text` por parâmetros.
4. Fazer `frmOrcamento`, que tinha uma cópia do cálculo, chamar a mesma função.

### 2. Executar passo a passo
Para cada passo:
1. Faça só aquele passo.
2. Compile (skill `delphi-compile-loop`).
3. Rode os testes (skill `delphi-characterization-tests`, script `Run-Tests.ps1`).
4. Verde → commit (`refactor: extrai cálculo do pedido para uPedidoCalculo`). Vermelho → desfaça
   o passo (`git checkout -- .`) e divida em passos menores. **Nunca "conserte" o teste.**

### 3. Encontrou um bug no caminho?
Não corrija durante a refatoração. Anote, termine o passo e mostre ao usuário. A correção é um
commit separado, com um teste que mostra o bug antes e o conserto depois.

### 4. Medir
Rode o diagnóstico (`delphi-legacy-modernizer`) com `-Comparar` e mostre a evolução:
linhas do método, tamanho da unit, duplicação, acoplamento.

## Limites
- Não renomeie componentes e campos do DFM junto com outra refatoração: o DFM e o `.pas`
  precisam mudar juntos, e é fácil quebrar eventos ligados.
- Não troque herança de forms (visual form inheritance) sem teste de carga de forms.
- Não introduza frameworks (DI container, ORM, MVVM) durante uma refatoração de resgate.
  Primeiro deixe o código testável; arquitetura nova é decisão separada.
- Interfaces só quando houver uma necessidade concreta (duas implementações, ou teste que precise de dublê).

## Entrega
1. Sequência de passos executada, com o commit de cada um.
2. Métricas antes × depois.
3. Bugs encontrados (não corrigidos) com a sugestão de teste para cada um.
4. Próximo alvo sugerido.
