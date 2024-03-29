##
# Templates retriever. Uses inter-process persistent cache in shared
# memory to store once retrieved templates.
# Cache top level keys are site names, for system templates '/' is used as
# a site name.
#
package Symphero::Templates;
use strict;
use Symphero::Defaults qw($homedir $projectsdir);
use Symphero::Utils;
use Symphero::SiteConfig;

##
# Cache for templates.
#
my %cache;

##
# Getting the text of given template.
#
sub get (%)
{ my %args=@_;
  my $path=$args{path};
  my $sitename=get_site_name();
  if($path =~ /\.\.\//)
   { eprint "Bad template path -- sitename=",$sitename,", path=$path";
     return undef;
   }

  ##
  # Checking in the memory cache
  #
  return $cache{$sitename}->{$path} if exists($cache{$sitename}) && exists($cache{$sitename}->{$path});
  return $cache{'/'}->{$path} if exists($cache{'/'}) && exists($cache{'/'}->{$path});

  ##
  # Retrieving from disk.
  #
  my $system;
  my $tpath;
  if(defined $sitename)
   { $tpath="$projectsdir/$sitename/templates/$path";
     $system=0;
   }
  if(! $tpath || ! -r $tpath)
   { $tpath="$homedir/templates/$path";
     $system=1;
   }
  local *F;
  return undef unless open(F,$tpath);
  my $text=join("",<F>);
  close(F);

  ##
  # Storing into cache. And return code is hidden here also.
  #
  $cache{$system ? '/' : $sitename}->{$path}=$text;
}

##
# Checking the existence of given template.
#
sub check (%)
{ my %args=@_;
  my $path=$args{path};
  my $sitename=get_site_name();
  if($path =~ /\.\.\//)
   { eprint "Bad template path -- sitename=",$sitename,", path=$path";
     return 0;
   }
  return 0 if !defined($path) || $path eq '';
  return 1 if defined($sitename) && -r "$projectsdir/$sitename/templates/$path";
  return 1 if -r "$homedir/templates/$path";
  return 0;
}

##
# Complete list of all available templates in random order.
#
# Returns list in array context and array reference in scalar context.
#
sub list (%)
{ my %args=@_;
  my $tpath;
  my $sitename=get_site_name();
  if(defined $sitename)
   { $tpath="$projectsdir/$sitename/templates/";
   }
  if(! $tpath || ! -r $tpath)
   { $tpath="$homedir/templates/";
   }
  if(! $tpath || ! -r $tpath)
   { eprint "Templates::list - can't get list";
     return wantarray ? () : undef;
   }
  local *F;
  if(!open(F,"/usr/bin/find $tpath -type f |"))
   { eprint "Templates::list - can't get list: $!\n";
     return wantarray ? () : undef;
   }
  my @list=map { chomp; s/^$tpath//; $_ } <F>;
  close(F);
  wantarray ? @list : (@list ? \@list : undef);
}

##
# That's it
#
use vars qw($VERSION);
($VERSION)=('$Id: Templates.pm,v 1.2 2001/03/01 02:48:14 amaltsev Exp $' =~ /(\d+\.\d+)/);
1;
