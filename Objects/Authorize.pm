##
# Basic authorization object.
#
# Usage to check authorization (presence and correctness of
# authorization cookie):
#  <%Authorize mode="check" failure="/bits/auth-failure" timeout="20"%>
#
# Usage in soft-authorization pages:
#  <%Authorize%>
#
# Usage in login scripts or hard-authorize pages:
#  <%Authorize mode="check" form="/login-template" success="/page-text"%>
#
# Usage in logout script:
#  <%Authorize mode="logout"%>
#
# Has no meaning outside site context, uses site's dbh handler and
# on successfull authorization check puts tied user data hash into
# $config{userdata} for that site. Other modules can use that data. No
# modifications allowed by default!
#
package Symphero::Objects::Authorize;
use strict;
use Symphero::Utils;
use Symphero::UsersDB;;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Displaying authorization page or check.
#
sub display ($%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Checking operational mode
  #
  my $mode=$args->{mode} || 'check';
  if($mode eq "logout")
   { $self->auth_logout($args);
   }
  elsif(!$mode || $mode eq "check")
   { $self->auth_check($args);
   }
  elsif(!$mode || $mode eq "chpass")
   { $self->auth_chpass($args);
   }
  else
   { eprint ref($self),"::display - unknown mode=$mode";
     return;
   }
}

##
# Checking authorization. May be used for working with login form and
# for checking authorization after user has logged in.
#
#  logname => optional logname, taken from cookie
#  password => optional password, taken from CGI params
#  failure => template path to display on failure.
#  failure.template => template text to display on failure.
#  success => template path to display on success.
#  success.failure => template text to display on success.
#  timeout => timeout for member cookie in minutes, default is 20m.
#  cookie_logname => name of cookie with logname, default is "logname".
#  cookie_mkey => name of cookie with member key, default is "mkey".
#  no_cgi_params => if true then it does not check cgi-params
#  table => table name, default is "Users".
#
# If no failure path is set then authorization status may be checked by
# presence of logname and userdata in site configuration. May be used for
# "soft" checks - when no authorization is required, but page behaviour
# may be different for a logged user and a visitor.
#
sub auth_check ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;

  ##
  # Checking if we are already logged in
  #
  my $config_userdata=$args->{config_userdata} || 'userdata';
  my $config_logname=$args->{config_logname} || 'logname';
  if(defined($config->get($config_userdata)))
   { my $obj=$self->object;
     $obj->display( path	=> $args->{'success.path'} || $args->{'success'}
                  , template	=> $args->{'success.template'}
                  , LOGNAME	=> $config->get($config_logname)
                  ) if $args->{'success'} || $args->{'success.path'} || $args->{'success.template'};
     return;
   }

  ##
  # Cookie names
  #
  my $cookie_logname=$args->{cookie_logname} ||
                     $config->get("cookie_logname") ||
                     "logname";
  my $cookie_mkey=$args->{cookie_mkey} ||
                  $config->get("cookie_mkey") ||
                  "mkey";

  ##
  # Looking up login name, mkey, password and timeout.
  #
  my $cgi=$config->cgi;
  my $logname;
  my $password;
  if($args->{no_cgi_params})
   { $logname=lc($args->{logname} ||
                 $cgi->cookie(-name => $cookie_logname));
     $password=$args->{password};
   }
  else
   { $logname=lc($args->{logname} ||
                 $cgi->param('logname') ||
                 $cgi->cookie(-name => $cookie_logname));
     $password=$args->{password} ||
               $cgi->param('password');
   }
  my $mkey=$args->{mkey} ||
           $cgi->cookie(-name => $cookie_mkey);
  my $timeout=60*($args->{timeout} || $config->get("logon_timeout") || 20);

  ##
  # Checking if user has already logged on
  #
  my $obj=$self->object;
  my $errmsg='';
  if($logname && $mkey && !$cgi->param('logname'))
   { my $user=Symphero::UsersDB->new( dbh => $self->dbh
                                    , id => $logname
                                    , table => $args->{table});
     my $umkey=$user->get("mkey");
     my $atime=$user->get("atime") || 0;
     if(! $umkey)
      {
      }
     elsif($umkey ne $mkey)
      { $errmsg="Someone was already logged in under your name!";
        $config->add_cookie(-name    => $cookie_mkey
                           ,-value   => ''
                           ,-path    => '/'
                           ,-expires => "-1m");
      }
     elsif($atime+$timeout < time)
      { $user->delete("mkey");
        $errmsg="Your session was expired.";
        $config->add_cookie(-name    => $cookie_mkey
                           ,-value   => ''
                           ,-path    => '/'
                           ,-expires => "-1m");
      }
     else
      { dprint "Authorize: logname=$logname, time=",time," atime=$atime, delta=",$timeout-(time-$atime);
        $config->session_specific($config_userdata,$config_logname);
        $config->put($config_userdata => $user);
        $config->put($config_logname => $logname);

        ##
        # Only updating cookie and atime if at least 10 seconds passed
        # since last authorization.
        #
        if(time - $atime > 10)
         { $user->update(atime => time);
           $user->disallow_changes();

           ##
           # Updating cookie with the mkey. Cookie will be send out by symphero.pl
           #
           $config->add_cookie(-name    => $cookie_logname
                              ,-value   => $logname
                              ,-path    => '/'
                              ,-expires => '+3y');
           $config->add_cookie(-name    => $cookie_mkey
                              ,-value   => $mkey
                              ,-path    => '/'
                              ,-expires => "+$timeout");
         }

        ##
        # Displaying success template if required.
        #
        $obj->display( path	=> $args->{'success.path'} || $args->{success}
                     , template	=> $args->{'success.template'}
                     , LOGNAME	=> $logname
                     , MKEY	=> $mkey
                     ) if $args->{success} || $args->{'success.path'} || $args->{'success.template'};
        return;
      }
   }

  ##
  # Checking username/password if entered
  #
  my $path;
  if($logname && $password)
   { my $user=Symphero::UsersDB->new( dbh => $self->dbh
                                    , id => $logname
                                    , table => $args->{table});
     if(! $user->valid)
      { $errmsg="No such user exists, please check your logname!";
      }
     elsif(! $user->check_password($password))
      { $errmsg="Incorrect password!";
      }
     else
      { $errmsg=$self->auth_check_final(user => $user);
      }

     ##
     # Checking for error. Setting cookies and redirecting to success
     # page if everything is ok.
     #
     if(! $errmsg)
      { $mkey=generate_key($logname);
        $user->put(mkey => $mkey);
        $user->put(atime => time);
        $config->session_specific($config_userdata,$config_logname);
        $config->put($config_userdata => $user);
        $config->put($config_logname => $logname);

        ##
        # Setting cookies
        #
        $config->add_cookie(-name    => $cookie_logname
                           ,-value   => $logname
                           ,-path    => '/'
                           ,-expires => '+3y');
        $config->add_cookie(-name    => $cookie_mkey
                           ,-value   => $mkey
                           ,-path    => '/'
                           ,-expires => "+$timeout");
        my $path=$args->{'logged.path'} || $args->{'logged'} ||
                 $args->{'success.path'} || $args->{success};
        my $template=$args->{'logged.template'} || $args->{'success.template'};
        $obj->display( path    => $path
                     , template	=> $template
                     , LOGNAME => $logname
                     , BASEURL => $config->get('base_url')
                     , PAGEURL => $self->pageurl(secure => $args->{secure})
                     , MKEY	=> $mkey
                     ) if $path || $template;
        return;
      }
   }

  ##
  # Displaying failure template (login form) if required
  #
  if($args->{failure} || $args->{'failure.path'} || $args->{'failure.template'})
   { $obj->display( path     => $args->{'failure.path'} || $args->{failure}
                  , template => $args->{'failure.template'}
                  , ERRSTR   => $errmsg || ""
                  , LOGNAME  => $logname || ""
                  , PAGEURL => $self->pageurl(secure => $args->{secure})
                  );
   }
}

##
# Final site-specific user authorization check. Called after user
# password and everything else are already checked.
# Arguments are:
#  user => user database reference
#  objargs => object arguments
#
# Should return error text on error.
#
sub auth_check_final ($%)
{ '';
}

##
# Logging user out.
#
#  cookie_logname => name of cookie with logname, default is "logname".
#  cookie_mkey => name of cookie with member key, default is "mkey".
#  table => table name, default is "Users".
#
sub auth_logout ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $cookie_logname=$args->{cookie_logname} || "logname";
  my $cookie_mkey=$args->{cookie_mkey} || "mkey";
  my $config=$self->{siteconfig};
  my $cgi=$config->cgi;
  my $logname=$cgi->cookie(-name=>$cookie_logname);
  my $mkey=$cgi->cookie(-name=>$cookie_mkey);
  dprint "Authorize::auth_logout logname=|$logname|";

  ##
  # Checking correctness of cookie, time and so on..
  #
  if(defined($logname) && $mkey)
   { my $user=Symphero::UsersDB->new( dbh => $self->dbh
                                    , id => $logname
                                    , table => $args->{table});
     $user->delete("mkey");
     $user->delete("atime");
     $config->add_cookie(-name    => $cookie_mkey
                        ,-value   => ''
                        ,-path    => '/'
                        ,-expires => "-1m");
   }
}

##
# The same functionality should be removed from UserAccount.pm!!
#
# Changes password. Arguments are:
#  form => path to the form template.
#  success => path to the template displayed after successful change.
#  id => user id, default is the user currently logged in.
#  checkold => check old password if set
#
# Form should have the following parameters:
#  oldpass => current password
#  newpass1 => new password
#  newpass2 => new password, second copy
#
sub auth_chpass ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my $udb=$self->get_user_db($args);
  my $config=$self->{siteconfig};
  my $cgi=$config->cgi;

  ##
  # Form already filled?
  #
  my $errstr;
  my $oldpass=$cgi->param('oldpass');
  if($args->{checkold})
   { my $newpass1=$cgi->param('newpass1');
     my $newpass2=$cgi->param('newpass2');
     if(defined($oldpass) && ! $udb->check_password($oldpass))
      { $errstr="Current password is not correct!";
        $oldpass='';
      }
     elsif(defined($newpass1))
      { if(length($newpass1) < 5)
         { $errstr="Password is too short!";
         }
        elsif($newpass1 ne $newpass2)
         { $errstr="Password copies mismatch!";
         }
        else
         { my $path=$args->{success};
           $path || throw Symphero::Errors::Page
                          ref($self)."::change_password - no 'success' path given";
           $udb->set_password($newpass1);
           $self->object->display(path => $args->{success}, ID => $udb->id);
           return;
         }
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
sub get_user_db ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $id=$args->{id};
  my $udb;
  if(!$id)
   { $udb=$self->siteconfig->get($args->{config_userdata} || 'userdata');
     $udb || throw Symphero::Errors::Page
                   ref($self)."::get_user_db - no id and no authorized user";
     $id=$udb->id;
   }
  $udb=Symphero::UsersDB->new(dbh => $self->dbh, id => $id, table => $args->{table});
  $udb->valid || throw Symphero::Errors::Page
                       ref($self)."::get_user_db - bad user db, id=$id";
  $udb;
}

##
# That's it
#
1;
