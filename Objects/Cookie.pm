##
# Cookies manipulations.
#
package Symphero::Objects::Cookie;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displays cookie. Arguments are:
#  name => cookie name
#  value => cookie value; nothing is displayed if value is given
#  default => what to display if there is no cookie set, nothing by default
#  expires => when to expire the cookie (same as in CGI->cookie)
#  path => cookie visibility path (same as in CGI->cookie)
#  domain => cookie domain (same as in CGI->cookie)
#  secure => cookie secure flag (same as in CGI->cookie)
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $cgi=$self->{siteconfig}->cgi;
  my $name=$args->{name};
  defined($name) || throw Symphero::Errors::Page ref($self)."::display - no name given";
  if(defined($args->{value}))
   { my $value=$args->{value};
     my $c=$cgi->cookie(-name => $name,
                        -value => $value,
                        -expires => $args->{expires},
                        -path => $args->{path},
                        -domain => $args->{domain},
                        -secure => $args->{secure});
     $self->{siteconfig}->add_cookie($c);
     return;
   }
  $self->textout(text => $cgi->cookie($name), objargs => $args);
}

##
# That's it
#
1;
