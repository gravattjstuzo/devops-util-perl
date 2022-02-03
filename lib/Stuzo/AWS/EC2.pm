package Stuzo::AWS::EC2;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;
use Stuzo::AWS::EC2::Address;
use Stuzo::AWS::EC2::NetworkInterface;

extends 'Stuzo::AWS';

with
  'Util::Medley::Roles::Attributes::List',
  'Util::Medley::Roles::Attributes::Logger',
  'Util::Medley::Roles::Attributes::Spawn',
  'Util::Medley::Roles::Attributes::String';

##############################################################################
# CONSTANTS
##############################################################################

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has profile => (
	is  => 'rw',
	isa => 'Str',
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

has _addresses => (
	is  => 'rw',
	isa => 'ArrayRef',
);

##############################################################################
# CONSTRUCTOR
##############################################################################

##############################################################################
# PUBLIC METHODS
##############################################################################

=pod

 returns ArrayRef[ HashRef[ ArrayRef ] ]
 

method awsXDescribeLoadBalancers (Str            :$type,
								  ArrayRef|Undef :$excludeProfiles) {

	my $aref = $self->awsX(
		subcommand      => 'elbv2 describe-load-balancers',
		excludeProfiles => $excludeProfiles
	);

	my @list;
	
	fore
	foreach my $href (@$aref) {

		my @elbs = ();

		foreach my $elb ( @{ $href->{LoadBalancers} } ) {
			if ( $type and $elb->{Type} ne $type ) {
				next;
			}

			push @elbs, $elb;
		}

		$href->{LoadBalancers} = \@elbs;
	}

	return $aref;
}

=cut

=pod

 returns ArrayRef[ Stuzo::AWS::EC2::NetworkInterface ]
 
=cut

method describeNetworkInterfaces (ArrayRef[Str] :$networkInterfaceIds,
							 	  Str           :$profile) {

	my @cmd = ( 'ec2', 'describe-network-interfaces' );
	if ($networkInterfaceIds) {
		push @cmd, '--network-interface-ids', join ',', @$networkInterfaceIds;
	}

	my $href = $self->aws( subcommand => join ' ', @cmd );
	my $aref = $href->{NetworkInterfaces};

	my @interfaces;
	foreach my $interface (@$aref) {
		my $interfaceHref = $self->__camelize($interface);
		my $networkInterface =
		  Stuzo::AWS::EC2::NetworkInterface->new(%$interfaceHref);
		push @interfaces, $networkInterface;
	}

	return \@interfaces;
}

=pod

 returns ArrayRef[ Stuzo::AWS::EC2::Address ]
 
=cut

method awsXDescribeAddresses (Regexp    	 :$matchTagName,
                              HashRef        :$ignoreTagsLike,
							  ArrayRef|Undef :$excludeProfiles,
							  Str|Undef      :$excludeProfilesRe,
							  Str|Undef      :$includeProfilesRe,
							  ArrayRef|Undef :$excludeNamesLike = []) {

	my $aref = $self->awsX(
		subcommand        => 'ec2 describe-addresses',
		excludeProfiles   => $excludeProfiles,
		excludeProfilesRe => $excludeProfilesRe,
		includeProfilesRe => $includeProfilesRe,
	);

	my @addresses;

	foreach my $href (@$aref) {
		my $profileName = $href->{ProfileName};

		foreach my $addressHref ( @{ $href->{Addresses} } ) {

			my %attr;
			foreach my $key ( keys %$addressHref ) {
				my $camelKey = $self->__camelize($key);
				$attr{$camelKey} = $addressHref->{$key};
			}

			my $address = Stuzo::AWS::EC2::Address->new(
				profileName => $profileName,
				%attr
			);
			push @addresses, $address;
		}
	}

	my @final;
	foreach my $address (@addresses) {

		my $name = $address->getName;
		if ($name) {

			my $skip = 0;
			foreach my $excl (@$excludeNamesLike) {

				# skip matches
				if ( $name =~ /$excl/ ) {
					$skip = 1;
					last;
				}
			}

			next if $skip;
		}

		if ($matchTagName) {

			# only add it if it matches
			if ($name) {
				if ( $name !~ $matchTagName ) {

					# does not match
					next;
				}
			}
			else {
				# if name not defined, it can't match
				next;
			}
		}

		if ($ignoreTagsLike) {
			foreach my $tagKey ( keys %$ignoreTagsLike ) {
				my $regex    = $ignoreTagsLike->{$tagKey};
				my $tagValue = $address->getTagValue($tagKey);
				if ( $tagValue =~ /$regex/ ) {
					$self->Logger->verbose("skipping tag $tagKey:$tagValue");
					next;
				}
			}
		}

		# if we get here we have passed all conditions
		push @final, $address;
	}

	return \@final;
}

method awsXDescribeNetworkInterfaces (ArrayRef|Undef :$excludeProfiles,
                                      Str|Undef      :$excludeProfilesRe,
                                      Str|Undef      :$includeProfilesRe,) {

	my $aref = $self->awsX(
		subcommand        => 'ec2 describe-network-interfaces',
		excludeProfiles   => $excludeProfiles,
		excludeProfilesRe => $excludeProfilesRe,
		includeProfilesRe => $includeProfilesRe,
	);

	my @interfaces;

	foreach my $href (@$aref) {
		my $profileName = $href->{ProfileName};

		foreach my $interfaceHref ( @{ $href->{NetworkInterfaces} } ) {

			my $camelizedHref = $self->__camelize($interfaceHref);

			my $interface = Stuzo::AWS::EC2::NetworkInterface->new(
				profileName => $profileName,
				%$camelizedHref
			);

			push @interfaces, $interface;
		}
	}

	return \@interfaces;
}

method describeAddresses (ArrayRef :$allocationIds) {

	if ( !$self->_addresses ) {
		my $href = $self->aws( subcommand => 'ec2 describe-addresses', );

		my @resp;
		foreach my $address ( @{ $href->{Addresses} } ) {
			push @resp, $address;
		}

		$self->_addresses( \@resp );
	}

=pod example response

    [
        {
            "PublicIp": "18.213.20.77",
            "AllocationId": "eipalloc-093acfe272721a222",
            "AssociationId": "eipassoc-088a11a4590b97fbd",
            "Domain": "vpc",
            "NetworkInterfaceId": "eni-01167db3eb635d3bb",
            "NetworkInterfaceOwnerId": "729361165913",
            "PrivateIpAddress": "10.115.12.208",
            "Tags": [
                {
                    "Key": "Stage",
                    "Value": "circlek"
                },
                {
                    "Key": "EipID",
                    "Value": "nlb-eip-1"
                },
                ...
            ],
            "PublicIpv4Pool": "amazon",
            "NetworkBorderGroup": "us-east-1"
        },
        ....
    ]

=cut

	if ($allocationIds) {

		my @resp;
		foreach my $href ( @{ $self->_addresses } ) {
			if ( $href->{AllocationId} ) {
				if (
					$self->List->contains(
						$allocationIds, $href->{AllocationId}
					)
				  )
				{
					push @resp, $href;
				}
			}
		}

		return \@resp;
	}

	return $self->_addresses;
}

method describeInstances (HashRef :$tags) {

	my %param;
	$param{subcommand} = 'ec2 describe-instances';
	$param{profile}    = $self->profile if $self->profile;

	my $href = $self->aws(%param);
	my @instances;
	foreach my $resHref ( @{ $href->{Reservations} } ) {
		push @instances, @{ $resHref->{Instances} };
	}

	if ( $tags and keys(%$tags) ) {
		my @resp;
		foreach my $instance (@instances) {
			foreach my $key ( keys %$tags ) {
				my $wantVal = $tags->{$key};
				my $val =
				  $self->getTagValue( tags => $instance->{Tags}, key => $key );
				if ( $val and $val eq $wantVal ) {
					push @resp, $instance;
					last;
				}
			}
		}
		
		return \@resp;
	}

	return \@instances;
}

method describeNatGateways (Str :$type) {

	my %param;
	$param{subcommand} = 'ec2 describe-nat-gateways';
	$param{profile}    = $self->profile if $self->profile;

	my $href = $self->aws(%param);

	# my $aref = $href->{NatGateways};

	my @resp;
	foreach my $gwHref ( @{ $href->{NatGateways} } ) {

		next if $type and $gwHref->{ConnectivityType} ne $type;

		push @resp, $gwHref;
	}

=pod

    [
        {
            "CreateTime": "2020-11-17T17:26:55+00:00",
            "NatGatewayAddresses": [
                {
                    "AllocationId": "eipalloc-0c5b54a9320f92608",
                    "NetworkInterfaceId": "eni-019bf4ae907015d77",
                    "PrivateIp": "10.9.10.177",
                    "PublicIp": "18.235.252.150"
                }
            ],
            "NatGatewayId": "nat-031020b30afcfbe5f",
            "State": "available",
            "SubnetId": "subnet-081bdbcc6f3a5e8e0",
            "VpcId": "vpc-0c59e577c9f066eb7",
            "Tags": [
                {
                    "Key": "ManagedByTerraform",
                    "Value": "true"
                },
                {
                    "Key": "Customer",
                    "Value": "cefco"
                },
                ....
            ],
            "ConnectivityType": "public"
        },
        ...
    ] 
=cut

	return \@resp;
}

method findNetworkInterfaceByAllocId (Str :$allocationId!) {

	foreach my $address ( @{ $self->describeAddresses } ) {
		if ( $address->{AllocationId} ) {
			if ( $address->{AllocationId} eq $allocationId ) {
				return $address->{NetworkInterfaceId};
			}
		}
	}
}

method findAddressByNetworkInterfaceId (Str :$networkInterfaceId!) {

	foreach my $addressHref ( @{ $self->describeAddresses } ) {
		if ( $addressHref->{NetworkInterfaceId} ) {
			if ( $addressHref->{NetworkInterfaceId} eq $networkInterfaceId ) {
				return $addressHref;
			}
		}
	}
}

method findAddressByPublicIp (Str :$ip!) {

    foreach my $addressHref ( @{ $self->describeAddresses } ) {
        if ( $addressHref->{PublicIp} ) {
        	if ($addressHref->{PublicIp} eq $ip) {
                return $addressHref;
            }
        }
    }
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
