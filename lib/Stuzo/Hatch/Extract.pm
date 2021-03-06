package Stuzo::Hatch::Extract;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;

##############################################################################
# CONSTANTS
##############################################################################

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has extractType => (
    is => 'rw',
    isa => 'Str'
);

has fileNames => (
    is => 'rw',
    isa => 'ArrayRef',
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


##############################################################################
# PROTECTED METHODS
##############################################################################


__PACKAGE__->meta->make_immutable;

1;
