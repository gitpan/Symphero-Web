##
# Retrieves parameter from CGI.
#
package Symphero::Objects::CgiParam;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw($page @ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Displaying CGI parameter. Very simple.
#  param => parameter name
#  default => default text
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $text;
  $text=$self->{siteconfig}->cgi->param($args->{param});
  $text=$args->{default} unless defined $text;
  return unless defined $text;
  $self->textout(text => $text, objargs => $args);
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=(q$Id: CgiParam.pm,v 1.1 2001/02/27 04:06:15 amaltsev Exp $ =~ /(\d+\.\d+)/);
1;
