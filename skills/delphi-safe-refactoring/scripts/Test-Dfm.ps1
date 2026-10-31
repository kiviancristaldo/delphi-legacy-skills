<#
.SYNOPSIS
  Confere se arquivos .dfm em texto têm sintaxe válida, convertendo uma CÓPIA de cada um
  para binário com o convert.exe do RAD Studio. O arquivo original não é alterado.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Test-Dfm.ps1 -Arquivos "C:\proj\src\Views\frmProdutos.dfm,C:\proj\src\Views\frmClientes.dfm"

.NOTES
  Detecta erro de sintaxe (aspas, object/end desbalanceados, valor mal formado).
  Não detecta propriedade inexistente na classe: isso aparece ao compilar/abrir o form
  (use o teste de carga de forms da skill delphi-characterization-tests).
#>
param(
  [Parameter(Mandatory = $true)] [string]$Arquivos,
  [string]$VersaoBDS = '37.0'
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

$convert = Join-Path (Get-BdsRoot $VersaoBDS) 'bin\convert.exe'
if (-not (Test-Path $convert)) { Write-Host "convert.exe não encontrado em $convert. Confira -VersaoBDS."; exit 2 }

$temp = Join-Path $env:TEMP ("dfm-check-{0}" -f $PID)
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$falhas = 0

try {
  foreach ($dfm in ($Arquivos -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    if (-not (Test-Path $dfm)) { Write-Host "NÃO ENCONTRADO  $dfm"; $falhas++; continue }
    $copia = Join-Path $temp ([IO.Path]::GetFileName($dfm))
    Copy-Item -Path $dfm -Destination $copia -Force

    $ErrorActionPreference = 'Continue'
    $saida = (& $convert -i $copia 2>&1 | Out-String)
    $ErrorActionPreference = 'Stop'

    # Sucesso = a cópia virou binário (assinatura TPF0)
    $fs = [IO.File]::OpenRead($copia)
    try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4) } finally { $fs.Close() }
    if ($n -eq 4 -and [Text.Encoding]::ASCII.GetString($b) -eq 'TPF0') {
      Write-Host "OK     $dfm"
    } else {
      $falhas++
      Write-Host "ERRO   $dfm" -ForegroundColor Red
      Write-Host ($saida.Trim())
    }
  }
} finally {
  Remove-Item -Path $temp -Recurse -Force -ErrorAction SilentlyContinue
}

exit $falhas
