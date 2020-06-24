CREATE TABLE "states" (
    date DATE,
    state TEXT,
    fips NUMERIC,
    cases NUMERIC,
    deaths NUMERIC
);
SELECT create_hypertable('states', 'date', 'state', 2, create_default_indexes=>FALSE);
CREATE INDEX ON states (date ASC, state);

CREATE TABLE "counties" (
    date DATE,
    county TEXT,
    state TEXT,
    fips NUMERIC,
    cases NUMERIC,
    deaths NUMERIC
);
SELECT create_hypertable('counties', 'date', 'county', 2, create_default_indexes=>FALSE);
CREATE INDEX ON counties (date ASC, county);

CREATE VIEW northern_california AS
SELECT date, fips, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM counties
WHERE county IN ('San Francisco', 'Santa Clara', 'Alameda', 'Marin', 'San Mateo', 'Contra Costa') AND state = 'California'
GROUP BY date, fips
ORDER BY date DESC;

CREATE VIEW southern_california AS
SELECT date, fips, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM counties
WHERE county IN ('Los Angeles', 'Ventura', 'Orange', 'San Bernardino', 'Riverside') AND state = 'California'
GROUP BY date, fips
ORDER BY date DESC;

CREATE VIEW new_york_city AS
SELECT date, fips, sum(cases) as total_cases, sum(deaths) as total_deaths
FROM counties
WHERE county IN ('New York City', 'Manhattan', 'Bronx', 'Brooklyn', 'Queens', 'Staten Island') AND state = 'New York'
GROUP BY date, fips
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

CREATE TABLE "world" (
    date DATE,
    country TEXT,
    provincestate TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    cases NUMERIC,
    recovered NUMERIC,
    deaths NUMERIC
);
SELECT create_hypertable('world', 'date', 'country', 2, create_default_indexes=>FALSE);
CREATE INDEX ON world (date ASC, country);

CREATE TABLE "employment" (
    fips NUMERIC,
    date DATE,
    population NUMERIC,
    employed NUMERIC,
    unemployed NUMERIC,
    unemploymentrate NUMERIC
);

CREATE TABLE "elections" (
    year NUMERIC,
    state TEXT,
    state_abbreviation TEXT,
    county TEXT,
    fips NUMERIC,
    office TEXT,
    candidate TEXT,
    party TEXT,
    votes NUMERIC,
    total_votes NUMERIC,
    version TEXT    
);

CREATE TABLE "gdp" (
    fips NUMERIC,
    county TEXT,
    dollars NUMERIC
);

CREATE TABLE "population" (
    statecode NUMERIC,
    countycode NUMERIC,
    fips NUMERIC,
    state TEXT,
    county TEXT,
    population2010 NUMERIC,
    population2019 NUMERIC
);