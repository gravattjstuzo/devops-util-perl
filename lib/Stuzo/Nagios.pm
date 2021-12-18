package Stuzo::Nagios;

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

method getHostObj (Str      :$hostName!,
				   Str      :$address!,
				   Str|Undef :$checkCommand,
				   ArrayRef :$parents,
				   Int      :$checkInterval = 5,
				   Int      :$retryInterval = 1,
				   Int      :$maxCheckAttempts = 3,
				   Str      :$checkPeriod = '24x7',
				   Int      :$notifyInterval = 60,
				   Str      :$notifyPeriod = '24x7',
				   ArrayRef :$notifyOptions = ['d', 'u', 'r', 'n'],
				   ArrayRef :$use = ['generic-host', 'host-pnp'],
) {
	$hostName = $self->_validateHostName(hostName => $hostName);

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
	push @directives, [ 'parents', join(',', @$parents) ] if $parents;

	my $maxLen = $self->_nagGetDirectiveMaxLength( directives => \@directives );
	my @lines  = ("define host {");

	foreach my $directiveAref (@directives) {
		my $format = '    %-' . $maxLen . "s %s";
		push @lines, sprintf( $format, @$directiveAref );
	}

	push @lines, "}";

	return join( "\n", @lines );
}

method getHostGroupObj (Str      :$name!,
					    ArrayRef :$members!) {

	my @members;
	foreach my $member (@$members) {
		push @members, $self->_validateHostName(hostName => $member);			
	}
	
	my @directives;
	push @directives, [ 'hostgroup_name', $name ];
	push @directives, [ 'members',        join( ',', @members ) ];

	my $maxLen = $self->_nagGetDirectiveMaxLength( directives => \@directives );
	my @lines  = ("define hostgroup {");

	foreach my $directiveAref (@directives) {
		my $format = '    %-' . $maxLen . "s %s";
		push @lines, sprintf( $format, @$directiveAref );
	}

	push @lines, "}";

	return join( "\n", @lines );
}

method getServiceObj (Str      :$desc!,
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

##############################################################################
# PRIVATE METHODS
##############################################################################

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

method _validateHostName (Str :$hostName!) {
	
	if ( $self->String->isBlank($hostName) ) {
		confess "hostName can't be blank";
	}

	if ( $hostName =~ /\s/ ) {
		confess "hostName can't have spaces";
	}	
	
	return lc $hostName;
}

__PACKAGE__->meta->make_immutable;

1;
