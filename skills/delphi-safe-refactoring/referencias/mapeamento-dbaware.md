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
| Legado (automático) | Agora (código) |
|---|---|
| Rolar o grid atualizava os TDBEdit | `DS_<Assunto>.OnDataChange` com `Field = nil` chama `CarregarRegistroSelecionado` |
| `Append`/`Edit`/`Post`/`Cancel` | flags `FIncluindo` e `FIdAtual` + chamadas ao Controller (veja `View.Produtos.pas.modelo`) |
| Grid continuava no mesmo registro depois de gravar | guardar o id e usar `Locate` depois de `AtualizarView` |
| `Required` do TField barrava o Post | `ValidarPreenchimento` no Controller |
| Botões habilitados conforme o estado do dataset | método de estado da tela (mantenha o nome que o legado usava) |

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
| Camadas | `Types.<Assunto>`, `Models.<Assunto>`, `Controllers.<Assunto>` |
| Sempre | `Data.DB`, `Vcl.Grids`, `Vcl.DBGrids` |

## FMX
Mesmo padrão. No FireMonkey, o curso usou `TListView` preenchido no `AtualizarView`, sem
dataset: é uma alternativa mais simples ao `TFDMemTable` quando a tela é só uma lista.
