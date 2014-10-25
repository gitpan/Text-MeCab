#!perl
use strict;
use Test::More qw(no_plan);

BEGIN
{
    use_ok("Text::MeCab");
}

my $node;
my $text = "��Ϻ�ϼ�Ϻ�����äƤ����ܤ�ֻҤ��Ϥ�����";
{
    my $mecab = Text::MeCab->new;
    $node = $mecab->parse($text);
    $mecab = undef;
}

ok($node); # yes, node exists, but DO NOT use node->surface.
