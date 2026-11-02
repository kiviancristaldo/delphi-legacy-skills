# Regras de limpeza

Baseadas nas etapas "Limpe" e "Organize" da palestra *O impacto e o poder dos softwares
legados na era da IA e porque inovar hoje!* (Kivian Emerim, Dia do ACBr).

## 0. Use o Git
Antes de qualquer coisa. Código comentado "para não perder" só existe porque não há Git.

## 1. Não permita vazamentos de memória (risco baixo)
Ligue o relatório de vazamentos só em Debug, no `.dpr`:
```pascal
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}
  Application.Initialize;
```
Todo objeto local criado e liberado no mesmo método fica protegido:
```pascal
// antes
L := TStringList.Create;
L.Add('x');
Processar(L);
L.Free;

// depois
L := TStringList.Create;
try
  L.Add('x');
  Processar(L);
finally
  L.Free;
end;
```
O `try` vem **logo depois** do `Create`, nunca antes (se o `Create` falhar, não há o que liberar).
Vários objetos: um `try/finally` por objeto, ou crie todos como `nil` antes e libere todos no `finally`.

## 2. Não faça funções que devolvem objetos criados (risco médio)
Quem cria é quem libera. Uma função que devolve `TStringList.Create` empurra a liberação para
quem chama, e alguém vai esquecer. Prefira receber o objeto já criado:
```pascal
// antes
function ListarClientes: TStringList;   // quem libera?

// depois
procedure ListarClientes(ALista: TStrings);   // quem chama cria e libera
```
Mude a assinatura e **todos** os chamadores no mesmo commit, com compilação e testes.
Exceção legítima: fábricas (`TFabrica.Criar...`) com nome claro e documentação de quem libera.

## 3. Não permita warnings e hints (risco baixo a médio)
Eles escondem os avisos que importam (por exemplo, função sem retorno). Use a skill
`delphi-compile-loop`, com a meta "zerar warnings e hints".

## 4. Não deixe exceptions vazias (risco ALTO para corrigir)
`except end;` faz o erro sumir e o dado ficar inconsistente sem ninguém saber.
A correção muda comportamento, então é **decisão do usuário**, caso a caso:
- erro esperado e inofensivo → capture só a classe específica e comente o porquê;
- erro inesperado → registre em log e relance (`raise;`), ou mostre ao usuário.
```pascal
// antes
try
  GravarLog(Msg);
except
end;

// depois (decisão: falha no log não pode parar a venda, mas precisa aparecer)
try
  GravarLog(Msg);
except
  on E: EInOutError do
    OutputDebugString(PChar('Falha ao gravar log: ' + E.Message));
end;
```

## 5. Retire os with (risco médio)
Com `with`, não dá para saber de quem é cada propriedade, e uma propriedade nova numa classe
muda o significado do código em silêncio. Expanda um `with` por vez:
```pascal
// antes
with qryClientes do
begin
  Close;
  ParamByName('ID').AsInteger := Id;
  Open;
  Caption := FieldByName('NOME').AsString;   // Caption de quem? do form!
end;

// depois
qryClientes.Close;
qryClientes.ParamByName('ID').AsInteger := Id;
qryClientes.Open;
Caption := qryClientes.FieldByName('NOME').AsString;
```
Para cada identificador dentro do bloco, decida: é membro do objeto do `with` ou de fora?
Na dúvida, confira a declaração da classe. `with A, B do` é o caso mais perigoso: trate com testes.

## 6. Retire o código que não está sendo usado (risco baixo a médio)
**Em escopo parcial (só algumas units), não remova nada que possa ser usado fora delas**:
métodos, componentes, units, tipos, constantes. O script já marca esses itens como
"Não remover: escopo parcial". Remover só depois de buscar no sistema inteiro e com a
decisão do usuário.

- Código comentado: apague (o Git guarda).
- Métodos sem uso: o script lista candidatos (ignora os ligados em DFM ou atribuídos em código
  a `OnXxx :=`, e os `virtual`/`override`/`dynamic`/`abstract`/`message`). Antes de apagar,
  confirme que não são eventos ligados num DFM herdado ou binário, publicados para RTTI
  (`published`, `MethodAddress`) ou chamados de outro projeto/pacote.
- Componentes de dados sem uso: o script lista datasets e DataSources cujo nome só aparece no
  `.dfm` e na declaração. Confirme que nenhum outro form usa `DM.Componente`, que não há
  `FindComponent` e que nenhum relatório (`.fr3`, `.rav`) usa o dataset.
- Queries e componentes sem uso no DFM: confirme no código (`FieldByName`, `.Open`) antes de remover.
- Units no `uses` sem uso: ferramentas como o CnPack (Uses Cleaner) ou o MMX ajudam. Sem elas,
  remova uma unit, compile e, se der erro, volte.

## 7. Comentários que explicam o óbvio (risco baixo)
`i := i + 1; // soma 1 no i` só atrapalha. Mantenha os comentários que explicam o **porquê**
(regra fiscal, contorno de bug de terceiros).

## 8. Senha no código ou no DFM (risco ALTO, segurança)
Mova para configuração fora do executável e fora do Git. Pergunte ao usuário onde a empresa
guarda credenciais. Depois de remover, a senha continua no histórico do Git: avise que ela
deve ser trocada.

## 9. Application.ProcessMessages (risco ALTO)
Permite que o usuário clique de novo enquanto o processamento roda (reentrância). Não remova
às cegas: a tela pode parecer travada. Opções para discutir: desabilitar o botão durante o
processo, usar `TTask`/thread para o trabalho pesado, ou manter com uma proteção contra reentrada.

## 10. Organize (proponha, não imponha)
- **Pastas por assunto**: `Cadastros\`, `Fiscal\`, `Financeiro\`, `Comum\`, `DataModules\`.
- **Nomes importam**: variáveis, classes e componentes com nome que diz o que são
  (`btnSalvar`, `qryClientes`, não `Button1`, `Query3`). Use a skill `delphi-coding-standards`.
- **Repense os componentes**: retire os que não são mais usados e avalie substitutos mantidos
  para os que estão abandonados.
- **Código duplicado**: anote os blocos repetidos (o levantamento e o diagnóstico mostram) para a
  skill `delphi-safe-refactoring`. Unificar duplicação é refatoração, não limpeza.

## 11. Riscos apontados (não são limpeza)
Unit ou DataModule grande, unit com muitas classes, método grande ou complexo, DataModule com
muitos assuntos, parâmetros `var`/`out` e código duplicado: a skill aponta, com prioridade e
recomendação, e não corrige. Como cada um é medido: [riscos-apontados.md](riscos-apontados.md).
