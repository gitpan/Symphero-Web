##
# This is the default default page handler :)
# It is called when there is no template for the given path and there is
# no path-to-object mapping defined for this path.
#
# Feel free to override it per-site to make it do something more useful
# then just displaying 404 error message.
#
package Symphero::Objects::Default;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Argument is path.
#
sub display ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;
  $config->header_args(-Status => '404 File not found');
  $self->SUPER::display(path => '/bits/errors/file-not-found',
                        FILEPATH => $args->{path} || '');
}

##
# That's it
#
1;
