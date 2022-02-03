package Stuzo;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use JSON;
use Devel::Confess;
use Net::DNS;

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

method nslookup (Str $name!) {

	$name =~ s/\.$//;    # remove trailing dots
	$self->Logger->verbose("nslookup '$name'");

	my @ips;
	foreach my $res ( rr($name) ) {

		push @ips, $res->address;
	}
	
	return @ips;
}

##############################################################################
# PROTECTED METHODS
##############################################################################

method __camelize (Any $data!) {

	my $new;

	if ( ref($data) eq 'ARRAY' ) {
		$new = [];
		foreach my $scalar (@$data) {

			my $type = ref($scalar);
			if ( $type eq 'ARRAY' or $type eq 'HASH' ) {
				push @$new, $self->__camelize($scalar);
			}
			elsif ( !$type ) {
				push @$new, $scalar;
			}
			else {
				#				$self->Logger->verbose("...scalar type: $type");
			}
		}
	}
	elsif ( ref($data) eq 'HASH' ) {
		$new = {};
		foreach my $key ( keys %$data ) {

			my $camelizedKey = $self->__camelize($key);
			my $scalar       = $data->{$key};
			my $type         = ref($scalar);

			if ( $type eq 'ARRAY' or $type eq 'HASH' ) {
				$new->{$camelizedKey} = $self->__camelize($scalar);
			}
			elsif ( $type eq '' or $type eq 'JSON::PP::Boolean' ) {
				$new->{$camelizedKey} = $scalar;
			}
			else {
				pdump $type;
				die;

				#				$self->Logger->verbose("...skipping scalar type: $type");
			}
		}
	}
	elsif ( ref($data) eq '' ) {
		if ( defined $data ) {
			if ( $data =~ /DNSName/i ) {
				$new = 'dnsName';    # want dnsName not dNSName
			}
			elsif ( $data =~ /TTL/i ) {
				$new = 'ttl';
			}
			else {
				$new = $self->String->camelize($data);
			}
		}
		else {
			die "shouldn't get here";
		}
	}
	else {
		#		$self->Logger->verbose( "skipping type: " . ref($data) );
	}

	return $new;
}

__PACKAGE__->meta->make_immutable;

1;

