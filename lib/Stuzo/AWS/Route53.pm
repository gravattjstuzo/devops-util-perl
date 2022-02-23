package Stuzo::AWS::Route53;

use Modern::Perl;
use Moose;
use namespace::autoclean;
use Kavorka 'method';
use Data::Printer alias => 'pdump';
use Devel::Confess;
use Stuzo::AWS::Route53::HostedZone;
use Stuzo::AWS::Route53::ResourceRecordSet;
use Data::Validate::IP         ('is_ipv4');
use Util::Medley::Simple::List ('uniq');

extends 'Stuzo::AWS';

with
  'Util::Medley::Roles::Attributes::Cache',
  'Util::Medley::Roles::Attributes::Logger',
  'Util::Medley::Roles::Attributes::Spawn',
  'Util::Medley::Roles::Attributes::String';

##############################################################################
# CONSTANTS
##############################################################################

use constant CACHE_NS_HOSTED_ZONES => 'stuzo-aws-route53';

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

has _hostedZones => (
	is        => 'rw',
	isa       => 'HashRef',
	predicate => '_hasHostedZones',
);

has _resourceRecordSets => (
	is      => 'rw',
	isa     => 'HashRef[ArrayRef]',
	default => sub { {} }
);

##############################################################################
# CONSTRUCTOR
##############################################################################

method BUILD {

}

##############################################################################
# PUBLIC METHODS
##############################################################################

method listHostedZones (Bool :$privateZone) {

	if ( !$self->_hasHostedZones ) {
		my %param;
		$param{subcommand} = 'route53 list-hosted-zones';
		$param{profile}    = $self->profile if $self->profile;
		my $href = $self->aws(%param);
		$self->_hostedZones($href);
	}

	my $href = $self->_hostedZones;

	my @resp;
	foreach my $zoneHref ( @{ $href->{HostedZones} } ) {

		if ( defined $privateZone ) {
			if ( $zoneHref->{Config}->{PrivateZone} != $privateZone ) {
				next;
			}
		}

		push @resp, $zoneHref;
	}

=pod example resp
    [    
       {
            "Id": "/hostedzone/Z1DRJ9MP941SAB",
            "Name": "staging.ocp.com.",
            "CallerReference": "73CB02EE-DEBF-1DBE-9ECE-8E5E9904BACE",
            "Config": {
                "PrivateZone": true
            },
            "ResourceRecordSetCount": 5
        },
    ]
=cut

	return \@resp;
}

=pod

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

=cut

method listResourceRecordSets (Str :$hostedZoneId) {

	my $cache = $self->_resourceRecordSets;
	if ( !$cache->{$hostedZoneId} ) {

		my @cmd = (
			'route53', 'list-resource-record-sets', '--hosted-zone-id',
			$hostedZoneId
		);

		my %param;
		$param{subcommand} = "@cmd";
		$param{profile}    = $self->profile if $self->profile;
		my $href = $self->aws(%param);

		$cache->{$hostedZoneId} = $href->{ResourceRecordSets};
	}

	return $cache->{$hostedZoneId};

=pod example resp

    [	
        {
            "Name": "dev.internal.opencomm.io.",
            "Type": "NS",
            "TTL": 60,
            "ResourceRecords": [
                {
                    "Value": "ns-1908.awsdns-46.co.uk"
                },
                {
                    "Value": "ns-1293.awsdns-33.org"
                },
                {
                    "Value": "ns-833.awsdns-40.net"
                },
                {
                    "Value": "ns-335.awsdns-41.com"
                }
            ]
        },
        {
            "Name": "drone.opencomm.io.",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "Z35SXDOTRQ7X7K",
                "DNSName": "bf17b822-ocdrone-drone-4333-815529931.us-east-1.elb.amazonaws.com.",
                "EvaluateTargetHealth": true
            }
        },
        
    ]
    
=cut

}

method findRecordsByAliasTarget (Str  :$dnsName!,
                                 Str  :$hostedZoneId,
                                 Bool :$privateZone) {

	my @records;

	my %params;
	$params{privateZone} = $privateZone if defined $privateZone;

	my $zones = $self->listHostedZones(%params);
	foreach my $zone (@$zones) {

		my $records =
		  $self->listResourceRecordSets( hostedZoneId => $zone->{Id} );
		foreach my $rec (@$records) {

			if ( exists $rec->{AliasTarget} ) {
				my $target = $rec->{AliasTarget};

				if ( $self->stripTrailingDot($dnsName) ne
					$self->stripTrailingDot( $target->{DNSName} ) )
				{
					next;
				}

				next
				  if $hostedZoneId and $hostedZoneId ne $target->{HostedZoneId};

				push @records, $rec;
			}
		}
	}

=pod example response

    [
        {
            "Name": "activate.stage.circlek.oc.ai.",
            "Type": "A",
            "AliasTarget": {
                "HostedZoneId": "Z35SXDOTRQ7X7K",
                "DNSName": "oc-stage-circlek-shared-alb-1846438719.us-east-1.elb.amazonaws.com.",
                "EvaluateTargetHealth": true
            }
        },
        ....
    ]        

=cut

	return \@records;
}

=pod

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

=cut

=pod

method ipToDnsNames (Str :$ip) {

    my $zonesAref = $self->listHostedZones;

    foreach my $zone (@$zonesAref) {

        my $records =
          $self->listResourceRecordSets( hostedZoneId => $zone->id );
    }   
}

=cut

method ipToCName (Str $ip!) {

	my @cnames;

	my $zonesAref = $self->listHostedZones;
	foreach my $zone (@$zonesAref) {

		next if $zone->isPrivate;

		my $records =
		  $self->listResourceRecordSets( hostedZoneId => $zone->id );

		foreach my $rec (@$records) {

			if ( $rec->type eq 'CNAME' ) {

				foreach my $href ( @{ $rec->resourceRecords } ) {
					my $value = $href->{value};
					$value =~ s/\.$//;    # remove trailing .

					my $_ip;
					if ( is_ipv4($value) ) {
						$_ip = $value;
					}
					else {
						eval { $_ip = $self->nslookup($value); };
						if ($@) {
							$self->Logger->warn("bad cname: $value");
							next;
						}
					}

					if ( $ip eq $_ip ) {
						push @cnames, $value;
					}
				}
			}
		}
	}

	return @cnames;
}

method ipToA (Str $ip!) {

	my @a;

	my $zonesAref = $self->listHostedZones;
	foreach my $zone (@$zonesAref) {

		next if $zone->isPrivate;

		my $records =
		  $self->listResourceRecordSets( hostedZoneId => $zone->id );

		foreach my $rec (@$records) {

			if ( $rec->type eq 'A' ) {
				if ( $rec->resourceRecords ) {

					foreach my $href ( @{ $rec->resourceRecords } ) {
						my $value = $href->{value};
						$value =~ s/\.$//;    # remove trailing .

						my $_ip;
						if ( is_ipv4($value) ) {
							$_ip = $value;
						}
						else {
							$_ip = $self->nslookup($value);
						}

						if ( $ip eq $_ip ) {
							push @a, $value;
						}
					}
				}
				elsif ( $rec->aliasTarget ) {

					my $dnsName = $rec->aliasTarget->{dnsName};
					my @ips     = $self->nslookup($dnsName);
					foreach my $_ip (@ips) {
						if ( $ip eq $_ip ) {
							push @a, $dnsName;
							last;
						}
					}
				}
				else {
					die $rec;
				}
			}
		}
	}

	return @a;
}

method ipToAAAA (Str $ip!) {

	my @aaaa;

	my $zonesAref = $self->listHostedZones;
	foreach my $zone (@$zonesAref) {

		next if $zone->isPrivate;

		my $records =
		  $self->listResourceRecordSets( hostedZoneId => $zone->id );

		foreach my $rec (@$records) {

			if ( $rec->type eq 'AAAA' ) {

=pod				
        aliasTarget   {
            dnsName                "d2kq87uq1g2ovy.cloudfront.net.",
            evaluateTargetHealth   0 (JSON::PP::Boolean) (read-only),
            hostedZoneId           "Z2FDTNDATAQYW2"
        },
        name          "activate-cc.prod.cefco.opencomm.io.",
        type          "AAAA"
=cut

				my $name    = $rec->name;
				my $dnsName = $rec->aliasTarget->{dnsName};
				my @ips     = $self->nslookup($dnsName);

				foreach my $_ip (@ips) {
					if ( $ip eq $_ip ) {
						push @aaaa, $name, $dnsName;
						last;
					}
				}
			}
		}
	}

	return @aaaa;
}

method ipToDnsNames (Str $ip!) {

	my @names;
	push @names, $self->ipToA($ip);
	push @names, $self->ipToAAAA($ip);
	push @names, $self->ipToCName($ip);

	return uniq(@names);
}

method reverseSearchDnsAliases (Str :$dnsName!) {

	my $zonesAref = $self->listHostedZones;

	my @aliases;
	foreach my $zone (@$zonesAref) {

		next if $zone->isPrivate();

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
					$targetDnsName =~ s/\.$//;    # remove trailing .
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

method stripTrailingDot (Str $str!) {

	$str =~ s/\.$//;

	return $str;
}

method stripTrailingDots (ArrayRef $list!) {

	my @new;
	foreach my $str (@$list) {
		push @new, $self->stripTrailingDot($str);
	}

	return \@new;
}

##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
