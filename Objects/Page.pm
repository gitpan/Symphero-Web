##
# Core object. Displaying page template. Most of objects derived from it
# (actually all of them right now).
#
package Symphero::Objects::Page;
use strict;
use Carp;
use Error qw(:try);
use Symphero::Utils;
use Symphero::Templates;
use Symphero::SiteConfig;
use Symphero::PageSupport;

##
# Methods prototypes
#
sub new ($%);
sub display ($%);
sub expand ($%);
sub parse ($%);
sub object ($%);
sub parse_args ($);
sub editable ();
sub check_db ($);
sub textout ($%);
sub finaltextout ($%);
sub set_outsub ($;$);
sub dbh ($);
sub siteconfig ($);
sub cgi ($);

##
# Creating new instance of Page.
#
sub new ($%)
{ my $proto=shift;
  my $class=ref($proto) || $proto;
  my $self=get_args(\@_) || {};
  bless $self,$class;
  carp "${class}::new - do not pass 'sitename' (it's deprecated)" if $self->{sitename};
  $self->{sitename}=get_site_name();
  $self->{siteconfig}=get_site_config();
  $self;
}

##
# Displaying given template.
#
# path     => template path
# template => template text
#
sub display ($%)
{ my $self=shift;
  my $args=$self->{args}=get_args(\@_);
  my $classname=ref $self || $self;
  if(! keys %{$args})
   { eprint "$classname: No arguments given";
     return;
   }

  ##
  # Parsing template
  #
  my $page=$self->parse(path => $args->{path}, template => $args->{template});
  $page || return;

  ##
  # Template processing itself. Pretty simple, huh? :)
  #
  foreach my $item (@{$page})
   { my $text=$item->{text};

     ##
     # <%End%> is special kind of object, processing stops where it is
     # found. Suitable to cut off carriage return at the end of template
     # and to put comments inside template.
     #
     last if !defined($text) && $item->{objname} eq 'End';

     ##
     # Trying to substitute from args if possible.
     #
     $text=$args->{$item->{objname}} unless defined($text);

     ##
     # Executing object if not.
     #
     if(!defined($text))
      { my $obj;
        try
         { $obj=$self->object(objname => $item->{objname});
         }
        catch Symphero::Errors::Objects with
         { my $e=shift;
           eprint "Object loading error while processing path='$args->{path}'";
           $e->throw;
         };

        ##
        # Preparing arguments. If argument includes object references -
        # they are expanded first.
        #
        my $objargs=$item->{args};
        foreach my $a (keys %{$objargs})
         { next unless $objargs->{$a} =~ /<\%.*\%>/s;
           my %newargs=%{$args};
           $newargs{template}=$objargs->{$a};
           delete $newargs{path};
           $objargs->{$a}=$self->expand(%newargs);
         }

        ##
        # Now decoding entities from arguments. Lt, gt, amp, quot and
        # &#DEC; are supported.
        #
        map
         { s/&lt;/</sg;
           s/&gt;/>/sg;
           s/&quot;/"/sg;
           s/&#(\d+);/chr($1)/sge;
           s/&amp;/&/sg;
         } values %{$objargs};

        ##
        # Executing object
        #
        delete $self->{merge_args};
        $text=$obj->expand($objargs);

        ##
        # Was it something like SetArg object? Merging changes in then.
        #
        if($self->{merge_args})
         { @{$args}{keys %{$self->{merge_args}}}=values %{$self->{merge_args}};
         }

        ##
        # Checking if this object required to stop processing
        #
        last if $self->siteconfig->get('_no_more_output');
      }

     ##
     # Safety conversion - q for query, h - for html, s - for nbsp'ced
     # html, f - for tag fields, t - for text as is (default).
     #
     if($item->{flag} && $item->{flag} ne 't')
      { if($item->{flag} eq 'h')
         { $text=Symphero::Utils::t2ht($text)
         }
        elsif($item->{flag} eq 's')
         { $text=(defined $text && length($text)) ? Symphero::Utils::t2ht($text) : "&nbsp;";
         }
        elsif($item->{flag} eq 'q')
         { $text=Symphero::Utils::t2hq($text)
         }
        elsif($item->{flag} eq 'f')
         { $text=Symphero::Utils::t2hf($text)
         }
      }
     $self->textout($text);
   }
}

##
# Expanding given template to string.
#
# First it prepares a place in stack for new text (push) and after
# display it calls pop to give back whatever was written. The sole
# reason for all this is speed optimization - Symphero::PageSupport
# is implemented in C in quite optimal way.
#
sub expand ($%)
{ my $self=shift;
  Symphero::PageSupport::push();
  $self->display(@_);
  Symphero::PageSupport::pop();
}

##
# Parses given template and returns reference to array of the following
# structure:
#  [ { text => text }
#  , { text => text }
#  , { objname => object name
#    , args => { object args }
#    , objtext => unparsed object text
#    , flag => text (h, q, f or t)
#    }
#  , { text => text }
#  ]
#
my %parsed_cache;
sub parse ($%)
{ my ($self,%args)=@_;
  my $classname=ref $self || $self;
  if(! keys %args)
   { eprint "$classname : No arguments given";
     return undef;
   }

  ##
  # Getting template text
  #
  my $template;
  if(defined($args{template}))
   { $template=$args{template};
   }
  else
   { my $path=$args{path};
     if(! $path)
      { throw Symphero::Errors::Page ref($self)."::parse - No path given to Page object";
        return undef;
      }
     return $parsed_cache{$path} if exists($parsed_cache{$path});
     $template=Symphero::Templates::get(path => $path);
     defined($template) || throw Symphero::Errors::Page
                                 ref($self)."::parse - no template found (path=$path)";
   }

  ##
  # Checking if we do not need to parse that template.
  #
  if($self->{args}->{unparsed})
   { return [ { text => $template } ];
   }

  ##
  # Parsing
  #
  my @page;
  $template=~s/<!--(?!\/\/).*?-->//sg;
  my @parts=split('(<%|%>|"|{|})',$template);
  my $in_object=0;
  my $in_quotes=0;
  my $in_brackets=0;
  my $objtext;
  for(my $pnum=0; $pnum!=@parts; $pnum++)
   { my $part=$parts[$pnum];
     if($in_object)
      { if($in_brackets)
         { $objtext.=$part;
           if($part eq '{')
            { $in_brackets++;
            }
           elsif($part eq '}')
            { $in_brackets--;
            }
         }
        elsif($part eq '"')
         { $objtext.='"';
           if($in_quotes)
            { $in_quotes=0;
            }
           else
            { $in_quotes=1;
            }
         }
        elsif($in_quotes)
         { $objtext.=$part;
         }
        elsif($part eq '{')
         { $in_brackets++;
           $objtext.='{';
         }
        elsif($part eq '<%')
         { $in_object++;
           $objtext.=$part;
         }
        elsif($part eq '%>')
         { $in_object--;
           if(!$in_object)
            { push(@page,{ objtext => $objtext });
            }
           else
            { $objtext.=$part;
            }
         }
        else
         { $objtext.=$part;
         }
      }
     else
      { if($part eq '<%')
         { $in_object++;
           $objtext='';
         }
        else
         { push(@page,{ text => $part });
         }
      }
   }
  throw Symphero::Errors::Page ref($self).'::display - not closed object in template' if $in_object;
  foreach my $item (@page)
   { next unless defined($item->{objtext});
     if($item->{objtext} !~ /^\s*(\w[\w\.]*)(\/(\w+))?\s*(.*)$/s)
      { $item->{text}='<%';	# <%%> is just a funny way to embed <%
        delete $item->{objtext};
        next;
      }
     $item->{objname}=$1;
     $item->{flag}=$3 ? $item->{flag}=lc(substr($3,0,1)) : 't';
     $item->{args}=parse_args($4);
   }

##  ##
##  # Document structure
##  #
##  for(my $i=0; $i!=@page; $i++)
##   { print "$i) ",join(",",%{$page[$i]}),"\n";
##     if($page[$i]->{args})
##      { my $args=$page[$i]->{args};
##        foreach my $a (sort keys %{$args})
##         { print "   $a => $args->{$a}\n";
##         }
##      }
##   }

  ##
  # Storing into cache and returning
  #
  return ($parsed_cache{$args{path}}=\@page) unless exists($args{template});
  \@page;
}

##
# Creates new displayable object with inherited outsub reference.
#
sub object ($%)
{ my $self=shift;
  my $args=get_args(@_);
  Symphero::Objects->new(objname => $args->{objname} || "Page",
                         outsub => $args->{outsub} || $self->{outsub},
                         parent => $self
                        );
}

##
# States for argument parser.
#
my $SPACE=0;
my $GOT_NAME=1;
my $GOT_EQUAL=2;
my $AFTER_EQUAL=3;
my $GOT_QUOTE=4;
my $GOT_LCB=5;

##
# Pretty hairy subroutine - parsing arguments and values from text
# string into hash reference.
#
# Example:
#  $parse_args('a b=bb c="c c&quot;c" d={dd&#125; {" 123}}');
#
# will return:
#  { a => 'on',
#    b => 'bb',
#    c => 'c c"c',
#    d => 'dd} {" 123}'
#  }
#
sub parse_args ($)
{ my $str=$_[0];
  return {} unless defined($str);
  my @tokens=split(/("|=|{|}|\s)/s,$str.' ');
  my %args;

  my $state=$SPACE;
  my $name='';
  my $value='';
  my $level=0;
  foreach my $token (@tokens)
   { if($state == $SPACE)
      { $value='';
        if($token =~ /^[a-z][\w.]*$/i)
         { $name=$token;
           $state=$GOT_NAME;
         }
        elsif($token eq '' || $token =~ /\s+/)
         {
         }
        else
         { eprint "Wrong argument name - $token";
           return {};
         }
      }
     elsif($state == $GOT_NAME)
      { if($token eq '=')
         { $state=$GOT_EQUAL;
         }
        elsif($token =~ /\s+/)
         { $args{$name}='on';
           $state=$SPACE;
         }
        else
         { eprint "Syntax error 1 in arguments, token='$token'";
           return {};
         }
      }
     elsif($state == $GOT_EQUAL)
      { if($token eq '')
         { $state=$AFTER_EQUAL;
         }
        else
         { $args{$name}=$token;
           $state=$SPACE;
         }
      }
     elsif($state == $AFTER_EQUAL)
      { if($token =~ /\s+/)
         { $args{$name}='';
           $state=$SPACE;
         }
        elsif($token eq '"')
         { $state=$GOT_QUOTE;
         }
        elsif($token eq '{')
         { $state=$GOT_LCB;
           $level++;
         }
        else
         { eprint "Syntax error 2 in arguments, token='$token'";
           return {};
         }
      }
     elsif($state == $GOT_QUOTE)
      { if($token eq '"')
         { $args{$name}=$value;
           $state=$SPACE;
         }
        else
         { $value.=$token;
         }
      }
     elsif($state == $GOT_LCB)
      { if($token eq '{')
         { $level++;
           $value.=$token;
         }
        elsif($token eq '}')
         { $level--;
           if($level)
            { $value.=$token;
            }
           else
            { $args{$name}=$value;
              $state=$SPACE;
            }
         }
        else
         { $value.=$token;
         }
      }
     else
      { eprint "Wow, got into unknown state!";
      }
   }
  if($state != $SPACE)
   { eprint "Syntax error in arguments, quote was not closed";
     return {};
   }
  \%args;
} 

##
# This is overriden in all editable objects. Default is "not editable".
#
sub editable ()
{ return 0;
}

##
# Checks that we have database connection. Suitable in derived objects.
#
sub check_db ($)
{ my $self=shift;
  carp ref($self)."::check_db method is obsolete, use dbh() to get dbh";
  if($self->{siteconfig}->dbh)
   { $self->{dbh}=$self->{siteconfig}->dbh;
     return 1;
   }
  my $class=ref $self || $self;
  eprint "$class need database connection";
  return 0;
}

##
# Return database handler or throws error if it is not available.
#
sub dbh ($)
{ my $self=shift;
  return $self->{dbh} if $self->{dbh};
  $self->{dbh}=$self->{siteconfig}->dbh;
  return $self->{dbh} if $self->{dbh};
  throw Symphero::Errors::Page ref($self)." requires database connection";
}

##
# Return database CGI or throws error if it is not available.
#
sub cgi ($)
{ my $self=shift;
  return $self->siteconfig->cgi;
}

##
# Returns site configuration reference. Recommended instead of using
# '$self->{siteconfig}'.
#
sub siteconfig ($)
{ my $self=shift;
  $self->{siteconfig};
}

##
# Displays text using stored outsub.
# Arguments are:
#  text => text to display.
#  objargs => object->display() arguments.
#
# It is recommended to call textout as textout($text) instead of
# textout(text => $text) that is kept only for compatibility.
#
sub textout ($%)
{ my $self=shift;
  if(@_ == 1)
   { if($self->{outsub})
      { &{$self->{outsub}}(text => $_[0]);
      }
     else
      { Symphero::PageSupport::addtext($_[0]);
      }
   }
  else
   { my %args=@_;
     if($self->{outsub})
      { &{$self->{outsub}}(\%args);
      }
     else
      { Symphero::PageSupport::addtext($args{text});
      }
   }
}

##
# Outputs some text and stops processing templates on all levels. No more
# objects should be called in this session and no more text should be
# printed.
#
# Used in Redirect object to return asap.A
#
sub finaltextout ($%)
{ my $self=shift;
  $self->textout(@_);
  $self->siteconfig->session_specific('_no_more_output');
  $self->siteconfig->put(_no_more_output => 1);
}

##
# Set output subroutine to the supplied.
#
sub set_outsub ($;$)
{ my $self=shift;
  my $newos=shift;
  my $oldos=$self->{outsub};
  $self->{outsub}=$newos;
  $oldos;
}

##
# Returns base_url for secure or normal connection. Depends on parameter "secure" if
# it is set, or current state, if it is not.
#
sub base_url ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $url;
  my $secure=$args->{secure};
  $secure=$self->cgi->https() ? 1 : 0 unless defined $secure;
  if($secure)
   { $url=$self->siteconfig->get('base_url_secure');
     if(!$url)
      { $url=$self->siteconfig->get('base_url');
        $url=~s/^http:/https:/i;
      }
   }
  else
   { $url=$self->siteconfig->get('base_url');
   }
  $url;
}

##
# Returns full URL of current page without parameters
#
sub pageurl ($;%)
{ my $self=shift;
  my $url=$self->base_url(@_);
  my $url_path=$self->siteconfig->get('pagedesc')->{fullpath};
  $url_path="/".$url_path unless $url_path=~ /^\//;
  $url.$url_path;
}

##
# Error to be thrown from displayable objects.
#
package Symphero::Errors::Page;
use Error;
use vars qw(@ISA);
@ISA=qw(Error::Simple);

##
# That's it
#
use vars qw($VERSION);
($VERSION)=(q$Id: Page.pm,v 1.1 2001/02/27 04:06:15 amaltsev Exp $ =~ /(\d+\.\d+)/);
1;
