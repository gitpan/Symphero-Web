=head1 NAME

Symphero::Objects::SetArg - sets base object arguments

=head1 SYNOPSIS

Currently is only useful in Symphero::Web site context.

=head1 DESCRIPTION

Sets argument in parent object.

To be used in situations like the following to set default values. Or in
general to set or modify current arguments.

Master template: 

  <%Page path="/bits/image-template" NAME="abc"%>
  <%Page path="/bits/image-template" NAME="def" WIDTH=123%>
  <%Page path="/bits/image-template" NAME="efg" HEIGHT=432%>

/bits/image-template:

  <%SetArg name="WIDTH" value="999"%>
  <%SetArg name="HEIGHT" value="777"%>
  <IMG SRC="/images/<%NAME/f%>.gif" WIDTH="<%WIDTH%>" HEIGHT="<%HEIGHT%>">

Actual output would be:

  <IMG SRC="/images/abc.gif" WIDTH="999" HEIGHT="777">
  <IMG SRC="/images/def.gif" WIDTH="123" HEIGHT="777">
  <IMG SRC="/images/efg.gif" WIDTH="999" HEIGHT="432">

I<Note:> Because of extra new-line characters in the template after both
SetArg lines actual output would be slightly different. Pay attention to
this if your HTML code is space-sensitive.
 
By default it does not override existing values. Use non-zero "override"
argument to override.

=head1 METHODS

No publicly available methods except overriden display() method.

=cut

###############################################################################
package Symphero::Objects::SetArg;
use strict;
use Error;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Setting arguments. Actual merging is done in Page object. We just set
# merge_args here.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $name=$args->{name};
  defined($name) || throw Symphero::Errors::Page
                          "SetArg is pointless without 'name' argument";
  my $value=defined($args->{value}) ? $args->{value} : "on";
  my $parent=$self->{parent};
  $parent || throw Symphero::Errors::Page "SetArg is pointless when orphan";
  $parent->{merge_args}->{$name}=$value if !defined($parent->{args}->{$name}) || $args->{override};
}

##
# That's it
#
1;
__END__

=head1 EXPORTS

Nothing.

=head1 AUTHOR

Brave New Worlds, Inc.: Andrew Maltsev <am@xao.com>.

=head1 SEE ALSO

Recommended reading:
L<Symphero::Web>,
L<Symphero::Page>.

=cut
