=head1 NAME

Symphero::Objects::Footer - simple HTML footer

=head1 SYNOPSIS

Currently is only useful in Symphero::Web site context.

=head1 DESCRIPTION

Displays "/bits/page-footer" template (can be overriden with "path"
argument) giving it the following arguments:

=over

=item VERSION

Current Symphero::Web package version.

=item COPYRIGHT

Copyright information for Symphero::Web.

=back

In most cases you would want to extend or override this object or at
least its default template with something site specific.

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
  my %a=(path => '/bits/page-footer',
         VERSION => $Symphero::Defaults::version,
         COPYRIGHT => 'Copyright (C) 2000,2001 Brave New Worlds, Inc.'
        );
  $self->SUPER::display($self->merge_args(oldargs => \%a,
                                          newargs => $args));
}

##
# That's it
#
1;
