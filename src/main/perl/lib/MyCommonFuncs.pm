package myCommonFuncs;
use strict;

use Cwd;
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
use constant DEBUG_DUMP    => FALSE; # TRUE
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

sub getSecret {
     my $path = $ENV{'HOME'} || getcwd();
     my $sourceFile = "${path}/../resources/.ak";
     open(IN, $sourceFile) || die "Cannot open $sourceFile\n$!\n";
     my @lines = <IN>;
     close(IN);
     my $value = $lines[0];
     chomp($value);
     return $value;
}

### -- End of Subroutines --- ###
###
1;
### -- End of File --- ###
