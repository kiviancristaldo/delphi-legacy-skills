<#
.SYNOPSIS
  Testa o CRUD REST de um recurso (Horse ou outro servidor) e mostra o status de cada chamada:
  GET lista, POST, GET por id, PUT, DELETE, GET de id inexistente (404) e POST inválido (400).

.EXAMPLE
  # Num prompt do PowerShell: chame o script com & (o JSON chega intacto)
  & .\Test-Endpoints.ps1 -BaseUrl http://localhost:9000 -Recurso produtos -Corpo '{"nome":"Teste skill","preco":9.9,"categoria":0,"ativo":true}'

.EXAMPLE
  # Com powershell -File (ou a partir do cmd.exe), passe o JSON em arquivo
  powershell -ExecutionPolicy Bypass -File Test-Endpoints.ps1 -BaseUrl http://localhost:9000 -Recurso produtos -CorpoArquivo corpo.json -CorpoInvalidoArquivo invalido.json

.NOTES
  GRAVA E APAGA um registro: use um banco de cópia.
  -CorpoInvalido: JSON que deve ser recusado com 400. O padrão (nome vazio) só serve se o
  assunto exige nome; informe um corpo que viole uma regra real do Controller.
  Não use "powershell -File ... -Corpo '{...}'" a partir do PowerShell 5.1: ele remove as
  aspas duplas internas e o servidor recebe JSON inválido (o 400 do teste inválido passaria
  pelo motivo errado). O script avisa se o corpo não for JSON válido.
#>
param(
  [Parameter(Mandatory = $true)] [string]$BaseUrl,
  [Parameter(Mandatory = $true)] [string]$Recurso,
  [string]$Corpo = '',
  [string]$CorpoArquivo = '',
  [string]$CorpoInvalido = '{"nome":""}',
  [string]$CorpoInvalidoArquivo = '',
  [string]$CampoId = 'id',
  [int]$IdInexistente = 999999999
)

$ErrorActionPreference = 'Stop'

if ($CorpoArquivo) { $Corpo = [IO.File]::ReadAllText((Resolve-Path $CorpoArquivo).Path, [Text.Encoding]::UTF8) }
if ($CorpoInvalidoArquivo) { $CorpoInvalido = [IO.File]::ReadAllText((Resolve-Path $CorpoInvalidoArquivo).Path, [Text.Encoding]::UTF8) }
if (-not $Corpo) { Write-Host 'Informe -Corpo ou -CorpoArquivo.'; exit 2 }

# Os dois corpos precisam ser JSON válido: o inválido deve violar uma REGRA, não a sintaxe
foreach ($par in @(@('Corpo', $Corpo), @('CorpoInvalido', $CorpoInvalido))) {
  try { $null = $par[1] | ConvertFrom-Json }
  catch {
    Write-Host "O parâmetro -$($par[0]) não é JSON válido: $($par[1])" -ForegroundColor Red
    Write-Host 'Se você chamou com powershell -File, as aspas duplas foram removidas: use & .\Test-Endpoints.ps1 ou -CorpoArquivo.'
    exit 2
  }
}
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
