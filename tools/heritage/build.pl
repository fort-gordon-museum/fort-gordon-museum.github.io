#!/usr/bin/perl
# Builds the Heritage magazine reading room:
#   heritage/index.html          the library of issues
#   heritage/issue-N.html        one reader per issue (text view + page scans)
#   heritage/pdf/*.pdf           the whole issue as a download
# from the page scans in heritage/issue-N/ and the page text in
# tools/heritage/text/issue-N/. See tools/heritage/README.md.
use strict; use warnings; use utf8;
use FindBin;
binmode STDOUT, ':utf8';

my $ROOT = "$FindBin::Bin/../..";
my $TEXT = "$FindBin::Bin/text";

my @ISSUES = (
  { n => 1, season => 'Fall–Winter 2020', date => '2020-10-01', issuu => 'fghms_2020_1st_edition_final',
    pdf => 'heritage-issue-1-fall-winter-2020.pdf',
    title => 'The Oscar Goes to the Signal Corps',
    dek => 'The first edition: Darryl F. Zanuck and The Longest Day, Camp Gordon’s mobilization for the First World War, and the Academy Awards won by Signal Corps filmmakers.',
    toc => [ [2, 'The Man Behind The Longest Day'], [3, 'Chairman’s Corner'], [4, 'Board of Directors'],
             [6, 'History Corner: Mobilization for War'], [12, 'Family Connection'], [13, 'The Oscar Goes to…'],
             [14, 'Destined to Serve'], [24, 'A.I. Saves Lives'], [28, 'Membership Application'] ] },
  { n => 2, season => 'Spring 2021', date => '2021-03-09', issuu => 'fghms_2021_2nd_edition',
    pdf => 'heritage-issue-2-spring-2021.pdf',
    title => 'The Military Police School at Camp Gordon',
    dek => 'Camp Gordon after the Second World War: the disciplinary barracks, the Military Police School, and prisoners of war in Georgia.',
    toc => [ [2, 'The Military Police School at Camp Gordon'], [3, 'Chairman’s Corner'], [4, 'Board of Directors'],
             [6, 'Editorial'], [8, 'Discipline Barracks'], [16, 'New Proposed Museum'], [18, 'Special Event'],
             [20, 'Membership Application'], [23, 'Donating Opportunity'] ] },
  { n => 3, season => 'Summer–Fall 2021', date => '2021-09-10', issuu => 'fghms_2021_3rd_edition_sof',
    pdf => 'heritage-issue-3-summer-fall-2021.pdf',
    title => 'Special Operations Communicators',
    dek => 'Honoring the communicators behind special operations: Brigadier General Jeth Rey, the 112th Signal Battalion, and the SOCEUR Signal Detachment.',
    toc => [ [3, 'Honoring Special Operations Communicators'], [4, 'Chairman’s Corner'], [5, 'Board of Directors'],
             [6, 'Q&A with Brigadier General Jeth Rey'], [8, 'Fireside Chat: Ingenuity'], [10, 'SCAMPI'],
             [12, '“No Ordinary Signal Unit”'], [15, 'Bringing SOF Communications to the Fight'],
             [26, 'How SOF Got Their Comms'], [32, 'Organization of FGHMS'], [33, 'Future Museum Site'],
             [35, 'Membership Application'], [36, 'Planned Gift Confirmation'] ] },
);

sub esc { my $s = shift; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/"/&quot;/g; $s }
sub slurp { my ($f, $mode) = @_; open my $fh, $mode || '<:encoding(UTF-8)', $f or return undef; local $/; my $d = <$fh>; close $fh; $d }
sub spew { my ($f, $d) = @_; open my $fh, '>:encoding(UTF-8)', $f or die "$f: $!"; print $fh $d; close $fh; print "wrote $f\n" }
sub jpeg_size { my $d = slurp($_[0], '<:raw'); my $p = 2;
  while ($p < length $d) { my ($m, $len) = unpack 'x C n', substr($d, $p, 4);
    if ($m >= 0xC0 && $m <= 0xCF && $m != 0xC4 && $m != 0xC8 && $m != 0xCC) { my ($h, $w) = unpack 'x5 n n', substr($d, $p, 9); return ($w, $h) }
    $p += 2 + $len } (0, 0) }
sub mb { sprintf '%.1f MB', $_[0] / 1048576 }

# Link "Cont. on Page 13" / "Continues on page 11" / "Continued from page 3" to that page.
sub linkify { my ($t, $n) = @_;
  $t =~ s{((?:Cont\.|Continue[sd]?)\s+(?:on|from)\s+[Pp]age\s+(\d+))}{<a class="cont" href="#p-$2">$1</a>}g;
  $t =~ s{(Cont\.\s+on\s+next\s+[Pp]age)}{'<a class="cont" href="#p-' . ($n + 1) . "\">$1</a>"}ge;
  $t }

sub page_text_html { my ($issue, $n) = @_;
  my $raw = slurp(sprintf '%s/issue-%d/p%02d.txt', $TEXT, $issue, $n);
  return '' unless defined $raw;
  my @out;
  for my $line (split /\n/, $raw) {
    my ($kind, $t) = split /\t/, $line, 2; next unless defined $t && $t =~ /\S/;
    my $h = linkify(esc($t), $n);
    push @out, $kind eq 'H' ? "<h3>$h</h3>" : "<p>$h</p>";
  }
  join "\n", @out }

my $CSS = <<'CSS';
:root{
  --ink:#0d1f16; --panel:#132a1e; --panel-2:#183324; --hair:#2a4a37;
  --gold:#c9a227; --gold-bright:#e0bc4a; --crimson:#a53344;
  --paper:#ece2c6; --paper-2:#f4ecd6; --paper-ink:#241d10; --paper-muted:#6b5d3f; --paper-hair:#d6c9a4;
  --white:#f4f3ee; --muted:#a9bdb0;
  --serif:'Spectral', Georgia, serif; --sans:'IBM Plex Sans', -apple-system, sans-serif; --mono:'IBM Plex Mono', monospace;
  --read-size:19px;
}
*{box-sizing:border-box;}
html{scroll-behavior:smooth; scroll-padding-top:70px;}
body{margin:0; background:var(--ink); color:var(--white); font-family:var(--sans); line-height:1.55; -webkit-font-smoothing:antialiased;}
a{color:inherit;}
img{max-width:100%; display:block;}
.wrap{max-width:1180px; margin:0 auto; padding:0 24px;}
.skip{position:absolute; left:-9999px; top:8px; background:var(--gold); color:var(--ink); padding:8px 14px; font-family:var(--mono); font-size:12px; z-index:50;}
.skip:focus{left:8px;}

.top{border-bottom:1px solid var(--hair); background:rgba(13,31,22,0.96);}
.top .wrap{display:flex; align-items:center; gap:14px; padding-top:12px; padding-bottom:12px;}
.brand{display:flex; align-items:center; gap:12px; text-decoration:none; min-width:0;}
.brand img{width:40px; height:40px; border-radius:50%; background:#fff; padding:2px; flex:none;}
.brand b{display:block; font-family:var(--serif); font-size:16px; font-weight:600; line-height:1.2;}
.brand span{display:block; font-family:var(--mono); font-size:10.5px; letter-spacing:1.5px; text-transform:uppercase; color:var(--muted);}
.top nav{margin-left:auto; display:flex; gap:18px; font-size:13.5px; flex:none;}
.top nav a{color:var(--muted); text-decoration:none;}
.top nav a:hover, .top nav a[aria-current]{color:var(--gold-bright);}
@media (max-width:640px){ .brand b{font-size:14px;} .brand span{display:none;} .top nav{gap:12px; font-size:12.5px;} }

.kicker{font-family:var(--mono); font-size:11.5px; letter-spacing:2px; text-transform:uppercase; color:var(--gold);}
h1{font-family:var(--serif); font-weight:600; font-size:clamp(30px, 5vw, 46px); line-height:1.1; margin:8px 0 12px;}
.dek{color:var(--muted); font-size:16px; max-width:640px; margin:0 0 20px;}
.btn{display:inline-flex; align-items:center; gap:8px; text-decoration:none; font-size:13.5px; font-weight:600; padding:10px 18px; border-radius:2px; border:1px solid var(--gold); cursor:pointer; font-family:var(--sans);}
.btn.primary{background:var(--gold); color:var(--ink);}
.btn.primary:hover{background:var(--gold-bright);}
.btn.ghost{background:none; color:var(--gold-bright);}
.btn.ghost:hover{background:var(--panel-2);}
.btn small{font-weight:400; opacity:.8;}
.actions{display:flex; gap:10px; flex-wrap:wrap;}

/* ---- issue hero ---- */
.hero{display:grid; grid-template-columns:1fr 200px; gap:32px; align-items:end; padding-top:36px; padding-bottom:28px;}
.hero .cover{border:1px solid var(--hair); box-shadow:0 14px 40px rgba(0,0,0,0.5);}
@media (max-width:720px){ .hero{grid-template-columns:1fr; padding-top:24px;} .hero .cover{display:none;} }

/* ---- sticky reading toolbar ---- */
.bar{position:sticky; top:0; z-index:20; background:rgba(13,31,22,0.97); border-top:1px solid var(--hair); border-bottom:1px solid var(--hair);}
.bar .wrap{display:flex; align-items:center; gap:10px; flex-wrap:wrap; padding-top:9px; padding-bottom:9px;}
.seg{display:inline-flex; border:1px solid var(--hair); border-radius:2px; overflow:hidden;}
.seg button, .tool{background:none; border:0; color:var(--muted); font-family:var(--sans); font-size:13px; padding:7px 13px; cursor:pointer;}
.seg button + button{border-left:1px solid var(--hair);}
.seg button[aria-pressed="true"]{background:var(--gold); color:var(--ink); font-weight:600;}
.seg button:hover:not([aria-pressed="true"]), .tool:hover{color:var(--white); background:var(--panel-2);}
.sizes{display:inline-flex; border:1px solid var(--hair); border-radius:2px;}
.sizes .tool{font-family:var(--serif); padding:5px 11px; font-size:15px;}
.sizes .tool + .tool{border-left:1px solid var(--hair);}
.jump{margin-left:auto; background:var(--panel); color:var(--white); border:1px solid var(--hair); font-family:var(--sans); font-size:13px; padding:7px 10px; border-radius:2px; max-width:260px;}
.bar .dl{padding:7px 14px; font-size:13px;}
body.mode-pages .sizes{visibility:hidden;}
@media (max-width:640px){ .jump{margin-left:0; flex:1; max-width:none;} .bar .dl span{display:none;} }

/* ---- layout ---- */
.layout{display:grid; grid-template-columns:230px minmax(0, 1fr); gap:36px; padding-top:28px; padding-bottom:60px;}
.toc{position:sticky; top:74px; align-self:start; max-height:calc(100vh - 90px); overflow:auto;}
.toc h2{font-family:var(--mono); font-size:11px; letter-spacing:2px; text-transform:uppercase; color:var(--muted); font-weight:500; margin:0 0 10px;}
.toc ol{list-style:none; margin:0; padding:0;}
.toc a{display:grid; grid-template-columns:26px 1fr; gap:6px; padding:7px 8px; font-size:13.5px; line-height:1.35; text-decoration:none; color:var(--muted); border-left:2px solid transparent;}
.toc a span{font-family:var(--mono); font-size:11.5px; color:var(--gold); padding-top:1px;}
.toc a:hover{color:var(--white); background:var(--panel);}
.toc a.on{color:var(--white); border-left-color:var(--gold); background:var(--panel);}
@media (max-width:900px){ .layout{grid-template-columns:1fr;} .toc{display:none;} }

/* ---- pages ---- */
.pg{margin:0 auto 28px; max-width:820px;}
.pg-head{display:flex; align-items:baseline; gap:12px; margin-bottom:10px;}
.pg-no{font-family:var(--mono); font-size:11.5px; letter-spacing:1.5px; text-transform:uppercase; color:var(--gold);}
.pg-title{font-family:var(--serif); font-size:24px; font-weight:600; margin:0; line-height:1.2;}
.pg-head .scan-link{margin-left:auto; font-size:12.5px; color:var(--muted); background:none; border:0; cursor:pointer; font-family:var(--sans); text-decoration:underline; padding:0; white-space:nowrap;}
.pg-head .scan-link:hover{color:var(--gold-bright);}
.pg.starts{margin-top:44px;}
.pg.starts:first-child{margin-top:0;}

.sheet{background:var(--paper-2); color:var(--paper-ink); border:1px solid var(--paper-hair); padding:34px clamp(18px, 5vw, 56px); box-shadow:0 10px 30px rgba(0,0,0,0.35); overflow:hidden;}
.sheet .thumb{float:right; width:150px; margin:4px 0 16px 24px; border:1px solid var(--paper-hair); cursor:zoom-in; background:#fff; padding:0;}
.sheet .thumb img{width:100%; height:auto;}
.sheet .thumb:focus-visible{outline:2px solid var(--gold); outline-offset:2px;}
@media (max-width:520px){ .sheet .thumb{width:96px; margin-left:14px;} }
.txt{font-family:var(--serif); font-size:var(--read-size); line-height:1.7; max-width:68ch; hyphens:auto; overflow-wrap:break-word;}
.txt p{margin:0 0 1em;}
.txt h3{font-family:var(--serif); font-size:1.2em; line-height:1.3; margin:1.3em 0 .5em; font-weight:700;}
.txt h3:first-child{margin-top:0;}
.txt a.cont{color:#7a5a00; font-style:italic;}
.no-text{font-family:var(--sans); font-size:14px; color:var(--paper-muted); font-style:italic; margin:0 0 14px;}
.sheet .full{margin:0; clear:both;}
.sheet .full img{width:100%; height:auto; border:1px solid var(--paper-hair); cursor:zoom-in;}

.scan{margin:0; background:#000; border:1px solid var(--hair); box-shadow:0 10px 30px rgba(0,0,0,0.4);}
.scan img{width:100%; height:auto; cursor:zoom-in;}
body.mode-text .scan{display:none;}
body.mode-pages .sheet{display:none;}

.note{max-width:820px; margin:0 auto 26px; font-size:13px; color:var(--muted); border-left:2px solid var(--gold); padding:4px 0 4px 14px;}
.foot{border-top:1px solid var(--hair); padding:26px 0 40px; font-size:13px; color:var(--muted);}
.foot .wrap{display:flex; gap:16px; flex-wrap:wrap; justify-content:space-between;}
.foot a{color:var(--gold-bright);}

/* ---- lightbox ---- */
.lb{position:fixed; inset:0; z-index:100; background:rgba(5,12,8,0.94); display:none; flex-direction:column;}
.lb.open{display:flex;}
.lb-bar{display:flex; align-items:center; gap:8px; padding:10px 14px; border-bottom:1px solid var(--hair); font-family:var(--mono); font-size:12px; color:var(--gold-bright);}
.lb-bar span{flex:1;}
.lb-bar button{background:none; border:1px solid var(--hair); color:var(--white); font-size:14px; min-width:36px; height:32px; border-radius:2px; cursor:pointer; font-family:var(--sans);}
.lb-bar button:hover{border-color:var(--gold);}
.lb-body{flex:1; overflow:auto; display:flex; justify-content:center; align-items:flex-start; padding:16px;}
.lb-body img{max-width:min(100%, 1156px); height:auto; background:#fff;}
.lb.zoom .lb-body img{max-width:none; width:1156px;}

/* ---- library ---- */
.shelf{display:grid; grid-template-columns:repeat(auto-fill, minmax(250px, 1fr)); gap:28px; padding-top:10px; padding-bottom:60px;}
.issue{background:var(--panel); border:1px solid var(--hair); display:flex; flex-direction:column;}
.issue .cv{display:block; border-bottom:1px solid var(--hair); background:#000;}
.issue .cv img{width:100%; height:auto; aspect-ratio:1156/1496; object-fit:cover; transition:opacity .15s;}
.issue .cv:hover img{opacity:.88;}
.issue .body{padding:16px 18px 18px; display:flex; flex-direction:column; gap:8px; flex:1;}
.issue h2{font-family:var(--serif); font-size:21px; line-height:1.25; margin:0;}
.issue h2 a{text-decoration:none;}
.issue h2 a:hover{color:var(--gold-bright);}
.issue p{margin:0; font-size:14px; color:var(--muted);}
.issue .actions{margin-top:auto; padding-top:8px;}
.issue .btn{padding:8px 14px; font-size:13px;}
.issue.soon{opacity:.75;}
.issue.soon .cv img{filter:grayscale(.3);}

@media print{
  .top, .bar, .toc, .foot, .hero .actions, .scan-link, .thumb, .lb, .note{display:none !important;}
  body{background:#fff; color:#000;}
  .layout{display:block; padding:0;}
  .sheet{box-shadow:none; border:0; padding:0; background:#fff;}
  body.mode-pages .scan{display:block; box-shadow:none; border:0; break-inside:avoid;}
  .pg{break-before:page;}
}
@media (prefers-reduced-motion:reduce){ html{scroll-behavior:auto;} }
CSS

my $JS = <<'JS';
(function(){
  var body = document.body;
  function store(k, v){ try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }

  // ---- text / pages view ----
  var modeBtns = document.querySelectorAll('[data-mode]');
  function setMode(m){
    body.classList.toggle('mode-text', m === 'text');
    body.classList.toggle('mode-pages', m === 'pages');
    modeBtns.forEach(function(b){ b.setAttribute('aria-pressed', String(b.getAttribute('data-mode') === m)); });
    store('heritage-mode', m);
  }
  modeBtns.forEach(function(b){
    b.addEventListener('click', function(){
      var here = currentPage();
      setMode(b.getAttribute('data-mode'));
      if (here) here.scrollIntoView({block:'start'});
    });
  });
  setMode(store('heritage-mode') === 'pages' ? 'pages' : 'text');

  // ---- text size ----
  var SIZES = [16, 17, 19, 21, 23, 26], size = parseInt(store('heritage-size'), 10);
  if (SIZES.indexOf(size) < 0) size = 19;
  function setSize(s){ size = s; document.documentElement.style.setProperty('--read-size', s + 'px'); store('heritage-size', s); }
  setSize(size);
  document.querySelectorAll('[data-size]').forEach(function(b){
    b.addEventListener('click', function(){
      var i = SIZES.indexOf(size) + (b.getAttribute('data-size') === 'up' ? 1 : -1);
      if (i >= 0 && i < SIZES.length) setSize(SIZES[i]);
    });
  });

  // ---- jump menu + table of contents highlight ----
  var pages = [].slice.call(document.querySelectorAll('.pg'));
  var jump = document.getElementById('jump');
  jump.addEventListener('change', function(){
    var t = document.getElementById(jump.value);
    if (t) { t.scrollIntoView({block:'start'}); history.replaceState(null, '', '#' + jump.value); }
  });
  function currentPage(){
    var y = Math.max(90, window.innerHeight * 0.3), best = null;
    pages.forEach(function(p){ if (p.getBoundingClientRect().top <= y) best = p; });
    return best || pages[0];
  }
  var tocLinks = [].slice.call(document.querySelectorAll('.toc a'));
  function markCurrent(){
    var p = currentPage(); if (!p) return;
    var n = parseInt(p.getAttribute('data-page'), 10), on = null;
    tocLinks.forEach(function(a){ if (parseInt(a.getAttribute('data-page'), 10) <= n) on = a; });
    tocLinks.forEach(function(a){ a.classList.toggle('on', a === on); });
    if (jump.value !== p.id) jump.value = p.id;
  }
  var ticking = false;
  window.addEventListener('scroll', function(){
    if (ticking) return; ticking = true;
    requestAnimationFrame(function(){ ticking = false; markCurrent(); });
  }, {passive:true});
  window.addEventListener('load', markCurrent);
  markCurrent();

  // ---- full-size page viewer ----
  var lb = document.getElementById('lb'), lbImg = document.getElementById('lb-img'), lbTitle = document.getElementById('lb-title');
  var lbIndex = 0, lastFocus = null;
  function openPage(i){
    lbIndex = Math.max(0, Math.min(pages.length - 1, i));
    var p = pages[lbIndex];
    lbImg.src = p.getAttribute('data-scan');
    lbImg.alt = 'Page ' + p.getAttribute('data-page') + ', full size';
    lbTitle.textContent = 'Page ' + p.getAttribute('data-page') + ' of ' + pages.length;
    if (!lb.classList.contains('open')) { lastFocus = document.activeElement; lb.classList.add('open'); document.getElementById('lb-close').focus(); }
    lb.querySelector('.lb-body').scrollTop = 0;
  }
  function closePage(){
    lb.classList.remove('open', 'zoom'); lbImg.removeAttribute('src');
    pages[lbIndex].scrollIntoView({block:'start'});
    if (lastFocus) lastFocus.focus();
  }
  document.addEventListener('click', function(e){
    var t = e.target.closest('[data-open]');
    if (t) { e.preventDefault(); openPage(pages.indexOf(t.closest('.pg'))); }
  });
  document.getElementById('lb-close').addEventListener('click', closePage);
  document.getElementById('lb-prev').addEventListener('click', function(){ openPage(lbIndex - 1); });
  document.getElementById('lb-next').addEventListener('click', function(){ openPage(lbIndex + 1); });
  document.getElementById('lb-zoom').addEventListener('click', function(){ lb.classList.toggle('zoom'); });
  document.addEventListener('keydown', function(e){
    if (!lb.classList.contains('open')) return;
    if (e.key === 'Escape') closePage();
    else if (e.key === 'ArrowLeft') openPage(lbIndex - 1);
    else if (e.key === 'ArrowRight') openPage(lbIndex + 1);
  });
})();
JS

sub page_shell { my (%a) = @_;
  my $canon = "https://sc-museum.github.io/heritage/$a{path}";
  return <<"HTML";
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>@{[ esc($a{title}) ]}</title>
<meta name="description" content="@{[ esc($a{desc}) ]}">
<link rel="canonical" href="$canon">
<link rel="icon" type="image/png" href="../seal.png">
<meta property="og:type" content="$a{ogtype}">
<meta property="og:site_name" content="Signal &amp; Cyber Corps Museum Society">
<meta property="og:title" content="@{[ esc($a{title}) ]}">
<meta property="og:description" content="@{[ esc($a{desc}) ]}">
<meta property="og:url" content="$canon">
<meta property="og:image" content="https://sc-museum.github.io/heritage/$a{image}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#0d1f16">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Spectral:ital,wght\@0,400;0,600;0,700;1,400&family=IBM+Plex+Sans:wght\@400;600&family=IBM+Plex+Mono:wght\@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="heritage.css">
</head>
<body class="$a{bodyclass}">
<a class="skip" href="#main">Skip to content</a>
<header class="top"><div class="wrap">
  <a class="brand" href="../"><img src="../seal.png" alt=""><div><b>Signal &amp; Cyber Corps Museum Society</b><span>Virtual Museum</span></div></a>
  <nav aria-label="Site"><a href="../">Museum</a><a href="./"@{[ $a{path} eq '' ? ' aria-current="page"' : '' ]}>Heritage</a></nav>
</div></header>
$a{content}
<footer class="foot"><div class="wrap">
  <div><i>Heritage</i> is published by the Fort Gordon Historical Museum Society, now the Signal &amp; Cyber Corps Museum Society.</div>
  <div><a href="../">← Back to the virtual museum</a></div>
</div></footer>
$a{script}
</body>
</html>
HTML
}

my @cards;
for my $is (@ISSUES) {
  my $n = $is->{n};
  my $dir = "$ROOT/heritage/issue-$n";
  opendir my $dh, $dir or die "$dir: $!";
  my @nums = sort { $a <=> $b } map { /^p(\d+)\.jpg$/ ? $1 + 0 : () } readdir $dh; closedir $dh;
  my %toc = map { $_->[0] => $_->[1] } @{ $is->{toc} };
  my $label = "Issue $n · $is->{season}";

  # whole-issue PDF
  my $pdf = "$ROOT/heritage/pdf/$is->{pdf}";
  system('perl', "$FindBin::Bin/mkpdf.pl", $pdf, "Heritage, $label", map { sprintf '%s/p%02d.jpg', $dir, $_ } @nums) == 0 or die "pdf failed";
  my $pdf_size = mb(-s $pdf);
  $is->{pdf_size} = $pdf_size; $is->{pages} = scalar @nums;

  my (@sections, @opts);
  for my $p (@nums) {
    my $img = sprintf 'issue-%d/p%02d.jpg', $n, $p;
    my $thumb = sprintf 'issue-%d/thumbs/p%02d.jpg', $n, $p;
    my ($w, $h) = jpeg_size("$ROOT/heritage/$img");
    my ($tw, $th) = jpeg_size("$ROOT/heritage/$thumb");
    my $name = $p == 1 ? 'Cover' : $p == $nums[-1] ? 'Back cover' : "Page $p";
    my $title = $toc{$p};
    my $alt = esc(($title ? "$title — " : '') . "$name of Heritage, $label");
    my $text = page_text_html($n, $p);
    my $words = () = $text =~ /\s+/g;
    my $sheet;
    if ($words > 25) {
      $sheet = qq{<div class="sheet"><button type="button" class="thumb" data-open aria-label="View $name full size"><img src="$thumb" width="$tw" height="$th" loading="lazy" decoding="async" alt=""></button>\n<div class="txt">\n$text\n</div></div>};
    } else {
      # covers, photo pages and pages with no text layer: the picture is the content
      $sheet = qq{<div class="sheet"><p class="no-text">} . ($p == 1 || $p == $nums[-1] ? 'The cover.' : 'This page is mostly pictures or was published as an image.') . qq{ Select it to read it full size.</p><figure class="full"><img src="$img" width="$w" height="$h" loading="lazy" decoding="async" alt="$alt" data-open></figure></div>};
    }
    my $head = qq{<span class="pg-no">$name</span>} . ($title ? qq{<h2 class="pg-title">@{[ esc($title) ]}</h2>} : '')
      . qq{<button type="button" class="scan-link" data-open>View page ⤢</button>};
    push @sections, qq{<section class="pg@{[ $title ? ' starts' : '' ]}" id="p-$p" data-page="$p" data-scan="$img" aria-label="$name">\n<div class="pg-head">$head</div>\n$sheet\n<figure class="scan"><img src="$img" width="$w" height="$h" loading="lazy" decoding="async" alt="$alt" data-open></figure>\n</section>};
    push @opts, qq{<option value="p-$p">$name@{[ $title ? ' — ' . esc($title) : '' ]}</option>};
  }
  my $toc_html = join "\n", map { qq{<li><a href="#p-$_->[0]" data-page="$_->[0]"><span>$_->[0]</span>@{[ esc($_->[1]) ]}</a></li>} } @{ $is->{toc} };

  my $content = <<"HTML";
<main id="main">
<div class="wrap hero">
  <div>
    <div class="kicker">Heritage · $label</div>
    <h1>@{[ esc($is->{title}) ]}</h1>
    <p class="dek">@{[ esc($is->{dek}) ]}</p>
    <div class="actions">
      <a class="btn primary" href="pdf/$is->{pdf}" download>Download PDF <small>$pdf_size · $is->{pages} pages</small></a>
      <a class="btn ghost" href="https://issuu.com/fghms/docs/$is->{issuu}" target="_blank" rel="noopener">Issuu edition ↗</a>
    </div>
  </div>
  <img class="cover" src="issue-$n/thumbs/p01.jpg" alt="Cover of Heritage, $label" width="360" height="466">
</div>
<div class="bar"><div class="wrap">
  <div class="seg" role="group" aria-label="View">
    <button type="button" data-mode="text" aria-pressed="true">Read text</button>
    <button type="button" data-mode="pages" aria-pressed="false">Page scans</button>
  </div>
  <div class="sizes" role="group" aria-label="Text size">
    <button type="button" class="tool" data-size="down" aria-label="Smaller text">A−</button>
    <button type="button" class="tool" data-size="up" aria-label="Larger text">A+</button>
  </div>
  <select class="jump" id="jump" aria-label="Go to page">
@{[ join "\n", @opts ]}
  </select>
  <a class="btn primary dl" href="pdf/$is->{pdf}" download>↓ <span>PDF</span></a>
</div></div>
<div class="wrap layout">
  <nav class="toc" aria-label="In this issue"><h2>In this issue</h2><ol>
$toc_html
  </ol></nav>
  <div>
    <p class="note">The text below comes from the digital edition, so photo captions and sidebars may sit out of order. The page scans are the original layout: switch to <b>Page scans</b> or select any page to see it full size.</p>
@{[ join "\n", @sections ]}
  </div>
</div>
</main>
<div class="lb" id="lb" role="dialog" aria-modal="true" aria-labelledby="lb-title">
  <div class="lb-bar"><span id="lb-title"></span>
    <button type="button" id="lb-prev" aria-label="Previous page">‹</button>
    <button type="button" id="lb-next" aria-label="Next page">›</button>
    <button type="button" id="lb-zoom" aria-label="Toggle zoom">⤢</button>
    <button type="button" id="lb-close" aria-label="Close">×</button>
  </div>
  <div class="lb-body"><img id="lb-img" alt=""></div>
</div>
HTML
  spew("$ROOT/heritage/issue-$n.html", page_shell(
    title => "$is->{title} — Heritage, $label", path => "issue-$n.html", ogtype => 'article',
    desc => $is->{dek}, image => "issue-$n/thumbs/p01.jpg", bodyclass => 'mode-text',
    content => $content, script => "<script>\n$JS</script>"));

  push @cards, <<"HTML";
<article class="issue">
  <a class="cv" href="issue-$n.html"><img src="issue-$n/thumbs/p01.jpg" width="360" height="466" loading="lazy" alt="Cover of Heritage, $label"></a>
  <div class="body">
    <div class="kicker">$label</div>
    <h2><a href="issue-$n.html">@{[ esc($is->{title}) ]}</a></h2>
    <p>@{[ esc($is->{dek}) ]}</p>
    <div class="actions">
      <a class="btn primary" href="issue-$n.html">Read</a>
      <a class="btn ghost" href="pdf/$is->{pdf}" download>PDF <small>$pdf_size</small></a>
    </div>
  </div>
</article>
HTML
}

push @cards, <<'HTML';
<article class="issue soon">
  <div class="cv"><img src="../assets/heritage_space.jpg" loading="lazy" alt="Heritage magazine cover: Shaping Space Operations"></div>
  <div class="body">
    <div class="kicker">Coming soon</div>
    <h2>Shaping Space Operations</h2>
    <p>This issue will be added to the reading room when it is published online.</p>
  </div>
</article>
HTML

spew("$ROOT/heritage/heritage.css", $CSS);
spew("$ROOT/heritage/index.html", page_shell(
  title => 'Heritage Magazine — Signal & Cyber Corps Museum Society', path => '', ogtype => 'website',
  desc => 'Read every issue of Heritage, the magazine of the Signal & Cyber Corps Museum Society, online or download it as a PDF.',
  image => 'issue-1/thumbs/p01.jpg', bodyclass => '', script => '',
  content => <<"HTML"));
<main id="main">
<div class="wrap" style="padding-top:36px; padding-bottom:22px;">
  <div class="kicker">The Society's magazine</div>
  <h1>Heritage</h1>
  <p class="dek">Every issue of <i>Heritage</i>, the Society's magazine of Signal Corps and Fort Gordon history. Read any issue here, as text sized for your screen or as the original pages, or download it as a PDF.</p>
</div>
<div class="wrap shelf">
@{[ join '', @cards ]}
</div>
</main>
HTML
