package Stuzo::AWS::Route53::HostedZone;

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

has callerReference        => ( is => 'ro', isa => 'Str', required => 1 );
has config                 => ( is => 'ro', isa => 'HashRef' );
has id                     => ( is => 'ro', isa => 'Str', required => 1 );
has linkedService          => ( is => 'ro', isa => 'HashRef' );
has name                   => ( is => 'ro', isa => 'Str', required => 1 );
has resourceRecordSetCount => ( is => 'ro', isa => 'Int' );
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

method isPublic {

    if ($self->isPrivate) {
        return 0;	
    }	
    
    return 1;
}

method isPrivate {

    my $bool = $self->config->{privateZone};
    
    return $bool;	
}

##############################################################################
# PRIVATE_METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

