# Tirando a tela do DataModule: mapeamentos

## Campo do banco → propriedade → componente
| TField no DataModule | Tipo no Model | Leitura da query | Componente novo | Tela ↔ Model |
|---|---|---|---|---|
| `TIntegerField`, `TSmallintField`, `TAutoIncField` | `Integer` | `AsInteger` | `TEdit` (chave: `ReadOnly`) | `StrToIntDef(Trim(edt.Text), 0)` / `.ToString` |
| `TLargeintField` | `Int64` | `AsLargeInt` | `TEdit` | `StrToInt64Def` / `.ToString` |
| `TStringField`, `TWideStringField` | `string` | `AsString` | `TEdit` com `MaxLength` = `Size` | `Trim(edt.Text)` |
| `TMemoField`, `TWideMemoField` | `string` | `AsString` | `TMemo` | `mmo.Text` (não `Lines.Text`, que acrescenta quebra de linha) |
| `TFloatField`, `TBCDField`, `TFMTBCDField` | `Double` | `AsFloat` | `TEdit` com `Alignment = taRightJustify` | `FormatFloat('0.00', V)` / `TryStrToFloat` com erro claro |
| `TCurrencyField` ou valor monetário | `Currency` | `AsCurrency` | `TEdit` à direita | idem |
| `TDateField` | `TDate` | `AsDateTime` | `TDateTimePicker` (data obrigatória) ou `TMaskEdit` (opcional) | `.Date` / `TryStrToDate`; vazio = 0 |
| `TDateTimeField`, `TSQLTimeStampField` | `TDateTime` | `AsDateTime` | `TDateTimePicker` | `.DateTime` |
| `TBooleanField` | `Boolean` | `AsBoolean` | `TCheckBox` | `.Checked` |
| `TStringField(1)` com 'S'/'N' | `Boolean` | `AsString = 'S'` | `TCheckBox` | grava `IfThen(V, 'S', 'N')` |
| Inteiro com lista de valores (enum) | enum em `Types.<Assunto>` | `TEnum(AsInteger)` | `TComboBox`/`TRadioGroup` | `ItemIndex` ↔ `Ord` |

O `DisplayFormat` e o `EditMask` do TField legado definem o formato na tela: mantenha.

## Componente DB-aware → componente comum (no .dfm)
| Antes | Depois | Remover do .dfm |
|---|---|---|
| `TDBEdit` | `TEdit` (ou `TMaskEdit` se havia `EditMask`) | `DataField`, `DataSource` |
| `TDBMemo` | `TMemo` | `DataField`, `DataSource` |
| `TDBCheckBox` | `TCheckBox` | `DataField`, `DataSource`, `ValueChecked`, `ValueUnchecked` |
| `TDBComboBox` | `TComboBox` | `DataField`, `DataSource` |
| `TDBRadioGroup` | `TRadioGroup` | `DataField`, `DataSource`, `Values` |
| `TDBText` | `TLabel` | `DataField`, `DataSource` |
| `TDBGrid` | `TDBGrid` (fica) | troca o `DataSource` para o do `TFDMemTable` |
| `TDataSource` → `DataModule.qryX` | `DS_<Assunto>` → `MTB_<Assunto>` | `DataSet = DataModule.qryX` |
| `TDBNavigator` | botões comuns | fora do escopo padrão: pergunte |

Ao trocar a classe no `.dfm`, troque também a declaração no `.pas` (mesmo nome, nova classe).
Renomeie componentes com nome padrão da IDE (`Edit1` → `edtNome`) só se o usuário aprovar no
plano, atualizando `FocusControl` e todas as referências.

## O grid: TFDMemTable local
O `TDBGrid` continua, ligado a um `TFDMemTable` do próprio form, preenchido pelo Controller
(método `AtualizarView`, como no curso). Bloco base no `.dfm`:
```
  object MTB_Produtos: TFDMemTable
    FieldDefs = <>
    IndexDefs = <>
    FetchOptions.AssignedValues = [evMode]
    FetchOptions.Mode = fmAll
    ResourceOptions.AssignedValues = [rvSilentMode]
    ResourceOptions.SilentMode = True
    UpdateOptions.AssignedValues = [uvCheckRequired]
    UpdateOptions.CheckRequired = False
    StoreDefs = True
    object MTB_ProdutosID: TIntegerField
      FieldName = 'ID'
    end
    object MTB_ProdutosNOME: TStringField
      FieldName = 'NOME'
      Size = 60
    end
    object MTB_ProdutosPRECO: TCurrencyField
      FieldName = 'PRECO'
    end
  end
  object DS_Produtos: TDataSource
    DataSet = MTB_Produtos
    OnDataChange = DS_ProdutosDataChange
  end
```
Copie dos TFields legados só o que afeta a exibição (`FieldName`, `Size`, `DisplayLabel`,
`DisplayFormat`, `Visible`, `Alignment`). **Não** copie `Required` (o `Post` no MemTable falharia),
`Origin` nem `ProviderFlags`. As `Columns` do grid precisam apontar para campos que existem no MemTable.

## Comportamentos que o DB-aware dava de graça
Levante quais destes o form legado tinha (B1). Os marcados com **Pergunte** mudam o jeito de usar a
tela: cada um é uma pergunta no B2, com a recomendação. Os demais você reimplementa e registra no plano.

| Legado (automático) | Agora (código) | Pergunte? |
|---|---|---|
| Rolar o grid atualizava os TDBEdit | `DS_<Assunto>.OnDataChange` com `Field = nil` chama `CarregarRegistroSelecionado` | não |
| `Append`/`Edit`/`Post`/`Cancel` | flags `FIncluindo` e `FIdAtual` + chamadas ao Controller (veja `View.Produtos.pas.modelo`) | não |
| Grid continuava no mesmo registro depois de gravar | guardar o id e usar `Locate` depois de `AtualizarView` | não |
| `Required` do TField barrava o Post | `ValidarPreenchimento` no Controller | não |
| `MaxLength` do TDBEdit vinha do `Size` do TField | `MaxLength` no `TEdit` (e a regra de tamanho no Controller, para a API) | não |
| `AutoEdit`: digitar num TDBEdit punha o dataset em edição sozinho | campos sempre editáveis; marque a tela como alterada (`FAlterado := True`) no `OnChange` dos campos | não |
| **Trocar de linha no grid (ou clicar em Novo/Atualizar) com edição pendente gravava sozinho** (`CheckBrowseMode` → `Post`) | no `OnDataChange`, antes de carregar outro registro, se `FAlterado`: gravar, descartar ou perguntar ao usuário da tela | **Pergunte**. Recomendação: perguntar na tela ("Gravar as alterações?"), que é o mais seguro; gravar sozinho reproduz o legado |
| **Edição direto no grid** (`dgEditing` nas `Options`, ligado por padrão, com dataset editável) | grid somente leitura (`dgEditing` fora ou `ReadOnly = True`); edição só nos campos | **Pergunte** se o legado deixava editar no grid. Recomendação: só leitura |
| **Esc num TDBEdit restaurava o valor do campo** (e Esc no grid cancelava a edição) | `OnKeyDown` com `VK_ESCAPE` → `CarregarRegistroSelecionado` (ou restaurar só o campo) | **Pergunte**. Recomendação: Esc restaura o registro |
| Caracteres aceitos pelo TField (`IsValidChar`: `TIntegerField` só aceita dígitos e sinal) | `NumbersOnly` no `TEdit` (não aceita sinal) ou filtro no `OnKeyPress`; conversão com `TryStrToInt` e erro claro | não |
| Botões do `TDBNavigator` habilitados conforme o estado (vazio, BOF/EOF, editando) | método de estado da tela chamado no `OnDataChange` e depois de cada ação (mantenha o nome que o legado usava) | não |
| `TDBNavigator.ConfirmDelete` (padrão `True`: "Delete record?") | `MessageDlg` antes de `Excluir`, só se o legado confirmava | não |
| Glifos do navegador | botões com texto (ou os mesmos ícones num `TImageList`) | **Pergunte** se a aparência importa para o usuário |

## Nulos e datas como parâmetro (FireDAC)
- Parâmetro com valor `Null` sem tipo definido falha em execução. Quando a coluna aceita nulo,
  defina o tipo antes: `Query.ParamByName('EMAIL').DataType := ftString;` e depois
  `Query.ParamByName('EMAIL').Clear;` (ou use `TFDQuery` com `ParamByName(...).AsString` e
  `.Clear` em vez de `ExecSQL(SQL, [valores])`).
- `TDate`/`TDateTime` dentro de `array of Variant` vira número em alguns drivers. Para datas,
  use `ParamByName('DATA').AsDate := V` (ou `AsDateTime`) num `TFDQuery`.
- Coluna que aceitava nulo e passa a gravar 0 ou vazio é **mudança de comportamento**: liste no plano.

## uses do form depois da transformação
| Situação | Ação |
|---|---|
| Não sobrou componente DB-aware (exceto `TDBGrid`) | remover `Vcl.DBCtrls` |
| DataModule não é mais usado pelo form | remover a unit do DataModule |
| `TFDMemTable` | `FireDAC.Stan.Intf`, `FireDAC.Stan.Option`, `FireDAC.Stan.Param`, `FireDAC.Stan.Error`, `FireDAC.DatS`, `FireDAC.Phys.Intf`, `FireDAC.DApt.Intf`, `FireDAC.Comp.DataSet`, `FireDAC.Comp.Client` |
| `TMaskEdit` / `TDateTimePicker` | `Vcl.Mask` / `Vcl.ComCtrls` |
| `MessageDlg` com `mtConfirmation`/`mrYes` | `System.UITypes` (sem ela o compilador dá o hint H2443) |
| Camadas | `Types.<Assunto>`, `Models.<Assunto>`, `Controllers.<Assunto>` |
| Sempre | `Data.DB`, `Vcl.Grids`, `Vcl.DBGrids` |

## FMX
Mesmo padrão. No FireMonkey, o curso usou `TListView` preenchido no `AtualizarView`, sem
dataset: é uma alternativa mais simples ao `TFDMemTable` quando a tela é só uma lista.
