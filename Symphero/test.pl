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
load_module "Symphero::Categories";

######################################################################
load_module "Symphero::Objects";

######################################################################
load_module "Symphero::OrdersDB";

######################################################################
load_module "Symphero::ProductsDB";

######################################################################
load_module "Symphero::SiteConfig";

######################################################################
load_module "Symphero::Templates";

######################################################################
load_module "Symphero::UsersDB";

1;
