#!/usr/bin/perl -w -I/home/sachss/bin -IJ:\Macro\Perl
#--#!/usr/pkg/bin/perl -w -I/sdf/arpa/tz/z/zaxxon/bin
use strict;
#--use lib qw(~/perl5/);
use constant::boolean;
use Cwd qw(abs_path);
use File::Basename;
use Net::IMAP::Simple;
use Email::Simple;
use Switch;

my $path = dirname(abs_path($0));
my @arMods = (
    File::Spec->catfile($path, "lib", "MyCommonFuncs.pm"),
    File::Spec->catfile($path, "lib", "YahooEmail_Functions.pm")
);
foreach my $mod ( @arMods ) {
     require ($mod);
} # end foreach mod

use constant DEBUG => FALSE;

my $username   = "sachss200x\@yahoo.com";
my $password   = YahooEmail_Functions::getPassword();

my $mailFolder = "";
my $mailID     = "";
my $mailIDEnd  = "";
my $limit      = 200;
my $override   = FALSE;
my $reverse    = FALSE;
my $showAll    = FALSE;
my $showSeen   = FALSE;
my $showZero   = FALSE;

while ($#ARGV > -1) {
    switch($ARGV[0]) {
        case qr/^-a$/     { $showAll    = TRUE; }
        case qr/^-a0$/    { $showAll    = TRUE; $showZero = TRUE; }
        case qr/^-u$/     { $showSeen   = TRUE; }
        case qr/^-e\d+/   { $mailIDEnd  = substr($ARGV[0], 2); }
        case qr/^-f$/     { $mailFolder = $ARGV[1]; shift; }
        case qr/^-fF$/    { $mailFolder = "Fanfiction"; }
        case qr/^-fF\d+$/ { $mailFolder = "Fanfiction"; $limit = substr($ARGV[0], 3); }
        case qr/^-fZ$/    { $mailFolder = "Zaxxon"; }
        case qr/^-fZ\d+$/ { $mailFolder = "Zaxxon"; $limit = substr($ARGV[0], 3); }
        case qr/^-(h|\?)$/ { YahooEmail_Functions::syntax(); exit -3; }
        case qr/^-l\d+/   { $limit      = substr($ARGV[0], 2); }
        case qr/^-o$/     { $override   = TRUE; }
        case qr/^-r$/     { $reverse    = TRUE; }
        case qr/^-s\d+/   { $mailID     = substr($ARGV[0], 2); }
        else {
            print "Unknown option: \"$ARGV[0]\"\n";
            exit -1;
        }
    } #endswitch
    shift;
}
$mailIDEnd = $mailID if ($mailIDEnd eq "");

my $server = Net::IMAP::Simple->new(
     'imap.mail.yahoo.com:993',
     use_ssl => TRUE)
     || die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";

if (!$server->login($username, $password)) {
    print STDERR "Login Failed: " . $server->errstr . "\n";
    $server->quit;
    exit(1);
} # End If Logon Failed

if ($showAll == TRUE) {
     YahooEmail_Functions::listAllMailBoxes( $server, $showZero );
} elsif ($mailFolder eq "") {
     YahooEmail_Functions::listMailboxes( $server );
} else {
     my $numMsgs = $server->select( $mailFolder )
          || die "Could not select Folder \"$mailFolder\"\n" 
               . $server->errstr . "\n";
     my ($unseen, $recent, $num_messages) = $server->status($mailFolder);

     print "\$numMsgs______: \"$numMsgs\"\n"
         . "\$num_messages_: \"$num_messages\"\n" 
          if ($numMsgs != $num_messages);

     print "\$unseen_: \"$unseen\"\n"
         . "\$recent_: \"$recent\"\n"
         . "\$numMsgs: \"$numMsgs\"\n"
          if (DEBUG == TRUE);
     
     print "Folder \"$mailFolder\" has \"$unseen\" unread message and"
        . " total of \"$num_messages\"\n";
     
     if ($mailID eq "") {
         if ($unseen > $limit && $override == FALSE) {
             print "Limiting \$unseen to \"$limit\", was \"$unseen\"\n";
             $unseen = $limit;
         } #endif unseen greater than $limit
         my $endPoint = $numMsgs - $unseen;
         $endPoint = $numMsgs - $limit if ($showSeen == TRUE);
         if ($reverse == FALSE) {
	         for (my $i = $numMsgs; $i > $endPoint; $i--) {
	               YahooEmail_Functions::displayMessage($server, $i);
	         } # End For Each Email
         } elsif ($reverse == TRUE) {
	         for (my $i = 1; $i < $endPoint; $i++) {
	               YahooEmail_Functions::displayMessage($server, $i);
	         } # End For Each Email
         }
     } elsif ($mailIDEnd ne "") {
         if ($reverse == TRUE) {
	         for (my $id = $mailID; $id < $mailIDEnd; $id++) {
	             YahooEmail_Functions::displayMessage($server, $id);
	         } #endfor
         } else {
	         for (my $id = $mailIDEnd; $id >= $mailID; $id--) {
	             YahooEmail_Functions::displayMessage($server, $id);
	         } #endfor
         }
     } else {
         YahooEmail_Functions::displayMessage($server, $mailID);
     } #end else
} # End If MailFolder Not Empty
$server->quit;
exit 0;
### --- End of Main --- ###
