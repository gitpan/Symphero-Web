##
# User variables displayer.
#
package Symphero::Objects::UserData;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying user variable content.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Makes sense only in site context and with user data already
  # initialized.
  #
  my $config=$self->{siteconfig};
  my $userdata=$config->get("userdata");
  if(!$userdata)
   { eprint ref($self),"::display - no user data loaded (sitename=$self->{sitename})";
     return;
   }

  ##
  # Looking what to display
  #
  if(!$args->{var})
   { eprint "Objects::UserData - no variable name given";
     return;
   }
  my $value=$userdata->get($args->{var});
  $value=$userdata->get($args->{var1}) if !defined($value) && $args->{var1};
  $value=$userdata->get($args->{var2}) if !defined($value) && $args->{var2};
  $value=$userdata->get($args->{var3}) if !defined($value) && $args->{var3};
  $value=$userdata->get($args->{var4}) if !defined($value) && $args->{var4};
  $value=$args->{default} if !defined($value) && defined($args->{default});
  $value='N/a' if !defined($value);

  ##
  # Printing
  #
  $self->textout(text => $value, objargs => $args);
}

##
# That's it
#
1;
