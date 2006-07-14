#!perl
# $Id: /mirror/Text-MeCab/trunk/Build.PL 1621 2006-07-05T08:42:36.916180Z daisuke  $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;
use Module::Build;

my $result = do 'tools/probe_mecab.pl';
die if $@;

my $class = Module::Build->subclass(code => <<'CODE');
    sub ACTION_disttest
    {
        my $self = shift;
        local $ENV{PERL_TESTPOD} = 1;
        $self->SUPER::ACTION_disttest(@_);
    }

    sub find_test_files
    {
        my $self  = shift;
        my $tests = $self->SUPER::find_test_files(@_);

        return $tests if $ENV{PERL_TESTPOD};
        return [ grep { $_ !~ /\bpod.*\.t\z/ } @$tests ];
    }
CODE

my $build = $class->new(
    dist_name => 'Text-MeCab',
    dist_version_from => 'lib/Text/MeCab.pm',
    extra_compiler_flags => [ split(/\s+/, $result->{cflags}), '-Wall' ],
    extra_linker_flags  => [ split(/\s+/, $result->{libs}) ],
    c_source => 'src',
    license => 'perl',
    create_readme => 1,
);
$build->create_build_script;