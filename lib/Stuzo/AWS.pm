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

method aws (Str       :$subcommand!,
			Str|Undef :$profile) {

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

method listProfiles (ArrayRef|Undef :$excludeProfiles,
                     Str|Undef      :$excludeProfilesRe,
                     Str|Undef      :$includeProfilesRe ) { 

    my %exclude;
    if ($excludeProfiles) {
        foreach my $profile (@$excludeProfiles) {
            $exclude{$profile} = 1;	
        }	
    }	
    
	my @cmd = ('aws', 'configure', 'list-profiles');
    my ( $stdout, $stderr, $exit ) = $self->Spawn->capture("@cmd");
    if ($exit) {
        confess $stderr;
    }
    
    my @profiles;
    foreach my $profile (split(/\n/, $stdout)) {
    	
    	next if $profile eq 'default';
        next if $exclude{$profile};
        
        if ($includeProfilesRe) {
        	if ($profile !~ /$includeProfilesRe/) {
        	   next;
        	}
        }
        		
        if ($excludeProfilesRe) {
            if ($profile =~ /$excludeProfilesRe/) {
                next;	
            }     	
        } 
        
        push @profiles, $profile;
    }
    
    return \@profiles;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;

