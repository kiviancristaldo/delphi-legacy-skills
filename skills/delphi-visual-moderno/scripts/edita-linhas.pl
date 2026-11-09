# Uso: perl edita-linhas.pl <arquivo> <N>=<texto novo> ... <N>=-
#   N=-      apaga a linha N
#   N=texto  troca a linha N pelo texto (mantém o final de linha original)
# Confere o conteúdo esperado: N~trecho exige que a linha N contenha o trecho.
use strict;
use warnings;

my $arq = shift;
open(my $in, '<:raw', $arq) or die "$arq: $!"; my @l = <$in>; close $in;
my (%troca, %apaga);
for my $op (@ARGV) {
  if ($op =~ /^(\d+)~(.*)$/s) {
    index($l[$1 - 1], $2) >= 0 or die "$arq:$1 nao contem '$2': $l[$1 - 1]";
  } elsif ($op =~ /^(\d+)=-$/) {
    $apaga{$1} = 1;
  } elsif ($op =~ /^(\d+)=(.*)$/s) {
    $troca{$1} = $2;
  } else { die "operacao invalida: $op\n"; }
}
my @saida;
for my $i (1 .. @l) {
  next if $apaga{$i};
  if (exists $troca{$i}) {
    my ($eol) = $l[$i - 1] =~ /(\r?\n)$/;
    push @saida, $troca{$i} . ($eol // "\n");
  } else {
    push @saida, $l[$i - 1];
  }
}
open(my $out, '>:raw', $arq) or die; print $out @saida; close $out;
print "ok: $arq\n";
