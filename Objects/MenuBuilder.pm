##
# Menu builder - for creating any kinds of menus - vertical, horizontal.
#
# Called as:
#  <%MenuBuilder base="/bits/top-menu"
#                item.0="statistic"
#                item.1="config"
#                item.1.grayed
#                item.2="password"
#                item.2.grayed
#                current="statistic"
#  %>
#
# Or:
#  <%MenuBuilder base="/bits/top-menu"
#                item.0="statistic"
#                item.1="config"
#                item.2="password"
#                grayed="config,password"
#                current="statistic"
#  %>
#
# Assumes the following file structure at the `base':
#  header    - static menu header (optional)
#  footer    - static menu footer (optional)
#  separator - static menu items separator
#  item-NAME-normal - normal item text
#  item-NAME-grayed - grayed item text
#  item-NAME-active - currently opened page
#
package Symphero::Objects::MenuBuilder;
use strict;
use Symphero::Utils;
use Symphero::Objects;
use Symphero::Templates;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying Date.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Base directory is required!
  #
  my $base=$args->{base};
  $base || throw Symphero::Errors::Page ref($self)."::display - no `base' defined";

  ##
  # Building the list of items to show
  #
  my %items;
  foreach my $item (keys %{$args})
   { next unless $item =~ /^item.(\w+)$/;
     $items{$1}=$args->{$item};
   }

  ##
  # Now buiding the list of grayed out items
  #
  my %grayed;
  if($args->{grayed})
   { dprint "g=$args->{grayed}";
     %grayed=map { $_ => 1 } split(/,/,$args->{grayed});
   }
  else
   { foreach my $item (keys %items)
      { $grayed{$item}=1 if $args->{"item.$item.grayed"};
      }
   }

  ##
  # And finally displaying items.
  #
  my $obj=$self->object;
  $obj->display(path => "$base/header") if Symphero::Templates::check(path => "$base/header");
  my $first=1;
  my $sepexists=Symphero::Templates::check(path => "$base/separator");
  foreach my $item (sort { ($a =~ /^\d+$/ && $b =~ /^\d+$/) ? $a <=> $b : $a cmp $b } keys %items)
   { my $name=$items{$item};
     $obj->display(path => "$base/separator") if !$first && $sepexists;
     $first=0;
     my $path;
     if($grayed{$name})
      { $path="grayed";
      }
     elsif(defined($args->{active}) && $name eq $args->{active})
      { $path="active";
      }
     else
      { $path="normal";
      }
     $path="$base/item-$name-$path";
     $obj->display(path => $path);
   }
  $obj->display(path => "$base/footer") if Symphero::Templates::check(path => "$base/footer");
}

##
# That's it
#
1;
