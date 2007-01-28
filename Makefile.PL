#!perl
# $Id: /mirror/Text-MeCab/Makefile.PL 3083 2006-05-07T16:38:07.535690Z daisuke  $
#
# Copyright (c) 2006 Daisuke Maki <dmaki@cpan.org>
# All rights reserved.

use strict;
use ExtUtils::MakeMaker 6.25; # Avoid Build.PL bug

my $result = do 'tools/probe_mecab.pl';
die if $@;

$result->{cflags} ||= '';
$result->{cflags} .= ' -I src';

# Hack. I don't like the layout where .xs files are on the top level.
link("lib/Text/MeCab.xs", "MeCab.xs");
WriteMakefile
(
    'DISTNAME'     => 'Text-MeCab',
    'NAME'         => 'Text::MeCab',
    'VERSION_FROM' => 'lib/Text/MeCab.pm',
    'PREREQ_PM'    => {},
    'INSTALLDIRS'  => 'site',
    'LIBS'         => [ split(/\s+/, $result->{libs}) ],
    'CCFLAGS'      => $result->{cflags},
    'clean'        => { FILES => 'MeCab.xs' }
);
