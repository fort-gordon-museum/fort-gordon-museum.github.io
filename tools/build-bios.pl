#!/usr/bin/perl
use strict; use warnings;
use JSON::PP;

# Build BIOS entries from the Society's own CMS collections.
# Usage: build-bios.pl <assetdir> <file.json> [file.json ...]
my $assetdir = shift or die "need assetdir\n";
my @files = @ARGV or die "need json files\n";

# already hand-written in index.html
my %SKIP = map { $_ => 1 } qw(1welton-chase-jr 3amy-tuschen);

# surname key per slug
my %KEY = (
  '4shalisha-haynes' => 'haynes',  '5laroy-peyton'    => 'peyton',
  '6atom-washer'     => 'washer',  '6eric-toler'      => 'toler',
  '7pete-wilson'     => 'wilson',  '9john-mcconnell'  => 'mcconnell',
  '9a-sly-cotton'    => 'cotton',  '9bdon-bray'       => 'bray',
  '9cjames-parks'    => 'parks',   '9ejohn-wilcox'    => 'wilcox',
  '1jeffery-foley'   => 'foley',   'annjohnson'       => 'johnson',
  'dr-tom-clark'     => 'clark',   'eric-y-nishizawa' => 'nishizawa',
  'stuart-m-dyer'    => 'dyer',
);

sub clean {
  my $t = shift; return '' unless defined $t;
  $t =~ s/<br\s*\/?>/\n\n/gi;
  $t =~ s/<\/p>/\n\n/gi;
  $t =~ s/<[^>]*>//g;
  $t =~ s/&nbsp;/ /g; $t =~ s/&amp;/&/g; $t =~ s/&#39;|&rsquo;/\x{2019}/g;
  $t =~ s/&quot;|&ldquo;|&rdquo;/"/g;
  $t =~ s/&mdash;/\x{2014}/g; $t =~ s/&ndash;/\x{2013}/g;
  $t =~ s/\r//g; $t =~ s/[ \t]+/ /g;
  $t =~ s/\n{3,}/\n\n/g;
  $t =~ s/^\s+|\s+$//g;
  return $t;
}
sub jsq {
  my $s = shift;
  $s =~ s/\\/\\\\/g; $s =~ s/'/\\'/g;
  $s =~ s/([^\x20-\x7e])/sprintf("\\u%04x", ord($1))/ge;
  return $s;
}

my @out; my @noBio; my @skipped;
for my $file (@files) {
  local $/; open(my $f, '<:raw', $file) or die $!;
  my $d = decode_json(<$f>); close $f;
  # The board collection marks live members with active=true and simply omits
  # the key on ones it is not showing (Jay Chapman). The advisory collection
  # has no active field at all. So only enforce the flag where it is in use.
  my $usesActive = grep { exists $_->{columns}{active} } @{ $d->{collection} || [] };

  for my $it (@{ $d->{collection} || [] }) {
    my $c = $it->{columns} or next;
    my $slug = $c->{slug} // '';
    next if $SKIP{$slug};
    if ($usesActive && !$c->{active}) { push @skipped, ($c->{name} // $slug) . ' (not active)'; next; }
    my $key = $KEY{$slug} or do { push @skipped, "$slug (no key)"; next; };
    my $bio = clean($c->{intro_text});
    unless (length $bio) { push @noBio, ($c->{name} // $slug); next; }

    my $img = ref($c->{image}) eq 'HASH' ? ($c->{image}{url} // '') : '';
    my $portrait = '';
    if ($img) {
      my ($ext) = $img =~ /\.([A-Za-z0-9]+)$/; $ext = lc($ext || 'jpg');
      $ext = 'jpg' if $ext eq 'jpeg';
      my $dest = "$assetdir/bio_$key.$ext";
      my $url = $img; $url =~ s{/images/0/}{/images/300/};
      system('curl', '-s', '-L', '--max-time', '60', '-A', 'Mozilla/5.0', $url, '-o', $dest);
      if (-s $dest > 1000) { $portrait = $dest } else { unlink $dest }
    }

    my @paras = grep { /\S/ } split /\n\s*\n/, $bio;
    my $name = $c->{name} // '';
    my $own  = 'In their own words';
    $own = 'In her own words' if $name =~ /^(Ann|Shalisha|Amy)\b/;
    $own = 'In his own words'  if $name =~ /^(Jeffery|Jeffrey|Laroy|Tom|Pete|John|Eric|Stuart|Donald|James|Dr\. Tom)\b/;

    push @out, join("\n",
      "    '$key': {",
      "      name: '" . jsq($name) . "',",
      "      role: '" . jsq($c->{motto} // '') . "',",
      "      org: '" . jsq($c->{job_title} // '') . "',",
      ($portrait ? "      portrait: '$portrait'," : ()),
      "      own: '$own',",
      "      paras: [",
      join(",\n", map { "        '" . jsq($_) . "'" } @paras),
      "      ],",
      "      src: '<a href=\"https://www.signalandcybercorpsmuseum.org/en/bod-single-page-layout/$slug\" target=\"_blank\" rel=\"noopener\">Profile at signalandcybercorpsmuseum.org \\u2197</a>'",
      "    }"
    );
  }
}

binmode(STDOUT, ':encoding(UTF-8)');
print join(",\n", @out), "\n";
print STDERR "\nbios generated: " . scalar(@out) . "\n";
print STDERR "no bio published: " . join(', ', @noBio) . "\n" if @noBio;
print STDERR "skipped: " . join(', ', @skipped) . "\n" if @skipped;
