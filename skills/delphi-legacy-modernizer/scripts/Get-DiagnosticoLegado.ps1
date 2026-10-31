<#
.SYNOPSIS
  Diagnóstico de um sistema Delphi legado: tamanho, métodos gigantes, eventos com regra de
  negócio, DataModules inchados, código duplicado, acoplamento entre units, variáveis
  globais, "with" e custo estimado em tokens para uma IA ler o código.
  Não altera nenhum arquivo do projeto.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Get-DiagnosticoLegado.ps1 -Pasta C:\Projetos\MeuSistema -Recursivo

.EXAMPLE
  # Ignorar componentes de terceiros e comparar com um diagnóstico anterior
  powershell -ExecutionPolicy Bypass -File Get-DiagnosticoLegado.ps1 -Pasta C:\Projetos\MeuSistema -Recursivo -Excluir 'ACBr|Componentes|Lib' -Comparar _modernizacao\diagnostico-2026-10-01.json

.OUTPUTS
  <Pasta>\_modernizacao\diagnostico.md   (relatório)
  <Pasta>\_modernizacao\diagnostico-<data>.json (métricas para comparar antes × depois)

.NOTES
  Análise por texto (heurística), não por compilador: os números são aproximados e servem
  para priorizar, não para auditoria. Tokens estimados em ~4 caracteres por token.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [switch]$Recursivo,
  [string]$Excluir = '',
  [int]$LimiteLinhasUnit = 2000,
  [int]$LimiteLinhasMetodo = 80,
  [int]$LimiteComponentesDM = 60,
  [int]$JanelaDuplicacao = 8,
  [int]$Top = 15,
  [string]$Comparar = ''
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path
$recurse = [bool]$Recursivo

function Get-Arquivos([string[]]$Extensoes) {
  $lista = if ($recurse) {
    Get-ChildItem -Path $Pasta -Include $Extensoes -File -Recurse -ErrorAction SilentlyContinue
  } else {
    Get-ChildItem -Path (Join-Path $Pasta '*') -Include $Extensoes -File
  }
  $lista = @($lista | Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao|_modernizacao|_build|Win32|Win64)\\' })
  if ($Excluir) { $lista = @($lista | Where-Object { $_.FullName.Substring($Pasta.Length) -notmatch $Excluir }) }
  return $lista
}
function Rel([string]$Caminho) { return $Caminho.Substring($Pasta.Length + 1) }

$pas = Get-Arquivos @('*.pas')
$dfm = Get-Arquivos @('*.dfm')
if ($pas.Count -eq 0) { Write-Host "Nenhum .pas encontrado em $Pasta"; exit 1 }

$unidades = @{}       # nome da unit -> objeto
$metodos = New-Object System.Collections.Generic.List[object]
$totalLinhas = 0; $totalChars = 0

# Qualquer rotina na coluna 0 da implementation (método ou função solta) abre um bloco novo
$reMetodo = '^(class\s+)?(procedure|function|constructor|destructor|operator)\s+([A-Za-z_][\w\.]*)'
$reFimBloco = '^(initialization|finalization|end\.)'

foreach ($f in $pas) {
  $linhas = [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)
  $chars = 0; foreach ($l in $linhas) { $chars += $l.Length + 2 }
  $totalLinhas += $linhas.Count; $totalChars += $chars

  $nome = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $u = [pscustomobject]@{
    Unit = $nome; Arquivo = (Rel $f.FullName); Linhas = $linhas.Count; Tokens = [int]($chars / 4)
    With = 0; Globais = 0; UsesInterface = @(); UsesImpl = @(); EhDataModule = $false; EhForm = $false
    SqlNoCodigo = 0; ProcessMessages = 0; ExceptVazio = 0
  }

  $secao = 'inicio'; $emVarGlobal = $false; $emUses = $false; $usesAtual = ''
  $metodoAtual = $null
  for ($i = 0; $i -lt $linhas.Count; $i++) {
    $l = $linhas[$i]
    $t = $l.Trim()

    if ($t -match '^interface\b') { $secao = 'interface'; continue }
    if ($t -match '^implementation\b') {
      $secao = 'implementation'; $emVarGlobal = $false; continue
    }

    # uses (pode ocupar várias linhas)
    if (-not $emUses -and $t -match '^uses\b') { $emUses = $true; $usesAtual = '' }
    if ($emUses) {
      $usesAtual += ' ' + ($t -replace '\{[^}]*\}', '' -replace '//.*$', '')
      if ($t -match ';') {
        $nomes = ($usesAtual -replace '^\s*uses\s+', '' -replace ';.*$', '') -split ',' |
          ForEach-Object { ($_ -replace '\s+in\s+.*$', '').Trim() } | Where-Object { $_ }
        if ($secao -eq 'implementation') { $u.UsesImpl += $nomes } else { $u.UsesInterface += $nomes }
        $emUses = $false
      }
      continue
    }

    if ($secao -eq 'interface') {
      if ($t -match 'class\s*\(\s*TDataModule\s*\)') { $u.EhDataModule = $true }
      if ($t -match 'class\s*\(\s*T(Form|Frame)\s*\)') { $u.EhForm = $true }
      # var global na interface
      if ($t -match '^var$' -or $t -match '^var\s+\w') { $emVarGlobal = $true; if ($t -match '^var\s+\w') { $u.Globais++ }; continue }
      if ($t -match '^(type|const|resourcestring|procedure|function)\b') { $emVarGlobal = $false }
      if ($emVarGlobal -and $t -match '^[\w\s,]+:\s*[^=]+;') { $u.Globais++ }
    }

    if ($t -match '\bwith\s+.+\bdo\b') { $u.With++ }
    if ($t -match 'Application\.ProcessMessages') { $u.ProcessMessages++ }
    if ($t -match '^except\s*$' -and $i + 1 -lt $linhas.Count -and $linhas[$i + 1].Trim() -match '^end;?$') { $u.ExceptVazio++ }
    if ($t -match 'SQL\.(Add|Text)\b' -or $t -match "'\s*(SELECT|INSERT|UPDATE|DELETE)\s") { $u.SqlNoCodigo++ }

    if ($secao -eq 'implementation') {
      if ($l -match $reMetodo -or $l -match $reFimBloco) {
        if ($metodoAtual) {
          $metodoAtual.Linhas = $i - $metodoAtual.Inicio
          $metodos.Add($metodoAtual)
          $metodoAtual = $null
        }
        if ($l -match $reMetodo) {
          $metodoAtual = [pscustomobject]@{
            Unit = $nome; Arquivo = (Rel $f.FullName); Nome = $Matches[3]; Inicio = $i + 1; Linhas = 0
            Evento = ($l -match '\(\s*Sender\s*:\s*TObject')
          }
        }
      }
    }
  }
  if ($metodoAtual) { $metodoAtual.Linhas = $linhas.Count - $metodoAtual.Inicio; $metodos.Add($metodoAtual) }
  $unidades[$nome.ToLower()] = $u
}

# ---------- DFMs: componentes por form/DataModule ----------
$forms = New-Object System.Collections.Generic.List[object]
foreach ($f in $dfm) {
  $fs = [IO.File]::OpenRead($f.FullName)
  try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4) } finally { $fs.Close() }
  if ($n -eq 4 -and [Text.Encoding]::ASCII.GetString($b) -eq 'TPF0') {
    $forms.Add([pscustomobject]@{ Arquivo = (Rel $f.FullName); Componentes = -1; Dados = -1; Binario = $true }); continue
  }
  $comp = 0; $dados = 0
  foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    if ($l -match '^\s*(object|inherited|inline)\s+\w+\s*:\s*(\w+)') {
      $comp++
      if ($Matches[2] -match '(Query|Table|DataSet|StoredProc|Connection|Command|ClientDataSet|Provider|MemTable)$') { $dados++ }
    }
  }
  $forms.Add([pscustomobject]@{ Arquivo = (Rel $f.FullName); Componentes = $comp - 1; Dados = $dados; Binario = $false })
}

# ---------- Acoplamento ----------
$nomesProjeto = @($unidades.Keys)
$fanIn = @{}
foreach ($k in $nomesProjeto) { $fanIn[$k] = 0 }
$mutuos = New-Object System.Collections.Generic.List[string]
foreach ($k in $nomesProjeto) {
  $u = $unidades[$k]
  $todos = @($u.UsesInterface + $u.UsesImpl | ForEach-Object { $_.ToLower() } | Where-Object { $fanIn.ContainsKey($_) } | Select-Object -Unique)
  $u | Add-Member -NotePropertyName FanOut -NotePropertyValue $todos.Count
  foreach ($d in $todos) {
    $fanIn[$d]++
    $outro = $unidades[$d]
    $volta = @($outro.UsesInterface + $outro.UsesImpl | ForEach-Object { $_.ToLower() })
    if ($volta -contains $k -and $k -lt $d) { $mutuos.Add("$($u.Unit) ↔ $($outro.Unit)") }
  }
}

# ---------- Duplicação ----------
$trivial = '^(begin|end;?|end\.|try|finally|except|else|\)|\(|;|)$'
$janelas = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'
$normPorArquivo = @{}
$totalNorm = 0
foreach ($f in $pas) {
  $norm = New-Object System.Collections.Generic.List[object]
  $num = 0
  foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    $num++
    $t = ($l -replace '//.*$', '').Trim().ToLower() -replace '\s+', ' '
    if ($t -match $trivial) { continue }
    $norm.Add(@($num, $t))
  }
  $relArq = Rel $f.FullName
  $normPorArquivo[$relArq] = $norm
  $totalNorm += $norm.Count
  for ($i = 0; $i + $JanelaDuplicacao -le $norm.Count; $i++) {
    $partes = for ($j = 0; $j -lt $JanelaDuplicacao; $j++) { $norm[$i + $j][1] }
    $chave = $partes -join "`n"
    if ($chave.Length -lt 150) { continue }
    if (-not $janelas.ContainsKey($chave)) { $janelas[$chave] = New-Object System.Collections.Generic.List[string] }
    $janelas[$chave].Add("$relArq|$i")
  }
}
$blocosDup = @($janelas.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 })
# Linhas (não triviais) cobertas por algum bloco duplicado
$linhasDup = @{}
foreach ($b in $blocosDup) {
  foreach ($o in $b.Value) {
    $arq, $idx = $o -split '\|'
    $n = $normPorArquivo[$arq]
    for ($j = 0; $j -lt $JanelaDuplicacao; $j++) { $linhasDup["$arq`:$($n[[int]$idx + $j][0])"] = $true }
  }
}
$pctDup = if ($totalNorm -gt 0) { [math]::Round(100.0 * $linhasDup.Count / $totalNorm, 1) } else { 0 }
function Format-Ocorrencia([string]$o) {
  $arq, $idx = $o -split '\|'
  return "$arq`:$($normPorArquivo[$arq][[int]$idx][0])"
}
$topDup = $blocosDup | Sort-Object { $_.Value.Count } -Descending | Select-Object -First $Top

# ---------- Relatório ----------
$uList = @($unidades.Values)
$grandes = @($uList | Where-Object { $_.Linhas -ge $LimiteLinhasUnit })
$metGrandes = @($metodos | Where-Object { $_.Linhas -ge $LimiteLinhasMetodo })
$eventosGrandes = @($metGrandes | Where-Object { $_.Evento })
$dmUnits = @($uList | Where-Object { $_.EhDataModule })
$dmGrandes = @($forms | Where-Object { $_.Componentes -ge $LimiteComponentesDM })
$totalTokens = [int]($totalChars / 4)

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Diagnóstico do sistema legado')
$md.Add('')
$md.Add("Pasta: ``$Pasta`` · Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm') · Análise heurística por texto")
$md.Add('')
$md.Add('## Em números')
$md.Add('| Métrica | Valor |')
$md.Add('|---|---|')
$md.Add("| Units (.pas) | $($pas.Count) |")
$md.Add("| Linhas de código | $totalLinhas |")
$md.Add("| Tokens estimados para uma IA ler tudo | $totalTokens |")
$md.Add("| Units com $LimiteLinhasUnit+ linhas | $($grandes.Count) |")
$md.Add("| Métodos com $LimiteLinhasMetodo+ linhas | $($metGrandes.Count) |")
$md.Add("| …dos quais são eventos de tela (Sender: TObject) | $($eventosGrandes.Count) |")
$md.Add("| DataModules | $($dmUnits.Count) |")
$md.Add("| Forms/DataModules com $LimiteComponentesDM+ componentes | $($dmGrandes.Count) |")
$md.Add("| Linhas de código (sem begin/end vazios) em blocos duplicados | $pctDup% |")
$md.Add("| Pares de units que se usam mutuamente | $($mutuos.Count) |")
$md.Add("| Variáveis globais na interface (inclui as ``Form1: TForm1``) | $(($uList | Measure-Object Globais -Sum).Sum) |")
$md.Add("| Comandos ``with`` | $(($uList | Measure-Object With -Sum).Sum) |")
$md.Add("| ``Application.ProcessMessages`` | $(($uList | Measure-Object ProcessMessages -Sum).Sum) |")
$md.Add("| ``except`` vazio (engole erro) | $(($uList | Measure-Object ExceptVazio -Sum).Sum) |")
$md.Add("| Linhas com SQL/acesso a dados no código | $(($uList | Measure-Object SqlNoCodigo -Sum).Sum) |")
$md.Add('')

$md.Add("## Maiores units (custo para manutenção e para a IA)")
$md.Add('| Unit | Linhas | Tokens | Tipo | with | Globais |')
$md.Add('|---|---|---|---|---|---|')
$uList | Sort-Object Linhas -Descending | Select-Object -First $Top | ForEach-Object {
  $tipo = if ($_.EhDataModule) { 'DataModule' } elseif ($_.EhForm) { 'Form' } else { 'Unit' }
  $md.Add("| $($_.Arquivo) | $($_.Linhas) | $($_.Tokens) | $tipo | $($_.With) | $($_.Globais) |")
}
$md.Add('')

$md.Add("## Maiores métodos")
$md.Add('| Método | Linhas | Evento de tela? | Onde |')
$md.Add('|---|---|---|---|')
$metodos | Sort-Object Linhas -Descending | Select-Object -First $Top | ForEach-Object {
  $md.Add("| $($_.Nome) | $($_.Linhas) | $(if ($_.Evento) { 'sim' } else { '' }) | $($_.Arquivo):$($_.Inicio) |")
}
$md.Add('')

$md.Add("## Forms e DataModules com mais componentes")
$md.Add('| DFM | Componentes | Componentes de dados |')
$md.Add('|---|---|---|')
$forms | Where-Object { -not $_.Binario } | Sort-Object Componentes -Descending | Select-Object -First $Top | ForEach-Object {
  $md.Add("| $($_.Arquivo) | $($_.Componentes) | $($_.Dados) |")
}
$bin = @($forms | Where-Object Binario)
if ($bin.Count -gt 0) { $md.Add(''); $md.Add("DFMs binários (não analisados): $($bin.Count)") }
$md.Add('')

$md.Add("## Acoplamento")
$md.Add('Units mais usadas (fan-in: mexer nelas afeta muita coisa)')
$md.Add('')
$md.Add('| Unit | Usada por | Usa |')
$md.Add('|---|---|---|')
$uList | Sort-Object { $fanIn[$_.Unit.ToLower()] } -Descending | Select-Object -First $Top | ForEach-Object {
  $md.Add("| $($_.Unit) | $($fanIn[$_.Unit.ToLower()]) | $($_.FanOut) |")
}
$md.Add('')
if ($mutuos.Count -gt 0) {
  $md.Add("Pares que se usam mutuamente (dependência circular via implementation): $($mutuos.Count)")
  $mutuos | Select-Object -First 30 | ForEach-Object { $md.Add("- $_") }
  $md.Add('')
}

$md.Add("## Código duplicado (blocos de $JanelaDuplicacao linhas iguais, mais repetidos)")
if ($topDup.Count -eq 0) { $md.Add('Nenhum bloco duplicado relevante.') }
foreach ($b in $topDup) {
  $md.Add('')
  $md.Add("**$($b.Value.Count) ocorrências:** " + (($b.Value | Select-Object -First 6 | ForEach-Object { Format-Ocorrencia $_ }) -join ', ') + $(if ($b.Value.Count -gt 6) { ', ...' } else { '' }))
  $md.Add('```pascal')
  ($b.Key -split "`n" | Select-Object -First 4) | ForEach-Object { $md.Add($_) }
  $md.Add('...')
  $md.Add('```')
}
$md.Add('')

# ---------- Comparação antes × depois ----------
$metricas = [ordered]@{
  data = (Get-Date).ToString('s'); units = $pas.Count; linhas = $totalLinhas; tokens = $totalTokens
  unitsGrandes = $grandes.Count; metodosGrandes = $metGrandes.Count; eventosGrandes = $eventosGrandes.Count
  dfmsGrandes = $dmGrandes.Count; pctDuplicado = $pctDup; paresMutuos = $mutuos.Count
  globais = ($uList | Measure-Object Globais -Sum).Sum; with = ($uList | Measure-Object With -Sum).Sum
  exceptVazio = ($uList | Measure-Object ExceptVazio -Sum).Sum
}
if ($Comparar) {
  $caminhoAnt = if ([IO.Path]::IsPathRooted($Comparar)) { $Comparar } else { Join-Path $Pasta $Comparar }
  $ant = Get-Content $caminhoAnt -Raw -Encoding UTF8 | ConvertFrom-Json
  $md.Add("## Antes × depois (comparado com $($ant.data))")
  $md.Add('| Métrica | Antes | Agora |')
  $md.Add('|---|---|---|')
  foreach ($k in $metricas.Keys) { if ($k -ne 'data') { $md.Add("| $k | $($ant.$k) | $($metricas[$k]) |") } }
  $md.Add('')
}

$saida = Join-Path $Pasta '_modernizacao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arqMd = Join-Path $saida 'diagnostico.md'
$arqJson = Join-Path $saida ("diagnostico-{0}.json" -f (Get-Date -Format 'yyyy-MM-dd'))
$md | Set-Content -Path $arqMd -Encoding UTF8
$metricas | ConvertTo-Json | Set-Content -Path $arqJson -Encoding UTF8

Write-Host "Units: $($pas.Count) | Linhas: $totalLinhas | Tokens estimados: $totalTokens"
Write-Host "Units grandes: $($grandes.Count) | Métodos grandes: $($metGrandes.Count) (eventos: $($eventosGrandes.Count)) | DFMs inchados: $($dmGrandes.Count)"
Write-Host "Duplicação aprox.: $pctDup% | Pares mútuos: $($mutuos.Count) | with: $($metricas.with) | globais: $($metricas.globais) | except vazio: $($metricas.exceptVazio)"
Write-Host "Relatório: $arqMd"
Write-Host "Métricas:  $arqJson"
