# Uso: perl sem-estilo-dfm.pl <UnPrincipal.dfm> [--redimensionavel]
# Dentro do bloco pnlConteudo, acrescenta "StyleElements = []" depois de cada
# "ShowCaption = False" (painéis) e "ParentFont = False" (labels): com estilo VCL ativo
# a VCL ignoraria as cores do layout. Não duplica se já houver.
# --redimensionavel: tira BorderStyle/BorderIcons do form (volta ao padrão: redimensiona e maximiza).
use strict;
use warnings;

my ($arq, $opcao) = @ARGV;
open(my $in, '<:raw', $arq) or die "$arq: $!"; my @l = <$in>; close $in;

my ($dentro, @saida) = (0);
for my $i (0..$#l) {
  my $linha = $l[$i];
  if ($opcao && $opcao eq '--redimensionavel' && $linha =~ /^  (BorderStyle|BorderIcons) = /) { next; }
  $dentro = 1 if $linha =~ /^  object pnlConteudo: /;
  push @saida, $linha;
  if ($dentro && $linha =~ /^(\s+)(ShowCaption = False|ParentFont = False)(\r?\n)$/) {
    my ($ind, $eol) = ($1, $3);
    my $prox = $l[$i + 1] // '';
    push @saida, "${ind}StyleElements = []$eol" unless $prox =~ /StyleElements/;
  }
  $dentro = 0 if $dentro && $linha =~ /^  end\r?$/;
}
open(my $out, '>:raw', $arq) or die; print $out @saida; close $out;
print "ok: $arq\n";
