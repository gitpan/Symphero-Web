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
sub load (%);
sub new ($%);

##
# Module version.
#
use vars qw($VERSION);
($VERSION)=(q$Id: Objects.pm,v 1.5 2001/03/14 02:42:01 amaltsev Exp $ =~ /(\d+\.\d+)/);

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
#  baseobj => ignore site specific objects even if they exist (optional).
#
my %objref_cache;
sub load (%)
{ my $class=(scalar(@_)%2 || ref($_[1]) ? shift(@_) : 'Symphero::Objects');
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
  my $objref;
  my $system;
  if(!$args->{baseobj} && defined($sitename))
   { (my $objfile=$objname) =~ s/::/\//sg;
     $objfile="$projectsdir/$sitename/objects/$objfile.pm";
     if(open(F,$objfile))
      { local $/;
        my $text=<F>;
        close(F);
        if($text =~ s{(package\s+Symphero::Objects)(::$objname\s*;)}
                     {${1}::${sitename}$2})
         { eval "\n# line 1 \"$objfile\"\n" . $text;
           throw Symphero::Errors::Objects
                 "Error loading $objname ($objfile) -- $@" if $@;
           $objref="Symphero::Objects::${sitename}::${objname}";
         }
        else
         { throw Symphero::Errors::Objects
                 "Package name is not Symphero::Objects::$objname in $objfile";
         }
      }
     $system=0;
   }
  if(! $objref)
   { $objref="Symphero::Objects::${objname}";
     eval "require $objref";
     throw Symphero::Errors::Objects "Error loading $objname ($objref) -- $@" if $@;
     $system=1;
   }

  ##
  # In case no object was found.
  #
  $objref || throw Symphero::Errors::Objects
                   "No object file found for sitename=$sitename, objname=$objname";

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
