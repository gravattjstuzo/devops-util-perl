#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Stuzo::AWS::EC2;
use Text::Table;

###### CONSTANTS ######

#use constant EXCLUDE_PROFILES_DEFAULT => qw(stuzo);

###### GLOBALS ######

use vars qw(
  @ExcludeProfiles
  $EC2
  $IncludeProfilesRe
  $ExcludeProfilesRe
);

###### MAIN ######

parseCmdLine();

$EC2 = Stuzo::AWS::EC2->new;

my $openSearchAref = $EC2->awsX(
	excludeProfiles   => \@ExcludeProfiles,
	excludeProfilesRe => $ExcludeProfilesRe,
	includeProfilesRe => $IncludeProfilesRe,
	subcommand        => "rds describe-db-instances",
);

my $table = Text::Table->new( "PROFILE", "ID", "TYPE" );

foreach my $href (@$openSearchAref) {
	my $profile = $href->{ProfileName};
	foreach my $instanceAref ( @{ $href->{DBInstances} } ) {
		my $id = $instanceAref->{DBInstanceIdentifier};
		my $type = $instanceAref->{DBInstanceClass};
		$table->load( [ $profile, $id, $type ] );
	}
}

print $table;

###### END MAIN ######

sub parseCmdLine {
	my $help;
	my $excludeProfiles;

	GetOptions(
		"e=s"    => \$excludeProfiles,
		"E=s"    => \$ExcludeProfilesRe,
		"I=s"    => \$IncludeProfilesRe,
		"help|?" => \$help
	);

	printUsage("usage:") if $help;

	if ( defined $excludeProfiles ) {
		@ExcludeProfiles = split /,/, $excludeProfiles;
	}
}

sub printUsage {
	print STDERR "@_\n";

	print <<"HERE";

$0    
    [-e <exclude profiles>]  
    [-E <exclude profiles regex>]
    [-I <include profiles regex>]
    
    [-?] (usage)
     
HERE

	exit 1;
}
