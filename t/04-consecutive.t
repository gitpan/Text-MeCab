#!perl
use strict;
use Test::More qw(no_plan);

BEGIN
{
    use_ok("Text::MeCab");
}

my $text_A = "太郎は次郎が持っている本を花子に渡した。";
my $text_B = "すもももももももものうち。";
my $mecab = Text::MeCab->new;

my $node_A = $mecab->parse($text_A);
my $node_B = $mecab->parse($text_B);

# XXX - better be at least 5 nodes after parsing (this may actually depend
# on the dictionary that you are using, but heck, if you are crazy enough
# to muck with the dictionary, then you know how to diagnose this test)

for(1..5) {
    if ($node_A->length != 0 || $node_B->length != 0) {
        isnt($node_A->surface, $node_B->surface);
    }

    $node_A = $node_A->next;
    $node_B = $node_B->next;
}