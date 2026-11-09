# Temas, cores e identidade

## Paletas prontas

| Função | Faixa lateral (menu, login, Sobre) | Conteúdo | Estilo VCL sugerido |
|---|---|---|---|
| `TemaPadrao` | escura `#111827`, texto claro | claro `#F3F4F6`, cartões brancos | `Windows Modern` |
| `TemaClaro` | branca, texto `#374151` | claro | `Windows Modern` |
| `TemaEscuro` | quase preta `#020617` | escuro `#0F172A`, cartões `#1E293B` | `Windows Modern Dark` |

`TemaPadrao` é o visual de referência (o que foi aprovado no sistema de origem). Use os outros quando o
usuário pedir, ou se o sistema roda em ambiente onde o escuro ou o claro faz mais sentido (recepção
clara, painel de operação escuro).

## Cor de destaque
Botão principal, item ativo do menu, foco dos campos, link:

```pascal
DefinirTema(ComDestaque(TemaPadrao, cdVerde));
```

| `TCorDestaque` | Cor | Combina com |
|---|---|---|
| `cdAzul` (padrão) | #2563EB | qualquer coisa; neutro, corporativo |
| `cdVerde` | #16A34A | saúde, financeiro, agro |
| `cdRoxo` | #7C3AED | educação, tecnologia |
| `cdLaranja` | #EA580C | varejo, alimentação |
| `cdVermelho` | #DC2626 | só se for a cor da marca (confunde com erro) |
| `cdCiano` | #0891B2 | clínicas, laboratórios |
| `cdRosa` | #DB2777 | estética, moda |
| `cdGrafite` | #475569 | sóbrio, jurídico |

Cor da marca do cliente: `ComDestaqueRGB(TemaPadrao, RGB(0, 120, 90), RGB(0, 95, 70))` (cor e uma
versão ~15% mais escura para o hover). Texto em cima do destaque é branco: evite marcas muito claras
(amarelo, verde-limão); nesses casos use a cor da marca só no logo e mantenha o destaque azul.

## Ajuste fino
`TTema` é um record: copie um pronto e mude campos (`LTema := TemaPadrao; LTema.MenuFundo :=
RGB(...); DefinirTema(LTema);`). Os campos estão comentados em `UnTema.pas`.

## Identidade

```pascal
DefinirIdentidade('CLÍNICA EXEMPLO', 'Sua Empresa', 'contato@suaempresa.com.br');
```

Organização aparece embaixo do nome do sistema (menu, login, Sobre); desenvolvedor e contato no
Sobre. Padrão: tudo vazio (o Sobre mostra "—" no desenvolvedor e esconde o contato). Sempre
chame `DefinirIdentidade` com os dados de quem desenvolve o sistema; pergunte se não souber.

## Trocar o tema com o sistema aberto
Chame `DefinirTema(...)` e depois `FMenuLateral.AplicarTema` (recolore o menu); telas abertas depois
já nascem no tema novo (Login, Sobre, diálogos e cadastros leem o tema ao abrir). Para guardar a
escolha do usuário final, grave o nome/cor num .ini ou no banco e chame `DefinirTema` no `.dpr`.
O estilo VCL também pode ser trocado em tempo de execução (`AplicarEstiloVCL('Windows Modern Dark')`),
desde que esteja incluído no projeto.
