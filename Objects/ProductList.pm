##
# List of products. Searches through the database and displays the list of
# products suitable for further browsing/adding to the shopping cart.
#
package Symphero::Objects::ProductList;
use strict;
use Symphero::Utils;
use Symphero::ProductsDB;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Page');

##
# Displaying products list. Arguments are taken first from the argument
# list and then from CGI environment (so, CGI environment overrides
# arguments).
#  header => header
#  row => what to display for each product
#  footer => footer
#  keywords => list of keywords to look for, "search string"
#  category => category id
#  orderby => order - may be "relevance" or any field name
#             (default is "relevance")
#  pagesize => number of items on one page
#  pagenum => number of page to show
#  field.XX.min => minimum value of the field XX
#  field.XX.max => maximum value of the field XX (eg. field.price.max=200)
#  field.XX => exact value of the field XX
#
sub display ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->siteconfig;

  ##
  # Overriding parameters in the %args by parameters from CGI query.
  # Only parameters from the known list are used to prevent security
  # problems.
  #
  my $cgi=$config->cgi;
  my %known;
  @known{qw(keywords orderby pagesize pagenum category)}=(1,1,1,1,1);
  foreach my $p ($cgi->param)
   { next unless $known{$p} || $p =~ /^field\.(\w+)(\.\w+)?$/;
     $args->{$p}=$cgi->param(-name=>$p);
   }

  ##
  # Getting the list of products
  #
  my $pl=Symphero::ProductsDB->new(dbh=>$config->dbh);
  $args->{skuonly}=1;
  my @products=$pl->search($args);

  ##
  # Displaying.
  #
  my $obj=$self->object;
  if(! @products)
   { $obj->display(path => $args->{nothing} || $args->{header},
                   NUMBER => 0);
     return;
   }
  $obj->display(path => $args->{header}, NUMBER => scalar(@products)) if $args->{header};
  foreach my $product (@products)
   { $obj->display(path => $args->{row},
                   SKU => $product->{sku},
                   RELEVANCE => $product->{relevance} || 0
                  );
   }
  $obj->display(path => $args->{footer}, NUMBER => scalar(@products)) if $args->{footer};
}

##
# That's it
#
1;
