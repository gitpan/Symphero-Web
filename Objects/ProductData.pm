##
# Product data displayer.
#
package Symphero::Objects::ProductData;
use strict;
use Symphero::Utils;
use Symphero::ProductsDB;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Last displayed product gets cached here because most probably we will
# be asked to display more than one property of that product.
#
use vars qw($product);

##
# Displaying product info.
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;
  if(!defined($args->{sku}))
   { eprint "ProductData called without SKU given";
     return;
   }

  ##
  # Loading product data
  #
  if(!$product || $product->{sku} ne $args->{sku})
   { my @fields;
     push(@fields,@{$self->{fields}}) if $self->{fields};
     push(@fields,@{$config->get("product_fields")}) if $config->get("product_fields");
     my $pd=Symphero::ProductsDB->new(dbh => $config->dbh,
                                      fields => \@fields);
     if(! $pd)
      { eprint "Can't get ProductsDB handler";
        return;
      }
     $product=$pd->load(sku=>$args->{sku});
   }

  ##
  # Looking what to display
  #
  if(!$args->{var})
   { eprint "Objects::ProductData - no variable name given";
     return;
   }
  my $value=$product->{$args->{var}};
  $value=$product->{$args->{var1}} if (!defined($value) || $value eq '') && $args->{var1};
  $value=$product->{$args->{var2}} if (!defined($value) || $value eq '') && $args->{var2};
  $value=$product->{$args->{var3}} if (!defined($value) || $value eq '') && $args->{var3};
  $value=$product->{$args->{var4}} if (!defined($value) || $value eq '') && $args->{var4};
  $value=$args->{default} if (!defined($value) || $value eq '') && defined($args->{default});
  defined($value) || dprint "Objects::ProductData - No value found, sitename=$self->{sitename}, var=$args->{var}";

  ##
  # If style defined - formatting the value. Should be more
  # flexible! (TBD, am@)
  #
  #  $ - money format
  # 
  if($args->{style})
   { my $style=$args->{style};
     if($style eq '$' && $value=~/[0-9.-]+/)
      { $value=sprintf("\$%.02f",$value);
      }
     else
      { eprint "Unknown style - '$style'";
      }
   }

  ##
  # Printing
  #
  $self->textout(text => $value, objargs => $args);
}

##
# That's it
#
1;
