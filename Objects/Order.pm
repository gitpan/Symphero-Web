##
# Order processing.
#
package Symphero::Objects::Order;
use strict;
use Symphero::Utils;
use Symphero::OrdersDB;
use Symphero::ProductsDB;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Action');

##
# Method prototypes.
#
sub check_mode ($$);
sub get_order ($%);
sub set_order_id ($@);
sub new_order ($@);
sub set_cookie ($%);
sub find_order ($@);
sub add_product ($@);
sub show_total ($@);
sub show_id ($@);
sub clear_order ($);
sub count_products ($@);
sub list_content ($@);
sub list_content_args ($);
sub calculate_total ($@);
sub list_orders ($@);
sub list_orders_sort ($%);
sub list_orders_check ($%);
sub clone_order ($%);
sub get_status_code ($%);
sub set_status_code ($%);
sub place_order ($%);
sub set_name ($%);
sub get_value ($%);

##
# Processing standard commands. Called from derived object as a last step.
#
# Standard commands are:
#  mode="set-id" id="NEWCARTID"
#  mode="add-product" sku="SKU" quantity="NNN"
#  mode="show-total"
#  mode="show-id"
#  mode="new-order"
#  mode="clear-order"
#  mode="list-content" header="header-path" row="product-path" footer="footer-path"
#  mode="list-orders" header="..." nothing="..." row="..." footer="..."
#  mode="count-products"
#  mode="clone-order" ...
#  mode="get-status-code" ...
#  mode="set-status-code" code="xxx"
#  mode="place-order" status="xxx"
#  mode="set-name" name="xxx"
#  mode="get-value" name="name" default="xxx"
#
sub check_mode ($$)
{ my $self=shift;
  my $args=get_args(\@_);
  my $mode=$args->{mode};
  if($mode eq "set-id")
   { $self->set_order_id($args);
   }
  elsif($mode eq "add-product")
   { $self->add_product($args);
   }
  elsif($mode eq "show-total")
   { $self->show_total($args);
   }
  elsif($mode eq "show-id")
   { $self->show_id($args);
   }
  elsif($mode eq "clear-order")
   { $self->clear_order($args);
   }
  elsif($mode eq "new-order")
   { $self->new_order($args);
   }
  elsif($mode eq "find-order")
   { $self->find_order($args);
   }
  elsif($mode eq "list-content")
   { $self->list_content($args);
   }
  elsif($mode eq "list-orders")
   { $self->list_orders($args);
   }
  elsif($mode eq "count-products")
   { $self->count_products($args);
   }
  elsif($mode eq "count-products")
   { $self->clone_order($args);
   }
  elsif($mode eq "get-status-code")
   { $self->get_status_code($args);
   }
  elsif($mode eq "set-status-code")
   { $self->set_status_code($args);
   }
  elsif($mode eq "place-order")
   { $self->place_order($args);
   }
  elsif($mode eq "set-name")
   { $self->set_name($args);
   }
  elsif($mode eq "get-value")
   { $self->get_value($args);
   }
  else
   { throw Symphero::Errors::Page ref($self)."::display - unknown mode=$mode";
   }
}

##
# Gets current order or order with given ID.
#  my $order=$self->get_order;
# Or:
#  my $order=$self->get_order(id => $args->{id});
#
# Unless "return_error" is set it never returns error, throws exception
# instead.
#
sub get_order ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order;
  if($args->{id})
   { my $id=repair_key($args->{id});
     $order=Symphero::OrdersDB->new(dbh => $self->dbh, id => $id);
   }
  else
   { $order=$self->{orderref}=$self->siteconfig->get("current_order");
   }
  if(!$order || !$order->valid)
   { return undef if $args->{return_error};
     throw Symphero::Errors::Page ref($self)."::get_order - no order id or bad order";
   }
  $order;
}

##
# Switching to new order
#
#  id => New order ID
#
# Result: siteconfig->{current_order} refers Symphero::OrdersDB object
# for new order ID.
#
sub set_order_id ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $id=repair_key($args->{id});
  $id || throw Symphero::Errors::Page
               ref($self)."::set_order_id - id parameter required";
  my $order=Symphero::OrdersDB->new(dbh => $self->dbh,
                                    id => $id);
  if(! $order->valid)
   { eprint ref($self),"::set_order_id - invalid order ID ($id)";
     return $self->new_order();
   }
  $self->siteconfig->session_specific("current_order");
  $self->siteconfig->put(current_order => $order);
  $order->id;
}

##
# Creating new order. Sets cookie if "cookie" parameter is set to cookie
# name.
#
sub new_order ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=Symphero::OrdersDB->new(dbh => $self->dbh);
  if($self->can('generate_id'))
   { $order->create(generator => $self->can('generate_id'));
   }
  else
   { $order->create();
   }
  my $config=$self->siteconfig;
  $order->put(logname => $config->get("logname")) if $config->get("logname");
  $config->session_specific("current_order");
  $config->put(current_order => $order);
  $self->set_cookie(id => $order->id);
  $order->id;
}

##
# Setting order cookie. Uses 'id' parameter if given or current order id
# if not.
#
# Arguments are:
#  id => order id to set (optional)
#  cookie => cookie name
#
sub set_cookie ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $id;
  if($args->{id})
   { $id=$args->{id};
   }
  else
   { my $order=$self->get_order;
     $id=$order->id;
   }
  my $config=$self->siteconfig;
dprint "cookie set to $id";
  $config->add_cookie(-name => ($args->{cookie} || "orderid")
                     ,-value => $id
                     ,-expires => $args->{expires} ? $args->{expires} : "+1y"
                     ,-path => "/"
                     );
}

##
# Finding order or creating a new one.
#  cookie => name of the cookie that store order id, default is "orderid"
#
sub find_order ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;
  if($config->get('current_order'))
   { return $config->get('current_order')->id;
   }
  my $cname=$args->{cookie} || "orderid";
  my $id=$config->cgi->cookie(-name => $cname);
  if($id)
   { $id=$self->set_order_id(id => $id);
     my $logname=$config->get("logname");
     my $order=$self->get_order;
     my $oln=$order->get("logname");
     if($oln)
      { ##
        # This could happen if different user logs in from the same
        # computer or user just logs out.
        #
        if(!$logname || $oln ne $logname)
         { $id=$self->new_order($args);
dprint "Logname mismatch, order re-created, logname=$logname, oln=$oln";
         }
      }
     elsif($logname)
      { dprint "Order $id is now owned by $logname";
        $order->put(logname => $logname);
      }
     $self->set_cookie(id => $id);
   }
  else
   { $id=$self->new_order($args);
   }
  $id;
}

##
# Adding new product into order and re-calculating total.
#  sku => Product SKU
#  quantity => Product quantity
#  price => Price (optional)
#  description => Description (optional)
#  extra_fields => { ffff => vvvvv }
#
sub add_product ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;

  ##
  # Getting product information
  #
  my $sku=$args->{sku};
  if(!$sku)
   { eprint ref($self),"::add_product - no SKU given";
     return;
   }
  my $product={};
  if(!$args->{price} || !$args->{description})
   { my $pdb=Symphero::ProductsDB->new( dbh => $self->dbh);
     $product=$pdb->load(sku => $args->{sku});
     if(!$product || $product->{sku} ne $sku)
      { eprint ref($self),"::add_product - no such product";
        return;
      }
   }

  ##
  # Adding product. Product should contain hard-coded list_price
  # field if you use this code! Define it in site's configuration
  # "product_fields".
  #
  my $quantity=int($args->{quantity} || 1);
  if($quantity <= 0)
   { eprint ref($self),"::add_product - bad quantity ($quantity)";
     return;
   }

  ##
  # Building list of fields with extra_fields if supplied
  #
  my %fields=( sku => $sku
             , quantity => $quantity
             , price => $args->{price} || $product->{list_price}
             , description => $args->{description} || $product->{name}
             );
  if($args->{extra_fields})
   { foreach my $name (keys %{$args->{extra_fields}})
      { $order->extra_fields($name => { required => 0 });
        $fields{$name}=$args->{extra_fields}->{$name};
      }
   }
  $order->put_product(%fields);

  ##
  # Re-calculating total
  #
  $self->calculate_total;
}

##
# Displaying current order total.
#
sub show_total ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order(id => $args->{id});
  $self->textout(args => $args, text => sprintf("%f",$order->total));
}

##
# Displays order ID or nothing if this is bad or non existent order.
#
sub show_id ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order(id => $args->{id}, return_error => 1);
  $self->textout(args => $args, text => $order->id) if $order;
}

##
# Clearing order
#
sub clear_order ($)
{ my $self=shift;
  my $order=$self->get_order;
  $order->clear;
}

##
# Returns number of products in the order.
#
sub count_products ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
  my $q=$order->get("quantity");
  $self->object->display( template => scalar(keys %{$q}) );
}

##
# Listing all products.
#
sub list_content ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;

  ##
  # Additional parameters are re-sent into displaying object.
  #
  my $obj=$self->object;
  my %a=%{$args};
  delete $a{path};
  delete $a{template};

  ##
  # Are there any products?
  #
  my $q=$order->get("quantity");
  if(!$q || ! keys %{$q})
   { $obj->display( path => $args->{nothing}, %a) if $args->{nothing};
     return;
   }

  ##
  # Displaying header
  #
  $obj->display( path => $args->{header}
               , TOTAL => $order->total
               , ORDERNAME => $order->get('name') || ''
               , %a) if $args->{header};

  ##
  # Displaying products
  #
  if($args->{row})
   { my $p=$order->get("price");
     my $d=$order->get("description");
     my $t=$order->total;
     foreach my $sku (keys %{$q})
      { $obj->display( path => $args->{row}
                     , TOTAL => $p->{$sku} * $q->{$sku}
                     , SKU => $sku
                     , QUANTITY => $q->{$sku}
                     , PRICE => $p->{$sku}
                     , DESCRIPTION => $d->{$sku}
                     , $self->list_content_args(order => $order, sku => $sku)
                     , %a
                     );
      }
   }

  ##
  # Displaying footer
  #
  $obj->display( path => $args->{footer}
               , TOTAL => $order->total
               , ORDERNAME => $order->get('name') || ''
               , %a) if $args->{footer};
}

##
# Additional arguments may be retrieved, calculated and passed here in
# derived objects.
#
sub list_content_args ($)
{ ();
}

##
# Calculating total for the order. Supposed to be overriden!
#
sub calculate_total ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;

  my $price=$order->get("price");
  my $quantity=$order->get("quantity");
  my $total;
  foreach my $sku (keys %{$price})
   { $total+=$price->{$sku}*$quantity->{$sku};
   }
  $order->total($total);
}

##
# Listing all orders for given user. Only works if userdata is already
# loaded into site configuration by Authorize object.
#
#  header => header template path
#  row => order template path
#  footer => footer template path
#  nothing => template to show if there is nothing to list or no user
#  available
#  pltime.min => minimum place time
#  pltime.max => maximum place time
#  skip => order ID to be skipped
#
sub list_orders ($@)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->{siteconfig};
  my $logname=$config->get("logname");
  my $obj=$self->object;
  if(!$args->{all} && ! $logname)
   { eprint ref($self),"::list_orders called without valid user data";
     $obj->display(path => $args->{nothing} || $args->{header},
                   NUMBER => 0);
     return;
   }

  ##
  # Selecting orders
  #
  my $odb=Symphero::OrdersDB->new(dbh => $self->dbh);
  if(! $odb)
   { eprint ref($self),"::list_orders - cannot get OrdersDB object";
     $obj->display(path => $args->{nothing} || $args->{header},
                   NUMBER => 0);
     return;
   }
  my @rlist=$args->{all} ? $odb->listids
                         : $odb->listids(placed_by => $logname);
  my %crtimes;
  my %pltimes;
  my %itemnum;
  my @list;
  my %dates;
  foreach my $orderid (@rlist)
   { $odb->setid($orderid);
     next if $args->{skip} && $orderid eq $args->{skip};
     my $crtime=$odb->get("crtime");
     if(!$crtime)
      { $odb->delete_all;
        dprint "Deleted invalid order id=$orderid";
        next;
      }
     $crtimes{$orderid}=$crtime;
     my $q=$odb->get("quantity");
     $itemnum{$orderid}=scalar(keys %{$q});
     if(! $itemnum{$orderid})
      { my $order=$self->get_order(return_error => 1);
        if(!$order || $order->id ne $orderid)
         { $odb->delete_all;
           dprint "Deleted empty order id=$orderid";
         }
        next;
      }
     my $pltime=$odb->get('pltime');
     my @td=localtime($pltime || time);
     $dates{$td[5]+1900}->{$td[4]+1}=0;
     next if $args->{'pltime.min'} && $pltime < $args->{'pltime.min'};
     next if $args->{'pltime.max'} && $pltime > $args->{'pltime.max'};
     $pltimes{$orderid}=$pltime;
     next unless $self->list_orders_check(order => $odb,
                                          quantities => $q,
                                          crtime => $crtime,
                                          pltime => $pltime,
                                          objargs => $args,
                                         );
     push @list,$orderid;
     $dates{$td[5]+1900}->{$td[4]+1}=1;
   }
  undef @rlist;
  if(! @list)
   { $obj->display( path => $args->{nothing} || $args->{header}
                  , NUMBER => 0);
     return;
   }

  ##
  # Creating month options list
  #
  my $month_options;
  my $selected=0;
  foreach my $year (sort { $b <=> $a } keys %dates)
   { foreach my $month (sort { $b <=> $a } keys %{$dates{$year}})
      { $selected+=$dates{$year}->{$month};
        $month_options.=$obj->expand( template => '<OPTION VALUE="<%MONTH%>"<%SELECTED%>><%MONTH%>'."\n"
                                    , MONTH => sprintf('%02u/%u',$month,$year)
                                    , SELECTED => ($selected==1 && $dates{$year}->{$month}) ? " SELECTED" : ""
                                    );
      }
   }

  ##
  # Displaying orders
  #
  $obj->display(path => $args->{header},
                NUMBER => scalar(@list),
                MONTH_OPTIONS => $month_options
               ) if $args->{header};
  foreach my $orderid (sort { $self->list_orders_sort(a => $a, b => $b,
                                                      itemnum => \%itemnum,
                                                      crtime => \%crtimes,
                                                      pltime => \%pltimes,
                                                      objargs => $args,
                                                      odb => $odb
                                                     );
                            } @list)
   { $odb->setid($orderid);
     my $crtime=$crtimes{$orderid};
     my $total=$odb->total;
     $obj->display( path => $args->{row}
                  , NUMBER => scalar(@list)
                  , ORDERID => $orderid
                  , LOGNAME => ($args->{all} ? $odb->get('logname') : $logname) || ''
                  , TOTAL => $total || 0
                  , NAME => $odb->get('name') || "No name"
                  , ITEMNUM => $itemnum{$orderid} || 0
                  , CRTIME => $crtime
                  , PLTIME => $pltimes{$orderid} || 0
                  , SHTIME => $odb->get('shtime') || 0
                  , STATUS => $odb->status_name || ''
                  );
   }
  $obj->display(path => $args->{footer},
                NUMBER => scalar(@list)) if $args->{footer};
}

##
# Sorting subroutine for list_orders
#
sub list_orders_sort ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  $args->{a} cmp $args->{$b};
}

##
# Selection subroutine for list_orders. Should return `true' for this order
# to be included into list or `false' otherwise.
#
# Arguments are:
#  order => order to be checked
#  objargs => display() args
#
sub list_orders_check ($%)
{ 1;
}

##
# Cloning order. Arguments are:
#  id => original order ID
#  extra_fields => [ list of product fields to copy ], optional
#
sub clone_order ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
 
  ##
  # Where should we clone from?
  #
  my $source=Symphero::OrdersDB->new(dbh => $self->dbh, id => $args->{id});
  $source->valid ||
   throw Symphero::Errors::OrdersDB ref($self)."::clone_order - no valid 'id' given";
 
  ##
  # The list of fields is taken from the current order.
  #
  my $q=$source->get("quantity");
  foreach my $sku (keys %{$q})
   { ##
     # Building the list of extra fields to copy.
     #
     my %ef;
     if($args->{extra_fields})
      { foreach my $fn (@{$args->{extra_fields}})
         { $ef{$fn}=$source->getsub($fn => $sku);
         }
      }
     $self->add_product(sku => $sku,
                        quantity => $q->{$sku},
                        extra_fields => \%ef);
   }
}

##
# Getting order status code.
#
sub get_status_code ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
  my $code=$order->status_code;
  $self->textout(text => $code || '', objargs => $args);
}

##
# Setting order status code without any checks!
# Arguments are:
#  code => new order status
#
sub set_status_code ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
  my $code=$args->{code};
  defined($code) || throw Symphero::Errors::Page
                          ref($self)."::set_status_code - no 'code' given";
  $order->status_code($code);
}

##
# Placing the order. Sets the status, sets pltime to current time and
# resets current order to newly created one.
#
# Does not decrement available inventory! This is supposed to be done
# from derived object if required.
#
sub place_order ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
  my $status=$args->{status} || 10;
  $self->set_status_code(code => $status);
  $order->put(pltime => time);
  $self->new_order();
}

##
# Setting order name. Arguments are:
#  name => new order name
#
sub set_name ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order;
  my $name=$args->{name};
  $order->put(name => $name) if defined $name;
}

##
# Getting arbitrary value from order by name.
#
sub get_value ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $order=$self->get_order(id => $args->{id});
  my $name=$args->{name};
  $name || throw Symphero::Errors::Page ref($self)."::get_value - no 'name' given";
  my $value=$order->get($name);
  $value='<HASH>' if $value && ref($value);
  $value=$args->{default} unless defined $value;
  $self->textout(text => $value, objargs => $args) if defined $value;
}

##

##
# That's it
#
1;
