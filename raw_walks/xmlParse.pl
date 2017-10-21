#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use XML::LibXML;

my $filename = '2017-10-04T14_39_35-03_00_PT49M30S_Walking.tcx';

my $dom = XML::LibXML->load_xml(location => $filename);

print "--- \nstart_date: ";
foreach my $id ($dom->findnodes('//Id')) {
    say substr $id->to_literal(), 0, 10; 
}

print "type: walk\n";
print "from: \n";

foreach my $coordinates ($dom->findnodes('//Position')) {
    print "- \"[", $coordinates->findvalue('./LongitudeDegrees'), ", ", $coordinates->findvalue('./LatitudeDegrees'), "],\"\n";
}

print "\n---";
print "\n";

