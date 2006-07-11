#!/usr/bin/perl
use strict;
use blib;
use Text::MeCab;

open(FILE, shift @ARGV);
local $/ = undef;
my $string = <FILE>;
close(FILE);

# my $string = "太郎は次郎が持っている本を花子に渡した。";

my @words;
my $mecab = Text::MeCab->new;
my $count = 0;
my $node = $mecab->parse($string);

while ($node) {
    push @words, $node->surface;
    $count++;
    if ($count % 100 == 0) {
        print "processed $count items...\n";
    }

    if (! defined($node)) {
        print "node is undefined\n";
    }
    $node = $node->next;
#    last if $count == 10_000_000;
}

print "now joing this baby\n",
    join('', @words);