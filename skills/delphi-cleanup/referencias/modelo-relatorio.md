# Modelo do relatório final da limpeza

Grave em `_modernizacao\limpeza-relatorio.md` (o `limpeza.md` é o levantamento do script e é
sobrescrito a cada execução) e mostre ao usuário.

```markdown
# Limpeza: relatório

## Escopo
- Projeto: <pasta> · Escopo: projeto todo | parcial (<units>)
- Referências procuradas em: <pasta raiz usada em -Pasta>
- Testes de caracterização antes: aceitou (<o que foi coberto>) | seguiu sem testes
- Limites usados: padrão | <parâmetros alterados>

## Antes × depois
| Item | Antes | Depois |
|---|---|---|
| with | 11 | 0 |
| Create sem try/finally | 8 | 0 |

## Feito
| Código | Item | O que foi feito | Commit |
|---|---|---|---|
| M1 | with | 11 with expandidos em 4 units | abc1234 |

## Não feito, por decisão do usuário
| Código | Item | Quantidade | Motivo informado |
|---|---|---|---|
| A2 | except vazio | 3 | quer revisar com o time |

## Não removido: escopo parcial
| Item | Onde | Por quê |
|---|---|---|
| Método possivelmente sem uso | uPedidos.pas:120 TfrmPedido.Recalcular | published; pode ser ligado em DFM de outro projeto |

## Riscos apontados (não corrigidos)
| Código | Risco | Onde | Recomendação |
|---|---|---|---|
| A1 | Método crítico | uPedidos.pas:300 Gravar: 240 linhas, complexidade 37 | testes de caracterização, depois delphi-safe-refactoring |

## Falsos positivos
- uX.pas:10: "Create sem try/finally" era liberado no destrutor (campo da classe).
```

Regras:
- todo item do levantamento aparece em uma das seções: feito, não feito (decisão do usuário),
  não removido (escopo parcial), risco apontado ou falso positivo;
- o motivo de "não feito" é o que o usuário disse; se ele não disse, escreva "sem motivo informado";
- não escreva "feito" sem o commit correspondente.
