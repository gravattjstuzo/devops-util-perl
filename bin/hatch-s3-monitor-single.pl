#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Time::Piece;
use Time::Seconds;

###### CONSTANTS ######

use constant OK       => 0;
use constant WARNING  => 1;
use constant CRITICAL => 2;
use constant UNKNOWN  => 3;

###### GLOBALS ######

use vars qw(
  $AwsProfile
  $ScanDays
  $S3Uri
  $FilePrefix
  %Found
  $Now
);

###### MAIN ######

parse_cmd_line();

$Now = Time::Piece->new;

#my @cmd = "s3://hatch-cap-data/production/";
my $cmd = "aws s3 ls $S3Uri";
$cmd .= " --profile $AwsProfile" if $AwsProfile;
my @output = `$cmd`;
exit UNKNOWN if $?;

%Found = newDict();

foreach my $line (@output) {

	chomp $line;

	if ( $line =~ /.txt$/ ) {
		my @a        = split( /\s+/, $line );
		my $fileName = pop @a;
		processFileName($fileName);
	}
}

my @crit;
my @warn;

foreach my $date ( keys %Found ) {

	my $aref = $Found{$date};
	if ( !@$aref ) {
		push @crit, "missing extract for $date";
	}
	elsif ( @$aref > 1 ) {
		push @warn, sprintf "found multiple extracts for $date (%s)",
		  join( ', ', @$aref );
	}
}

if (@crit) {
	printf "CRITICAL:  %s\n", join( "\n", @crit );
	exit CRITICAL;
}
elsif (@warn) {
	printf "WARNING: %s\n", join( "\n", @warn );
	exit WARNING;
}

say "OK";
exit OK;

###### END MAIN ######

sub processFileName {

	my $fileName = shift;

	my @fileNameParts = split( /_/, $fileName );
	my $dateStamp     = pop @fileNameParts;
	my $prefix        = join '_', @fileNameParts;

	if ( $prefix eq $FilePrefix ) {
		my $parsedDate     = substr( $dateStamp, 0, 8 );
		my $extractDate    = Time::Piece->strptime( $parsedDate, '%Y%m%d' );
		my $extractDateStr = $extractDate->date;
		if ( exists $Found{$extractDateStr} ) {
			push @{ $Found{$extractDateStr} }, $fileName;
		}
	}
}

sub newDict {

	my %new;

	for ( my $i = 1 ; $i <= $ScanDays ; $i++ ) {
		my $prev = $Now - ( ONE_DAY * $i );
		$new{ $prev->date } = [];
	}

	return %new;
}

sub check_required {
	my $opt = shift;
	my $arg = shift;

	print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
	my $help;

	GetOptions(
		"d=s"    => \$ScanDays,
		'f=s'    => \$FilePrefix,
		'p=s'    => \$AwsProfile,
		"s=s"    => \$S3Uri,
		"help|?" => \$help
	);

	print_usage("usage:") if $help;

	check_required( '-d', $ScanDays );
	check_required( '-p', $FilePrefix );
	check_required( '-s', $S3Uri );

	if ( @ARGV != 0 ) {
		print_usage("parse_cmd_line failed");
	}
}

sub print_usage {
	print STDERR "@_\n";

	print <<"HERE";

$0    
    -d <number of days to scan>
    -f <file prefix>  (ie offer_fulfillments)
    -s <s3://uri>  (needs to be a directory)
   
    [-p <aws profile>] 
    [-?] (usage)
     
HERE

	exit UNKNOWN;
}
