package Stuzo;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use JSON;
use Devel::Confess;

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

method getTag (ArrayRef :$tags!,
               Str      :$key!) {

	foreach my $href (@$tags) {
		if ( $href->{Key} and $href->{Key} =~ /^$key$/ ) {
			return $href;
		}
	}
}

method getTagValue (ArrayRef :$tags!,
		  		    Str      :$key!) {

	foreach my $href (@$tags) {
		if ( $href->{Key} and $href->{Key} =~ /^$key$/ ) {
			return $href->{Value};
		}
	}
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
			elsif ( $type eq '' ) {
				$new->{$camelizedKey} = $scalar;
			}
			else {
				#				$self->Logger->verbose("...skipping scalar type: $type");
			}
		}
	}
	elsif ( ref($data) eq '' ) {
		if ( defined $data ) {
			if ( $data =~ /DNSName/i ) {
				$new = 'dnsName';    # want dnsName not dNSName
			}
			elsif ($data =~ /TTL/i) {
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

