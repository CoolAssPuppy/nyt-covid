Earlier today, I saw an article about how the current US Presidential Administration [plans to distribute COVID-19 tests][test-distribution]. According to the article, the Administration is debating sending tests to rural areas with relatively few cases instead of urban hotspots where the COVID-19 infection is growing at a geometric rate. [Most public health experts agree][more-testing] that widespread testing will help restart the economy, the dominant driver of which resides in America's urban centers. On the surface, this decision appears to be political in nature.

So, I set out to demonstrate, through data, what those political calculations could be. What if we could look at COVID-19 data alongside political affiliation of a region and economic impact of those same regions? We would be able to determine the consequences of planned actions and encourage our decision-makers to act accordingly. 

Fortunately, this data exists and in public form. Bringing this information together can help public officials prioritize scarce resources to optimize for better health outcomes and stave off a greater economic calamity.

To complete this analysis, I needed to combine three public datasets:

- The [New York Times COVID-19 public dataset][covid-data]
- The [MIT Election Data Science Lab county-by-county election data][election-data]
- The [US Commerce Department county-by-county GDP data][gdp-data]

**Important to note: I am not an epidemiologist or expert in any way, shape, or form. The public data is available for all of us to use, and this is a tutorial that helps us use that public data to understand the world around us.** I'll also add that there's no shame in wanting to steep yourself in data about this crisis, nor is there any shame in walling yourself off from the data. We all cope with anxiety and stress in different ways, and at this moment in our history, taking the time to appreciate our differences will go a long way.

# Top-line insight
Through this analysis, I was able to conclude several things:

- Northern California is seeing a lower rate of confirmed cases and deaths than Southern California (my hypothesis, which is not substantiated by the data in this post, is that our weekend weather here in Northern California has been consistently terrible, making it easier to comply with social distancing orders)
- At the current growth rate of COVID-19, the counties that voted for President Donald Trump are approximately 5-7 days behind the counties that voted for Secretary Hillary Rodham Clinton in the rate of reported infections and deaths 
- Counties that voted for President Trump account for 1/3 of total Gross Domestic Product (GDP), while counties that voted for Secretary Clinton accounted for 2/3 of total GDP
- Electing to deploy resources to counties that voted for President Trump *at the expense of* counties that voted for Secretary Clinton will deepen the economic catastrophe of the entire nation
- According to the Brookings Institution, [31 million fewer people][population-article] live in counties that voted for President Trump than in counties that voted for Secretary Clinton

This is no time to play politics, yet we run the risk of political considerations guiding decision-making. Deploying resources to rural areas at the expense of urban areas may be a wise political calculation, but it runs the significant risk of deepening the nationwide health and economic crisis caused by COVID-19.

What follows are step-by-step instructions on how to obtain the data and come to your own conclusions.

# Obtaining our datasets

As mentioned, we will be using three different datasets. Two of these are on GitHub, while the other we can obtain freely via a US Government website.

First, let's clone the two GitHub repositories we will need:

```bash
git clone https://github.com/nytimes/covid-19-data.git
git clone https://github.com/MEDSL/county-returns.git
```

And for the GDP data:
1. Click on "Interactive Data" and select "GDP by County and Metropolitan Area".
2. In the resulting screen, click on "GROSS DOMESTIC PRODUCT (GDP) BY COUNTY AND METROPOLITAN AREA".
3. Click on "Gross Domestic Product (GDP) summary (CAGDP1)".
4. You want "County" data, for "All counties in the US", and for our purposes we just need "Real GDP".
5. For the purposes of this tutorial, you only need "2018" data.
6. Select "Download" and choose "Excel". We will need to do some finagling in Microsoft Excel to clean up this dataset.

I wrote a blog post on [cleaning up public data][cleanup-data-post] that I recommend reading. In this case, you will need to delete the rows at the top and bottom of your spreadsheet, turn the FIPS and GDP columns into numbers, and search and replace the handful of instances of "(NA)" with zeroes. Save your file as a CSV.

If you'd prefer not to download and manipulate the dataset yourself, you can get the CSV files from [my GitHub repo][my-github].

# Setting up your database and ingesting data

We will need to: setup our database, create our tables, and ingest our data.

## Set up the database
For this tutorial, I'm using [TimescaleDB][timescale-info], an open-source time-series database (and also my employer). The easiest way to use TimescaleDB is by [signing up for Timescale Cloud][timescale-cloud]. You get $300 in free credits, which is more than enough to complete this tutorial. This [installation guide][timescale-install] will get you up and running with TimescaleDB.

Be sure to also [install psql][install-psql] and test that you can connect to your database, per the TimescaleDB installation instructions.

Before proceeding, create your database, which we will call `nyt_covid`, and add the TimescaleDB extension:

```sql
CREATE DATABASE nyt_covid;
\c nyt_covid
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
```

## Create tables
We will create the following tables:

- `counties`
- `states`
- `elections`
- `gdp`

This script will create the tables with the proper schema, and create the appropriate hypertables and views on the data (which we will use later during our analysis):

```sql
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
```

Once completed, you can run the `\d` command in `psql` and you should get a result like this:

```sql
                List of relations
 Schema |        Name         | Type  |   Owner   
--------+---------------------+-------+-----------
 public | clinton_counties    | view  | tsdbadmin
 public | counties            | table | tsdbadmin
 public | elections           | table | tsdbadmin
 public | gdp                 | table | tsdbadmin
 public | northern_california | view  | tsdbadmin
 public | southern_california | view  | tsdbadmin
 public | states              | table | tsdbadmin
 public | trump_counties      | view  | tsdbadmin
(8 rows)
```

## Ingest the data
Now, let's ingest our data. We have three datasets, across four files:

- `us-counties.csv`: county-by-county COVID-19 data from the New York Times
- `us-states.csv`: state-by-state COVID-19 data from the New York Times
- `countypres_2000-2016.csv`: county-by-county election results from MIT
- `county-gdp.csv`: the file you saved via Excel containing county-by-county GDP data from the US Department of Commerce

The New York Times COVID-19 data is ready to go as-is, so we don't need to clean up that file. And you've already cleaned up the GDP data using Excel.

The election data requires a little bit of clean-up to replace instances of "NA" with zeroes. The following `awk` script will perform this substitution for us:

```bash
awk -F, '{if($5 == "NA") $5="0"; if($9 == "NA") $9="0"; if($10 == "NA") $10="0";}1' OFS=,  countypres_2000-2016.csv > countyresults.csv
```

Finally, let's use `psql` to load our data so we can get to the analysis:

```sql
\COPY counties FROM us-counties.csv CSV HEADER;
\COPY states FROM us-states.csv CSV HEADER;
\COPY elections FROM countyresults.csv CSV HEADER;
\COPY gdp FROM county-gdp.csv CSV HEADER;
```

You can test your ingestion with a simple SQL query, like this one:

```sql
SELECT * 
FROM counties 
ORDER BY date desc 
LIMIT 25;
```

And you should get a result like this:

```sql
    date    |     county      |     state      | fips  | cases | deaths 
------------+-----------------+----------------+-------+-------+--------
 2020-04-01 | Yuma            | Arizona        |  4027 |    12 |      0
 2020-04-01 | Yuma            | Colorado       |  8125 |     2 |      0
 2020-04-01 | Yolo            | California     |  6113 |    28 |      1
 2020-04-01 | Yellow Medicine | Minnesota      | 27173 |     1 |      0
 2020-04-01 | Yazoo           | Mississippi    | 28163 |     9 |      0
 2020-04-01 | Yankton         | South Dakota   | 46135 |     8 |      0
 2020-04-01 | Yadkin          | North Carolina | 37197 |     3 |      0
 2020-04-01 | Wyoming         | New York       | 36121 |    10 |      1
 2020-04-01 | Wyandot         | Ohio           | 39175 |     2 |      0
 2020-04-01 | Wright          | Iowa           | 19197 |     1 |      0
 2020-04-01 | Wright          | Minnesota      | 27171 |     6 |      0
 2020-04-01 | Wright          | Missouri       | 29229 |     4 |      0
 2020-04-01 | Woodson         | Kansas         | 20207 |     3 |      0
 2020-04-01 | Woodruff        | Arkansas       |  5147 |     1 |      0
 2020-04-01 | Woodbury        | Iowa           | 19193 |     4 |      0
 2020-04-01 | Wood            | Ohio           | 39173 |    15 |      0
 2020-04-01 | Wood            | Texas          | 48499 |     1 |      0
 2020-04-01 | Wood            | West Virginia  | 54107 |     2 |      0
 2020-04-01 | Wood            | Wisconsin      | 55141 |     2 |      0
 2020-04-01 | Winona          | Minnesota      | 27169 |    10 |      0
 2020-04-01 | Winneshiek      | Iowa           | 19191 |     3 |      0
 2020-04-01 | Winchester city | Virginia       | 51840 |     5 |      0
 2020-04-01 | Wilson          | North Carolina | 37195 |    15 |      0
 2020-04-01 | Wilson          | Tennessee      | 47189 |    45 |      0
 2020-04-01 | Wilson          | Texas          | 48493 |     5 |      0
(25 rows)
```

# Analysis

Let's use this data to answer a few questions.

## What is the national trend in reverse chronological order?
Our SQL query would look like this:

```sql
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM states
GROUP BY date
ORDER BY date DESC;
```

And the result would look like this (clipped for space):

```sql
    date    | total_cases | total_deaths 
------------+-------------+--------------
 2020-04-01 |      214461 |         4841
 2020-03-31 |      187834 |         3910
 2020-03-30 |      163796 |         3073
 2020-03-29 |      142161 |         2486
 2020-03-28 |      123628 |         2134
 2020-03-27 |      102648 |         1649
 2020-03-26 |       85533 |         1275
 2020-03-25 |       68515 |          990
 2020-03-24 |       53938 |          731
```

## What is the state-by-state trend in reverse chronological order?
Now we will need to adjust our SQL query to `GROUP BY` the `state`, and we will order the results in reverse chronological and alphabetical order also:

```sql
SELECT date, state, cases, deaths
FROM states
GROUP BY date, state, cases, deaths
ORDER BY date DESC, state ASC;
```

And the result should look like this (clipped for space):

```sql
    date    |          state           | cases | deaths 
------------+--------------------------+-------+--------
 2020-04-01 | Alabama                  |  1106 |     28
 2020-04-01 | Alaska                   |   143 |      2
 2020-04-01 | Arizona                  |  1413 |     29
 2020-04-01 | Arkansas                 |   624 |     10
 2020-04-01 | California               |  9816 |    212
 2020-04-01 | Colorado                 |  3346 |     80
```

## How is each part of California (or my state) doing?
In this case, we will adjust our query to search by county. This should give us a (rough) geographic approximation of where COVID-19 is spreading in each state we are interested in. So, we will search the `counties` table and we want to filter using the SQL `WHERE` clause, providing the name of the state we're interested in:

```sql
SELECT date, county, cases, deaths
FROM counties
WHERE state = 'California'
GROUP BY date, county, cases, deaths
ORDER BY date DESC, county ASC;
```

The result should look like this (clipped for space):

```sql
    date    |     county      | cases | deaths 
------------+-----------------+-------+--------
 2020-04-01 | Alameda         |   380 |      8
 2020-04-01 | Alpine          |     1 |      0
 2020-04-01 | Amador          |     3 |      1
 2020-04-01 | Butte           |     8 |      0
 2020-04-01 | Calaveras       |     3 |      0
 2020-04-01 | Colusa          |     1 |      0
 2020-04-01 | Contra Costa    |   250 |      3
```

## What about Northern California vs. Southern California?
Earlier we created two views, `northern_california` and `southern_california`. To recap, here's the `CREATE VIEW` statement for Northern California from our script. It queries all counties in Northern California. In this case, we have to structure the `WHERE` clause so that it searches for specific counties *in a specified state*. You'd be surprised how many duplicate county names there are across the United States:

```sql
CREATE VIEW northern_california AS
SELECT date, sum (cases) as total_cases, sum (deaths) as total_deaths
FROM counties
WHERE county IN ('San Francisco', 'Santa Clara', 'Alameda', 'Marin', 'San Mateo', 'Contra Costa') AND state = 'California'
GROUP BY date
ORDER BY date DESC;
```

What we'd like to do is see the date-over-date comparison between these two regions. We *could* run two queries, like these:

```sql
SELECT * FROM northern_california;
SELECT * FROM southern_california;
```

But it would assist our analysis to see them alongside one another. For this, we will use the `UNION ALL` function in SQL to merge the two queries, and the `crosstabview` function in PostgreSQL (which TimescaleDB is based on) to arrange the results side-by-side:

```sql
SELECT *, 'NorCal' AS region FROM northern_california
WHERE date >= current_date - interval '10' day
UNION ALL
SELECT *, 'SoCal' AS region FROM southern_california
WHERE date >= current_date - interval '10' day
GROUP BY date, region, total_cases, total_deaths
ORDER BY date DESC, region DESC \crosstabview region date total_cases;
```

Our result should look like this:

```sql
 region | 2020-04-01 | 2020-03-31 | 2020-03-30 | 2020-03-29 | 2020-03-28 | 2020-03-27 | 2020-03-26 | 2020-03-25 | 2020-03-24 | 2020-03-23 
--------+------------+------------+------------+------------+------------+------------+------------+------------+------------+------------
 SoCal  |       4909 |       4216 |       3466 |       2982 |       2472 |       2118 |       1695 |       1197 |        950 |        761
 NorCal |       2519 |       2257 |       2121 |       1825 |       1692 |       1556 |       1358 |       1122 |        978 |        854
(2 rows)
```

## Graphing data using Grafana
[Grafana][grafana-product] is an open source visualization tool for time-series data. You can install Grafana by following [this tutorial][grafana-install]. You'll want to setup a new datasource that connects to your TimescaleDB instance. If you're using Timescale Cloud, this information can be found in the "Overview" tab of your Timescale Cloud Portal:

![img](https://s3.amazonaws.com/docs.timescale.com/hello-timescale/NYC_figure1_1.png)

Once Grafana is setup, you can create a new dashboard and a new visualization. For visualization, we will use a simple line graph.

- In the "General" tab, set the "Title" to "Northern and Southern California".
- In the "Visualization" tab, set the "Draw Mode" to "Bars" and uncheck "Lines". In the "Stacking & Null value" section, turn "Stack" on. 
- In the "Queries" tab, click on the "Query" dropdown to select your datsource. Now, click on 
"Edit SQL" and enter the following: 

```sql
SELECT date as "time", 'NorCal' AS region, total_cases
FROM northern_california
GROUP BY date, region, total_cases
ORDER BY date
```

Click the "Add Query" button to add a second query to your visualization and add the following query:

```sql
SELECT date as "time", 'SoCal' AS region, total_cases
FROM southern_california
GROUP BY date, region, total_cases
ORDER BY date
```

Your query and graph should now look like this:

![Graph + Query of NorCal vs SoCal confirmed cases](https://dev-to-uploads.s3.amazonaws.com/i/bxlhct4yz5n47ub74t6o.png)

(and here's a view of just the graph)

![Zoom in of Graph of NorCal vs SoCal confirmed cases](https://dev-to-uploads.s3.amazonaws.com/i/nqlwk3ugfba3a0ss8inh.png)

## What is the rate of change in cases?
The rate of change day-over-day gives us a good idea of the velocity with which events are changing. Combined with the raw numbers, we can develop understanding of whether or not we are making progress in the fight against COVID-19. To calculate the rate of change, we will use the [`time_bucket`][time-bucket-docs] function in TimescaleDB. Time bucket, as the name suggests, enables us to bucket our results in a pre-defined period of time. For example, we could look at the rate of change every day, or every few days. In this case, let's query for the rate of change in cases due to COVID-19 day-over-day:

```sql
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
```

Our results should look like this (clipped for space):

```sql
    day     |          state           | cases | previous_day | rate_of_change 
------------+--------------------------+-------+--------------+----------------
 2020-04-01 | Northern Mariana Islands |     6 |            2 |            200
 2020-04-01 | Tennessee                |  2440 |         1834 |             33
 2020-04-01 | Nebraska                 |   249 |          193 |             29
 2020-04-01 | Oklahoma                 |   719 |          566 |             27
 2020-04-01 | Idaho                    |   669 |          526 |             27
 2020-04-01 | Louisiana                |  6424 |         5237 |             23
 2020-04-01 | Michigan                 |  9293 |         7630 |             22
 2020-04-01 | Virginia                 |  1511 |         1250 |             21
 2020-04-01 | Puerto Rico              |   286 |          239 |             20
 2020-04-01 | South Carolina           |  1293 |         1083 |             19
```

And, if you'd prefer, you can arrange it as cross-tabs ordered by state:

```sql
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
ORDER BY date DESC, state ASC \crosstabview state day rate_of_change;
```

Your result should look like this (clipped for space):

```sql
          state           | 2020-04-01 | 2020-03-31 | 2020-03-30 | 2020-03-29 | 2020-03-28 | 2020-03-27 | 2020-03-26 | 2020-03-25 | 2020-03-24 | 2020-03-23 
--------------------------+------------+------------+------------+------------+------------+------------+------------+------------+------------+------------
 Alabama                  |         11 |          5 |         14 |         15 |         13 |         19 |         39 |         60 |         23 |     [null]
 Alaska                   |          8 |         12 |          4 |         12 |         20 |         23 |         17 |         40 |         17 |     [null]
 Arizona                  |          9 |         11 |         26 |         20 |         16 |         31 |         26 |         23 |         39 |     [null]
 Arkansas                 |         11 |         11 |         13 |         10 |          6 |         10 |         14 |         33 |         15 |     [null]
 California               |         14 |         16 |         18 |         13 |         13 |         21 |         28 |         20 |         18 |     [null]
 Colorado                 |         12 |         14 |         14 |         12 |         19 |         21 |         32 |         19 |         26 |     [null]
```

## How does the spread of COVID-19 relate to election data? 
Given that our political leadership has transformed what should be purely a public health discussion into a political and partisan one, it may be important to factor in political considerations when understanding the spread and impact of COVID-19.

Our election data from the MIT Election Data Science Lab is organized as follows, which is reflected in the schema we setup earlier for the `elections` table:

- The `year` of the election (data in this dataset goes back to 2000)
- The `state` and `county` (with corresponding `fips` code, a [standard numeric designation][fips-code] used by the United States Government)
- The `candidate`
- The `votes` the candidate received, and the `total_votes` in the election

There are other fields in the dataset, but they're not relevant to our analysis here.

We can start by segmenting our election data into counties that voted for President Trump and counties that voted for Secretary Clinton. To do this, we will create two SQL views, each of which include a subquery:

```sql
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
```

Now, let's look at all cases and deaths in each of the counties that voted for President Trump. To execute this query, we will use a subquery matched on the county "FIPS" code. Because we're using public datasets from three different sources, we want to account for possible discrepancies in county names, be they from spelling errors, use of special characters, and so forth. Standardizing on a numeric FIPS code enables us to match queries across tables:

```sql
SELECT counties.date, sum (counties.cases) as total_cases, sum (counties.deaths) as total_deaths
FROM counties
WHERE counties.fips IN (SELECT fips FROM trump_counties) AND date >= current_date - interval '10' day
GROUP BY date
ORDER BY date DESC;
```

And our result should look like this:

```sql
    date    | total_cases | total_deaths 
------------+-------------+--------------
 2020-04-01 |       43339 |          903
 2020-03-31 |       37101 |          702
 2020-03-30 |       31466 |          553
 2020-03-29 |       26802 |          455
 2020-03-28 |       22692 |          404
 2020-03-27 |       18704 |          317
 2020-03-26 |       14997 |          230
 2020-03-25 |       11726 |          174
 2020-03-24 |        9353 |          126
 2020-03-23 |        7363 |           96
(10 rows)
```

We can run a similar query for counties that voted for Secretary Clinton by substituting the `clinton_counties` view and obtain the following results:

```sql
    date    | total_cases | total_deaths 
------------+-------------+--------------
 2020-04-01 |      116490 |         2178
 2020-03-31 |      101935 |         1769
 2020-03-30 |       88163 |         1393
 2020-03-29 |       76400 |         1129
 2020-03-28 |       66035 |         1029
 2020-03-27 |       55193 |          854
 2020-03-26 |       44653 |          641
 2020-03-25 |       35046 |          512
 2020-03-24 |       28361 |          400
 2020-03-23 |       22702 |          314
(10 rows)
```

## Graphing the spread of COVID-19 alongside election data
Let's view the results of our analysis into COVID-19 cases and election data in a Grafana visualization.

In Grafana, add a new panel and choose the "Graph" visualization. This time, we will create a simple line chart with all the default settings. Make sure the correct dataset is selected in the "Query" drop-down, add the following query by clicking "Edit SQL":

```sql
SELECT counties.date as "time", sum (counties.cases) as trump_cases
FROM counties
WHERE counties.fips IN (SELECT fips FROM trump_counties)
GROUP BY date
ORDER BY date DESC;
```

Add another query, click "Edit SQL", and enter the following:

```sql
SELECT counties.date as "time", sum (counties.cases) as clinton_cases
FROM counties
WHERE counties.fips IN (SELECT fips FROM clinton_counties)
GROUP BY date
ORDER BY date DESC;
```

The resulting visualization should look like this:

![Graph + Query of confirmed COVID19 cases in Trump counties vs Clinton counties](https://dev-to-uploads.s3.amazonaws.com/i/ee0x1i4g1au55d2kvk6i.png)

(and zoomed in on the graph itself)

![Zoomed graph of confirmed COVID19 cases in Trump counties vs Clinton counties](https://dev-to-uploads.s3.amazonaws.com/i/gtne8cy9y0hj6inzpomr.png)

## And what about the economic impact?
We can use the county-by-county Gross Domestic Product (GDP) data to look at GDP across the country and within each county itself. First, let's look at how much total GDP is represented in our dataset using the simplest query we've run in this tutorial:

```sql
SELECT sum(dollars)
FROM gdp;
```

Our result is $18,452,822,315.00, or close to $18.5T. The *actual* GDP of the country is a bit higher, but our dataset accounts for $18.5T.

Now, we can compare the GDP of the counties where there are greater than 100 cases:

```sql
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM counties WHERE cases > 100 AND date = current_date - 1);
```

The resulting answer ($11,229,517,359.00) is roughly 61% of the total GDP in our dataset. (of course, these results will change depending on when you choose to run these queries)

## Put it all together
We know that so far, the counties that voted for Secretary Clinton are harder hit in terms of total COVID-19 cases and deaths than the counties that voted for President Trump.

Using this query, we can see the total GDP of counties that voted for President Trump:

```sql
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM trump_counties);
```

It amounts to about $6.3T, or 1/3 of total GDP of the United States.

A similar query can be run for counties that voted for Secretary Clinton:

```sql
SELECT sum(dollars) AS total_gdp
FROM gdp
WHERE gdp.fips IN (SELECT fips FROM clinton_counties);
```

Those counties amount to $11.9T, or 2/3 of total GDP of the United States.

In order to stave off even greater economic catastrophe, it would behoove the United States Government to quickly stabilize counties that did not vote for President Trump, because these account for 2/3 of total US GDP, before those that did vote for him. While correlation isn't causation, and we'd like to give everyone the benefit of the doubt, one fact remains true: playing politics in the middle of a health and economic crisis hurts all Americans, everywhere.

# Summary
Data gives us insight into the world around us. By using data, we are able to make better decisions for our physical, emotional, and financial health. This post gives you much of the mechanics of extracting and querying data. Conducting analysis and making inferences based on that data is an art form, and always subject to interpretation. I'd love to see your interepretation and further analysis.

As you can see, bringing multiple public datasets together can be fascinating. I’ve also **[started a virtual meetup][meetup]** (with the help of my colleagues at Timescale) so I can meet people with similar interests and continue to learn new things. If you’re a data enthusiast, you’re welcome (and encouraged) to join us at any time - the more the merrier.

Finally, please follow all guidelines from your local public health authorities. Let's all look out for one another, be kind, and do our part to get through this time as safely as possible.

[test-distribution]: https://www.washingtonpost.com/health/2020/04/01/scramble-rapid-coronavirus-tests-everybody-wants/
[more-testing]: https://www.marketwatch.com/story/anthony-fauci-says-coronavirus-might-keep-coming-back-year-after-year-the-ultimate-game-changer-in-this-will-be-a-vaccine-2020-04-02
[population-article]: https://www.brookings.edu/blog/the-avenue/2017/03/23/a-substantial-majority-of-americans-live-outside-trump-counties-census-shows/
[covid-data]: https://github.com/nytimes/covid-19-data
[election-data]: https://github.com/MEDSL/county-returns
[gdp-data]: https://www.bea.gov/data/gdp/gdp-county-metro-and-other-areas
[cleanup-data-post]: https://dev.to/timescale/how-to-weave-together-public-datasets-to-make-sense-of-the-world-3pfh
[my-github]: https://github.com/coolasspuppy/nyt-covid
[timescale-info]: https://www.timescale.com/products?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=products
[timescale-cloud]: https://www.timescale.com/cloud?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=product-cloud
[timescale-install]: https://docs.timescale.com/latest/getting-started/exploring-cloud?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=explore-cloud
[install-psql]: https://docs.timescale.com/latest/getting-started/install-psql-tutorial?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=install-psql
[grafana-product]: https://www.grafana.com
[grafana-install]: https://docs.timescale.com/latest/tutorials/tutorial-grafana?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=grafana-install
[time-bucket-docs]: https://docs.timescale.com/latest/using-timescaledb/reading-data#time-bucket?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=time-bucket-docs
[fips-code]: https://en.wikipedia.org/wiki/FIPS_county_code
[meetup]: https://www.timescale.com/meetups/datapub/?utm_source=devto-covidelection&utm_medium=blog&utm_campaign=apr-2020-advocacy&utm_content=datapub-signup
