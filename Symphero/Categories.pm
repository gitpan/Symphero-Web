##
# Container and selector for categories.
# Stores data in SQL tables of the following structure:
# CREATE TABLE Categories
# ( id INT NOT NULL PRIMARY KEY auto_increment,	// category id
#   level INT NOT NULL,				// level of subcategoring
#   parent INT NOT NULL,			// id of previous level
#   name CHAR(40),				// name of this level
#   description CHAR(100),			// category description
#   UNIQUE(level,parent,name)
# );
#
# Depends on auto_increment feature of the database. Must be changed if
# database doesn't support it.
#
package Symphero::Categories;
use strict;
use Symphero::Utils;

##
# Prototypes
#
sub new ($%);
sub select ($%);
sub category ($%);
sub master_category ($%);

##
# Creating object, remembering table name to use.
#
# table => table name (default is Categories)
# dbh   => database handler (mandatory)
#
sub new ($%)
{ my ($class,%args)=@_;
  if(!$args{dbh})
   { eprint "Symphero::Categories - no database handler given";
     return undef;
   }
  my $self={ table => $args{table} || "Categories"
           , dbh   => $args{dbh}
           };
  bless $self,ref $class || $class;
}

##
# Looks up categories in the database by some fields known.
#
#  $c->select(name0 => 'Name 0', name1 => 'Name 1');
#  $c->select(namepath => 'Category::Sub1::Sub2');
#  $c->select(master => 123);
#
# In case name path points to the exact category without any
# subcategories -- this category ID is returned in scalar
# context and empty list otherwise.
#
sub select ($%)
{ my ($self,%args)=@_;
  my $level=0;
  my $master=0;
  my $namepath="";

  ##
  # If we have master's id - everything is simple
  #
  if($args{master})
   { $master=$args{master};
     $level=$args{level} || 0;
   }

  ##
  # Otherwise searching by name
  #
  elsif($args{namepath} || $args{name0})
   { if($args{namepath})
      { my $level=0;
        foreach my $name (split("::",$args{namepath}))
         { $args{"name".$level}=$name;
           $level++;
         }
      }

     ##
     # Going through the tree
     #
     while($args{"name$level"})
      { my $sth=$self->{dbh}->prepare("SELECT id FROM $self->{table}" .
                                      " WHERE parent=? AND name=?");
        if(!$sth || !$sth->execute($master,$args{"name$level"}))
         { eprint "SQL: ",$self->{dbh}->errstr;
           return undef;
         }
        my $id=($sth->fetchrow_array())[0];
        return undef unless $id;
        $namepath.="::" if $namepath;
        $namepath.=$args{"name$level"};
        $master=$id;
        $level++;
      }
   }

  ##
  # Selecting categories
  #
  my $sth=$self->{dbh}->prepare("SELECT id,level,name,description" .
                                " FROM $self->{table} WHERE parent=$master");
  if(!$sth || !$sth->execute())
   { eprint "SQL: ",$self->{dbh}->errstr;
     return undef;
   }
  my @list;
  while(my @row=$sth->fetchrow_array())
   { my %cat;
     @cat{qw(id level name description master namepath)}=(@row,$master,$namepath);
     $cat{description}=$namepath."::".$cat{name} unless $cat{description};
     push(@list,\%cat);
   }
  return $master unless @list || wantarray;
  @list;
}

##
# Loads category description by known ID.
#
#  $c->category(id => 123);
#
sub category ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $id=$args->{id};
  if(!$id)
   { eprint ref($self)."::category called with unknown id!";
     return undef;
   }
  my $sth=$self->{dbh}->prepare("SELECT level,name,description,parent" .
                                " FROM $self->{table} WHERE id=$id");
  if(!$sth || !$sth->execute())
   { eprint "SQL: ",$self->{dbh}->errstr;
     return undef;
   }
  my $row=$sth->fetchrow_arrayref();
  return undef unless $row;
  my %cat;
  @cat{qw(id level name description master)}=($id,@{$row});
  \%cat;
}

##
# Returns description of master (top level category)
#
sub master_category ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $id=$args->{id};
  if(!$id)
   { eprint ref($self)."::master_category called without id!";
     return undef;
   }
  my $cinfo=$self->category(id => $id);
  while($cinfo && $cinfo->{master})
   { $cinfo=$self->category(id => $cinfo->{master});
   }
  $cinfo;
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=('$Id: Categories.pm,v 1.1 2001/02/28 02:50:44 amaltsev Exp $' =~ /(\d+\.\d+)/);
1;
