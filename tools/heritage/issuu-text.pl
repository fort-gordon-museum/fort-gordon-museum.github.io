# usage: perl extract.pl page.bin  -> prints blocks as "H\ttext" / "P\ttext"
use FindBin; require "$FindBin::Bin/issuu-layer.pl";
use utf8;
binmode STDOUT, ':utf8';
open my $fh, '<:raw', $ARGV[0] or die; local $/; my $raw = <$fh>; close $fh;
my ($runs, $PW, $PH) = runs($raw); $PH ||= 1500;
my @L;   # lines: {x, y, x2, size, text}
for my $r (@$runs) {
  my $t = $r->{t}; utf8::decode($t);
  my @m = unpack('f<*', $r->{f5}); my @g = unpack('f<*', $r->{f6});
  next unless @m >= 6;
  my $size = ($r->{f3} || 50) * abs($m[0] || $m[1]);
  next if $size < 6;                                     # hairline / invisible text
  my ($x, $y) = ($m[4], $m[5]); my $x2 = $x + (@g ? $g[-1] : 0) * abs($m[0]) + $size * 0.5;
  my $prev = $L[-1];
  if ($prev && abs($prev->{y} - $y) < $size * 0.35 && $x >= $prev->{x2} - $size * 1.2 && $x - $prev->{x2} < $size * 2.5) {
    my $gap = $x - $prev->{x2};
    my $lig = $prev->{text} =~ /[\x{FB00}-\x{FB04}]$/ || $t =~ /^[\x{FB00}-\x{FB04}]/;
    $prev->{text} .= (!$lig && $gap > $size * 0.2 && $prev->{text} !~ /\s$/ && $t !~ /^\s/) ? " $t" : $t;
    $prev->{x2} = $x2; $prev->{size} = $size if $size > $prev->{size};
  } else { push @L, { x=>$x, y=>$y, x2=>$x2, size=>$size, text=>$t } }
}
my %lig = ("\x{FB00}"=>'ff', "\x{FB01}"=>'fi', "\x{FB02}"=>'fl', "\x{FB03}"=>'ffi', "\x{FB04}"=>'ffl');
for (@L) { my $t = $_->{text}; $t =~ s/([\x{FB00}-\x{FB04}])/$lig{$1}/g; $t =~ s/\s+/ /g; $t =~ s/^ | $//g; $_->{text} = $t }
# drop running heads and folios
@L = grep { $_->{text} ne '' && $_->{text} !~ /^(Page \d+|Issue No\.? ?\d+ ?HERITAGE.*|HERITAGE|\d{1,2})$/i
  && !($_->{y} < $PH * 0.05 && $_->{text} =~ /Issue No|HERITAGE/) } @L;
exit unless @L;
my @sz = sort { $a <=> $b } map { sprintf '%.1f', $_->{size} } @L;
# body size = most common rounded size, weighted by text length
my %w; $w{sprintf '%.0f', $_->{size}} += length $_->{text} for @L;
my ($body) = sort { $w{$b} <=> $w{$a} } keys %w;
my @B; my $cur;
for my $l (@L) {
  my $head = $l->{size} > $body * 1.3;
  my $new = !$cur || $head != $cur->{head} || abs($l->{size} - $cur->{size}) > $body * 0.15
    || $l->{y} - $cur->{y} > $l->{size} * 1.9 || $l->{y} < $cur->{y} - $l->{size} * 0.5
    || abs($l->{x} - $cur->{x}) > $body * 4;
  # a paragraph that runs over into the next column continues mid-sentence
  if ($new && $cur && !$head && !$cur->{head} && abs($l->{size} - $cur->{size}) < $body * 0.15
      && $cur->{text} !~ /[.!?:"\x{201D}]$/ && $l->{text} =~ /^\p{Ll}/) { $new = 0 }
  if ($new) { $cur = { head=>$head, size=>$l->{size}, x=>$l->{x}, y=>$l->{y}, text=>$l->{text} }; push @B, $cur; next }
  if ($cur->{text} =~ /(\p{L})-$/ && $l->{text} =~ /^\p{Ll}/) { $cur->{text} =~ s/-$// ; $cur->{text} .= $l->{text} }
  else { $cur->{text} .= ' ' . $l->{text} }
  $cur->{y} = $l->{y}; $cur->{x} = $l->{x};
}
for my $b (@B) { my $t = $b->{text}; $t =~ s/\s+/ /g; $t =~ s/\( /(/g; $t =~ s/ ([),.;:])/$1/g; $t =~ s/^\s+|\s+$//g; next if $t eq ''; print(($b->{head} ? 'H' : 'P'), "\t$t\n") }
