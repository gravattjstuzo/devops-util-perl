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

has profile => (
    is      => 'ro',
    isa     => 'Str',
);

##############################################################################
# PRIVATE_ATTRIBUTES
##############################################################################

has _loadBalancers => (
    is => 'rw',
    isa => 'HashRef',
);

has _tags => (
    is => 'rw',
    isa => 'HashRef[ArrayRef]',
    default => sub {{}},
);

##############################################################################
# CONSTRUCTOR
##############################################################################

##############################################################################
# PUBLIC METHODS
##############################################################################

method describeLoadBalancer (Str :$arn!) {
    
    my $cache = $self->_loadBalancers;	
    if (!$cache->{$arn}) {
        
        my %param;
        $param{subcommand} = "elbv2 describe-load-balancers --load-balancer-arns $arn";
        $param{profile} = $self->profile if $self->profile;  	
        
        my $href = $self->aws(%param);
        
        foreach my $lbHref (@{ $href->{LoadBalancers} }) {
            if ($lbHref->{LoadBalancerArn} eq $arn) {
                $cache->{$arn} = $lbHref;
            }
        }
    }
    
    if ($cache->{$arn}) {
    	return $cache->{$arn};
    }
}

method describeLoadBalancers (Str :$type,
                              Str :$scheme,
                              Str :$stateCode) {

    my %param;
    $param{subcommand} = 'elbv2 describe-load-balancers';
    $param{profile} = $self->profile if $self->profile;
    
    my $href = $self->aws(%param);
    
    my %cache; 
    my @resp;
    
    foreach my $lbHref (@{ $href->{LoadBalancers} }) {
          	
        next if $type and $lbHref->{Type} ne $type;
        next if $scheme and $lbHref->{Scheme} ne $scheme;
        next if $stateCode and $lbHref->{State}->{Code} ne $stateCode;
        
        push @resp, $lbHref	
    }
   
=pod example response

[
    [0] {
            AvailabilityZones       [
                [0] {
                        LoadBalancerAddresses   [],
                        SubnetId                "subnet-00ffbe60d78c35d8d",
                        ZoneName                "us-east-1a"
                    },
                [1] {
                        LoadBalancerAddresses   [],
                        SubnetId                "subnet-06efcd76d17a448fa",
                        ZoneName                "us-east-1c"
                    },
                [2] {
                        LoadBalancerAddresses   [],
                        SubnetId                "subnet-09f65c28a3377194f",
                        ZoneName                "us-east-1b"
                    }
            ],
            CanonicalHostedZoneId   "Z35SXDOTRQ7X7K",
            CreatedTime             "2022-01-14T13:40:43.590000+00:00" (dualvar: 2022),
            DNSName                 "k8s-argocd-argocd-7bf7d767f1-1469684114.us-east-1.elb.amazonaws.com",
            IpAddressType           "ipv4",
            LoadBalancerArn         "arn:aws:elasticloadbalancing:us-east-1:729361165913:loadbalancer/app/k8s-argocd-argocd-7bf7d767f1/39a634d2f900b0fe",
            LoadBalancerName        "k8s-argocd-argocd-7bf7d767f1",
            Scheme                  "internet-facing",
            SecurityGroups          [
                [0] "sg-0d621fd32aff9ae19"
            ],
            State                   {
                Code   "active"
            },
            Type                    "application",
            VpcId                   "vpc-07dc8ae7f4242ce3a"
        },
    [1] {
            "LoadBalancerArn": "arn:aws:elasticloadbalancing:us-east-1:729361165913:loadbalancer/net/oc-stage-circlek-external-nlb/65497eb015f4dab3",
            "DNSName": "oc-stage-circlek-external-nlb-65497eb015f4dab3.elb.us-east-1.amazonaws.com",
            "CanonicalHostedZoneId": "Z26RNL4JYFTOTI",
            "CreatedTime": "2022-01-14T15:46:28.397000+00:00",
            "LoadBalancerName": "oc-stage-circlek-external-nlb",
            "Scheme": "internet-facing",
            "VpcId": "vpc-07dc8ae7f4242ce3a",
            "State": {
                "Code": "active"
            },
            "Type": "network",
            "AvailabilityZones": [
                {
                    "ZoneName": "us-east-1b",
                    "SubnetId": "subnet-09f65c28a3377194f",
                    "LoadBalancerAddresses": [
                        {
                            "IpAddress": "52.203.232.77",
                            "AllocationId": "eipalloc-096b3d51b8f3e064c"
                        }
                    ]
                },
                ...
            ],
            ...
        }                
]
    
=cut
 
    return \@resp; 
}

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
		my $profileName = $href->{ProfileName};
		
		foreach my $elbHref ( @{ $href->{LoadBalancers} } ) {
			my $camelizedHref = $self->__camelize($elbHref);
			my $loadBalancer =
			  Stuzo::AWS::ELBv2::LoadBalancer->new(%$camelizedHref, profileName => $profileName);



=pod
		
{
    "TagDescriptions": [
        {
            "ResourceArn": "arn:aws:elasticloadbalancing:us-east-1:890710746291:loadbalancer/app/bf17b822-ocdrone-drone-4333/530ab6b0c2b42631",
            "Tags": [
                {
                    "Key": "ingress.k8s.aws/stack",
                    "Value": "oc-drone/drone"
                },
                
=cut
		    
		    my @tags;  	
			my $arn = $loadBalancer->loadBalancerArn;
            my $href = $self->aws(profile => $profileName, subcommand => "elbv2 describe-tags --resource-arns $arn");
            my $aref = $href->{TagDescriptions};
            foreach my $tagDescHref (@$aref) {
                if ($tagDescHref->{Tags}) {
                	push @tags, @{ $tagDescHref->{Tags} };
                }	
            }
            
            $loadBalancer->tags(\@tags);
           
            #
            # check type
            # 
            if ($type) {
                if ( $loadBalancer->type eq $type ) {
                    push @elbs, $loadBalancer;
                }
                else {
                    next;   
                }
            }
            else {
                push @elbs, $loadBalancer;
            }            
		}
	}
	
	return \@elbs;
}

method describeTags (Str :$arn!) {

    my $cache = $self->_tags;
    if (!$cache->{$arn}) {
    	
        my %param;
        $param{subcommand} = "elbv2 describe-tags --resource-arns $arn";
        $param{profile} = $self->profile if $self->profile;
    
        my $href = $self->aws(%param);
        
        my $tagDescAref = $href->{TagDescriptions};
        foreach my $tagHref (@{ $href->{TagDescriptions} }){
            my $arn = $tagHref->{ResourceArn};
            if ($arn eq $tagHref->{ResourceArn}) {
            	if ($tagHref->{Tags}) {
                    $cache->{$arn} = $tagHref->{Tags};
            	}
            	else {
                    $cache->{$arn} = [];	
                }
            }
        }
    }
    

=pod example response
     
            [
                {
                    "Key": "ManagedByK8s",
                    "Value": "true"
                },
                {
                    "Key": "ManagedByTerraform",
                    "Value": "false"
                },
                {
                    "Key": "ingress.k8s.aws/stack",
                    "Value": "oc-shared-group"
                },
                ...
            ]

=cut             
   
   return $cache->{$arn}; 
}

method getTagValue (Str :$arn!,
                    Str :$key!) {

    my $tagsAref = $self->describeTags(arn => $arn);
    
    return $self->SUPER::getTagValue (tags => $tagsAref,
                                      key => $key);
}

method getLoadBalancerAllocationIds (Str :$arn!) {

    my @ids;
    
    my $lb = $self->describeLoadBalancer(arn => $arn);
    if (defined $lb) {
        foreach my $azHref (@{ $lb->{AvailabilityZones} }) {
            foreach my $address ( @{ $azHref->{LoadBalancerAddresses} } ) {
                if ($address->{AllocationId}) {
                    push @ids, $address->{AllocationId};
                }       
            }
        }
    }

    return @ids;    
}
                    
##############################################################################
# PRIVATE METHODS
##############################################################################

__PACKAGE__->meta->make_immutable;

1;
