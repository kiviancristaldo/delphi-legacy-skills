<#
.SYNOPSIS
  Levantamento para a limpeza de código Delphi. Não altera nenhum arquivo.
  Procura (1) problemas de limpeza: with, except vazio, objeto criado sem try/finally, função
  que devolve objeto criado, código comentado, ProcessMessages, senha no código/DFM, métodos e
  componentes de dados que parecem não ser usados, .dpr sem ReportMemoryLeaksOnShutdown;
  e (2) riscos para apontar (não para corrigir sozinho): units e DataModules grandes, units com
  muitas classes, métodos grandes ou com complexidade ciclomática alta, DataModules com muitos
  assuntos, parâmetros var/out e código duplicado.
  O relatório sai agrupado por prioridade (alta, média, baixa), com arquivo:linha em cada item,
  para o usuário decidir o que será feito.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Find-CodeSmells.ps1 -Pasta C:\Projetos\MeuSistema -Recursivo -Excluir 'ACBr|Componentes'

.EXAMPLE
  # Escopo parcial: analisa só duas units, mas procura referências no projeto inteiro (-Pasta).
  # Nada que possa ser usado por outras partes do sistema é sugerido para remoção.
  powershell -ExecutionPolicy Bypass -File Find-CodeSmells.ps1 -Pasta C:\Projetos\MeuSistema -Recursivo -Arquivos "uPedidos.pas,Cadastros\uClientes.pas"

.OUTPUTS
  <Pasta>\_modernizacao\limpeza.md

.NOTES
  Heurística por texto, não por compilador: todo item é CANDIDATO e precisa ser confirmado.
  Comentários ({ }, (* *), //) e conteúdo de strings são ignorados ao contar decisões e procurar
  padrões (diretivas {$...} são mantidas). DFM binário não é lido (aparece um aviso).
  Complexidade ciclomática = 1 + if + while + for + repeat + cada rótulo de case + and/or dentro
  das condições de if/while/until + except + cada "on E: Classe do". Rotinas aninhadas contam
  para a rotina de fora (como no Get-DiagnosticoLegado). Detalhes em referencias/riscos-apontados.md.
#>
param(
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [switch]$Recursivo,
  [string]$Excluir = '',
  [int]$MaxPorItem = 150,
  # Escopo parcial: units separadas por vírgula ou ponto e vírgula (relativas a -Pasta, absolutas
  # ou só o nome). Vazio = projeto todo.
  [string]$Arquivos = '',
  [int]$LimiteLinhasUnit = 2000,
  [int]$LimiteLinhasMetodo = 80,
  [int]$LimiteComplexidade = 10,
  [int]$LimiteComplexidadeAlta = 20,
  [int]$LimiteClassesUnit = 5,
  [int]$LimiteComponentesDM = 60,
  [int]$LimiteDatasetsDM = 20,
  [int]$LimiteAssuntosDM = 4,
  [int]$LimiteTabelasDM = 10,
  [int]$JanelaDuplicacao = 8,
  [int]$LimiteVarOut = 3
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path.TrimEnd('\')
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

# Mesma função do Find-PadroesMigracao (delphi-unicode-migration), com a opção de manter o
# conteúdo das strings (usada na busca de duplicação e de SQL). Tira comentários { }, (* *) e //,
# mantém diretivas {$...}. $Estado guarda o comentário de várias linhas em aberto.
function Limpar-Linha([string]$Linha, [ref]$Estado, [bool]$ManterStrings = $false) {
  # Atalhos (desempenho): linha sem string nem comentário, ou inteira dentro de um comentário
  if ($Estado.Value -eq '' -and $Linha.IndexOf("'") -lt 0 -and $Linha.IndexOf('{') -lt 0 -and $Linha.IndexOf('(*') -lt 0 -and $Linha.IndexOf('//') -lt 0) { return $Linha.Trim() }
  if ($Estado.Value -eq 'chave' -and $Linha.IndexOf('}') -lt 0) { return '' }
  if ($Estado.Value -eq 'paren' -and $Linha.IndexOf('*)') -lt 0) { return '' }
  $sb = New-Object System.Text.StringBuilder
  $i = 0; $n = $Linha.Length
  while ($i -lt $n) {
    $c = $Linha[$i]
    if ($Estado.Value -eq 'chave') { if ($c -eq '}') { $Estado.Value = '' }; $i++; continue }
    if ($Estado.Value -eq 'paren') {
      if ($c -eq '*' -and $i + 1 -lt $n -and $Linha[$i + 1] -eq ')') { $Estado.Value = ''; $i += 2 } else { $i++ }
      continue
    }
    if ($c -eq "'") {
      $j = $Linha.IndexOf("'", $i + 1)
      if ($j -lt 0) { if ($ManterStrings) { [void]$sb.Append($Linha.Substring($i)) } else { [void]$sb.Append("''") }; break }
      if ($ManterStrings) { [void]$sb.Append($Linha.Substring($i, $j - $i + 1)) } else { [void]$sb.Append("''") }
      $i = $j + 1; continue
    }
    if ($c -eq '/' -and $i + 1 -lt $n -and $Linha[$i + 1] -eq '/') { break }
    if ($c -eq '{') {
      if ($i + 1 -lt $n -and $Linha[$i + 1] -eq '$') {
        $j = $Linha.IndexOf('}', $i)
        if ($j -lt 0) { [void]$sb.Append($Linha.Substring($i)); break }
        [void]$sb.Append($Linha.Substring($i, $j - $i + 1)); $i = $j + 1; continue
      }
      $Estado.Value = 'chave'; $i++; continue
    }
    if ($c -eq '(' -and $i + 1 -lt $n -and $Linha[$i + 1] -eq '*') { $Estado.Value = 'paren'; $i += 2; continue }
    [void]$sb.Append($c); $i++
  }
  return $sb.ToString().Trim()
}

function Limpar-Arquivo([string[]]$Linhas, [bool]$ManterStrings) {
  $res = New-Object string[] $Linhas.Count
  $estado = ''
  for ($i = 0; $i -lt $Linhas.Count; $i++) { $res[$i] = Limpar-Linha $Linhas[$i] ([ref]$estado) $ManterStrings }
  return , $res
}

# DFM binário: "TPF0" no início, ou o cabeçalho de recurso FF 0A 00 que a IDE grava antes dele
function Test-DfmBinario([string]$Caminho) {
  $fs = [IO.File]::OpenRead($Caminho)
  try { $b = New-Object byte[] 64; $n = $fs.Read($b, 0, 64) } finally { $fs.Close() }
  if ($n -ge 4 -and [Text.Encoding]::ASCII.GetString($b, 0, 4) -eq 'TPF0') { return $true }
  if ($n -ge 3 -and $b[0] -eq 0xFF -and $b[1] -eq 0x0A -and $b[2] -eq 0x00) { return $true }
  return $false
}

# ---------------------------------------------------------------- arquivos e escopo
$todosPas = @(Get-Arquivos @('*.pas', '*.dpr'))
$todosDfm = @(Get-Arquivos @('*.dfm', '*.fmx'))
$dfmBinarios = @($todosDfm | Where-Object { Test-DfmBinario $_.FullName })
$dfmTexto = @($todosDfm | Where-Object { $dfmBinarios -notcontains $_ })

$parcial = [bool]$Arquivos.Trim()
if ($parcial) {
  $pedidos = @($Arquivos -split '[,;]' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ })
  $escolhidos = New-Object System.Collections.Generic.List[object]
  foreach ($p in $pedidos) {
    $alvo = if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $Pasta $p }
    $achou = @($todosPas | Where-Object { $_.FullName -ieq $alvo })
    if ($achou.Count -eq 0 -and $p -notmatch '[\\/]') { $achou = @($todosPas | Where-Object { $_.Name -ieq $p }) }
    if ($achou.Count -eq 0) { Write-Host "Aviso: '$p' não foi encontrado em $Pasta (confira -Recursivo e -Excluir)" -ForegroundColor Yellow }
    foreach ($a in $achou) { if (-not $escolhidos.Contains($a)) { $escolhidos.Add($a) } }
  }
  if ($escolhidos.Count -eq 0) { Write-Host 'Nenhuma unit de -Arquivos foi encontrada.'; exit 1 }
  $pas = $escolhidos.ToArray()
} else {
  $pas = $todosPas
}
$nomesEscopo = @{}
foreach ($f in $pas) { $nomesEscopo[[IO.Path]::ChangeExtension($f.FullName, $null).ToLower()] = $true }
$dfm = @($dfmTexto | Where-Object { $nomesEscopo.ContainsKey([IO.Path]::ChangeExtension($_.FullName, $null).ToLower()) })
$dfmBinEscopo = @($dfmBinarios | Where-Object { $nomesEscopo.ContainsKey([IO.Path]::ChangeExtension($_.FullName, $null).ToLower()) })

# Cache de leitura (cada arquivo é lido uma vez)
$cache = @{}
function Ler([string]$Caminho) {
  if (-not $cache.ContainsKey($Caminho)) { $cache[$Caminho] = [IO.File]::ReadAllLines($Caminho, [Text.Encoding]::Default) }
  return , $cache[$Caminho]
}
# Versão limpa (sem comentários; strings vazias ou mantidas), também calculada uma vez só
$cacheLimpo = @{}
function Ler-Limpo([string]$Caminho, [bool]$ManterStrings) {
  $chave = "$ManterStrings|$Caminho"
  if (-not $cacheLimpo.ContainsKey($chave)) { $cacheLimpo[$chave] = Limpar-Arquivo (Ler $Caminho) $ManterStrings }
  return , $cacheLimpo[$chave]
}

# ---------------------------------------------------------------- tipos de item
# Nome = @(prioridade, risco de corrigir, benefício, recomendação)
$tipos = [ordered]@{
  'Senha no código ou DFM' = @('alta', 'médio: mover para configuração; a senha continua no histórico do Git e precisa ser trocada', 'segurança: credencial fora do executável e do repositório', 'perguntar onde a empresa guarda credenciais; mover; avisar que a senha deve ser trocada')
  'except vazio' = @('alta', 'ALTO: logar ou relançar muda comportamento', 'erros deixam de sumir sem rastro (dado inconsistente)', 'decidir caso a caso com o usuário, com teste de caracterização no trecho')
  'Método crítico (muito grande ou complexo)' = @('alta', 'ALTO: quebrar mexe em muitos caminhos ao mesmo tempo', 'legibilidade, testabilidade, menos tokens para a IA', 'NÃO é limpeza: criar testes (delphi-characterization-tests) e depois quebrar com delphi-safe-refactoring')
  'Unit gigante' = @('alta', 'ALTO: dividir mexe em uses, .dpr e em quem usa a unit', 'manutenção e custo de leitura para a IA', 'NÃO é limpeza: planejar a divisão com delphi-safe-refactoring, com testes antes')
  'DataModule gigante' = @('alta', 'ALTO: dividir quebra referências de forms e DFMs (DataSource = DM.xxx)', 'acoplamento menor, abertura mais rápida', 'NÃO é limpeza: delphi-safe-refactoring (referencias/dividir-datamodule.md), com testes antes')
  'Unit com classes demais' = @('alta', 'médio: mover classes muda uses de quem as usa', 'cada unit com um assunto; menos conflito de merge', 'NÃO é limpeza: separar por assunto com delphi-safe-refactoring')
  'DataModule com assuntos demais' = @('alta', 'ALTO: separar quebra referências de forms e DFMs', 'cada DataModule com um assunto; menos acoplamento', 'NÃO é limpeza: dividir por assunto com delphi-safe-refactoring (dividir-datamodule.md), com testes antes')
  'Código duplicado extenso' = @('alta', 'médio a alto: unificar exige que as cópias façam de fato a mesma coisa', 'corrigir num lugar só; menos código', 'NÃO é limpeza: confirmar que as cópias são iguais de verdade, testar e extrair com delphi-safe-refactoring')
  'Rotina com muitos var/out' = @('alta', 'médio: mudar assinatura exige mudar todos os chamadores', 'menos efeito colateral, mais fácil de testar', 'NÃO é limpeza: devolver um record/objeto de resultado (delphi-safe-refactoring), com testes antes')
  'with' = @('média', 'médio: o escopo é ambíguo; expandir um por vez', 'fica claro de quem é cada propriedade', 'expandir um with por vez, compilar; with A, B com teste')
  'Create sem try/finally' = @('média', 'baixo: envolver em try/finally não muda o fluxo normal', 'não vaza memória quando há exceção', 'try logo depois do Create, Free no finally')
  'Função devolve objeto criado' = @('média', 'médio: mudar quem cria/libera exige revisar todos os chamadores', 'dono do objeto fica claro; menos vazamento', 'receber o objeto já criado por parâmetro; todos os chamadores no mesmo commit')
  'Application.ProcessMessages' = @('média', 'ALTO: remover pode travar a tela; manter pode causar reentrância', 'evita clique duplo/reentrada durante o processamento', 'decidir com o usuário: desabilitar o botão, thread ou proteção contra reentrada')
  'Método grande ou complexo' = @('média', 'médio: quebrar exige entender todos os caminhos', 'legibilidade e testabilidade', 'NÃO é limpeza: testes antes e depois delphi-safe-refactoring (extrair método)')
  'Unit grande' = @('média', 'médio: dividir mexe em uses e no .dpr', 'manutenção e custo de leitura para a IA', 'NÃO é limpeza: avaliar divisão com delphi-safe-refactoring')
  'DataModule grande' = @('média', 'médio: dividir quebra referências de forms e DFMs', 'acoplamento menor', 'NÃO é limpeza: avaliar divisão com delphi-safe-refactoring')
  'Unit com muitas classes' = @('média', 'médio: mover classes muda uses de quem as usa', 'cada unit com um assunto', 'NÃO é limpeza: avaliar separação com delphi-safe-refactoring')
  'DataModule com muitos assuntos' = @('média', 'médio a alto: separar quebra referências de forms e DFMs', 'cada DataModule com um assunto', 'NÃO é limpeza: avaliar divisão com delphi-safe-refactoring, com testes antes')
  'Parâmetro var/out' = @('média', 'médio: mudar assinatura exige mudar todos os chamadores', 'menos efeito colateral escondido, mais fácil de testar', 'NÃO é limpeza: devolver resultado (função/record) com delphi-safe-refactoring; testes antes')
  'Código duplicado' = @('média', 'médio: unificar exige que as cópias façam de fato a mesma coisa', 'corrigir num lugar só', 'NÃO é limpeza: anotar para delphi-safe-refactoring (extrair método), com testes')
  'Código comentado' = @('baixa', 'baixo: o Git guarda a história', 'menos código para ler', 'apagar o bloco comentado')
  'Método possivelmente sem uso' = @('baixa', 'médio: pode ser chamado por RTTI, DFM herdado, outro projeto ou pacote', 'menos código para ler e manter', 'confirmar com busca no sistema inteiro (inclusive DFMs e outros projetos) antes de remover')
  'Componente de dados possivelmente sem uso' = @('baixa', 'médio: pode ser usado por outro form (DM.Componente), por FindComponent ou por relatório', 'DataModule menor, menos datasets abertos', 'confirmar no sistema inteiro (inclusive .fr3/.rav e FindComponent) antes de remover')
  'Parâmetro var/out em evento' = @('baixa', 'não se aplica: a assinatura é do evento da VCL', 'nenhum (apenas informativo)', 'não mudar; só vale reduzir a lógica dentro do evento')
  '.dpr sem ReportMemoryLeaksOnShutdown' = @('baixa', 'baixo: ligar só em Debug', 'mostra vazamentos ao fechar o programa', 'acrescentar {$IFDEF DEBUG} ReportMemoryLeaksOnShutdown := True; {$ENDIF}')
  'Não remover: escopo parcial' = @('info', 'remover pode quebrar outra parte do sistema que não foi analisada', '-', 'não remover; ou buscar no sistema inteiro antes e só então decidir')
}
$itens = [ordered]@{}
foreach ($k in $tipos.Keys) { $itens[$k] = New-Object System.Collections.Generic.List[string] }

$reDados = '(Query|Table|DataSet|StoredProc|Connection|Command|ClientDataSet|Provider|MemTable)$'
$reDataset = '(Query|Table|DataSet|StoredProc|ClientDataSet|MemTable|Command)$'
$reMetodo = '^(class\s+)?(procedure|function|constructor|destructor|operator)\s+([A-Za-z_][\w\.]*)'
$reFimBloco = '^(initialization|finalization|end\.)'

# ---------------------------------------------------------------- referências no projeto inteiro
# Frequência de cada identificador (texto bruto: comentário também conta, para errar do lado seguro)
$frequencia = New-Object 'System.Collections.Generic.Dictionary[string,int]'
foreach ($f in $todosPas + $dfmTexto) {
  $txt = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::Default)
  foreach ($m in [regex]::Matches($txt, '[A-Za-z_]\w*')) {
    $w = $m.Value.ToLower()
    if ($frequencia.ContainsKey($w)) { $frequencia[$w] = $frequencia[$w] + 1 } else { $frequencia[$w] = 1 }
  }
}
function Freq([string]$Nome) { $k = $Nome.ToLower(); if ($frequencia.ContainsKey($k)) { return $frequencia[$k] } return 0 }

$eventosNoDfm = @{}
foreach ($f in $dfmTexto) {
  foreach ($l in (Ler $f.FullName)) {
    if ($l -match '^\s*On\w+\s*=\s*(\w+)\s*$') { $eventosNoDfm[$Matches[1].ToLower()] = $true }
  }
}

# Eventos ligados por código (TClientDataSet(X).OnReconcileError := cdsReconcileError)
foreach ($f in $todosPas) {
  foreach ($l in (Ler-Limpo $f.FullName $false)) {
    foreach ($m in [regex]::Matches($l, '(?i)\bOn\w+\s*:=\s*(\w+)\s*;')) { $eventosNoDfm[$m.Groups[1].Value.ToLower()] = $true }
  }
}

# Herança de classes no projeto inteiro (para saber se TMeuDM descende de TDataModule)
$paiDe = @{}
foreach ($f in $todosPas) {
  foreach ($l in (Ler-Limpo $f.FullName $false)) {
    if ($l -match '^([A-Za-z_]\w*)\s*=\s*class\s*\(\s*([\w\.]+)') { $paiDe[$Matches[1].ToLower()] = ($Matches[2] -replace '^.*\.', '').ToLower() }
  }
}
function Test-DescendeDe([string]$Classe, [string]$Base) {
  $c = $Classe.ToLower(); $alvo = $Base.ToLower()
  for ($n = 0; $n -lt 30 -and $c; $n++) {
    if ($c -eq $alvo) { return $true }
    if (-not $paiDe.ContainsKey($c)) { return $false }
    $c = $paiDe[$c]
  }
  return $false
}

# ---------------------------------------------------------------- métricas de rotina
function Medir-Complexidade([string[]]$Codigo) {
  # $Codigo: linhas já sem comentários, strings vazias ('') e sem diretivas
  $cc = 1
  $pilha = New-Object System.Collections.Generic.List[string]
  $cond = ''
  foreach ($linha in $Codigo) {
    if (-not $linha) { continue }
    $topo = if ($pilha.Count -gt 0) { $pilha[$pilha.Count - 1] } else { '' }
    # Rótulo de case: linha que começa com "valor[, valor][..valor]:" (sem ser :=) dentro de case..of
    if ($topo -eq 'case' -and $linha -notmatch '^(else|end)\b' -and $linha -match "^[\w\.\+\-#\$\[\]\(\)\s,']+:(?!=)") { $cc++ }
    $temOn = $linha -match '\bon\s+\w+(\s*:\s*[\w\.]+)?\s+do\b'
    foreach ($m in [regex]::Matches($linha, '[A-Za-z_]\w*|;')) {
      $w = $m.Value.ToLower()
      switch ($w) {
        'if'     { $cc++; $cond = 'then' }
        'then'   { if ($cond -eq 'then') { $cond = '' } }
        'while'  { $cc++; $cond = 'do' }
        'do'     { if ($cond -eq 'do') { $cond = '' } }
        'for'    { $cc++ }
        'repeat' { $cc++ }
        'until'  { $cond = ';' }
        ';'      { if ($cond -eq ';') { $cond = '' } }
        'and'    { if ($cond) { $cc++ } }
        'or'     { if ($cond) { $cc++ } }
        'case'   { $pilha.Add('case0') }
        'of'     { if ($pilha.Count -gt 0 -and $pilha[$pilha.Count - 1] -eq 'case0') { $pilha[$pilha.Count - 1] = 'case' } }
        'begin'  { $pilha.Add('b') }
        'asm'    { $pilha.Add('b') }
        'record' { $pilha.Add('b') }
        'try'    { $pilha.Add('try') }
        'except' { $cc++; if ($pilha.Count -gt 0 -and $pilha[$pilha.Count - 1] -eq 'try') { $pilha[$pilha.Count - 1] = 'tryexc' } }
        'on'     { if ($temOn -and $pilha.Contains('tryexc')) { $cc++ } }
        'end'    { if ($pilha.Count -gt 0) { $pilha.RemoveAt($pilha.Count - 1) }; if ($cond -eq ';') { $cond = '' } }
      }
    }
  }
  return $cc
}

# Parâmetros var/out do cabeçalho (texto já limpo, pode ter várias linhas juntadas)
function Get-ParametrosVarOut([string]$Cabecalho) {
  $res = New-Object System.Collections.Generic.List[string]
  $ini = $Cabecalho.IndexOf('(')
  if ($ini -lt 0) { return , $res.ToArray() }
  $prof = 0; $fim = -1
  for ($i = $ini; $i -lt $Cabecalho.Length; $i++) {
    if ($Cabecalho[$i] -eq '(') { $prof++ } elseif ($Cabecalho[$i] -eq ')') { $prof--; if ($prof -eq 0) { $fim = $i; break } }
  }
  if ($fim -lt 0) { $fim = $Cabecalho.Length }
  foreach ($grupo in ($Cabecalho.Substring($ini + 1, $fim - $ini - 1) -split ';')) {
    $g = $grupo.Trim() -replace '\s+', ' '
    if ($g -match '^(?i)(var|out)\s+\w') { $res.Add($g) }
  }
  return , $res.ToArray()
}

# ---------------------------------------------------------------- DFM: componentes, SQL e tabelas
function Decodificar-StringDfm([string]$Texto) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($m in [regex]::Matches($Texto, "'((?:[^']|'')*)'|#(\d+)")) {
    if ($m.Groups[1].Success) { [void]$sb.Append($m.Groups[1].Value.Replace("''", "'")) }
    else { [void]$sb.Append([char][int]$m.Groups[2].Value) }
  }
  return $sb.ToString()
}

# Valor de propriedade do DFM em várias linhas: 'abc' + 'def' (ou + no fim da linha) é uma string
# só; cada linha de SQL.Strings sem + é um item separado (itens juntados com espaço)
function Decodificar-ValorDfm([string]$Texto) {
  $itensSql = New-Object System.Collections.Generic.List[string]
  $sb = New-Object System.Text.StringBuilder
  $continua = $false
  foreach ($m in [regex]::Matches($Texto, "'(?:[^']|'')*'|#\d+|\+|\n")) {
    $v = $m.Value
    if ($v -eq '+') { $continua = $true }
    elseif ($v -eq "`n") { if (-not $continua -and $sb.Length -gt 0) { $itensSql.Add($sb.ToString()); [void]$sb.Clear() } }
    else { [void]$sb.Append((Decodificar-StringDfm $v)); $continua = $false }
  }
  if ($sb.Length -gt 0) { $itensSql.Add($sb.ToString()) }
  return ($itensSql.ToArray() -join ' ')
}

$palavrasNaoTabela = @('SELECT', 'WHERE', 'SET', 'VALUES', 'FIRST', 'SKIP', 'LATERAL', 'ONLY', 'OR', 'AND', 'ON', 'AS', 'TABLE', 'THE')
function Get-Tabelas([string]$Sql) {
  $res = New-Object System.Collections.Generic.List[string]
  # EXTRACT(YEAR FROM x), SUBSTRING(x FROM 1), TRIM(x FROM y)... não são tabelas
  $s = $Sql -replace '(?is)\b(extract|substring|trim|position|overlay)\s*\([^)]*\)', ' '
  $s = $s -replace "'[^']*'", "''"
  foreach ($m in [regex]::Matches($s, '(?i)\b(from|join|into|update)\s+("?[A-Za-z_][\w\$]*"?(\s*\.\s*"?[A-Za-z_][\w\$]*"?)?)')) {
    $nome = ($m.Groups[2].Value -replace '[\s"]', '').ToUpper()
    $nome = $nome -replace '^.*\.', ''
    if ($palavrasNaoTabela -contains $nome) { continue }
    # Tabelas de sistema (Firebird/InterBase, Oracle) não são assunto do DataModule
    if ($nome -match '^(RDB\$|MON\$|SEC\$)' -or $nome -eq 'DUAL') { continue }
    if (-not $res.Contains($nome)) { $res.Add($nome) }
  }
  return , $res.ToArray()
}

function Ler-Dfm([string[]]$Linhas) {
  $res = [pscustomobject]@{ Raiz = ''; ClasseRaiz = ''; Componentes = 0; Datasets = 0; Campos = 0; Topo = (New-Object System.Collections.Generic.List[object]) }
  $pilha = 0
  $atual = $null
  $propsRef = '^(MasterSource|DataSet|DataSource|ProviderName|LookupDataSet|DataSetProvider|UpdateObject)$'
  $propsSql = '^(?i)(\w+\.)?(SQL|CommandText|SelectSQL|InsertSQL|UpdateSQL|DeleteSQL|RefreshSQL|ModifySQL)(\.Strings)?$'
  $i = 0
  while ($i -lt $Linhas.Count) {
    $t = $Linhas[$i].Trim()
    if ($t -match '^(object|inherited|inline)\s+(\w+)\s*:\s*([\w\.]+)') {
      $nome = $Matches[2]; $classe = $Matches[3]; $tipo = $Matches[1]
      if ($pilha -eq 0) { $res.Raiz = $nome; $res.ClasseRaiz = $classe }
      else {
        $res.Componentes++
        if ($classe -match $reDados) { $res.Datasets++ }
        if ($classe -match 'Field$') { $res.Campos++ }
        if ($pilha -eq 1) {
          $atual = [pscustomobject]@{ Nome = $nome; Classe = $classe; Linha = $i + 1; Herdado = ($tipo -eq 'inherited')
            Refs = (New-Object System.Collections.Generic.List[string]); Tabelas = (New-Object System.Collections.Generic.List[string]) }
          $res.Topo.Add($atual)
        }
      }
      $pilha++; $i++; continue
    }
    if ($t -eq 'item') { $pilha++; $i++; continue }
    # Fechou um componente de primeiro nível (pilha volta a 1): as propriedades seguintes são da raiz
    if ($t -match '^end>?$') { $pilha--; if ($pilha -le 1) { $atual = $null }; $i++; continue }
    if ($atual -and $pilha -ge 2 -and $t -match '^([\w\.]+)\s*=\s*(.*)$') {
      $prop = $Matches[1]; $valor = $Matches[2]
      if ($prop -match $propsRef) { $atual.Refs.Add(($valor.Trim().Trim("'") -replace '^.*\.', '')) }
      elseif ($prop -ieq 'TableName') { $tab = (Decodificar-StringDfm $valor).Trim().ToUpper(); if ($tab -and -not $atual.Tabelas.Contains($tab)) { $atual.Tabelas.Add($tab) } }
      elseif ($prop -match $propsSql) {
        $texto = $valor
        if ($valor.Trim() -eq '(' -or $valor.Trim().StartsWith('(')) {
          while ($i + 1 -lt $Linhas.Count -and -not $texto.TrimEnd().EndsWith(')')) { $i++; $texto += "`n" + $Linhas[$i].Trim() }
        } else {
          while ($i + 1 -lt $Linhas.Count -and ($texto.Trim() -eq '' -or $texto.TrimEnd().EndsWith('+'))) { $i++; $texto += "`n" + $Linhas[$i].Trim() }
        }
        $sql = Decodificar-ValorDfm $texto
        foreach ($tab in (Get-Tabelas $sql)) { if (-not $atual.Tabelas.Contains($tab)) { $atual.Tabelas.Add($tab) } }
      }
    }
    $i++
  }
  return $res
}

# DFM herdado (inherited TMeuDM): junta os componentes e ligações do DFM do ancestral, senão um
# "inherited cdsControl" sem ProviderName parece solto. Contagem de componentes continua só a do filho.
$dfmPorClasse = @{}
foreach ($f in $dfmTexto) {
  foreach ($l in (Ler $f.FullName)) {
    if ($l -match '^\s*(object|inherited|inline)\s+\w+\s*:\s*(\w+)') { $dfmPorClasse[$Matches[2].ToLower()] = $f.FullName; break }
  }
}
function Ler-DfmComHeranca([string]$Caminho, [int]$Nivel = 0) {
  $linhasDfm = Ler $Caminho
  $info = Ler-Dfm $linhasDfm
  $primeira = @($linhasDfm | Where-Object { $_.Trim() } | Select-Object -First 1)
  if ($Nivel -ge 10 -or $primeira.Count -eq 0 -or $primeira[0].Trim() -notmatch '^inherited\s') { return $info }
  $pai = $paiDe[$info.ClasseRaiz.ToLower()]
  if (-not $pai -or -not $dfmPorClasse.ContainsKey($pai) -or $dfmPorClasse[$pai] -eq $Caminho) { return $info }
  $ancestral = Ler-DfmComHeranca $dfmPorClasse[$pai] ($Nivel + 1)
  foreach ($ca in $ancestral.Topo) {
    $proprio = $null
    foreach ($cp in $info.Topo) { if ($cp.Nome -ieq $ca.Nome) { $proprio = $cp } }
    if ($proprio) {
      foreach ($x in $ca.Refs) { if (-not $proprio.Refs.Contains($x)) { $proprio.Refs.Add($x) } }
      # Tabelas do ancestral só valem se o filho não redefiniu o SQL
      if ($proprio.Tabelas.Count -eq 0) { foreach ($x in $ca.Tabelas) { $proprio.Tabelas.Add($x) } }
    } else {
      $ca.Herdado = $true
      $info.Topo.Add($ca)
    }
  }
  return $info
}

# Assuntos de um DataModule: grupos de datasets ligados entre si (mesma tabela, mestre-detalhe,
# DataSource -> DataSet, Provider, Lookup). Conexões ficam fora (ligariam tudo).
function Get-Assuntos($Dfm, [string[]]$TabelasDoCodigo, [hashtable]$TabelasPorComponente) {
  $paiUF = @{}
  function Raiz([string]$x) { while ($paiUF[$x] -ne $x) { $paiUF[$x] = $paiUF[$paiUF[$x]]; $x = $paiUF[$x] }; return $x }
  function Unir([string]$a, [string]$b) { $ra = Raiz $a; $rb = Raiz $b; if ($ra -ne $rb) { $paiUF[$ra] = $rb } }
  $nomes = @{}
  foreach ($c in $Dfm.Topo) {
    if ($c.Classe -match '(Connection|Database|Session|Transaction)$') { continue }
    if ($c.Classe -notmatch $reDados -and $c.Classe -notmatch '(DataSource|Provider|UpdateSQL)$') { continue }
    $nomes[$c.Nome.ToLower()] = $c
    $paiUF['c:' + $c.Nome.ToLower()] = 'c:' + $c.Nome.ToLower()
  }
  $todasTabelas = New-Object System.Collections.Generic.List[string]
  foreach ($c in $nomes.Values) {
    $chave = 'c:' + $c.Nome.ToLower()
    $tabs = New-Object System.Collections.Generic.List[string]
    foreach ($t in $c.Tabelas) { $tabs.Add($t) }
    if ($TabelasPorComponente.ContainsKey($c.Nome.ToLower())) { foreach ($t in $TabelasPorComponente[$c.Nome.ToLower()]) { $tabs.Add($t) } }
    foreach ($t in $tabs) {
      if (-not $paiUF.ContainsKey("t:$t")) { $paiUF["t:$t"] = "t:$t" }
      Unir $chave "t:$t"
      if (-not $todasTabelas.Contains($t)) { $todasTabelas.Add($t) }
    }
    foreach ($ref in $c.Refs) { if ($nomes.ContainsKey($ref.ToLower())) { Unir $chave ('c:' + $ref.ToLower()) } }
  }
  foreach ($t in $TabelasDoCodigo) {
    if (-not $paiUF.ContainsKey("t:$t")) { $paiUF["t:$t"] = "t:$t" }
    if (-not $todasTabelas.Contains($t)) { $todasTabelas.Add($t) }
  }
  $grupos = @{}
  foreach ($k in @($paiUF.Keys)) {
    $rz = Raiz $k
    if (-not $grupos.ContainsKey($rz)) { $grupos[$rz] = New-Object System.Collections.Generic.List[string] }
    $grupos[$rz].Add($k)
  }
  # Um assunto precisa ter dataset ou tabela (DataSource solto não é assunto)
  $lista = New-Object System.Collections.Generic.List[string]
  foreach ($g in $grupos.Values) {
    $ds = @($g | Where-Object { $_.StartsWith('c:') -and $nomes[$_.Substring(2)].Classe -match $reDataset } | ForEach-Object { $nomes[$_.Substring(2)].Nome })
    $tb = @($g | Where-Object { $_.StartsWith('t:') } | ForEach-Object { $_.Substring(2) } | Sort-Object)
    if ($ds.Count -eq 0 -and $tb.Count -eq 0) { continue }
    $dsTxt = if ($ds.Count -gt 4) { (($ds | Select-Object -First 4) -join ', ') + ", +$($ds.Count - 4)" } else { $ds -join ', ' }
    if (-not $dsTxt) { $dsTxt = '(SQL no código)' }
    $lista.Add("$dsTxt [$($tb -join ', ')]")
  }
  return [pscustomobject]@{ Grupos = $lista.ToArray(); Tabelas = $todasTabelas.ToArray() }
}

# ---------------------------------------------------------------- análise das units do escopo
$metodosMedidos = New-Object System.Collections.Generic.List[object]
$unitsMedidas = New-Object System.Collections.Generic.List[object]
$candRemocao = New-Object System.Collections.Generic.List[object]

foreach ($f in $pas) {
  $linhas = Ler $f.FullName
  $limpas = Ler-Limpo $f.FullName $false
  $r = Rel $f.FullName
  $ehDpr = $f.Extension -ieq '.dpr'

  # --- membros de classe declarados (visibilidade e diretivas), classes e herança
  $membros = @{}
  $classes = New-Object System.Collections.Generic.List[object]
  $classeAtual = ''; $visib = ''
  $secao = 'inicio'
  for ($i = 0; $i -lt $limpas.Count; $i++) {
    $c = $limpas[$i]
    if ($c -match '^(?i)implementation\b') { $secao = 'implementation' }
    elseif ($c -match '^(?i)interface\b') { $secao = 'interface' }
    if ($c -match '^(?i)([A-Za-z_]\w*)(\s*<[^>]*>)?\s*=\s*(packed\s+)?class\b(?!\s*(of\b|;))') {
      $nomeClasse = $Matches[1]
      $pai = if ($c -match '(?i)class\s*(sealed|abstract)?\s*\(\s*([\w\.]+)') { $Matches[2] -replace '^.*\.', '' } else { 'TObject' }
      $classes.Add([pscustomobject]@{ Nome = $nomeClasse; Linha = $i + 1; Pai = $pai })
      # Classe completa numa linha só: "TX = class(TY);" ou "TX = class(TY) end;"
      if ($c -match '\)\s*;\s*$' -or $c -match '\bend\s*;\s*$') { continue }
      $classeAtual = $nomeClasse.ToLower()
      $visib = if ((Test-DescendeDe $nomeClasse 'TPersistent') -or (Test-DescendeDe $nomeClasse 'TComponent') -or $pai -match '^T(Form|DataModule|Frame|Component|Persistent|CustomForm)$') { 'published' } else { 'public' }
      continue
    }
    if ($classeAtual) {
      if ($c -match '^(?i)end\s*;') { $classeAtual = ''; continue }
      if ($c -match '^(?i)(strict\s+)?(private|protected|public|published)\b') { $visib = $Matches[2].ToLower() }
      if ($c -match '^(?i)(class\s+)?(procedure|function|constructor|destructor)\s+(\w+)') {
        $nomeM = $Matches[3].ToLower()
        $diretivas = $c
        $j = $i + 1
        while ($j -lt $limpas.Count -and $limpas[$j] -match '^(?i)(virtual|override|dynamic|abstract|message|reintroduce|overload|stdcall|cdecl|inline|static|final)\b') { $diretivas += ' ' + $limpas[$j]; $j++ }
        $membros["$classeAtual.$nomeM"] = [pscustomobject]@{ Visib = $visib; Heranca = ($diretivas -match '(?i)\b(virtual|override|dynamic|abstract|message)\b') }
      }
    }
  }

  # --- itens de limpeza linha a linha
  $comentadas = 0
  $emImpl = $false
  $metodoAtual = $null
  for ($i = 0; $i -lt $linhas.Count; $i++) {
    $l = $linhas[$i]
    $t = $l.Trim()
    $c = $limpas[$i]
    $pos = "$r`:$($i + 1)"
    if ($c -match '^(?i)implementation\b') { $emImpl = $true }

    if ($t -match '^\s*//') {
      if ($t -match '(:=|;\s*$|\bbegin\b|\bend\b|\bthen\b)') { $comentadas++ } else { $comentadas = 0 }
      if ($comentadas -eq 3) { $itens['Código comentado'].Add("$r`:$($i - 1)  $t") }
      continue
    } else { $comentadas = 0 }

    if ($c -match '(?i)\bwith\s+.+\bdo\b') { $itens['with'].Add("$pos  $t") }
    if ($c -match '^(?i)except$') {
      $j = $i + 1
      while ($j -lt $limpas.Count -and $limpas[$j] -eq '') { $j++ }
      if ($j -lt $limpas.Count -and $limpas[$j] -match '^(?i)end;?$') { $itens['except vazio'].Add("$pos  except ... end") }
    }
    # Objeto com dono (Create(Application/Self/AOwner/Owner)) é liberado pelo dono: não precisa de try/finally
    if ($c -match '^(\w+)\s*:=\s*T\w+\.Create\b' -and $Matches[1] -ne 'Result' -and
        $c -notmatch '\.Create\s*\(\s*(Application|Self|AOwner|Owner)\s*[,)]') {
      $j = $i + 1
      while ($j -lt $limpas.Count -and $limpas[$j] -eq '') { $j++ }
      if ($j -lt $limpas.Count -and $limpas[$j] -notmatch '^(?i)try\b') { $itens['Create sem try/finally'].Add("$pos  $t") }
    }
    if ($c -match '^(?i)Result\s*:=\s*T\w+\.Create\b') { $itens['Função devolve objeto criado'].Add("$pos  $t") }
    if ($c -match '(?i)Application\.ProcessMessages') { $itens['Application.ProcessMessages'].Add("$pos  $t") }
    # Senha: identificador no código (fora de string) recebendo um literal não vazio, ou
    # "Password=..." dentro de uma string de conexão. 'Password: ' + Campo (mensagem) não conta.
    $senhaCodigo = $c -match "(?i)\w*(password|senha|pwd)\w*\s*:?=\s*''" -and $t -match "(?i)(password|senha|pwd)\w*\s*:?=\s*'[^']+'"
    $senhaConexao = $t -match "(?i)'[^']*\b(password|senha|pwd)=[^';]+"
    if ($senhaCodigo -or $senhaConexao) {
      $itens['Senha no código ou DFM'].Add("$pos  (valor omitido)")
    }

    # --- limites de rotina (mesma regra do Get-DiagnosticoLegado: cabeçalho na coluna 0 da
    # implementation; a rotina vai até o último "end;" na coluna 0 antes do próximo cabeçalho)
    if ($emImpl -and -not $ehDpr) {
      if ($l -match $reMetodo -or $l -match $reFimBloco) {
        if ($metodoAtual) {
          $metodoAtual.Fim = if ($metodoAtual.UltimoEnd -gt 0) { $metodoAtual.UltimoEnd } else { $i }
          $metodosMedidos.Add($metodoAtual); $metodoAtual = $null
        }
        if ($l -match $reMetodo) {
          $metodoAtual = [pscustomobject]@{ Arquivo = $r; Nome = $Matches[3]; Inicio = $i + 1; Fim = 0; UltimoEnd = 0; Limpas = $limpas }
        }
      } elseif ($metodoAtual -and $l -match '^end;') { $metodoAtual.UltimoEnd = $i + 1 }
    }

    # --- métodos sem uso: o nome aparece no máximo 2 vezes no projeto (declaração + implementação)
    if ($emImpl -and $l -match '^(procedure|function)\s+(T\w+)\.(\w+)') {
      $classeM = $Matches[2]; $nome = $Matches[3]
      $info = $membros["$($classeM.ToLower()).$($nome.ToLower())"]
      if (-not $eventosNoDfm.ContainsKey($nome.ToLower()) -and (Freq $nome) -le 2 -and -not ($info -and $info.Heranca)) {
        $obs = if ($info -and $info.Visib -eq 'published') { ' (published: confira DFMs herdados e RTTI)' } else { '' }
        $candRemocao.Add([pscustomobject]@{ Tipo = 'Método possivelmente sem uso'; Texto = "$pos  $classeM.$nome$obs" })
      }
    }
  }
  if ($metodoAtual) {
    $metodoAtual.Fim = if ($metodoAtual.UltimoEnd -gt 0) { $metodoAtual.UltimoEnd } else { $linhas.Count }
    $metodosMedidos.Add($metodoAtual)
  }

  if (-not $ehDpr) {
    $unitsMedidas.Add([pscustomobject]@{ Arquivo = $r; Caminho = $f.FullName; Linhas = $linhas.Count; Classes = $classes.ToArray(); Limpas = $limpas })
  }
}

# Senha no DFM
foreach ($f in $dfm) {
  $i = 0
  foreach ($l in (Ler $f.FullName)) {
    $i++
    if ($l -match "(?i)'(password|senha|pwd)=[^']+'" -or $l -match "(?i)^\s*Password\s*=\s*'[^']+'") {
      $itens['Senha no código ou DFM'].Add("$(Rel $f.FullName):$i  (valor omitido)")
    }
  }
}

# .dpr sem ReportMemoryLeaksOnShutdown
foreach ($d in @($pas | Where-Object { $_.Extension -ieq '.dpr' })) {
  if (-not ([IO.File]::ReadAllText($d.FullName, [Text.Encoding]::Default) -match 'ReportMemoryLeaksOnShutdown')) {
    $itens['.dpr sem ReportMemoryLeaksOnShutdown'].Add("$(Rel $d.FullName):1  $($d.Name)")
  }
}

# ---------------------------------------------------------------- métodos: tamanho, complexidade, var/out
$listaMetodos = New-Object System.Collections.Generic.List[object]
$listaVarOut = New-Object System.Collections.Generic.List[object]
foreach ($m in $metodosMedidos) {
  $lim = $m.Limpas
  $ini = $m.Inicio - 1
  # Cabeçalho: até fechar os parênteses e achar o ";"
  $cab = ''; $k = $ini
  while ($k -lt $m.Fim -and $k -lt $lim.Count) {
    $cab += ' ' + $lim[$k]
    $abre = ([regex]::Matches($cab, '\(')).Count; $fecha = ([regex]::Matches($cab, '\)')).Count
    if ($abre -le $fecha -and $cab -match ';') { break }
    $k++
  }
  $corpo = New-Object System.Collections.Generic.List[string]
  for ($x = $k + 1; $x -lt $m.Fim -and $x -lt $lim.Count; $x++) { $corpo.Add(($lim[$x] -replace '\{\$[^}]*\}', '').Trim()) }
  $qtdLinhas = $m.Fim - $m.Inicio + 1
  $cc = Medir-Complexidade $corpo.ToArray()
  $listaMetodos.Add([pscustomobject]@{ Arquivo = $m.Arquivo; Inicio = $m.Inicio; Nome = $m.Nome; Linhas = $qtdLinhas; CC = $cc })

  $params = Get-ParametrosVarOut $cab
  if ($params.Count -gt 0) {
    # "var A, B: Integer" são 2 parâmetros
    $qtdNomes = 0
    foreach ($g in $params) { $qtdNomes += @((($g -replace '^(?i)(var|out)\s+', '') -split ':')[0] -split ',').Count }
    # Evento: tem Sender: TObject ou está ligado num DFM/código (OnUpdateError := ...): a assinatura é da VCL
    $evento = ($cab -match '(?i)\bSender\s*:\s*TObject') -or $eventosNoDfm.ContainsKey(($m.Nome -replace '^.*\.', '').ToLower())
    $listaVarOut.Add([pscustomobject]@{ Arquivo = $m.Arquivo; Inicio = $m.Inicio; Nome = $m.Nome; Params = $params; Qtd = $qtdNomes; Evento = $evento })
  }
}
foreach ($m in ($listaMetodos | Sort-Object -Property @{ Expression = 'CC'; Descending = $true }, @{ Expression = 'Linhas'; Descending = $true })) {
  $alta = ($m.CC -gt $LimiteComplexidadeAlta) -or ($m.Linhas -ge 2 * $LimiteLinhasMetodo)
  $media = ($m.CC -gt $LimiteComplexidade) -or ($m.Linhas -ge $LimiteLinhasMetodo)
  $txt = "$($m.Arquivo):$($m.Inicio)  $($m.Nome): $($m.Linhas) linhas, complexidade $($m.CC)"
  if ($alta) { $itens['Método crítico (muito grande ou complexo)'].Add($txt) }
  elseif ($media) { $itens['Método grande ou complexo'].Add($txt) }
}
foreach ($v in ($listaVarOut | Sort-Object -Property @{ Expression = { $_.Qtd }; Descending = $true })) {
  $txt = "$($v.Arquivo):$($v.Inicio)  $($v.Nome)(" + ($v.Params -join '; ') + ')'
  if ($v.Evento) { $itens['Parâmetro var/out em evento'].Add($txt) }
  elseif ($v.Qtd -ge $LimiteVarOut) { $itens['Rotina com muitos var/out'].Add($txt) }
  else { $itens['Parâmetro var/out'].Add($txt) }
}

# ---------------------------------------------------------------- units, classes e DataModules
$dfmPorBase = @{}
foreach ($f in $dfm) { $dfmPorBase[[IO.Path]::ChangeExtension($f.FullName, $null).ToLower()] = $f }

foreach ($u in ($unitsMedidas | Sort-Object Linhas -Descending)) {
  $base = [IO.Path]::ChangeExtension($u.Caminho, $null).ToLower()
  $dfmU = $dfmPorBase[$base]
  $ehDM = $false; $infoDfm = $null
  if ($dfmU) {
    $infoDfm = Ler-DfmComHeranca $dfmU.FullName
    $ehDM = Test-DescendeDe $infoDfm.ClasseRaiz 'TDataModule'
  }
  if (-not $ehDM) { foreach ($cl in $u.Classes) { if (Test-DescendeDe $cl.Nome 'TDataModule') { $ehDM = $true } } }
  $linhaClasse = 1
  if ($infoDfm) { foreach ($cl in $u.Classes) { if ($cl.Nome -ieq $infoDfm.ClasseRaiz) { $linhaClasse = $cl.Linha } } }

  if ($ehDM) {
    $comp = if ($infoDfm) { $infoDfm.Componentes } else { 0 }
    $ds = if ($infoDfm) { $infoDfm.Datasets } else { 0 }
    $campos = if ($infoDfm) { $infoDfm.Campos } else { 0 }
    $txt = "$($u.Arquivo):$linhaClasse  $(if ($infoDfm) { $infoDfm.ClasseRaiz } else { 'DataModule' }): $($u.Linhas) linhas, $comp componentes (dos quais $campos campos persistentes), $ds componentes de dados"
    if ($u.Linhas -ge 2 * $LimiteLinhasUnit -or $comp -ge 2 * $LimiteComponentesDM -or $ds -ge 2 * $LimiteDatasetsDM) { $itens['DataModule gigante'].Add($txt) }
    elseif ($u.Linhas -ge $LimiteLinhasUnit -or $comp -ge $LimiteComponentesDM -or $ds -ge $LimiteDatasetsDM) { $itens['DataModule grande'].Add($txt) }

    # Assuntos: tabelas do DFM e do SQL montado no .pas
    if ($infoDfm) {
      $porComp = @{}; $soltas = New-Object System.Collections.Generic.List[string]
      $limpasStr = Ler-Limpo $u.Caminho $true
      $nomesComp = @{}; foreach ($cmp in $infoDfm.Topo) { $nomesComp[$cmp.Nome.ToLower()] = $true }
      foreach ($cs in $limpasStr) {
        if ($cs -notmatch '(?i)\b(SQL|CommandText|TableName)\b') { continue }
        $literais = ([regex]::Matches($cs, "'(?:[^']|'')*'") | ForEach-Object { $_.Value.Trim("'").Replace("''", "'") }) -join ' '
        if (-not $literais) { continue }
        $tabs = if ($cs -match '(?i)\bTableName\s*:=') { @($literais.Trim().ToUpper()) } else { Get-Tabelas $literais }
        $dono = if ($cs -match '^(\w+)\.(SQL|CommandText|TableName)\b' -and $nomesComp.ContainsKey($Matches[1].ToLower())) { $Matches[1].ToLower() } else { '' }
        foreach ($tb in $tabs) {
          if (-not $tb) { continue }
          if ($dono) { if (-not $porComp.ContainsKey($dono)) { $porComp[$dono] = New-Object System.Collections.Generic.List[string] }; $porComp[$dono].Add($tb) }
          elseif (-not $soltas.Contains($tb)) { $soltas.Add($tb) }
        }
      }
      $assuntos = Get-Assuntos $infoDfm $soltas.ToArray() $porComp
      $qa = $assuntos.Grupos.Count; $qt = $assuntos.Tabelas.Count
      if ($qa -ge $LimiteAssuntosDM -or $qt -ge $LimiteTabelasDM) {
        $txt = "$($u.Arquivo):$linhaClasse  $($infoDfm.ClasseRaiz): $qa assuntos, $qt tabelas"
        foreach ($g in $assuntos.Grupos) { $txt += "`n$g" }
        if ($qa -ge 2 * $LimiteAssuntosDM -or $qt -ge 2 * $LimiteTabelasDM) { $itens['DataModule com assuntos demais'].Add($txt) }
        else { $itens['DataModule com muitos assuntos'].Add($txt) }
      }
    }
  } else {
    $txt = "$($u.Arquivo):1  $($u.Linhas) linhas"
    if ($u.Linhas -ge 2 * $LimiteLinhasUnit) { $itens['Unit gigante'].Add($txt) }
    elseif ($u.Linhas -ge $LimiteLinhasUnit) { $itens['Unit grande'].Add($txt) }
  }

  $qc = $u.Classes.Count
  if ($qc -ge $LimiteClassesUnit) {
    $txt = "$($u.Arquivo):$($u.Classes[0].Linha)  $qc classes: " + ((($u.Classes | Select-Object -First 8) | ForEach-Object { $_.Nome }) -join ', ') + $(if ($qc -gt 8) { ', ...' } else { '' })
    if ($qc -ge 2 * $LimiteClassesUnit) { $itens['Unit com classes demais'].Add($txt) } else { $itens['Unit com muitas classes'].Add($txt) }
  }

  # Componentes de dados que parecem não ser usados (nome só no DFM e na declaração do .pas)
  if ($infoDfm) {
    foreach ($cmp in $infoDfm.Topo) {
      if ($cmp.Herdado) { continue }
      if ($cmp.Classe -notmatch $reDados -and $cmp.Classe -notmatch 'DataSource$') { continue }
      if ($cmp.Classe -match '(Connection|Database|Session|Transaction)$') { continue }
      if ((Freq $cmp.Nome) -le 2) {
        $candRemocao.Add([pscustomobject]@{ Tipo = 'Componente de dados possivelmente sem uso'; Texto = "$(Rel $dfmU.FullName):$($cmp.Linha)  $($cmp.Nome): $($cmp.Classe)" })
      }
    }
  }
}

# Remoções: no escopo parcial, nada que possa ser usado em outra parte do sistema é removido
foreach ($cand in $candRemocao) {
  if ($parcial) { $itens['Não remover: escopo parcial'].Add("$($cand.Texto)  [$($cand.Tipo)]") }
  else { $itens[$cand.Tipo].Add($cand.Texto) }
}

# ---------------------------------------------------------------- duplicação
# Mesma ideia do Get-DiagnosticoLegado (janelas de N linhas não triviais iguais, com 150+ caracteres),
# ignorando comentários e juntando janelas consecutivas num bloco só. Procura no projeto inteiro e
# relata os blocos com pelo menos uma ocorrência no escopo.
$trivial = '^(begin|end;?|end\.|try|finally|except|else|\)|\(|;|)$'
$janelas = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[string]]'
$normPorArquivo = @{}
$relEscopo = @{}; foreach ($f in $pas) { $relEscopo[(Rel $f.FullName)] = $true }
foreach ($f in @($todosPas | Where-Object { $_.Extension -ieq '.pas' })) {
  $relArq = Rel $f.FullName
  $limpasStr = Ler-Limpo $f.FullName $true
  $norm = New-Object System.Collections.Generic.List[object]
  for ($i = 0; $i -lt $limpasStr.Count; $i++) {
    $t = ($limpasStr[$i] -replace '\{\$[^}]*\}', '').Trim().ToLower() -replace '\s+', ' '
    if ($t -match $trivial) { continue }
    $norm.Add(@(($i + 1), $t))
  }
  $normPorArquivo[$relArq] = $norm
  for ($i = 0; $i + $JanelaDuplicacao -le $norm.Count; $i++) {
    $partes = for ($j = 0; $j -lt $JanelaDuplicacao; $j++) { $norm[$i + $j][1] }
    $chave = $partes -join "`n"
    if ($chave.Length -lt 150) { continue }
    if (-not $janelas.ContainsKey($chave)) { $janelas[$chave] = New-Object System.Collections.Generic.List[string] }
    $janelas[$chave].Add("$relArq|$i")
  }
}
$ocorrKey = @{}
$dupKeys = New-Object System.Collections.Generic.List[string]
foreach ($par in $janelas.GetEnumerator()) {
  if ($par.Value.Count -lt 2) { continue }
  $dupKeys.Add($par.Key)
  foreach ($o in $par.Value) { $ocorrKey[$o] = $par.Key }
}
# Janela K continua a janela K' se todas as ocorrências de K começam uma linha depois das de K'
$antecessor = @{}
foreach ($key in $dupKeys) {
  $ocs = $janelas[$key]; $prev = $null; $ok = $true
  foreach ($o in $ocs) {
    $arq, $idx = $o -split '\|'
    $ant = "$arq|$([int]$idx - 1)"
    if (-not $ocorrKey.ContainsKey($ant)) { $ok = $false; break }
    if ($null -eq $prev) { $prev = $ocorrKey[$ant] } elseif ($ocorrKey[$ant] -ne $prev) { $ok = $false; break }
  }
  if ($ok -and $prev -and $janelas[$prev].Count -eq $ocs.Count -and $prev -ne $key) { $antecessor[$key] = $prev }
}
$blocos = New-Object System.Collections.Generic.List[object]
foreach ($key in $dupKeys) {
  if ($antecessor.ContainsKey($key)) { continue }
  $ocs = $janelas[$key]
  $arq0, $idx0 = $ocs[0] -split '\|'
  $tam = 1; $atualK = $key
  while ($tam -lt 100000) {
    $prox = "$arq0|$([int]$idx0 + $tam)"
    if (-not $ocorrKey.ContainsKey($prox)) { break }
    $candK = $ocorrKey[$prox]
    if ($antecessor.ContainsKey($candK) -and $antecessor[$candK] -eq $atualK) { $atualK = $candK; $tam++ } else { break }
  }
  $linhasBloco = $JanelaDuplicacao + $tam - 1
  $locais = New-Object System.Collections.Generic.List[string]
  $noEscopo = $false
  foreach ($o in $ocs) {
    $arq, $idx = $o -split '\|'
    $n = $normPorArquivo[$arq]
    $ini = $n[[int]$idx][0]; $fimIdx = [Math]::Min([int]$idx + $linhasBloco - 1, $n.Count - 1); $fim = $n[$fimIdx][0]
    $locais.Add("$arq`:$ini-$fim")
    if ($relEscopo.ContainsKey($arq)) { $noEscopo = $true }
  }
  if (-not $noEscopo) { continue }
  $blocos.Add([pscustomobject]@{ Ocorrencias = $ocs.Count; Linhas = $linhasBloco; Locais = $locais.ToArray(); Primeira = ($key -split "`n")[0] })
}
foreach ($b in ($blocos | Sort-Object -Property @{ Expression = { $_.Ocorrencias * $_.Linhas }; Descending = $true })) {
  $mostrar = ($b.Locais | Select-Object -First 6) -join ', '
  if ($b.Locais.Count -gt 6) { $mostrar += ', ...' }
  $inicioTxt = if ($b.Primeira.Length -gt 60) { $b.Primeira.Substring(0, 57) + '...' } else { $b.Primeira }
  $txt = "$($b.Locais[0])  $($b.Ocorrencias) ocorrências de ~$($b.Linhas) linhas: $mostrar (começa com: $inicioTxt)"
  if ($b.Ocorrencias -ge 3 -or $b.Linhas -ge 3 * $JanelaDuplicacao) { $itens['Código duplicado extenso'].Add($txt) }
  else { $itens['Código duplicado'].Add($txt) }
}

# ---------------------------------------------------------------- relatório
$ordemPrioridade = @(@('alta', 'A', 'Prioridade alta'), @('média', 'M', 'Prioridade média'), @('baixa', 'B', 'Prioridade baixa'), @('info', 'N', 'Não remover: escopo parcial'))
$codigo = @{}
foreach ($op in $ordemPrioridade) {
  $seq = 0
  foreach ($k in $tipos.Keys) {
    if ($tipos[$k][0] -ne $op[0] -or $itens[$k].Count -eq 0) { continue }
    $seq++; $codigo[$k] = "$($op[1])$seq"
  }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Limpeza: levantamento priorizado')
$md.Add('')
$escopoTxt = if ($parcial) { "parcial ($($pas.Count) units: $((($pas | ForEach-Object { Rel $_.FullName }) -join ', '))); referências procuradas em $($todosPas.Count) units e $($dfmTexto.Count) DFMs de ``$Pasta``" } else { "projeto todo ($($pas.Count) units)" }
$md.Add("Pasta: ``$Pasta`` · Escopo: $escopoTxt · Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$md.Add('')
$md.Add('Todo item é candidato: confirme antes de corrigir. Nada aqui é feito sem a decisão do usuário.')
$md.Add('Os riscos (tamanho, complexidade, classes, assuntos, var/out, duplicação) são apontados, não corrigidos: a recomendação diz qual skill usar.')
$md.Add("Limites: unit $LimiteLinhasUnit linhas · método $LimiteLinhasMetodo linhas · complexidade > $LimiteComplexidade (alta > $LimiteComplexidadeAlta) · $LimiteClassesUnit classes por unit · DataModule $LimiteComponentesDM componentes ou $LimiteDatasetsDM de dados · $LimiteAssuntosDM assuntos ou $LimiteTabelasDM tabelas por DataModule · duplicação em janelas de $JanelaDuplicacao linhas · $LimiteVarOut var/out por rotina. O nível alto começa no dobro do limite (complexidade: no limite alto).")
if ($parcial) {
  $md.Add('')
  $md.Add('> **Escopo parcial**: métodos, componentes e units que parecem sem uso NÃO são sugeridos para remoção (veja a seção "Não remover: escopo parcial"). Outras partes do sistema, outros projetos, pacotes, DFMs herdados e RTTI podem usá-los.')
}
if ($dfmBinarios.Count -gt 0) {
  $md.Add('')
  $md.Add("> **Atenção**: $($dfmBinarios.Count) DFM(s) binário(s) não foram lidos ($((($dfmBinarios | Select-Object -First 5 | ForEach-Object { Rel $_.FullName }) -join ', '))$(if ($dfmBinarios.Count -gt 5) { ', ...' })). Eventos ligados neles não aparecem: não confie em ""sem uso"" sem converter para texto antes.")
}
$md.Add('')
$md.Add('| Item | Quantidade | Prioridade | Código | Risco de corrigir |')
$md.Add('|---|---|---|---|---|')
foreach ($op in $ordemPrioridade) {
  foreach ($k in $tipos.Keys) {
    if ($tipos[$k][0] -ne $op[0]) { continue }
    if ($op[0] -eq 'info' -and -not $parcial) { continue }
    $cod = if ($codigo.ContainsKey($k)) { $codigo[$k] } else { '-' }
    $md.Add("| $k | $($itens[$k].Count) | $($op[0]) | $cod | $($tipos[$k][1]) |")
  }
}

foreach ($op in $ordemPrioridade) {
  $temAlgum = $false
  foreach ($k in $tipos.Keys) { if ($tipos[$k][0] -eq $op[0] -and $itens[$k].Count -gt 0) { $temAlgum = $true } }
  if ($op[0] -eq 'info' -and -not $temAlgum) { continue }
  $md.Add('')
  $md.Add("## $($op[2])")
  if (-not $temAlgum) { $md.Add(''); $md.Add('Nenhum item.'); continue }
  foreach ($k in $tipos.Keys) {
    if ($tipos[$k][0] -ne $op[0] -or $itens[$k].Count -eq 0) { continue }
    $md.Add('')
    $md.Add("### $($codigo[$k]). $k ($($itens[$k].Count))")
    $md.Add("Risco de corrigir: $($tipos[$k][1]) · Benefício: $($tipos[$k][2]) · Recomendação: $($tipos[$k][3])")
    $md.Add('')
    foreach ($it in ($itens[$k] | Select-Object -First $MaxPorItem)) {
      $partes = $it -split "`n"
      $md.Add("- ``$($partes[0])``")
      for ($p = 1; $p -lt $partes.Count; $p++) { $md.Add("  - $($partes[$p])") }
    }
    if ($itens[$k].Count -gt $MaxPorItem) { $md.Add("- ... mais $($itens[$k].Count - $MaxPorItem)") }
  }
}
$md.Add('')
$md.Add('## Decisão')
$md.Add('Para cada código acima, o usuário responde: fazer, não fazer ou adiar. O que não for escolhido entra no relatório final como "não feito, por decisão do usuário".')

$saida = Join-Path $Pasta '_modernizacao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arq = Join-Path $saida 'limpeza.md'
$md | Set-Content -Path $arq -Encoding UTF8

foreach ($op in $ordemPrioridade) {
  foreach ($k in $tipos.Keys) {
    if ($tipos[$k][0] -ne $op[0]) { continue }
    if ($op[0] -eq 'info' -and -not $parcial) { continue }
    Write-Host ("{0,-44} {1,5}  [{2}]" -f $k, $itens[$k].Count, $op[0])
  }
}
if ($parcial) { Write-Host "Escopo parcial: $($pas.Count) unit(s); referências procuradas em $($todosPas.Count) units" }
Write-Host "Relatório: $arq"
