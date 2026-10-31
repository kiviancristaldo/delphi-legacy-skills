<#
.SYNOPSIS
  Compila o projeto de testes DUnitX com MSBuild e executa os testes.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Run-Tests.ps1 -Projeto Testes\MeuSistemaTests.dproj

.NOTES
  Código de saída: 0 = todos passaram, 1 = falhas, 2 = erro de compilação/execução.
  -VersaoBDS 37.0 = Delphi 13 Florence. Delphi 12 = 23.0, Delphi 11 = 22.0.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Projeto,
  [string]$Config = 'Debug',
  [string]$Plataforma = 'Win32',
  [string]$VersaoBDS = '37.0',
  [string]$Exe = ''
)

$ErrorActionPreference = 'Stop'

function Get-BdsRoot([string]$Versao) {
  $chaves = @(
    "HKCU:\Software\Embarcadero\BDS\$Versao",
    "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\$Versao",
    "HKLM:\SOFTWARE\Embarcadero\BDS\$Versao"
  )
  foreach ($key in $chaves) {
    $p = Get-ItemProperty -Path $key -Name RootDir -ErrorAction SilentlyContinue
    if ($p -and $p.RootDir) { return $p.RootDir }
  }
  return "C:\Program Files (x86)\Embarcadero\Studio\$Versao\"
}

$projetoFull = (Resolve-Path $Projeto).Path
$root = Get-BdsRoot $VersaoBDS
$rsvars = Join-Path $root 'bin\rsvars.bat'
if (-not (Test-Path $rsvars)) {
  Write-Host "rsvars.bat não encontrado em $rsvars. Confira -VersaoBDS."
  exit 2
}

# Compila via .bat temporário (evita problemas de aspas do PowerShell com cmd.exe)
$bat = Join-Path $env:TEMP ("dunitx-build-{0}.bat" -f $PID)
@"
@echo off
call "$rsvars" >nul
msbuild "$projetoFull" /t:Build /p:Config=$Config /p:Platform=$Plataforma /v:minimal /nologo 2>&1
"@ | Set-Content -Path $bat -Encoding Default

Write-Host "Compilando $projetoFull ($Config/$Plataforma)..."
$ErrorActionPreference = 'Continue'   # stderr de programa externo não pode abortar o script (PS 5.1)
$saida = & cmd.exe /c "`"$bat`"" 2>&1 | ForEach-Object { "$_" }
$codigo = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item $bat -ErrorAction SilentlyContinue

if ($codigo -ne 0) {
  $saida | Where-Object { $_ -match ':\s+(error|fatal)\s' } | Select-Object -Unique | ForEach-Object { Write-Host $_ }
  Write-Host "Falha na compilação dos testes (código $codigo). Use a skill delphi-compile-loop."
  exit 2
}

if (-not $Exe) {
  $nome = [IO.Path]::GetFileNameWithoutExtension($projetoFull)
  $Exe = Join-Path (Split-Path $projetoFull) "$Plataforma\$Config\$nome.exe"
}
if (-not (Test-Path $Exe)) {
  Write-Host "Executável não encontrado: $Exe. Informe -Exe com o caminho correto."
  exit 2
}

Write-Host "Executando $Exe..."
$ErrorActionPreference = 'Continue'
Push-Location (Split-Path $Exe)
try {
  & $Exe
  $resultado = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($resultado -eq 0) { Write-Host 'RESULTADO: todos os testes passaram.' }
elseif ($resultado -eq 1) { Write-Host 'RESULTADO: há testes falhando.' }
else { Write-Host "RESULTADO: erro na execução (código $resultado)." }
exit $resultado
