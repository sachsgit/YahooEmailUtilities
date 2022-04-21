#!/usr/bin/perl -w -I/home/sachss/bin -IE:\Macro\Perl
#--#!/usr/pkg/bin/perl -w -I/sdf/arpa/tz/z/zaxxon/bin
use strict;
#--use lib qw(~/perl5/);
use constant::boolean;
use Net::IMAP::Simple;
use Email::Simple;
use Switch;
use Lingua::EN::Numbers qw(num2en);
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::Spec qw( catfile );

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
my $mailSearch   = "";

my $deleteFlag   = FALSE;
my $forceFlag    = FALSE;
my $downloadFlag = FALSE;

while ($#ARGV > -1) {
    switch($ARGV[0]) {
        case qr/^-d$/     { $deleteFlag   = TRUE;                                  }
        case qr/^-f$/     { $mailFolder   = $ARGV[1]; shift;                       }
        case qr/^-fF$/    { $mailFolder   = "Fanfiction";                          }
        case qr/^-fZ$/    { $mailFolder   = "Zaxxon";                              }
        case qr/^-g$/     { $downloadFlag = TRUE;                                  }
        case qr/^-o$/     { $forceFlag    = TRUE;                                  }
        case qr/^-r$/     { $mailSearch   .= "SEEN ";                              }
        case qr/^-sb$/    { $mailSearch   .= 'OR BODY "' . $ARGV[1] . '"'
                             . ' SUBJECT "' . $ARGV[1] . '" '; shift;              }
        case qr/^-sf$/    { $mailSearch   .= 'FROM "' . $ARGV[1] . '" '; shift;    }
        case qr/^-ss$/    { $mailSearch   .= 'SUBJECT "' . $ARGV[1] . '" '; shift; }
        case qr/^-ssFT$/  { $mailSearch   .= 'SUBJECT "Favorites Tracker" ';       }
        case qr/^-u$/     { $mailSearch   .= "UNSEEN ";                            }
        else { die "Unknown option: \"$ARGV[0]\"\n";                               }
    } #endswitch
    shift;
} #endwhile
$mailSearch = myCommonFuncs::trim($mailSearch);

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
     print "Searching $mailFolder for \"$mailSearch\"\n";
     my @arIDs = $server->search( $mailSearch );
     my $strMatch = "";
     switch ($#arIDs) {
         case -1 { $strMatch = "no matches"; }
         case 0  { $strMatch = "one match"; }
         else    { $strMatch = num2en($#arIDs + 1) . " matches"; }
     } #endswitch
     print "There are $strMatch found.\n";
     for my $id ( sort {$b <=> $a} @arIDs ) {
     	YahooEmail_Functions::displayMessage($server, $id);
          YahooEmail_Functions::downloadMessage($server, $id)
               if ($downloadFlag == TRUE);
     	YahooEmail_Functions::deleteMessage($server, $id, $deleteFlag)
			if ($deleteFlag == TRUE);
     } #endfor
     print "End Search.\n";
} # End If MailFolder Not Empty
$server->quit;
exit 0;
### --- End of Main --- ###
### --- End of File --- ###
