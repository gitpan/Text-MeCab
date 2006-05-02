#!perl
# $Id: Build.PL 2 2006-05-02 02:11:10Z daisuke $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;
use Module::Build;

# try probing in places where we expect it to be
my $mecab_config;
foreach my $path qw(/usr/bin /usr/local/bin) {
    my $tmp = File::Spec->catfile($path, 'mecab-config');
    if (-f $tmp && -x _) {
        $mecab_config = $tmp;
        last;
    }
}

if (my $tmp = Module::Build->prompt("Path to mecab config? [$mecab_config]")) {
    $mecab_config = $tmp;
}

if (!-f $mecab_config || ! -x _) {
    print STDERR "Can't proceed without mecab-config. Aborting...\n";
    exit 1;
}

my $cflags = `$mecab_config --cflags`;
chomp($cflags);
print "Using compiler flags '$cflags'...\n";

my $libs   = `$mecab_config --libs`;
chomp($libs);
print "Using linker flags '$libs'...\n";

my $build = Module::Build->new(
    dist_name => 'Text-MeCab',
    dist_version_from => 'lib/Text/MeCab.pm',
    extra_compiler_flags => [ split(/\s+/, $cflags) ],
    extra_linker_flags  => [ split(/\s+/, $libs) ],
    license => 'perl',
    create_readme => 1,
    create_makefile_pl => 'traditional'
);
$build->create_build_script;