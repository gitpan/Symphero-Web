#!/usr/bin/perl -w
use strict;

##
# File version
#
use vars qw($VERSION);
($VERSION)=(q$Id: Defaults.PL,v 1.5 2001/03/14 02:42:01 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Reading $homedir
#
my $homedir;
my $version;
open(F,".config") || die "Can't open .config: $!\n";
while(<F>)
 { next unless /^(\w+)\s+(.*?)[\s\r\n]+$/s;
   my ($cmd,$value)=($1,$2);
   if($cmd eq 'homedir')
    { $homedir=$value;
    }
   elsif($cmd eq 'version')
    { $version=$value;
    }
 }
close(F);
die "Bad .config data!\n" unless $homedir && $version;

##
# Generating output Defaults.pm file
#
my $outfile=shift(@ARGV);
die "No output file given!\n" unless $outfile;
open(F,"> $outfile") || die "Can't open $outfile: $!\n";
print F <<EOT;
####################################################################
###### THIS IS AUTOMATICALLY GENERATED FILE -- DO NOT EDIT IT ######
########## RE-INSTALL Symphero::Web PACKAGE TO UPDATE IT ###########
####################################################################
package Symphero::Defaults;
use strict;
require Exporter;

use vars qw(\@ISA \@EXPORT_OK \@EXPORT \$VERSION
            \$homedir \$projectsdir \$version);

\@ISA=qw(Exporter);
\@EXPORT_OK=qw(\$homedir \$projectsdir);
\@EXPORT=();

##
# Symphero::Web package version
#
\$version='$version';

##
# Home directory of Symphero supporting files
#
\$homedir='$homedir';

##
# Root directory for all projects
#
\$projectsdir='$homedir/projects';

##
# File version (almost useless, for uniformness)
#
\$VERSION='$VERSION';

##
# That's it.
#
1;
EOT
close(F);
exit(0);
