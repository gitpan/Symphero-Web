##
# Users database.
#
package Symphero::UsersDB;
use strict;
use Digest::MD5 qw(md5_base64);
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Inheritance.
#
use Symphero::MultiValueDB;
use vars qw(@ISA);
@ISA=qw(Symphero::MultiValueDB);

##
# Methods:
#
sub new ($%);
sub set_password ($$);
sub check_password ($$);
sub status_code ($$);
sub status_name ($$);
sub status_codes_list ();

##
# Creating instance.
#
sub new ($%)
{ my $proto=shift;
  my %args=@_;
  $args{table}="Users" unless $args{table};
  $proto->SUPER::new(%args);
}

##
# Sets new password without any checks.
#
sub set_password ($$)
{ my $self=shift;
  my $password=shift;
  defined($password) || throw Symphero::Errors::Page
                              ref($self)."::set_password - no password given";
  my $old=$self->allow_changes;
  $self->put(password => md5_base64($password));
  $self->allow_changes($old);
}

##
# Checks password. Returns boolean true if the password is correct.
#
sub check_password ($$)
{ my $self=shift;
  my $npt=shift;
  md5_base64($npt) eq $self->get("password");
}

##
# Retrieves or sets user status
#
sub status_code ($$)
{ my $self=shift;
  my $code=shift;
  if(defined($code))
   { my $old=$self->allow_changes;
     $self->put(status => $code);
     $self->allow_changes($old);
     return $code;
   }
  $self->get("status");
}

##
# Default user statuses. May be overriden in site configuration.
#
my %user_status_table=( 0 => "Inactive"
                      , 1 => "Active"
                      );

##
# Status name by given code
#
sub status_name ($$)
{ my $self=shift;
  my $code=shift;
  $code=$self->get("status") unless defined $code;
  my $siteconfig=get_site_config();
  my $table=$siteconfig && $siteconfig->get("user_status_table")
            ? $siteconfig->get("user_status_table")
            : \%user_status_table;
  $table->{$code};
}

##
# List of statuses
#
sub status_codes_list ()
{ my $siteconfig=get_site_config();
  my $table=$siteconfig && $siteconfig->get("user_status_table")
            ? $siteconfig->get("user_status_table")
            : \%user_status_table;
  keys %{$table};
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=(q$Id: UsersDB.pm,v 1.1 2001/02/27 04:06:15 amaltsev Exp $ =~ /(\d+\.\d+)/);
1;
