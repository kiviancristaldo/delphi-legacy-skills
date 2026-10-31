program ServerProdutos;

{ Servidor Horse que expõe o assunto como API REST, reaproveitando as MESMAS
  units de Types, Connection, Models e Controllers usadas pelo aplicativo desktop.

  Dependências (Boss, na pasta do servidor):
    boss install horse
    boss install jhonson
    boss install handle-exception

  Configuração do banco: ServerProdutos.ini ao lado do executável (veja Connection.Database). }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Jhonson,
  Horse.HandleException,
  FireDAC.ConsoleUI.Wait,
  Connection.Database in '..\src\Connection\Connection.Database.pas',
  Types.Produtos in '..\src\Types\Types.Produtos.pas',
  Models.Produtos in '..\src\Models\Models.Produtos.pas',
  Controllers.Produtos in '..\src\Controllers\Controllers.Produtos.pas',
  Routes.Produtos in 'Routes\Routes.Produtos.pas';

const
  PORTA = 9000;

begin
  ReportMemoryLeaksOnShutdown := True;

  THorse.Use(Jhonson);
  THorse.Use(HandleException);

  Routes.Produtos.Registry;

  Writeln(Format('Servidor no ar: http://localhost:%d/produtos', [PORTA]));
  THorse.Listen(PORTA);
end.
