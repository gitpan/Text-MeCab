#!perl
# $Id: probe_mecab.pl 11 2006-05-07 16:38:07Z daisuke $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use File::Spec;

my $interactive = -t STDIN && (-t STDOUT || !(-f STDOUT || -c STDOUT)) ;
my($version, $cflags, $libs);
# Save the poor puppies that run on Windows
if ($^O eq 'MSWin32') {
    print <<EOM;
You seem to be running on an environment that may not have mecab-config
available. This script uses mecab-config to auto-probe 
  1. The version string of libmecab that you are building Text::MeCab
     against. (e.g. 0.90)
  2. Additional compiler flags that you may have built libmecab with, and
  3. Additional linker flags that you may have build libmecab with.

Since we can't auto-probe, you should specify the above three to proceed
with compilation:
EOM

    print "Version of libmecab that you are compiling against (required)? [] ";
    $version = <STDIN>;
    chomp($version);
    die "no version specified!" unless $version;

    print "Additional compiler flags? [] ";
    if ($interactive) {
        $cflags = <STDIN>;
        chomp($cflags);
    }

    print "Additional linker flags? [] ";
    if ($interactive) {
        $libs = <STDIN>;
        chomp($cflags);
    }
} else {
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
    
    $version = `$mecab_config --version`;
    chomp $version;

    $cflags = `$mecab_config --cflags`;
    chomp($cflags);

    $libs   = `$mecab_config --libs`;
    chomp($libs);
}

print "detected mecab version $version\n";
if ($version < 0.90) {
    print " + mecab version < 0.90 doesn't contain some of the features\n",
          " + that are available in Text::MeCab. Please read the documentation\n",
          " + carefully before using\n";
}

my($major, $minor, $micro) = map { s/\D+//g; $_ } split(/\./, $version);
$cflags .= " -DMECAB_MAJOR_VERSION=$major -DMECAB_MINOR_VERSION=$minor";
print "Using compiler flags '$cflags'...\n";
print "Using linker flags '$libs'...\n";

return { cflags => $cflags, libs => $libs };