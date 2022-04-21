#!/usr/bin/perl -w -I/home/sachss/bin -IJ:\Macro\Perl -I.
#--#!/usr/pkg/bin/perl -w -I/sdf/arpa/tz/z/zaxxon/bin
use strict;
#--use lib qw(~/perl5/);
use constant::boolean;
use Net::IMAP::Simple;
use Email::Simple;
use Switch;
use File::Spec;

my $path  = ".";
my $cfile = File::Spec->catfile( $path, "lib", "YahooEmail_Functions.pm" );
require($cfile);

use constant DEBUG => FALSE;

my $username = "sachss200x";
my $password = YahooEmail_Functions::getPassword();

my $mailFolder = "";
my $mailID     = "";
my @mailIDs;
my @sortedMailIDs;

if ($#ARGV < 1) {
    die "SYNTAX: $0 <mailFolder> <MailID>\n";
} else {
    while ($#ARGV > -1) {
        switch ($ARGV[0]) {
            case qr/^-f$/   { $mailFolder = $ARGV[1]; shift; }
            case qr/^-fF$/  { $mailFolder = "Fanfiction";    }
            case qr/^-fZ$/  { $mailFolder = "Zaxxon";        }
            case qr/^\d+$/  { $mailID     = $ARGV[0];        }
            case qr/^-g$/   { shift;
                while ($#ARGV > -1 && $ARGV[0] =~ /^\d+$/) {
                    push @mailIDs, $ARGV[0];
                    shift;
                } #end while
               @sortedMailIDs = sort {$b <=> $a} @mailIDs;
               @mailIDs = @sortedMailIDs;
            } #endcase
		  else { die "Unknown option \"$ARGV[0]\"\n"; }
        } #endswitch
        shift;
    } #endwhile
} # End Else


if (DEBUG == TRUE) {
	print "\$mailFolder: \"$mailFolder\"\n";
	print "\$mailID____: \"$mailID\"\n";
	print "\@mailIDs___: \"@mailIDs\"\n";
} #endif

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
     $server->quit;
     exit -1;
}
my $numMsgs = $server->select( $mailFolder )
     || die "Could not select Folder \"$mailFolder\"" . $server->errstr;
print "Folder $mailFolder has $numMsgs messages.\n";

if ($mailID ne "") {
     YahooEmail_Functions::displayMessage($server, $mailID);
     YahooEmail_Functions::deleteMessage($server, $mailID);
} else {
    for (my $i = 0; $i <= $#mailIDs; $i++) {
        YahooEmail_Functions::displayMessage($server, $mailIDs[$i]);
        YahooEmail_Functions::deleteMessage($server, $mailIDs[$i]);
    } #endfor
}

$server->quit;
exit 0;
### --- End of Main --- ###
