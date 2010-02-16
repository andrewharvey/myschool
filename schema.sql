
create domain PC as char(4) check (value ~ '[0-9]{4}');

-- only pcode, locality and state are important.
-- category could be usefull, no schools in a PO box!
-- schema based on the data at http://www1.auspost.com.au/download/pc-full.zip
CREATE TABLE postcode (
	pcode           PC PRIMARY KEY,
--	locality        text,
	state           text,
	comments        text,
	delivery_office text,
	presort_indicator integer,
	parcel_zone     text,
	bsp_number      integer,
	bsp_name        text,
	category        text
);

CREATE TABLE suburb (
	pcode PC REFERENCES postcode,
	suburb text,
	state text, --yes URIARRA,2611 spans NSW and ACT
	
	PRIMARY KEY (pcode, suburb, state)
);

-- Information about the school, that doesn't vary from year to year (generally)
CREATE TABLE school (
	postcode            PC REFERENCES postcode,
	name                text NOT NULL,
	sector              text NOT NULL,
	sector_sys_website  text,
	website             text,
	myschool_url        text PRIMARY KEY,
	type                text,
	year_range          text,
	location            text,
	geolocation         text --should be 'lat,long'
);

CREATE TABLE myschoolhtml (
	school  text REFERENCES school,
	html    text NOT NULL,
	scrape_year integer,
	
	PRIMARY KEY (school, scrape_year)
);

-- stats that change yearly
CREATE TABLE schoolstats (
    school              text REFERENCES school,
    year                integer,
    
    male                integer,
    female              integer,
    indigenous          integer,
    attendance          integer, -- percentage
    
    teaching_staff         integer,
    fte_teaching_staff     real,
    non_teaching_staff     integer,
    fte_non_teaching_staff real,
    
    -- YEAR 12 results
    sen_sec_cert_awarded integer,
    completed_sen_sec    integer,
    
    -- VET
    vet_qual_awarded    integer,
    sbat                integer,
    
    -- Post school destinations
    post_school_uni     integer, -- percenatge
    post_school_tafe    integer, -- percenatge
    post_school_employment integer, -- percenatge
    
    -- Index of Community Socio-Educational Advantage (ICSEA)
	icsea               integer,
	icsea_q1            integer, -- percentage
	icsea_q2            integer, -- percentage
	icsea_q3            integer, -- percentage
	icsea_q4            integer, -- percentage
	
	PRIMARY KEY (school, year)
);

CREATE TABLE nplan (
	school     text REFERENCES school,
	year       integer,
	grade      integer,
	area       text,
	score      integer,
	
	PRIMARY KEY (school, year, grade, area)
);
