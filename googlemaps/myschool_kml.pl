#!/usr/bin/perl -w -T
#               ^ warnings and taint (a bit safer) mode

# Info: Produces a KML file from data in the myschool database 
#       (the database used in the other programs here,
#       see http://github.com/andrewharvey/myschool)
# Author: Andrew Harvey (http://andrewharvey4.wordpress.com/)
# Date: 15 Feb 2010 
#
# To the extent possible under law, the person who associated CC0
# with this work has waived all copyright and related or neighboring
# rights to this work.
# http://creativecommons.org/publicdomain/zero/1.0/

# Usage: as a cgi script

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use DBI;
use URI::Escape;
use XML::Writer;
use Data::Dumper;

warningsToBrowser(1); #perl warnings are sent to the browser in the HTML. (use 0 for production environment)

sub kml_placemark;

# Get CGI paramaters
my $cgi = new CGI;
my $bbox = $cgi->param('BBOX');
my $viewsize = $cgi->param('VIEWSIZE');
my $f = $cgi->param('f'); #feature

#parse CGI paramaters
my ($bbox_west, $bbox_south, $bbox_east, $bbox_north) = split /,/, $bbox;
my ($horiz_pixels, $vert_pixels) = split /x/, $viewsize;

#if ommited in query, we want to include all locations (that have a reasonable location set)
$bbox_west = 180 if (!defined $bbox_west);
$bbox_south = -90 if (!defined $bbox_south);
$bbox_east = -180 if (!defined $bbox_east);
$bbox_north = 90 if (!defined $bbox_north );

print $cgi->header(-type=>'application/vnd.google-earth.kml+xml');
#print $cgi->header(-type=>'text/plain');

#Database info
my $dbname = 'myschool';
my $dbhost = 'localhost';
my $dbuser = '';
my $dbpass = '';

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", "$dbuser", "$dbpass", {'RaiseError' => 1});

#Using XML::Writer to write the KML file
my $xmlwriter = new XML::Writer(); #NEWLINES => 1); #newlines are in weird places and look ugly...
$xmlwriter->startTag("kml", "xmlns" => "http://earth.google.com/kml/2.1");
$xmlwriter->startTag("Document");


#TODO use $f to only show certain schools. (eg. gov, non-gov, secondary, primary)

#the fields after geolocation are used for the description text.
my $s = "SELECT name, geolocation, website, sector, sector_sys_website, type, year_range FROM school;";
my $sth = $dbh->prepare($s);
$sth->execute();
while ( my @row = $sth->fetchrow_array() ){
	kml_placemark(@row);
}

sub kml_placemark {
    my @args = @_;
    my $school_name = $args[0];
    my $geoloc = $args[1];
    my ($lat, $long) = split /,\s*/, $geoloc;
    
    #check location is in the given bounding box
    if ( ($lat <= $bbox_north && $lat >= $bbox_south) && ($long <= $bbox_west && $long >= $bbox_east) ) {

        $xmlwriter->startTag("Placemark");
            $xmlwriter->dataElement("name", "$school_name");
            
            $xmlwriter->emptyTag("atom:link", "href" => "$args[2]");
            #HTML accepted for <description> tag
            $xmlwriter->cdataElement("description", "Sector: <a href=\"$args[4]\">$args[3]</a><br />Type: $args[5] ($args[6])<br />");
            $xmlwriter->dataElement("styleUrl", "#school");
            $xmlwriter->startTag("Style");
                $xmlwriter->startTag("IconStyle");
                    #dataElement("scale", "0.5");
                    $xmlwriter->startTag("Icon");
                        $xmlwriter->dataElement("href", "http://google-maps-icons.googlecode.com/files/school.png");
                    $xmlwriter->endTag("Icon");
                $xmlwriter->endTag("IconStyle");
            $xmlwriter->endTag("Style");
            
            $xmlwriter->startTag("Point");
                $xmlwriter->dataElement("coordinates", "$long,$lat");
            $xmlwriter->endTag("Point");
        $xmlwriter->endTag("Placemark");
        
    }
}

$xmlwriter->endTag("Document");
$xmlwriter->endTag("kml");
