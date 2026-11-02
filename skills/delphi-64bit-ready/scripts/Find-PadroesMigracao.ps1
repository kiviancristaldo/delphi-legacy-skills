<#
.SYNOPSIS
  Procura no código Delphi os padrões que costumam quebrar na migração para Unicode
  (projetos do Delphi 2007 ou anterior) ou para 64 bits. Não altera nenhum arquivo.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Find-PadroesMigracao.ps1 -Tipo Unicode -Pasta C:\Projetos\MeuSistema -Recursivo

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Find-PadroesMigracao.ps1 -Tipo Win64 -Pasta C:\Projetos\MeuSistema -Recursivo -Excluir 'ACBr|Componentes'

.OUTPUTS
  <Pasta>\_modernizacao\padroes-<Tipo>.md

.NOTES
  Busca por texto: cada ocorrência é um ponto para revisar, não um erro certo.
  O compilador (warnings W1057, W1058, W1050, W1044, W1062...) complementa esta lista.
#>
param(
  [Parameter(Mandatory = $true)] [ValidateSet('Unicode', 'Win64')] [string]$Tipo,
  [Parameter(Mandatory = $true)] [string]$Pasta,
  [switch]$Recursivo,
  [string]$Excluir = '',
  [int]$MaxPorItem = 100
)

$ErrorActionPreference = 'Stop'
$Pasta = (Resolve-Path $Pasta).Path
$recurse = [bool]$Recursivo

# Nome | regex (ignora maiúsculas, salvo 5º item 'cs') | risco | o que fazer [| 'cs']
# A busca ignora comentários e o conteúdo de strings.
$regras = @{
  Unicode = @(
    # Set de Char: "in [...]" e constantes "= [...]" com literal de caractere (não ":=", nem
    # constante tipada como set of AnsiChar/TSysCharSet, que é a correção)
    @('Char em set (in [...])',            "(\bin|(?<![:<>]|\b(AnsiChar|TSysCharSet)\s*)=)\s*\[\s*('|#)", 'alto',  'ASCII puro: CharInSet(C, [...]); com caractere > 127 (acento, €): C.IsInArray([...]) ou comparação direta'),
    @('set of Char',                       "\bset\s+of\s+(Char\b|''|#)",                                'alto',  'set of AnsiChar/TSysCharSet + CharInSet; não guarda caractere acima de 255'),
    @('SizeOf(Char/string) e Move/FillChar','\bSizeOf\s*\(\s*(Char|string)\s*\)|\b(Move|FillChar)\s*\(', 'alto',  'Char tem 2 bytes: use Length(S) * SizeOf(Char) ou ByteLength(S)'),
    @('Buffer array of Char',              '\barray\s*\[[^\]]*\]\s*of\s+Char\b',                        'médio', 'SizeOf(Buffer) agora dá o dobro dos caracteres: APIs que pedem nº de caracteres recebem Length(Buffer)'),
    @('String como buffer de bytes',       '\b(BlockRead|BlockWrite|ReadBuffer|WriteBuffer|SendBuf|ReceiveBuf|SendText)\b|\.(Read|Write)\s*\(\s*\w+\s*\[\s*1\s*\]', 'alto', 'use TBytes/RawByteString e TEncoding explícito'),
    @('UTF-8/ANSI convertido à mão',       '\b(UTF8Encode|UTF8Decode|AnsiToUtf8|Utf8ToAnsi)\b',          'alto',  'UTF8String virou tipo próprio: guardar o resultado em string desfaz a conversão; use TEncoding.UTF8.GetBytes/GetString'),
    @('Chr/# entre 128 e 255',             '\bChr\s*\(\s*(12[89]|1[3-9]\d|2[0-4]\d|25[0-5]|\$[89A-F][0-9A-F])\s*\)|#(12[89]|1[3-9]\d|2[0-4]\d|25[0-5])(?!\d)|#\$(00)?[89A-F][0-9A-F](?![0-9A-F])', 'médio', 'Chr(n) é Unicode (Chr(128) = U+0080) e #n segue a codepage do compilador (#128 = €): use o caractere ou #$20AC'),
    @('Hash/criptografia/Base64 de string','\b(MD5|SHA1|SHA256|Crypt|Encrypt|Decrypt|Cripto|Base64|Hash)\w*\s*\(', 'alto', 'o resultado muda se os bytes mudarem: fixe o encoding (UTF-8 ou ANSI) antes de calcular'),
    @('Arquivo texto / integração',        '\b(AssignFile|Rewrite|Append|SaveToFile|LoadFromFile|SaveToStream|LoadFromStream)\b', 'médio', 'defina TEncoding explícito conforme o layout combinado (ANSI ou UTF-8)'),
    @('API Windows versão A',              '\b(MessageBox|ShellExecute|ShellExecuteEx|GetModuleFileName|CreateFile|CreateProcess|LoadLibrary|FindWindow|SendMessage|PostMessage|WinExec|GetWindowText|SetWindowText|RegOpenKeyEx|RegQueryValueEx|RegSetValueEx|GetPrivateProfileString|WritePrivateProfileString|GetTempPath|GetComputerName|GetUserName|CopyFile|MoveFile|DeleteFile|FindFirstFile|OutputDebugString|lstrcpy|lstrlen)A\b', 'médio', 'use a versão sem sufixo (string) ou a W; WinExec → CreateProcess/ShellExecute'),
    @('PChar com DLL externa',             "\bexternal\s+(''|[A-Za-z_]\w*)|\bGetProcAddress\s*\(",      'alto',  'DLL espera PAnsiChar? declare PAnsiChar (também nos tipos de ponteiro de função) e converta com AnsiString(S)'),
    @('Cast para PAnsiChar / AnsiString',  '\b(PAnsiChar|AnsiString|AnsiChar)\b',                       'médio', 'confirme se Ansi é necessário (DLL, arquivo, protocolo); senão use string/Char'),
    @('StrPCopy/StrCopy/StrLCopy',         '\b(StrPCopy|StrCopy|StrLCopy|StrPLCopy)\b',                 'médio', 'tamanho do buffer em Chars, não em bytes'),
    @('Byte de string (Ord > 255)',        '\bOrd\s*\(\s*\w+\s*\[',                                      'baixo', 'Ord(S[i]) pode passar de 255 agora'),
    @('ShortString / string[n]',           '\bstring\s*\[\s*\d+\s*\]|\bShortString\b',                   'baixo', 'continua Ansi: confira conversões com string')
  )
  Win64 = @(
    @('Ponteiro em Integer/Cardinal',      '\b(Integer|Cardinal|Longint|LongWord|DWORD)\s*\(\s*(Pointer\s*\(|@|Self\b|Sender\b|\w+\.Handle\b|\w+\.Items\s*\[)', 'alto', 'NativeInt/NativeUInt (ou UIntPtr) para guardar ponteiros'),
    @('Integer em Pointer/objeto',         '\b(Pointer|TObject|T\w+)\s*\(\s*(Integer|Longint|Cardinal)\s*\(', 'alto', 'mesmo problema no sentido inverso'),
    @('Tag com ponteiro/objeto',           '\.Tag\s*:=\s*(Integer|Longint|Cardinal)\s*\(|\bT\w+\s*\(\s*\w+\.Tag\s*\)', 'alto', 'Tag é NativeInt: atribua NativeInt(Obj), sem Integer()'),
    @('SetWindowLong/GetWindowLong',       '\b(SetWindowLong|GetWindowLong|SetClassLong|GetClassLong)\b(?!Ptr)', 'alto', 'use as versões ...Ptr'),
    @('Mensagens Windows com ponteiro',    '\b(SendMessage|PostMessage|Perform)\s*\(',                  'médio', 'WPARAM/LPARAM têm 64 bits: não converta ponteiro para Integer'),
    @('Assembler embutido',                '\basm\b',                                                    'alto',  'Win64 não aceita asm misturado com Pascal: reescreva em Pascal ou função 100% asm'),
    @('Extended (precisão muda)',          '\bExtended\b',                                               'alto',  'no Win64, Extended = Double: arredondamento pode mudar (cálculo fiscal!); teste com golden master'),
    @('DLL externa',                       '\bexternal\s+''|\bLoadLibrary\w*\s*\(',                     'alto',  'precisa existir versão 64 bits de cada DLL (fbclient, libeay, DLLs de TEF/impressora...)'),
    @('Registro gravado em arquivo',       '\bfile\s+of\b|\bpacked\s+record\b',                          'médio', 'tamanhos de Pointer/NativeInt mudam: arquivos gravados no 32 não leem no 64'),
    @('IFDEF WIN32',                       '\{\$IFDEF\s+WIN32\}|\{\$IF\s+DEFINED\s*\(\s*WIN32\s*\)',     'médio', 'use MSWINDOWS para código Windows; WIN32 só para o que é exclusivo de 32 bits'),
    @('BDE (não existe em 64 bits)',       '\b(DBTables|Bde\.DBTables)\b',                               'alto',  'migre para FireDAC antes (skill bde-to-firedac)'),
    # Diferencia maiúsculas (5º item): QuickReport usa TQR.../QR<Maiúscula>; "QryCliente" não é QuickReport
    @('Componentes sem versão 64 bits',    '\b(TQR\w+|QR[A-Z]\w*|QuickRpt|TRave\w+|Rave[A-Z]\w*|TwwDB\w+)\b', 'médio', 'confirme se o fornecedor tem pacote 64 bits', 'cs')
  )
}[$Tipo]

# Tira comentários ({ }, (* *), //) e o conteúdo das strings (mantém as aspas), preservando
# diretivas {$...}. $Estado guarda o comentário de bloco aberto de uma linha para a outra.
function Limpar-Linha([string]$Linha, [ref]$Estado) {
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
      [void]$sb.Append("''")
      if ($j -lt 0) { break }
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

$arquivos = if ($recurse) {
  Get-ChildItem -Path $Pasta -Include *.pas, *.dpr, *.inc -File -Recurse -ErrorAction SilentlyContinue
} else {
  Get-ChildItem -Path (Join-Path $Pasta '*') -Include *.pas, *.dpr, *.inc -File
}
$arquivos = @($arquivos | Where-Object { $_.FullName -notmatch '\\(__history|__recovery|_migracao|_modernizacao|_build|Win32|Win64)\\' })
if ($Excluir) { $arquivos = @($arquivos | Where-Object { $_.FullName.Substring($Pasta.Length) -notmatch $Excluir }) }

$achados = @{}
foreach ($r in $regras) { $achados[$r[0]] = New-Object System.Collections.Generic.List[string] }

foreach ($f in $arquivos) {
  $rel = $f.FullName.Substring($Pasta.Length + 1)
  $i = 0
  $estado = ''
  foreach ($l in [IO.File]::ReadAllLines($f.FullName, [Text.Encoding]::Default)) {
    $i++
    $t = Limpar-Linha $l ([ref]$estado)
    if (-not $t) { continue }
    foreach ($r in $regras) {
      $opcoes = if ($r.Count -gt 4 -and $r[4] -eq 'cs') { 'None' } else { 'IgnoreCase' }
      if ([regex]::IsMatch($t, $r[1], $opcoes)) {
        $original = $l.Trim()
        $trecho = if ($original.Length -gt 140) { $original.Substring(0, 137) + '...' } else { $original }
        $achados[$r[0]].Add("$rel`:$i  $trecho")
      }
    }
  }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Padrões de risco para $Tipo")
$md.Add('')
$md.Add("Pasta: ``$Pasta`` · $($arquivos.Count) arquivos · Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
$md.Add('')
$md.Add('| Padrão | Ocorrências | Risco | O que fazer |')
$md.Add('|---|---|---|---|')
foreach ($r in $regras) { $md.Add("| $($r[0]) | $($achados[$r[0]].Count) | $($r[2]) | $($r[3]) |") }
foreach ($r in $regras) {
  $lista = $achados[$r[0]]
  if ($lista.Count -eq 0) { continue }
  $md.Add('')
  $md.Add("## $($r[0]) ($($lista.Count)) · risco $($r[2])")
  $lista | Select-Object -First $MaxPorItem | ForEach-Object { $md.Add("- ``$_``") }
  if ($lista.Count -gt $MaxPorItem) { $md.Add("- ... mais $($lista.Count - $MaxPorItem)") }
}

$saida = Join-Path $Pasta '_modernizacao'
New-Item -ItemType Directory -Path $saida -Force | Out-Null
$arq = Join-Path $saida "padroes-$Tipo.md"
$md | Set-Content -Path $arq -Encoding UTF8

foreach ($r in $regras) { Write-Host ("{0,-38} {1,5}  [risco {2}]" -f $r[0], $achados[$r[0]].Count, $r[2]) }
Write-Host "Relatório: $arq"
