#!/usr/bin/perl -w

# Info: Gets the myschool.edu.au page for every school, and adds it to the database.
#       See http://github.com/andrewharvey/myschool/
# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 06 Feb 2010
#
# This should populate or update a database with a new list of schools, and the
# myschool.edu.au HTML page. Use parse.pl for parsing this HTML content.
#
# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

# Usage: ./get.pl

use strict;
use LWP::UserAgent;
use URI::Escape;
use HTML::TreeBuilder;
use HTTP::Cookies;
use Encode;
use DBI;

sub fetch_schools_in($$$);
sub parse_school_list($$);
sub get_school_details($);
sub recon();

my $dbname = 'myschool';
my $dbhost = 'localhost';
my $dbuser = '';
my $dbpass = '';

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", "$dbuser", "$dbpass", {'RaiseError' => 1});

my $DOMAIN = 'www.myschool.edu.au';

#set up the LWP useragent
my $ua = LWP::UserAgent->new;
$ua->agent("MySchool Scraper/0.1 ");
$ua->cookie_jar(HTTP::Cookies->new); #save cookies for duration of program

## Do some recon work...
my $viewstate;
my $eventvalidation;
recon();

sub recon() {
	#Their server requires clients to POST back two form values that we are given.
	#Ideally we would be smarter and act like a web browser, but this is faster to set up.
	#We use a recon request to get these form values.
	my $robots_req = HTTP::Request->new(GET => "http://$DOMAIN/robots.txt");
	my $robots_res = $ua->request($robots_req);
	if ($robots_res->is_success) {
		#my $robots_txt = $robots_res->content;
		print "robots.txt present\n";
		exit 1; #currently no file, so no need to parse it atm.
	} #else don't worry about it
	my $recon_req = HTTP::Request->new(GET => "http://$DOMAIN/SchoolSearch.aspx");
	$recon_req->accept_decodable; #'Accept-Encoding' => $can_accept
	my $recon_res = $ua->request($recon_req);

	if ($recon_res->is_success) {
		my @html_lines = split /\n/, $recon_res->decoded_content;
		my @viewstate_lines = grep(/__VIEWSTATE/, @html_lines);
		$viewstate = $viewstate_lines[0]; #the value for __VIEWSTATE
		$viewstate =~ s/.*value=\"?//;
		$viewstate =~ s/\".*//;

		my @eventvalidation_lines = grep(/__EVENTVALIDATION/, @html_lines);
		$eventvalidation = $eventvalidation_lines[0]; #the value for __EVENTVALIDATION
		$eventvalidation =~ s/.*value=\"?//;
		$eventvalidation =~ s/\".*//;
	}else {
	  print "Recon failed: ".$recon_res->status_line."\n";
	  sleep 4; #wait some time
	  sub recon(); #try again
	}
}

#in hind sight I should really have used 
#POST /AutoComplete.asmx/GetSuburbNames HTTP/1.1
#{"prefixText":"2000","count":1000}
#and parse that result. That would be more reliable than using my other data source.
my $s = "SELECT pcode, suburb, state FROM suburb;";
my $sth = $dbh->prepare($s);
$sth->execute();
while (my @res = $sth->fetchrow_array()) {
	print "Postcode: $res[0] ($res[1] $res[2])...\n";
    fetch_schools_in("$res[1],$res[2],$res[0]", 0, $res[0]);
}

exit;


sub fetch_schools_in($$$) {
	my ($locality, $count, $pc) = @_;

	#Send a request to the server, hopefully this will return a list of schools in the area.
	my $req = HTTP::Request->new(POST => "http://$DOMAIN/SchoolSearch.aspx");
    $req->accept_decodable;
	$req->content_type('application/x-www-form-urlencoded');
	my %post_content = ('__EVENTARGUMENT' => '',
					 '__EVENTTARGET' => '',
					 '__EVENTVALIDATION' => uri_escape("$eventvalidation"),
					 '__VIEWSTATE' => uri_escape("$viewstate"),
					 'ctl00%24ContentPlaceHolder1%24GovernmentCheckBox' => 'on',
					 'ctl00%24ContentPlaceHolder1%24NonGovernmentCheckBox' => 'on',
					 'ctl00%24ContentPlaceHolder1%24SchoolKeyValue' => '',
					 'ctl00%24ContentPlaceHolder1%24SchoolNameTextBox' => '',
					 'ctl00%24ContentPlaceHolder1%24ScriptManager1' => 'ctl00%24ContentPlaceHolder1%24UpdatePanel1%7Cctl00%24ContentPlaceHolder1%24SearchImageButton',
					 'ctl00%24ContentPlaceHolder1%24SearchImageButton.x' => '191',
					 'ctl00%24ContentPlaceHolder1%24SearchImageButton.y' => '22',
					 'ctl00%24ContentPlaceHolder1%24SuburbTownTextBox' => uri_escape("$locality"),
					 'hiddenInputToUpdateATBuffer_CommonToolkitScripts' => 1 );

	my $post_content_string = '';
	foreach my $key (keys %post_content) {
		$post_content_string .= "$key=".$post_content{$key}."&";
	}
	chop $post_content_string;

	$req->content("$post_content_string");

	# Pass request to the user agent and get a response back
	my $res = $ua->request($req);

	# Check the outcome of the response
	if ($res->is_success) {
		print "   Got list of schools in locality ($locality).\n";
		parse_school_list($res->decoded_content, $pc);
	}else {
		print "   Getting list of schools for '$locality' failed: ".$res->status_line."\n"."   POST content was: $post_content_string\n";
		if ($count > 2) {
		    print "Retrying too many times failed.\n";
		    sleep 10; #or die, if you want.
		}
		print "   Retrying recon...\n";
		recon();
		fetch_schools_in($locality, $count++, $pc);
	}
}

#argument is the HTML response which should contain a list of schools in a given locality.
sub parse_school_list($$) {
	my ($html, $pc) = @_;
	#$html = decode_utf8($html);
	my $element;
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($html); $tree->eof;
	$tree->elementify();

	#find the table that lists all the schools in the given area.
	my @schools_table = $tree->look_down('_tag', 'table',
	    'id', 'ctl00_ContentPlaceHolder1_SchoolResultsGridView');
	#my $first = $schools_table[0]->as_HTML();
	my @school_list = $schools_table[0]->look_down('_tag', 'tr',
	    'class', qr/(GridViewRowStyle)|GridViewAlternatingRowStyle/);
	foreach my $school (@school_list) {
		if (!defined $school) {
			print "   No schools in locality.\n";
		}else{
			#print Dumper($school->as_HTML());
			my ($school_url_html, $school_type, $school_sector) = $school->look_down('_tag', 'td');
			my $school_url = $school_url_html->look_down('_tag', 'a')->attr('href');
			$school_url =~ s/&CalendarYear=\d*//; #remove the year attribute

			print "   School: ".$school_url_html->as_text()."\n";
			print "   School Type: ".$school_type->as_text()."\n";
			print "   School Sector: ".$school_sector->as_text()."\n";
			print "   URL: $school_url\n";

		    my $s = "SELECT myschool_url FROM school WHERE myschool_url = ?;";
            my $sth = $dbh->prepare($s);
            $sth->execute($school_url);
            my $result = $sth->fetchrow_hashref();

            if (!defined $result) {
    	        $s = "INSERT INTO school (postcode, name, type, sector, myschool_url) VALUES (?, ?, ?, ?, ?);";
                $sth = $dbh->prepare($s);
                $sth->execute($pc, $school_url_html->as_text(), $school_type->as_text(), $school_sector->as_text(), $school_url);
            }
			get_school_details($school_url);
		}
		print "\n";
	}
	$tree->delete;
}

#ie get the page which contains all the stats for the given school
sub get_school_details($) {
	my ($school_url) = @_;
	foreach my $year (2008..2009) {
		my $school_url_y = $school_url.'&CalendarYear='.$year;
		
		#This should get the HTML page of the school details.
		my $req = HTTP::Request->new(GET => "http://${DOMAIN}/${school_url_y}");
		$req->accept_decodable;
		my $res = $ua->request($req);

		# Check the outcome of the response
		if ($res->is_success) {
			print "   ::::Got page with school details ($year).\n";
		    my $s = "INSERT INTO myschoolhtml (school, html, scrape_year) VALUES (?, ?, ?);";
		    my $sth = $dbh->prepare($s);
		    $sth->execute($school_url, $res->decoded_content(charset => 'none'), $year);
		}else {
			print "   ::::GET of page failed.\n";
		}
	}
}
