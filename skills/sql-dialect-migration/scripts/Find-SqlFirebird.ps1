<#
.SYNOPSIS
  Procura construções SQL específicas do Firebird em .pas, .dfm, .inc e .sql de um projeto
  Delphi e mostra o que muda no PostgreSQL ou no SQL Server. Não altera nenhum arquivo.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Find-SqlFirebird.ps1 -Pasta C:\Projetos\MeuSistema -Destino PG -Recursivo

.OUTPUTS
  Resumo no console e relatório em <Pasta>\_migracao\sql-firebird-<Destino>.md
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [Parameter(Mandatory = $true)] [ValidateSet('PG', 'MSSQL')] [string]$Destino,
  [switch]$Recursivo,
  [int]$MaxDetalhesPorItem = 200
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path

# Nome | regex (sem diferenciar maiúsculas) | troca no PG | troca no SQL Server | risco
# Troca '-' = funciona igual no destino (o item não aparece no relatório desse destino)
$regras = @(
  @('FIRST/SKIP',            '\bSELECT\s+(DISTINCT\s+)?(FIRST|SKIP)\b',     'LIMIT n OFFSET m',                     'TOP n / OFFSET m ROWS FETCH NEXT n ROWS ONLY', 'médio'),
  @('ROWS m TO n',           '\bROWS\s+\d+\s+TO\s+\d+',                    'LIMIT/OFFSET',                         'OFFSET/FETCH',                          'médio'),
  @('GEN_ID',                '\bGEN_ID\s*\(',                              "nextval('seq')",                       'NEXT VALUE FOR seq',                    'alto'),
  @('NEXT VALUE FOR',        '\bNEXT\s+VALUE\s+FOR\b',                     "nextval('seq')",                       '-',                                     'médio'),
  @('CREATE/SET GENERATOR',  '\b(CREATE|SET|DROP)\s+GENERATOR\b',          'CREATE SEQUENCE / setval',             'CREATE SEQUENCE / ALTER SEQUENCE',      'médio'),
  @('FROM RDB$DATABASE',     '\bRDB\$DATABASE\b',                          'remover o FROM',                       'remover o FROM',                        'baixo'),
  @('Tabelas de sistema',    '\b(RDB|MON)\$(?!DATABASE\b)\w+',             'information_schema / pg_catalog',      'INFORMATION_SCHEMA / sys.*',            'alto'),
  @('CONTAINING',            '\bCONTAINING\b',                             "ILIKE '%x%'",                          "LIKE '%x%' (collation CI)",             'médio'),
  @('STARTING WITH',         '\bSTARTING\s+WITH\b',                        "LIKE 'x%'",                            "LIKE 'x%'",                             'baixo'),
  @("'NOW'/'TODAY'",         "'(NOW|TODAY|TOMORROW|YESTERDAY)'",           'CURRENT_TIMESTAMP / CURRENT_DATE',     'SYSDATETIME() / CAST(GETDATE() AS DATE)', 'baixo'),
  @('LIST()',                '\bLIST\s*\(',                                'string_agg()',                         'STRING_AGG() (2017+)',                  'baixo'),
  @('IIF()',                 '\bIIF\s*\(',                                 'CASE WHEN',                            '-',                                     'baixo'),
  @('DECODE()',              '\bDECODE\s*\(',                              'CASE',                                 'CASE',                                  'baixo'),
  @('Concatenação ||',       '\|\|',                                       '-',                                    '+ ou CONCAT() (NULL muda)',             'médio'),
  @('UPDATE OR INSERT',      '\bUPDATE\s+OR\s+INSERT\b',                   'INSERT ... ON CONFLICT',               'MERGE',                                 'alto'),
  @('RETURNING',             '\bRETURNING\b',                              '-',                                    'OUTPUT INSERTED.col',                   'médio'),
  @('EXECUTE PROCEDURE',     '\bEXECUTE\s+PROCEDURE\b',                    'CALL / SELECT função',                 'EXEC',                                  'médio'),
  @('EXECUTE BLOCK',         '\bEXECUTE\s+BLOCK\b',                        'DO $$...$$ ou função',                 'lote T-SQL / procedure',                'alto'),
  @('SUSPEND (selecionável)','\bSUSPEND\b',                                'RETURNS TABLE / RETURN NEXT',          'função com valor de tabela',            'alto'),
  @('DATEADD/DATEDIFF',      '\bDATE(ADD|DIFF)\s*\(',                      'aritmética com INTERVAL',              '-',                                     'médio'),
  @('EXTRACT WEEKDAY/YEARDAY','\bEXTRACT\s*\(\s*(WEEKDAY|YEARDAY)\b',      'DOW / DOY-1',                          'DATEPART (cuidado @@DATEFIRST)',        'alto'),
  @('SUBSTRING FROM/FOR',    '\bSUBSTRING\s*\([^)]*\bFROM\b',              '-',                                    'SUBSTRING(s, a, b)',                    'baixo'),
  @('POSITION()',            '\bPOSITION\s*\(',                            '-',                                    'CHARINDEX()',                           'baixo'),
  @('CHAR_LENGTH()',         '\b(CHAR|CHARACTER)_LENGTH\s*\(',             '-',                                    'LEN() (ignora espaços à direita)',      'baixo'),
  @('BLOB SUB_TYPE',         '\bBLOB\s+SUB_TYPE\b',                        'text / bytea',                         'VARCHAR(MAX) / VARBINARY(MAX)',         'baixo'),
  @('COMPUTED BY',           '\bCOMPUTED\s+BY\b',                          'GENERATED ALWAYS AS ... STORED',       'coluna calculada AS (...)',             'médio'),
  @('SET TERM',              '\bSET\s+TERM\b',                             'remover',                              'remover (GO no sqlcmd)',                'baixo'),
  @('PLAN / WITH LOCK',      '\bPLAN\s*\(|\bWITH\s+LOCK\b',                'remover / FOR UPDATE',                 'remover / UPDLOCK',                     'médio'),
  @('Data literal dd.mm.aaaa',"'\d{1,2}\.\d{1,2}\.\d{2,4}'",               'parâmetro',                            'parâmetro',                             'alto'),
  @('FormatDateTime no SQL', "FormatDateTime\s*\(\s*'[^']*'",              'parâmetro',                            'parâmetro',                             'alto'),
  @('Mensagem de erro por texto', "Pos\s*\(\s*'[^']*(violation|deadlock|lock conflict|update conflicts)",  'E.Kind (EFDDBEngineException)', 'E.Kind (EFDDBEngineException)', 'médio')
)

$col = if ($Destino -eq 'PG') { 2 } else { 3 }
$nomeDestino = if ($Destino -eq 'PG') { 'PostgreSQL' } else { 'SQL Server' }

$recurse = [bool]$Recursivo
$arquivos = @(Get-ChildItem -Path $Pasta -Include *.pas, *.dfm, *.inc, *.sql, *.dpr -File -Recurse:$recurse -ErrorAction SilentlyContinue)
if (-not $recurse) { $arquivos = @(Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.pas, *.dfm, *.inc, *.sql, *.dpr -File) }
$arquivos = $arquivos | Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao|_build)\\' }

$achados = @{}
foreach ($r in $regras) { $achados[$r[0]] = New-Object System.Collections.Generic.List[string] }

foreach ($f in $arquivos) {
  # DFM binário não tem SQL legível
  $fs = [IO.File]::OpenRead($f.FullName)
  try { $b = New-Object byte[] 64; $n = $fs.Read($b, 0, 64) } finally { $fs.Close() }
  if ((($n -ge 4 -and [Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'TPF0') -or ($n -ge 3 -and $b[0] -eq 0xFF -and $b[1] -eq 0x0A -and [Text.Encoding]::ASCII.GetString($b, 0, $n).Contains('TPF0')))) { continue }

  $rel = $f.FullName.Substring($Pasta.Length + 1)
  $i = 0
  foreach ($linha in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    $i++
    foreach ($r in $regras) {
      if ($r[$col] -eq '-') { continue }
      if ([regex]::IsMatch($linha, $r[1], 'IgnoreCase')) {
        $trecho = $linha.Trim()
        if ($trecho.Length -gt 160) { $trecho = $trecho.Substring(0, 157) + '...' }
        $achados[$r[0]].Add("$rel`:$i  $trecho")
      }
    }
  }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# SQL específico do Firebird → $nomeDestino")
$md.Add("")
$md.Add("Pasta: ``$Pasta`` | Arquivos analisados: $($arquivos.Count) | Gerado em: $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$md.Add("")
$md.Add("## Resumo")
$md.Add("| Construção | Ocorrências | Troca no $nomeDestino | Risco |")
$md.Add("|---|---|---|---|")
$total = 0
foreach ($r in $regras) {
  if ($r[$col] -eq '-') { continue }
  $qtd = $achados[$r[0]].Count
  $total += $qtd
  if ($qtd -gt 0) { $md.Add("| $($r[0]) | $qtd | $($r[$col]) | $($r[4]) |") }
}
$md.Add("")
$md.Add("Total: $total ocorrência(s). Itens sem ocorrência foram omitidos.")
$md.Add("")
$md.Add("## Detalhes")
foreach ($r in $regras) {
  if ($r[$col] -eq '-') { continue }
  $lista = $achados[$r[0]]
  if ($lista.Count -eq 0) { continue }
  $md.Add("")
  $md.Add("### $($r[0]) ($($lista.Count)) → $($r[$col])")
  $lista | Select-Object -First $MaxDetalhesPorItem | ForEach-Object { $md.Add("- ``$_``") }
  if ($lista.Count -gt $MaxDetalhesPorItem) { $md.Add("- ... mais $($lista.Count - $MaxDetalhesPorItem)") }
}

$saida = Join-Path $Pasta '_migracao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arquivo = Join-Path $saida "sql-firebird-$Destino.md"
$md | Set-Content -Path $arquivo -Encoding UTF8

Write-Host "SQL específico do Firebird → $nomeDestino ($($arquivos.Count) arquivos)"
foreach ($r in $regras) {
  if ($r[$col] -eq '-') { continue }
  $qtd = $achados[$r[0]].Count
  if ($qtd -gt 0) { Write-Host ("  {0,-28} {1,5}x  → {2}  [risco {3}]" -f $r[0], $qtd, $r[$col], $r[4]) }
}
Write-Host "Total: $total ocorrência(s). Relatório: $arquivo"
