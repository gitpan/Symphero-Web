##
# This is Content object - named container for some externally defined
# data. Provides easy way for customers to edit page content in
# pre-specified places.
#
package Symphero::Objects::Content;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Displaying content object. For now it simply retrieves content from
# SQL table and displays it.
#
sub display ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $name=$args->{name};
  if(!defined($name))
   { eprint "Objects::Content - name is required";
     return;
   }
  my $sth=$self->dbh->prepare("SELECT content FROM Content WHERE name=?");
  if(!$sth || !$sth->execute("".$name))
   { eprint "Objects::Content - SQL error";
     return;
   }
  my $content=($sth->fetchrow_array)[0];
  if($args->{parse})
   { my %a=%{$args};
     $a{template}=$content;
     delete $a{path};
     $self->object->display(\%a);
   }
  else
   { $self->textout(text => $content, objargs => $args);
   }
}

##
# This is editable object
#
sub editable (%)
{ return 1;
}

##
# Editing object properties. Called after check_db, so we can safely
# assume presence of sitename, siteconfig, cgi and dbh.
#
# Uses two templates:
#  path.edit - editing template, default is /admin/bits/editobject/Content-edit
#  path.done - final message, default is /admin/bits/editobject/Content-done
#
sub edit ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $cgi=$self->siteconfig->cgi;
  my $dbh=$self->dbh;

  ##
  # Loading page content
  #
  my $objargs=$args->{objargs};
  my $name=$args->{name} || $objargs->{name};
  throw Symphero::Errors::Page "No name given to content editor" unless $name;
  my $sth=$dbh->prepare("SELECT content,description FROM Content WHERE name=?");
  $sth && $sth->execute(''.$name) || throw Symphero::Errors::Page "Objects::Content - SQL error";
  my ($content,$desc)=$sth->fetchrow_array();

  ##
  # We already have new values?
  #
  my $suffix="edit";
  my $newcontent=$cgi->param("content");
  my $newdesc=$cgi->param("description");
  if(defined($newcontent) && defined($newdesc))
   { if(defined($content) || defined($desc))
      { $sth=$dbh->prepare("UPDATE Content SET description=?, content=? WHERE name=?");
      }
     else
      { $sth=$dbh->prepare("INSERT INTO Content (description,content,name) VALUES (?,?,?)");
      }
     $sth && $sth->execute("".$newdesc,"".$newcontent,"".$name) ||
      throw Symphero::Errors::Page "Objects::Content - SQL error";
     $content=$newcontent;
     $desc=$newdesc;
     $suffix="done";
   }

  ##
  # Getting template path
  #
  my $path=$args->{'path.' . $suffix} || "/admin/bits/editobject/$self->{objname}-$suffix";

  ##
  # Displaying
  #
  $self->object->display( path => $path,
                          OBJNAME => $self->{objname},
                          NAME => $name,
                          DESCRIPTION => $desc || '',
                          CONTENT => $content || '',
                          PAGEURL => $cgi->url,
                          PAGEPATH => $args->{pagepath} || '',
                          OBJNUM => $args->{objnum} || '',
                          %{$args}
                        );
}

##
# That's it
#
1;
