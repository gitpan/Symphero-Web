##
# Supporting object for categories.
#
package Symphero::Objects::Category;
use strict;
use Symphero::Utils;
use Symphero::Objects;
use Symphero::Categories;

##
# Inheritance
#
use vars qw($page @ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Displaying Category object.
#
# level => level of sub-categoring, 0 - top category
# select => show selector (<SELECT name="category.0">..)
# table => table name (default is "Categories")
# showname => show category name
#
sub display ($;%)
{ my $self=shift;
  my %args=%{get_args(\@_)};
  my $config=$self->{siteconfig};
  my $table=$args{table} || "Categories";
  my $level=defined($args{level}) ? int($args{level}) : 0;

  ##
  # What we were called for?
  #
  my $obj=$self->object;
  if($args{select})
   { my $c=Symphero::Categories->new(dbh=>$config->dbh);
     my @list=$c->select(%args);
     $obj->display(path => $args{"select.path"},
                   template => $args{"select.template"},
                   LEVEL => $level);
     if(@list)
      { foreach my $cat (sort {$a->{description} cmp $b->{description}} @list)
         { my $cur=$args{current} && $cat->{id} == $args{current} ? " SELECTED" : "";
           $obj->display(path => $args{"option.path"},
                         template => $args{"option.template"},
                         SELECTED => $cur,
                         VALUE => $cat->{id},
                         DESCRIPTION => $cat->{description});
         }
      }
     else
      { $obj->display(path => $args{"empty.path"},
                      template => $args{"empty.template"},
                     );
      }
     $self->textout(text => "</SELECT>", objargs => \%args);
     return;
   }

  ##
  # Showing category name?
  #
  elsif($args{showname})
   { my $cdb=Symphero::Categories->new(dbh => $config->dbh);
     my $cat=$cdb->category(id => $args{showname});
     $self->textout(text => $cat->{description} || $cat->{name},
                    objargs => \%args);
     return;
   }

  ##
  # Showing master name?
  #
  elsif(defined($args{showpath}))
   { my $cdb=Symphero::Categories->new(dbh => $config->dbh);
     my $id=$args{showpath};
     return unless $id;
     my $catpath='';
     while($id)
      { my $cat=$cdb->category(id => $id);
        if($cat)
         { my $name=$cat->{description} || $cat->{name};
           $catpath="::" . $catpath if $catpath;
           $catpath=$name.$catpath;
           $id=$cat->{master};
         }
        else
         { $id=0;
         }
      }
     $self->textout(text => $catpath, objargs => \%args);
     return;
   }

  ##
  # Unknown mode of operations
  #
  else
   { eprint "Objects::Category syntax error";
   }
}

##
# That's it
#
1;
