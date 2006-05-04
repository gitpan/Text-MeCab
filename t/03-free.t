#!perl
use strict;
use Test::More qw(no_plan);

BEGIN
{
    use_ok("Text::MeCab");
}

my $node;
my $text = "太郎は次郎が持っている本を花子に渡した。";
{
    my $mecab = Text::MeCab->new;
    $node = $mecab->parse($text);
    $mecab = undef;
}

for(; $node; $node = $node->next) {
    ok(defined $node->surface);
    last unless $node->next;
}

for(; $node; $node = $node->prev) {
    ok(defined $node->surface);
}
