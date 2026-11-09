# Armadilhas conhecidas

Coisas que deram errado de verdade ao aplicar este visual (num sistema real em produção) e como evitar.

| Sintoma | Causa | Solução |
|---|---|---|
| Campo de busca branco, marca d'água preta, fundo claro na lista do menu | Estilo VCL ativo ignora `Color`/`Font.Color` | `StyleElements := []` (as units já fazem); nos DFMs: `scripts/sem-estilo-dfm.pl` |
| Janela pequena, sem botão de maximizar, menu apertado | `BorderStyle = bsSingle` + `BorderIcons` sem `biMaximize` faz o Windows ignorar `wsMaximized` | `scripts/sem-estilo-dfm.pl --redimensionavel` |
| Menu com itens que o usuário não deveria ver | `AtualizarPermissoes` chamado antes da rotina de permissão | Chamar logo depois dela (e de novo onde ela rodar de novo) |
| Grupo que abre vazio ou item que não faz nada | Grupo só com separador e Sair | O componente já esconde; confira se o Sair foi para `AIgnorar` e `DefinirSair` |
| Login aceita "maria" mas o menu vem sem permissões | Usuário salvo como digitado, permissões gravadas com outra caixa | Global recebe o login como está no cadastro (`FieldByName(...)`) |
| Ninguém com senha minúscula entra | `CharCase = ecUpperCase` no campo de senha | Só no campo do usuário (`AUsuarioMaiusculo`) |
| W1057/W1058 em toda linha que usa o usuário | Global `string[n]` (ShortString) | Trocar por `string` e cortar no login com `Copy(..., 1, n)`; se não puder, converter explícito |
| Acentos viram "Ã©" num `.pas` antigo | Texto UTF-8 colado em arquivo cp1252 | Editar cópia UTF-8 e converter com `iconv -f utf-8 -t cp1252`; conferir com `file` |
| Linhas com LF misturadas a CRLF | Inserção por script sem respeitar o final de linha | `scripts/edita-linhas.pl` preserva; normalizar com Perl se acontecer |
| Testes "forms carregam" quebram ou não incluem a tela nova | Projeto de testes gerado do `.dpr` | Regenerar o projeto de testes depois de mexer no `.dpr` |
| Commit de correções levou junto arquivos apagados de outro assunto | `git rm` deixa a remoção no índice; o próximo `git commit` leva | Commitar com caminhos explícitos (`git commit -- arquivos`) ou conferir `git diff --cached` |
| Esc no form principal pergunta "Sair?" enquanto o usuário só queria limpar a busca | `KeyPreview` entrega o Esc ao form antes do campo | `if FMenuLateral.LimparBusca then begin Key := #0; Exit; end;` no começo do `#27` |
| Componentes de terceiros ou relatórios estranhos com estilo VCL | Estilo é global | Testar as telas principais; se algo ficar ruim, `StyleElements` no controle ou não aplicar o estilo |
| Rebuild falha com "acesso negado" ao .exe | O sistema está aberto (às vezes pelo próprio teste visual) | Fechar a instância antes de compilar |
| Ícones do menu lateral saem como quadradinhos/pontos (texto normal) | Versão antiga do `UnMenuLateral` fazia `FFonteIcones := FonteIcones` dentro da classe: lia a própria propriedade vazia | Usar `UnTema.FonteIcones` (corrigido em 09/11/2026); se copiou a unit antes disso, atualize |
| Testes de caracterização/golden master quebram ao trocar mensagens | O fechador de diálogos do teste procura o label `Message` do `MessageDlg`; a caixa do `UnDialogo` não tem | Ensinar o fechador a achar os `TBotaoModerno` (ficam no painel de rodapé, não direto no form: buscar por `Controls` recursivo) e o `TLabel` com `WordWrap`; os aprovados mudam só no título da caixa |
| `ShowMessage` "sobra" depois da troca | Pascal não diferencia maiúsculas: `showmessage`/`messagedlg` escapam de grep sensível a caixa | Buscar com `grep -i` e trocar ignorando caixa |
