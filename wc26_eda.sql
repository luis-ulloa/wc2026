--Confirm all tables are present
SELECT name FROM sqlite_schema
WHERE type='table' AND name NOT LIKE 'sqlite_%'
ORDER BY name;  --good, all 11 tables are present


--Check counts
SELECT COUNT(*) FROM all_players; --1248; not linked to overall schema, it's just to get the average team age
SELECT COUNT(*) FROM base_camps; --48
SELECT COUNT(*) FROM cards; --283 yellow and red cards issued ONLY to players. Technical staff not included
SELECT COUNT(*) FROM countries; --60; 48 participating nations plus referee teams
SELECT COUNT(*) FROM goals; --308
SELECT COUNT(*) FROM host_cities; --16
SELECT COUNT(*) FROM matches; --104
SELECT COUNT(*) FROM penalties; --62, these include penalties during match plus shootouts
SELECT COUNT(*) FROM players; --399; this one only counts players that either scored, got carded, or both
SELECT COUNT(*) FROM referees; --42; only the ones who got assigned as main referee for each match
SELECT COUNT(*) FROM stadiums; --16


--VIEW THAT SEGREGATES EACH TEAM INTO HOME AND AWAY FOR EACH MATCH---------
CREATE VIEW match_teams AS

SELECT
    match_id,
    home_country_code AS country_code,
    'Home' AS team_role
FROM matches

UNION ALL

SELECT
    match_id,
    away_country_code AS country_code,
    'Away' AS team_role
FROM matches
ORDER BY match_id;


--VIEW THAT SUMMARIZES KEY STATS AGGREGATED BY COUNTRY---------------------
CREATE	VIEW country_match_stats AS
SELECT
    country_code,
	CAST(COUNT(country_code) AS INTEGER)		AS played_matches,
	CAST(SUM(ot) AS INTEGER)					AS extra_time_matches,
    CAST(SUM(scored_goals) AS INTEGER)			AS total_goals,
	CAST(SUM(conceded_goals) AS INTEGER)		AS conceded_goals,
	CAST(ROUND(AVG(possession),2) AS NUMERIC)	AS avg_possession,
	CAST(SUM(shots) AS INTEGER)					AS total_shots,
	CAST(SUM(saves) AS INTEGER)					AS total_saves,
	CAST(SUM(fouls) AS INTEGER)					AS total_fouls,
	CAST(SUM(card_count) AS INTEGER)			AS total_cards,
	CAST(SUM(match_minutes) AS INTEGER)			AS total_minutes_played
	
	
	
FROM (
    SELECT
        home_country_code 	AS country_code,
        home_goals 			AS scored_goals,
		away_goals			AS conceded_goals,
		possession_home 	AS possession,
		home_shots_on_goal	AS shots,
		home_saves 			AS saves,
		home_fouls 			AS fouls,
		home_cards			AS card_count,
		minutes_played		AS match_minutes,
		CASE WHEN extra1_stoppage_mins IS NOT NULL THEN 1 ELSE 0 END AS ot
    FROM matches

    UNION ALL

    SELECT
        away_country_code 	AS country_code,
        away_goals 			AS scored_goals,
		home_goals			AS conceded_goals,
		possession_away 	AS possession,
		away_shots_on_goal	AS shots,
		away_saves 			AS saves,
		away_fouls 			AS fouls,
		away_cards			AS card_count,
		minutes_played		AS match_minutes,
		CASE WHEN extra1_stoppage_mins IS NOT NULL THEN 1 ELSE 0 END AS ot
    FROM matches
)
GROUP BY country_code
ORDER BY played_matches DESC;

--VIEW THAT SUMMARIZES SOME KEY GROUP STAGE PERFORMANCE STATS BY TEAM------
CREATE	VIEW group_stage_match_stats AS
SELECT
    country_code,
	CAST(COUNT(country_code) AS INTEGER)		AS played_matches,
    CAST(SUM(scored_goals) AS INTEGER)			AS total_goals,
	CAST(SUM(conceded_goals) AS INTEGER)		AS conceded_goals,
	CAST(ROUND(AVG(possession),2) AS NUMERIC)	AS avg_possession,
	CAST(SUM(shots) AS INTEGER)					AS total_shots,
	CAST(SUM(saves) AS INTEGER)					AS total_saves,
	CAST(SUM(fouls) AS INTEGER)					AS total_fouls,
	CAST(SUM(card_count) AS INTEGER)			AS total_cards,
	CAST(SUM(match_minutes) AS INTEGER)			AS total_minutes_played
		
FROM (
    SELECT
        home_country_code 	AS country_code,
        home_goals 			AS scored_goals,
		away_goals			AS conceded_goals,
		possession_home 	AS possession,
		home_shots_on_goal	AS shots,
		home_saves 			AS saves,
		home_fouls 			AS fouls,
		home_cards			AS card_count,
		minutes_played		AS match_minutes
	FROM matches
	WHERE stage = 'group'

    UNION ALL

    SELECT
        away_country_code 	AS country_code,
        away_goals 			AS scored_goals,
		home_goals			AS conceded_goals,
		possession_away 	AS possession,
		away_shots_on_goal	AS shots,
		away_saves 			AS saves,
		away_fouls 			AS fouls,
		away_cards			AS card_count,
		minutes_played		AS match_minutes
	FROM matches
	WHERE stage = 'group'
)
GROUP BY country_code;

--VIEW FOR EACH TEAM'S CHANGE IN POWER RANKINGS----------------------------
CREATE VIEW country_power_rankings AS
SELECT
	country_code,
	country,
	1000*(MAX(CAST(pre_tournament_soccer_ranking AS INTEGER)) OVER()
			- pre_tournament_soccer_ranking + 10) /
			(MAX(CAST(pre_tournament_soccer_ranking AS INTEGER)) OVER()
			- MIN(CAST(pre_tournament_soccer_ranking AS INTEGER)) OVER() + 10) AS starting_pwr_ranking,
	1000*(MAX(CAST(post_tournament_soccer_ranking AS INTEGER)) OVER()
			- post_tournament_soccer_ranking + 10) /
			(MAX(CAST(post_tournament_soccer_ranking AS INTEGER)) OVER()
			- MIN(CAST(post_tournament_soccer_ranking AS INTEGER)) OVER() + 10) AS ending_pwr_ranking
FROM countries
WHERE tournament_group <> 'referee team';
--NOTE TO SELF: update view to show team's stage progression
---------------------------------------------------------------------------




--EXPLORATORY DATA ANALYSIS------------------------------------------------

--TOTAL GOALS--------------------------------------------------------------
--There should be 308 per goals table
--However, for data consistency, check also from matches table
WITH all_goals AS (
	SELECT 
		SUM(home_goals) AS hgoals,
		SUM(away_goals) AS agoals
	FROM matches
	)
SELECT hgoals + agoals AS total_goals
FROM all_goals; -- numbers match


--GOALS PER MATCH
SELECT ROUND((SELECT COUNT(*) FROM goals) *1.0 / (SELECT COUNT(*) FROM matches),2) AS goals_per_match; --2.96 goals/match


--ATTENDANCE STATS
--1st: confirm that attendance at every match DOES NOT exceed venue capacity
SELECT
	m.match_id	AS 'matches to review'
FROM matches m
JOIN stadiums s
	ON m.host_city_id = s.host_city_id
WHERE m.attendance > s.stadium_capacity; --no matches returned, attendance data is correct


--Overall stadium capacity across all 16 venues
SELECT AVG(stadium_capacity) FROM stadiums; --64,614


--Split that stadium capacity average across the three host countries
--Canada only has two small stadiums with lower capacities
--Mexico has a behemoth (Estadio Azteca), then the other two have lower capacities
--The remaining 13 stadiums in the US vary a lot in capacity from 60Ks to 80Ks
SELECT 
	ROUND(AVG(stadium_capacity)) AS avg_capacity,
	CASE
		WHEN stadium_city IN ("Guadalajara", "Guadalupe", "Mexico City") THEN "MEX"
		WHEN stadium_city IN ("Vancouver", "Toronto") THEN "CAN"
		ELSE "USA"
	END AS country
FROM stadiums
GROUP BY country
ORDER BY avg_capacity DESC;
--USA: 69,142; MEX: 59,244; CAN: 47,767


--Average attendance per match
SELECT ROUND(AVG(attendance),0) FROM matches; --65,490 fans/match


--Average attendance per match in each host city
SELECT
	ROUND(AVG(m.attendance),0)	AS avg_attendance,
	hc.host_city_name 			AS host_city
FROM matches m
JOIN host_cities hc ON m.host_city_id = hc.host_city_id
GROUP BY hc.host_city_name
ORDER BY avg_attendance DESC;
--Top: Mexico City, then NYNJ, last two: Guadalajara and Toronto.
--Consistent with stadium capacities


--Average stadium utilization per match
WITH avg_attendance_by_city AS (
	SELECT
		AVG(m.attendance)	AS avg_attendance,
		s.stadium	 		AS venue,
		s.stadium_capacity	AS capacity,
		s.stadium_city		AS location
	FROM matches m
	JOIN stadiums s ON m.host_city_id = s.host_city_id
	GROUP BY venue, location
	)
SELECT 
	ROUND((aabc.avg_attendance / aabc.capacity)*100,2) AS avg_utilization_rate,
	aabc.venue	AS stadium,
	aabc.location AS city
FROM avg_attendance_by_city aabc
ORDER BY avg_utilization_rate DESC;
--Results show that throughout the tournament, fans filled the stadiums at 
--every match in every host city.  Vancouver and Mexico City were always sold-out
--the remaining stadiums were almost at full capacity with utilization rates exceeding 99%!


--Average match attendance per stage
--group stage vs. round of 32, vs round of 16, etc...
SELECT
	ROUND(AVG(attendance))	AS avg_attendance,
	stage
FROM matches
GROUP BY stage
ORDER BY avg_attendance DESC;
--not counting the final and the 3rd/4th place match, since they're just one game each
--the tournament stage with the highest average attendance was actually the round of 16
--which averaged 69,612 fans per match.  Lowest average attendance was the group stage at 64,508.


--Check final and 3rd/4th place match attendance vs. actual stadium capacity
SELECT
	m.stage,
	m.home_country_code || " vs. " || m.away_country_code AS teams,
	m.attendance,
	s.stadium_capacity
FROM matches m JOIN stadiums s
ON m.host_city_id = s.host_city_id
WHERE m.stage = "3rd & 4th place"
	OR m.stage = "final";
--So, the attendance number alone could be misleading
--In fact, it reinforces perceptions that the 3rd/4th place match
--is not interesting nor well attended.
--The two last matches were a full house

--Finally, what was total overall attendance across all 104 matches?
SELECT SUM(attendance) FROM matches; --6,810,966 fans!!!


--HOW HOT IT WAS?  SUMMER IN NORTH AMERICA IS HOT!!!------------------------
--Average temperature in celcius at the start of each match
SELECT ROUND(AVG(temperature),2) FROM matches; --not too bad: 25.88C


--How about at the host city level?
SELECT
	printf('%02d:%02d',
       CAST(AVG(m.mins_since_midnight) / 60 AS INTEGER),
       ROUND(AVG(m.mins_since_midnight) % 60)) AS avg_kickoff_time,
	ROUND(AVG(m.temperature),2) 	AS 'match start avg temp',
	hc.host_city_name,
	s.stadium,
	s.roof
FROM matches m 
	JOIN host_cities hc
		ON m.host_city_id = hc.host_city_id
	JOIN stadiums s 
		ON m.host_city_id = s.host_city_id
GROUP BY hc.host_city_name, s.stadium, s.roof
ORDER BY AVG(m.temperature) DESC;
--the three hottest cities have roofed stadiums, so that seems to have
--allowed for earlier local kickoff times.  Monterrey is the 4th hottest,
--but since their stadium has no roof, it looks like local kickoff times
--were deliberately shifted to the evening when the sun was no longer blazing
--Vancouver and Mexico City had the coolest temperatures at local kickoff_local
--matches in those two cities were always sold-out. Coincidence??


--As tournament progressed, it got inevitably hotter (start of summer in North America)
--What was the average temperature at local kickoff time?
SELECT
	stage,
	printf('%02d:%02d',
       CAST(AVG(mins_since_midnight) / 60 AS INTEGER),
       ROUND(AVG(mins_since_midnight) % 60)) AS avg_kickoff_time,
	ROUND(AVG(temperature),2) AS 'match start avg temp'
FROM matches
GROUP BY stage
ORDER BY CASE
			WHEN stage = 'group' THEN 1
			WHEN stage = 'round of 32' THEN 2
			WHEN stage = 'round of 16' THEN 3
			WHEN stage = 'quarter finals' THEN 4
			WHEN stage = 'semi finals' THEN 5
			WHEN stage = '3rd & 4th place' THEN 6
			ELSE 7
		 END
--Lowest avg kickock temperature is during group stage, it makes sense
--all cities are hosting, so the coolest cities are bringing the avg temp down
--last four matches: semis, 3rd/4th place and final were hosted in hotter cities


--Did day of the week impact average local kickoff times?
SELECT
	day,
	printf('%02d:%02d',
       CAST(AVG(mins_since_midnight) / 60 AS INTEGER),
       ROUND(AVG(mins_since_midnight) % 60)) AS avg_kickoff_time
FROM matches
GROUP BY day
ORDER BY avg_kickoff_time;
--Friday and Saturday games had the latest starts


--STOPPAGE STATS------------------------------------------------------------
--Overall, how many stoppage minutes were played across the entire tournament?
SELECT 
	SUM(
		COALESCE(half1_stoppage_mins,0)
		+ COALESCE(half2_stoppage_mins,0)
		+ COALESCE(extra1_stoppage_mins,0)
		+ COALESCE(extra2_stoppage_mins,0)
		) AS total_stoppage_minutes
FROM matches;
--1,477 stoptage minutes, that's 16.4 additional games!!


--On average, how many stoppage minutes were added per match?
SELECT 
	ROUND(AVG(
		COALESCE(half1_stoppage_mins,0)
		+ COALESCE(half2_stoppage_mins,0)
		+ COALESCE(extra1_stoppage_mins,0)
		+ COALESCE(extra2_stoppage_mins,0)
		),2) AS avg_stoppage_minutes
FROM matches;
--Overall, across all 104 matches, an average of 14.2 stoppage minutes were added in the aggregate


--Now, by stage, on average how many stoppage minutes were added to each match?
SELECT 
	ROUND(AVG(
		COALESCE(half1_stoppage_mins,0)
		+ COALESCE(half2_stoppage_mins,0)
		+ COALESCE(extra1_stoppage_mins,0)
		+ COALESCE(extra2_stoppage_mins,0)
		),2) AS avg_stoppage_minutes,
	stage
FROM matches
GROUP BY stage
ORDER BY 1 DESC;
--So, based on results, as the tournament advanced, and those knockout games became even more 
--intense, crucial and competitve, the referees added more stoppage time


--Average stoppage minutes by period: 1st Half vs 2nd Half vs Extra Time 1 vs Extra Time 2
SELECT
	ROUND(AVG(COALESCE(half1_stoppage_mins,0)),2)	AS h1_avg,
	ROUND(AVG(COALESCE(half2_stoppage_mins,0)),2)	AS h2_avg,
	ROUND(AVG(CASE
		WHEN stage NOT LIKE 'group' THEN extra1_stoppage_mins
	END),2) AS et1_avg,
	ROUND(AVG(CASE
		WHEN stage NOT LIKE 'group' THEN extra2_stoppage_mins
	END),2) AS et2_avg
FROM matches;
--1st half: 5.72, 2nd half: 7.89, 1st OT: 2.56, 2nd OT: 4.22


--Average stoppage minutes: Regular Time vs Extra Time
SELECT
	ROUND(AVG(COALESCE(half1_stoppage_mins + half2_stoppage_mins,0)),2)	AS regular_time,
	ROUND(AVG(CASE
		WHEN stage NOT LIKE 'group' THEN extra1_stoppage_mins + extra2_stoppage_mins
	END),2) AS extra_time
FROM matches;
--Regular Time: 13.62, Extra Time: 6.78


--Lastly, which three teams played the most minutes due to stoppages and extra times?
SELECT 
	country_code,
	total_minutes_played
FROM country_match_stats
ORDER BY 2 DESC
LIMIT 3;
--Argentina: 946 minutes, England: 871 minutes, Spain: 868 minutes



--BALL POSESSION STATS-------------------------------------------------------
--How often did the team with the highest possesion percent actually win the match?
WITH possession_results AS (
    SELECT
        CASE
            WHEN possession_home > possession_away AND home_goals > away_goals THEN 1
            WHEN possession_away > possession_home AND away_goals > home_goals THEN 1
            ELSE 0
        END AS higher_possession_won
    FROM matches
    WHERE possession_home <> possession_away
)
SELECT
    ROUND(100.0 * AVG(higher_possession_won), 2) AS pct_higher_possession_won
FROM possession_results;
--Team with the highest possession of the ball only won the match 57.69 percent of the time.


--Which team had the highest overall possession percent during the tournament?
SELECT 
	country_code,
	played_matches,
	avg_possession
FROM country_match_stats
WHERE avg_possession = (SELECT MAX(avg_possession) FROM country_match_stats);
--Germany and Turkey were the most dominant teams on the pitch, yet they didn't capitalize
--That's how fútbol is.  Turkey didn't even make it the knockout stage and Germany
--got knocked out in a penaly shootout in the round of 32.  Ball possession does not
--always translate to a win and/or success


--What was Spain overall ball possession percent across the tournament?
SELECT
	country_code,
	avg_possession
FROM country_match_stats
WHERE country_code = 'ESP'; -- 64%


--How did the first four places fared?
SELECT
	country_code AS team,
	avg_possession,
	CASE country_code
		WHEN 'ESP' THEN '1st Place'
		WHEN 'ARG' THEN '2nd Place'
		WHEN 'ENG' THEN '3rd Place'
		WHEN 'FRA' THEN '4th Place'
	END AS place
FROM country_match_stats
WHERE played_matches = 8
ORDER BY place;
--Spain's overall possession was impressive.  They dominated and ultimately won the championship.


--OVERALL COUNTRY MATCHES STATS----------------------------------------------
--Which team scored the most goals?
SELECT 
	country_code,
	total_goals
FROM country_match_stats
WHERE total_goals = (SELECT MAX(total_goals) FROM country_match_stats);
--Both France and England with 20 goals each


--Which country conceded the most goals?
SELECT 
	country_code,
	conceded_goals
FROM country_match_stats
WHERE conceded_goals = (SELECT MAX(conceded_goals) FROM country_match_stats);
--England, Tunisia and Iraq conceded the most goals.  However, Tunisia and Iraq never made
--it past the group stage.  So, they got bombarded with goals early on!!


--This brings up the following questions:
--1: Goal production per match, who was the most lethal?
--2: Goal concessions per match, who had the most porous defense?


--Question 1: Goals scored per match, top 3
SELECT
	country_code,
	ROUND(total_goals * 1.0 / played_matches, 2) AS goals_per_match
FROM country_match_stats
ORDER BY goals_per_match DESC
LIMIT 3;
--Netherlands: 2.75 goals/match; Germany: 2.75 goals/match; France: 2.5 goals/match


--What was the champion's goal production?
SELECT
	country_code,
	ROUND(total_goals * 1.0 / played_matches, 2) AS goals_per_match
FROM country_match_stats
WHERE country_code = 'ESP';
--Just 1.75 goals/match


--Question 2: Goals conceded per match, top 3 (as in the least goals conceded)
SELECT
	country_code,
	ROUND(conceded_goals * 1.0 / played_matches, 2) AS conceded_goals_per_match
FROM country_match_stats
ORDER BY conceded_goals_per_match ASC
LIMIT 3;
--And that might explain why Spain won it all!!  Their defense was brutal, just 0.13 goals conceded per match
--In fact, only Belgium scored against Spain, one goal.  Everybody else was scoreless against them.
--Recall too that Spain's average possession was 64%, so they dominated both aspects of the game.
--And although Portugal also had great defense, it was Spain who ultimately sent them home.
--Colombia also had great defense, but they allowed their match against Switzerland to go to penalties, which is a lottery
--at that point.  Had they advanced, perhaps they could have stopped Argentina???


--On the flip side, who conceded the most goals per match?
SELECT
	country_code,
	ROUND(conceded_goals * 1.0 / played_matches, 2) AS conceded_goals_per_match
FROM country_match_stats
ORDER BY conceded_goals_per_match DESC
LIMIT 3;
--We all know what happened to Tunisia, Iraq and Uzbekistan.


--Now, let's combine both sides of the goal equation: goal differential
--Which three countries had the worst differential?
SELECT
	country_code,
	total_goals - conceded_goals AS goal_differential
FROM country_match_stats
ORDER BY goal_differential ASC
LIMIT 3; 
--Iraq: -11, Tunisia: -10, Uzbekistan: -9


--Which three countries had the best differential
SELECT
	country_code,
	total_goals - conceded_goals AS goal_differential
FROM country_match_stats
ORDER BY goal_differential DESC
LIMIT 3; 
--Spain: 13, Argentina: 11, France: 10
--Again, Spain showing by the won the trophy.


--Let's explore goal production from a different angle
--Shot efficiency, basically how many shots were eventually converted into goals
--As well as how often did they shoot per match.  This helps normalize the comparison
--since not everyone played the same number of matches
SELECT
	country_code,
	total_goals,
	total_shots,
	ROUND(total_goals * 1.0 / total_shots,2) 	AS shot_efficiency,
	ROUND(total_shots * 1.0 / played_matches,2) AS shots_per_match
FROM country_match_stats
ORDER BY shot_efficiency DESC;
--Top 3: Austria: 75% & 2 shots/match, Japan: 62% & 3.25 shots/match, USA: 58% & 3.8 shots/match
--Spain is number 36 with 26% & 6.75 shots/match.  So, the "efficiency" alone is somewhat misleading
--Austria, Japan and the US each took less than 20 shots at goal, Austria only had 8!
--Spain, on the other hand took 54 shots.  They kept shooting, and shooting until the ball when in


--Most shots at goal vs. efficiency
SELECT 
	country_code,
	total_shots,
	ROUND(total_goals * 1.0 / total_shots,2) 	AS shot_efficiency,
	ROUND(total_shots * 1.0 / played_matches,2) AS shots_per_match
FROM country_match_stats
ORDER BY shots_per_match DESC;
--Top 3 by shots per match: France: 7.38, Germany: 7 and Spain: 6.75


--Same exercise, but now focused on defensive efficiency
--Esentially, how many times the opponents shot at each team's goal
--vs. how many goals were conceded and prevented (saves)
SELECT
	country_code,
	conceded_goals,
	conceded_goals + total_saves AS opponent_shots_on_target,
	ROUND((conceded_goals + total_saves)/ (played_matches * 1.0),2) AS opponent_shots_per_match,
	ROUND(total_saves * 1.0 / (conceded_goals + total_saves),2) AS defensive_efficiency
FROM country_match_stats
ORDER BY defensive_efficiency DESC;
--Spain showing once again that they were a defensive powerhouse.  Their opponents only managed
--11 shots against them and 91% of them were denied.


--DISCIPLINARY ASPECT: Top 3 teams with the most fouls and top 3 teams with the least fouls
--Compare against number of cards issued
SELECT
	country_code,
	total_fouls,
	total_cards
FROM country_match_stats
ORDER BY 2 DESC
LIMIT 3;
--Most fouls>> Argentina: 113 fouls & 15 cards, Spain: 101 fouls & 6 cards, Switzerland: 87 fouls & 8 cards
--Argentina and Spain show that to get to the final prize you must fight your way to it


--However, which countries actually collected highest number of cards?
SELECT
	country_code,
	total_fouls,
	total_cards
FROM country_match_stats
ORDER BY 3 DESC
LIMIT 3;
--Argentina: 15, Egypt: 12, Canada: 11


--Which teams had the cleanest games? How many cards did they get?
SELECT
	country_code,
	total_fouls,
	total_cards
FROM country_match_stats
ORDER BY 2 ASC
LIMIT 3;
--Least fouls>> South Korea: 25 fouls & 4 cards, Cape Verde: 27 fouls and 5 cards, Tunisia: 27 & 1 card


--But, which teams really got the least number of cards?
SELECT
	country_code,
	total_fouls,
	total_cards
FROM country_match_stats
ORDER BY 3 ASC
LIMIT 3;
--Tunisia: 1 card, Czechia: 1 card, Türkeye: 2 cards


--The results so far show that perhaps the number of cards is not highly correlated to the number of fouls
--Intuitively, one would think that the higher the number of fouls committed, the higher the likelihood
--of having a proportionally higher number cards.  Let's look into that by seeing what's the ratio of 
--fouls given to the number of cards issued
SELECT
	country_code,
	total_fouls,
	total_cards,
	ROUND(total_fouls * 1.0 / total_cards,2) AS fouls_to_cards_ratio
FROM country_match_stats
ORDER BY 4 DESC;
--Highest: Czechia: 37 fouls for every card given, but that's an outlier.  They only committed 37 fouls and 
--obviosly got just one card, so they're fouls where not of a flagrant nature.
--Lowest: Curacao: 4.57 fouls for every card given.  They actually committed less fouls than Czechia, but 
--were shown more cards, so perhaps their fouls were a bit flagrant.  The only way to confirm is to go back
--to the videos and verify.  The actual average for this specific metric is 10.01 fouls for every card given.


--However, what about the four teams that made it all the way to the end?  Since they have the longest
--run in the tournament, a comparison between them would merit some scrutinity.  Let's see...
SELECT
	country_code,
	total_fouls,
	total_cards,
	ROUND(total_fouls * 1.0 / total_cards,2) 	AS fouls_to_cards_ratio,
	ROUND(total_fouls * 1.0 / played_matches,2) AS fouls_per_match
FROM country_match_stats
WHERE country_code IN ('ESP','ARG','ENG','FRA')
ORDER BY 5 DESC;
--Out of the final four, Argentina committed the most fouls (113) at the rate of 14.13 fouls per match.
--Spain's foul count also exceeded 100, they fouled 12.63 times per match, but their ratio of fouls to cards given
--is more than double Argentina's.  In other words, either the refs were lenient with Spain, or their fouls
--were not considered very flagrant.


--Attacking Minutes
SELECT
	country_code,
	ROUND(avg_possession * total_minutes_played,1)					AS attacking_mins,
	ROUND((avg_possession * total_minutes_played)/total_shots,2)	AS mins_between_shots,
	ROUND((avg_possession * total_minutes_played)/total_goals,2) 	AS mins_between_goals
FROM country_match_stats
WHERE country_code IN ('ESP','ARG','ENG','FRA')
ORDER BY 4 ASC;
--This can be expanded to all 48 teams


--Group Stage Performance
SELECT
	c.tournament_group											AS grouping,
	c.country,
	cpr.starting_pwr_ranking,
	gs.total_goals,
	gs.total_goals - gs.conceded_goals 							AS goal_diff,
	ROUND(gs.total_goals * 1.0 / gs.played_matches,2) 			AS goals_per_match,
	gs.avg_possession,
	CAST(gs.avg_possession*gs.total_minutes_played AS INTEGER)	AS attacking_mins
FROM countries c
JOIN group_stage_match_stats gs
	ON c.country_code = gs.country_code
JOIN country_power_rankings cpr
	ON c.country_code = cpr.country_code
ORDER BY c.tournament_group ASC, goal_diff DESC;
--I'm not even sure what to make of this one...


--Overall tournament performance: Power ranking change from start to finish
SELECT
	c.country,
	
	ROUND(cms.total_goals * 1.0 / cms.played_matches,2)	AS goals_per_match,
	
	cms.avg_possession,
	cpr.starting_pwr_ranking							AS starting_power_rank,
	cpr.ending_pwr_ranking								AS ending_power_rank,
	cpr.ending_pwr_ranking - cpr.starting_pwr_ranking	AS power_rank_change,
	
	ROUND(((cpr.ending_pwr_ranking - cpr.starting_pwr_ranking) * 1.0
	/ cpr.starting_pwr_ranking)*100,1)					AS power_rank_improvement_pct,
	
	CAST(c.tournament_position AS INTEGER)				AS position
FROM countries c
JOIN country_match_stats cms
	ON c.country_code = cms.country_code
JOIN country_power_rankings cpr
	ON c.country_code = cpr.country_code
ORDER BY 8 ASC;
--Expand on this one: Power rank change tells a compelling story for some teams
--such as Norway.  I can see which teams overperformed/underperformed relative to 
--their power positions.  Add the group letter and the soccer federations to 
--analyze performance at those levels of granularity: Perhaps better to do in Tableau


--PLAYERS AND PLAYING POSTIONS
--Avg Team Age
SELECT
	team,
	ROUND(AVG(age),2) AS avg_age
FROM all_players
GROUP BY team
ORDER BY avg_age ASC;
--Spain at number 7 with 26.5, Argentina at number 40 with 28.81

	
--Avg Position Age within each Team
SELECT
	team,
	position,
	ROUND(AVG(age),2) AS avg_age
FROM all_players
GROUP BY team, position
ORDER BY team, avg_age ASC;
--Might be useful to compare different positions across squads
--The goal keepers tend to be the oldest cohort in most teams


--Overall avg age by position
SELECT
	position,
	ROUND(avg(age),2) AS avg_age
FROM all_players
GROUP BY position
ORDER BY avg_age ASC;
--Interesting finding: the forwards are the youngest.  Strikers need to be fast
--and speed is often associated with youth.
--then the midfielders, then the defenders and lastly the goal keepers
--longevity seems to be a hallmark within that cohort


SELECT
	team,
	position,
	short_name AS goal_keeper_name,
	age
FROM all_players
ORDER BY age DESC
LIMIT 10;
--The 10 oldest players range from 39 to 43
--and six of them are goal keepers.


--Out of curiosity: youngest and oldest players
SELECT
	team,
	full_name,
	MIN(age) AS age
FROM all_players

UNION ALL

SELECT
	team,
	full_name,
	MAX(age) AS age
FROM all_players;
--Gilberto Zambrano from Mexico (17), Craig Gordon from Scotland (43)


--Avg team heights
SELECT
	team,
	ROUND(AVG(height_cm/100.0),2) AS avg_height_meters
FROM all_players
GROUP BY team
ORDER BY avg_height_meters DESC;
--Range is only 9cm: From Saudi Arabia at 1.78 to Norway at 1.87; I'm looking at you Haaland!!


--Wondering which teams are on average shorter then I am?
SELECT
	team,
	ROUND(AVG(height_cm/100.0),2) AS avg_height_meters
FROM all_players
GROUP BY team
HAVING avg_height_meters < 1.83
ORDER BY avg_height_meters DESC;
--Wow, 23 teams in total!!  Even Spain has an average height shorter than me, but just by 1cm


--Who's the shortest, who's the tallest?
--My wild guess is that the tallest will turn out to be a goal keeper, let's see...
SELECT
	team,
	position,
	full_name,
	MIN(height_cm/100.0) AS height
FROM all_players

UNION ALL

SELECT
	team,
	position,
	full_name,
	MAX(height_cm/100.0) AS height
FROM all_players;
--Shortest player: César Velasco from Panama at 1.60m
--As suspected, the tallest is goal keeper Florian Wiegele from Austria at 2.05m


--Lastly, out of all 1,248 players, wondering how many are shorter than myself...
SELECT
	COUNT(*)
FROM all_players
WHERE height_cm/100.0 < 1.83;
--just 582 players. That, however, does not mean I can run faster, jump higher or play better!



--CARDS-----------------------------------------------------------------------
--Total cards and yellow/red breakdown
SELECT COUNT(*) FROM cards; --283 cards (issued to players, NOT technical staff)

SELECT
	color,
	COUNT(*)
FROM cards GROUP BY color;
--Just 15 red cards vs. 268 yellow cards


--Card distribution red/yellow against regular time / extra time / stoppage
SELECT
	color	AS card_color,
	SUM(CASE WHEN minute <= 90 AND stoppage IS NULL THEN 1 ELSE 0 END)		AS regular_time,
	SUM(CASE WHEN minute <= 90 AND stoppage IS NOT NULL THEN 1 ELSE 0  END)	AS stoppage_reg,
	SUM(CASE WHEN minute > 90 AND stoppage IS NULL THEN 1 ELSE 0  END)		AS extra_time,
	SUM(CASE WHEN minute > 90 AND stoppage IS NOT NULL THEN 1 ELSE 0  END)	AS stoppage_extra
FROM cards
GROUP BY color;
--			reg st  ot  st
--red		10	5	0	0
--yellow	209	46	13	0
--something to keep in mind for now...


--Card distribution by 15-min intervals
--1-15, 16-30, 31-45, 46-60, 61-75, 76-90, 91-105, 106-120, and the various stoppage periods
--Logic on this query is different to allow for better scaling, it's a bit more optimized
WITH cards_classification AS (
	SELECT
		color,
		CASE
			WHEN minute <= 15 THEN 'T1'
			WHEN minute > 15 AND minute <= 30 THEN 'T2'
			WHEN minute > 30 AND minute <= 45 AND stoppage IS NULL THEN 'T3'
			WHEN minute > 30 AND minute <= 45 AND stoppage IS NOT NULL THEN 'T4'
			WHEN minute > 45 AND minute <= 60 THEN 'T5'
			WHEN minute > 60 AND minute <= 75 THEN 'T6'
			WHEN minute > 75 AND minute <= 90 AND stoppage IS NULL THEN 'T7'
			WHEN minute > 75 AND minute <= 90 AND stoppage IS NOT NULL THEN 'T8'
			--I already know from previous query that no cards were issued 
			--during stoppage time in extra time periods, no need to check for those cases
			WHEN minute > 90 AND minute <= 105 THEN 'T9'
			WHEN minute > 105 AND minute <= 120 THEN 'T10'
		END AS time_interval
	FROM cards
)
SELECT
	cc.color,
	SUM(cc.time_interval = 'T1')	AS 'Minutes 1-15',
	SUM(cc.time_interval = 'T2')	AS 'Minutes 16-30',
	SUM(cc.time_interval = 'T3')	AS 'Minutes 31-45',
	SUM(cc.time_interval = 'T4')	AS '1st half stoppage',
	SUM(cc.time_interval = 'T5')	AS 'Minutes 46-60',
	SUM(cc.time_interval = 'T6')	AS 'Minutes 61-75',
	SUM(cc.time_interval = 'T7')	AS 'Minutes 76-90',
	SUM(cc.time_interval = 'T8')	AS '2nd half stoppage',
	SUM(cc.time_interval = 'T9')	AS 'Minutes 91-105',
	SUM(cc.time_interval = 'T10')	AS 'Minutes 106-120'
FROM cards_classification cc
GROUP BY cc.color
ORDER BY cc.color DESC;
--cards peak towards the end of the 1st half, then again in the last 30 minutes of the 2nd half
--and the last minutes of stoppage
--output
--yellow	23	24	45	6	34	41	42	40	5	8
--red		 1	 0	 1	1	 3	 3	 2	 4	0	0



--Which players are repeat offenders?
SELECT 
	p.name,
	p.team,
	COUNT(c.color) AS card_count
FROM cards c
JOIN players p
	ON c.player_id = p.id
GROUP BY p.name, p.team
HAVING card_count > 1
ORDER BY card_count DESC, p.team ASC;
--38 repeat offenders with Issa Diop from Morocco with 3 cards
--All remaining repeat offenders got two cards


--In which matches did Issa Diop got his three cards?
--His player ID is 163MAR
SELECT
	m.date,
	m.stage,
	c.color,
	c.minute,
	m.home_country_code || ' vs. ' || m.away_country_code AS 'match',
	h.host_city_name AS host_city,
	s.stadium AS venue,
	-------------------------------------------------------------------------------------------------------------------------------------
	CASE 
		WHEN m.away_goals > m.home_goals THEN 'WIN'
		WHEN m.away_goals = m.home_goals THEN (CASE WHEN m.away_shootout_penalties > m.home_shootout_penalties THEN 'WIN' ELSE 'LOSS' END)
		ELSE 'LOSS'
	END AS result -- <<< Case Statement logic based on fact that Morocco was the away team in all three matches
	---------------------Return to this and make it reusable via CTEs and/or nested case statements
	-------------------------------------------------------------------------------------------------------------------------------------
FROM cards c
JOIN matches m ON c.match_id = m.match_id
JOIN stadiums s ON m.host_city_id = s.host_city_id 
JOIN host_cities h ON m.host_city_id = h.host_city_id
WHERE c.player_id = '163MAR'
--Output
--6/19/2026	group			yellow	23	SCO vs. MAR	Boston		Gillette Stadium	WIN
--6/29/2026	round of 32		yellow	47	NLD vs. MAR	Monterrey	Estadio BBVA		WIN
--7/9/2026	quarter finals	yellow	63	FRA vs. MAR	Boston		Gillette Stadium	LOSS


--Which referees had the most "fun" handing out cards?
WITH ref_card_counts AS (
	SELECT 
		m.main_referee		AS id,
		r.short_name		AS name,
		COUNT(c.card_id)	AS card_count
	FROM matches m
	LEFT JOIN cards c ON m.match_id = c.match_id
	JOIN referees r ON m.main_referee = r.ref_id
	GROUP BY 1
),
ref_game_counts AS (
	SELECT 
		main_referee AS id, 
		COUNT(*) AS match_count
	FROM matches
	GROUP BY 1
)
SELECT 
	rcc.id,
	rcc.name,
	rcc.card_count,
	rgc.match_count,
	ROUND(rcc.card_count * 1.0 / rgc.match_count,2) AS cards_per_match
FROM ref_card_counts rcc
JOIN ref_game_counts rgc
	ON rcc.id = rgc.id
ORDER BY 3 DESC;
--Note to self: May want to turn this particular query into a VIEW, add fouls, penalties and stoppage time
--Output: By absolute count, Michael Oliver (R32) from England issued the most cards 
--at 17 over four officiated matches.  The most cards per match were six
--by Felix Zwayer (R17) from Germany. He only officiated two matches.  Need to 
--dig back into matches table to see which matches were those.


SELECT
	r.short_name AS name,
	m.date,
	m.stage,
	m.home_country_code || ' vs. ' || m.away_country_code AS game
FROM matches m
JOIN referees r ON m.main_referee = r.ref_id
WHERE m.main_referee = 'R17' OR m.main_referee = 'R32'
--Four group stage matches, one round of 16 and one quarter final


--BACK TO GOALS: ANALYSIS OF GOALS DISTRIBUTION BY DIFFERENT ATTRIBUTES-------------
--There were 308 goals (This count does not include penalty shootouts)
--But it does include conceded penalties during either regular time or extra time


--Goals distribution by situation
SELECT	
	situation,
	COUNT(goal_id) AS goal_count
FROM goals
GROUP BY 1 ORDER BY 2 DESC;
--Output: most goals during open play with 237, then off corner shots: 24; penalties with 16; own goals with 14
--off free kicks jusst 7 goals; set piece off a free kick: 6 and set piece, thrown it: 3 and one kickoff blunder with 1 goal
--Need to carve out time to review the situations again and make sure each one is accurate	


--Goals distribution by shot type
SELECT	
	shot_type,
	COUNT(goal_id) AS goal_count
FROM goals
GROUP BY 1 ORDER BY 2 DESC;
--Output: right foot: 164 goals, left foot: 89 goals, headers: 52 goals; off body: 3, which were actually own goals
--so, will need to add that detail


--Goals distribution by zone, where do they land on the net?
SELECT	
	goal_zone,
	COUNT(goal_id) AS goal_count
FROM goals
GROUP BY 1 ORDER BY 2 DESC;
--Output: low left: 90; low right: 83; low center: 48; high right: 41; high left: 28; high center: 18
--About 56% of the goals snuck in thru the low sides, it makes sense, it makes it more difficult
--for the goal keeper to reach them. And 72% entered thru low zones when low center is added.
--Only 87 goals (28%) were netted at a high level.  This would make for an interesting heat map.
--Both overall distribition and by team.  Perhaps even by player for those with about 4 or more goals?


--Goal distribution by distance
--First, determine MIN an MAX
SELECT 
	'Shortest Goal' 	AS label,
	MIN(distance_yds)	AS distance FROM goals
UNION ALL
SELECT 
	'Longest Goal' 		AS label,
	MAX(distance_yds) 	AS distance FROM goals
--Shortest: 1 yard; Longest: 35 yards


--Suggested buckets based on the range: 1-5, 6-10, 11-15, 16-20, 21-25, 26-30 and 31-35
WITH goal_distances AS (
	SELECT
		CASE
			WHEN distance_yds <= 5 THEN 'D1'
			WHEN distance_yds > 5 AND  distance_yds <= 10 THEN 'D2'
			WHEN distance_yds > 10 AND distance_yds <= 15 THEN 'D3'
			WHEN distance_yds > 15 AND distance_yds <= 20 THEN 'D4'
			WHEN distance_yds > 20 AND distance_yds <= 25 THEN 'D5'
			WHEN distance_yds > 25 AND distance_yds <= 30 THEN 'D6'
			ELSE 'D7'			
		END AS buckets
	FROM goals
)
SELECT
	SUM(gd.buckets = 'D1')	AS '1-5 yds',
	SUM(gd.buckets = 'D2')	AS '6-10 yds',
	SUM(gd.buckets = 'D3')	AS '11-15 yds',
	SUM(gd.buckets = 'D4')	AS '16-20 yds',
	SUM(gd.buckets = 'D5')	AS '21-25 yds',
	SUM(gd.buckets = 'D6')	AS '26-30 yds',
	SUM(gd.buckets = 'D7')	AS '31-35 yds'
FROM goal_distances gd;
--Output>> 1-5 yds: 38; 6-10 yds: 83; 11-15 yds: 74; 16-20 yds: 63; 21-25 yds: 21; 26-30 yds: 25; 31-35 yds: 4
--71% of the goals were scored from a distance of between 6 to 20 yards
--This can be further explored and broken down into different categories
--in Tableau and/or Power BI


--Who scored those four extra long goals?  And in which matches?
--Where did they land?  Definitely not headers from that distance.
SELECT
	m.date,
	m.home_country_code || ' .vs. ' || m.away_country_code AS matchup,
	m.stage,
	p.short_name AS name,
	g.team,
	g.minute,
	g.situation,
	g.shot_type,
	g.goal_zone,
	g.distance_yds
FROM goals g
JOIN matches m ON g.match_id = m.match_id
JOIN players p ON g.player_id = p.id
WHERE g.distance_yds > 30;
--Amazing, Cape Verde's first two world cup goals ever were long distance shots in the
--same match against Uruguay!


--Tally up all 308 goals by player
SELECT
	p.short_name AS name,
	g.team,
	p.position,
	COUNT(g.goal_id) AS goal_count
FROM goals g
JOIN players p ON g.player_id = p.id
GROUP BY p.short_name, p.position
ORDER BY goal_count DESC;
--Top 10 range: 4 to 10; Only one is a mid fielder, all remaining nine are forwards


--Goals distribution by player position
SELECT
	p.position,
	COUNT(g.goal_id) AS goal_count
FROM goals g
JOIN players p ON g.player_id = p.id
GROUP BY p.position
ORDER BY goal_count DESC;
--Output>> Forwards: 171 goals, mid fielders: 97, defenders: 37 and goal keepers: 3


--Confirm the 3 goals attributed to goal keepers are actually auto goals
SELECT
	m.date,
	m.home_country_code || ' vs. ' || m.away_country_code AS matchup,
	g.minute,
	p.short_name AS name,
	p.position,
	g.situation
FROM goals g
JOIN players p ON g.player_id = p.id
JOIN matches m ON g.match_id = m.match_id
WHERE p.position = 'GK'
--Output shows goal keepers.  Further verification confirmed
--they were accurately recorded as auto goals


--base_camps TABLE: more for plotting team movement in Tableau / Power BI
--penalties TABLE: similar analysis as goals; distribution by game_stage, result, shot_type, goal_zone, minute, etc.
