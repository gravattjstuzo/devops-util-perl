package Stuzo::AWS::ELBv2;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;
use Stuzo::AWS::ELBv2::LoadBalancer;

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

method awsXDescribeLoadBalancers (Str            :$type,
								  ArrayRef|Undef :$excludeProfiles,
                                  Str|Undef      :$excludeProfilesRe,
                                  Str|Undef      :$includeProfilesRe,) {

	my $aref = $self->awsX(
		subcommand        => 'elbv2 describe-load-balancers',
		excludeProfiles   => $excludeProfiles,
		excludeProfilesRe => $excludeProfilesRe,
		includeProfilesRe => $includeProfilesRe,
	);

	my @elbs;

	foreach my $href (@$aref) {
		foreach my $elbHref ( @{ $href->{LoadBalancers} } ) {
			my $camelizedHref = $self->__camelize($elbHref);
			my $loadBalancer =
			  Stuzo::AWS::ELBv2::LoadBalancer->new(%$camelizedHref);

			if ($type) {
				if ( $loadBalancer->type eq $type ) {
					push @elbs, $loadBalancer;
				}
			}
			else {
				push @elbs, $loadBalancer;
			}
		}
	}
	
	return \@elbs;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
