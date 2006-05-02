#!perl
use strict;
use Test::More qw(no_plan);

BEGIN
{
    use_ok("Text::MeCab");
}

my $mecab = Text::MeCab->new({ all_morphs => 1 });
ok($mecab);

for (
    my $node = $mecab->parse("太郎は次郎が持っている本を花子に渡した。");
    $node;
    $node = $node->next
) {
    foreach my $field qw(surface length rcattr lcattr stat isbest alpha beta prob wcost cost) {
        my $p = eval { $node->$field };
        ok(!$@, "$field ok ($p)");
    }
}

$mecab = Text::MeCab->new("--all-morphs");
ok($mecab);

for (
    my $node = $mecab->parse("太郎は次郎が持っている本を花子に渡した。");
    $node;
    $node = $node->next
) {
    foreach my $field qw(surface length rcattr lcattr stat isbest alpha beta prob wcost cost) {
        my $p = eval { $node->$field };
        ok(!$@, "$field ok ($p)");
    }
}


1;