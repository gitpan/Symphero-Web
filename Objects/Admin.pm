##
# Administrator web-based shell. Supposed to be overriden in derived
# classes.
#
package Symphero::Objects::Admin;
use strict;
use Symphero::Utils;
use Symphero::Objects;
use Symphero::Templates;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Action');

##
# Processing standard commands. Called from derived object as a last step.
#
# Standard commands are:
#  mode="auth-check" (Authorize mode=check arguments)
#  mode="auth-logout" (Authoize mode=logout arguments)
#  mode="edit-content" name="content-name" path="xxx"
#
sub check_mode ($$)
{ my $self=shift;
  my $args=get_args(\@_);
  my $mode=$args->{mode};
  if($mode eq "auth-check")
   { $self->auth_check($args);
   }
  elsif($mode eq "auth-logout")
   { $self->auth_logout($args);
   }
  elsif($mode eq "auth-chpass")
   { $self->auth_chpass($args);
   }
  elsif($mode eq "user-data")
   { $self->user_data($args);
   }
  elsif($mode eq "site-map")
   { $self->site_map($args);
   }
  elsif($mode eq "edit-page")
   { $self->edit_page($args);
   }
  elsif($mode eq "edit-object")
   { $self->edit_object($args);
   }
  elsif($mode eq "edit-content")
   { $self->edit_content($args);
   }
  else
   { throw Symphero::Errors::Page ref($self)."::check_mode - unknown mode=$mode";
   }
}

##
# Checking authorization
#
sub auth_check ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  $args->{table}="Admins";
  $args->{config_userdata}="admdata";
  $args->{config_logname}="admname";
  $args->{cookie_logname}="admname";
  $args->{cookie_mkey}="admkey";
  $args->{mode}="check";
  $self->object(objname => "Authorize")->display($args);
}

##
# Changing password.
#
sub auth_chpass ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  $args->{table}="Admins";
  $args->{config_userdata}="admdata";
  $args->{config_logname}="admname";
  $args->{cookie_logname}="admname";
  $args->{cookie_mkey}="admkey";
  $args->{mode}="chpass";
  $self->object(objname => "Authorize")->display($args);
}

##
# Logging out
#
sub auth_logout ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  $args->{table}="Admins";
  $args->{config_userdata}="admdata";
  $args->{config_logname}="admname";
  $args->{cookie_logname}="admname";
  $args->{cookie_mkey}="admkey";
  $args->{mode}="logout";
  $self->object(objname => "Authorize")->display($args);
}

##
# Displaying piece of data from admin configuration
#
sub user_data ($%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Makes sense only in site context and with user data already
  # initialized.
  #
  my $config=$self->siteconfig;
  my $userdata=$config->get('admdata');
  if(!$userdata)
   { eprint ref($self),"::user_data - no user data loaded (sitename=$self->{sitename})";
     return;
   }

  ##
  # Looking what to display
  #
  if(!$args->{var})
   { eprint ref($self),"::user_data - no variable name given";
     return;
   }
  my $value=$userdata->get($args->{var});
  $value=$userdata->get($args->{var1}) if !defined($value) && $args->{var1};
  $value=$userdata->get($args->{var2}) if !defined($value) && $args->{var2};
  $value=$userdata->get($args->{var3}) if !defined($value) && $args->{var3};
  $value=$userdata->get($args->{var4}) if !defined($value) && $args->{var4};
  $value=$args->{default} if !defined($value) && defined($args->{default});
  $value='' if !defined($value);

  ##
  # Printing
  #
  $self->textout(text => $value, objargs => $args);
}

##
# Showing complete site map, all pages and building blocks
#
sub site_map ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $list=Symphero::Templates::list(sitename => $self->{sitename});
  my $obj=$self->object;
  foreach my $file (sort @{$list})
   { $obj->display(path => $args->{path},
                   template => $args->{template},
                   PAGEPATH => $file
                  );
   }
}

##
# Editing page
#
sub edit_page ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $pagepath=$args->{pagepath} || $self->{siteconfig}->cgi->param("pagepath");
  my $page=$self->parse(path => $pagepath);
  if(!$page)
   { eprint "No page to edit";
     return;
   }
  my $editurl=$args->{editurl} || "editobj.html";
  my $pageobj=$self->object;
  for(my $i=0; $i!=@{$page}; $i++)
   { my $obj=$page->[$i];
     next unless defined $obj->{objname};
     my $object=$self->object(objname => $obj->{objname});
     my $editable=$object && $object->editable($obj->{args});
     my $argtext;
     foreach my $arg (sort keys %{$obj->{args}})
      { $argtext.=" " if $argtext;
        $argtext.=qq($arg="$obj->{args}->{$arg}");
      }
     $pageobj->display(path => $args->{path},
                       template => $args->{template},
                       OBJLINK => $editable
                                  ? "<A HREF=\"$editurl?pagepath=$pagepath&objnum=$i\">$obj->{objname}</A>"
                                  : $obj->{objname},
                       OBJNAME => $obj->{objname},
                       OBJARGS => $argtext,
                       OBJNUM => $i,
                       PAGEPATH => $pagepath
                      );
   }
}

##
# Editing object properties
#
sub edit_object ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $pagepath=$args->{pagepath} || $self->{siteconfig}->cgi->param("pagepath");
  my $objnum=$args->{objnum} || $self->{siteconfig}->cgi->param("objnum");
  if(!$pagepath)
   { eprint "No pagepath";
     return;
   }
  my $page=$self->parse(path=>$pagepath);
  my $objdesc=$page->[$objnum];
  if(!$objdesc->{objname})
   { eprint "Not object, pagepath=$pagepath, objnum=$objnum";
     return;
   }
  my $obj=$self->object(objname => $objdesc->{objname});
  if(!$obj)
   { eprint "Can't load object for editing";
     return;
   }
  if(!$obj->editable($objdesc->{args}))
   { $self->SUPER::display(template => "This object has no editable properties");
     return;
   }
  return $obj->edit(pagepath => $pagepath,
                    objnum => int($objnum),
                    objargs => $objdesc->{args});
}

##
# Editing page content via Content object. Does not have to know where it
# is referred from.
#
sub edit_content ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $obj=$self->object(objname => 'Content');
  my $name=$args->{name};
  throw Symphero::Errors::Page ref($self)."::edit_content - No 'name' given" unless $name;
dprint $name;
  $obj->edit($args);
}

##
# That's it
#
1;
