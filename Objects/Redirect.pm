##
# Redirector object. Not very useful in the pages themselves, but handy
# for reusing by other objects.
#
# Can set cookies on the redirect.
#
package Symphero::Objects::Redirect;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Redirecting; arguments are:
#
# url => new url or short path.
# target => target frame (optional)
#
sub display
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;

  ##
  # Checking parameters.
  #
  if(! $args->{url})
   { eprint "No URL or path in Redirect";
     return;
   }

  ##
  # Additional fields into standard header.
  #
  my %qa=( -Status => '302 Moved' );

  ##
  # Target window works only with Netscape, but we do not care here and
  # do our best.
  #
  if($args->{target})
   { $qa{-Target}=$args->{target};
     dprint ref($self),"::display - 'target=$args->{target}' does not work with MSIE!";
   }

  ##
  # Getting redirection URL
  #
  my $url;
  if($args->{url} =~ /^\w+:\/\//)
   { $url=$args->{url};
   }
  else
   { $url=$self->base_url(secure => $self->cgi->https() ? 1 : 0);
     my $url_path=$args->{url};
     $url_path="/".$url_path unless $url_path=~ /^\//;
     $url.=$url_path;
   }

  ##
  # Redirecting
  #
  $qa{-Location}=$url;
  $config->header_args(\%qa);
  $self->finaltextout(<<EOT);
The document is moved <A HREF="$url">here</A>.
EOT
}

##
# That's it
#
1;
