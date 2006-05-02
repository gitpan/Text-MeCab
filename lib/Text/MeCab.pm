# $Id: MeCab.pm 3 2006-05-02 02:29:14Z daisuke $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

package Text::MeCab;
use strict;
use vars qw($VERSION @ISA %EXPORT_TAGS @EXPORT_OK);
BEGIN
{
    $VERSION = '0.02';
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

sub new
{
    my $class = shift;
    return (ref($_[0]) eq 'HASH') ? $class->_new(@_) : $class->_new_optarg(\@_);
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
    input_buffer_size  => $input_buffer_soap,
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
  use Text::MeCab qw(MECAB_NODE_NODE);

  # want to use a command line arguments?
  my $mecab = Text::MeCab->new("--userdic=/foo/bar/baz", "-P");

=head1 DESCRIPTION

libmecab (http://mecab.sourceforge.ne.jp) already has a perl interface built 
with it, so why a new module? I just feel that while a subtle difference,
making the perl interface through a tied hash is just... weird.

So Text::MeCab gives you a more natural, Perl-ish way to access libmecab!

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

Parses the given text via mecab, and returns a mecab node object.

=head1 SEE ALSO

http://mecab.sourceforge.ne.jp

=head1 AUTHOR

(c) 2006 Daisuke Maki E<lt>dmaki@cpan.orgE<gt>
All rights reserved.

=cut
