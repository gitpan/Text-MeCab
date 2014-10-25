# $Id: /mirror/Text-MeCab/trunk/lib/Text/MeCab.pm 2035 2006-07-11T17:50:38.222225Z daisuke  $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

package Text::MeCab;
use strict;
use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT_OK);
BEGIN
{
    $VERSION = '0.09';
    if ($] > 5.006) {
        require XSLoader;
        XSLoader::load(__PACKAGE__, $VERSION);
    } else {
        require DynaLoader;
        @ISA = qw(DynaLoader);
        __PACKAGE__->bootstrap;
    }

    require Exporter;
    push @ISA, 'Exporter';

    %EXPORT_TAGS = (all => [ qw(MECAB_NOR_NODE MECAB_UNK_NODE MECAB_BOS_NODE MECAB_EOS_NODE) ]);
    @EXPORT_OK = map { @$_ } values %EXPORT_TAGS;
}

my %bool_options = (
    map { ($_, 'bool') } qw(
        --all-morphs --partial --allocate-sentence --version --help
    )
);

sub new
{
    my $class = shift;
    my @args;
    if (ref($_[0]) ne 'HASH') {
        @args = @_;
    } else {
        my %args = %{$_[0]};
        while (my ($key, $value) = each %args) {
            $key =~ s/_/-/g;
            my $l_key = "--$key";
            if ($bool_options{$l_key}) {
                push @args, $l_key;
            } else {
                push @args, "$l_key=$value";
            }
        }
    }

    return $class->xs_new(\@args);
}

1;

__END__

=head1 NAME

Text::MeCab - Alternate Interface To libmecab

=head1 SYNOPSIS

  use Text::MeCab;
  my $mecab = Text::MeCab->new({
    rcfile             => $rcfile,
    dicdir             => $dicdir,
    userdic            => $userdic,
    lattice_level      => $lattice_level,
    all_morphs         => $all_morphs,
    output_format_type => $output_format_type,
    partial            => $partial,
    node_format        => $node_format,
    unk_format         => $unk_format,
    bos_format         => $bos_format,
    eos_format         => $eos_format,
    input_buffer_size  => $input_buffer_size,
    allocate_sentence  => $allocate_sentence,
    nbest              => $nbest,
    theta              => $theta,
  });

  for (my $node = $mecab->parse($text); $node; $node = $node->next) {
     # See perdoc for Text::MeCab::Node for list of methods
     print $node->surface, "\n";
  }

  # use constants
  use Text::MeCab qw(:all);
  use Text::MeCab qw(MECAB_NOR_NODE);

  # want to use a command line arguments?
  my $mecab = Text::MeCab->new("--userdic=/foo/bar/baz", "-P");

  # check what mecab version we compiled against?
  print "Compiled with ", &Text::MeCab::MECAB_VERSION, "\n";

=head1 DESCRIPTION

libmecab (http://mecab.sourceforge.ne.jp) already has a perl interface built 
with it, so why a new module? I just feel that while a subtle difference,
making the perl interface through a tied hash is just... weird.

So Text::MeCab gives you a more natural, Perl-ish way to access libmecab!

WARNING: Please note that this module is primarily targetted for libmecab
>= 0.90, so if things seem to be broken and your libmecab version is below
0.90, then you might want to consider upgrading libmecab first.

=head1 Text::MeCab AND SCOPING

[NOTE: The memory management issue has been changed since 0.09]

libmecab's default behavior is such that when you analyze a text and get a
node back, that node is tied to the mecab "tagger" object that did the
analysis. Therefore, when that tagger is destroyed via mecab_destroy(),
all nodes that are associated to it are freed as well.

Text::MeCab defaults to the same behavior, so the following won't work:

  sub get_mecab_node {
     my $mecab = Text::MeCab->new;
     my $node  = $mecab->parse($_[0]);
     return $node;
  }

  my $node = get_mecab_node($text);

By the time get_mecab_node() returns, the Text::MeCab object is DESTROY'ed, 
and so is $node (actually, the object exists, but it will complain when you
try to access the nodes internals, because the C struct that was there
has already been freed).

In such cases, use the dclone() method. This will copy the *entire* node
structure and create a new Text::MeCab::Node::Cloned instance. 

  sub get_mecab_node {
     my $mecab = Text::MeCab->new;
     my $node  = $mecab->parse($_[0]);
     return $node->dclone();
  }

The returned Text::MeCab::Node::Cloned object is exactly the same as 
Text::MeCab::Node object on the surface. It just uses a different but
very similar C struct underneath. It is blessed into a different namespace
only because we need to use a different memory management strategy.

Do be aware of the memory issue. You WILL use up twice as much memory.

Also please note that if you try the first example, accessiing node WILL
result in a segfauilt. This is not a bug: it's a feature :) While it is
possible to control the memory management such that accessing a field in
a node that has already expired results in a legal croak(), we do not go
to the length to ensure this, because it will result in a performance
penalty. 

Just remember that unless you dclone() a node, then you are NOT allowed to
access it when the original tagger goes out scope:

   {
       my $mecab = Text::MeCab->new;
       $node = $mecab->parse(...);
   }

   $node->surface; # segfault!!!!

Always remember to dclone() before doing this!

=head1 METHODS

=head2 new HASHREF | LIST

Creates a new Text::MeCab instance.

You can either specify a hashref and use named parameters, or you can use the
exact command line arguments that the mecab command accepts.

Below is the list of accepted named options. See the man page for mecab for 
details about each option.

=over 4

=item B<rcfile>

=item B<dicdir>

=item B<lattice_level>

=item B<all_morphs>

=item B<output_format_type>

=item B<partial>

=item B<node_format>

=item B<unk_format>

=item B<bos_format>

=item B<eos_format>

=item B<input_buffer_size>

=item B<allocate_sentence>

=item B<nbest>

=item B<theta>

=back

=head2 parse SCALAR

Parses the given text via mecab, and returns a Text::MeCab::Node object.

=head1 SEE ALSO

http://mecab.sourceforge.ne.jp

=head1 AUTHOR

(c) 2006 Daisuke Maki E<lt>dmaki@cpan.orgE<gt>
All rights reserved.

=cut
