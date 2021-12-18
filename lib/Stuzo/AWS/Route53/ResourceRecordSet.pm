package Stuzo::AWS::Route53::ResourceRecordSet;

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

has aliasTarget             => ( is => 'ro', isa => 'HashRef' );
has failover                => ( is => 'ro', isa => 'Str' );
has geoLocation             => ( is => 'ro', isa => 'HashRef' );
has healthCheckId           => ( is => 'ro', isa => 'Str' );
has multiValueAnswer        => ( is => 'ro', isa => 'Bool' );
has name                    => ( is => 'ro', isa => 'Str', required => 1 );
has region                  => ( is => 'ro', isa => 'Str' );
has resourceRecords         => ( is => 'ro', isa => 'ArrayRef' );
has setIdentifier           => ( is => 'ro', isa => 'Str' );
has trafficPolicyInstanceId => ( is => 'ro', isa => 'Str' );
has ttl                     => ( is => 'ro', isa => 'Int' );
has type                    => ( is => 'ro', isa => 'Str', required => 1 );
has weight                  => ( is => 'ro', isa => 'Int' );
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

method BUILD {

    if (!$self->type) {
        pdump $self;
        die;	
    }	
}

##############################################################################
# PUBLIC METHODS
##############################################################################

##############################################################################
# PRIVATE_METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

