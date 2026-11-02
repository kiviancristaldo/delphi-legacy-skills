unit GoldenMaster;

{ Golden master / approval testing para DUnitX.

  Uso:
    TGoldenMaster.Verify('NomeDoCaso', TextoGerado);
    TGoldenMaster.Verify('Itens', TGoldenMaster.DataSetToText(Query));

  - Se <Folder>\NomeDoCaso.approved.txt não existe: grava .received.txt e falha.
  - Se existe e o conteúdo é diferente: grava .received.txt e falha.
  - Se é igual: passa e apaga um .received.txt antigo.
  Para aprovar, renomeie .received.txt para .approved.txt
  (scripts\Approve-GoldenMaster.ps1 faz isso). }

interface

uses
  System.SysUtils, System.Classes, Data.DB;

type
  TGoldenMaster = class
  private
    class function Normalize(const AText: string): string; static;
  public
    class var Folder: string;
    class procedure Verify(const AName, AActual: string); static;
    class function DataSetToText(ADataSet: TDataSet): string; static;
  end;

implementation

uses
  System.IOUtils, DUnitX.TestFramework;

class function TGoldenMaster.Normalize(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := TrimRight(Result) + #10;
end;

class procedure TGoldenMaster.Verify(const AName, AActual: string);
var
  Dir, ApprovedFile, ReceivedFile, Approved, Actual: string;
begin
  Dir := Folder;
  if Dir = '' then
    Dir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'approved');
  ForceDirectories(Dir);

  ApprovedFile := TPath.Combine(Dir, AName + '.approved.txt');
  ReceivedFile := TPath.Combine(Dir, AName + '.received.txt');
  Actual := Normalize(AActual);

  if not TFile.Exists(ApprovedFile) then
  begin
    TFile.WriteAllText(ReceivedFile, Actual, TEncoding.UTF8);
    Assert.Fail(Format('Ainda não há saída aprovada para "%s". Revise %s e aprove.',
      [AName, ReceivedFile]));
  end;

  Approved := Normalize(TFile.ReadAllText(ApprovedFile, TEncoding.UTF8));
  if Approved <> Actual then
  begin
    TFile.WriteAllText(ReceivedFile, Actual, TEncoding.UTF8);
    Assert.Fail(Format('A saída de "%s" mudou. Compare %s com %s.',
      [AName, ApprovedFile, ReceivedFile]));
  end;

  if TFile.Exists(ReceivedFile) then
    TFile.Delete(ReceivedFile);

  // Registra uma asserção: o projeto de testes liga FailsOnNoAsserts, e um teste que só
  // chama Verify falharia com "No assertions were made". Não use Assert.Pass aqui: ele
  // encerra o teste e um segundo Verify no mesmo teste não rodaria.
  Assert.IsTrue(True, Format('Saída de "%s" igual à aprovada.', [AName]));
end;

class function TGoldenMaster.DataSetToText(ADataSet: TDataSet): string;
var
  SB: TStringBuilder;
  I: Integer;
  Bookmark: TBookmark;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to ADataSet.FieldCount - 1 do
    begin
      if I > 0 then
        SB.Append(#9);
      SB.Append(ADataSet.Fields[I].FieldName);
    end;
    SB.Append(#10);

    ADataSet.DisableControls;
    Bookmark := ADataSet.GetBookmark;
    try
      ADataSet.First;
      while not ADataSet.Eof do
      begin
        for I := 0 to ADataSet.FieldCount - 1 do
        begin
          if I > 0 then
            SB.Append(#9);
          if ADataSet.Fields[I].IsNull then
            SB.Append('<null>')
          else
            SB.Append(ADataSet.Fields[I].AsString);
        end;
        SB.Append(#10);
        ADataSet.Next;
      end;
    finally
      if (Bookmark <> nil) and ADataSet.BookmarkValid(Bookmark) then
        ADataSet.GotoBookmark(Bookmark);
      ADataSet.FreeBookmark(Bookmark);
      ADataSet.EnableControls;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
