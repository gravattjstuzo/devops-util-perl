package Stuzo::AWS::EC2::NetworkInterface;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;

extends 'Stuzo::AWS';

with 'Util::Medley::Roles::Attributes::Logger';

##############################################################################
# CONSTANTS
##############################################################################

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has association => (
	is  => 'ro',
	isa => 'HashRef',
);

has attachment => (
	is  => 'ro',
	isa => 'HashRef',
);

has availabilityZone => (
	is  => 'ro',
	isa => 'Str',
);

has description => (
	is  => 'ro',
	isa => 'Str',
);

has groups => (
	is  => 'ro',
	isa => 'ArrayRef',
);

has interfaceType => (
	is  => 'ro',
	isa => 'Str',
);

has ipv6Addresses => (
	is  => 'ro',
	isa => 'ArrayRef',
);

has macAddress => (
	is  => 'ro',
	isa => 'Str',
);

has networkInterfaceId => (
	is  => 'ro',
	isa => 'Str',
);

has outpostArn => (
	is  => 'ro',
	isa => 'Str',
);

has ownerId => (
	is  => 'ro',
	isa => 'Str',
);

has privateDnsName => (
	is  => 'ro',
	isa => 'Str',
);

has privateIpAddress => (
	is  => 'ro',
	isa => 'Str',
);

has privateIpAddresses => (
	is  => 'ro',
	isa => 'ArrayRef',
);

has requesterId => (
	is  => 'ro',
	isa => 'Str',
);

has requesterManaged => (
	is  => 'ro',
	isa => 'Bool',
);

has sourceDestCheck => (
	is  => 'ro',
	isa => 'Bool',
);

has status => (
	is  => 'ro',
	isa => 'Str',
);

has subnetId => (
	is  => 'ro',
	isa => 'Str',
);

has tagSet => (
	is  => 'ro',
	isa => 'ArrayRef',
);

has vpcId => (
	is  => 'ro',
	isa => 'Str',
);

has profileName => (
    is => 'ro',
    isa => 'Str',
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

##############################################################################
# CONSTRUCTOR
##############################################################################

##############################################################################
# PUBLIC METHODS
##############################################################################

method getTagValue (Str $key!) {
    
    return $self->SUPER::getTagValue(
        tags => $self->tagSet,
        key  => $key   
    );  
}

method getTag (Str $key!) {

	return $self->SUPER::getTag(
		tags => $self->tagSet,
		key  => $key
	);
}

##############################################################################
# PRIVATE_METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

