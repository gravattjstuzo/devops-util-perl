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
  'Util::Medley::Roles::Attributes::Logger',
  'Util::Medley::Roles::Attributes::Spawn',
  'Util::Medley::Roles::Attributes::String';

##############################################################################
# CONSTANTS
##############################################################################

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

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
		my $interfaceHref = $self->__camelize( $interface );
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

		my $name = $address->getTag( key => 'Name' );
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

			my $camelizedHref = $self->__camelize( $interfaceHref );

			my $interface = Stuzo::AWS::EC2::NetworkInterface->new(
				profileName => $profileName,
				%$camelizedHref
			);

			push @interfaces, $interface;
		}
	}

	return \@interfaces;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
