##
# Date displayer. One of the simpliest objects.
#
package Symphero::Objects::Date;
use strict;
use Symphero::Utils;
use Symphero::Objects;
use POSIX qw(strftime);

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
  # It can be curent time or given time
  #
  my $time=$args->{gmtime} || time;

  ##
  # Checking output style
  #
  my $style=$args->{style} || '';
  my $format='';
  if(!$style)
   { $format=$args->{format};
   }
  elsif($style eq 'dateonly')
   { $format='%m/%d/%Y';
   }
  elsif($style eq 'short')
   { $format='%H:%M:%S %m/%d/%Y';
   }
  elsif($style eq 'timeonly')
   { $format='%H:%M:%S';
   }
  else
   { eprint "Unknown date style '$style'";
   }

  ##
  # Displaying according to format.
  #
  if($format)
   { $time=strftime($format,localtime($time));
   }
  else
   { $time=scalar(localtime($time));
   }
  $self->textout($time);
}

##
# That's it
#
1;
