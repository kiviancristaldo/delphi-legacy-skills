<#
.SYNOPSIS
  Testa o CRUD REST de um recurso (Horse ou outro servidor) e mostra o status de cada chamada:
  GET lista, POST, GET por id, PUT, DELETE, GET de id inexistente (404) e POST inválido (400).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Test-Endpoints.ps1 -BaseUrl http://localhost:9000 -Recurso produtos -Corpo '{"nome":"Teste skill","preco":9.9,"categoria":0,"ativo":true}'

.NOTES
  GRAVA E APAGA um registro: use um banco de cópia.
  -CorpoInvalido: JSON que deve ser recusado com 400 (padrão: nome vazio).
#>
param(
  [Parameter(Mandatory = $true)] [string]$BaseUrl,
  [Parameter(Mandatory = $true)] [string]$Recurso,
  [Parameter(Mandatory = $true)] [string]$Corpo,
  [string]$CorpoInvalido = '{"nome":""}',
  [string]$CampoId = 'id',
  [int]$IdInexistente = 999999999
)

$ErrorActionPreference = 'Stop'
$url = $BaseUrl.TrimEnd('/') + '/' + $Recurso.Trim('/')
$resultados = New-Object System.Collections.Generic.List[object]

function Chamar([string]$Nome, [string]$Metodo, [string]$Url, [string]$Json, [int[]]$Esperado) {
  $params = @{ Uri = $Url; Method = $Metodo; UseBasicParsing = $true; ContentType = 'application/json; charset=utf-8' }
  if ($Json) { $params.Body = [Text.Encoding]::UTF8.GetBytes($Json) }
  $status = 0; $conteudo = ''
  try {
    $r = Invoke-WebRequest @params
    $status = [int]$r.StatusCode
    $conteudo = $r.Content
  } catch {
    # Windows PowerShell 5.1 (WebException) e PowerShell 7 (HttpResponseException)
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    $conteudo = if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
  }
  $ok = $Esperado -contains $status
  $resultados.Add([pscustomobject]@{ Teste = $Nome; Metodo = $Metodo; Status = $status; Esperado = ($Esperado -join '/'); Resultado = $(if ($ok) { 'OK' } else { 'FALHOU' }) })
  $cor = if ($ok) { 'Green' } else { 'Red' }
  Write-Host ("{0,-7} {1,-28} {2}  (esperado {3})" -f $Metodo, $Nome, $status, ($Esperado -join '/')) -ForegroundColor $cor
  if (-not $ok -and $conteudo) { Write-Host "        $conteudo" }
  return $conteudo
}

Write-Host "Testando $url"
Chamar 'Listar' 'GET' $url '' @(200) | Out-Null

$criado = Chamar 'Incluir' 'POST' $url $Corpo @(201, 200)
$id = $null
try { $id = ($criado | ConvertFrom-Json).$CampoId } catch { }
if (-not $id) {
  Write-Host "Não consegui ler o campo '$CampoId' da resposta do POST; os testes por id foram pulados." -ForegroundColor Yellow
} else {
  Chamar 'Buscar por id' 'GET' "$url/$id" '' @(200) | Out-Null
  Chamar 'Alterar' 'PUT' "$url/$id" $Corpo @(200, 204) | Out-Null
  Chamar 'Excluir' 'DELETE' "$url/$id" '' @(204, 200) | Out-Null
  Chamar 'Buscar excluído (404)' 'GET' "$url/$id" '' @(404) | Out-Null
}
Chamar 'Buscar inexistente (404)' 'GET' "$url/$IdInexistente" '' @(404) | Out-Null
Chamar 'Incluir inválido (400)' 'POST' $url $CorpoInvalido @(400) | Out-Null

$falhas = @($resultados | Where-Object Resultado -eq 'FALHOU').Count
Write-Host ''
Write-Host "$($resultados.Count) chamadas, $falhas falha(s)."
exit $falhas
