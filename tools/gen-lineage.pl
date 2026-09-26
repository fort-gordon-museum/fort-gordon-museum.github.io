#!/usr/bin/perl
use strict; use warnings;
my ($raw, $outdir, $snapfile) = @ARGV;

my %snap;
if (open(my $s, '<', $snapfile)) {
  while (<$s>) { chomp; my ($f,$t) = split /\t/; $snap{$f} = $t if defined $f && defined $t; }
  close $s;
}

sub norm {
  my $t = shift; $t = '' unless defined $t;
  $t =~ s/&nbsp;/ /g;
  $t =~ s/[\x02\x03\x1E]//g;
  $t =~ s/\s+/ /g;
  $t =~ s/^ +//; $t =~ s/ +$//;
  return $t;
}
sub strip { my $t = shift; $t = '' unless defined $t; $t =~ s/<[^>]*>//g; return norm($t); }
sub esc {
  my $t = shift; $t = '' unless defined $t;
  $t =~ s/&/&amp;/g; $t =~ s/</&lt;/g; $t =~ s/>/&gt;/g;
  return $t;
}

my $SKIP = qr/^(?:
    BY\s+ORDER\s+OF\s+THE\s+SECRETARY\s+OF\s+THE\s+ARMY:?|
    Chief\s+of\s+Military\s+History|
    Official:?|
    Return\s+to\s+Branch\s+Index|
    Lineage\s+And\s+Honors\s+Information|
    CMH\s*Home|
    Administrative\s+Assistant\s+to\s+the|
    Secretary\s+of\s+the\s+Army|
    General,?\s+United\s+States\s+Army|
    Chief\s+of\s+Staff|
    Department\s+of\s+the\s+Army
  )$/xi;

opendir(my $dh, $raw) or die "cannot open $raw: $!";
my @files = sort grep { /[.]htm$/ } readdir($dh);
closedir $dh;

my @index; my $n = 0; my @problems;

for my $file (@files) {
  open(my $fh, '<', "$raw/$file") or next;
  my $html = do { local $/; <$fh> }; close $fh;

  # ---------- unit name (three source variants) ----------
  # All three put the name on several lines separated by <br>; a trailing motto
  # in parentheses reads better without a comma in front of it.
  my $unitname = sub {
    my $u = shift;
    $u =~ s/<br\s*\/?>/\x1F/gis;
    $u =~ s/<[^>]*>//g;
    my @parts = grep { /\S/ }
                map { my $x = $_; $x =~ s/&nbsp;/ /g; $x =~ s/\s+/ /g; $x =~ s/^ +//; $x =~ s/ +$//; $x }
                split /\x1F/, $u;
    my $out = '';
    for my $p (@parts) {
      if    ($out eq '')  { $out = $p; }
      elsif ($p =~ /^\(/) { $out .= " $p"; }
      else                { $out .= ", $p"; }
    }
    return $out;
  };

  my $unit = '';
  if    ($html =~ /<p[^>]*class="header1"[^>]*>(.*?)<\/p>/is) { $unit = $unitname->($1); }
  elsif ($html =~ /<p[^>]*class="unitz"[^>]*>(.*?)<\/p>/is)   { $unit = $unitname->($1); }
  elsif ($html =~ /<h1[^>]*>(.*?)<\/h1>/is)                   { $unit = $unitname->($1); }

  # ---------- as-of date ----------
  my $asof = '';
  if ($html =~ /Lineage\s+and\s+Honors\s+Information\s+as\s+of\s*([^<]{3,40})/is) { $asof = norm($1); }

  # ---------- isolate the record body ----------
  my $c = $html;
  $c =~ s/^.*?<div[^>]*class="context"[^>]*>//is;
  $c =~ s/<hr\s*\/?>.*$//is;
  $c =~ s/<div[^>]*class="(?:siggy|sig_|footersp|coinprint|coinclick)[^"]*"[^>]*>.*?<\/div>//gis;
  $c =~ s/<p[^>]*class="header1"[^>]*>.*?<\/p>//is;
  $c =~ s/<p[^>]*class="unitz"[^>]*>.*?<\/p>//is;
  $c =~ s/<h1[^>]*>.*?<\/h1>//is;
  $c =~ s/<p[^>]*class="[^"]*asof[^"]*"[^>]*>.*?<\/p>//is;
  $c =~ s/<p[^>]*class="header2"[^>]*>.*?<\/p>//is;

  # conflict labels -> \x02 label \x03 ; line breaks -> \x1E
  $c =~ s/<li[^>]*class="lin_und"[^>]*>(.*?)<\/li>/<p>\x02$1\x03<\/p>/gis;
  $c =~ s/<u>(.*?)<\/u>/\x02$1\x03/gis;
  $c =~ s/<span[^>]*class="conflict"[^>]*>(.*?)<\/span>/\x02$1\x03/gis;
  $c =~ s/<br\s*\/?>/\x1E/gis;

  # ---------- flatten to ordered text blocks ----------
  # Split on block-level boundaries rather than matching <p>...</p> pairs: these
  # pages are hand-built HTML 3.2 and some have stray or unmatched </p>, which
  # leaves a section heading sitting as bare text inside a <div>. Treating every
  # block tag as a separator catches those too.
  $c =~ s{</?(?:p|li|ul|ol|div|h[1-6]|tr|td|table|blockquote|center)\b[^>]*>}{\x1E}gis;
  $c =~ s/<[^>]*>//g;

  my @blocks;
  for my $piece (split /\x1E/, $c) {
    my $marked = $piece;
    $marked =~ s/&nbsp;/ /g;
    $marked =~ s/\s+/ /g;
    $marked =~ s/^ +//; $marked =~ s/ +$//;
    my $plain = $marked; $plain =~ s/[\x02\x03]//g;
    next if $plain eq '';
    next if $plain =~ $SKIP;
    push @blocks, [$marked, $plain];
  }

  # ---------- classify ----------
  my (@lin, @cpc, @dec);
  my $sec = 'lin';
  for my $b (@blocks) {
    my ($marked, $plain) = @$b;
    if ($plain =~ /^CAMPAIGN\s+PARTICIPATION\s+CREDIT$/i) { $sec = 'cpc'; next; }
    if ($plain =~ /^DECORATIONS?$/i)                      { $sec = 'dec'; next; }
    if (length($plain) < 60 && $plain =~ /\bHonors$/i)    { next; }
    if (length($plain) < 60 && $plain =~ /\bLineage$/i)   { $sec = 'lin'; next; }

    if ($sec eq 'lin') {
      if    ($plain =~ /^ANNEX\b/i) { push @lin, ['head', $plain]; }
      elsif ($plain =~ /^\(/)       { push @lin, ['note', $plain]; }
      else                          { push @lin, ['item', $plain]; }
    }
    elsif ($sec eq 'cpc') {
      if ($marked =~ /\x02(.*?)\x03(.*)$/s) {
        my ($conf, $rest) = ($1, $2);
        $conf = norm($conf); $conf =~ s/:\s*$//;
        push @cpc, ['conf', $conf] if $conf ne '';
        $rest = norm($rest);
        $rest =~ s/^:\s*//;          # "World War II</span>: Normandy; ..."
        if ($rest ne '') {
          for my $camp (split /;/, $rest) {
            my $x = norm($camp);
            next if $x eq '';
            push @cpc, [($x =~ /entitled\s+to:?$/i ? 'note' : 'camp'), $x];
          }
        }
      } elsif ($plain =~ /entitled\s+to:?$/i) {
        push @cpc, ['note', $plain];
      } else {
        push @cpc, ['camp', $plain];
      }
    }
    else { push @dec, $plain; }
  }

  unless ($unit ne '') { push @problems, "$file: no unit name"; next; }
  push @problems, "$file: no lineage entries" unless @lin;

  # ---------- render ----------
  my $body = '';
  if (@lin) {
    $body .= "      <h2>Lineage</h2>\n";
    for my $e (@lin) {
      my ($k, $t) = @$e;
      if    ($k eq 'head') { $body .= "      <h3>" . esc($t) . "</h3>\n"; }
      elsif ($k eq 'note') { $body .= "      <p class=\"entry note\">" . esc($t) . "</p>\n"; }
      else                 { $body .= "      <p class=\"entry\">" . esc($t) . "</p>\n"; }
    }
  }
  if (@cpc) {
    $body .= "      <h2>Campaign Participation Credit</h2>\n";
    my $open = 0;
    for my $e (@cpc) {
      my ($k, $t) = @$e;
      if ($k eq 'conf') {
        $body .= "      </ul>\n" if $open;
        $body .= "      <h3>" . esc($t) . "</h3>\n";
        $body .= "      <ul class=\"camps\">\n";
        $open = 1;
      } elsif ($k eq 'note') {
        if ($open) { $body .= "      </ul>\n"; $open = 0; }
        $body .= "      <p class=\"qual\">" . esc($t) . "</p>\n";
      } else {
        if (!$open) { $body .= "      <ul class=\"camps\">\n"; $open = 1; }
        $body .= "        <li>" . esc($t) . "</li>\n";
      }
    }
    $body .= "      </ul>\n" if $open;
  }
  if (@dec) {
    $body .= "      <h2>Decorations and Unit Citations</h2>\n";
    for my $d (@dec) {
      my $cls = ($d =~ /entitled\s+to:?$/i) ? 'qual' : 'dec';
      $body .= "      <p class=\"$cls\">" . esc($d) . "</p>\n";
    }
  }

  # ---------- provenance ----------
  my $ts = $snap{$file} || '';
  my $orig = "https://history.army.mil/html/forcestruc/lineages/branches/sc/$file";
  my $wb = $ts ? "https://web.archive.org/web/$ts/$orig" : '';
  my $snapdate = '';
  if ($ts =~ /^(\d{4})(\d{2})(\d{2})/) {
    my @mn = qw(January February March April May June July August September October November December);
    my $d = $3 + 0; $snapdate = "$d " . $mn[$2 - 1] . " $1";
  }
  my $src = "Official lineage and honors compiled by the <strong>U.S. Army Center of Military History</strong>, "
          . "mirrored here so the record stays reachable from the museum. "
          . "Original: <a href=\"$orig\" target=\"_blank\" rel=\"noopener\">history.army.mil &#8599;</a>";
  $src .= " &middot; archived copy: <a href=\"$wb\" target=\"_blank\" rel=\"noopener\">Internet Archive, $snapdate &#8599;</a>" if $wb;

  my $uesc = esc($unit);
  my $aesc = $asof ne '' ? "Lineage and honors as of " . esc($asof) : "";

  my $page = <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>$uesc &#8212; Lineage and Honors</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Spectral:ital,wght\@0,400;0,500;0,600;0,700;1,400&family=IBM+Plex+Sans:wght\@400;500;600;700&family=IBM+Plex+Mono:wght\@400;500&display=swap" rel="stylesheet">
<link href="lineage.css" rel="stylesheet">
</head>
<body>
  <header class="bar">
    <div class="inner">
      <a class="brand" href="../index.html">Signal &amp; Cyber Corps Museum Society</a>
      <a class="back" href="index.html">All lineages &amp; honors &#8594;</a>
    </div>
  </header>
  <div class="wrap">
    <div class="kicker">Lineage and Honors</div>
    <h1>$uesc</h1>
    <p class="asof">$aesc</p>
$body      <footer class="src">$src</footer>
  </div>
</body>
</html>
HTML

  open(my $out, '>', "$outdir/$file") or die "cannot write $outdir/$file: $!";
  print $out $page; close $out;

  my $ncamp = scalar grep { $_->[0] eq 'camp' } @cpc;
  push @index, [$file, $unit, $asof, scalar(@lin), $ncamp, scalar(@dec)];
  $n++;
}

open(my $man, '>', "$outdir/manifest.tsv") or die;
print $man join("\t", @$_), "\n" for @index;
close $man;
print "generated $n pages\n";
print "PROBLEMS (" . scalar(@problems) . "):\n" . join("\n", @problems) . "\n" if @problems;
