##
# Basic header. Prints page title, keywords, description and so on.
#
package Symphero::Objects::Header;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying header. Arguments are:
#  path => template path (default is /bits/page-header)
#  title => page title
#  keywords => comma separated keywords list for page
#  description => page description for search engines
#  type => content-type (does not print anything if this is set)
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  if($args->{type})
   { $self->siteconfig->header_args(-type => $args->{type});
     return;
   }
  my $title=$args->{title} || "Symphero 4 -- No title";
  my $path=$args->{path} || "/bits/page-header";
  my $meta="";
  $meta.=qq(<META NAME="Keywords" CONTENT="$args->{keywords}">\n) if $args->{keywords};
  $meta.=qq(<META NAME="Description" CONTENT="$args->{description}">\n) if $args->{description};
  $self->SUPER::display(path => $path,
                        template => $args->{template},
                        TITLE=>$title,
                        META=>$meta);
}

##
# That's it
#
1;
