package Stuzo::AWS::EC2::Address;

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

has allocationId => (
	is  => 'ro',
	isa => 'Str',
);

has associationId => (
	is  => 'ro',
	isa => 'Str',
);

has carrierIp => (
	is  => 'ro',
	isa => 'Str',
);

has customerOwnedIp => (
	is  => 'ro',
	isa => 'Str',
);

has customerOwnedIpv4Pool => (
	is  => 'ro',
	isa => 'Str',
);

has domain => (
	is  => 'ro',
	isa => 'Str',
);

has instanceId => (
	is  => 'ro',
	isa => 'Str',
);

has networkBorderGroup => (
	is  => 'ro',
	isa => 'Str',
);

has networkInterfaceId => (
	is  => 'ro',
	isa => 'Str',
);

has networkInterfaceOwnerId => (
	is  => 'ro',
	isa => 'Str',
);

has privateIpAddress => (
	is  => 'ro',
	isa => 'Str',
);

has publicIp => (
	is  => 'ro',
	isa => 'Str',
);

has publicIpv4Pool => (
	is  => 'ro',
	isa => 'Str',
);

has tags => (
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub { [] },
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

method getName {
	
	my $name = $self->getTagValue('Name');
	if (!$name) {
		return $self->allocationId;	
	}	

	$name =~ s/\s/-/g; # convert spaces to dashes
	
	return $name;
}

method getTagValue (Str $key!) {
    
    return $self->SUPER::getTagValue(
        tags => $self->tags,
        key  => $key   
    );	
}

method getTag (Str $key!) {

	return $self->SUPER::getTag(
		tags => $self->tags,
		key  => $key
	);
}

##############################################################################
# PRIVATE_METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

