##
# This package contains persistent hash of site configurations and other
# site-specific data.
#
# For more detailed information refer to the corresponding section of
# the Symphero 4.0 Design document.
#
package Symphero::SiteConfig;
use strict;
use Carp;
use Symphero::Utils;
use DBI;
use Error;

##
# Static methods.
#
sub new ($$);
sub find ($$);
sub get_site_name ();
sub get_site_config ();
sub set_current ($);
#
# Private methods
#
sub _data ($);
#
# Configuration object specific methods additional to derived from
# SimpleHash.
#
sub add_cookie ($@);
sub cgi ($$);
sub cleanup ($);
sub cookies ($);
sub dbconnect ($%);
sub dbh ($$);
sub disable_special_access ($);
sub enable_special_access ($);
sub header ($@);
sub header_args($@);
sub init ($);
sub session_specific ($@);
sub sitename ($);

##
# Package version for checks and reference
#
use vars qw($VERSION);
($VERSION)=(q$Id: SiteConfig.pm,v 1.1 2001/02/27 04:06:15 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Deriving form SimpleHash and Exporter
#
use Symphero::SimpleHash;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA=qw(Symphero::SimpleHash Exporter);
@EXPORT=qw(get_site_name get_site_config);

##
# Container for all individual site configurations, each of those is
# SimpleHash object.
#
use vars qw(%data_objects);

##
# Creates and blesses new configuration object with given site name.
#
sub new ($$)
{ my ($proto,$sitename)=@_;
  return $data_objects{$sitename} if $data_objects{$sitename};

  ##
  # What class we actually are?
  #
  my $class=ref($proto) || $proto;
  carp "$class is Symphero::SiteConfig which is strange" if $class eq "Symphero::SiteConfig";

  ##
  # A bit of magic here to create an instance of SimpleHash so that it
  # will think it is an instance of Symphero::SiteConfig.
  #
  my $self=Symphero::SimpleHash::new($class);
  $data_objects{$sitename}=$self;

  ##
  # Pre-filling the hash
  #
  $self->fill(sitename => $sitename
             ,_data => { crtime => time
                       , class => $class
                       }
             );

  ##
  # This is supposed to be overriden in every site config
  #
  $self->init();
  $self;
}

##
# Looks into pre-initialized configurations list and returns object if
# found.
#
sub find ($$)
{ my ($class,$sitename)=@_;
  $data_objects{$sitename};
}

##
# Returns internal data hash, not to be called from outside
#
sub _data ($)
{ my $self=shift;
  $self->get("_data");
}

##
# Configuration object methods
##

##
# Current site configuration is stored here.
#
my $current_site_config;

##
# Retrieving current site name
#
sub get_site_name ()
{ $current_site_config ||
   throw Symphero::Errors::SiteConfig "get_site_name() called before site has been defined";
  $current_site_config->sitename;
}

##
# Retrieving current site name
#
sub get_site_config ()
{ $current_site_config;
}

##
# Sets default configuration to current one.
#
sub set_current ($)
{ my $self=shift;
  unless($self && ref($self))
   { carp "SiteConfig::set_current must be called on reference";
     return;
   }
  $current_site_config=$self;
}

##
# Dummy initialization subroutine. Supposed to be overriden.
#
sub init ($)
{ my $self=shift;
  carp ref($self),"::init - pure virtual function called";
}

##
# Adding cookie into internal list. If there is only one parameter we
# assume it is already encoded cookie, otherwise we assume it is a hash
# of parameters for $cgi->cookie method.
#
sub add_cookie ($@)
{ my $self=shift;
  my $cookie;
  if(@_ == 1)
   { $cookie=shift;
   }
  else
   { $cookie=get_args(\@_);
   }
  
  ##
  # If new cookie has the same name, domain and path
  # as previously set one - we replace it. Works only for
  # cookies stored as parameters, unprepared.
  #
  if($self->_data->{cookies} && ref($cookie) && ref($cookie) eq 'HASH')
   { for(my $i=0; $i!=@{$self->_data->{cookies}}; $i++)
      { my $c=$self->_data->{cookies}->[$i];
        next unless ref($c) && ref($c) eq 'HASH';
        next unless $c->{-name} eq $cookie->{-name} &&
                    $c->{-path} eq $cookie->{-path} &&
                    $c->{-domain} eq $cookie->{-domain};
        $self->_data->{cookies}->[$i]=$cookie;
        return $cookie;
      }
   }
  push @{$self->_data->{cookies}},$cookie;
}

##
# Return or sets CGI object
#
sub cgi ($$)
{ my ($self,$newcgi)=@_;
  my $data=$self->_data;
  return $data->{cgi} unless $newcgi;
  if($data->{special_access})
   { $data->{cgi}=$newcgi;
     return $newcgi;
   }
  throw Symphero::Errors::SiteConfig "$data->{class}::cgi() Storing new CGI requires allow_special_access()";
}

##
# Return or sets database handler
#
sub dbh ($$)
{ my ($self,$newdbh)=@_;
  my $data=$self->_data;
  return $data->{dbh} unless $newdbh;
  if($data->{special_access})
   { $data->{dbh}=$newdbh;
     return $newdbh;
   }
  carp "$data->{class}::dbh() Storing new DBH requires allow_special_access()";
  undef;
}

##
# Returns sitename, the same as $config->{sitename}
#
sub sitename ($)
{ my $self=shift;
  $self->get("sitename");
}

## 
# Adding names of temporary values to be purged.
#
sub session_specific ($@)
{ my $self=shift;
  push(@{$self->_data->{session_specific}},@_);
}

##
# Cleaning up. All session specific values are cleaned. Cleans also
# cookies and CGI.
#
sub cleanup ($)
{ my $self=shift;
  my $data=$self->_data;
  delete $data->{cgi};
  delete $data->{cookies};
  delete $data->{header_printed};
  delete $data->{header_args};
  delete $data->{special_access};
  foreach my $key (@{$data->{session_specific}})
   { $self->delete($key);
   }
  $current_site_config=undef;
}

##
# Returns reference to the array of prepared cookies.
#
sub cookies ($)
{ my $self=shift;
  my @baked;
  foreach my $c (@{$self->_data->{cookies}})
   { if(ref($c) && ref($c) eq 'HASH')
      { push @baked,$self->cgi->cookie(%{$c});
      }
     else
      { push @baked,$c;
      }
   }
  \@baked;
}

##
# Enables use of dbh and cgi to set values. Foolproof.
#
sub enable_special_access ($)
{ my $self=shift;
  $self->_data->{special_access}=1;
}

##
# Disables use of dbh and cgi to set values. Foolproof.
#
sub disable_special_access ($)
{ my $self=shift;
  delete $self->_data->{special_access};
}

##
# Returns HTTP header. The same as $cgi->header and accepts the same
# parameters. Pre-added cookies are included.
#
# Prints header only once, un subsequent calls returns undef.
#
# *** In mod_perl CGI will send the header itself and return empty
# *** string. Be carefull to check the result for "if(defined($header))"
# *** instead of just "if($header)"
#
sub header ($@)
{ my $self=shift;
  my $data=$self->_data;
  return undef if $data->{header_printed};
  $self->header_args(@_) if @_;
  $data->{header_printed}=1;
  $self->cgi->header(-cookie => $self->cookies,
                     %{$data->{header_args}}
                    );
}

##
# Sets some parameters for header generation. You can use it to change
# page status for example (see Default object for an example).
#
sub header_args ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $data=$self->_data;
  @{$data->{header_args}}{keys %{$args}}=values %{$args};
}

##
# Connecting to the database. Gets hash of arguments:
#  db_dsn => DSN (like DBI:mysql:database)
#  db_user => User name
#  db_pass => Password
# Puts these values into configuration `hash' also on success.
# Puts dbh into configuration data.
# Returns $dbh or undef.
#
sub dbconnect ($%)
{ my $self=shift;
  my %args=@_;
  my $dbh=DBI->connect($args{db_dsn},$args{db_user},$args{db_pass});
  throw Symphero::Errors::SiteConfig ref($self)."::dbconnect - can't connect to the database!" unless $dbh;
  $self->fill(\%args);
  $self->enable_special_access();
  $self->dbh($dbh);
  $self->disable_special_access();
  $dbh;
}

##
# Error package for MultiValueDB.
#
package Symphero::Errors::SiteConfig;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
