#!%PERL% -w
#
use strict;
use Getopt::Long;
use Symphero::Utils;
use Symphero::CryptoUtils;
use Symphero::CryptoDB;
use DBI;
use DBD::mysql;

##
# Prototypes
#
sub help ();

my $database;
my $user;
my $password;
my @encrypt;
my @decrypt;
my $keyfile;
my $key;
my $help;
my $table;
my $genkeys;

GetOptions( 'help|?'		=> \$help
          , 'db|database=s'	=> \$database
          , 'user=s'		=> \$user
          , 'password=s'	=> \$password
          , 'table=s'		=> \$table
          , 'encrypt=s'		=> \@encrypt
          , 'decrypt=s'		=> \@decrypt
          , 'key-file=s'	=> \$keyfile
          , 'key-text=s'	=> \$key
          , 'generate-keys=i'	=> \$genkeys
          , 'debug|verbose'	=> sub { set_debug(1); }
          , 'quiet'		=> sub { set_debug(0); }
          );

help if $help || !$database;

dprint "Connecting to the database";
my $dbh=DBI->connect("DBI:mysql:$database",$user,$password);
die "SQL error" unless $dbh;

dprint "Creating Symphero::CryptoDB instance";
my $cdb=Symphero::CryptoDB->new(dbh => $dbh);
die "SQL error" unless $dbh;

if($genkeys)
 { my $keys=$cdb->generate_keys($genkeys);
   if($keys)
    { print <<EOT;
=========================================================== Public key ==
$keys->{public_key_text}
=========================================================== Secret key ==
$keys->{secret_key_text}
=========================================================================
EOT
      exit(0);
    }
   eprint "Keys cannot be generated";
   exit(1);
 }
elsif(@encrypt)
 { foreach my $text (@encrypt)
    { my $id=$cdb->encrypt($text);
      print "$id - $text\n";
    }
 }
elsif(@decrypt && ($key || $keyfile))
 { if($keyfile)
    { open(F,$keyfile) || die "Can't open $keyfile: $!\n";
      $key=join('',<F>);
      close(F);
    }
   $key=convert_base64_to_sk($key);
   if(!$key)
    { eprint "Cannot restore key!";
      exit(1);
    }
   foreach my $id (@decrypt)
    { print "$id - ",$cdb->decrypt(key => $key, id => $id),"\n";
    }
 }
else
 { help;
   exit(1);
 }
exit(0);

#========================================================

sub END
{ $dbh->disconnect if $dbh;
}

sub help ()
{ print STDERR <<EOH;
Usage:
 --db=DBNAME		database name, required
 --user=USER		database user (optional)
 --password=USER	database password (optional)
 --table=TABLE		table name (default is CryptoData)

 --generate-keys=BITS	generates new pair of keys, default is 1024 bits

 --encrypt=TEXT		text to be encrypted

 --decrypt=ID		entry ID to be decrypted
 --key-file=PATH	path to secret key file
 --key-text=BASE64	base64 text of secret key

Examples:
 $0 --db test --encrypt "test text"
 $0 --db test --key-file test/secret-key --decrypt JH78UY34 --decrypt 32DF874E
EOH
  exit(1);
}
