use strict;
use Test::More qw(no_plan);
use MeCab;
use Text::MeCab;

my $text = "今日は晴れ";

my $swig_result = '';
{
    my $swig_mecab = MeCab::Tagger->new("--all-morphs");
    for (
        my $node = $swig_mecab->parseToNode($text);
        $node;
        $node = $node->{next}
    ) {
        $swig_result .= $node->{feature}."\n";
    }
}

my $xs_result = '';
{
    my $xs_mecab = Text::MeCab->new({ all_morphs => 1 });
    for (
        my $node = $xs_mecab->parse($text);
        $node;
        $node = $node->next
    ) {
        $xs_result .= $node->feature . "\n";
    }
}

is $swig_result, $xs_result;
