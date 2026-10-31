<#
.SYNOPSIS
  Compila um projeto Delphi (.dproj) com MSBuild e devolve erros, warnings e hints
  de forma estruturada (console + JSON), para um ciclo "compila → corrige → compila".

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Build-Delphi.ps1 -Projeto C:\Projetos\MeuSistema\MeuSistema.dproj

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Build-Delphi.ps1 -Projeto MeuSistema.dproj -Config Release -Plataforma Win64 -Incremental

.NOTES
  Por padrão faz REBUILD: no build incremental, units que não foram recompiladas não
  mostram seus warnings e hints, e a contagem fica errada.
  Código de saída: 0 = compilou, 1 = erros de compilação, 2 = problema de ambiente.
  -VersaoBDS 37.0 = Delphi 13 Florence. Delphi 12 = 23.0, Delphi 11 = 22.0.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Projeto,
  [string]$Config = 'Debug',
  [string]$Plataforma = 'Win32',
  [string]$VersaoBDS = '37.0',
  [switch]$Incremental,
  [string]$Saida = '',
  [int]$MaxItensConsole = 60
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

if (-not (Test-Path $Projeto)) { Write-Host "Projeto não encontrado: $Projeto"; exit 2 }
$projetoFull = (Resolve-Path $Projeto).Path
if ([IO.Path]::GetExtension($projetoFull) -ne '.dproj') {
  Write-Host 'Informe o .dproj (o MSBuild não compila .dpr diretamente).'
  exit 2
}

$root = Get-BdsRoot $VersaoBDS
$rsvars = Join-Path $root 'bin\rsvars.bat'
if (-not (Test-Path $rsvars)) { Write-Host "rsvars.bat não encontrado em $rsvars. Confira -VersaoBDS."; exit 2 }

if (-not $Saida) {
  $Saida = Join-Path (Split-Path $projetoFull) '_build\build-result.json'
}
New-Item -ItemType Directory -Path (Split-Path $Saida) -Force | Out-Null
$logBruto = [IO.Path]::ChangeExtension($Saida, '.log')

$alvo = if ($Incremental) { 'Build' } else { 'Rebuild' }
$bat = Join-Path $env:TEMP ("delphi-build-{0}.bat" -f $PID)
@"
@echo off
call "$rsvars" >nul
msbuild "$projetoFull" /t:$alvo /p:Config=$Config /p:Platform=$Plataforma /v:minimal /nologo /clp:NoSummary 2>&1
"@ | Set-Content -Path $bat -Encoding Default

$inicio = Get-Date
$ErrorActionPreference = 'Continue'   # stderr de programa externo não pode abortar o script (PS 5.1)
$linhas = & cmd.exe /c "`"$bat`"" 2>&1 | ForEach-Object { "$_" }
$codigo = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item $bat -ErrorAction SilentlyContinue
$linhas | Set-Content -Path $logBruto -Encoding UTF8

# Formato do dcc via MSBuild, por exemplo:
#   C:\src\Unit1.pas(25,3): error E2003: Undeclared identifier: 'Foo' [C:\src\Proj.dproj]
#   C:\src\Unit1.pas(30): hint warning H2164: Variable 'i' is declared but never used [..]
$regex = '^\s*(?<arq>.+?\.(pas|dpr|dpk|inc|dfm|fmx))\((?<lin>\d+)(,(?<col>\d+))?\):\s+(?<tipo>[a-z ]+?)\s+(?<cod>[EWHF]\d{4}):\s*(?<msg>.*?)(\s+\[[^\]]+\])?\s*$'

$itens = New-Object System.Collections.Generic.List[object]
$vistos = @{}
foreach ($l in $linhas) {
  $m = [regex]::Match($l, $regex, 'IgnoreCase')
  if (-not $m.Success) { continue }
  $cod = $m.Groups['cod'].Value.ToUpper()
  $chave = "$($m.Groups['arq'].Value)|$($m.Groups['lin'].Value)|$cod|$($m.Groups['msg'].Value)"
  if ($vistos.ContainsKey($chave)) { continue }   # o MSBuild repete mensagens
  $vistos[$chave] = $true
  $severidade = switch ($cod.Substring(0, 1)) { 'F' { 'fatal' } 'E' { 'error' } 'W' { 'warning' } 'H' { 'hint' } }
  $itens.Add([pscustomobject]@{
    severidade = $severidade
    codigo     = $cod
    arquivo    = $m.Groups['arq'].Value
    linha      = [int]$m.Groups['lin'].Value
    coluna     = if ($m.Groups['col'].Success) { [int]$m.Groups['col'].Value } else { $null }
    mensagem   = $m.Groups['msg'].Value
  })
}

# Erros que não seguem o formato acima (MSBuild, linker, projeto)
$outrosErros = @($linhas | Where-Object { $_ -match '\berror\b' -and -not [regex]::IsMatch($_, $regex, 'IgnoreCase') } | Select-Object -Unique)

$fatais = @($itens | Where-Object severidade -eq 'fatal').Count
$erros = @($itens | Where-Object severidade -eq 'error').Count
$warnings = @($itens | Where-Object severidade -eq 'warning').Count
$hints = @($itens | Where-Object severidade -eq 'hint').Count

$porCodigo = $itens | Group-Object codigo | Sort-Object Count -Descending |
  ForEach-Object { [pscustomobject]@{ codigo = $_.Name; quantidade = $_.Count; exemplo = $_.Group[0].mensagem } }

$resultado = [pscustomobject]@{
  projeto      = $projetoFull
  config       = $Config
  plataforma   = $Plataforma
  alvo         = $alvo
  inicio       = $inicio.ToString('s')
  duracaoSeg   = [int]((Get-Date) - $inicio).TotalSeconds
  codigoSaida  = $codigo
  compilou     = ($codigo -eq 0)
  totais       = [pscustomobject]@{ fatal = $fatais; error = $erros; warning = $warnings; hint = $hints }
  porCodigo    = @($porCodigo)
  outrosErros  = $outrosErros
  # ToArray(): no PS 5.1, @($lista) com List[object] dentro de um hashtable literal lança
  # "Os tipos de argumento não correspondem" (ArgumentException), mesmo com a lista vazia
  itens        = $itens.ToArray()
}
$resultado | ConvertTo-Json -Depth 5 | Set-Content -Path $Saida -Encoding UTF8

# ---------- Resumo no console ----------
Write-Host "Projeto: $projetoFull ($Config/$Plataforma, $alvo)"
Write-Host "Resultado: $(if ($codigo -eq 0) { 'COMPILOU' } else { 'FALHOU' }) | fatal: $fatais | erros: $erros | warnings: $warnings | hints: $hints"
Write-Host ''
if ($porCodigo) {
  Write-Host 'Por código:'
  $porCodigo | Select-Object -First 25 | ForEach-Object { Write-Host ("  {0,-6} {1,5}x  {2}" -f $_.codigo, $_.quantidade, $_.exemplo) }
  Write-Host ''
}
$ordem = @{ fatal = 0; error = 1; warning = 2; hint = 3 }
$itens | Sort-Object { $ordem[$_.severidade] }, arquivo, linha | Select-Object -First $MaxItensConsole | ForEach-Object {
  Write-Host ("  [{0}] {1}({2}): {3} {4}" -f $_.severidade, $_.arquivo, $_.linha, $_.codigo, $_.mensagem)
}
if ($itens.Count -gt $MaxItensConsole) { Write-Host "  ... mais $($itens.Count - $MaxItensConsole) item(ns) no JSON." }
if ($outrosErros.Count -gt 0) {
  Write-Host ''
  Write-Host 'Outros erros (MSBuild/linker):'
  $outrosErros | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" }
}
Write-Host ''
Write-Host "Detalhes: $Saida"
Write-Host "Log bruto: $logBruto"

if ($codigo -eq 0) { exit 0 } else { exit 1 }
