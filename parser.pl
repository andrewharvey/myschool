#!/usr/bin/perl -w

# Info: The parser. See http://github.com/andrewharvey/myschool/
# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 07 Feb 2010 
#
# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

# Usage: ./parser.pl

use strict;
use HTML::TreeBuilder;
use DBI;
use URI::Escape;
use LWP::Simple;
sub parse_school_page($$$$$);

my $dbname = 'myschool';
my $dbhost = 'localhost';
my $dbuser = '';
my $dbpass = '';

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", "$dbuser", "$dbpass", {'RaiseError' => 1});


my $s = "SELECT h.html, h.school, h.scrape_year, s.name, s.postcode FROM myschoolhtml h, school s WHERE h.school = s.myschool_url;";
my $sth = $dbh->prepare($s);
$sth->execute();
while ( my @row = $sth->fetchrow_array() ){
	print $row[3]."\n";
	parse_school_page($row[0], $row[1], $row[2], $row[3], $row[4]);
}

sub parse_school_page($$$$$) {
	my ($html, $school_url, $scrape_year, $school_name, $pc) = @_;
	#$html = decode_utf8($html);
	my $element;
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($html); $tree->eof;
	$tree->elementify();

	#School facts
	my $sector = '';
	my $type = '';
	my $year_range = '';
	my $total_enrolments = '';
	my $female = '';
	my $male = '';
	my $fte_enrolments = '';
	my $indigenous_students = '';
	my $location = '';
	my $stu_attendance = '';
	my $teaching_staff = '';
	my $fte_teaching_staff = '';
	my $non_teaching_staff = '';
	my $fte_non_teaching_staff  = '';
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPSchoolSectorDescription">([^<]*)<\/span>/) {
		$sector = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPSchoolType">([^<]*)<\/span>/) {
		$type = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPYearRange">([^<]*)<\/span>/) {
		$year_range = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPTotalEnrolments">([\d\.]*)[^<]*<\/span>/) {
		$total_enrolments = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPFemale">([\d\.]*)[^<]*<\/span>/) {
		$female = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPMale">([\d\.]*)[^<]*<\/span>/) {
		$male = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPFTEEnrolments">([\d\.]*)[^<]*<\/span>/) {
		$fte_enrolments = $1; #fte = full time equiverlant
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPIndigenousStudents">([\d\.]*)[^<]*%[^<]*<\/span>/) {
		$indigenous_students = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPLocation">([^<]*)<\/span>/) {
		$location = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPStudentAttendanceRateAggregate">([\d\.]*)[^<]*%[^<]*<\/span>/) {
		$stu_attendance = $1;
	}

	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPTeachingStaffNumbers">([\d\.]*)[^<]*<\/span>/) {
		$teaching_staff = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPFTETeachingStaffNumbers">([\d\.]*)[^<]*<\/span>/) {
		$fte_teaching_staff = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPNonTeachingStaffNumbers">([\d\.]*)[^<]*<\/span>/) {
		$non_teaching_staff = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPFTENonTeachingStaffNumbers">([\d\.]*)[^<]*<\/span>/) {
		$fte_non_teaching_staff = $1;
	}
	
	#Student Background
	my $icsea = '';
	my $Q1 = ''; #bottom quarter
	my $Q2 = '';
	my $Q3 = '';
	my $Q4 = ''; #top quarter
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPLikeSchoolIndexICSEAScore">([\d\.]*)[^<]*<\/span>/) {
		$icsea = $1;
	}

	if ($html =~ /span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPRankingQuartile1">([\d\.]*)%<\/span>/) {
		$Q1 = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPRankingQuartile2">([\d\.]*)%<\/span>/) {
		$Q2 = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPRankingQuartile3">([\d\.]*)%<\/span>/) {
		$Q3 = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPRankingQuartile4">([\d\.]*)%<\/span>/) {
		$Q4 = $1;
	}

   #secondary schools only
   my $sen_sec_cert_awarded = '';
   my $completed_sen_secondary = '';
   my $vet_qual = '';
   my $sbat = '';
   
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPCertificateAwarded">([\d\.]*)[^<]*<\/span>/) {
		$sen_sec_cert_awarded = $1;
	}

	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPSeniorSecSchoolComplete">([\d\.]*)[^<]*<\/span>/) {
		$completed_sen_secondary = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPVETAttainment">([\d\.]*)[^<]*<\/span>/) {
		$vet_qual = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPUndertookSBAT">([\d\.]*)[^<]*<\/span>/) {
		$sbat = $1;
	}
	
	#VIC only
	my $uni = '';
   my $tafe = '';
   my $emp = '';
   
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPPctUniStudents">([\d\.]*)[^<]*<\/span>/) {
		$uni = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPPctTafeStudents">([\d\.]*)[^<]*<\/span>/) {
		$tafe = $1;
	}
	
	if ($html =~ /<span id="ctl00_ContentPlaceHolder1_SchoolProfileUserControl_SCPPctEmpStudents">([\d\.]*)[^<]*<\/span>/) {
		$emp = $1;
	}
	
	
	#Schools links
	my $school_website = '';
   my	$school_sector_website = '';
	my $school_sector = '';
	
	if ($html =~ /School website:<\/div>\s[^<]*\s<div class="ProfileValue">\s[^<]*\s<a href="([^"]*)" target="_blank">[^<]*<\/a>/) {
		$school_website = $1;
	}
	
	if ($html =~ /Sector or system website:<\/div>\s[^<]*\s<div class="ProfileValue">\s[^<]*\s<a href="([^"]*)" target="_blank">([^<]*)<\/a>/) {
		$school_sector_website = $1;
		$school_sector = $2;
	}

   #Use Google's Geoencoding services to get a lat and long...
GEOENC:
   my $sleep = 0;
   sleep $sleep;
   
   my $google_geoenc_url = "http://maps.google.com/maps/geo?q=".uri_escape($school_name).",+".sprintf('%04s',$pc).",AUSTRALIA&output=csv&sensor=true&key=your_api_key";
   
   my $geoenc_res = get($google_geoenc_url) or print STDERR "Failed to fetch geoencoding.\n";
   my ($geoenc_code, $geoenc_acc, $geoenc_lat, $geoenc_long) = split ',', $geoenc_res; #200,4,-33.8671390,151.2071140
   if ($geoenc_code eq "200") {
      #no problem
      #print "      Loc: $geoenc_lat, $geoenc_long\n";
   }elsif ($geoenc_code eq "620") {
      $sleep++;
      print STDERR "Google Geoencoding: 620 (querying too fast)... sleeping $sleep sec.\n";
      goto GEOENC;
   }else{
      print STDERR "Geoencode $geoenc_code response.\n";
      print STDERR "$google_geoenc_url\n";
   }
   
#commenting out may speed things up a little
#=comment
	#Print Results	
	print "      School Sector: $sector\n";
	print "      School Type: $type\n";
	print "      Year Range: $year_range\n";
	print "      Total Enrolments: $total_enrolments\n";
	print "      Female: $female\n";
	print "      Male: $male\n";
	print "      Full-time Equiverlant Enrolments: $fte_enrolments\n";
	print "      Indigenous Students: $indigenous_students\%\n";
	print "      Location: $location\n";
	print "      Student Attendance Rate: $stu_attendance\%\n";
	print "      Teaching Staff: $teaching_staff\n";
	print "      Full-time Equiverlant Teaching Staff: $fte_teaching_staff\n";
	print "      Non-teaching Staff: $non_teaching_staff\n";
	print "      Full-time Equiverlant Non-teaching Staff: $fte_non_teaching_staff\n";
	print "      \n";
	print "      School ICSEA: $icsea\n";
	print "      Q1: $Q1\n";
	print "      Q2: $Q2\n";
	print "      Q3: $Q3\n";
	print "      Q4: $Q4\n";
	print "      \n";
	print "      Senior secondary certificate awarded: $sen_sec_cert_awarded\n";
	print "      Completed senior secondary school: $completed_sen_secondary\n";
	print "      Awarded a VET qualification: $vet_qual\n";
	print "      Undertook SBAT: $sbat\n";
	print "      \n";
	print "      Students at university: $uni\n";
	print "      Students at TAFE/vocational study: $tafe\n";
	print "      Students in employment: $emp\n";
	print "      \n";
	print "      \n";
	print "      School Website: $school_website\n";
	print "      Sector or System Website: $school_sector_website\n";
	print "      School Sector or System: $school_sector\n";
	print "\n\n";
#=cut

    #hmm seems it doesn't like it when and integer type is given as ''.
    for ($year_range, $total_enrolments, $female, $male, $fte_enrolments, $indigenous_students, $location, $stu_attendance, $teaching_staff, $fte_teaching_staff, $non_teaching_staff, $fte_non_teaching_staff, $icsea, $Q1, $Q2, $Q3, $Q4, $sen_sec_cert_awarded, $completed_sen_secondary, $vet_qual, $sbat, $uni, $tafe, $emp, $school_website, $school_sector_website, $school_sector, $geoenc_lat, $geoenc_long, $school_url) {
       $_ = undef if ($_ eq '');
    }

	#update school table
    my $s = "UPDATE school SET sector_sys_website = ?, website = ?, year_range = ?, location = ?, geolocation = ? WHERE myschool_url = ?;";
    my $sth = $dbh->prepare($s);
    $sth->execute($school_sector_website, $school_website, $year_range, $location, "$geoenc_lat, $geoenc_long", $school_url);
    
    #insert into schoolstats table
    $s = "INSERT INTO schoolstats VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);";
    $sth = $dbh->prepare($s);
    $sth->execute($school_url, $scrape_year, $male, $female, $indigenous_students, $stu_attendance, $teaching_staff, $fte_teaching_staff, $non_teaching_staff, $fte_non_teaching_staff, $sen_sec_cert_awarded, $completed_sen_secondary, $vet_qual, $sbat, $uni, $tafe, $emp, $icsea, $Q1, $Q2, $Q3, $Q4);
    
    #insert into nplan table
    #TODO
    
    
#        for ($year_range, $total_enrolments, $female, $male, $fte_enrolments, $indigenous_students, $location, $stu_attendance, $teaching_staff, $fte_teaching_staff, $non_teaching_staff, $fte_non_teaching_staff, $icsea, $Q1, $Q2, $Q3, $Q4, $sen_sec_cert_awarded, $completed_sen_secondary, $vet_qual, $sbat, $uni, $tafe, $emp, $school_website, $school_sector_website, $school_sector, $geoenc_lat, $geoenc_long, $school_url) {
#       $_ = '' if (!defined $_);
#    }
	
#	use HTML::TableExtract;
#	my $te = HTML::TableExtract->new();
#	$te->parse($school_facts->as_HTML);
                         
#	foreach my $ts ($te->tables) {
#		print "Table (", join(',', $ts->coords), "):\n";
#		foreach my $row ($ts->rows) {
#			print join(',', @$row), "\n";
#		}
#	}

	$tree->delete;
}
