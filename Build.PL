#!perl
# $Id: Build.PL 11 2006-05-07 16:38:07Z daisuke $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;
use Module::Build;

my $result = do 'tools/probe_mecab.pl';
die if $@;

my $build = Module::Build->new(
    dist_name => 'Text-MeCab',
    dist_version_from => 'lib/Text/MeCab.pm',
    extra_compiler_flags => [ split(/\s+/, $result->{cflags}) ],
    extra_linker_flags  => [ split(/\s+/, $result->{libs}) ],
    c_source => 'src',
    license => 'perl',
    create_readme => 1,
);
$build->create_build_script;