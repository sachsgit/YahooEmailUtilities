package YahooEmail_Functions;
#--use lib qw(~/perl5/);
use constant::boolean;
use Cwd qw(abs_path);
use File::Basename;
use MIME::Parser;
use MIME::QuotedPrint;
use Email::Simple;
use Email::MIME::Attachment::Stripper;
use Term::ReadKey;
use Text::ASCIITable;
use Text::Trim;

my $path = dirname(abs_path($0));
my $cfile = File::Spec->catfile($path, "MyCommonFuncs.pm");
require ($cfile);

use constant DEBUG => FALSE;

sub listMailboxes {
    my $server = shift;
    my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
    my @mailBoxes = $server->mailboxes;
    my $t = Text::ASCIITable->new(
        {headingText => "Available Mailboxes"}
    );
    my $numColumns = 4;
    $t->setCols("","","","");
    $t->addRow("","","Total", $#mailBoxes);
    $t->addRowLine();
    while (@mailBoxes) {
        $t->addRow(map{ qq/"$_"/ } splice(@mailBoxes, 0, $numColumns));
    } #endwhile
    print $t;
    return;
} # end sub listMailboxes

sub listAllMailBoxes {
     my $server    = shift;
     my $showZero  = shift;
     my @mailBoxes = $server->mailboxes;
     my $t = Text::ASCIITable->new(
          {headingText => "Total Mailboxes:" . $#mailBoxes }
     );
     $t->setCols("Mailbox", "Recent", "Total");
     foreach my $box ( @mailBoxes ) {
          my ($unseen, $recent, $numMessages) = $server->status($box);
          if ($unseen != 0) {
               $t->addRow($box, $unseen, $numMessages);
          } elsif ($unseen == 0 && $showZero == TRUE) {
               $t->addRow($box, $unseen, $numMessages);
          }
     } #endfor
     print $t;
     return;
} #end sub listAllMailBoxes

sub displayMessage {
    my ($server, $id, $isSeen) = @_;
    $isSeen = TRUE unless defined($isSeen);

    if (!$server->seen( $id )) {
        print "*";
    } else {
        print " ";
        $isSeen = FALSE;
    }

    my $email = Email::Simple->new(join '', @{$server->get($id)});
    my $subject = $email->header('Subject');
    $subject = convert_subject($subject);
    $subject = convert_subject($subject);
    $subject = convert_subject($subject);
    my $from = $email->header('From');
    $from = substr($from, 0, (index($from, "<") - 1)) if ($from =~ /</);
    $from =~ s/"//g;
    $from = $email->header('From') if ($from eq "");
    my $emailBody = $email->body;

    my $url = "";
    if ($emailBody =~ /(http(?:s){0,1}:\/\/www.favoritestracker.org\/storyInfo.php\?storyID=\d+)/) {
          $url = $1;
          print "FT\n" if (DEBUG == TRUE);
    } elsif ($emailBody =~ /(http(?:s){0,1}:\/\/www\.fanfiction\.net\/s\/\d+\/\d+\/)/) {
          $url = $1;
          print "FFN\n" if (DEBUG == TRUE);
    } elsif ($emailBody =~ /(http(?:s){0,1}:\/\/www\.tthfanfic\.org\/)T-\d+\/(Story-\d+(?:-\d+){0,1}\/.*?\.htm)/
          ||
    $emailBody =~ /(http(?:s){0,1}:\/\/www\.tthfanfic\.org\/Story-\d+(?:-\d+){0,1}\/.*?\.htm)/) {
          $url = $1;
          print "TTH\n" if (DEBUG == TRUE);
    }
    $url = myCommonFuncs::trim($url);

    if (DEBUG) {
        open(OUT, ">dumpFile.txt") || die "Cannot create dumpFile.txt\n$!\n";
        print OUT $emailBody, "\n";
        close(OUT);
    }

    # Screen Size: 160 Characters
    if ($url ne "") {
        printf("[%04d] %-20s %-50s %10s %-50s\n", $id, $from, $subject, "", $url);
    } else {
        printf("[%04d] %-20s %-80s\n", $id, $from, $subject);
    }

    unseeMessage($server, $id) if ($isSeen);
} # End Sub displayMessage

sub unseeMessage {
    my $server = shift;
    my $mailID = shift;

    no warnings 'once';
    $server->unsee($mailID) || warn "Unable to mark as unread: "
          . $Net::IMAP::Simple::errstr . "\n";
} # end sub unseeMessage

sub deleteMessage {
     my ($server, $mailID, $deleteFlag) = @_;
     $deleteFlag = FALSE unless defined($deleteFlag);

     my $answer = "";
     if ($deleteFlag == TRUE || lc($deleteFlag) eq "true") {
          $answer = "y";
     } else {
          print "Shall I delete the message above? ";
          $answer = <STDIN>;
          chomp ($answer) if $answer =~ /\R$/;
     }

     if ($answer =~ /^y/i) {
          print "Deleting msg #$mailID ..." if $server->delete( $mailID );
          defined( my $deleted = $server->deleted( $mailID ) )
               or warn "\nProblem Testing for Deleted: " . $server->errstr . "\n";

          if ($deleted) {
               print " Msg #$mailID has been Deleted!\n";
          } else {
               print " Problem deleting #$mailID " . $server->errstr . "\n";
          }
     } else {
          print " Msg #$mailID was NOT been deleted!\nAnswer was: \"$answer\"\n";
     } #endif answer starts with [Yy]
} # End Sub deleteMessage

sub downloadMessage {
     my $server = shift;
     my $mailID = shift;

     my $parser = MIME::Parser->new( );
     my $entity = $parser->parse_data(join '', @{$server->get($mailID)});
     my $header = $entity->head( );

     print "Email: " . $header->get('Subject') . "\n";
     my $numParts = $entity->parts;
     my @parts    = $entity->parts;
     if ($numParts > 0) {
          foreach my $part (@parts) {
               my $type = $part->mime_type;
               print "MIME Type: $type\n";
               # my $bh   = $part->bodyhandle;
          } # End For Each Part
     } # End If Num of Parts > 0
} #end sub downloadMessage

sub getPassword {
     my $HOME = $ENV{'HOME'} || $path;
     open(IN, "$HOME/.yp") || die "Cannot open $HOME/.yp\n$!\n";
     my @lines = <IN>;
     close(IN);
     my $value = $lines[0];
     chomp($value);
     return $value;
}

sub convert_subject {
     use utf8;
     use MIME::Base64;
     use Encode;

     my $subject = $_[0];
     my $decoded_subject = "";
     my $character_set = "";
     my $encoding_type = "";
     my $encoded_subject = "";
     $_ = $subject;
     m/=\?([a-z0-9\-]+)\?([A-Z])\?(.*)\?=/gi;
     if ($1) {
          $character_set=$1;
          $encoding_type=$2;
          $encoded_subject=$3;
     } #end if
     if ($character_set eq 'utf-8' || $character_set eq 'UTF-8') {
          if ($encoding_type eq 'B') {
               $decoded_subject = decode_base64($encoded_subject);
               #my $windows_1252 = Encode::encode("Windows-1252", $decoded_subject);
               my $ISO88591 = Encode::encode("ISO-8859-1", $decoded_subject);
               my $ascii = $ISO88591;
               $ascii =~ s/=20/ /g;
               $ascii =~ s/[^[:ascii:]]//g;
               return $ascii;
          } else {
               my $ISO88591 = Encode::encode("ISO-8859-1", $encoded_subject);
               my $ascii = $ISO88591;
               $ascii =~ s/=20/ /g;
               $ascii =~ s/[^[:ascii:]]//g;
               return $ascii;
          } #end else
     } else {
          return $subject;
     } #end else
} #end sub convert_subject

sub syntax {
    print "SYNTAX: $0 -f<folderName> [options]\n";
	printf "\t%-10s\t%s\n" , "Option"  , "Description";
	printf "\t%-10s\t%s\n" , "a"      , "Show All Mail Folders";
	printf "\t%-10s\t%s\n" , "a0"     , "Show All Mail Folders Plus Zero Size Folders";
	printf "\t%-10s\t%s\n" , "u"      , "Include Seen Email in Listing";
	printf "\t%-10s\t%s\n" , "e\\d+"  , "Email ID to stop at within given Folder";
	printf "\t%-10s\t%s\n" , "f"      , "Select Folder Given Next";
	printf "\t%-10s\t%s\n" , "fF"     , "Assume Given Folder is \"Fanfiction\"";
	printf "\t%-10s\t%s\n" , "fF\\d+" , "Assume Given Folder is \"Fanfiction\" and Assign Display Limit";
	printf "\t%-10s\t%s\n" , "fZ"     , "Assume Given Folder is \"Zaxxon\"";
	printf "\t%-10s\t%s\n" , "fZ\\d+" , "Assume Given Folder is \"Zaxxon\" and Assign Display Limit";
    printf "\t%-10s\t%s\n" , "(h|\?)" , "Syntax Notes";
	printf "\t%-10s\t%s\n" , "l\\d+"  , "Assign Display Limit";
	printf "\t%-10s\t%s\n" , "o"      , "Override Display Limit of 20";
	printf "\t%-10s\t%s\n" , "r"      , "Reverse the Display Order";
	printf "\t%-10s\t%s\n" , "s\\d+"  , "Display Specific Email within Given Folder";
}
1;
### --- End of File --- ###
