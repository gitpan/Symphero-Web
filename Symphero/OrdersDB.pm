##
# Shopping carts and order information database. See Design document for
# details.
#
package Symphero::OrdersDB;
use strict;
use Carp;
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Inheritance.
#
use Symphero::MultiValueDB;
use vars qw(@ISA);
@ISA=qw(Symphero::MultiValueDB);

##
# Package version
#
use vars qw($VERSION);
($VERSION)=(q$Id: OrdersDB.pm,v 1.1 2001/02/28 02:50:44 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Method prototypes
#
sub new ($%);
sub extra_fields ($%);
sub put_product ($%);
sub delete_product ($%);
sub get_product ($%);
sub addsub ($$$$);
sub total ($;$);
sub valid ($);
sub clear ($);
sub status_code ($$);
sub status_name ($$);
sub status_codes_list ();
sub calculate_total ($);

##
# Creating instance.
#
sub new ($%)
{ my $proto=shift;
  my %args=@_;
  if(!$args{table} && (!ref($proto) || !$$proto->{table}))
   { $args{table}="Orders";
   }
  my $self=$proto->SUPER::new(%args);

  ##
  # Standard and extra fields are stored here.
  #
  $$self->{product_fields}=
   { price =>       { required => 1
                    }
   , description => { required => 1
                    }
   , quantity =>    { required => 1
                    , additive => 1
                    }
   }; 

  ##
  # Checking for extra fields in site configuration
  #
  my $config=get_site_config;
  if($config && $config->get('order_product_fields'))
   { $self->extra_fields($config->get('order_product_fields'));
   }

  ##
  # All set.
  #
  $self;
}

##
# Sets the list of extra fields to store/retrieve/delete for each
# product.
#
sub extra_fields ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  foreach my $field (keys %{$args})
   { my $desc=$args->{$field};
     if(ref($desc) ne "HASH")
      { carp ref($self),"::extra_fields - bad field description for '$field'";
        return;
      }
     $$self->{product_fields}->{$field}=$desc;
   }
  $$self->{product_fields};
}

##
# Putting new product into order. Replaces existing information or
# creates new product.
#
# Quantity accumulates.
#
sub put_product ($%)
{ my $self=shift;
  my %args=%{get_args(\@_)};
  my $sku=$args{sku};
  if(!$sku)
   { carp ref($self),"::put_product - no SKU given";
     return;
   }
  foreach my $field (keys %{$$self->{product_fields}})
   { if(!defined($args{$field}) &&
        $$self->{product_fields}->{$field}->{required})
      { carp ref($self),"::put_product - field '$field' is required";
        return undef;
      }
   }
  foreach my $field (keys %{$$self->{product_fields}})
   { if($$self->{product_fields}->{$field}->{additive})
      { $self->addsub($field, $sku => $args{$field});
      }
     else
      { $self->putsub($field, $sku => $args{$field}) if $args{$field} || $$self->{product_fields}->{$field}->{required};
      }
   }
  1;
}

##
# Deletes given product from the cart
#
sub delete_product ($%)
{ my $self=shift;
  my $sku;
  if(@_ == 1)
   { $sku=shift;
   }
  else
   { my $args=get_args(\@_);
     $sku=$args->{sku};
   }
  defined($sku) || throw Symphero::Errors::OrdersDB
                   ref($self)."::delete_product - no SKU given";
  foreach my $field (keys %{$$self->{product_fields}})
   { $self->delsub($field => $sku);
   }
  1;
}

##
# Returns product description by given SKU.
#
sub get_product ($%)
{ my $self=shift;
  my $sku;
  if(@_ == 1)
   { $sku=shift;
   }
  else
   { my $args=get_args(\@_);
     $sku=$args->{sku};
   }
  defined($sku) || throw Symphero::Errors::OrdersDB
                   ref($self)."::get_product - no SKU given";
  my %desc=(sku => $sku);
  foreach my $field (keys %{$$self->{product_fields}})
   { $desc{$field}=$self->getsub($field => $sku);
   }
  \%desc;
}

##
# Mathematically adds value to already existing in the database. Takes
# three arguments - field name, sku and value (the same as in
# MultiValueDB::putsub).
#
sub addsub ($$$$)
{ my ($self,$name,$subname,$value)=@_;
  return unless $name && $subname;
  my $ev=$self->getsub($name,$subname);
  $value=($ev ? $ev : 0) + ($value ? $value : 0);
  $self->putsub($name => $subname, $value);
}

##
# Sets or returns value of order total, calculated outside. Supposed to
# include all discounts, shipping, taxes and so on - this is what user
# would be charged.
#
sub total ($;$)
{ my $self=shift;
  my $total=shift;
  if($total)
   { $self->put(total => $total);
   }
  else
   { $total=$self->get("total");
   }
  $total;
}

##
# Clearing order, dangerous!
#
sub clear ($)
{ my $self=shift;
  my $crt=$self->get('crtime');
  $self->delete_all;
  $self->put(crtime => $crt);
}

##
# Checking that the order is valid.
#
sub valid ($)
{ my $self=shift;
  $self->id && $self->get('crtime');
}

##
# Retrieves or sets user status
#
sub status_code ($$)
{ my $self=shift;
  my $code=shift;
  if(defined($code))
   { my $old=$self->allow_changes;
     $self->put(status => $code);
     $self->allow_changes($old);
     return $code;
   }
  $self->get("status");
}

##
# Default user statuses. May be overriden in site configuration with
# "order_status_table" parameter.
#
my %order_status_table=(  0 => "Filling up"
                       , 10 => "Ready to process"
                       , 20 => "Processed"
                       , 30 => "Packing & Shipping"
                       , 40 => "Shipped"
                       );

##
# Status name by given code
#
sub status_name ($$)
{ my $self=shift;
  my $code=shift;
  $code=$self->get("status") unless defined $code;
  $code=0 unless defined $code;
  my $siteconfig=get_site_config();
  my $table=$siteconfig && $siteconfig->get("order_status_table")
            ? $siteconfig->get("order_status_table")
            : \%order_status_table;
  $table->{$code};
}

##
# List of statuses
#
sub status_codes_list ()
{ my $siteconfig=get_site_config();
  my $table=$siteconfig && $siteconfig->get("order_status_table")
            ? $siteconfig->get("order_status_table")
            : \%order_status_table;
  keys %{$table};
}

##
# Sums up all products in the order without any S&H or taxes.
#
sub calculate_total ($)
{ my $self=shift;
  my $quantity=$self->get("quantity");
  return 0 unless $quantity && ref($quantity);
  my $price=$self->get("price");
  my $total=0;
  foreach my $sku (keys %{$price})
   { $total+=$price->{$sku}*$quantity->{$sku};
   }
  $total;
}

##
# Error package for OrdersDB.
#
package Symphero::Errors::OrdersDB;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
