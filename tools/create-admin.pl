#!/usr/bin/perl -w
#
use Digest::MD5 qw(md5_base64);
use Symphero::Utils;

my $password=shift;
unless($password)
 { print "Usage: $0 clear_text_password\n";
   exit(1);
 }
print $password, " -> ",md5_base64($password),"\n";
exit(0);
