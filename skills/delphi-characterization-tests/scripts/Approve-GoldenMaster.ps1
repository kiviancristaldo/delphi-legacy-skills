<#
.SYNOPSIS
  Aprova saídas de golden master: renomeia *.received.txt para *.approved.txt.

.EXAMPLE
  # Aprovar tudo (só depois que o usuário revisou!)
  powershell -ExecutionPolicy Bypass -File Approve-GoldenMaster.ps1 -Pasta Testes\approved

.EXAMPLE
  # Aprovar um caso específico
  powershell -ExecutionPolicy Bypass -File Approve-GoldenMaster.ps1 -Pasta Testes\approved -Nome Pedido_123_Itens
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [string]$Nome = ''
)

$ErrorActionPreference = 'Stop'
$filtro = if ($Nome) { "$Nome.received.txt" } else { '*.received.txt' }
$arquivos = @(Get-ChildItem -Path $Pasta -Filter $filtro -File -ErrorAction SilentlyContinue)

if ($arquivos.Count -eq 0) {
  Write-Host 'Nenhum arquivo .received.txt para aprovar.'
  exit 0
}

foreach ($f in $arquivos) {
  $destino = $f.FullName -replace '\.received\.txt$', '.approved.txt'
  Move-Item -Path $f.FullName -Destination $destino -Force
  Write-Host "Aprovado: $([IO.Path]::GetFileName($destino))"
}
Write-Host "$($arquivos.Count) saída(s) aprovada(s). Lembre de versionar a pasta approved no Git."
