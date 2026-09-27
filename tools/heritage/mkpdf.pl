# usage: perl mkpdf.pl out.pdf "Title" page1.jpg page2.jpg ...   (each JPEG fills a US Letter page)
use strict; use warnings;
my ($out, $title, @jpgs) = @ARGV;
sub jpeg_info { my ($d) = @_; my $p = 2;
  while ($p < length $d) { my ($m, $len) = unpack 'x C n', substr($d, $p, 4);
    if ($m >= 0xC0 && $m <= 0xCF && $m != 0xC4 && $m != 0xC8 && $m != 0xCC) { my ($h, $w, $c) = unpack 'x5 n n C', substr($d, $p, 10); return ($w, $h, $c) }
    $p += 2 + $len } die "no SOF" }
my @obj; my $n = sub { push @obj, $_[0]; scalar @obj };
my $cat = $n->(''); my $pages = $n->('');
my @kids;
for my $f (@jpgs) {
  open my $fh, '<:raw', $f or die "$f: $!"; local $/; my $d = <$fh>; close $fh;
  my ($w, $h, $c) = jpeg_info($d);
  my $cs = $c == 1 ? '/DeviceGray' : $c == 4 ? '/DeviceCMYK' : '/DeviceRGB';
  my $im = $n->("<< /Type /XObject /Subtype /Image /Width $w /Height $h /ColorSpace $cs /BitsPerComponent 8 /Filter /DCTDecode /Length " . length($d) . " >>\nstream\n$d\nendstream");
  my ($pw, $ph) = (612, sprintf('%.2f', 612 * $h / $w));
  my $cs_ = "q $pw 0 0 $ph 0 0 cm /Im0 Do Q";
  my $ct = $n->("<< /Length " . length($cs_) . " >>\nstream\n$cs_\nendstream");
  push @kids, $n->("<< /Type /Page /Parent $pages 0 R /MediaBox [0 0 $pw $ph] /Resources << /XObject << /Im0 $im 0 R >> >> /Contents $ct 0 R >>");
}
$obj[$cat - 1] = "<< /Type /Catalog /Pages $pages 0 R /PageLayout /SinglePage >>";
$obj[$pages - 1] = "<< /Type /Pages /Kids [" . join(' ', map { "$_ 0 R" } @kids) . "] /Count " . scalar(@kids) . " >>";
(my $t = $title) =~ s/([()\\])/\\$1/g;
my $info = $n->("<< /Title ($t) /Author (Fort Gordon Historical Museum Society) /Producer (sc-museum.github.io) >>");
open my $o, '>:raw', $out or die; my $pdf = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n"; my @off;
for my $i (0 .. $#obj) { push @off, length $pdf; $pdf .= ($i + 1) . " 0 obj\n$obj[$i]\nendobj\n" }
my $x = length $pdf; $pdf .= "xref\n0 " . (@obj + 1) . "\n0000000000 65535 f \n"; $pdf .= sprintf("%010d 00000 n \n", $_) for @off;
$pdf .= "trailer\n<< /Size " . (@obj + 1) . " /Root $cat 0 R /Info $info 0 R >>\nstartxref\n$x\n%%EOF\n";
print $o $pdf; close $o;
