#!/usr/bin/perl -w -I/home/sachss/bin -IJ:\Macro\Perl
#--#!/usr/pkg/bin/perl -w -I/sdf/arpa/tz/z/zaxxon/bin
use strict;
#--use lib qw(~/perl5/);

use constant::boolean;
use Net::IMAP::Simple;
use Email::Simple;
use Switch;

my $path = dirname(abs_path($0));
my @arMods = (
    File::Spec->catfile($path, "MyCommonFuncs.pm"),
    File::Spec->catfile($path, "YahooEmail_Functions.pm")
);
foreach my $mod ( @arMods ) {
     require ($mod);
} # end foreach mod

use constant DEBUG => FALSE;

my $username     = "sachss200x";
my $password     = YahooEmail_Functions::getPassword();

my $mailFolder   = "";
my $mailID       = "";
my $mailEndPoint = "";

if ($#ARGV == -1) {
    die "SYNTAX: $0 <mailFolder>\n";
} else {
    while ($#ARGV > -1) {
        switch ($ARGV[0]) {
            case qr/^-id$/ { $mailID       = $ARGV[1]; shift; }
            case qr/^-e$/  { $mailEndPoint = $ARGV[1]; shift; }
            case qr/^-f$/  { $mailFolder   = $ARGV[1]; shift; }
            case qr/^-fF$/ { $mailFolder   = "Fanfiction";    }
            case qr/^-fZ$/ { $mailFolder   = "Zaxxon";        }
            else           { die "Unknown switch: \"$ARGV[0]\"\n"; }
        } #endswitch
        shift;
    } #endwhile
} #endelse

if (DEBUG) {
	print "\$mailFolder__: \"$mailFolder\"\n";
	print "\$mailID______: \"$mailID\"\n";
	print "\$mailEndPoint: \"$mailEndPoint\"\n";
} #end debug

my $server = Net::IMAP::Simple->new(
     'imap.mail.yahoo.com:993',
     use_ssl => TRUE)
     || die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";

if (!$server->login($username, $password)) {
    print STDERR "Login Failed: " . $server->errstr . "\n";
    exit(1);
} # End If Logon Failed

if ($mailFolder eq "") {
    YahooEmail_Functions::listMailboxes($server);
} else {
     my $numMsgs = $server->select( $mailFolder )
          || die "Could not select Folder \"$mailFolder\"" . $server->errstr;
     if ($mailID eq "") {
          my $endPoint = $numMsgs - $mailEndPoint;
          for (my $i = $numMsgs; $i > $endPoint; $i--) {
               YahooEmail_Functions::unseeMessage($server, $i);
               YahooEmail_Functions::displayMessage($server, $i);
          } # End For Each Email
     } else {
          YahooEmail_Functions::unseeMessage($server, $mailID);
          YahooEmail_Functions::displayMessage($server, $mailID);
     }
} #endelse
$server->quit;
exit 0;
### --- End of Main --- ###
### --- Begin Subroutines --- ###
### --- End Subroutines --- ###
### --- End of File --- ###
