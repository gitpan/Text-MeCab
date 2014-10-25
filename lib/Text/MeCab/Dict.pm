# $Id: /mirror/coderepos/lang/perl/Text-MeCab/trunk/lib/Text/MeCab/Dict.pm 38366 2008-01-10T02:38:13.336273Z daisuke  $
#
# Copyright (c) 2008 Daisuke Maki <daisuke@endeworks.jp>
# All rights reserved.

package Text::MeCab::Dict;
use strict;
use warnings;
use base qw(Class::Accessor::Fast);
use Text::CSV_XS;
use Text::MeCab;
use Path::Class::Dir;
use Path::Class::File;

our $MAKE = 'make';

__PACKAGE__->mk_accessors($_) for qw(entries config dict_source libexecdir input_encoding output_encoding);

sub new
{
    my $class = shift;
    my %args  = @_;

    my $libexecdir;
    my $config = $args{mecab_config} || &Text::MeCab::MECAB_CONFIG;
    my $dict_source = $args{dict_source};
    my $ie     = $args{ie} || $args{input_encoding} || &Text::MeCab::ENCODING;
    my $oe     = $args{oe} || $args{output_encoding} || &Text::MeCab::ENCODING;

    if (! $config) {
        $libexecdir = $args{libexecdir};
    } else {
        $libexecdir = `$config --libexecdir`;
        chomp $libexecdir;
    }

    if (! $dict_source || ! $libexecdir) {
        die "You must specify dict_source and libexecdir";
    }
    $dict_source = Path::Class::Dir->new($dict_source);
    $libexecdir = Path::Class::Dir->new($libexecdir);

    my $self  = bless {
        config          => $config,
        entries         => [],
        dict_source     => $dict_source,
        libexecdir      => $libexecdir,
        input_encoding  => $ie,
        output_encoding => $oe,
    }, $class;
}

sub add
{
    my $self = shift;

    my $entry;
    if (scalar @_ == 1) {
        $entry = shift @_;
    } else {
        my %args = @_;
        $entry = Text::MeCab::Dict::Entry->new(%args);
    }
    push @{ $self->entries }, $entry;
}

sub write
{
    my $self = shift;
    my $file = shift;
    my $csv  = Text::CSV_XS->new({ binary => 1 });

    my @output;
    my $entries = $self->entries;

    my @columns = qw(
        surface left_id right_id cost pos category1 category2 category3 
        inflect inflect_type original yomi pronounse extra
    );
    foreach my $entry (@$entries) {
        $csv->combine( map { $entry->$_ } @columns ) or
            die "Failed at Text::CSV_XS->combine";
        push @output, $csv->string;
    }

    $file = Path::Class::File->new($file);
    if (! $file->is_absolute) {
        $file = $self->dict_source->file( $file );
    }

    my $fh = $file->open(">>");
    $fh->print(join("\n", @output, ""));
    $fh->close;

    $self->entries([]);
}

sub rebuild
{
    my $self = shift;

    my $dict_source = $self->dict_source;
    my $dict_index = $self->libexecdir->file('mecab-dict-index');

    my $curdir = Path::Class::Dir->new->absolute;
    eval {
        chdir $dict_source;

        my @cmds = (
            [ $dict_index, '-f', $self->input_encoding, '-t', $self->output_encoding ],
            [ $MAKE, "install" ]
        );

        foreach my $cmd (@cmds) {
            if (system(@$cmd) != 0) {
                die "Failed to execute '@$cmd': $!";
            }
        }
    };
    if (my $e = $@) {
        chdir $curdir;
        die $e;
    }
}

package Text::MeCab::Dict::Entry;
use strict;
use warnings;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors($_) for qw(
    surface left_id right_id cost pos category1 category2 category3 
    inflect inflect_type original yomi pronounse extra
);

sub new
{
    my $class = shift;
    $class->SUPER::new({ 
        left_id  => -1,
        right_id => -1,
        cost     => 0,
        @_
    });
}

1;

__END__

=encoding UTF-8

=head1 NAME

Text::MeCab::Dict - Utility To Work With MeCab Dictionary

=head1 SYNOPSIS

  use Text::MeCab::Dict;

  my $dict = Text::MeCab::Dict->new(
    dict_source => "/path/to/mecab-ipadic-source"
  );
  $dict->add(
    surface      => $surface,        # 表層形
    left_id      => $left_id,        # 左文脈ID
    right_id     => $right_id,       # 右文脈ID
    cost         => $cost,           # コスト
    pos          => $part_of_speech, # 品詞
    category1    => $category1,      # 品詞細分類1
    category2    => $category2,      # 品詞細分類2
    category3    => $category3,      # 品詞細分類3

    # XXX this below two parameter names need blessing from a knowing
    # expert, and is subject to change
    inflect      => $inflect,        # 活用形
    inflect_type => $inflect_type,   # 活用型

    original     => $original,       # 原形
    yomi         => $yomi,           # 読み
    pronounce    => $pronounce,      # 発音
    extra        => \@extras,        # ユーザー設定
  );
  $dict->write('foo.csv');
  $dict->build();

=head1 METHODS

=head2 new

Creates a new instance of Text::MeCab::Dict. 

The path to the source of mecab-ipadic is required:

  my $dict = Text::MeCab::Dict->new(
    dict_source => "/path/to/mecab-ipadic-source"
  );

If you are in an environment where mecab-config is NOT available, you must
also specify libexecdir, which is where mecab-dict-index is installed:

  my $dict = Text::MeCab::Dict->new(
    dict_source => "/path/to/mecab-ipadic-source",
    libexecdir  => "/path/to/mecab/libexec/",
  );

=head2 add

Adds a new entry to be appended to the dictionary. Please see SYNOPSIS for
arguments.

=head2 write

Writes out the entries that were added via add() to the specified file
location. If the file name does not look like an absolute path, the name
will be treated relatively from dict_source

=head2 rebuild

Rebuilds the index. This usually requires that you are have root privileges

=head1 SEE ALSO

http://mecab.sourceforge.net/dic.html

=cut