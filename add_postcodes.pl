#!/usr/bin/perl -w

# Info: Inserts postcodes to database. See http://github.com/andrewharvey/myschool/
# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 07 Feb 2010 
#
# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

# Usage: ./add_postcodes.pl postcodes.csv

use strict;
use DBI;

my $dbname = 'myschool';
my $dbhost = 'localhost';
my $dbuser = '';
my $dbpass = '';

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", "$dbuser", "$dbpass", {'RaiseError' => 1});

if (@ARGV ne 1) {
	print "Usage $0 postcodes.csv\n";
	exit 1;
}

#file should be format
#"Pcode","Locality","State",
#See http://www1.auspost.com.au/download/pc-full.zip
open POSTCODE, "$ARGV[0]";
my $num_postcodes = `wc -l $ARGV[0]` - 1;
print "$num_postcodes postcodes.\n";

readline POSTCODE; #chew the header line
my $i = 0;
while (<POSTCODE>) {
	my $line = $_;
	my @row = split /,/, $line;
	my @prow;
	foreach (@row) {
		s/^\"(.*)\"$/$1/; #get rid of quotes in quoted values. ie "2000" -> 2000
		s/^(\s*)//g; #get rid of leading and trailing whitespace
		s/(\s*)$//g;
		push @prow, $_;
	}
    #printf "## %.2f%% ## Line %d\n", ($i/$num_postcodes)*100, $i;
    $i++;
#    if ($prow[2] eq "ACT") { # if you only want one particular state (ie. down want to download all of NSW myschool data)
	 if ($prow[9] =~ "Delivery Area") { #assuming no schools only have a PO box, ie. no loction.
		my $s = "SELECT pcode FROM postcode WHERE pcode = ?;";
		my $sth = $dbh->prepare($s);
		$sth->execute($prow[0]);
		my $result = $sth->fetchrow_hashref();
        #don't change data if pcode is already in table. Also you will notice that there can be more that one locality for a post code. Here we just use the first one.
        
        if (!defined $result) {
			$s = "INSERT INTO postcode(pcode, state, category) VALUES (?,?,?);";
			$sth = $dbh->prepare($s);
			$sth->execute($prow[0], $prow[2], $prow[9]); #probably won't like it if these are blank, but they aren't in the file I used. Also I haven't worried about the other fields in the csv file, so they are not added to the database.
		}
		
		#check to see if exists.. some are listed more than once in the pc.csv file.
		$s = "SELECT pcode, suburb, state FROM suburb WHERE pcode = ? AND suburb = ? AND state = ?;";
		$sth = $dbh->prepare($s);
		$sth->execute($prow[0], $prow[1], $prow[2]);
		$result = $sth->fetchrow_hashref();
        
        if (!defined $result) {
			$s = "INSERT INTO suburb VALUES (?,?,?);";
			$sth = $dbh->prepare($s);
			$sth->execute($prow[0], $prow[1], $prow[2]);
		}
	}
#	}
}

