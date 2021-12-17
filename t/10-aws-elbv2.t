#!/usr/bin/env perl

use Modern::Perl;
use Test::More;
use Data::Printer alias => 'pdump';

###########################

use_ok('Stuzo::AWS::ELBv2');

my $ec2 = Stuzo::AWS::ELBv2->new;
my $aref = $ec2->awsXDescribeLoadBalancers(includeProfilesRe => 'internal');
isa_ok($aref, 'ARRAY');

foreach my $elb (@$aref) {
	isa_ok($elb, 'Stuzo::AWS::ELBv2::LoadBalancer');
}

done_testing();

##########################
