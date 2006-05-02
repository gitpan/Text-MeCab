#!perl
use strict;
use Test::More (tests => 5);

BEGIN
{
    use_ok("Text::MeCab", ':all');
}

ok(eval { my $v = MECAB_NOR_NODE; 1 } && !$@, "MECAB_NOR_NODE ok");
ok(eval { my $v = MECAB_UNK_NODE; 1 } && !$@, "MECAB_UNK_NODE ok");
ok(eval { my $v = MECAB_BOS_NODE; 1 } && !$@, "MECAB_BOS_NODE ok");
ok(eval { my $v = MECAB_EOS_NODE; 1 } && !$@, "MECAB_EOS_NODE ok");

1;