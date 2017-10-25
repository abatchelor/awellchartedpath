#!/usr/bin/perl

use 5.010;
use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;


# create a hash to track how many times we've used each base filename
my %nameCounts = ();
my $posCount = 0;
my $outString = '';


# Identify list of files to convert
#my $directory="/Users/nateperkins/github/awellchartedpath/raw_walks";
my $directory=$ARGV[0];
opendir(DIR, $directory) or die "couldn't open $directory: $!\n";
my @files = readdir DIR;
closedir DIR;
foreach my $filesList (@files) {
	if (index($filesList, "tcx") != -1) {
   		print "Opening ", $filesList, "\n";

		#my $filename = '2017-10-02T09_09_10-03_00_PT1H17M30S_Walking.tcx';

		my $dom = XML::LibXML->load_xml(location => $filesList);
		my $xpc = XML::LibXML::XPathContext->new($dom);
		$xpc->registerNs('main',  'http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2');
		$xpc->registerNs('author', 'http://www.w3.org/2001/XMLSchema-instance');

		foreach my $activity ($xpc->findnodes('//main:Activity')) {
			# keep the output in a string and write it to the file all at once
			$outString = '';
			$posCount = 0;
			
		#	my $id = $xpc->findvalue('//main:Id',$activity); # this returns all Ids in the file
			my $id = $xpc->findvalue('./main:Id', $activity);
	
			# create filename from date in Id
			my $outFileName = substr $id, 0, 10;
			if (exists $nameCounts{$outFileName}) {
				$nameCounts{$outFileName} += 1;
			} else {
				$nameCounts{$outFileName} = 1;
			}
			$outFileName .= '-' . sprintf("%02d", $nameCounts{$outFileName});
			$outFileName .= ".yml";
	
		#	$outString .= "--- \nstart_date: " . $id . "\n"; # use this alternative to demonstrate that each Activity is getting the correct Id
			$outString .= "--- \nstart_date: " . substr($id, 0, 10) . "\n";
			$outString .= "type: walk\n";
			$outString .= "from: \n";
		# 	for my $coordinates ( $xpc->findnodes('//main:Position', $activity) ) {
			for my $coordinates ( $xpc->findnodes('./main:Lap/main:Track/main:Trackpoint/main:Position', $activity) ) {
					my $LongitudeDegrees = $xpc->findvalue('main:LongitudeDegrees', $coordinates);
					my $LatitudeDegrees = $xpc->findvalue('main:LatitudeDegrees', $coordinates);
					$outString .= "- \"[" . $LongitudeDegrees . ", " . $LatitudeDegrees . "],\"\n";
					$posCount++;
			}
			$outString .= "\n---\n";

			# Write the file in the specified subdirectory
			open(my $fh, '>', 'walkTracks/' . $outFileName);
			print $fh $outString;
			close $fh;
			print "done - wrote Activity to ", $outFileName, " for Id: ", $id, " with ", $posCount, " Positions" . "\n";

		} #foreach Activity
	} #if tcx file
} # foreach file in directory from first command line argument

