##
# Styler. Very simple - it just adds style name to "/bits/styler/" and
# then displays that template with TEXT being set to $args{text}.
#
package Symphero::Objects::Styler;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw($page @ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying styling template.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Special formatting for special fields.
  #
  # number => 1,234,456,789
  #
  my $template="<%NUMBER%>" if defined($args->{number});
  my $number=int($args->{number} || 0);
  1 while $number=~s/(\d)(\d{3}($|,))/$1,$2/;

  ##
  # dollars => $1'234.78
  #
  $template="<%DOLLARS%>" if defined($args->{dollars}) || defined($args->{dollar});
  my $dollars=sprintf("%.2f",$args->{dollars} || $args->{dollar} || 0);
  1 while $dollars=~s/(\d)(\d{3}($|,|\.))/$1,$2/;
  $dollars='$'.$dollars;

  ##
  # real => 1'234.78
  #
  $template="<%REAL%>" if defined($args->{real});
  my $real=sprintf("%.2f",$args->{real} || 0);
  1 while $real=~s/(\d)(\d{3}($|,|\.))/$1,$2/;

  ##
  # Percents
  #
  my $percent=0;
  if(defined($args->{percent}))
   { $template="<%PERCENT%>";
     if(defined($args->{total}))
      { $percent=$args->{total} ? $args->{percent}/$args->{total} : 0;
      }
     else
      { $percent=$args->{percent};
      }
   }

  ##
  # Displaying what we've got and any additional arguments
  #
  my $path=$args->{style};
  my $text=$args->{text};
  if($path)
   { $path="/bits/styler/$path";
     $template=undef;
   }
  else
   { $template=$text unless $template;
     $path=undef;
   }
  delete $args->{path};
  delete $args->{template};
  $self->SUPER::display( path => $path
                       , template => $template
                       , TEXT => $text
                       , NUMBER => $number
                       , DOLLARS => $dollars
                       , REAL => $real
                       , PERCENT => sprintf('%.2f%%',$percent*100)
                       , %{$args});
}

##
# That's it
#
1;
