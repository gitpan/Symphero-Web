#!/usr/bin/perl -w
use strict;
use FindBin qw($Bin);

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
#!/usr/bin/perl
####################################################################
###### THIS IS AUTOMATICALLY GENERATED FILE -- DO NOT EDIT IT ######
############# SAY `make devsite' TO UPDATE IT INSTEAD ##############
####################################################################
use lib qw( $Bin/blib/lib $Bin/blib/arch/auto);
use Symphero::Utils;
Symphero::Utils::set_debug(1);
do '$Bin/blib/script/symphero.pl';
EOT
close(F);
chmod 0755,$outfile;
exit(0);
