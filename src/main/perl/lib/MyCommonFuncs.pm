package myCommonFuncs;
use strict;

use Data::Dump qw(dump);
use Encode;
use File::Copy qw(copy);
use File::Type;
use File::stat;
use HTML::Entities();
use HTML::TableExtract;
use HTML::TreeBuilder::XPath qw();
use HTTP::Cookies::Netscape;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use IPC::System::Simple qw(capturex);
use LWP::Simple qw($ua get);
use LWP::Simple qw($ua head);
use Lingua::ENG::Numbers qw(American);
use Lingua::ENG::Word2Num;
use Number::Format qw(:subs);
use Roman;
use Scalar::Util qw(looks_like_number);
use Switch;
use Text::Unidecode;
use XML::XPath::XMLParser;
use constant::boolean;
use MIME::Detect;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;

# g/\(\w\+\); # \(\w\+\)$/s//\2; # \1/
use constant DEBUG         => FALSE; # TRUE
use constant DEBUG_CLEANUP => FALSE; # TRUE
use constant DEBUG_DECODE  => FALSE; # TRUE
use constant DEBUG_DUMP    => TRUE;
use constant DEBUG_HEAD    => FALSE; # TRUE
use constant DEBUG_ISCOM   => FALSE; # TRUE

use constant USER_AGENT_STRING => "Mozilla/5.0"
    . " (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    . " (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36";

sub trim {
     my $word = shift;
     $word =~ s/^\s+//g;
     $word =~ s/\s+$//g;
     return $word;
} # End Sub trim

sub padChar {
     my ($strVal, $padValue) = @_;

     print STDERR __LINE__ . ": \$padValue is \"${padValue}\"\n"
          . "\$strVal is \"${strVal}\"\n" if (DEBUG == TRUE);
     $strVal = sprintf("%0${padValue}d", $strVal);

     while (length($strVal) > $padValue) {
          $strVal = substr($strVal, 2) if (substr($strVal, 1, 1) eq "0" );
          $strVal = substr($strVal, 2) if (substr($strVal, 1, 1) eq " " );
     } # End If
     return $strVal;
} # End Sub padChar

sub displayTF {
     my $boolean = shift;
     return "TRUE" if ($boolean == TRUE);
     return "FALSE";
} # End Sub displayTF

sub dumpFile {
    my $value = shift;
    my $outFile = "testData.txt";
    unlink($outFile) if -e $outFile;
    open (OUT, ">$outFile") || die "Cannot write to $outFile\n$!\n";
    print OUT dump($value) . "\n";
    close(OUT);
} # End Sub dumpFile

sub geturl {
    my $url = shift;
    die "No URL to retrieve" unless defined $url;

    my $ua = LWP::UserAgent->new;
    $ua->agent( USER_AGENT_STRING );
    $ua->cookie_jar(
        HTTP::Cookies->new(
                file => 'mycookies.txt',
                autosave => 1
        )
    );
    my $req = GET $url;
    my $res = $ua->request($req);

    if ($res->is_success) {
        my $contents = $res->decoded_content;
        $contents = narrow_char($contents);
        dumpContents($contents) if (DEBUG_DUMP == TRUE);
        return $contents;
    } else {
        dumpContents($res->decoded_content);
        print "Status Line: " . $res->status_line . "\n";
    }
}

sub geturl_old {
     my $myUrl = shift;
     die "No URL to retrieve" unless defined $myUrl;

     my $ua = LWP::UserAgent->new;

     # Firefox 55.0
     my $myAgent = "Mozilla/5.0 (Android 4.4; Tablet; rv:41.0)"
          . " Gecko/41.0 Firefox/55.0";

     $ua->agent($myAgent);
     $ua->timeout(30);
     #$ua->env_proxy;

     my $headerResponse = $ua->head($myUrl);
     print STDERR __LINE__ . ": Status: " . $headerResponse->status_line
          . "\n" if (DEBUG_HEAD == TRUE);

     my $response = $ua->get($myUrl);

     warn "Couldn't get contents of \"$myUrl\"\n" unless defined $response;

     my $contents = "";
     if ($response->is_success && $response->content ne "") {
          $contents = $response->content;
          $contents = decode('utf-8', $contents);
          dumpContents($contents) if (DEBUG_DUMP == TRUE);
          return ($contents);
     } elsif (!$response->is_success) {
          die "GetUrl returns \"" . $response->status_line() . "\"\n"
               . "URL: \"" . $myUrl . "\"\n";
     } else {
          print STDERR __LINE__ . ": Using lynx instead of "
               . "LWP::UserAgent\n" if DEBUG == TRUE;
          my $lynxcmd = capturex("which", "lynx");
          $lynxcmd = trim($lynxcmd);
          die "Cannot find lynx on system\n" if $lynxcmd eq "";
          my @arParams;
          $arParams[0] = "-dump";
          $arParams[1] = "-source";
          $arParams[2] = $myUrl;
          $contents = capturex($lynxcmd, @arParams);
          $contents = decode('utf-8', $contents);
          dumpContents($contents) if (DEBUG_DUMP == TRUE);
          return $contents;
     } # End If-ElsIf-Else

     if ($contents =~ /class='errortext'>Age Consent Required/) {
         $response = $ua->get($myUrl . "&ageconsent=ok&warning=4");
         $contents = $response->content;
         $contents = decode('utf-8', $contents);
     } elsif ($contents =~ /This work could have adult content. If you proceed you have agreed that you are willing to see such content./) {
         $response = $ua->get($myUrl . "?view_adult=true");
         $contents = $response->content;
         $contents = decode('utf-8', $contents);
         if (DEBUG_DUMP == TRUE) {
             print "Dumping Contents ...";
             dumpContents($contents);
             print " ... dumped.\n";
         }
     }
     print STDERR __LINE__ . ": Size of content is " . length($contents) . "\n"
          if (DEBUG_DECODE == TRUE);
     return ($contents);
} # End Sub geturl_old

sub isComplete {
     my ($lines, $chpt) = @_;

     print "Checking for completeness\n" if (DEBUG_ISCOM == TRUE);

     if ($lines =~ /http(s)?:\/\/(www\.)?tthfanfic/i) {
          print STDERR __LINE__ . " TTH found\n" if (DEBUG_ISCOM == TRUE);
          my $te = HTML::TableExtract->new( headers => [
               qw(Chapters Complete)] );
          (my $utf8lines = $lines) =~ s/([^[\x20-\x7F])/"&#" . ord($1) . ";"/eg;
          print STDERR __LINE__ . " Size: " . length($lines) . " Size: " .
               length($utf8lines) . "\n" if (DEBUG_ISCOM == TRUE);
          $te->parse($utf8lines);
          my $ts = $te->first_table_found;
          my $numChpts = trim($ts->cell(0,0));
          my $isComplete = trim($ts->cell(0,1));
          if (DEBUG_ISCOM == TRUE) {
               print STDERR __LINE__ . " \$numChpts is \"$numChpts\"\n";
               print STDERR __LINE__ . " \$chpt is \"$chpt\"\n";
               print STDERR __LINE__ . " \$isComplete is \"" .
                    displayTF($isComplete) . "\"\n";
          } # End If DEBUG_ISCOM is TRUE
          return TRUE if ($isComplete eq 'Yes');
     } elsif ($lines =~ /http(s)?:\/\/(www\.)?fanfiction\.net/i
               && $lines !~ /adult-fanfiction/i) {
          print STDERR __LINE__ . ": FFN found\n" if (DEBUG_ISCOM == TRUE);
          my @lines = split /\n/, $lines;
          my @NotFound = grep /<hr size=1 noshade>Chapter not found./, @lines;
          print STDERR __LINE__ . ": \$#NotFound: $#NotFound\n" if (DEBUG_ISCOM == TRUE);
          return FALSE if $#NotFound == 0;

          @NotFound = grep /Story not found/, @lines;
          print STDERR __LINE__ . ": \$#NotFound: $#NotFound\n" if (DEBUG_ISCOM == TRUE);
          return FALSE if $#NotFound == 0;

          my $lastChpt = 1;
          my $isComplete = FALSE;
          print STDERR __LINE__ . ": Length of \$lines " . length($lines) . "\n"
               if (DEBUG_ISCOM == TRUE);
          my $tree = new HTML::TreeBuilder::XPath->new;
          $tree->parse($lines);
          my @Status = $tree->findnodes('//span[@class="xgray'
              . ' xcontrast_txt"]');
          print STDERR __LINE__ . ": Status Count: $#Status\n" if (DEBUG_ISCOM == TRUE);
          my $myStatus = ($Status[0]->as_HTML || $Status[0]);
          if ($myStatus =~ /(Status: Complete)/) {
               print STDERR __LINE__ . " $1\n" if (DEBUG_ISCOM == TRUE);
               $isComplete = TRUE;
          }
          $lastChpt = $1 if ($lines =~ /Chapters: (\d+)/);
          if (DEBUG_ISCOM == TRUE) {
               print STDERR __LINE__ . " \$lastChpt is \"$lastChpt\"\n";
               print STDERR __LINE__ . " \$chpt is \"$chpt\"\n";
               print STDERR __LINE__ . " \$isComplete is \"" .
                    displayTF($isComplete) . "\"\n";
          }
          return TRUE if ($isComplete == TRUE);
     } elsif ($lines =~ /ficwad/i) {
         print STDERR __LINE__ . " FW Found\n" if (DEBUG_ISCOM == TRUE);
         my $lastChpt = 1;
         my $tree = new HTML::TreeBuilder::XPath->new;
         $tree->parse($lines);
         my @chpts = $tree->findnodes('//div[@class="chapterform"]'
              . '/form/select/option');
         $lastChpt = (($#chpts + 1)/2) - 1 if ($lines =~
              /<div class="chapterform"/);
         print STDERR __LINE__ . " \$lastChpt is \"$lastChpt\"\n"
              . "\$chpt is \"$chpt\"\n"
              if (DEBUG_ISCOM == TRUE);
         return TRUE if ($lines =~
             /\d+&nbsp;words\s+-\s+Complete<\/p>/);
     } # End if

     return FALSE
} #-- end isComplete

sub cleanup {
     my $name = shift;

     while ($name =~ s/([a-z])([A-Z])/$1 $2/g) { };
     $name =  HTML::Entities::decode($name);
     $name =~ s/#&(\d+);/&#$1;/g;
     $name =  unidecode($name);
     $name =~ s/\s{2,}/ /g;
     $name =~ s/ /_/g;
     $name =~ s/\//_/g;
     $name =~ s/[!?]//g;
     $name =~ s/\+/_/g;
     $name =~ s':'+'g;
     $name =~ s/&/_and_/g;
     $name =  $1 . ",_The" if ($name =~ /^The_(.*)/);
     $name =~ s/_{2,}/_/g;
     $name =~ s/([0-9]+)([a-z]+)\./$1.\u$2./g;
     $name =~ s/\.([a-z])/.\u$1/g;
     $name =~ s/([A-Z][A-Z]+)/\L\u$1/g;
     $name =~ s/\.([a-z]+)\./.\u$1./g;
     $name =~ s/(^[a-z])/\u$1/g;
     $name =~ s/([-_][a-z])/\U$1/g;
     $name =~ s/[^A-Za-z0-9_\.\-\+,"'\(\)]/_/g;
     while ($name =~ s/_(The|And|A|Of|An)_/_\L$1\E_/g) { };

     $name =~ s/Bt_Vs/BtVS/;
     $name =~ s/Btvs/BtVS/;
     $name =~ s/Sg-1/SG-1/;

     my @arWords = split('_', $name);
     for (my $i = 0; $i <= $#arWords; $i++) {
          my $word    = $arWords[$i];
          print STDERR __LINE__ . ": \$word is \"$word\"\n"
               if (DEBUG_CLEANUP == TRUE);

          if (looks_like_number($word) && $word !~ /\d+\.\d+/) {
               $word =~ s/(\d+)\.$/$1/;
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
               my $n = new Lingua::ENG::Numbers($word);
               $word = $n->get_string;
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
          } elsif ($word =~ /(\d+)'s/) {
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
               my $n = new Lingua::ENG::Numbers($1);
               $word = $n->get_string . "'s";
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
          } elsif ($word =~ /\((\d+)\)/) {
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
               my $n = new Lingua::ENG::Numbers($1);
               $word = "(" . $n->get_string . ")";
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
          } elsif ($word =~ /(\d+)([:+])/) {
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
               my $n = new Lingua::ENG::Numbers($1);
               $word = $n->get_string . $2;
               print STDERR __LINE__ . ": \$word is \"$word\"\n"
                    if (DEBUG_CLEANUP == TRUE);
          }

          my $roman = "";
          ($roman = $word) =~ s/\W//;
          $word = uc($word) if (isroman($roman));

          if ($i == 0) {
               $name = $word;
          } else {
               $name .= "_" . $word;
          }
     } # End For Each Word
     return $name;
} # End Sub Cleanup

sub dumpContents {
    my $mime = MIME::Detect->new();
	my $myContents = shift;

    my $outFile = "tmpfile_" . $$ . "_" . getTimeStamp();
    my $ft = File::Type->new();
    my $type = $ft->mime_type($myContents);

	open(TEMP,">$outFile") || die "Cannot open $outFile for writing\n";
	print TEMP dump($myContents) . "\n";
	close(TEMP);

    my $t = $mime->mime_type($outFile);
    $t = $t ? $t->mime_type : "<unknown>";
    print "Created $outFile, Type: $type, Mime-Type: $t\n";
} # End Sub dumpContents

sub getTimeStamp {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) 
        = localtime(time);
    my $ts = sprintf("%04d%02d%02d_%02d%02d%02d", $year+1900, $mon+1,
        $mday, $hour, $min, $sec);
    return $ts;
}

sub narrow_char {
    $_[0] =~ s/(.)/chr(ord($1)>>8)/eg
      if (length($_[0]) * 3 == do { use bytes; length $_[0] } );
    $_[0]; 

}

### -- End of Subroutines --- ###
###
1;
### -- End of File --- ###
