##
# Simple utility object. Returns BGCOLOR=xxx on every second invokation.
# Suitable to form chess-like colored tables.
#
package Symphero::Objects::BgColor;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw($page @ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Persistent storage.
#
my $bgcolor="#eeeeee";
my $tdseq=0;
my $trseq=1;

##
# Displaying background color.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # We were called to set up color?
  #
  if($args->{color})
   { $bgcolor=$args->{color};
   }

  ##
  # Row start?
  #
  if($args->{rowstart})
   { $tdseq=$trseq=1-$trseq;
   }

  ##
  # Printing
  #
  $self->textout(text => " BGCOLOR=\"$bgcolor\"", objargs => $args) if $tdseq;
  $tdseq=1-$tdseq;
}

##
# That's it
#
1;
