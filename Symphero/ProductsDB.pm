##
# Container and selector for products.
# Stores data in SQL tables of the following structure (minimal required
# fields):
# CREATE TABLE Products
# ( sku CHAR(40) NOT NULL PRIMARY KEY,	// Product ID
#   category1 INT NOT NULL,		// First category
#   category2 INT NOT NULL,		// Second category
#   category3 INT NOT NULL,		// Third category
#   category4 INT NOT NULL,		// Fourth category
#   name CHAR(80) NOT NULL,		// Name of the product (short)
#   description CHAR(1000) NOT NULL	// Product description
# );
#
# Any additional fields may be added for specific sites.
#
package Symphero::ProductsDB;
use strict;
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Prototypes
#
sub new ($%);
sub load ($%);
sub search ($%);
sub update ($%);

##
# Package version
#
use vars qw($VERSION);
($VERSION)=(q$Id: ProductsDB.pm,v 1.1 2001/02/28 02:50:44 amaltsev Exp $ =~ /(\d+\.\d+)/);

##
# Standard fields which always present in a products database. Number of
# categories each product may be listed in should be configurable. But the
# way to achieve is TBD.
#
my @stdfields=qw(sku category1 category2 category3 category4
                 name description);

##
# Creating object, remembering table name to use.
#
# table  => table name (default is Products)
# dbh    => database handler (mandatory)
# fields => additional fields (optional array), would also be taken from
#           "product_fields" site configuration value if it is available.
#
sub new ($%)
{ my $class=shift;
  my $args=get_args(\@_);
  $args->{dbh} || throw Symphero::Errors::ProductsDB
                        "Symphero::Products - no database handler given";
  my $fields=$args->{fields};
  if(! $fields)
   { my $config=get_site_config();
     $fields=$config->get("product_fields") if $config;
   }
  my $self={ table  => $args->{table} || "Products"
           , dbh    => $args->{dbh}
           , fields => $fields
           };
  bless $self,ref $class || $class;
}

##
# Fast loading of one product with known SKU. Returns reference to the
# hash.
#
# Arguments are:
#  sku => product SKU
#  fields => array reference, list of fields to retrieve (optional).
#
sub load ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $sku=$args->{sku};
  defined($sku) || throw Symphero::Errors::ProductsDB
                         ref($self)."::loas - no 'sku' given";

  ##
  # Building the list of fields to retrieve. Some magick here to
  # eliminate repeating names.
  #
  my @fields;
  if($args->{fields})
   { @fields=@{$args->{fields}};
   }
  else
   { my %fields;
     @fields{@stdfields}=@stdfields;
     @fields{@{$self->{fields}}}=@{$self->{fields}} if $self->{fields};
     @fields=keys %fields;
   }

  ##
  # Building query
  #
  my $sql="SELECT ".join(",",@fields)." FROM $self->{table} WHERE sku=?";
  my $sth=$self->{dbh}->prepare($sql);
  if(!$sth || !$sth->execute("".$sku))
   { eprint "ProductsDB::load - SQL: ",$self->{dbh}->errstr;
     return undef;
   }
  my $row=$sth->fetchrow_arrayref();
  if(!$row)
   { dprint "No product found for SKU=$sku";
     return undef;
   }
  my %row;
  @row{@fields}=@{$row};
  \%row;
}

##
# Looks up products in database.
#  category => category to look in (optional)
#  keywords => keywords (optional)
#  limit    => limit on the number of products returned (optional)
#  field.NAME.COND => extra conditions (example: field.sku.like => "123").
#  skuonly  => return the list of SKUs only
#
# Without arguments will return _complete_ list of products in the
# database. This can take a lot of time and memory. You've been warned.
#
sub search ($%)
{ my $self=shift;
  my %args=%{get_args(\@_)};
  my $category=$args{category};
  my $keywords=$args{keywords};
  my $limit=$args{limit};
  my $orderby=$args{orderby};

  ##
  # Preparing list of keywords and extra conditions.
  #
  my @keywords=split('\s+',$args{keywords} || "");
  my @extra;
  foreach my $f (keys %args)
   { next unless $f =~ /^field\.(\w+)(\.(\w+))?$/;
     push(@extra,{ field => $1,
                   value => $args{$f},
                   condition => $3 || "eq"
                 });
   }

  ##
  # Building SQL clause
  #
  my $sql="SELECT ";
  my @fields;
  if($args{skuonly})
   { @fields=("sku");
     push(@fields,qw(name description)) if $args{keywords};
     push(@fields,map { $_->{field} } @extra);
   }
  else
   { @fields=@stdfields;
     push(@fields,@{$self->{fields}}) if $self->{fields};
   }
  $sql.=join(",",@fields);
  $sql.=" FROM $self->{table}";
  $sql.=" WHERE category1=$category OR category2=$category" .
           " OR category3=$category OR category4=$category" if defined($category);
  $sql.=" ORDER BY $orderby" if $orderby && $orderby ne "relevance";
  $sql.=" LIMIT $limit" if $limit;
  my $sth=$self->{dbh}->prepare($sql);
  if(!$sth || !$sth->execute())
   { eprint "Products::search - SQL: ",$self->{dbh}->errstr;
     return;
   }

  ##
  # Going throught the list of returned products and selecting those we
  # need. It may be not very efficient for long lists especially if the
  # database is not on the local computer. We should probably move more
  # job into SQL engine. TBD.
  #
  # This manual search gives us advantage of better sorting.
  #
  my @products;
  while(my @row=$sth->fetchrow_array())
   { my %row;
     @row{@fields}=@row;
     my $relevance=0;
     if(@extra)
      { foreach my $ex (@extra)
         { my $cond=$ex->{condition};
           if($cond eq "eq")
            { $relevance++ if $row{$ex->{field}} eq $ex->{value};
            }
           elsif($cond eq "min")
            { $relevance++ if $row{$ex->{field}} >= $ex->{value};
            }
           elsif($cond eq "max")
            { $relevance++ if $row{$ex->{field}} <= $ex->{value};
            }
           elsif($cond eq "like")
            { $relevance++ if $row{$ex->{field}} =~ /$ex->{value}/;
            }
           else
            { throw Symphero::Errors::ProductsDB
                    ref($self)."::search - unknown condition: " .
                    "field=$ex->{field}, cond=$cond, value=$ex->{value}";
            }
         }
        next unless $relevance;
      }
     if(@keywords)
      { foreach my $kw (@keywords)
         { $relevance++ if $row{name} =~ /$kw/i;
           $relevance++ if $row{description} =~ /$kw/i;
         }
      }
     else
      { $relevance++;
      }
     next unless $relevance;
     $row{relevance}=$relevance;
     push @products,\%row;
   }
  $orderby eq "relevance"
   ? sort {$a->{relevance} <=> $b->{relevance}} @products
   : @products;
}

##
# Updating some fields in the product database. Arguments are the hash
# with fields to be updated and their new values.
#
# Does not allow to update unknown fields.
#
# SKU field is required and is used as a key.
#
sub update ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $sku=$args->{sku};
  defined($sku) && length($sku) ||
   throw Symphero::Errors::ProductsDB ref($self)."::update - no 'sku' given";

  ##
  # Going through the list of fields
  #
  my %cf=map { ($_,1) } @{$self->{fields}};
  foreach my $name (keys %{$args})
   { next if $name eq 'sku';
     $cf{$name} ||
      throw Symphero::Errors::ProductsDB ref($self)."::update - unknown field, name=$name";
     my $sth=$self->{dbh}->prepare("UPDATE $self->{table} SET $name=? WHERE sku=?");
     $sth && $sth->execute(''.$args->{$name},''.$sku) ||
      throw Symphero::Errors::ProductsDB ref($self)."::update - SQL error, ".$self->{dbh}->errstr;
   }
}

##
# Error package for ProductsDB.
#
package Symphero::Errors::ProductsDB;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
1;
