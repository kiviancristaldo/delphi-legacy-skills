<#
.SYNOPSIS
  Smoke test dos scripts do kit: EXECUTA cada script contra uma pasta de exemplo gerada na hora
  e confere o resultado. Complementa o Testar-Sintaxe.ps1, que só confere a sintaxe.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Testar-Scripts.ps1

.NOTES
  Rode com o Windows PowerShell 5.1 (o mais restritivo). Não altera nada fora de %TEMP%.
  Os testes que precisam do Delphi (Build-Delphi, Test-Dfm) são pulados se o RAD Studio
  não estiver instalado. Código de saída = número de falhas.
#>
param(
  [string]$VersaoBDS = '37.0'
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path $PSScriptRoot -Parent
$K = Join-Path $raiz 'skills'
$tmp = Join-Path $env:TEMP ('delphi-legacy-skills-smoke-{0}' -f $PID)
$ansi = [Text.Encoding]::GetEncoding(1252)
$resultados = New-Object System.Collections.Generic.List[object]

function Gravar([string]$Relativo, [string]$Texto) {
  $caminho = Join-Path $tmp $Relativo
  New-Item -ItemType Directory -Path (Split-Path $caminho) -Force | Out-Null
  [IO.File]::WriteAllText($caminho, ($Texto -replace "`r?`n", "`r`n"), $ansi)
}

function Rodar([string]$Script, [string[]]$Argumentos) {
  # stderr do script filho não pode abortar o smoke test (PS 5.1 + ErrorActionPreference Stop)
  $ErrorActionPreference = 'Continue'
  $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $K $Script) @Argumentos 2>&1 | Out-String
  return [pscustomobject]@{ Saida = $saida; Codigo = $LASTEXITCODE }
}

function Conferir([string]$Nome, [bool]$Passou, [string]$Detalhe = '') {
  $resultados.Add([pscustomobject]@{ Nome = $Nome; Passou = $Passou })
  if ($Passou) { Write-Host "OK     $Nome" -ForegroundColor Green }
  else { Write-Host "FALHA  $Nome" -ForegroundColor Red; if ($Detalhe) { Write-Host "       $($Detalhe.Trim())" } }
}

function Pular([string]$Nome, [string]$Motivo) { Write-Host "PULADO $Nome ($Motivo)" -ForegroundColor Yellow }

function Contagem([string]$Md, [string]$Item) {
  $linha = Get-Content -Path $Md -Encoding UTF8 | Where-Object { $_ -like "| $Item |*" } | Select-Object -First 1
  if (-not $linha) { return -1 }
  return [int](($linha -split '\|')[2].Trim())
}

function DfmBinario([string]$Relativo, [string]$NomeForm) {
  # Cabeçalho de recurso (FF 0A 00 + nome + 00 + flags + tamanho) e só depois TPF0, como a IDE grava
  $nome = [Text.Encoding]::ASCII.GetBytes($NomeForm.ToUpper())
  $corpo = [Text.Encoding]::ASCII.GetBytes('TPF0' + [char]6 + 'TForm1' + [char]5 + 'Form1' + [char]0 + [char]0)
  $bytes = @(0xFF, 0x0A, 0x00) + $nome + @(0x00, 0x30, 0x10) + [BitConverter]::GetBytes([int]$corpo.Length) + $corpo
  $caminho = Join-Path $tmp $Relativo
  New-Item -ItemType Directory -Path (Split-Path $caminho) -Force | Out-Null
  [IO.File]::WriteAllBytes($caminho, [byte[]]$bytes)
}

New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  # ---------- Pasta de exemplo ----------
  Gravar 'App\uCalculo.pas' @'
unit uCalculo;

interface

uses
  System.SysUtils, Vcl.Forms, Bde.DBTables,
  QRCtrls,
  QryCliente;

function Total(AValor: Double): Double;

implementation

{ calcula o extended price do item: palavra em comentário não conta }
(* outro comentário com Extended
   em duas linhas *)

procedure Exemplo;
var
  Lista: TStringList;
  Form: TForm;
  Rotulo: TQRLabel;
  Valor: Extended;
begin
  Lista := TStringList.Create;
  Form := TForm.Create(Application);
  Rotulo := nil;
  Valor := 0;
  ShowMessage('texto com Extended dentro da string');
end;

{ Comentário antes do método: não entra na contagem de linhas de Total }

function Total(AValor: Double): Double;

  function Dobro(A: Double): Double;
  begin
    Result := A * 2;
  end;

begin
  Result := Dobro(AValor);
end;

end.
'@
  Gravar 'App\QryCliente.pas' @'
unit QryCliente;

interface

implementation

end.
'@
  Gravar 'App\uDados.dfm' @'
object Dados: TDados
  object SQLConnection1: TSQLConnection
    ConnectionName = 'MO'
    DriverName = 'Interbase'
  end
  object SQLDataSet1: TSQLDataSet
    SQLConnection = SQLConnection1
    object SQLDataSet1DATA: TSQLTimeStampField
      FieldName = 'DATA'
    end
  end
end
'@
  DfmBinario 'App\uBinario.dfm' 'TBINARIO'
  Gravar 'App\uBinario.pas' @'
unit uBinario;

interface

uses
  Data.SqlExpr;

implementation

end.
'@

  # ---------- Find-PadroesMigracao (Win64) ----------
  $r = Rodar 'delphi-64bit-ready\scripts\Find-PadroesMigracao.ps1' @('-Tipo', 'Win64', '-Pasta', "$tmp\App", '-Recursivo')
  $md = "$tmp\App\_modernizacao\padroes-Win64.md"
  Conferir 'Find-PadroesMigracao roda' ($r.Codigo -eq 0 -and (Test-Path $md)) $r.Saida
  if (Test-Path $md) {
    Conferir 'Find-PadroesMigracao: Extended só no código (ignora comentário e string)' ((Contagem $md 'Extended (precisão muda)') -eq 1)
    Conferir 'Find-PadroesMigracao: QuickReport sim, QryCliente não' ((Contagem $md 'Componentes sem versão 64 bits') -eq 2)
    Conferir 'Find-PadroesMigracao: BDE' ((Contagem $md 'BDE (não existe em 64 bits)') -eq 1)
  }
  $iguais = (Get-FileHash "$K\delphi-64bit-ready\scripts\Find-PadroesMigracao.ps1").Hash -eq (Get-FileHash "$K\delphi-unicode-migration\scripts\Find-PadroesMigracao.ps1").Hash
  Conferir 'Find-PadroesMigracao: cópias unicode e 64 bits idênticas' $iguais

  # ---------- Find-CodeSmells ----------
  $r = Rodar 'delphi-cleanup\scripts\Find-CodeSmells.ps1' @('-Pasta', "$tmp\App", '-Recursivo')
  $md = "$tmp\App\_modernizacao\limpeza.md"
  Conferir 'Find-CodeSmells roda' ($r.Codigo -eq 0 -and (Test-Path $md)) $r.Saida
  if (Test-Path $md) {
    Conferir 'Find-CodeSmells: Create(Application) não conta, Create sem dono conta' ((Contagem $md 'Create sem try/finally') -eq 1)
  }

  # ---------- Get-DiagnosticoLegado ----------
  $r = Rodar 'delphi-legacy-modernizer\scripts\Get-DiagnosticoLegado.ps1' @('-Pasta', "$tmp\App", '-Recursivo')
  $md = "$tmp\App\_modernizacao\diagnostico.md"
  Conferir 'Get-DiagnosticoLegado roda' ($r.Codigo -eq 0 -and (Test-Path $md)) $r.Saida
  if (Test-Path $md) {
    # Exemplo (13 linhas) é seguido de linha em branco e comentário, que não podem contar;
    # Total (10 linhas) tem função aninhada com end; indentado
    foreach ($caso in @(@('Exemplo', 13), @('Total', 10))) {
      $linha = Get-Content $md -Encoding UTF8 | Where-Object { $_ -like "| $($caso[0]) |*" } | Select-Object -First 1
      $linhas = if ($linha) { [int](($linha -split '\|')[2].Trim()) } else { -1 }
      Conferir "Get-DiagnosticoLegado: linhas de $($caso[0]) vão até o end; ($($caso[1]))" ($linhas -eq $caso[1]) "$($caso[0]) = $linhas"
    }
    $json = @(Get-ChildItem "$tmp\App\_modernizacao" -Filter 'diagnostico-*.json')
    Conferir 'Get-DiagnosticoLegado: JSON com data e hora no nome' ($json.Count -eq 1 -and $json[0].Name -match '^diagnostico-\d{4}-\d{2}-\d{2}_\d{6}\.json$') ($json.Name -join ', ')
  }

  # ---------- Get-InventarioAcessoDados (DBX) ----------
  $r = Rodar 'dbx-to-firedac\scripts\Get-InventarioAcessoDados.ps1' @('-Origem', 'DBX', '-Pasta', "$tmp\App", '-Recursivo')
  $md = "$tmp\App\_migracao\inventario-DBX.md"
  Conferir 'Get-InventarioAcessoDados roda' ($r.Codigo -eq 0 -and (Test-Path $md)) $r.Saida
  if (Test-Path $md) {
    $texto = Get-Content $md -Encoding UTF8 -Raw
    Conferir 'Inventário: detecta DFM binário com cabeçalho FF 0A' ($texto -match '## 1\. DFMs em formato binário: 1')
    Conferir 'Inventário: conta TSQLTimeStampField' ($texto -match '## 6b\. Campos TSQLTimeStampField: 1')
  }
  $copias = @('ado', 'bde', 'dbx') | ForEach-Object { (Get-FileHash "$K\$_-to-firedac\scripts\Get-InventarioAcessoDados.ps1").Hash } | Sort-Object -Unique
  Conferir 'Inventário: cópias ado/bde/dbx idênticas' (@($copias).Count -eq 1)

  # ---------- Test-Endpoints (sem servidor: só a validação do JSON) ----------
  $r = Rodar 'delphi-safe-refactoring\scripts\Test-Endpoints.ps1' @('-BaseUrl', 'http://localhost:1', '-Recurso', 'x', '-Corpo', '{nome:sem aspas}')
  Conferir 'Test-Endpoints: recusa corpo que não é JSON (exit 2)' ($r.Codigo -eq 2) $r.Saida
  # JSON em arquivo: é assim que se passa JSON por powershell -File no PS 5.1
  Gravar 'json\corpo.json' '{"nome":"Teste skill"}'
  Gravar 'json\invalido.json' '{"nome":""}'
  $r = Rodar 'delphi-safe-refactoring\scripts\Test-Endpoints.ps1' @('-BaseUrl', 'http://localhost:1', '-Recurso', 'x', '-CorpoArquivo', "$tmp\json\corpo.json", '-CorpoInvalidoArquivo', "$tmp\json\invalido.json")
  Conferir 'Test-Endpoints: lê -CorpoArquivo e tenta chamar (sem servidor: falhas de conexão)' ($r.Codigo -gt 0 -and $r.Saida -match 'Testando http://localhost:1/x' -and $r.Saida -notmatch 'não é JSON válido') $r.Saida

  # ---------- Precisam do Delphi ----------
  $bds = "C:\Program Files (x86)\Embarcadero\Studio\$VersaoBDS"
  $chave = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\$VersaoBDS" -Name RootDir -ErrorAction SilentlyContinue
  if ($chave -and $chave.RootDir) { $bds = $chave.RootDir.TrimEnd('\') }
  if (-not (Test-Path (Join-Path $bds 'bin\rsvars.bat'))) {
    Pular 'Test-Dfm e Build-Delphi' "RAD Studio $VersaoBDS não encontrado"
  } else {
    # Test-Dfm: um .dfm válido passa, um quebrado falha
    Gravar 'Dfm\Valido.dfm' "object Form1: TForm1`r`n  Caption = 'Teste'`r`nend`r`n"
    Gravar 'Dfm\Quebrado.dfm' "object Form1: TForm1`r`n  Caption = 'Teste`r`n"
    $r = Rodar 'delphi-safe-refactoring\scripts\Test-Dfm.ps1' @('-Arquivos', "$tmp\Dfm\Valido.dfm")
    Conferir 'Test-Dfm: .dfm válido passa' ($r.Codigo -eq 0) $r.Saida
    $r = Rodar 'delphi-safe-refactoring\scripts\Test-Dfm.ps1' @('-Arquivos', "$tmp\Dfm\Quebrado.dfm")
    Conferir 'Test-Dfm: .dfm quebrado falha' ($r.Codigo -eq 1) $r.Saida

    # Build-Delphi: projeto console com 1 hint (variável não usada) e um com erro
    Gravar 'Build\Ok\Ok.dpr' "program Ok;`r`n{`$APPTYPE CONSOLE}`r`nprocedure P;`r`nvar`r`n  I: Integer;`r`nbegin`r`nend;`r`nbegin`r`n  P;`r`nend.`r`n"
    Gravar 'Build\Erro\Erro.dpr' "program Erro;`r`n{`$APPTYPE CONSOLE}`r`nbegin`r`n  NaoExiste;`r`nend.`r`n"
    $modelo = [IO.File]::ReadAllText((Join-Path $K 'delphi-characterization-tests\modelos\ProjetoTestes.dproj.modelo'), [Text.Encoding]::UTF8)
    foreach ($p in 'Ok', 'Erro') {
      $dproj = $modelo.Replace('{{Projeto}}Tests.dpr', "$p.dpr").Replace('{{GUID}}', ('{' + [guid]::NewGuid().ToString().ToUpper() + '}')).Replace('{{PastaFonteDUnitX}};', '')
      [IO.File]::WriteAllText("$tmp\Build\$p\$p.dproj", $dproj, (New-Object Text.UTF8Encoding($true)))
    }
    $r = Rodar 'delphi-compile-loop\scripts\Build-Delphi.ps1' @('-Projeto', "$tmp\Build\Ok\Ok.dproj")
    $json = "$tmp\Build\Ok\_build\build-result.json"
    Conferir 'Build-Delphi: compila, exit 0 e gera JSON' ($r.Codigo -eq 0 -and (Test-Path $json)) $r.Saida
    if (Test-Path $json) {
      $j = Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json
      Conferir 'Build-Delphi: totais do JSON (0 erros, 1 hint H2164)' ($j.totais.error -eq 0 -and $j.totais.hint -eq 1 -and $j.itens[0].codigo -eq 'H2164') ($j.totais | Out-String)
    }
    $r = Rodar 'delphi-compile-loop\scripts\Build-Delphi.ps1' @('-Projeto', "$tmp\Build\Erro\Erro.dproj")
    $json = "$tmp\Build\Erro\_build\build-result.json"
    $ok = $false
    if (Test-Path $json) { $j = Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json; $ok = ($j.totais.error -ge 1) }
    Conferir 'Build-Delphi: erro de compilação dá exit 1 e conta o erro no JSON' ($r.Codigo -eq 1 -and $ok) $r.Saida
  }
} finally {
  Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$falhas = @($resultados | Where-Object { -not $_.Passou }).Count
Write-Host ''
Write-Host "PowerShell $($PSVersionTable.PSVersion) · $($resultados.Count) verificações · $falhas falha(s)"
exit $falhas
