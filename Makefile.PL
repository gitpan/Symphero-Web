use ExtUtils::MakeMaker;

##
# Package version
#
my $version='0.3';

##
# Trying to find out current configuration. If it is saved in file -
# retrieving and asking otherwise.
#
my $homedir;
my $ask=0; ## grep(/^ASK(=1)?$/,@ARGV);
if(open(F,".config"))
 { while(<F>)
    { next unless /^(\w+)\s+(.*?)[\s\r\n]+$/s;
      my ($cmd,$value)=($1,$2);
      if($cmd eq 'homedir')
       { $homedir=$value;
       }
    }
   close(F);
 }
$ask=1 unless $homedir;
while($ask)
 { if(!$homedir)
    { eval { require Symphero::Defaults };
      $homedir=$Symphero::Defaults::homedir unless $@;
    }
   $homedir='/usr/local/symphero' unless $homedir;
   print <<EOT;
Symphero::Web needs a directory to store its templates, tools, CGI-BIN
executables and other useful stuff. All your sites would also be stored
(or sym-linked to) inside of this directory.

EOT
   print "Directory name ? [$homedir] ";
   (my $hd=<STDIN>) =~ s/[\s\n\r]//sg;
   if($hd && substr($hd,0,1) ne '/')
    { print "\nBad path ($hd)!\n\n";
      next;
    }
   $homedir=$hd if $hd;

   print <<EOT;

The following directory structure will be used:
$homedir/bin       - various tools
$homedir/cgi-bin   - CGI scripts
$homedir/projects  - projects root directory
$homedir/templates - default templates

EOT
   print "Is that OK? [Y/n] ";
   (my $answer=<STDIN>) =~ s/[\s\r\n]//sg;
   next if lc(substr($answer,0,1)) eq 'n';

   open(F,"> .config") || die "Cannot write .config: $!\n";
   print F "homedir $homedir\n";
   print F "version $version\n";
   close(F);
   $ask=0;
   print "\n";
 }

WriteMakefile( 'AUTHOR'		=> 'Andrew Maltsev <am@xao.com>'
             , 'ABSTRACT'	=> 'Web templating system'
             , 'NAME'		=> 'Symphero::Web'
             , 'VERSION'	=> $version
             , 'PREREQ_PM'	=> { 'CGI' => '2.46'
				   , 'DBI' => '1.14'
				   , 'Digest::MD5' => '2.12'
				   , 'Error' => '0.13'
				   , 'Mail::Sender' => '0.7'
				   , 'Symphero::MultiValueDB' => '1.1'
                                   , 'Symphero::SimpleHash' => '1.1'
                                   , 'Symphero::Utils' => '1.1'
				   },
             , 'INSTALLBIN'	=> $homedir . '/bin'
             , 'INSTALLSCRIPT'	=> $homedir . '/cgi-bin'
             , 'PL_FILES'	=> { 'Defaults.PL' => '$(INST_LIB)/Symphero/Defaults.pm'
                                   }
             );

sub MY::postamble
{ <<EOT;

install::
	\@chmod 700 ./install-templates
	\@./install-templates $homedir
	\@echo
	\@echo "Please read the Symphero::Web manpage for usage instructions."
	\@echo
	\@echo "Good luck!"
	\@echo

devsite::
	\@ln -s -f ../templates devsite/templates
	\@ln -s -f ../blib/bin devsite/bin
	\@if [ ! -d devsite/projects ]; then \\
		mkdir devsite/projects; \\
		chmod 755 devsite/projects; \\
		ln -s -f ../../docsite devsite/projects; \\
	fi
	\@if [ ! -d devsite/cgi-bin ]; then \\
		mkdir devsite/cgi-bin; \\
	fi
	\@\$(PERL) DevSite.PL devsite/cgi-bin/symphero.pl
	\@\$(PERL) -MFile::Find -e 'find(sub { my \$\$n=\$\$File::Find::name; chmod(0755,\$\$n) if -d \$\$n; chmod(0644,\$\$n) if -f \$\$n; },"templates","docsite")'
	\@chmod 755 .
	\@echo
	\@echo "'Devsite' directory has been successfully set up."
	\@echo
	\@echo "Make sure web server can access data in devsite - chmod 755 all"
	\@echo "directories in the path."
	\@echo
	\@echo "Read devsite/README for more details."
	\@echo
EOT
}
