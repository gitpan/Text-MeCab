
use strict;
use Test::More qw(no_plan);
use Encode;

BEGIN
{
    use_ok("Text::MeCab");
}

my $text = encode('euc-jp', decode('utf-8', "となりの客は良く柿食う客だ"));

my $mecab = Text::MeCab->new({ 
    output_format_type => 'user',
    node_format => "%m",
});
for( my $node = $mecab->parse($text);
        $node;
        $node = $node->next
) {
    next unless $node->surface;

    my $format = $node->format($mecab);
    my $feature = $node->feature;
    ok($format, "format returns '$format'");
    unlike($format, qr/,/, "'$format' doesn't contain any comma");
    like($feature, qr/,/, "'$feature' does contain commas");
}

for( my $node = $mecab->parse($text)->dclone;
        $node;
        $node = $node->next
) {
    next unless $node->surface;

    my $format = $node->format($mecab);
    my $feature = $node->feature;
    ok($format, "format returns '$format'");
    unlike($format, qr/,/, "'$format' doesn't contain any comma");
    like($feature, qr/,/, "'$feature' does contain commas");
}
