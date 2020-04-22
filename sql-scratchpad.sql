-- This is a file for all my common queries and commands.

-- delete existing COVID data
DROP TABLE counties CASCADE;
DROP TABLE states CASCADE;
DROP TABLE world CASCADE;

-- copy COVID data
\COPY counties FROM covid-19-data/us-counties.csv CSV HEADER;
\COPY states FROM covid-19-data/us-states.csv CSV HEADER;
\COPY world FROM covid-19/data/time-series-19-covid-combined.csv CSV HEADER;

-- get unemployment data: https://www.bls.gov/lau/
-- refresh employment data
DROP TABLE employment CASCADE;
\COPY employment FROM unemployment/unemployment.csv CSV HEADER;

-- get population data:
-- refresh population data
DROP TABLE population CASCADE;
\COPY population FROM county-population/populationdata.csv CSV HEADER;

-- View international trend in reverse chronoogical order
SELECT date, sum (cases) as total_cases, sum(recovered) as total_recovered, sum (deaths) as total_deaths
FROM world
GROUP BY date
ORDER BY date DESC;

-- View country by country trend in reverse chronological order
SELECT date, country, latitude, longitude, sum (cases) as total_cases, sum(recovered) as total_recovered, sum (deaths) as total_deaths
FROM world
GROUP BY date, country, latitude, longitude
ORDER BY date DESC, country ASC;

-- View US national trend in reverse chronological order
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM states
GROUP BY date
ORDER BY date DESC;

-- View percentage of cases from US
SELECT date, 100 * cases / (SELECT sum(cases) FROM world WHERE date = numerator_world.date) as percentage
FROM world numerator_world
WHERE country = 'US'
GROUP BY date, cases
ORDER BY date DESC;

-- View latest state data in reverse chronological order
SELECT date, state, cases, deaths
FROM states
GROUP BY date, state, cases, deaths
ORDER BY date DESC, state ASC;

-- View California data in reverse chronological order
SELECT date, county, cases, deaths
FROM counties
WHERE state = 'California'
GROUP BY date, county, cases, deaths
ORDER BY date DESC, county ASC;

-- View Northern vs. Southern California in reverse chronological order as date columns
-- first create Views
CREATE VIEW northern_california AS
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM counties
WHERE county IN ('San Francisco', 'Santa Clara', 'Alameda', 'Marin', 'San Mateo', 'Contra Costa') AND state = 'California'
GROUP BY date
ORDER BY date DESC;

CREATE VIEW southern_california AS
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM counties
WHERE county IN ('Los Angeles', 'Ventura', 'Orange', 'San Bernardino', 'Riverside') AND state = 'California'
GROUP BY date
ORDER BY date DESC;

-- now run the query

SELECT *, 'NorCal' AS region FROM northern_california
WHERE date >= current_date - interval '10' day
UNION ALL
SELECT *, 'SoCal' AS region FROM southern_california
WHERE date >= current_date - interval '10' day
GROUP BY date, region, total_cases, total_deaths
ORDER BY date DESC, region DESC \crosstabview region date total_cases;

-- How is New York doing?
-- Include all boroughs for completeness, but NYT isn't reporting them broken out yet
SELECT date, state, county, sum(cases) as total_cases, sum(deaths) as total_deaths
FROM counties
WHERE county IN ('New York City', 'Manhattan', 'Bronx', 'Brooklyn', 'Queens', 'Staten Island') AND state = 'New York'
GROUP BY date, state, county
ORDER BY date desc;

CREATE VIEW new_york_city AS
SELECT date, sum(cases) as total_cases, sum(deaths) as total_deaths
FROM counties
WHERE county IN ('New York City', 'Manhattan', 'Bronx', 'Brooklyn', 'Queens', 'Staten Island') AND state = 'New York'
GROUP BY date
ORDER BY date desc;

-- What about anticipated Election 2020 battleground counties?
CREATE VIEW battleground_counties AS
SELECT date, fips, state, county, sum(cases) as total_cases, sum(deaths) as total_deaths
FROM counties
WHERE 
    (county IN ('Erie') AND state = 'Pennsylvania') OR
    (county IN ('Saulk') AND state = 'Wisconsin') OR
    (county IN ('Muskegon') AND state = 'Michigan') OR
    (county in ('Maricopa') AND state = 'Arizona') OR
    (county IN ('Tarrant') AND state = 'Texas') OR
    (county IN ('New Hanover') AND state = 'North Carolina') OR
    (county IN ('Peach') AND state = 'Georgia') OR
    (county IN ('Washington') AND state = 'Minnesota') OR
    (county IN ('Hillsborough') AND state = 'New Hampshire') OR
    (county IN ('Lincoln') AND state = 'Maine')
GROUP BY date, fips, state, county
ORDER BY date desc;

-- View the daily rate of change in cases as reverse chronologial order as date columns
-- first let's view the raw change in cases
SELECT time_bucket('1 day', date) AS day,
       state,
       cases,
       lag(cases, 1) OVER (
           PARTITION BY state
           ORDER BY date
       ) previous_day,
       round (100 * (cases - lag(cases, 1) OVER (PARTITION BY state ORDER BY date)) / lag(cases, 1) OVER (PARTITION BY state ORDER BY date)) AS rate_of_change
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, cases
ORDER BY date DESC, rate_of_change DESC;

-- now let's arrange it by state using cross tabs
SELECT time_bucket('1 day', date) AS day,
       state,
       cases,
       lag(cases, 1) OVER (
           PARTITION BY state
           ORDER BY date
       ) previous_day,
       round (100 * (cases - lag(cases, 1) OVER (PARTITION BY state ORDER BY date)) / lag(cases, 1) OVER (PARTITION BY state ORDER BY date)) AS rate_of_change
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, cases
ORDER BY date DESC, rate_of_change ASC \crosstabview state day rate_of_change;

-- View state-by-state trend in deaths
SELECT time_bucket('1 day', date) AS day,
       state,
       deaths,
       lag(deaths, 1) OVER (
           PARTITION BY state
           ORDER BY date
       ) previous_day,
       round (100 * (deaths - lag(deaths, 1) OVER (PARTITION BY state ORDER BY date)) / (1 + lag(deaths, 1) OVER (PARTITION BY state ORDER BY date))) AS rate_of_change
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, deaths
ORDER BY date DESC, deaths DESC;

-- State-by-state trend in deaths as cross tab
SELECT time_bucket('1 day', date) AS day,
       state,
       deaths,
       lag(deaths, 1) OVER (
           PARTITION BY state
           ORDER BY date
       ) previous_day
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, deaths
ORDER BY date DESC, deaths DESC \crosstabview state day deaths;

-- View national trend in reverse chronological order with percent changed
-- TODO
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM states
GROUP BY date
ORDER BY date DESC;

-- View latest state case data in reverse chronological order as date columns
SELECT state, date, cases
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, cases
ORDER BY date DESC, state ASC \crosstabview state;

-- View latest state death data in reverse chronological order as date columns
SELECT state, date, deaths
FROM states
WHERE date >= current_date - interval '10' day
GROUP BY date, state, deaths
ORDER BY date DESC, state ASC \crosstabview state;

-- View state 3-day rate of change
SELECT state, time_bucket('3 days', date) as day, sum (cases) as cases, sum (deaths) as deaths
FROM states
GROUP BY state, day
ORDER BY day ASC;

-- View county 3-day rate of change
SELECT state, county, time_bucket('3 days', date) as day, sum (cases) as cases, sum (deaths) as deaths
FROM counties
GROUP BY state, county, day
ORDER BY day ASC;

-- View data from the latest hotspots

SELECT date as "time", state, deaths
FROM states
WHERE state IN ('Louisiana', 'Georgia', 'Michigan', 'Florida')
GROUP BY time, state, deaths
ORDER BY time DESC, state ASC;

SELECT date as "time", state, deaths
FROM states
WHERE state IN ('Louisiana', 'Georgia', 'Michigan', 'Florida') AND
      date >= current_date - interval '10' day
GROUP BY time, state, deaths
ORDER BY time DESC, state ASC \crosstabview state time deaths;

-- ELECTION DATA

-- normalize election data script
awk -F, '{if($5 == "NA") $5="0"; if($9 == "NA") $9="0"; if($10 == "NA") $10="0";}1' OFS=,  countypres_2000-2016.csv

-- find all results
SELECT state, county, votes, candidate
FROM elections
WHERE year = 2016
GROUP BY state, county, votes, candidate
ORDER BY state ASC, county ASC;

-- find all winners by county
SELECT year, state, county, fips, last(candidate, votes) as winner, max(votes) as winning_votes
FROM elections 
WHERE year = 2016
GROUP BY year, state, county, fips 
ORDER BY year, state, county;

-- find all Trump counties
CREATE VIEW trump_counties AS
SELECT * FROM (
    SELECT year, state, county, fips, last(candidate, votes) as winner, max(votes) as winning_votes
    FROM elections 
    WHERE year = 2016
    GROUP BY year, state, county, fips 
    ORDER BY year, state, county
) all_winners 
WHERE winner = 'Donald Trump';

-- find all Hillary Clinton counties
CREATE VIEW clinton_counties AS
SELECT * FROM (
    SELECT year, state, county, fips, last(candidate, votes) as winner, max(votes) as winning_votes
    FROM elections 
    WHERE year = 2016
    GROUP BY year, state, county, fips 
    ORDER BY year, state, county
) all_winners 
WHERE winner = 'Hillary Clinton';

-- find all cases and deaths in Trump counties
SELECT counties.date, sum (counties.cases) as total_cases, sum (counties.deaths) as total_deaths
FROM counties
WHERE counties.fips IN (SELECT fips FROM trump_counties) AND date >= current_date - interval '10' day
GROUP BY date
ORDER BY date DESC;

-- find all cases and deaths in Clinton counties
SELECT counties.date, sum (counties.cases) as total_cases, sum (counties.deaths) as total_deaths
FROM counties
WHERE counties.fips IN (SELECT fips FROM clinton_counties) AND date >= current_date - interval '10' day
GROUP BY date
ORDER BY date DESC;

-- how many voters in Trump counties
SELECT sum(total_votes) 
FROM (
    SELECT * FROM (
        SELECT year, total_votes, state, county, fips, last(candidate, votes) as winner, max(votes) as winning_votes
        FROM elections 
        WHERE year = 2016
        GROUP BY year, state, county, fips, total_votes 
        ORDER BY year, state, county
    ) all_winners 
    WHERE winner = 'Donald Trump'
) total;

-- how many voters in Clinton counties
SELECT sum(total_votes) 
FROM (
    SELECT * FROM (
        SELECT year, total_votes, state, county, fips, last(candidate, votes) as winner, max(votes) as winning_votes
        FROM elections 
        WHERE year = 2016
        GROUP BY year, state, county, fips, total_votes 
        ORDER BY year, state, county
    ) all_winners 
    WHERE winner = 'Hillary Clinton'
) total;

-- find all cases and deaths in Trump vs. Clinton counties side by side
SELECT * FROM
(
    SELECT counties.date, sum (counties.cases) as total_cases, sum (counties.deaths) as total_deaths, 'Trump Counties' as area
    FROM counties
    WHERE counties.fips IN (SELECT fips FROM trump_counties) AND date >= current_date - interval '10' day
    GROUP BY counties.date
    UNION ALL
    SELECT counties.date, sum (counties.cases) as total_cases, sum (counties.deaths) as total_deaths, 'Clinton Counties' as area
    FROM counties
    WHERE counties.fips IN (SELECT fips FROM clinton_counties) AND date >= current_date - interval '10' day
    GROUP BY counties.date
) merged
GROUP BY merged.date, merged.area, total_cases, total_deaths
ORDER BY merged.date DESC 
\crosstabview merged.area date total_deaths;

SELECT *, 'NorCal' AS region FROM northern_california
WHERE date >= current_date - interval '10' day
UNION ALL
SELECT *, 'SoCal' AS region FROM southern_california
WHERE date >= current_date - interval '10' day
GROUP BY date, region, total_cases, total_deaths
ORDER BY date DESC, region DESC \crosstabview region date total_cases;

-- GDP DATA

-- total GDP of Clinton counties
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM clinton_counties);

-- total GDP of Trump counties
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM trump_counties);

-- total GDP of counties with >100 cases
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM counties WHERE cases > 100 AND date = current_date - 1);

-- EMPLOYMENT DATA
SELECT time_bucket('30d', date) AS day,
       (100 * sum(unemployed) / sum (population)) AS unemployment_rate
FROM employment
WHERE employment.fips IN (SELECT fips FROM clinton_counties)
GROUP BY date;

SELECT time_bucket('30d', date) AS day,
       (100 * sum(unemployed) / sum (population)) AS unemployment_rate
FROM employment
WHERE employment.fips IN (SELECT fips FROM trump_counties)
GROUP BY date;

-- EMPLOYMENT RATE NOW
SELECT time_bucket('30d', date) AS time,
       (100 * sum(unemployed) / sum (population)) AS value
FROM employment
WHERE employment.fips IN (SELECT fips FROM battleground_counties)
GROUP BY date;