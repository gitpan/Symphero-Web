##
# This is object loader.
#
package Symphero::Objects;
use strict;
use Symphero::Defaults qw($homedir $projectsdir);
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Prototypes
#
sub load ($%);
sub new ($%);

##
# Module version.
#
use vars qw($VERSION);
($VERSION)=(q$Id: Objects.pm,v 1.2 2001/03/01 02:48:13 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Loads object into memory.
#
# It first looks into site directory for object package, then into
# Symphero objects directory. If found - loads and creates object,
# otherwise returns undef.
#
# It's assumed that standard objects are in Symphero::Objects::
# namespace and site overriden objects are in sitename::Objects::
# namespace.
#
# On success returns class name of the loaded object.
#
# Arguments:
#  objname => object name.
#  baseobj => ignore site specific objects even if they exist.
#
my %objref_cache;
sub load ($%)
{ my $class=shift;
  my $args=get_args(\@_);
  my $objname=$args->{objname} || "Page";
  my $sitename=get_site_name();

  ##
  # Checking cache first
  #
  return $objref_cache{$sitename}->{$objname} if exists($objref_cache{$sitename}) && exists($objref_cache{$sitename}->{$objname});
  return $objref_cache{'/'}->{$objname} if exists($objref_cache{'/'}) && exists($objref_cache{'/'}->{$objname});

  ##
  # Checking project directory
  #
  my $objfile;
  my $objref;
  my $system;
  if(!$args->{baseobj} && defined($sitename))
   { $objfile="$projectsdir/$sitename/objects/$objname.pm";
     $objref="Symphero::Objects::${sitename}::${objname}" if -r $objfile;
     $system=0;
   }
  if(! $objref)
   { $objfile="Symphero::Objects::${objname}";
     $objref="Symphero::Objects::${objname}";
     $system=1;
   }

dprint "objref=$objref, objfile=$objfile";

  ##
  # This should be handled better, for example by returning ErrorPage
  # object reference. Or some other guaranteed to exist object.
  #
  $objref || throw Symphero::Errors::Objects
                   "No object file found for sitename=$sitename, objname=$objname";

  ##
  # Fetching object in
  #
  if(! $INC{$objfile})
   { if($system)
      { eval "require $objfile";
      }
     else
      { eval { require $objfile };
      }
     $@ && throw Symphero::Errors::Objects
                 "Error fetching object for $objref ($objfile) -- $@";
   }

  ##
  # Returning class name and storing into cache
  #
  $objref_cache{$system ? '/' : $sitename}->{$objname}=$objref;
}

##
# Creates instance of named object. Arguments are the same as for load().
#
# When it first found an object it makes an extra instance of it and places
# it into cache. Then it creates new objects "on it" if it available. Should
# speed thing up because it avoids `eval'.
#
my %obj_cache;
sub new ($%)
{ my $class=shift;
  my $args=get_args(\@_);

  ##
  # First trying the cache
  #
  my $objname=$args->{objname} || "Page";
  my $sitename=get_site_name();
  my $proto=$obj_cache{$sitename.':'.$objname};
  return $proto->new($args) if $proto;

  ##
  # Not found, now the real thing.
  #
  my $objref=$class->load($args);
  return undef unless $objref;

  ##
  # Creating instance of that object
  #
  my $obj=eval $objref.'->new($args)';
  $obj || throw Symphero::Errors::Objects
                "Error creating instance of $objref -- $@";

  ##
  # Storing extra object into the cache
  #
  $obj_cache{$sitename.':'.$objname}=$obj->new();
  $obj;
}

##
# Error to be thrown from Symphero::Objects
##
package Symphero::Errors::Objects;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
