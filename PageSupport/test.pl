# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
###########################################################################
use strict;

sub tprint ($$)
{ my ($name,$rc)=@_;
  print $name,'.' x (50-length($name)),".",$rc ? "ok" : "NOT OK","\n";
}

sub load_module ($)
{ my $module=shift;
  eval "use $module";
  my $err=$@;
  my $ver=$err ? 'BAD' : (eval ('$' . $module . '::VERSION') || 'BAD');
  tprint "$module<$ver>", ! $err;
  die $err if $err;
}

##########################################################################
load_module "Symphero::PageSupport";

my $t1;
Symphero::PageSupport::reset();
for(1..10)
 { Symphero::PageSupport::addtext(scalar($_ * 13) x 5);
   for(1..10)
    { Symphero::PageSupport::addtext(scalar($_ * 29) x 5);
      Symphero::PageSupport::push();
      for(1..10)
       { Symphero::PageSupport::addtext(scalar($_ * 7) x 5);
       } 
      $t1.=Symphero::PageSupport::pop();
    }
 }
my $t2=Symphero::PageSupport::pop();
my $c1=unpack('%16C',$t1);
my $c2=unpack('%16C',$t2);
tprint "inner", $c1 eq '55';
tprint "outer", $c2 eq '49';

1;
