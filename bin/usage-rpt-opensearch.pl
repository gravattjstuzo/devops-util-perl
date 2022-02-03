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
	subcommand        => "opensearch list-domain-names",
);

my $table = Text::Table->new( "PROFILE", "DOMAIN", "NODE", "TYPE", "COUNT" );

foreach my $href (@$openSearchAref) {
	my $profile         = $href->{ProfileName};
	my $domainNamesAref = $href->{DomainNames};

	foreach my $domainHref (@$domainNamesAref) {
		my $domainName = $domainHref->{DomainName};
		my $respHref   = $EC2->aws(
			profile    => $profile,
			subcommand => "opensearch describe-domain --domain-name $domainName"
		);

		my $configHref = $respHref->{DomainStatus}->{ClusterConfig};

		my $type  = $configHref->{DedicatedMasterType};
		my $count = $configHref->{DedicatedMasterCount};
		$table->load( [ $profile, $domainName, 'master', $type, $count ] );

		$type  = $configHref->{InstanceType};
		$count = $configHref->{InstanceCount};
		$table->load( [ $profile, $domainName, 'data', $type, $count ] );
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
