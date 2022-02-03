#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Stuzo::AWS::EC2;
use Stuzo::AWS::ELBv2;
use Stuzo::AWS::Route53;

###### CONSTANTS ######

use constant EXCLUDE_PROFILES_DEFAULT => qw(stuzo);

###### GLOBALS ######

use vars qw(
  @ExcludeProfiles
  $EC2
  $ELBv2
  $UtilHostname
  $IncludeProfilesRe
  $ExcludeProfilesRe
);

###### MAIN ######

=pod interface types

            "InterfaceType" : "global_accelerator_managed",
            "InterfaceType" : "interface",
            "InterfaceType" : "lambda",
            "InterfaceType" : "nat_gateway",
            "InterfaceType" : "network_load_balancer",
            "InterfaceType" : "vpc_endpoint",

=cut

parseCmdLine();

$EC2   = Stuzo::AWS::EC2->new;
$ELBv2 = Stuzo::AWS::ELBv2->new;

my @names;
push @names, getEIPHostnames();
push @names, getALBHostnames();

foreach my $name ( sort @names ) {
	say $name;
}

###### END MAIN ######

sub findNetworkInterface {

	my $networkInterfaceId = shift;

	state $interfacesAref;
	state $interfacesHref;

	if ( !$interfacesAref ) {
		$interfacesAref = $EC2->awsXDescribeNetworkInterfaces(
			excludeProfiles   => \@ExcludeProfiles,
			excludeProfilesRe => $ExcludeProfilesRe,
			includeProfilesRe => $IncludeProfilesRe
		);
	}

	if ( !$interfacesHref ) {
		my %interfaces;
		foreach my $interface (@$interfacesAref) {
			my $id = $interface->networkInterfaceId;
			$interfaces{$id} = $interface;
		}

		$interfacesHref = \%interfaces;
	}

	return $interfacesHref->{$networkInterfaceId};
}

sub getALBHostnames {
	#
	# build hosts (find public ALBs)
	#
	my $elbsAref = $ELBv2->awsXDescribeLoadBalancers(
		type              => 'application',
		excludeProfiles   => \@ExcludeProfiles,
		excludeProfilesRe => $ExcludeProfilesRe,
		includeProfilesRe => $IncludeProfilesRe
	);

	my @names;
	foreach my $elb (@$elbsAref) {

		if (    $elb->scheme eq 'internet-facing'
			and $elb->state->{code} eq 'active' )
		{
			my $fqdn = $elb->dnsName;
			next if $fqdn =~ /argo/;

			my $route53 = getRoute53( $elb->profileName );
			my $aliasesAref =
			  $route53->reverseSearchDnsAliases( dnsName => $elb->dnsName );

			if (@$aliasesAref) {
				foreach my $alias (@$aliasesAref) {

					# use the first one found
					push @names, $alias;
				}
			}
			else {
				push @names, $fqdn;
			}
		}
	}

	return @names;
}

sub getRoute53 {
	my $profile = shift;

	state %route53;

	if ( !$route53{$profile} ) {
		$route53{$profile} = Stuzo::AWS::Route53->new( profile => $profile );
	}

	return $route53{$profile};
}

sub getEIPHostnames {
	#
	# build hosts (find active EIPs)
	#
	my $addressesAref = $EC2->awsXDescribeAddresses(
		excludeProfiles   => \@ExcludeProfiles,
		excludeProfilesRe => $ExcludeProfilesRe,
		includeProfilesRe => $IncludeProfilesRe
	);

	my @names;
	foreach my $address (@$addressesAref) {

		next if !$address->networkInterfaceId;

		my $interface = findNetworkInterface( $address->networkInterfaceId );
		if ( $interface->interfaceType eq 'interface' ) {
            push @names, $interface->association->{dnsName};
		}
		elsif ( $interface->interfaceType eq 'network_load_balancer' ) {
			push @names, $interface->association->{dnsName};
		}
		elsif ( $interface->interfaceType eq 'nat_gateway' ) {
            push @names, $interface->association->{dnsName};
		}
		else {
			pdump $address;
			die;
		}
	}

	return @names;
}

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
	else {
		@ExcludeProfiles = EXCLUDE_PROFILES_DEFAULT();
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
