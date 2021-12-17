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

method awsX ( Str 			 :$subcommand!, 
			  ArrayRef|Undef :$excludeProfiles ) {

	my $command = "awsx $subcommand";
	$command .= " --merge-output";

	if ($excludeProfiles) {
		$command .= " -e " . join( ',', @$excludeProfiles );
	}

	my ( $stdout, $stderr, $exit ) = $self->Spawn->capture($command);
	if ($exit) {
		confess $stderr;
	}

	my $aref = decode_json($stdout);

	return $aref;
}

method awsXGetAllPublicAddresses (ArrayRef|Undef :$excludeProfiles) {

	my $aref =
	  $self->awsXDescribeAddresses( excludeProfiles => $excludeProfiles, );

	$aref = $self->awsXDescribeLoadBalancers(
		excludeProfiles => $excludeProfiles,
		type            => 'application',
	);
}

=pod

 returns ArrayRef[ HashRef[ ArrayRef ] ]
 
=cut

method awsXDescribeLoadBalancers (Str            :$type,
								  ArrayRef|Undef :$excludeProfiles) {

	my $aref = $self->awsX(
		subcommand      => 'elbv2 describe-load-balancers',
		excludeProfiles => $excludeProfiles
	);

	foreach my $href (@$aref) {

		my @elbs = ();

		foreach my $elb ( @{ $href->{LoadBalancers} } ) {
			if ( $type and $elb->{Type} ne $type ) {
				next;
			}

			push @elbs, $elb;
		}

		$href->{LoadBalancers} = \@elbs;
	}

	return $aref;
}

=pod

 returns ArrayRef[ HashRef[ ArrayRef ] ]
 
=cut

method awsXDescribeAddresses (Regexp    	 :$matchTagName,
							  ArrayRef|Undef :$excludeProfiles,
							  ArrayRef|Undef :$excludeNamesLike = []) {

	my $aref = $self->awsX(
		subcommand      => 'ec2 describe-addresses',
		excludeProfiles => $excludeProfiles,
	);

	foreach my $href (@$aref) {

		my @addresses = ();

		foreach my $eip ( @{ $href->{Addresses} } ) {

			my $name;
			if ( $eip->{Tags} ) {
				$name = $self->getTagValue(
					tags => $eip->{Tags},
					key  => 'Name'
				);
			}

			if ($name) {

				my $skip = 0;
				foreach my $excl (@$excludeNamesLike) {

					# skip matches
					if ( $name =~ /$excl/ ) {
						$skip = 1;
						last;
					}
				}

				next if $skip;
			}

			if ($matchTagName) {

				# only add it if it matches
				if ($name) {
					if ( $name !~ $matchTagName ) {

						# does not match
						next;
					}
				}
				else {
					# if name not defined, it can't match
					next;
				}
			}

			# if we get here we have passed all conditions
			push @addresses, $eip;
		}

		$href->{Addresses} = \@addresses;
	}

	return $aref;
}

method nagGetHostObj (Str      :$hostName!,
					  Str      :$address!,
					  Str      :$checkCommand,
					  Int      :$checkInterval = 5,
					  Int      :$retryInterval = 1,
					  Int      :$maxCheckAttempts = 3,
					  Str      :$checkPeriod = '24x7',
					  Int      :$notifyInterval = 60,
					  Str      :$notifyPeriod = '24x7',
					  ArrayRef :$notifyOptions = ['d', 'u', 'r', 'n'],
					  ArrayRef :$use = ['generic-host', 'host-pnp'],
) {

	my @directives;
	push @directives, [ 'use',                   join( ',', @$use ) ];
	push @directives, [ 'host_name',             $hostName ];
	push @directives, [ 'address',               $address ];
	push @directives, [ 'check_interval',        $checkInterval ];
	push @directives, [ 'retry_interval',        $retryInterval ];
	push @directives, [ 'max_check_attempts',    $maxCheckAttempts ];
	push @directives, [ 'check_period',          $checkPeriod ];
	push @directives, [ 'notification_interval', $notifyInterval ];
	push @directives, [ 'notification_period',   $notifyPeriod ];
	push @directives, [ 'notification_options',  join( ',', @$notifyOptions ) ];
	push @directives, [ 'check_command', $checkCommand ] if $checkCommand;

	my $maxLen = $self->_nagGetDirectiveMaxLength( directives => \@directives );
	my @lines  = ("define host {");

	foreach my $directiveAref (@directives) {
		my $format = '    %-' . $maxLen . "s %s";
		push @lines, sprintf( $format, @$directiveAref );
	}

	push @lines, "}";

	return join( "\n", @lines );
}

method nagGetHostGroupObj (Str      :$name!,
						   ArrayRef :$members!) {

	my @directives;
	push @directives, [ 'hostgroup_name', $name ];
	push @directives, [ 'members',        join( ',', @$members ) ];

	my $maxLen = $self->_nagGetDirectiveMaxLength( directives => \@directives );
	my @lines  = ("define hostgroup {");

	foreach my $directiveAref (@directives) {
		my $format = '    %-' . $maxLen . "s %s";
		push @lines, sprintf( $format, @$directiveAref );
	}

	push @lines, "}";

	return join( "\n", @lines );
}

method nagGetServiceObj (Str      :$desc!,
						 Str      :$hostGroupName,
					  	 Str      :$checkCommand!,
					     Int      :$checkInterval = 5,
					     Int      :$retryInterval = 1,
					     Int      :$maxCheckAttempts = 3,
					     Str      :$checkPeriod = '24x7',
					     Int      :$notifyInterval = 60,
					     Str      :$notifyPeriod = '24x7',
					     ArrayRef :$use = ['generic-service', 'srv-pnp']) {

	my @directives;
	push @directives, [ 'use',                   join( ',', @$use ) ];
	push @directives, [ 'service_description',   $desc ];
	push @directives, [ 'hostgroup_name',        $hostGroupName ];
	push @directives, [ 'check_interval',        $checkInterval ];
	push @directives, [ 'retry_interval',        $retryInterval ];
	push @directives, [ 'max_check_attempts',    $maxCheckAttempts ];
	push @directives, [ 'check_period',          $checkPeriod ];
	push @directives, [ 'notification_interval', $notifyInterval ];
	push @directives, [ 'notification_period',   $notifyPeriod ];
	push @directives, [ 'check_command',         $checkCommand ];

	my $maxLen = $self->_nagGetDirectiveMaxLength( directives => \@directives );
	my @lines  = ("define service {");

	foreach my $directiveAref (@directives) {
		my $format = '    %-' . $maxLen . "s %s";
		push @lines, sprintf( $format, @$directiveAref );
	}

	push @lines, "}";

	return join( "\n", @lines );
}

method getTagValue (ArrayRef :$tags!,
		  		    Str      :$key!) {

	foreach my $href (@$tags) {
		if ( $href->{Key} and $href->{Key} eq $key ) {
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
			if ( $data =~ /dnsname/i ) {
				$new = 'dnsName';    # want dnsName not dNSName
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

method _nagGetDirectiveMaxLength (ArrayRef :$directives!) {

	my $maxLen = 0;
	foreach my $directiveAref (@$directives) {
		my $directive = $directiveAref->[0];
		my $length    = length $directive;
		if ( $length > $maxLen ) {
			$maxLen = $length;
		}
	}

	return $maxLen;
}

__PACKAGE__->meta->make_immutable;

1;

