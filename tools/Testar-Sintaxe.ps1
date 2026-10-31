<#
.SYNOPSIS
  Confere a sintaxe de todos os scripts PowerShell do kit, sem executá-los.
  É o primeiro teste a rodar depois de clonar o repositório.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\Testar-Sintaxe.ps1
#>
$raiz = Split-Path -Parent $PSScriptRoot
$scripts = Get-ChildItem -Path (Join-Path $raiz 'skills') -Filter *.ps1 -Recurse
$falhas = 0

foreach ($s in $scripts) {
  $tokens = $null
  $erros = $null
  [System.Management.Automation.Language.Parser]::ParseFile($s.FullName, [ref]$tokens, [ref]$erros) | Out-Null

  # Sem BOM, o Windows PowerShell 5.1 lê os acentos errado
  $bytes = [IO.File]::ReadAllBytes($s.FullName)
  $temBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF

  $rel = $s.FullName.Substring($raiz.Length + 1)
  if ($erros.Count -eq 0 -and $temBom) {
    Write-Host "OK     $rel"
  } else {
    $falhas++
    Write-Host "FALHA  $rel" -ForegroundColor Red
    if (-not $temBom) { Write-Host '       arquivo sem BOM UTF-8' }
    foreach ($e in $erros) { Write-Host ("       linha {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) }
  }
}

Write-Host ''
Write-Host "PowerShell $($PSVersionTable.PSVersion) · $($scripts.Count) scripts · $falhas com problema"
exit $falhas
