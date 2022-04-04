#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Time::Piece;
use Time::Seconds;
use DBI;
use Util::Medley::Logger;

###### CONSTANTS ######

use constant OK       => 0;
use constant WARNING  => 1;
use constant CRITICAL => 2;
use constant UNKNOWN  => 3;

use constant DEFAULT_HOST   => 'localhost';
use constant DEFAULT_DBNAME => 'activate_core_production';
use constant DEFAULT_PORT   => 5432;

###### GLOBALS ######

use vars qw(
  $Host
  $DbName
  $Port
  $Dbh
  $Logger
);

###### MAIN ######

$Logger = Util::Medley::Logger->new;

parse_cmd_line();

my $dsn = sprintf "dbi:Pg:host=%s;dbname=%s;port=%d", $Host, $DbName, $Port;
$Dbh = DBI->connect( $dsn, '', '', { AutoCommit => 1 } );

my $sql = qq{
	select
        count(id) as record_count,
        abs(sum(quantity)) as point_volume
    from
        membership_point_transactions
    where
        created_at between ? and ? and
        source_type = 'Chain'
    group by
        source_type
};
	
my $now = Time::Piece->new;
my $prev = $now - ONE_DAY - ONE_HOUR;

$now = sprintf "%s %s", $now->date, $now->time;
$prev = sprintf "%s %s", $prev->date, $prev->time;

$Logger->verbose("start $prev");
$Logger->verbose("end $now");

my ($cnt, $vol) = $Dbh->selectrow_array($sql, undef, $prev, $now);
$cnt = 0 if !defined $cnt;
$vol = 0 if !defined $vol;

$Logger->verbose("count: $cnt");
$Logger->verbose("vol: $vol");

if ($cnt < 1) {
    printf "CRITICAL:  %s\n", "no records found";	
	exit CRITICAL;
}

say "OK ($cnt records)";
exit OK;

###### END MAIN ######

sub check_required {
	my $opt = shift;
	my $arg = shift;

	print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
	my $help;

	GetOptions(
		"h=s"    => \$Host,
		"d=s"    => \$DbName,
		"p=s"    => \$Port,
		"help|?" => \$help
	);

	print_usage("usage:") if $help;

	#	check_required( '-h', $Host );

	$Host   = DEFAULT_HOST   if !$Host;
	$DbName = DEFAULT_DBNAME if !$DbName;
	$Port   = DEFAULT_PORT   if !$Port;

	if ( @ARGV != 0 ) {
		print_usage("parse_cmd_line failed");
	}
}

sub print_usage {
	print STDERR "@_\n";

	print <<"HERE";

$0    
    [-h <host>]   
    [-d <dbname>]
    [-p <port>]
    
    [-?] (usage)
     
HERE

	exit UNKNOWN;
}
