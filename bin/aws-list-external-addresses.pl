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
use Stuzo::AWS::CloudFront;
use Util::Medley::Simple::List ( 'uniq', 'nsort' );
use YAML::Syck;
$YAML::Syck::Headless = 1;
$YAML::Syck::SortKeys = 1;
use Util::Medley::Logger;

###### CONSTANTS ######

###### GLOBALS ######

use vars qw(
  $EC2
  $ELBv2
  $CF
  $Profile
  %FoundNetworkInterfaceIds
  %Yaml
  %SkipEnvs
  $Logger
  $Route53
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

$Logger  = Util::Medley::Logger->new;
$EC2     = Stuzo::AWS::EC2->new;
$ELBv2   = Stuzo::AWS::ELBv2->new;
$CF      = Stuzo::AWS::CloudFront->new;
$Route53 = getRoute53();

getNatGateways();
getALBs();
getNLBs();
getInstances();
getCloudFront();

#
# verify we have accounted for all EIPs
#
foreach my $address ( @{ $EC2->describeAddresses } ) {

	next if !exists $address->{AssociationId};

	my $id = $address->{NetworkInterfaceId};
	if ( !$FoundNetworkInterfaceIds{$id} ) {
		$Logger->warn("missing match for network interface id: $id");
	}
}

say YAML::Syck::Dump( \%Yaml );

###### END MAIN ######

sub getCloudFront {

	my $aref = $CF->listDistributions;

	my %yaml;
	foreach my $dist ( @{ $CF->listDistributions } ) {

		my @ips;
		my @aliases;

		my $fqdn = $dist->{DomainName};
		push @ips, $CF->nslookup($fqdn);

		my $aliasesHref = $dist->{Aliases};
		if ( exists $aliasesHref->{Items} ) {

			foreach my $alias ( @{ $aliasesHref->{Items} } ) {
				push @ips,     $CF->nslookup($alias);
				push @aliases, $alias;
			}
		}

		my $name = $dist->{Id};
		$yaml{$name} = {
			FQDN    => $fqdn,
			Aliases => [ nsort( uniq(@aliases) ) ],
			IPs => ['(dynamic)'],
		};
	}

	saveYamlGroup( 'CloudFront', \%yaml );
}

sub foundNetworkInterfaceId {

	my $id = shift;

	$FoundNetworkInterfaceIds{$id} = 1;
}

sub getInstances {

	my $aref = $EC2->describeInstances;

	my %yaml;
	foreach my $instance (@$aref) {

		my @ips;
		my @aliases;

		my $name =
		  $EC2->getTagValue( tags => $instance->{Tags}, key => 'Name' );
		if ( !defined $name ) {
			$name = $instance->{InstanceId};
		}

		my $env =
		  $EC2->getTagValue( tags => $instance->{Tags}, key => 'Environment' );

		foreach my $iface ( @{ $instance->{NetworkInterfaces} } ) {

			if ( $iface->{NetworkInterfaceId} ) {

				foundNetworkInterfaceId( $iface->{NetworkInterfaceId} );

				if ( $iface->{Association} ) {
					my $assoc = $iface->{Association};
					push @ips, $assoc->{PublicIp} if ( $assoc->{PublicIp} );
				}
			}
		}

        next if skipEnv( $name, $env ); # put this under the loop to register network interface ids

		my $fqdn = $instance->{PublicDnsName};
		if ($fqdn) {
			my $route53 = $Route53;
			my $recs    = $route53->findRecordsByAliasTarget(
				dnsName     => $fqdn,
				privateZone => 0
			);

			if (@$recs) {

				foreach my $rec (@$recs) {
					my $name = $route53->stripTrailingDot( $rec->{Name} );
					push @aliases, $name;

					if ( !@ips ) {
						push @ips,
						  $ELBv2->nslookup($name);    # only need one nslookup
					}
				}
			}

			my $instanceName =
			  $EC2->getTagValue( tags => $instance->{Tags}, key => 'Name' );
			if ( !defined $instanceName ) {
				$instanceName = $instance->{instanceId};
			}

			@ips = tagEips( uniq(@ips) );

			$yaml{$instanceName} = {
				FQDN    => $fqdn,
				Aliases => [ nsort( uniq(@aliases) ) ],
				IPs     => [ nsort(@ips) ],
			};
		}
	}

	saveYamlGroup( 'EC2 Instances', \%yaml );
}

sub tagEips {

	my @ips = @_;

	my @resp;
	foreach my $ip (@ips) {
		my $addressHref = $EC2->findAddressByPublicIp( ip => $ip );
		if ($addressHref) {
			push @resp,
			  sprintf( "%-15.15s (%s)", $ip, $addressHref->{AllocationId} );
		}
		else {
			push @resp, $ip;
		}
	}

	return @resp;
}

sub skipEnv {
	my ( $name, $env ) = @_;

	if ($env) {
		if ( $SkipEnvs{$env} ) {
			return 1;
		}
	}
	elsif ($name) {

		# legacy match for hatch
		foreach my $key ( keys %SkipEnvs ) {
			if ( $name =~ /$key/ ) {
				return 1;
			}
		}
	}

	return 0;
}

sub getNatGateways {

	$Logger->info("getting NAT Gateways");

	my $aref = $EC2->describeNatGateways( type => 'public' );

	my %yaml;
	foreach my $gw (@$aref) {

		my $name = $EC2->getTagValue( tags => $gw->{Tags}, key => 'Name' );
		if ( !defined $name ) {
			$name = $gw->{NatGatewayId};
		}

		my $env =
		  $EC2->getTagValue( tags => $gw->{Tags}, key => 'Environment' );

		my @ips;
		foreach my $address ( @{ $gw->{NatGatewayAddresses} } ) {

			if ( $address->{NetworkInterfaceId} ) {
				foundNetworkInterfaceId( $address->{NetworkInterfaceId} );
			}

			if ( $address->{PublicIp} ) {
				push @ips, $address->{PublicIp};
			}
		}

        next if skipEnv( $name, $env ); # put this under the loop to register network interface ids
        
		@ips = tagEips( uniq(@ips) );
		$yaml{ $gw->{NatGatewayId} } = { IPs => [ nsort(@ips) ] };
	}

	saveYamlGroup( 'NAT Gateways', \%yaml );

	#say YAML::Syck::Dump( { 'NAT Gateways' => \%yaml } );
}

sub saveYamlGroup {
	my $key  = shift;
	my $data = shift;

	my $profile = $EC2->getProfileName;
	$Yaml{$profile}->{$key} = $data;
}

sub getNLBs {

	$Logger->info("getting NLBs");

	my $elbsAref = $ELBv2->describeLoadBalancers(
		type      => 'network',
		scheme    => 'internet-facing',
		stateCode => 'active',
	);

	my %nlbs;
	foreach my $elb (@$elbsAref) {

		my @aliases;
		my @ips;

		my $dnsName = $elb->{DNSName};
		next if $dnsName =~ /argo/;

		my $name = $elb->{LoadBalancerName};

		my $env = $ELBv2->getTagValue(
			arn => $elb->{LoadBalancerArn},
			key => 'Environment'
		);

		#
		# flag found network interfaces
		#
		my @allocationIds =
		  $ELBv2->getLoadBalancerAllocationIds(
			arn => $elb->{LoadBalancerArn} );

		foreach my $id (@allocationIds) {
			my $addressesAref =
			  $EC2->describeAddresses( allocationIds => [$id] );
			foreach my $address (@$addressesAref) {
				if ( $address->{NetworkInterfaceId} ) {
					foundNetworkInterfaceId( $address->{NetworkInterfaceId} );
				}
			}
		}

        next if skipEnv( $name, $env ); # put this under the loop to register network interface ids

		my $route53 = $Route53;
		my $recs    = $route53->findRecordsByAliasTarget(
			dnsName     => $dnsName,
			privateZone => 0
		);

		if (@$recs) {

			foreach my $rec (@$recs) {
				my $name = $route53->stripTrailingDot( $rec->{Name} );
				push @aliases, $name;

				if ( !@ips ) {
					push @ips, $ELBv2->nslookup($name); # only need one nslookup
				}
			}
		}

		@ips = tagEips( uniq(@ips) );

		$nlbs{ $elb->{LoadBalancerName} } = {
			FQDN    => $dnsName,
			Aliases => [ nsort( uniq(@aliases) ) ],
			IPs     => [ nsort(@ips) ]
		};
	}

	#	say YAML::Syck::Dump( { 'Network LBs' => \%nlbs } );
	saveYamlGroup( 'Network LBs', \%nlbs );
}

sub getALBs {

	$Logger->info("getting ALBs");

	my $elbsAref = $ELBv2->describeLoadBalancers(
		type      => 'application',
		scheme    => 'internet-facing',
		stateCode => 'active',
	);

	my %albs;
	foreach my $elb (@$elbsAref) {

		my @aliases;
		my @ips;

		my $fqdn = $elb->{DNSName};
		next if $fqdn =~ /argo/;

		my $name = $elb->{LoadBalancerName};

		my $env = $ELBv2->getTagValue(
			arn => $elb->{LoadBalancerArn},
			key => 'Environment'
		);

		next if skipEnv( $name, $env );

		my $route53 = $Route53;
		my $dnsName = $elb->{DNSName};

		my $recs = $route53->findRecordsByAliasTarget(
			dnsName     => $dnsName,
			privateZone => 0
		);
		if (@$recs) {
			foreach my $rec (@$recs) {
				my $name = $route53->stripTrailingDot( $rec->{Name} );
				push @aliases, $name;

				if ( !@ips ) {
					push @ips, $ELBv2->nslookup($name); # only need one nslookup
				}
			}
		}

		$albs{ $elb->{LoadBalancerName} } = {
			FQDN    => $fqdn,
			Aliases => [ nsort( uniq(@aliases) ) ],

			#			IPs     => [ nsort( uniq(@ips) ) ]
			IPs => ['(dynamic)'],
		};
	}

	#	say YAML::Syck::Dump( { 'Application LBs' => \%albs } );
	saveYamlGroup( 'Application LBs', \%albs );
}

sub getRoute53 {

	my %param;
	$param{profile} = $Profile if $Profile;

	return Stuzo::AWS::Route53->new(%param);
}

sub parseCmdLine {
	my $help;
	my $skipEnvs;

	GetOptions(
		"p=s"    => \$Profile,
		"s=s"    => \$skipEnvs,
		"help|?" => \$help
	);

	foreach my $skipEnv ( split( /,/, $skipEnvs ) ) {
		$SkipEnvs{$skipEnv} = 1;
	}

	printUsage("usage:") if $help;
}

sub printUsage {
	print STDERR "@_\n";

	print <<"HERE";
$0    
    [-p <aws-profile>]  (default is AWS_PROFILE)
    [-s <skip envs>]
    [-t <ignore tags like>]
        
    [-?] (usage)
     
HERE

	exit 1;
}
