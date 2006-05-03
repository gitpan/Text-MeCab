#!perl
# $Id$
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;

# try probing in places where we expect it to be
my $mecab_config;
foreach my $path qw(/usr/bin /usr/local/bin) {
    my $tmp = File::Spec->catfile($path, 'mecab-config');
    if (-f $tmp && -x _) {
        $mecab_config = $tmp;
        last;
    }
}

print "Path to mecab config? [$mecab_config] ";
my $tmp = <STDIN>;
chomp $tmp;
if ($tmp) {
    $mecab_config = $tmp;
}

if (!-f $mecab_config || ! -x _) {
    print STDERR "Can't proceed without mecab-config. Aborting...\n";
    exit 1;
}

my $version = `$mecab_config --version`;
chomp $version;
print "detected mecab version $version\n";
if ($version < 0.90) {
    print " + mecab version < 0.90 doesn't contain some of the features\n",
          " + that are available in Text::MeCab. Please read the documentation\n",
          " + carefully before using\n";
}

my($major, $minor, $micro) = split(/\./, $version);

my $cflags = `$mecab_config --cflags`;
chomp($cflags);

$cflags .= " -DMECAB_MAJOR_VERSION=$major -DMECAB_MINOR_VERSION=$minor";
print "Using compiler flags '$cflags'...\n";

my $libs   = `$mecab_config --libs`;
chomp($libs);
print "Using linker flags '$libs'...\n";

return { cflags => $cflags, libs => $libs };