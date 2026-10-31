<#
.SYNOPSIS
  Aplica as regras OFICIAIS do reFind (BDE, ADO ou dbExpress → FireDAC) num projeto
  Delphi, com correções conhecidas dos arquivos oficiais e regras extras do projeto.

.DESCRIPTION
  1. Localiza reFind.exe (bin do RAD Studio) e o arquivo oficial de regras em
     Public\Documents\Embarcadero\Studio\<versão>\Samples\Object Pascal\Database\FireDAC\Tool\reFind
  2. Recusa rodar se o Git tiver alterações não commitadas (use -SemGit para forçar com .bak).
  3. Recusa rodar se houver DFM binário.
  4. Monta <Pasta>\_migracao\regras-efetivas-<Origem>.txt =
       regras extras do projeto + regras oficiais com correções aplicadas.
  5. Executa o reFind em *.pas, *.dfm e *.fmx.
  6. Lista o que sobrou do acesso legado em _migracao\pendencias-<Origem>.txt.

.EXAMPLE
  # Só monta e mostra as regras, sem alterar nada
  powershell -ExecutionPolicy Bypass -File Invoke-ReFind.ps1 -Origem BDE -Pasta C:\Projetos\MeuSistema -Simular

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Invoke-ReFind.ps1 -Origem DBX -Pasta C:\Projetos\MeuSistema -Recursivo -RegrasExtras _migracao\regras-do-projeto.txt
#>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('BDE', 'ADO', 'DBX')] [string]$Origem,
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [string[]]$RegrasExtras = @(),
  [string]$VersaoBDS = '37.0',
  [string]$PastaRegrasOficiais = '',
  [switch]$Recursivo,
  [switch]$SemGit,
  [switch]$Simular
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path

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

# ---------- 1. Ferramentas e regras oficiais ----------
$root = Get-BdsRoot $VersaoBDS
$refind = Join-Path $root 'bin\reFind.exe'
if (-not (Test-Path $refind)) { throw "reFind.exe não encontrado em $refind. Confira -VersaoBDS." }

if (-not $PastaRegrasOficiais) {
  $PastaRegrasOficiais = Join-Path $env:PUBLIC "Documents\Embarcadero\Studio\$VersaoBDS\Samples\Object Pascal\Database\FireDAC\Tool\reFind"
}
$arquivoOficial = Join-Path $PastaRegrasOficiais "${Origem}2FDMigration\FireDAC_Migrate_$Origem.txt"
if (-not (Test-Path $arquivoOficial)) { throw "Regras oficiais não encontradas: $arquivoOficial" }

# ---------- 2. Git ----------
# Programas externos (git, reFind) escrevem em stderr; no Windows PowerShell 5.1 isso
# vira erro terminante com 'Stop'. Durante essas chamadas usamos 'Continue'.
$ErrorActionPreference = 'Continue'

$temGit = $false
if (Get-Command git -ErrorAction SilentlyContinue) {
  & git -C $Pasta rev-parse --is-inside-work-tree 2>$null | Out-Null
  $temGit = ($LASTEXITCODE -eq 0)
}
if ($temGit) {
  # A pasta _migracao (relatórios e regras desta skill) não bloqueia a execução
  $pendente = @(& git -C $Pasta status --porcelain) | Where-Object { $_ -and $_ -notmatch '_migracao' }
  if ($pendente -and -not $Simular) {
    Write-Host 'PARE: há alterações não commitadas. Faça commit antes de migrar:'
    $pendente | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
    exit 3
  }
} elseif (-not $SemGit -and -not $Simular) {
  Write-Host 'PARE: a pasta não está num repositório Git. Crie um (git init + commit) ou use -SemGit (o reFind criará .bak).'
  exit 3
}
$ErrorActionPreference = 'Stop'

# ---------- 3. DFMs binários ----------
$recurse = [bool]$Recursivo
$forms = @(Get-ChildItem -Path $Pasta -Include *.dfm, *.fmx -File -Recurse:$recurse -ErrorAction SilentlyContinue)
if (-not $recurse) { $forms = @(Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.dfm, *.fmx -File) }
$binarios = @()
foreach ($f in $forms) {
  $fs = [IO.File]::OpenRead($f.FullName)
  try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4) } finally { $fs.Close() }
  if ($n -eq 4 -and [Text.Encoding]::ASCII.GetString($b) -eq 'TPF0') { $binarios += $f.FullName }
}
if ($binarios.Count -gt 0) {
  Write-Host "PARE: $($binarios.Count) DFM(s) binário(s). Converta para texto com $(Join-Path $root 'bin\convert.exe') -t <arquivo>:"
  $binarios | ForEach-Object { Write-Host "  $_" }
  exit 4
}

# ---------- 4. Regras efetivas ----------
$correcoes = @(
  @{ Padrao = '\bTSQLConnecion:'; Troca = 'TSQLConnection:';
     Motivo = 'Erro de digitação no arquivo oficial DBX: as regras de TSQLConnection nunca casavam.' },
  @{ Padrao = 'FireDAC\.Stan\.Params\b'; Troca = 'FireDAC.Stan.Param';
     Motivo = 'A unit FireDAC.Stan.Params não existe (o nome certo é FireDAC.Stan.Param).' }
)

$oficial = [IO.File]::ReadAllText($arquivoOficial, [Text.Encoding]::Default)
$aplicadas = @()
foreach ($c in $correcoes) {
  $qtd = [regex]::Matches($oficial, $c.Padrao).Count
  if ($qtd -gt 0) {
    $oficial = [regex]::Replace($oficial, $c.Padrao, $c.Troca)
    $aplicadas += "$($c.Motivo) ($qtd linha(s) corrigida(s))"
  }
}

$extras = ''
foreach ($r in $RegrasExtras) {
  $caminho = if ([IO.Path]::IsPathRooted($r)) { $r } else { Join-Path $Pasta $r }
  if (-not (Test-Path $caminho)) { throw "Arquivo de regras extras não encontrado: $caminho" }
  $extras += "; ===== Regras do projeto: $([IO.Path]::GetFileName($caminho)) =====`r`n"
  $extras += [IO.File]::ReadAllText($caminho, [Text.Encoding]::Default) + "`r`n"
}

$saida = Join-Path $Pasta '_migracao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$efetivo = Join-Path $saida "regras-efetivas-$Origem.txt"
$conteudo = $extras + "; ===== Regras oficiais: $arquivoOficial (com correções) =====`r`n" + $oficial
[IO.File]::WriteAllText($efetivo, $conteudo, [Text.Encoding]::Default)

Write-Host "reFind:        $refind"
Write-Host "Regras:        $efetivo"
if ($aplicadas.Count -gt 0) {
  Write-Host 'Correções aplicadas nas regras oficiais:'
  $aplicadas | ForEach-Object { Write-Host "  - $_" }
}

if ($Simular) {
  Write-Host ''
  Write-Host 'Modo -Simular: nada foi alterado. Revise o arquivo de regras acima.'
  exit 0
}

# ---------- 5. Executa ----------
# /B:0 (padrão do reFind) NÃO substitui nada se já existir .bak: numa segunda rodada
# ele "funciona" sem mudar nada. Por isso: com Git, /B:2 (sem .bak); sem Git, /B:1.
$backup = if ($temGit) { '/B:2' } else { '/B:1' }
$argumentos = @('*.pas', '*.dfm')
if (@($forms | Where-Object { $_.Extension -eq '.fmx' }).Count -gt 0) { $argumentos += '*.fmx' }
if ($recurse) { $argumentos += '/S' }
$argumentos += $backup
$argumentos += "/X:$efetivo"

$ErrorActionPreference = 'Continue'
Push-Location $Pasta
try {
  Write-Host "Executando: reFind $($argumentos -join ' ')"
  & $refind @argumentos
  $codigo = $LASTEXITCODE
} finally { Pop-Location }
Write-Host "reFind terminou com código $codigo."

# ---------- 6. O que sobrou ----------
$residuos = @{
  BDE = '\bDBTables\b|\bBDEConst\b|\bT(Table|Query|Database|Session|StoredProc|UpdateSQL|BatchMove)\b|\bTableType\s*=|\bOnUpdateRecord\b|\bOnUpdateError\b|\bEDBEngineError\b'
  ADO = '\bADODB\b|\bTADO\w+|\bConnectionString\s*=|\bProvider\s*=|\bRecordset\b|\bOnUpdateRecord\b|\bParameters\b'
  DBX = '\bSqlExpr\b|\bDBXCommon\b|\bTSQL(Connection|Query|DataSet|Table|StoredProc|Monitor)\b|\bTSimpleDataSet\b|\bVendorLib\s*=|\bDriverName\s*=|\bTTransactionDesc\b|\bLoadParamsOnConnect\b'
}[$Origem]

$alvos = @(Get-ChildItem -Path $Pasta -Include *.pas, *.dfm, *.fmx, *.dpr -File -Recurse:$recurse -ErrorAction SilentlyContinue)
if (-not $recurse) { $alvos = @(Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.pas, *.dfm, *.fmx, *.dpr -File) }
$alvos = $alvos | Where-Object { $_.FullName -notmatch '\\_migracao\\' }
$hits = @($alvos | Select-String -Pattern $residuos -ErrorAction SilentlyContinue)
$arqPend = Join-Path $saida "pendencias-$Origem.txt"
$hits | ForEach-Object { "$($_.Path.Substring($Pasta.Length + 1)):$($_.LineNumber): $($_.Line.Trim())" } |
  Set-Content -Path $arqPend -Encoding UTF8
Write-Host "Pendências encontradas: $($hits.Count) linha(s). Lista completa em $arqPend"
$hits | Select-Object -First 40 | ForEach-Object { Write-Host "  $($_.Filename):$($_.LineNumber): $($_.Line.Trim())" }

# Units auxiliares de migração adicionadas pelas regras oficiais (FireDAC.ADO.Migrate / FireDAC.DBX.Migrate)
$migrate = @($alvos | Where-Object { $_.Extension -eq '.pas' } |
             Select-String -Pattern 'FireDAC\.(ADO|DBX)\.Migrate' -List -ErrorAction SilentlyContinue)
if ($migrate.Count -gt 0) {
  $fonte = Get-ChildItem -Path (Join-Path $root 'source') -Filter 'FireDAC.*.Migrate.pas' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  Write-Host ''
  Write-Host "$($migrate.Count) unit(s) passaram a usar FireDAC.$Origem.Migrate (helpers de compatibilidade)."
  if ($fonte) {
    Write-Host "Se o compilador não achar a unit, adicione ao search path: $($fonte.DirectoryName)"
  } else {
    Write-Host 'Fonte da unit .Migrate não encontrada em $(BDS)\source. Se der F2613, troque os helpers pelo código FireDAC nativo.'
  }
}

if ($temGit) {
  Write-Host ''
  Write-Host 'Resumo das alterações (git diff --stat):'
  & git -C $Pasta diff --stat | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
}
Write-Host ''
Write-Host 'Próximo passo: compilar com a skill delphi-compile-loop e rodar o teste de carga de forms.'
exit $codigo
