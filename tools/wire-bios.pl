#!/usr/bin/perl
use strict; use warnings;
my $file = shift or die;

my %MAP = (
  'Shalisha Haynes'   => 'haynes',
  'Laroy Peyton'      => 'peyton',
  'Tom Washer'        => 'washer',
  'Eric Toler'        => 'toler',
  'Pete Wilson'       => 'wilson',
  'John McConnell'    => 'mcconnell',
  'Jeffery Foley'     => 'foley',
  'Ann Johnson'       => 'johnson',
  'Dr. Tom Clark'     => 'clark',
  'Eric Y. Nishizawa' => 'nishizawa',
  'Stuart M. Dyer'    => 'dyer',
);

local $/;
open(my $fh, '<:encoding(UTF-8)', $file) or die $!;
my $html = <$fh>; close $fh;

my $n = 0;
for my $name (sort { length($b) <=> length($a) } keys %MAP) {
  my $key = $MAP{$name};
  my $q = quotemeta($name);
  my $new = '<div class="nm"><button type="button" class="bio-link" data-bio="' . $key . '">'
          . '<span class="n">' . $name . '</span>'
          . '<span class="more">Read biography &#10530;</span></button></div>';
  my $c = ($html =~ s{<div class="nm">$q</div>}{$new}g);
  $n += $c;
  printf "%-20s -> %-12s %d place(s)\n", $name, $key, $c;
}

open(my $out, '>:encoding(UTF-8)', $file) or die $!;
print $out $html; close $out;
print "total rewritten: $n\n";
