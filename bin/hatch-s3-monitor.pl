#!/usr/bin/env perl

# vim: tabstop=4 expandtab

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Time::Piece;
use Time::Seconds;
use Stuzo::Hatch::Extract;

###### CONSTANTS ######

use constant OK       => 0;
use constant WARNING  => 1;
use constant CRITICAL => 2;
use constant UNKNOWN  => 3;

use constant EXTRACTS => qw(
  locations
  locations_offers
  marketing_contents
  membership_point_transactions
  memberships
  memberships_offers
  offer_fulfillments
  offers
  redemptions
  rewards
  transaction_line_items
  transactions
  users
);

###### GLOBALS ######

use vars qw(
  $AwsProfile
  $ScanDays
  $S3Uri
  %Inv
  $Now
  $IgnoreWarnings
  $IgnoreCriticals
);

###### MAIN ######

parseCmdLine();

$Now = Time::Piece->new;

my $cmd = "aws s3 ls $S3Uri";
$cmd .= " --profile $AwsProfile" if $AwsProfile;
my @output = `$cmd`;
exit UNKNOWN if $?;

#
# build expected file inventory map
#
foreach my $extractName (EXTRACTS) {
	$Inv{$extractName} = newDict();
}

foreach my $line (@output) {

	chomp $line;

	my $fileName = extractFileName($line);
	my ( $extractName, $dateStamp, $suffix ) = parseFileName($fileName);

	if ( $suffix =~ /^txt$/i ) {
		if ( wantExtract($extractName) ) {
			my $extractDateStr = parseDate($dateStamp);
			if ( wantDate($extractDateStr) ) {
				my $dateMapHref = $Inv{$extractName};
				push @{ $dateMapHref->{$extractDateStr} }, $fileName;
			}
		}
	}
}

#
# print results
#
my @crit = getCriticals();
my @warn = getWarnings();

if ( @crit and !$IgnoreCriticals ) {
	printf "CRITICAL:  %s\n", join( "\n", @crit );
	exit CRITICAL;
}
elsif ( @warn and !$IgnoreWarnings ) {
	printf "WARNING: %s\n", join( "\n", @warn );
	exit WARNING;
}

say "OK";
exit OK;

###### END MAIN ######

sub getWarnings {

	my @warn;

	foreach my $extractName ( keys %Inv ) {
		my $dateMap = $Inv{$extractName};
		foreach my $dateStr ( keys %$dateMap ) {
			my $aref = $dateMap->{$dateStr};
			if ( @$aref > 1 ) {
				push @warn,
				  sprintf( "found multiple extracts for $extractName (%s)",
					join( ', ', @$aref ) );
			}
		}
	}

	return @warn;
}

sub getCriticals {

	my @crit;

	foreach my $extractName ( keys %Inv ) {
		my $dateMap = $Inv{$extractName};
		foreach my $dateStr ( keys %$dateMap ) {
			my $aref = $dateMap->{$dateStr};
			if ( !@$aref ) {
				push @crit, "missing extract for $extractName ($dateStr)";
			}
		}
	}

	return @crit;
}

sub wantExtract {

	my $extractName = shift;

	state %map;

	if ( !keys %map ) {
		foreach my $extract (EXTRACTS) {
			$map{$extract} = 1;
		}
	}

	if ( $map{$extractName} ) {
		return 1;
	}

	return 0;
}

sub extractFileName {

	my $line = shift;

	my @parts    = split( /\s+/, $line );
	my $fileName = pop @parts;

	return $fileName;
}

sub parseFileName {

	my $fileName = shift;

	# extract suffix from $fileName
	my @parts  = split( /\./, $fileName );
	my $suffix = pop @parts;
	$fileName = join( '.', @parts );

	# extract datestamp from $fileName
	@parts = split( /_/, $fileName );
	my $dateStamp = pop @parts;
	$fileName = join '_', @parts;

	# set extract name
	my $extractName = $fileName;

	return ( $extractName, $dateStamp, $suffix );
}

sub parseDate {

	my $dateStamp = shift;

	my $parsedDate  = substr( $dateStamp, 0, 8 );
	my $extractDate = Time::Piece->strptime( $parsedDate, '%Y%m%d' );

	return $extractDate->date;
}

sub wantDate {

	my $dateStr = shift;

	state %dates;
	if ( !keys %dates ) {

		# build cache
		%dates = %{ newDict() };
	}

	if ( $dates{ $dateStr } ) {
		return 1;
	}

	return 0;
}

sub newDict {

	my %new;

	for ( my $i = 1 ; $i <= $ScanDays ; $i++ ) {
		my $prev = $Now - ( ONE_DAY * $i );
		$new{ $prev->date } = [];
	}

	return \%new;
}

sub checkRequired {
	my $opt = shift;
	my $arg = shift;

	printUsage("missing arg $opt") if !$arg;
}

sub parseCmdLine {
	my $help;

	GetOptions(
		"d=s"              => \$ScanDays,
		'p=s'              => \$AwsProfile,
		"s=s"              => \$S3Uri,
		'ignore-warnings'  => \$IgnoreWarnings,
		'ignore-criticals' => \$IgnoreCriticals,
		"help|?"           => \$help
	);

	printUsage("usage:") if $help;

	checkRequired( '-d', $ScanDays );
	checkRequired( '-s', $S3Uri );

	if ( $IgnoreWarnings and $IgnoreCriticals ) {
		die "--ignore-warnings and --ignore-criticals are mutually exclusive";
	}

	if ( @ARGV != 0 ) {
		printUsage("parseCmdLine failed");
	}
}

sub printUsage {
	print STDERR "@_\n";

	print <<"HERE";

$0    
    -d <number of days to scan>
    -s <s3://uri>  (needs to be a directory)
   
    [-p <aws profile>] 
    [--ignore-warnings]
    [--ignore-criticals]
    [-?] (usage)
     
HERE

	exit UNKNOWN;
}
