##
# Pretty interesting object -- allows to include different other objects
# depending on conditions.
#
# Used like this:
#  <%Condition NAME1.value="<%CgiParam param=test%>"
#              NAME1.path="/bits/test-is-set"
#              NAME2.cgiparam="foo"
#              NAME2.path="/bits/foo-is-set"
#              NAME3.siteconf="product_list"
#              NAME3.template="product_list exists in siteconfig"
#              default.objname="Error"
#              default.template="No required parameter set"
#
#  %>
#
# Which means to execute /bits/test-is-set if CGI has `test'
# parameter, otherwise execute /bits/foo-is-set if `foo' parameter
# is set and finally, if there is no foo and no test - execute
# /bits/nothing-set. For `foo' shortcut is used, because most of the
# time you will check for CGI parameters anyway.
#
# Default object to be substituted is Page. Another object may be
# specified with objname. All arguments after NAMEx. are just passed
# into object without any processing.
#
# NAME1 and NAME2 may be anything, they sorted alphabetycally before
# checking. So, usually if there is only one check and default - then
# something meaningful is used for the name. For multiple choices just
# numbers are better for names.
#
# Condition checked in perl style - '0' and empty string is false.
#
# Hides itself from object it executes - makes parent and parent_args
# pointing to Condition's parent.
#
# Supports the following conditions:
#  value - just constant value, usually substituted in template itself
#  cgiparam - parameter in CGI
#  arg - parent object argument
#  siteconf - site configuration parameter
#  cookie - cookie value
#
# All values are treated as boolean only, no comparision is implemented
# yet.
#
package Symphero::Objects::Condition;
use strict;
use Symphero::Utils;
use Symphero::Objects;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => "Page");

##
# Displaying conditional object.
#
sub display ($;%)
{ my $self=shift;
  my %args=%{get_args(\@_) || {}};
  my $config=$self->siteconfig;

  ##
  # First going through the list of conditions and checking them.
  #
  my $name;
  foreach my $a (sort keys %args)
   { next unless $a =~ /^(\w+)\.(number|value|arg|cgiparam|siteconf|siteconfig|cookie)$/;
     if($2 eq 'cgiparam')
      { my $param=$args{$a};
        my $cname=$1;
        if($param =~ /\s*(.*?)\s*=\s*(.*?)\s*$/)
         { my $pval=$config->cgi->param($1);
           if(defined($pval) && $pval eq $2)
            { $name=$cname;
              last;
            }
         }
        else
         { if($config->cgi->param($param))
            { $name=$cname;
              last;
            }
         }
      }
     elsif($2 eq 'arg')
      { if($self->{parent} && $self->{parent}->{args}->{$args{$a}})
         { $name=$1;
           last;
         }
      }
     elsif($2 eq 'siteconf' || $2 eq 'siteconfig')
      { if($config->get($args{$a}))
         { $name=$1;
           last;
         }
      }
     elsif($2 eq 'cookie')
      {  if($config->cgi->cookie($args{$a}))
          { $name=$1;
             last;
          }    
      }
     elsif($2 eq 'number')
      { if(($args{$a} || 0)+0)
         { $name=$1;
           last;
         }    
      }
     elsif($args{$a})	# value
      { $name=$1;
        last;
      }
   }
  $name="default" unless defined $name;

  ##
  # Building object arguments now.
  #
  my %objargs;
  foreach my $a (keys %args)
   { if($self->{parent} && $self->{parent}->{args} && $a =~ /^$name\.(\w.*)\.pass$/)
      { $objargs{$1}=$self->{parent}->{args}->{$1};
      }
     elsif($a =~ /^$name\.(\w.*)$/)
      { $objargs{$1}=$args{$a};
      }
   }
  return unless %objargs;

  ##
  # Now getting object and executing it.
  #
  my $obj=$self->object(objname=>$objargs{objname} || "Page");
  delete $objargs{objname};
  $obj->display(%objargs);
}

##
# That's it
#
1;
