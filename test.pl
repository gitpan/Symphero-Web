# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
###########################################################################
use strict;

sub tprint ($$)
{ my ($name,$rc)=@_;
  print $name,'.' x (50-length($name)),".",$rc ? "ok" : "NOT OK","\n";
}

sub load_module ($)
{ my $module=shift;
  eval "use $module";
  my $err=$@;
  my $ver=$err ? 'BAD' : (eval ('$' . $module . '::VERSION') || 'BAD');
  tprint "$module<$ver>", ! $err;
  die $err if $err;
}

######################################################################
load_module 'Symphero::Defaults';

use Symphero::Defaults qw($homedir $projectsdir);

tprint "homedir", $Symphero::Defaults::homedir;
tprint "loc.homedir", $homedir;
tprint "projectsdir", $Symphero::Defaults::projectsdir;
tprint "loc.projectsdir", $projectsdir;
tprint "version<$Symphero::Defaults::version>", $Symphero::Defaults::version;

1;
