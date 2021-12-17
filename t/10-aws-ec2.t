#!/usr/bin/env perl

use Modern::Perl;
use Test::More;
use Data::Printer alias => 'pdump';

###########################

use_ok('Stuzo::AWS::EC2');

my $ec2 = Stuzo::AWS::EC2->new;
my $aref = $ec2->awsXDescribeNetworkInterfaces(includeProfilesRe => 'internal');
isa_ok($aref, 'ARRAY');

foreach my $interface (@$aref) {
	isa_ok($interface, 'Stuzo::AWS::EC2::NetworkInterface');
}

done_testing();

##########################
