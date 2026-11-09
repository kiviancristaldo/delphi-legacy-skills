# Mensagens e confirmações

`UnDialogo` monta a caixa em código (sem DFM): círculo colorido com o ícone do tipo, título, texto
com quebra de linha automática e botões modernos num rodapé. Enter aciona o botão principal, Esc o
de cancelar, e o foco já começa no principal.

```pascal
Informar('Cadastro gravado.');
InformarSucesso('Pedido 1234 faturado.');
Avisar('Preencha o CPF.');
MostrarErro('Não foi possível gravar: ' + E.Message);
if Confirmar('Excluir o cliente ' + LNome + '?', 'Excluir', 'Excluir', 'Cancelar', True) then ...
LOpcao := ExibirDialogo(tdPergunta, 'Salvar alterações?', 'O pedido foi alterado.',
  ['Cancelar', 'Descartar', 'Salvar']);   // devolve 0, 1, 2 ou -1 (fechou no X)
```

## Trocando as chamadas antigas

| Antigo | Novo |
|---|---|
| `ShowMessage(T)` | `Informar(T)` |
| `MessageDlg(T, mtInformation, [mbOK], 0)` | `Informar(T)` |
| `MessageDlg(T, mtWarning, [mbOK], 0)` | `Avisar(T)` |
| `MessageDlg(T, mtError, [mbOK], 0)` | `MostrarErro(T)` |
| `MessageDlg(T, mtConfirmation, [mbYes, mbNo], 0) = mrYes` | `Confirmar(T)` |
| `MessageDlg(...) <> mrYes` / `= mrNo` | `not Confirmar(T)` |
| `Application.MessageBox(PChar(T), PChar(Titulo), MB_YESNO) = IDYES` | `Confirmar(T, Titulo)` |
| `MessageDlg(T, mtConfirmation, [mbYes, mbNo, mbCancel], 0)` | `ExibirDialogo(tdPergunta, ..., ['Cancelar', 'Não', 'Sim'])`: 2 = Sim, 1 = Não, 0/-1 = Cancelar |
| caixa própria do sistema (ex.: `TConfirmacaoSim.Execute`) | `Confirmar` só se o usuário pedir; leia a classe antes |

Cuidados:
- `Confirmar` devolve False quando a janela é fechada no X ou com Esc, como o "Não": o mesmo
  resultado do `MessageDlg` com `[mbYes, mbNo]`.
- Mantenha o texto da mensagem igual (só troque a função). Títulos novos são bem-vindos.
- Testes automatizados que respondem diálogos procurando a janela padrão do Windows
  (`TMessageForm`, classe `#32770`) deixam de achar a caixa nova. Antes de trocar em massa, procure
  esse tipo de teste no projeto e avise o usuário.
- Mensagens dentro de laços longos ou de threads: não troque (a caixa é modal e da thread principal).
- Troque por tela/assunto, compilando a cada lote; `grep -n "ShowMessage\|MessageDlg"` dá a lista.
