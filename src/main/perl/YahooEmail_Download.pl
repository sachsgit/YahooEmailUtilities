#!/usr/bin/perl -w -I/home/sachss/bin -IJ:\Macro\Perl
#--#!/usr/pkg/bin/perl -w -I/sdf/arpa/tz/z/zaxxon/bin
use strict;
#--use lib qw(~/perl5/);
use Cwd qw(abs_path);
use File::Basename;
use constant::boolean;
use Net::IMAP::Simple;
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

# Help from http://www.perlmonks.org/?node_id=1133987

my $username   = "sachss200x";
my $password   = YahooEmail_Functions::getPassword();

my $mailFolder = "";
my $mailID     = "";
my $override   = FALSE;
my @mailIDs;
my @sortedMailIDs;

if ($#ARGV == -1) {
    die "SYNTAX: $0 (-f <mailFolder>|[<mailID>])\n";
} else {
    while ($#ARGV > -1) {
        switch($ARGV[0]) {
            case qr/^-f$/  { $mailFolder = $ARGV[1]; shift; }
            case qr/^-fF$/ { $mailFolder = "Fanfiction";    }
            case qr/^-fZ$/ { $mailFolder = "Zaxxon";        }
            case qr/\d+/   { $mailID     = $ARGV[0];        }
            case qr/^-g$/  { shift;
                while ($#ARGV > -1 && $ARGV[0] =~ /^\d+$/) {
                    push @mailIDs, $ARGV[0];
                    shift;
                } #end while
               @sortedMailIDs = sort {$b <=> $a} @mailIDs;
               @mailIDs = @sortedMailIDs;
            } #endcase
            case qr/^-o$/ { $override = TRUE;              }
		  else { die "Unknown option \"$ARGV[0]\"\n"; }
        } #endswitch
        shift;
    } #endwhile
} #end else

if (DEBUG) {
    print "\$mailFolder: \"${mailFolder}\"\n";
    print "\$mailID____: \"${mailID}\"\n";
} # if DEBUG

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
     my $numMsgs = $server->select( $mailFolder );
     my ($unseen, $recent, $num_messages) = $server->status($mailFolder);
     
     if ($mailID eq "") {
         if ($#mailIDs > 0) {
             for (my $i = 0; $i <= $#mailIDs; $i++) {
                 if (!$server->seen( $mailIDs[$i] ) && $override == FALSE) {
                     YahooEmail_Functions::downloadMessage($server, $mailIDs[$i]);
                 } elsif ($override == TRUE) {
                     YahooEmail_Functions::downloadMessage($server, $mailIDs[$i]);
                 } # End IF New Email
             }
         } else {
             my $endPoint = $numMsgs - $unseen;
             for (my $i = $numMsgs; $i > $endPoint; $i--) {
                 if (!$server->seen( $i ) && $override == FALSE) {
                     YahooEmail_Functions::downloadMessage($server, $i);
                 } elsif ($override == TRUE) {
                     YahooEmail_Functions::downloadMessage($server, $i);
                 } else {
                     print "Message #" . $i . " was seen. Skipping.\n";
                 }
             } # End Foreach Mail
         } #end Else
     } else {
          YahooEmail_Functions::downloadMessage($server, $mailID);
     }
} # end else
$server->quit();

exit 0;
### --- End of Main --- ###
### --- Begin of Subroutines --- ###
### --- End of Subroutines --- ###
### --- End of File --- ###
