##
# Generic footer. Pretty pointless object, just to give an idea that you
# can use common names like Footer/Header and so on for objects and make
# them do something useful.
#
package Symphero::Objects::Footer;
use strict;
use Symphero::Defaults;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying footer.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  $args->{path}='/bits/page-footer';
  $args->{VERSION}=$Symphero::Defaults::version;
  $args->{COPYRIGHT}='Copyright (C) 2000,2001 Brave New Worlds, Inc.';
  $self->SUPER::display($args);
}

##
# That's it
#
1;
