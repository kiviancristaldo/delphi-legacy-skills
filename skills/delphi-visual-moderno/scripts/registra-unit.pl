# Inclui uma unit no .dpr e no .dproj de um sistema Delphi, logo antes de uma unit-âncora.
#
# Uso:
#   perl registra-unit.pl <Sistema.dpr> <Sistema.dproj> <UnitAncora> <caminho\da\Unit.pas> [f_Form]
#
#   UnitAncora : unit que já está no projeto; a nova entra antes dela (ex.: UnPrincipal)
#   caminho    : relativo à pasta do .dpr, com barra invertida (ex.: ..\Comum\UnTema.pas)
#   f_Form     : só para units com form (ex.: f_Login) -> {f_Login} no .dpr e <Form> no .dproj
#
# Preserva o final de linha de cada arquivo. Rodar de novo não duplica: se a unit já está
# registrada, a linha antiga é retirada antes.
use strict;
use warnings;

my ($dpr, $dproj, $ancora, $caminho, $form) = @ARGV;
die "uso: perl registra-unit.pl <dpr> <dproj> <UnitAncora> <caminho\\Unit.pas> [f_Form]\n"
  unless $dpr && $dproj && $ancora && $caminho;
my ($unit) = $caminho =~ /([^\\\/]+)\.pas$/i or die "caminho deve terminar em .pas\n";

sub ler { my $a = shift; open(my $f, '<:raw', $a) or die "$a: $!"; local $/; my $c = <$f>; close $f; return $c; }
sub gravar { my ($a, $c) = @_; open(my $f, '>:raw', $a) or die "$a: $!"; print $f $c; close $f; }

# .dpr
my $d = ler($dpr);
$d =~ s/^[ \t]*\Q$unit\E in '[^']*'[^\r\n]*\r?\n//mi;   # tira registro antigo
my $comentario = $form ? " {$form}" : '';
$d =~ s/^([ \t]*)(\Q$ancora\E in [^\r\n]*?)(\r?\n)/$1$unit in '$caminho'$comentario,$3$1$2$3/mi
  or die "$dpr: unit-âncora '$ancora' não encontrada\n";
gravar($dpr, $d);

# .dproj
my $p = ler($dproj);
my $qc = quotemeta($caminho);
$p =~ s/^[ \t]*<DCCReference Include="$qc"\s*\/>\r?\n//mi;
$p =~ s/^[ \t]*<DCCReference Include="$qc">.*?<\/DCCReference>\r?\n//msi;
my $entrada;
$p =~ s{^([ \t]*)(<DCCReference Include="(?:[^"]*[\\/])?\Q$ancora\E\.pas"[^\r\n]*)(\r?\n)}{
  my ($ind, $linha, $eol) = ($1, $2, $3);
  $entrada = $form
    ? "$ind<DCCReference Include=\"$caminho\">$eol$ind    <Form>$form</Form>$eol$ind</DCCReference>$eol"
    : "$ind<DCCReference Include=\"$caminho\"/>$eol";
  "$entrada$ind$linha$eol";
}mie or die "$dproj: unit-âncora '$ancora' não encontrada\n";
gravar($dproj, $p);

print "ok: $unit registrada em $dpr e $dproj\n";
