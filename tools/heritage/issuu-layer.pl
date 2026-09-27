use strict; use warnings;
sub vi { my ($s,$p)=@_; my ($v,$sh)=(0,0); while ($$p < length $$s) { my $b=ord substr($$s,$$p++,1); $v|=($b&0x7f)<<$sh; $sh+=7; return $v unless $b&0x80; return undef if $sh>63 } undef }
# returns arrayref of [field, value] or undef if not a clean message
sub pr { my ($s)=@_; my $p=0; my @f; while ($p < length $s) { my $k=vi(\$s,\$p); return undef unless defined $k; my ($fn,$wt)=($k>>3,$k&7); return undef unless $fn;
  if ($wt==0) { my $v=vi(\$s,\$p); return undef unless defined $v; push @f,[$fn,$v] }
  elsif ($wt==5) { return undef if $p+4>length $s; push @f,[$fn,unpack('f<',substr($s,$p,4))]; $p+=4 }
  elsif ($wt==1) { return undef if $p+8>length $s; push @f,[$fn,unpack('d<',substr($s,$p,8))]; $p+=8 }
  elsif ($wt==2) { my $l=vi(\$s,\$p); return undef unless defined $l && $p+$l<=length $s; push @f,[$fn,substr($s,$p,$l)]; $p+=$l }
  else { return undef } } \@f }
sub fields { my %h; push @{$h{$_->[0]}}, $_->[1] for @{pr($_[0]) || []}; \%h }
# text runs: {t, x, y, h, w} in page pixels
sub runs { my ($raw)=@_; my @r; my $top = fields($raw);
  for my $n (@{$top->{9}||[]}) { my $h = fields($n); next unless $h->{2}; my $r = fields($h->{2}[0]); next unless defined $r->{1};
    push @r, { t=>$r->{1}[0], f5=>$r->{5}[0], f6=>$r->{6}[0], f3=>$r->{3}[0], f2=>$r->{2} ? $r->{2}[0] : 0 } }
  (\@r, $top->{4}[0], $top->{5}[0]) }
1;
