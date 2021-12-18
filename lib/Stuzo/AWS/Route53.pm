package Stuzo::AWS::Route53;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;
use Stuzo::AWS::Route53::HostedZone;
use Stuzo::AWS::Route53::ResourceRecordSet;

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

has profile => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_buildProfile',
);

method _buildProfile {

	return $ENV{AWS_PROFILE}         if $ENV{AWS_PROFILE};
	return $ENV{AWS_DEFAULT_PROFILE} if $ENV{AWS_DEFAULT_PROFILE};

	confess "unable to determine profile";
}

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

has _hostedZones => (
	is  => 'rw',
	isa => 'ArrayRef[Stuzo::AWS::Route53::HostedZone]',
);

has _resourceRecordSets => (
	is      => 'rw',
	isa     => 'HashRef[ArrayRef]',
	default => sub { {} }
);

##############################################################################
# CONSTRUCTOR
##############################################################################

##############################################################################
# PUBLIC METHODS
##############################################################################

method listHostedZones {

	if ( !$self->_hostedZones ) {

		my @cmd  = ( 'route53', 'list-hosted-zones' );
		my $href = $self->aws(
			subcommand => "@cmd",
			profile    => $self->profile
		);

		my @zones;
		foreach my $zoneHref ( @{ $href->{HostedZones} } ) {
			my $camelizedHref = $self->__camelize($zoneHref);
			my $zone = Stuzo::AWS::Route53::HostedZone->new(%$camelizedHref);
			push @zones, $zone;
		}

		$self->_hostedZones( \@zones );
	}

	return $self->_hostedZones;
}

method listResourceRecordSets (Str      :$hostedZoneId!,
                               ArrayRef :$types) {

	my $cache = $self->_resourceRecordSets;
	if ( !$cache->{$hostedZoneId} ) {

		my @cmd = (
			'route53', 'list-resource-record-sets', '--hosted-zone-id',
			$hostedZoneId
		);
		my $href = $self->aws(
			subcommand => "@cmd",
			profile    => $self->profile
		);

		my @records;
		foreach my $recordHref ( @{ $href->{ResourceRecordSets} } ) {

			my $camelizedHref = $self->__camelize($recordHref);
			my $set =
			  Stuzo::AWS::Route53::ResourceRecordSet->new(%$camelizedHref);
			push @records, $set;
		}

		$cache->{$hostedZoneId} = \@records;
	}

	if ($types) {

		my %types;
		foreach my $type (@$types) {
			$types{$type} = 1;
		}

		my @records;
		foreach my $record ( @{ $cache->{$hostedZoneId} } ) {

			if ( $types{ $record->type } ) {
				push @records, $record;
			}
		}

		return \@records;
	}

	return $cache->{$hostedZoneId};
}

method reverseSearchDnsAliases (Str :$dnsName!) {

	my $zonesAref = $self->listHostedZones;

	my @aliases;
	foreach my $zone (@$zonesAref) {

		my $records =
		  $self->listResourceRecordSets( hostedZoneId => $zone->id );

		foreach my $rec (@$records) {

			if ( $rec->type eq 'CNAME' ) {
				foreach my $href ( @{ $rec->resourceRecords } ) {
					my $value = $href->{value};
					$value =~ s/\.$//;    # remove trailing .
					if ( $value eq $dnsName ) {
						my $name = $rec->name;
						$name =~ s/\.$//;
						push @aliases, $name;
					}
				}
			}
			elsif ( $rec->type eq 'A' ) {
				if ( $rec->aliasTarget ) {
					my $target        = $rec->aliasTarget;
					my $targetDnsName = $target->{dnsName};
					$targetDnsName =~ s/\.$//;             # remove trailing .
					if ( $targetDnsName eq $dnsName ) {
						my $name = $rec->name;
						$name =~ s/\.$//;
						push @aliases, $name;
					}
				}
			}
		}
	}

	return \@aliases;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
