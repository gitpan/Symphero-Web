##
# Various small utility functions for templates. Like time converting,
# selectors, mathematic and so on.
#
package Symphero::Objects::Utility;
use strict;
use Symphero::Utils;

##
# Inheritance
#
use vars qw(@ISA);
@ISA=Symphero::Objects->load(objname => 'Action');

##
# Processing modes.
#
sub check_mode ($$)
{ my $self=shift;
  my $args=get_args(\@_);
  my $mode=$args->{mode};
  if($mode eq "convert-time")
   { $self->convert_time($args);
   }
  elsif($mode eq "select-time-range")
   { $self->select_time_range($args);
   }
  elsif($mode eq "tracking-url")
   { $self->tracking_url($args);
   }
  elsif($mode eq "config-param")
   { $self->config_param($args);
   }
  elsif($mode eq "pass-cgi-params")
   { $self->pass_cgi_params($args);
   }
  elsif($mode eq "current-url")
   { $self->show_current_url($args);
   }
  elsif($mode eq "base-url")
   { $self->show_base_url($args);
   }
  elsif($mode eq "show-pagedesc")
   { $self->show_pagedesc($args);
   }
  else
   { throw Symphero::Errors::Page ref($self)."::check_mode - Unknown mode '$mode'";
   }
}

##
# Converting time from various formats to unix time.
# Arguments are:
#  mode => 'convert-time'
#  result => [ min | max ]
#  quarter => YYYY-N
#  month => YYYY-MM
#  year => YYYY
#
# For example the result of:
#  <%Utility mode="convert-time" result="min" quarter="1999-3"%>
# would be something like 91231239 - first second of third quarter of
# 1999.
#
sub convert_time ($%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Getting the range.
  #
  my $min;
  my $max;
  throw Symphero::Errors::Page ref($self)."::convert_time is not implemented";
}

##
# Displays <OPTION> list for time range.
#
sub select_time_range ($%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # Checking type of range
  #
  my $type=$args->{type};
  if($type eq 'quarters')
   { ##
     # Start date
     #
     my $year;
     my $quarter;
     if($args->{start})
      { my ($y,$q)=($args->{start} =~ /^(\d+)\D+(\d+)$/);
        if($y>1000 && $q>0 && $q<5)
         { $year=$y;
           $quarter=$q;
         }
        else
         { eprint "Bad year ($y) or quarter ($q) in '$args->{start}'";
         }
      }
     if(!$year)
      { $year=2000;	# Kind of birthday of Symphero :)
        $quarter=1;
      }
     my $lastyear;
     my $lastquarter;
     if($args->{end})
      { my ($y,$q)=($args->{end} =~ /^(\d+)\D+(\d+)$/);
        if($y>1000 && $q>0 && $q<5)
         { $lastyear=$y;
           $lastquarter=$q;
         }
        else
         { eprint "Bad last year ($y) or quarter ($q) in '$args->{end}'";
         }
      }
     if(!$lastyear)
      { $lastyear=(gmtime)[5]+1900;
        $lastquarter=(gmtime)[4]/3+1;
      }
     if($year>$lastyear || ($year == $lastyear && $quarter>$lastquarter))
      { eprint "Start date ($year-$quarter) is after end date ($lastyear-$lastquarter)";
        $lastyear=$year;
        $lastquarter=$quarter;
      }
     my $obj=$self->object;
     my @qq=('Jan-Mar', 'Apr-Jun', 'Jul-Sep', 'Oct-Dec');
     if($args->{ascend})
      { while($year<$lastyear || ($year==$lastyear && $quarter<=$lastquarter))
         { my $value="$year-$quarter";
           $obj->display(path => $args->{path},
                         template => '<OPTION VALUE="<%VALUE%>"<%SELECTED%>><%TEXT%>',
                         VALUE => $value,
                         SELECTED => $args->{current} && $args->{current} eq $value ? " SELECTED " : "",
                         TEXT => $year . ', ' . $qq[$quarter-1],
                         YEAR => $year,
                         QUARTER => $quarter
                        );
           $quarter++;
           if($quarter>4)
            { $quarter=1;
              $year++;
            }
         }
      }
     else
      { while($lastyear>$year || ($year==$lastyear && $lastquarter>=$quarter))
         { my $value="$lastyear-$lastquarter";
           $obj->display(path => $args->{path},
                         template => '<OPTION VALUE="<%VALUE%>"<%SELECTED%>><%TEXT%>',
                         VALUE => $value,
                         SELECTED => $args->{current} && $args->{current} eq $value ? " SELECTED " : "",
                         TEXT => $lastyear . ', ' . $qq[$lastquarter-1],
                         YEAR => $lastyear,
                         QUARTER => $lastquarter
                        );
           $lastquarter--;
           if($lastquarter<1)
            { $lastquarter=4;
              $lastyear--;
            }
         }
      }
   }
  else
   { throw Symphero::Errors::Page ref($self)."::select_time_range - unknown range type ($type)";
   }
}

##
# Displays tracking URL for given carrier and tracking number.
# Arguments are:
#  carrier => shipment carrier [ usps, ups, fedex, dhl, yellow ]
#  tracknum => tracking number
#
sub tracking_url ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $carrier=$args->{carrier};
  my $tracknum=$args->{tracknum};
  my $url;
  if(lc($carrier) eq 'usps')
   { $url='http://www.framed.usps.com/cgi-bin/cttgate/ontrack.cgi' .
          '?tracknbr=' . t2ht($tracknum);
   }
  elsif(lc($carrier) eq 'ups')
   { $url='http://wwwapps.ups.com/etracking/tracking.cgi' .
          '&TypeOfInquiryNumber=T' .
          '&InquiryNumber1=' . t2ht($tracknum);
   }
  elsif(lc($carrier) eq 'fedex')
   { $url='http://fedex.com/cgi-bin/tracking' .
          '?tracknumbers=' .  t2ht($tracknum) .
          '&action=track&language=english&cntry_code=us';
   }
  elsif(lc($carrier) eq 'dhl')
   { $url='http://www.dhl-usa.com/cgi-bin/tracking.pl' .
          '?AWB=' . t2ht($tracknum) .
          'LAN=ENG&TID=US_ENG&FIRST_DB=US';
   }
  elsif(lc($carrier) eq 'yellow')
   { $tracknum=sprintf('%09u',int($tracknum));
     $url='http://www2.yellowcorp.com/cgi-bin/gx.cgi/applogic+yfsgentracing.E000YfsTrace' .
          '?diff=protrace&PRONumber=' . t2ht($tracknum);
   }
  else
   { eprint "Unknown carrier '$carrier'";
     $url='';
   }
  $self->textout(text => $url, objargs => $args);
}

##
# Displays configuration parameter
#
sub config_param ($%)
{ my $self=shift;
  my $args=get_args(\@_);
  my $config=$self->{siteconfig};
  $args->{name} || throw Symphero::Errors::Page
                         ref($self)."::config_param - no 'name' given";
  my $value=$config->get($args->{name});
  $value=$args->{default} if !defined($value) && defined($args->{default});
  $self->textout(text => $value, objargs => $args) if defined $value;
}

##
# Builds a piece of HTML containing current CGI parameters
# Arguments are:
#  params => comma separated list of parameters
#  result => [ query | form ]
#
# Parameter names may end with '*', then all parameters metching this
# template are used.
#
sub pass_cgi_params ($%)
{ my $self=shift;
  my $args=get_args(\@_);

  ##
  # First expanding parameters in list
  #
  my @params;
  foreach my $param (split(/[,\s]/,$args->{params}))
   { $param=~s/\s//gs;
     next unless length($param);
     if(index($param,'*') != -1)
      { $param=substr($param,0,index($param,'*'));
        foreach my $p ($self->{siteconfig}->cgi->param)
         { next unless index($p,$param) == 0;
           push @params,$p;
         }
        next;
      }
     push @params,$param;
   }
  my $html;
  foreach my $param (@params)
   { $param=~s/\s//gs;
     next unless length($param);
     my $value=$self->{siteconfig}->cgi->param($param);
     next unless defined $value;
     if($args->{result} eq 'form')
      { $html.='<INPUT TYPE="HIDDEN" NAME="' . t2hf($param) . '" VALUE="' . t2hf($value) . '">';
      }
     else
      { $html.='&' if $html;
        $html.=t2hq($param) . '=' . t2hq($value);
      }
   }
  $self->textout(text => $html, objargs => $args);
}

##
# Prints out current page URL without parameters
#
sub show_current_url ($;%)
{ my $self=shift;
  $self->textout($self->pageurl);
}

##
# Prints out base URL without parameters
#
sub show_base_url ($;%)
{ my $self=shift;
  my $args=get_args(\@_);
  $self->textout($self->base_url(secure => $args->{secure}));
}

##
# Prints out base URL without parameters
#
sub show_pagedesc ($)
{ my $self=shift;
  my $args=get_args(\@_);
  my $name=$args->{name} || 'fullpath';
  $self->textout($self->siteconfig->get('pagedesc')->{$name} || '');
}

##
# That's it
#
1;
