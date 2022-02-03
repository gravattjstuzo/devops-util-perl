package Stuzo::AWS::CloudFront;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;
#use Stuzo::AWS::Route53::HostedZone;
#use Stuzo::AWS::Route53::ResourceRecordSet;
#use Data::Validate::IP         ('is_ipv4');
#use Util::Medley::Simple::List ('uniq');

extends 'Stuzo::AWS';

with
  'Util::Medley::Roles::Attributes::Logger',
  'Util::Medley::Roles::Attributes::String';

##############################################################################
# CONSTANTS
##############################################################################

##############################################################################
# PUBLIC ATTRIBUTES
##############################################################################

has profile => (
	is  => 'ro',
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

method listDistributions {

    my %param;
    $param{subcommand} = 'cloudfront list-distributions';
    $param{profile}    = $self->profile if $self->profile;

    my $href = $self->aws(%param);
    my $itemsAref = $href->{DistributionList}->{Items};
    
    return $itemsAref;
}


##############################################################################
# PRIVATE METHODS
##############################################################################



__PACKAGE__->meta->make_immutable;

1;
