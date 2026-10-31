<#
.SYNOPSIS
  Converte arquivos Delphi para a codificação do projeto (ANSI cp1252 ou UTF-8 com BOM),
  sempre com quebra de linha CRLF. Use depois da ÚLTIMA edição de cada arquivo.

.DESCRIPTION
  Detecta a codificação atual de cada arquivo (UTF-8 com BOM, UTF-8 sem BOM ou ANSI)
  e regrava na codificação pedida. Arquivos .dproj/.groupproj ficam sempre em UTF-8 com BOM.
  Avisa quando:
  - um caractere não existe em cp1252 (seria perdido no ANSI);
  - um .dfm tem caractere não ASCII (use escape: 'Pre'#231'o').

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Normalize-Encoding.ps1 -Encoding Ansi -Arquivos "C:\proj\src\Models\Models.Produtos.pas,C:\proj\src\Views\frmProdutos.dfm"
#>
param(
  [Parameter(Mandatory = $true)] [string]$Arquivos,
  [Parameter(Mandatory = $true)] [ValidateSet('Ansi', 'Utf8Bom')] [string]$Encoding
)

$ErrorActionPreference = 'Stop'
$cp1252 = [Text.Encoding]::GetEncoding(1252)
$utf8Estrito = New-Object System.Text.UTF8Encoding($false, $true)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
$problemas = 0

foreach ($caminho in ($Arquivos -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  if (-not (Test-Path $caminho)) { Write-Host "NÃO ENCONTRADO  $caminho"; $problemas++; continue }
  $bytes = [IO.File]::ReadAllBytes($caminho)

  # 1. Detectar a codificação atual
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $origem = 'UTF-8 com BOM'
    $texto = $utf8Estrito.GetString($bytes, 3, $bytes.Length - 3)
  } else {
    try {
      $texto = $utf8Estrito.GetString($bytes)
      $origem = 'UTF-8 sem BOM'
    } catch {
      $texto = $cp1252.GetString($bytes)
      $origem = 'ANSI'
    }
  }

  # 2. Quebras de linha CRLF
  $texto = ($texto -replace "`r`n", "`n") -replace "`r", "`n"
  $texto = $texto -replace "`n", "`r`n"

  # 3. Destino
  $ext = [IO.Path]::GetExtension($caminho).ToLower()
  $destino = if ($ext -in @('.dproj', '.groupproj')) { 'Utf8Bom' } else { $Encoding }

  if ($destino -eq 'Ansi') {
    $novo = $cp1252.GetBytes($texto)
    if ($cp1252.GetString($novo) -ne $texto) {
      Write-Host "AVISO           $caminho tem caracteres que não existem em cp1252 (viraram '?'). Use Utf8Bom ou troque o texto." -ForegroundColor Yellow
      $problemas++
    }
  } else {
    $novo = $utf8Bom.GetPreamble() + $utf8Bom.GetBytes($texto)
  }

  if ($ext -in @('.dfm', '.fmx') -and $texto -match '[^\x00-\x7F]') {
    Write-Host "AVISO           $caminho tem caractere não ASCII. No .dfm, use escape: 'Pre'#231'o'." -ForegroundColor Yellow
    $problemas++
  }

  [IO.File]::WriteAllBytes($caminho, [byte[]]$novo)
  Write-Host ("OK              {0}  ({1} -> {2}, CRLF)" -f $caminho, $origem, $destino)
}

if ($problemas -gt 0) { Write-Host "$problemas aviso(s). Revise antes de compilar."; exit 1 }
exit 0
