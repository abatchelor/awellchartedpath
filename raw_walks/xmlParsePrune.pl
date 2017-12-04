#!/usr/bin/perl
# perl xmlParsePrune.pl 3 .

use 5.010;
use strict;
use warnings;

use XML::LibXML;
use XML::LibXML::XPathContext;

# Arguments - both arguments are mandatory
# 1st argument is the deflection threshold (in feet) for pruning waypoints. 0 or -1 means no pruning. Suggest 3 feet
# 2nd argument is directory in which to find the source tcx files

# create a hash to track how many times we've used each base filename
my %nameCounts = ();
my $posCount = 0;
my $pruneCount = 0;
my $outString = '';
my $midOut = ''; # used for storing output string for waypoints that are candidates for pruning

my $dt = $ARGV[0];
print "The deflection threshold is ", $dt, " feet.\n";
my $feetPerDegree = 364826.88;
my $pi = 3.14159265358979;
sub deg_to_rad { ($_[0]/180) * $pi }
my ($x1, $y1, $x2, $y2, $x0, $y0); # 0 is the point from which we are calculating deflection
my $lonFactor;
my $d = 1.1; # calculated deflection

# Identify list of files to convert
#my $directory="/Users/nateperkins/github/awellchartedpath/raw_walks";
my $directory=$ARGV[1];
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
			$pruneCount = 0;
			
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
				if ($dt <= 0) {
					# write out every point no matter what
					$outString .= "- \"[" . sprintf("%6.5f", $LongitudeDegrees) . ", " . sprintf("%6.5f", $LatitudeDegrees) . "],\"\n";
				} else {
					if ($posCount < 1) {
						# write out the first point no matter what
						$outString .= "- \"[" . sprintf("%6.5f", $LongitudeDegrees) . ", " . sprintf("%6.5f", $LatitudeDegrees) . "],\"\n";
						$lonFactor = cos(deg_to_rad($LatitudeDegrees)); # base this on the first longitude. Others will be close enough.
						$x1 = $LatitudeDegrees;
						$y1 = $LongitudeDegrees * $lonFactor;
					} else {
						if ($posCount < 2) {
							# this is the second point. Don't know if we're writing this one out until we get to point 3
							$x0 = $LatitudeDegrees;
							$y0 = $LongitudeDegrees * $lonFactor;
							$midOut = "- \"[" . sprintf("%6.5f", $LongitudeDegrees) . ", " . sprintf("%6.5f", $LatitudeDegrees) . "],\"\n";
						} else {
							# we already have a point 1 and a point 0. This is point 2. Calculate deflection so we know if we're saving the point 0
							$x2 = $LatitudeDegrees;
							$y2 = $LongitudeDegrees * $lonFactor;
							if (($x1 == $x2) && ($y1 == $y2)) {
								# point 1 and point 2 are the same so the deflection is simply the distance to point 0
								$d = sqrt(($y2-$y0)*($y2-$y0) + ($x2-$x0)*($x2-$x0)) * $feetPerDegree;
							} else {
								# found this "distance from point to line" formula in wikipedia
								$d = abs(($y2-$y1)*$x0 - ($x2-$x1)*$y0 + $x2*$y1 - $y2*$x1)/sqrt(($y2-$y1)*($y2-$y1) + ($x2-$x1)*($x2-$x1)) * $feetPerDegree;
							}
							if ($d > $dt) {
								# we are keeping the point 0; write it out and move p0 to p1
								$outString .= $midOut;
								$x1 = $x0; $y1 = $y0;
							} else {
								# we are pruning point 0; point 1 stays the same
								$pruneCount++;
							}
						# move point 2 to point 0 and save the output line in case we end up using this point
						$x0 = $x2; $y0 = $y2;
						$midOut = "- \"[" . sprintf("%6.5f", $LongitudeDegrees) . ", " . sprintf("%6.5f", $LatitudeDegrees) . "],\"\n";
						}
					}
				}
				$posCount++;
			}
			$outString .= $midOut; # write out the final waypoint
			$outString .= "\n---\n";

			if ($posCount - $pruneCount > 9) {
				# Write the file in the specified subdirectory
				open(my $fh, '>', 'walkTracks/' . $outFileName);
				print $fh $outString;
				close $fh;
				print "done - wrote Activity to ", $outFileName, " for Id: ", $id, " with ", $posCount - $pruneCount, " Positions (Pruned " . $pruneCount , " positions)" , "\n";
			} else {
				print "done - skipped Activity for Id: ", $id, " with only ", $posCount - $pruneCount, " Positions (Pruned " . $pruneCount , " positions)" . "\n";
			}

		} #foreach Activity
	} #if tcx file
} # foreach file in directory from first command line argument

