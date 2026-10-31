# Política de correção

O objetivo é o código ficar **correto**, não o compilador ficar **quieto**.

## Proibido sem autorização explícita do usuário
- `{$WARNINGS OFF}`, `{$HINTS OFF}`, `{$WARN <nome> OFF}` ou mudar as opções de warnings no `.dproj`.
- Cast só para calar o compilador (`string(X)`, `Integer(P)`, `AnsiString(S)`) sem entender a conversão.
- Comentar ou apagar código que gera erro.
- Mudar regra de negócio, ordem de execução, tratamento de exceção ou valor de constante.
- Editar fontes de componentes de terceiros ou da RTL/VCL.
- Trocar tipo de campo persistente (`TStringField` ↔ `TWideStringField`) sem confirmar com o usuário: isso muda o DFM e o banco.

## Permitido
- Ajustar `uses` (unit renomeada, unit com namespace: `SysUtils` → `System.SysUtils`).
- Ajustar search path / library path quando a unit existe no disco.
- Trocar API obsoleta pela equivalente atual com o mesmo comportamento.
- Inicializar variável quando o caminho sem inicialização é claramente um bug
  (`Result := ''` no início de função). Informe cada caso no relatório: muda comportamento em casos-limite.
- Cast explícito **quando a conversão é intencional e segura**, com um comentário curto do motivo.
- Remover variáveis e atribuições sem uso (hints), confirmando que não há efeito colateral.

## Quando houver dúvida
Explique as duas opções ao usuário, com o risco de cada uma, e espere a decisão.
Um warning que fica documentado é melhor que um bug escondido por um cast.
