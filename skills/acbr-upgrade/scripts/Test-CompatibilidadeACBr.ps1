<#
.SYNOPSIS
  Confere um projeto Delphi contra os fontes da versão NOVA do ACBr: lista os componentes
  ACBr usados nos DFMs e as propriedades configuradas, e aponta classes, propriedades e
  units que não existem mais nos fontes novos. Não altera nenhum arquivo.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Test-CompatibilidadeACBr.ps1 -Pasta C:\Projetos\MeuSistema -FontesACBr C:\ACBr\Fontes -Recursivo

.OUTPUTS
  <Pasta>\_modernizacao\acbr-compatibilidade.md

.NOTES
  Verificação por nome (texto), não por compilação: "não encontrado" significa "procure
  o novo nome no changelog/fórum", não necessariamente que a propriedade sumiu.
  Propriedades herdadas de classes da VCL (Name, Left, Top, Tag...) são ignoradas.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [Parameter(Mandatory = $true)] [string]$FontesACBr,
  [switch]$Recursivo,
  [string]$Excluir = ''
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path
$FontesACBr = (Resolve-Path $FontesACBr).Path
$recurse = [bool]$Recursivo

# ---------- Índice dos fontes novos do ACBr ----------
Write-Host "Indexando fontes do ACBr em $FontesACBr ..."
$fontes = @(Get-ChildItem -Path $FontesACBr -Filter *.pas -File -Recurse -ErrorAction SilentlyContinue)
$unitsACBr = @{}
$classes = @{}
$propriedades = @{}
foreach ($f in $fontes) {
  $unitsACBr[[IO.Path]::GetFileNameWithoutExtension($f.Name).ToLower()] = $true
  $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default)
  foreach ($m in [regex]::Matches($txt, '\b(T\w+)\s*=\s*class\b', 'IgnoreCase')) { $classes[$m.Groups[1].Value.ToLower()] = $true }
  foreach ($m in [regex]::Matches($txt, '\bproperty\s+(\w+)', 'IgnoreCase')) { $propriedades[$m.Groups[1].Value.ToLower()] = $true }
}
Write-Host "  $($fontes.Count) units, $($classes.Count) classes, $($propriedades.Count) nomes de propriedade"

# Propriedades comuns da VCL/RTL que não precisam estar nos fontes do ACBr
$vcl = 'name|left|top|width|height|tag|enabled|visible|onclick|font|color|align|anchors|caption|hint|showhint|parentfont|taborder|tabstop|designinfo|explicit\w*|left|items|strings|lines|text|charset|size|style|onchange|onexit|onenter'

# ---------- Projeto ----------
$arquivos = if ($recurse) {
  Get-ChildItem -Path $Pasta -Include *.pas, *.dpr, *.dfm -File -Recurse -ErrorAction SilentlyContinue
} else {
  Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.pas, *.dpr, *.dfm -File
}
$arquivos = @($arquivos | Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao|_modernizacao|_build|Win32|Win64)\\' -and $_.FullName -notlike "$FontesACBr*" })
if ($Excluir) { $arquivos = @($arquivos | Where-Object { $_.FullName.Substring($Pasta.Length) -notmatch $Excluir }) }

$usoClasses = @{}          # classe -> quantidade
$usoProps = @{}            # "Classe.Caminho" -> lista de locais
$unitsUsadas = @{}         # unit ACBr no uses -> lista de arquivos

foreach ($f in $arquivos) {
  $rel = $f.FullName.Substring($Pasta.Length + 1)
  if ($f.Extension -eq '.dfm') {
    $fs = [IO.File]::OpenRead($f.FullName)
    try { $b = New-Object byte[] 4; $n = $fs.Read($b, 0, 4) } finally { $fs.Close() }
    if ($n -eq 4 -and [Text.Encoding]::ASCII.GetString($b) -eq 'TPF0') { Write-Host "  DFM binário ignorado: $rel"; continue }

    $pilha = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
      $i++
      $t = $l.Trim()
      if ($t -match '^(object|inherited|inline)\s+\w+\s*:\s*(\w+)') {
        $cls = $Matches[2]; $pilha.Add($cls)
        if ($cls -match '^TACBr') { $usoClasses[$cls] = 1 + [int]$usoClasses[$cls] }
        continue
      }
      if ($t -match '^item$' -or $t -match '<\s*$') { $pilha.Add('#item'); continue }
      if ($t -eq 'end' -or $t -eq '>') {
        if ($pilha.Count -gt 0) { $pilha.RemoveAt($pilha.Count - 1) }
        continue
      }
      if ($t -eq 'end>') {   # fecha o item e a coleção
        for ($k = 0; $k -lt 2 -and $pilha.Count -gt 0; $k++) { $pilha.RemoveAt($pilha.Count - 1) }
        continue
      }
      if ($pilha.Count -gt 0 -and $pilha[$pilha.Count - 1] -match '^TACBr' -and $t -match '^([A-Za-z_][\w\.]*)\s*=') {
        $caminho = $Matches[1]
        $chave = "$($pilha[$pilha.Count - 1]).$caminho"
        if (-not $usoProps.ContainsKey($chave)) { $usoProps[$chave] = New-Object System.Collections.Generic.List[string] }
        $usoProps[$chave].Add("$rel`:$i")
      }
    }
  } else {
    $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default)
    foreach ($m in [regex]::Matches($txt, '(?is)\buses\b(.*?);')) {
      foreach ($nome in ($m.Groups[1].Value -replace '\{[^}]*\}', '' -replace '//[^\r\n]*', '' -split ',')) {
        $u = ($nome -replace '\s+in\s+.*$', '').Trim()
        if ($u -match '^(pcn|pcnConversao|ACBr)\w*' -or $u -match '^ACBr') {
          if (-not $unitsUsadas.ContainsKey($u)) { $unitsUsadas[$u] = New-Object System.Collections.Generic.List[string] }
          $unitsUsadas[$u].Add($rel)
        }
      }
    }
  }
}

# ---------- Comparação ----------
$classesFaltando = @($usoClasses.Keys | Where-Object { -not $classes.ContainsKey($_.ToLower()) } | Sort-Object)
$unitsFaltando = @($unitsUsadas.Keys | Where-Object { -not $unitsACBr.ContainsKey($_.ToLower()) } | Sort-Object)
$propsFaltando = New-Object System.Collections.Generic.List[object]
foreach ($k in ($usoProps.Keys | Sort-Object)) {
  $segmentos = ($k -split '\.') | Select-Object -Skip 1
  $ausentes = @($segmentos | Where-Object { $_ -notmatch "^($vcl)$" -and -not $propriedades.ContainsKey($_.ToLower()) })
  if ($ausentes.Count -gt 0) {
    $propsFaltando.Add([pscustomobject]@{ Caminho = $k; Ausentes = ($ausentes -join ', '); Onde = (($usoProps[$k] | Select-Object -First 3) -join ', ') })
  }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Compatibilidade com a versão nova do ACBr')
$md.Add('')
$md.Add("Projeto: ``$Pasta``  ")
$md.Add("Fontes ACBr: ``$FontesACBr`` ($($fontes.Count) units)  ")
$md.Add("Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm') · verificação por nome, confirme cada item")
$md.Add('')
$md.Add('## Componentes ACBr usados nos DFMs')
$md.Add('| Classe | Instâncias | Existe nos fontes novos? |')
$md.Add('|---|---|---|')
foreach ($c in ($usoClasses.Keys | Sort-Object)) { $md.Add("| $c | $($usoClasses[$c]) | $(if ($classes.ContainsKey($c.ToLower())) { 'sim' } else { '**NÃO**' }) |") }
$md.Add('')
$md.Add("## Units ACBr no uses que não existem nos fontes novos: $($unitsFaltando.Count)")
foreach ($u in $unitsFaltando) { $md.Add("- ``$u`` (usada em: $(($unitsUsadas[$u] | Select-Object -Unique -First 5) -join ', '))") }
$md.Add('')
$md.Add("## Propriedades configuradas nos DFMs com nome não encontrado: $($propsFaltando.Count)")
$md.Add('Ao carregar o form, uma propriedade que não existe gera "Error reading ... Property X does not exist".')
$md.Add('')
$md.Add('| Propriedade no DFM | Nome não encontrado | Onde |')
$md.Add('|---|---|---|')
foreach ($p in $propsFaltando) { $md.Add("| $($p.Caminho) | $($p.Ausentes) | $($p.Onde) |") }
$md.Add('')
$md.Add("## Todas as propriedades ACBr configuradas ($($usoProps.Count))")
$md.Add('Use esta lista para revisar a configuração depois da atualização (certificado, SSL, schemas, ambiente).')
foreach ($k in ($usoProps.Keys | Sort-Object)) { $md.Add("- ``$k``") }

$saida = Join-Path $Pasta '_modernizacao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arq = Join-Path $saida 'acbr-compatibilidade.md'
$md | Set-Content -Path $arq -Encoding UTF8

Write-Host "Componentes ACBr: $($usoClasses.Count) classes | classes ausentes: $($classesFaltando.Count)"
Write-Host "Units ACBr no uses: $($unitsUsadas.Count) | ausentes: $($unitsFaltando.Count)"
Write-Host "Propriedades configuradas: $($usoProps.Count) | com nome não encontrado: $($propsFaltando.Count)"
Write-Host "Relatório: $arq"
