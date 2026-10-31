unit Connection.Database;

{ Conexão central por código, sem DataModule (padrão das camadas).

  Diferente de uma conexão única compartilhada, aqui cada operação pede uma conexão
  nova e a libera no fim. Com Pooled=True o FireDAC reaproveita as conexões físicas,
  então isso é barato, e funciona tanto no aplicativo VCL/FMX quanto num servidor Horse,
  que atende várias requisições ao mesmo tempo (uma TFDConnection não pode ser usada
  por duas threads ao mesmo tempo).

  Configuração no arquivo <executavel>.ini:
    [Banco]
    DriverID=FB
    Servidor=localhost
    Database=C:\Dados\SISTEMA.FDB
    Usuario=SYSDBA
    Senha=...

  Acrescente no .dpr a unit de espera adequada:
    VCL: FireDAC.VCLUI.Wait · FMX: FireDAC.FMXUI.Wait · servidor/console: FireDAC.ConsoleUI.Wait }

interface

uses
  System.SysUtils,
  System.Classes,
  System.IniFiles,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.Intf,
  FireDAC.Phys.FB,
  FireDAC.DApt,
  FireDAC.Comp.Client;

type
  TConnectionDatabase = class
  private
    class procedure RegistrarDefinicao;
  public
    /// Nova conexão aberta. Quem chama libera (try/finally).
    class function NovaConexao: TFDConnection;
  end;

implementation

const
  NOME_DEFINICAO = 'Principal';

class procedure TConnectionDatabase.RegistrarDefinicao;
var
  Ini: TIniFile;
  Params: TStringList;
begin
  if FDManager.IsConnectionDef(NOME_DEFINICAO) then
    Exit;

  Ini := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  Params := TStringList.Create;
  try
    Params.Values['DriverID'] := Ini.ReadString('Banco', 'DriverID', 'FB');
    Params.Values['Server'] := Ini.ReadString('Banco', 'Servidor', 'localhost');
    Params.Values['Database'] := Ini.ReadString('Banco', 'Database', '');
    Params.Values['User_Name'] := Ini.ReadString('Banco', 'Usuario', 'SYSDBA');
    Params.Values['Password'] := Ini.ReadString('Banco', 'Senha', '');
    Params.Values['Pooled'] := 'True';
    FDManager.AddConnectionDef(NOME_DEFINICAO, Params.Values['DriverID'], Params);
  finally
    Params.Free;
    Ini.Free;
  end;
end;

class function TConnectionDatabase.NovaConexao: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.ConnectionDefName := NOME_DEFINICAO;
    Result.LoginPrompt := False;
    Result.Connected := True;
  except
    on E: Exception do
    begin
      Result.Free;
      raise Exception.Create('Não foi possível conectar ao banco de dados.' + sLineBreak + E.Message);
    end;
  end;
end;

initialization
  // Registrada uma única vez, antes de qualquer thread pedir conexão
  TConnectionDatabase.RegistrarDefinicao;

end.
