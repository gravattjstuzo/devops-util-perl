package Stuzo::AWS;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use JSON;
use Devel::Confess;

extends 'Stuzo';

with
  'Util::Medley::Roles::Attributes::Logger',
  'Util::Medley::Roles::Attributes::Spawn';

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

method aws (Str :$subcommand!,
			Str :$profile) {

	my @cmd = ('aws');
	push @cmd, '--profile', $profile if $profile;
	push @cmd, '--no-paginate';
	push @cmd, $subcommand;
	my $command = join ' ', @cmd;

	my ( $stdout, $stderr, $exit ) = $self->Spawn->capture($command);
	if ($exit) {
		confess $stderr;
	}

	my $href = decode_json($stdout);

	return $href;
}

method awsX ( Str 			 :$subcommand!, 
			  ArrayRef|Undef :$excludeProfiles,
			  Str|Undef      :$excludeProfilesRe,
			  Str|Undef      :$includeProfilesRe ) {

	my @cmd = ( 'awsx', $subcommand, '--merge-output' );

	push @cmd, '-e', join( ',', @$excludeProfiles ) if $excludeProfiles;
	push @cmd, '-E', $excludeProfilesRe             if $excludeProfilesRe;
	push @cmd, '-I', $includeProfilesRe             if $includeProfilesRe;

	my ( $stdout, $stderr, $exit ) = $self->Spawn->capture("@cmd");
	if ($exit) {
		confess $stderr;
	}

	my $aref = decode_json($stdout);

	return $aref;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

