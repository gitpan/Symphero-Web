##
# Very interesting object. Placeholder awating for actual substitute
# from parent object. Suitable for templates like this:
#
# document.html:
#  <%Page path="/template"
#         stub.header.title="Test page"
#         stub.top.path="/top-menu"
#  %>
#
# /template:
#  <%Stub name="header" default.objname="Header"%>
#  <CENTER>
#   <%Stub name="top" default.path="/top-menu-default"%>
#  </CENTER>
#
# On execution of /template it will works exactly like if it had the
# following content:
#  <%Header title="Test page"%>
#  <CENTER>
#   <%Page path="/top-menu"%>
#  </CENTER>
#
package Symphero::Objects::Stub;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw($page @ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $name=$args->{name};
  if(!defined($name))
   { eprint "Nameless Stubs are useless!";
     return;
   }
  my $parent=$self->{parent};
  if(!$parent)
   { eprint "Orphan Stubs are useless!";
     return;
   }

  ##
  # Composing arguments for real object. First taking defaults from our
  # arguments
  #
  my %rargs;
  foreach my $k (keys %{$args})
   { $rargs{$1}=$args->{$k} if $k =~ /^default\.(.*)$/;
   }

  ##
  # ..then values from parent to override them.
  #
  my $pargs=$parent->{args} || {};
  foreach my $k (keys %{$pargs})
   { $rargs{$1}=$pargs->{$k} if $k =~ /^stub\.$name\.(.*)$/;
   }

  ##
  # If the object is default (Page) -- displaying the content through
  # our own ancestor.
  #
  my $obj=$self->object(objname => $rargs{objname});
  delete $rargs{objname};
  $obj->display(%rargs);
}

##
# That's it
#
1;
