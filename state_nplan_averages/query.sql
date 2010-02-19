SELECT state, avg(avgscore) FROM (
	SELECT s.name schoolname, s.myschool_url, sub.state state, avg(n.score) avgscore
	FROM nplan n, school s, (SELECT distinct pcode, state FROM suburb) sub
	WHERE n.school = s.myschool_url 
	  AND s.postcode = sub.pcode
	  AND n.year = 2008 --year
	  
	  --AND (n.grade BETWEEN 7 AND 12) --secondary
	  AND (n.grade BETWEEN 1 AND 6) --primary
	  
	  --leave both commented for ALL, or uncomment each one at a time for just that area
	  --AND n.area = 'numeracy' 
	  --AND (n.area = 'reading' OR n.area = 'writing' OR n.area = 'gramAndPunc' OR n.area = 'spelling' )
	  
	GROUP BY s.name, sub.state, s.myschool_url) o
GROUP BY state
ORDER BY avg desc;
