#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Stuzo::AWS::EC2;
use Stuzo::AWS::ELBv2;
use Stuzo::Nagios;
use Util::Medley::Hostname;

###### CONSTANTS ######

use constant EXCLUDE_PROFILES_DEFAULT => qw(stuzo);

###### GLOBALS ######

use vars qw(
  @ExcludeProfiles
  $EC2
  $ELBv2
  $Nagios
  $UtilHostname
  %HostGroups
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

$EC2          = Stuzo::AWS::EC2->new;
$ELBv2        = Stuzo::AWS::ELBv2->new;
$Nagios       = Stuzo::Nagios->new;
$UtilHostname = Util::Medley::Hostname->new;

buildHostsForEips();
buildHostsForALBs();
buildChecksForSDMs();
buildChecksForNLBs();
buildChecksForALBs();

###### END MAIN ######

sub buildChecksForSDMs {
	#
	# service checks for SDM
	#
	if ( $HostGroups{SDM} ) {

		my @names = @{ $HostGroups{SDM} };
		print $Nagios->getHostGroupObj( name => 'SDM', members => \@names )
		  . "\n\n";

		print $Nagios->getServiceObj(
			desc          => 'cert check [port 5000]',
			checkCommand  => 'check_ssl_cert!5000!14!7',
			hostGroupName => 'SDM'
		) . "\n\n";
	}
}

sub buildChecksForNLBs {
	#
	# service checks for NLBs
	#
	if ( $HostGroups{NLB} ) {

		my @names = @{ $HostGroups{NLB} };
		print $Nagios->getHostGroupObj( name => 'NLB', members => \@names )
		  . "\n\n";

		foreach my $port ( 443, 4009, 4010, 4109, 4110 ) {

			print $Nagios->getServiceObj(
				desc          => "cert check [port $port]",
				checkCommand  => "check_ssl_cert!$port!14!7",
				hostGroupName => 'NLB',
			);

			print "\n\n";
		}
	}
}

sub buildChecksForALBs {

	#
	# service checks for ALBs
	#
	if ( $HostGroups{ALB} ) {

		my @names = @{ $HostGroups{ALB} };
		print $Nagios->getHostGroupObj( name => 'ALB', members => \@names )
		  . "\n\n";

		print $Nagios->getServiceObj(
			desc          => 'cert check [port 443]',
			checkCommand  => 'check_ssl_cert!443!14!7',
			hostGroupName => 'ALB'
		);
	}
}

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

sub buildHostsForALBs {
	#
	# build hosts (find public ALBs)
	#
	my $elbsAref = $ELBv2->awsXDescribeLoadBalancers(
		type              => 'application',
		excludeProfiles   => \@ExcludeProfiles,
		excludeProfilesRe => $ExcludeProfilesRe,
		includeProfilesRe => $IncludeProfilesRe
	);

	foreach my $elb (@$elbsAref) {

		if (    $elb->scheme eq 'internet-facing'
			and $elb->state->{code} eq 'active' )
		{

			if ( !$elb->dnsName ) {
				pdump $elb;
				die;    # shouldn't get here
			}

			my $fqdn = $elb->dnsName;
			my ( $hostname, $domain ) = $UtilHostname->parseHostname($fqdn);

			push @{ $HostGroups{ALB} }, $hostname;

			my $hostObj = $Nagios->getHostObj(
				hostName     => $hostname,
				address      => $fqdn,       # ips are dynamic for app balancers
				checkCommand => "check_tcp!443",
			);

			print "$hostObj\n\n";
		}
	}
}

sub buildHostsForEips {
	#
	# build hosts (find active EIPs)
	#
	my $addressesAref = $EC2->awsXDescribeAddresses(
		excludeProfiles   => \@ExcludeProfiles,
		excludeProfilesRe => $ExcludeProfilesRe,
		includeProfilesRe => $IncludeProfilesRe
	);

	foreach my $address (@$addressesAref) {

		next if !$address->networkInterfaceId;

		my $profileName = $address->profileName;
		my $name        = $address->getName;

		my $checkCommand;
		my $interface = findNetworkInterface( $address->networkInterfaceId );
		if ( $interface->interfaceType eq 'interface' ) {
			if ( $name =~ /sdm/ ) {
				push @{ $HostGroups{SDM} }, $name;
			}

			push @{ $HostGroups{'EC2-INSTANCE'} }, $name;
			$checkCommand = "check_tcp!5000";
		}
		elsif ( $interface->interfaceType eq 'network_load_balancer' ) {
			push @{ $HostGroups{NLB} }, $name;
			$checkCommand = "check_tcp!443";
		}
		elsif ( $interface->interfaceType eq 'nat_gateway' ) {
			#
			# no good way to verify up or down without doing an API call to AWS
			#

			push @{ $HostGroups{'NAT-GW'} }, $name;
			next;
		}
		else {
			pdump $address;
			die;
		}

		my $hostObj = $Nagios->getHostObj(
			hostName     => $name,
			address      => $address->publicIp,
			checkCommand => $checkCommand,
		);

		print "$hostObj\n\n";
	}
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
