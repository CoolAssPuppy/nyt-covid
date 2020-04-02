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

CREATE TABLE "gdp" (
    fips NUMERIC,
    county TEXT,
    dollars NUMERIC
);