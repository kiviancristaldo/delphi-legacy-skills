<#
.SYNOPSIS
  Procura problemas de limpeza em código Delphi: with, except vazio, objeto criado sem
  try/finally, função que devolve objeto criado, código comentado, ProcessMessages,
  senha no código/DFM e métodos que parecem não ser usados. Não altera nenhum arquivo.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Find-CodeSmells.ps1 -Pasta C:\Projetos\MeuSistema -Recursivo -Excluir 'ACBr|Componentes'

.OUTPUTS
  <Pasta>\_modernizacao\limpeza.md

.NOTES
  Heurística por texto: todo item é CANDIDATO e precisa ser confirmado antes de corrigir.
  "Método sem uso" ignora eventos ligados no DFM, mas não enxerga chamadas por RTTI/MethodAddress.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [switch]$Recursivo,
  [string]$Excluir = '',
  [int]$MaxPorItem = 150
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

$pas = Get-Arquivos @('*.pas', '*.dpr')
$dfm = Get-Arquivos @('*.dfm', '*.fmx')

$itens = [ordered]@{
  'with'                         = New-Object System.Collections.Generic.List[string]
  'except vazio'                 = New-Object System.Collections.Generic.List[string]
  'Create sem try/finally'       = New-Object System.Collections.Generic.List[string]
  'Função devolve objeto criado' = New-Object System.Collections.Generic.List[string]
  'Código comentado'             = New-Object System.Collections.Generic.List[string]
  'Application.ProcessMessages'  = New-Object System.Collections.Generic.List[string]
  'Senha no código ou DFM'       = New-Object System.Collections.Generic.List[string]
  'Método possivelmente sem uso' = New-Object System.Collections.Generic.List[string]
}
$risco = @{
  'with' = 'médio: expandir muda nada se feito certo, mas o escopo é ambíguo; um por vez'
  'except vazio' = 'ALTO para corrigir: logar ou relançar muda comportamento; decidir com o usuário'
  'Create sem try/finally' = 'baixo: envolver em try/finally não muda o fluxo normal'
  'Função devolve objeto criado' = 'médio: mudar quem cria/libera exige revisar todos os chamadores'
  'Código comentado' = 'baixo: o Git guarda a história'
  'Application.ProcessMessages' = 'ALTO: remover pode travar a tela; manter pode causar reentrância'
  'Senha no código ou DFM' = 'ALTO (segurança): mover para configuração protegida'
  'Método possivelmente sem uso' = 'médio: confirmar que não é chamado por RTTI, herança ou pacote'
}

# Frequência de cada identificador no projeto inteiro (uma passada só)
$frequencia = New-Object 'System.Collections.Generic.Dictionary[string,int]'
foreach ($f in $pas + $dfm) {
  $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default)
  foreach ($m in [regex]::Matches($txt, '[A-Za-z_]\w*')) {
    $w = $m.Value.ToLower()
    if ($frequencia.ContainsKey($w)) { $frequencia[$w] = $frequencia[$w] + 1 } else { $frequencia[$w] = 1 }
  }
}

$eventosNoDfm = @{}
foreach ($f in $dfm) {
  foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    if ($l -match '^\s*On\w+\s*=\s*(\w+)\s*$') { $eventosNoDfm[$Matches[1].ToLower()] = $true }
  }
}

foreach ($f in $pas) {
  $linhas = [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)
  $r = Rel $f.FullName
  $comentadas = 0
  $emImpl = $false
  for ($i = 0; $i -lt $linhas.Count; $i++) {
    $t = $linhas[$i].Trim()
    $pos = "$r`:$($i + 1)"
    if ($t -match '^implementation\b') { $emImpl = $true }

    if ($t -match '^\s*//') {
      if ($t -match '(:=|;\s*$|\bbegin\b|\bend\b|\bthen\b)') { $comentadas++ } else { $comentadas = 0 }
      if ($comentadas -eq 3) { $itens['Código comentado'].Add("$r`:$($i - 1)  $t") }
      continue
    } else { $comentadas = 0 }

    if ($t -match '\bwith\s+.+\bdo\b') { $itens['with'].Add("$pos  $t") }
    if ($t -match '^except\s*$') {
      $j = $i + 1
      while ($j -lt $linhas.Count -and $linhas[$j].Trim() -eq '') { $j++ }
      if ($j -lt $linhas.Count -and $linhas[$j].Trim() -match '^end;?$') { $itens['except vazio'].Add("$pos  except ... end") }
    }
    # Objeto com dono (Create(Application/Self/AOwner/Owner)) é liberado pelo dono: não precisa de try/finally
    if ($t -match '^(\w+)\s*:=\s*T\w+\.Create\b' -and $Matches[1] -ne 'Result' -and
        $t -notmatch '\.Create\s*\(\s*(Application|Self|AOwner|Owner)\s*[,)]') {
      $j = $i + 1
      while ($j -lt $linhas.Count -and $linhas[$j].Trim() -eq '') { $j++ }
      if ($j -lt $linhas.Count -and $linhas[$j].Trim() -notmatch '^try\b') { $itens['Create sem try/finally'].Add("$pos  $t") }
    }
    if ($t -match '^Result\s*:=\s*T\w+\.Create\b') { $itens['Função devolve objeto criado'].Add("$pos  $t") }
    if ($t -match 'Application\.ProcessMessages') { $itens['Application.ProcessMessages'].Add("$pos  $t") }
    if ($t -match "(?i)(password|senha|pwd)\s*[:=]+\s*'[^']+'" -or $t -match "(?i)'(password|senha|pwd)=[^']+'") {
      $itens['Senha no código ou DFM'].Add("$pos  (valor omitido)")
    }

    # Métodos sem uso: conta ocorrências do nome no projeto inteiro (declaração + implementação = 2)
    if ($emImpl -and $linhas[$i] -match '^(procedure|function)\s+T\w+\.(\w+)') {
      $nome = $Matches[2]
      if (-not $eventosNoDfm.ContainsKey($nome.ToLower())) {
        $qtd = $frequencia[$nome.ToLower()]
        if ($qtd -le 2) { $itens['Método possivelmente sem uso'].Add("$pos  $nome") }
      }
    }
  }
}
foreach ($f in $dfm) {
  $i = 0
  foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    $i++
    if ($l -match "(?i)'(password|senha|pwd)=[^']+'" -or $l -match "(?i)^\s*Password\s*=\s*'[^']+'") {
      $itens['Senha no código ou DFM'].Add("$(Rel $f.FullName):$i  (valor omitido)")
    }
  }
}

# ReportMemoryLeaksOnShutdown no .dpr
$dprs = @($pas | Where-Object { $_.Extension -eq '.dpr' })
$semLeak = @($dprs | Where-Object { -not ([IO.File]::ReadAllText($_.FullName, [Text.Encoding]::Default) -match 'ReportMemoryLeaksOnShutdown') })

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Limpeza: candidatos encontrados')
$md.Add('')
$md.Add("Pasta: ``$Pasta`` · $($pas.Count) units · Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$md.Add('Todo item é candidato: confirme antes de corrigir.')
$md.Add('')
$md.Add('| Item | Quantidade | Risco da correção |')
$md.Add('|---|---|---|')
foreach ($k in $itens.Keys) { $md.Add("| $k | $($itens[$k].Count) | $($risco[$k]) |") }
$md.Add("| .dpr sem ReportMemoryLeaksOnShutdown | $($semLeak.Count) | baixo: ligar só em Debug |")
foreach ($k in $itens.Keys) {
  if ($itens[$k].Count -eq 0) { continue }
  $md.Add('')
  $md.Add("## $k ($($itens[$k].Count))")
  $itens[$k] | Select-Object -First $MaxPorItem | ForEach-Object { $md.Add("- ``$_``") }
  if ($itens[$k].Count -gt $MaxPorItem) { $md.Add("- ... mais $($itens[$k].Count - $MaxPorItem)") }
}

$saida = Join-Path $Pasta '_modernizacao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arq = Join-Path $saida 'limpeza.md'
$md | Set-Content -Path $arq -Encoding UTF8

foreach ($k in $itens.Keys) { Write-Host ("{0,-32} {1,5}" -f $k, $itens[$k].Count) }
Write-Host ("{0,-32} {1,5}" -f '.dpr sem ReportMemoryLeaks', $semLeak.Count)
Write-Host "Relatório: $arq"
