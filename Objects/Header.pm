=head1 NAME

Symphero::Objects::Header - Simple HTML header

=head1 SYNOPSIS

Currently is only useful in Symphero::Web site context.

=head1 DESCRIPTION

Simple HTML header object. Accepts the following arguments, modifies
them as appropriate and displays "/bits/page-header" template.

=over

=item title => 'Page title'

Passed as is.

=item description => 'Page description for search engines'

This is converted to
<META NAME="Description" CONTENT="Page..">.

=item keywords => 'Page keywords for search engines'

This is converted to
<META NAME="Keywords" CONTENT="Page keywords..">.

=item path => '/bits/alternative-template-path'

Header template path, default is "/bits/page-header".

=item type => 'text/csv'

Allows you to set page type to something different then default
"text/html". If you set type the template would not be displayed! If you
still need it - call Header again without "type" argument.

=back

Would pass the folowing arguments to the template:

=over

=item META

Keywords and description combined.

=item TITLE

The value of 'title' argument above.

=back

Example:

 <%Header title="Site Search" keywords="super, duper, hyper, commerce"%>

=head1 METHODS

No publicly available methods except overriden display().

=head1 EXPORTS

Nothing.

=head1 AUTHOR

Brave New Worlds, Inc.: Andrew Maltsev <am@xao.com>.

=head1 SEE ALSO

Recommended reading:
L<Symphero::Web>,
L<Symphero::Page>.

=cut

###############################################################################
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
# Displaying HTML header.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  if($args->{type})
   { $self->siteconfig->header_args(-type => $args->{type});
     return;
   }
  my $title=$args->{title} || "Symphero::Web -- No title";
  my $path=$args->{path} || "/bits/page-header";
  my $meta="";
  $meta.=qq(<META NAME="Keywords" CONTENT="$args->{keywords}">\n) if $args->{keywords};
  $meta.=qq(<META NAME="Description" CONTENT="$args->{description}">\n) if $args->{description};
  $self->SUPER::display(path => $path,
                        TITLE=>$title,
                        META=>$meta);
}

##
# That's it
#
1;
