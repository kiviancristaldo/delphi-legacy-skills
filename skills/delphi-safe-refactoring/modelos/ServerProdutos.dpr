program ServerProdutos;

{ Servidor Horse que expõe o assunto como API REST, reaproveitando as MESMAS
  units de Types, Connection, Models e Controllers usadas pelo aplicativo desktop.

  Dependências (Boss, na pasta do servidor):
    boss install horse
    boss install jhonson
    boss install handle-exception
  O Boss 3.x põe os fontes em modules\github_com_hashload_<pacote>\src; o ServerProdutos.dproj.modelo
  já traz esse search path.

  Configuração do banco: ServerProdutos.ini ao lado do executável (veja Connection.Database). }

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
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
  // Acentos certos no console (também com a saída redirecionada para arquivo/log)
  SetTextCodePage(Output, GetConsoleOutputCP);

  // Middlewares ANTES das rotas, e o Jhonson ANTES do HandleException: o HandleException responde
  // o erro com um TJSONObject, e quem serializa é o Jhonson, que precisa estar por fora.
  // Na ordem inversa o 500 sai como página HTML, sem JSON (testado com Horse 3.3 / handle-exception 0.2).
  THorse.Use(Jhonson);
  THorse.Use(HandleException);

  Routes.Produtos.Registry;

  THorse.Listen(PORTA,
    procedure
    begin
      Writeln(Format('Servidor no ar: http://localhost:%d/produtos', [THorse.Port]));
      Flush(Output);   // com a saída redirecionada (serviço, log), sem isto a linha fica no buffer
    end);
end.
