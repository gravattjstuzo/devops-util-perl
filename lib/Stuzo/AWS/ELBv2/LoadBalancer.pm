package Stuzo::AWS::ELBv2::LoadBalancer;

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

has availabilityZones     => ( is => 'ro', isa => 'ArrayRef' );
has canonicalHostedZoneId => ( is => 'ro', isa => 'Str' );
has createdTime           => ( is => 'ro', isa => 'Str' );
has customerOwnedIpv4Pool => ( is => 'ro', isa => 'Str' );
has dnsName               => ( is => 'ro', isa => 'Str' );
has ipAddressType         => ( is => 'ro', isa => 'Str' );
has loadBalancerArn       => ( is => 'ro', isa => 'Str' );
has loadBalancerName      => ( is => 'ro', isa => 'Str' );
has scheme                => ( is => 'ro', isa => 'Str' );
has securityGroups        => ( is => 'ro', isa => 'ArrayRef[Str|Undef]' );
has 'state'               => ( is => 'ro', isa => 'HashRef' );
has type                  => ( is => 'ro', isa => 'Str' );
has vpcId                 => ( is => 'ro', isa => 'Str' );
has profileName => (
    is => 'ro',
    isa => 'Str',
);
has tags => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
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

method getPublicAddresses {

    #
    # DO NOT USE
    #
    # application load balancers have ephemeral ips, therefore
    # no addresses are in availabilityZones. use a dns-lookup instead
    # if you really need the addresses.
    #
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

