##
# Managing user account. Not so much here, most of real functionality is
# site specific.
#
package Symphero::Objects::UserAccount;
use strict;
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Action');

##
# Processing standard commands. Called from derived object as a last step.
#
# Standard commands are:
#  mode="change-password" form="form-path" success="success-path"
#
sub check_mode ($$)
{ my $self=shift;
  my $args=get_args(\@_);
  my $mode=$args->{mode};
  if($mode eq "change-password")
   { $self->change_password($args);
   }
  else
   { throw Symphero::Errors::Page ref($self)."::check_mode - unknown mode=$mode";
   }
}

##
# Changes password. Arguments are:
#  form => path to the form template.
#  success => path to the template displayed after successful change.
#  id => user id, default is the user currently logged in.
#
# Form should have the following parameters:
#  oldpass => current password, only checked if present!
#  newpass1 => new password
#  newpass2 => new password, second copy
#
sub change_password ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my $udb=$self->get_user_db($args->{id});
  my $cgi=$self->{siteconfig}->cgi;

  ##
  # Form already filled?
  #
  my $errstr;
  my $oldpass=$cgi->param('oldpass');
  if(defined($oldpass) || defined($cgi->param('newpass1')))
   { my $newpass1=$cgi->param('newpass1');
     my $newpass2=$cgi->param('newpass2');
     if(defined($oldpass) && ! $udb->check_password($oldpass))
      { $errstr="Current password is not correct!";
        $oldpass='';
      }
     elsif($newpass1 ne $newpass2)
      { $errstr="Password copies mismatch!";
      }
     elsif(length($newpass1) < 5)
      { $errstr="Password is too short!";
      }
     else
      { my $path=$args->{success};
        $path || throw Symphero::Errors::Page
                       ref($self)."::change_password - no 'success' path given";
        $udb->set_password($newpass1);

        ##
        # Doing something site specific with clear text password
        #
        $self->change_password_ctp(id => $args->{id}, password => $newpass1, udb => $udb);

        ##
        # Displaying results..
        #
        $self->object->display(path => $args->{success}, ID => $udb->id);
        return;
      }
   }

  ##
  # Displaying the form.
  #
  my $path=$args->{form};
  $path || throw Symphero::Errors::Page
                 ref($self)."::change_password - no 'form' path given";
  $self->object->display( path => $path
                        , ID => $udb->id
                        , OLDPASS => $oldpass || ""
                        , ERRSTR => $errstr || ""
                        );
}

##
# Returns user database reference for given ID or for currently
# authorized user. Does not return stored user database reference,
# creates new with the same user id.
#
sub get_user_db ($$)
{ my $self=shift;
  my $id=shift;
  my $udb;
  if(!$id)
   { $udb=get_site_config()->get("userdata");
     $udb || throw Symphero::Errors::Page
                   ref($self)."::get_user_db - no id and no authorized user";
     $id=$udb->id;
   }
  $udb=Symphero::UsersDB->new(dbh => $self->dbh, id => $id);
  $udb->valid || throw Symphero::Errors::Page
                       ref($self)."::get_user_db - bad user db, id=$id";
  $udb;
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=(q$Id: UserAccount.pm,v 1.1 2001/02/27 04:06:15 amaltsev Exp $ =~ /(\d+\.\d+)/);
1;
