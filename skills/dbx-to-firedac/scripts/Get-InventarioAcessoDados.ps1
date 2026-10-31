<#
.SYNOPSIS
  Inventário do acesso a dados legado (BDE, ADO ou dbExpress) de um projeto Delphi,
  antes da migração para FireDAC. Não altera nenhum arquivo do projeto.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Get-InventarioAcessoDados.ps1 -Origem BDE -Pasta C:\Projetos\MeuSistema -Recursivo

.OUTPUTS
  Resumo no console e relatório completo em <Pasta>\_migracao\inventario-<Origem>.md
#>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('BDE', 'ADO', 'DBX')] [string]$Origem,
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [switch]$Recursivo
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path

$perfil = @{
  BDE = @{
    Units   = 'DBTables|BDE|BDEConst|BDEMTS|Bde\.DBTables|Bde\.BDEConst'
    Classes = '^T(Table|Query|Database|Session|StoredProc|UpdateSQL|BatchMove|NestedTable)$'
    Props   = @('DatabaseName', 'SessionName', 'TableType', 'PrivateDir')
  }
  ADO = @{
    Units   = 'ADODB|Data\.Win\.ADODB|ADOInt|Winapi\.ADOInt|OleDB|Winapi\.OleDB'
    Classes = '^TADO(Connection|Query|Table|StoredProc|DataSet|Command)$'
    Props   = @('ConnectionString', 'Provider', 'LockType', 'CursorLocation', 'CursorType', 'CommandType')
  }
  DBX = @{
    Units   = 'SqlExpr|Data\.SqlExpr|DBXCommon|Data\.DBXCommon|SimpleDS|Data\.SimpleDS|DBXDynalink|Data\.Dbx\w+|DBConnAdmin'
    Classes = '^T(SQLConnection|SQLQuery|SQLDataSet|SQLTable|SQLStoredProc|SimpleDataSet|SQLMonitor)$'
    Props   = @('DriverName', 'VendorLib', 'LibraryName', 'GetDriverFunc', 'ConnectionName', 'LoadParamsOnConnect')
  }
}[$Origem]

$recurse = [bool]$Recursivo
$pas = @(Get-ChildItem -Path $Pasta -Include *.pas, *.dpr -File -Recurse:$recurse -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao)\\' })
if (-not $recurse) { $pas = @(Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.pas, *.dpr -File) }
$forms = @(Get-ChildItem -Path $Pasta -Include *.dfm, *.fmx -File -Recurse:$recurse -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao)\\' })
if (-not $recurse) { $forms = @(Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.dfm, *.fmx -File) }

$rel = New-Object System.Collections.Generic.List[string]
$rel.Add("# Inventário $Origem → FireDAC")
$rel.Add("")
$rel.Add("Pasta: ``$Pasta``  ")
$rel.Add("Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$rel.Add("")

# 1. DFMs binários (o reFind só trabalha com DFM texto)
$binarios = @()
foreach ($f in $forms) {
  $fs = [IO.File]::OpenRead($f.FullName)
  try {
    $b = New-Object byte[] 64
    $n = $fs.Read($b, 0, 64)
  } finally { $fs.Close() }
  if ((($n -ge 4 -and [Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'TPF0') -or ($n -ge 3 -and $b[0] -eq 0xFF -and $b[1] -eq 0x0A -and [Text.Encoding]::ASCII.GetString($b, 0, $n).Contains('TPF0')))) { $binarios += $f }
}
$rel.Add("## 1. DFMs em formato binário: $($binarios.Count)")
if ($binarios.Count -gt 0) {
  $rel.Add("Converta para texto ANTES do reFind: ``convert.exe -t <arquivo.dfm>`` (fica na pasta bin do RAD Studio).")
  foreach ($b in $binarios) { $rel.Add("- $($b.FullName.Substring($Pasta.Length + 1))") }
}
$rel.Add("")

# 2. Units com uses do acesso legado
$rel.Add("## 2. Units que usam $Origem no uses")
$unitsComUso = @()
foreach ($f in $pas) {
  $texto = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default)
  if ($texto -match "(?is)\buses\b[^;]*?\b($($perfil.Units))\b") { $unitsComUso += $f }
}
$rel.Add("Total: $($unitsComUso.Count)")
foreach ($u in $unitsComUso) { $rel.Add("- $($u.FullName.Substring($Pasta.Length + 1))") }
$rel.Add("")

# 3. Componentes nos DFMs por classe
$rel.Add("## 3. Componentes nos DFMs")
$contagem = @{}
$porForm = @{}
foreach ($f in ($forms | Where-Object { $binarios -notcontains $_ })) {
  foreach ($linha in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    if ($linha -match '^\s*(object|inherited|inline)\s+\w+\s*:\s*(\w+)') {
      $classe = $Matches[2]
      if ($classe -match $perfil.Classes) {
        $contagem[$classe] = 1 + [int]$contagem[$classe]
        $porForm[$f.Name] = 1 + [int]$porForm[$f.Name]
      }
    }
  }
}
$rel.Add("| Classe | Quantidade |")
$rel.Add("|---|---|")
foreach ($k in ($contagem.Keys | Sort-Object)) { $rel.Add("| $k | $($contagem[$k]) |") }
$rel.Add("")
$rel.Add("Forms/DataModules com componentes $Origem`: $($porForm.Count)")
$rel.Add("")

# 4. Classes próprias herdando dos componentes legados (exigem regras extras)
$rel.Add("## 4. Classes do projeto que herdam de componentes $Origem")
$rel.Add("O reFind oficial NÃO conhece essas classes. Gere regras em regras-do-projeto.txt.")
$heranca = @()
foreach ($f in $pas) {
  $i = 0
  foreach ($linha in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    $i++
    if ($linha -match '(\w+)\s*=\s*class\s*\(\s*(\w+)\s*\)') {
      if ($Matches[2] -match $perfil.Classes) {
        $heranca += "- ``$($Matches[1])`` herda de ``$($Matches[2])`` ($($f.Name):$i)"
      }
    }
  }
}
if ($heranca.Count -eq 0) { $rel.Add("Nenhuma encontrada.") } else { $heranca | ForEach-Object { $rel.Add($_) } }
$rel.Add("")

# 5. Componentes de terceiros conhecidos que dependem do acesso legado
$rel.Add("## 5. Componentes de terceiros que podem depender de $Origem")
$terceiros = 'Tww(Table|Query|StoredProc)|TRx(Query|Table)|TIB\w+|TDBISAM\w+|TkbmMemTable|TQuickRep'
$achados = @{}
foreach ($f in ($forms | Where-Object { $binarios -notcontains $_ })) {
  foreach ($linha in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    if ($linha -match "^\s*(object|inherited|inline)\s+\w+\s*:\s*($terceiros)\b") {
      $achados[$Matches[2]] = 1 + [int]$achados[$Matches[2]]
    }
  }
}
if ($achados.Count -eq 0) { $rel.Add("Nenhum dos conhecidos encontrado.") }
else { foreach ($k in ($achados.Keys | Sort-Object)) { $rel.Add("- $k`: $($achados[$k])") } }
$rel.Add("")

# 6. Propriedades nos DFMs que precisam de atenção manual
$rel.Add("## 6. Propriedades nos DFMs que exigem revisão manual")
foreach ($p in $perfil.Props) {
  $hits = @($forms | Where-Object { $binarios -notcontains $_ } |
            Select-String -Pattern "^\s*$p\s*=" -ErrorAction SilentlyContinue)
  $rel.Add("- ``$p``: $($hits.Count) ocorrência(s)")
}
$rel.Add("")

# 6b. Campos persistentes específicos do dbExpress
if ($Origem -eq 'DBX') {
  $ts = @($forms | Where-Object { $binarios -notcontains $_ } |
          Select-String -Pattern '^\s*(object|inherited)\s+\w+\s*:\s*TSQLTimeStampField\b' -ErrorAction SilentlyContinue)
  $rel.Add("## 6b. Campos TSQLTimeStampField: $($ts.Count)")
  $rel.Add("Confira, depois do reFind, a classe que o FireDAC cria para essas colunas (dtDateTimeStamp → TSQLTimeStampField;")
  $rel.Add("com FormatOptions.MapRules pode virar TDateTimeField) e deixe os campos persistentes iguais: divergência dá 'Type mismatch' ao abrir o form.")
  $ts | Select-Object -First 30 | ForEach-Object { $rel.Add("- $($_.Filename):$($_.LineNumber) ``$($_.Line.Trim())``") }
  $rel.Add("")
}
# 7. Sinais de Paradox/dBase (BDE) e de arquivos locais (ADO/Jet)
if ($Origem -eq 'BDE') {
  $local = @($forms | Where-Object { $binarios -notcontains $_ } |
             Select-String -Pattern "TableType\s*=\s*tt(Paradox|DBase|FoxPro|ASCII)|TableName\s*=\s*'[^']+\.(db|dbf)'" -ErrorAction SilentlyContinue)
  $rel.Add("## 7. Tabelas locais Paradox/dBase: $($local.Count) indício(s)")
  $rel.Add("FireDAC NÃO acessa Paradox/dBase nativamente: os dados precisam ir para um banco real (Firebird, SQLite...).")
  $local | Select-Object -First 30 | ForEach-Object { $rel.Add("- $($_.Filename):$($_.LineNumber) ``$($_.Line.Trim())``") }
}
if ($Origem -eq 'ADO') {
  $cs = @($forms + $pas | Where-Object { $binarios -notcontains $_ } |
          Select-String -Pattern "Provider\s*=\s*[\w\.]+" -AllMatches -ErrorAction SilentlyContinue)
  $provs = $cs | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value -replace '\s', '' } | Sort-Object -Unique
  $rel.Add("## 7. Providers OLE DB encontrados nas ConnectionStrings")
  if ($provs) { $provs | ForEach-Object { $rel.Add("- $_") } } else { $rel.Add("Nenhum encontrado (podem estar em arquivo .udl ou .ini).") }
}
if ($Origem -eq 'DBX') {
  $ini = @(Get-ChildItem -Path $Pasta -Filter 'dbxconnections.ini' -File -Recurse:$recurse -ErrorAction SilentlyContinue)
  $rel.Add("## 7. Arquivos dbxconnections.ini: $($ini.Count)")
  $rel.Add("Precisam virar FDConnectionDefs.ini (ou Params no TFDConnection).")
  $ini | ForEach-Object { $rel.Add("- $($_.FullName)") }
}

$saida = Join-Path $Pasta '_migracao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arquivo = Join-Path $saida "inventario-$Origem.md"
$rel | Set-Content -Path $arquivo -Encoding UTF8

$rel | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Relatório salvo em $arquivo"
