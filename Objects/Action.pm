##
# Very simple object with overridable check_mode method.
# Simplifies implementation of objects with arguments like:
#  <%Fubar mode="kick" target="ass"%>
#
package Symphero::Objects::Action;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Just calls check_mode if it is available. Everyting else is the
# same as for Page.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  return $self->check_mode($args) if $self->can('check_mode');
  $self->SUPER::display($args);
}

##
# That's it
#
1;
