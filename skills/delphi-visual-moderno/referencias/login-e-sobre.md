# Login e Sobre

## Login: visual comum, regra de cada sistema

`UnLogin` tem a tela (`Tf_Login`) e a interface:

```pascal
TResultadoLogin = (rlEntrou, rlCorrigirUsuario, rlCorrigirSenha, rlEncerrar, rlPermanecer);
IAutenticacaoLogin = interface
  function Autenticar(const AUsuario, ASenha: string): TResultadoLogin;
end;
function ExecutarLogin(AAutenticacao; ASistema; AIcone = ''; ARotuloUsuario = 'Usuário';
  AUsuarioMaiusculo = False): Boolean;
```

O retorno diz à tela o que fazer, no lugar do que o form antigo fazia com os próprios controles:

| Login antigo | Retorno |
|---|---|
| `ShowMessage(...)`; `d_operador.SetFocus; Exit` | `ShowMessage(...)`; `Exit(rlCorrigirUsuario)` |
| `ShowMessage(...)`; `d_senha.Text := ''; d_senha.SetFocus; Exit` | `Exit(rlCorrigirSenha)` (a tela limpa a senha) |
| `ShowMessage(...)`; `Close; Exit` (ex.: usuário inativo) | `Exit(rlEncerrar)` |
| `Exit` sem mexer em nada (ex.: área não escolhida) | `Exit(rlPermanecer)` |
| preenche globais; `d_flag.Text := 'S'` / `Tag := 1` / `ModalResult := mrOk`; `Close` | preenche globais; `Result := rlEntrou` |

### Como portar o login de um sistema
1. Leia o login antigo inteiro (o `OnClick` do Confirma/OK, o `FormShow`, funções auxiliares) e
   **quem chama** (como o principal confere o sucesso e o que faz na desistência).
2. Reescreva a unit do login como uma classe `TInterfacedObject, IAutenticacaoLogin`:
   - mesmas mensagens, mesmo texto, mesma ordem de checagem;
   - query criada no método (`try/finally`) com a mesma conexão: `DatabaseName` (BDE), `Connection`
     (FireDAC/ADO), copiada do DFM antigo;
   - as mesmas globais preenchidas, com o mesmo corte de tamanho (`Copy(..., 1, 10)` se a global
     era `string[10]`; se ainda for ShortString, `ShortString(...)` explícito);
   - funções auxiliares (escolha de filial/área etc.) viram métodos privados da classe, sem mudar.
3. Exponha `function FazerLogin: Boolean;` na mesma unit:
   `Result := ExecutarLogin(TLoginSistema.Create, 'Vendas', C_ICONE_CARRINHO, 'Operador');`
4. No principal, troque o bloco `CreateForm/ShowModal/confere flag/Free` por `if not FazerLogin
   then <exatamente o que o sistema fazia na desistência>`. Alguns encerram (`Close;
   Application.Terminate; Exit`), outros só fecham (`Close`): preserve.
5. O form antigo sai: apague o `.dfm`, tire o `{f_Operador}` do `.dpr` e o `<Form>` do `.dproj`
   (a unit continua, sem form). Inclua `UnLogin` com `{f_Login}`.
6. Procure outros lugares que abriam o form antigo (`grep Tf_Operador`), inclusive código comentado.

### Melhorias que mudam comportamento (só com o usuário sabendo)
- **SQL com parâmetro** no lugar de concatenar o texto digitado: mesmo resultado para entradas
  normais e fecha injeção de SQL. Recomendado; avise.
- **Usuário sem diferenciar maiúsculas** (`upper(campo) = :param` + `UpperCase`): se fizer, a global
  do usuário deve receber o valor **como está no cadastro** (`Trim(FieldByName('login').AsString)`),
  senão as consultas de permissão que comparam com o usuário deixam de casar.
- `AUsuarioMaiusculo = True` só converte o que se digita no campo do usuário. **Nunca** converta a
  senha (`CharCase` no campo de senha): quem tem senha com minúscula deixa de entrar.

## Sobre

`ExibirSobre('Vendas', 'Controle de pedidos e estoque', C_ICONE_CARRINHO);`

- Data de compilação lida do cabeçalho do próprio executável (`DataCompilacao`); se o linker não
  gravou data real, usa a data do arquivo.
- Desenvolvedor e contato vêm de `DefinirIdentidade` (padrão: vazios; sem
  desenvolvedor aparece "—"). Sem contato, a linha some. Clicar no e-mail abre o cliente de e-mail.
- Substitui o Sobre antigo do sistema: troque o corpo do `Sobre1Click` por `ExibirSobre(...)`,
  tire o form antigo do `.dpr`/`.dproj` (registre `UnSobre` com `{f_sobre}`) e apague-o. Se outra
  tela mexia nos campos do Sobre antigo (título de aba, label), passe esse texto como descrição.
