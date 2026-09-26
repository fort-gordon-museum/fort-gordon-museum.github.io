#!/usr/bin/perl
use strict; use warnings;
my ($outdir) = @ARGV;

my %GROUPS = (
  sccmd => ['Signal Commands',    1],
  scbde => ['Signal Brigades',    2],
  scctr => ['Signal Centers',     3],
  scbn  => ['Signal Battalions',  4],
  scco  => ['Signal Companies',   5],
  scdet => ['Signal Detachments', 6],
);

open(my $m, '<', "$outdir/manifest.tsv") or die "no manifest: $!";
my %by;
my $total = 0;
while (my $line = <$m>) {
  chomp $line;
  next unless $line =~ /\S/;
  my ($file, $unit, $asof, $nlin, $ncamp, $ndec) = split /\t/, $line;
  my ($code) = $file =~ /\d+(sc[a-z]+?)(?:_|\.)/;
  $code = 'scbn' unless $code && $GROUPS{$code};
  push @{ $by{$code} }, [$file, $unit, $asof, $nlin, $ncamp, $ndec];
  $total++;
}
close $m;

sub esc { my $t = shift; $t = '' unless defined $t; $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g; return $t; }

sub tidy {
  # the DA-certificate pages shout in caps; give the index a readable form
  my $u = shift;
  my $upper = () = $u =~ /[A-Z]/g;
  my $lower = () = $u =~ /[a-z]/g;
  # ordinals like "311th" keep a couple of lowercase letters, so judge by ratio
  return $u unless $upper + $lower > 0 && $upper / ($upper + $lower) > 0.6;
  my @w = split / /, lc $u;
  my @small = qw(and of the to in a an for);
  my %small = map { $_ => 1 } @small;
  my @out;
  for my $i (0..$#w) {
    my $w = $w[$i];
    if ($i > 0 && $small{$w}) { push @out, $w; next; }
    $w =~ s/^([a-z])/\u$1/;
    $w =~ s/^(\()([a-z])/$1\u$2/;
    push @out, $w;
  }
  my $r = join ' ', @out;
  $r =~ s/\b(\d+)(st|nd|rd|th|d)\b/$1$2/gi;
  $r =~ s/\bHhc\b/HHC/g; $r =~ s/\bHhd\b/HHD/g; $r =~ s/\bUs\b/U.S./g;
  return $r;
}

my $body = '';
for my $code (sort { $GROUPS{$a}[1] <=> $GROUPS{$b}[1] } keys %by) {
  my ($label) = @{ $GROUPS{$code} };
  my @rows = sort { $a->[0] cmp $b->[0] } @{ $by{$code} };
  $body .= "    <div class=\"grp\" data-grp=\"" . esc($label) . "\">\n";
  $body .= "      <h2>" . esc($label) . " <span class=\"gcount\">(" . scalar(@rows) . ")</span></h2>\n";
  $body .= "      <div class=\"rows\">\n";
  for my $r (@rows) {
    my ($file, $unit, $asof, $nlin, $ncamp, $ndec) = @$r;
    my $name = esc(tidy($unit));
    my @bits;
    push @bits, ($ncamp == 1 ? "1 campaign" : "$ncamp campaigns") if $ncamp;
    push @bits, ($ndec == 1 ? "1 citation" : "$ndec citations") if $ndec;
    push @bits, "lineage only" unless @bits;
    my $meta = join(' &middot; ', map { esc($_) } @bits);
    $body .= "        <a href=\"" . esc($file) . "\" data-name=\"" . lc($name) . "\"><span class=\"nm\">$name</span><span class=\"meta\">$meta</span></a>\n";
  }
  $body .= "      </div>\n    </div>\n";
}

my $page = <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Lineage &amp; Honors Archive &#8212; Signal Regiment</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Spectral:ital,wght\@0,400;0,500;0,600;0,700;1,400&family=IBM+Plex+Sans:wght\@400;500;600;700&family=IBM+Plex+Mono:wght\@400;500&display=swap" rel="stylesheet">
<link href="lineage.css" rel="stylesheet">
</head>
<body>
  <header class="bar">
    <div class="inner">
      <a class="brand" href="../index.html">Signal &amp; Cyber Corps Museum Society</a>
      <a class="back" href="../index.html#room-command-gallery">&#8592; Command Gallery</a>
    </div>
  </header>
  <div class="wrap">
    <div class="kicker">The Archive</div>
    <h1>Lineage &amp; Honors</h1>
    <p class="lede">The official lineage, campaign participation credit, and unit citations for $total units of the Signal Regiment &#8212; every unit the museum's Command Gallery roster links to. Each record is compiled by the U.S. Army Center of Military History and mirrored here so it stays reachable from the museum.</p>
    <input type="text" id="q" class="idx-search" placeholder="Filter by unit &#8212; try &quot;501st&quot; or &quot;brigade&quot;" autocomplete="off">
    <p class="idx-count" id="count">$total records</p>
$body    <footer class="src">
      Records compiled by the <strong>U.S. Army Center of Military History</strong> and reproduced here as works of the U.S. Government.
      Each page links to its original address at history.army.mil and to the archived copy it was taken from.
      Campaign credit and citations are reproduced as published; corrections belong with CMH.
    </footer>
  </div>
<script>
(function(){
  var q = document.getElementById('q');
  var count = document.getElementById('count');
  var rows = [].slice.call(document.querySelectorAll('.rows a'));
  var groups = [].slice.call(document.querySelectorAll('.grp'));
  q.addEventListener('input', function(){
    var t = q.value.trim().toLowerCase();
    var shown = 0;
    rows.forEach(function(a){
      var hit = !t || a.getAttribute('data-name').indexOf(t) !== -1;
      a.hidden = !hit;
      if (hit) shown++;
    });
    groups.forEach(function(g){
      var any = [].slice.call(g.querySelectorAll('.rows a')).some(function(a){ return !a.hidden; });
      g.hidden = !any;
    });
    count.textContent = t ? (shown + (shown === 1 ? ' record matches' : ' records match')) : '$total records';
  });
})();
</script>
</body>
</html>
HTML

open(my $out, '>', "$outdir/index.html") or die "cannot write index: $!";
print $out $page; close $out;
print "index written: $total records\n";
