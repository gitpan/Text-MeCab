#!perl
use strict;
use Test::More qw(no_plan);

BEGIN
{
    use_ok("Text::MeCab");
}

my $mecab = Text::MeCab->new({ all_morphs => 1 });
ok($mecab);

my @fields = qw(surface feature length cost);
if (&Text::MeCab::MECAB_VERSION >= 0.90) {
    push @fields, qw(rcattr lcattr stat isbest alpha beta prob wcost);
}

for (
    my $node = $mecab->parse("太郎は次郎が持っている本を花子に渡した。");
    $node;
    $node = $node->next
) {
    foreach my $field (@fields) {
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
    foreach my $field (@fields) {
        my $p = eval { $node->$field };
        ok(!$@, "$field ok ($p)");
    }
}


1;