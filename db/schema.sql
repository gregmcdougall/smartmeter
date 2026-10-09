-- Schema for the Smart Meter Data Viewer, reconstructed from the queries in the
-- current code (the CREATE TABLE blocks in scripts/postgrestest.py are out of date).
-- See docs/database.md for column meanings.

DROP VIEW IF EXISTS sm_tariffs;
DROP TABLE IF EXISTS sm_periods, sm_accounts, sm_quantity, sm_variables,
    sm_hh_variable_vals, sm_d_variable_vals, sm_log,
    price_function, price_forecast, forecast_demand, forecast_wind, forecast_solar;

-- One row per half hour; period_id 0 is 2019-01-01 00:00 UTC
CREATE TABLE sm_periods (
    period_id integer PRIMARY KEY
    , period char(16) NOT NULL            -- UTC, 'YYYY-MM-DD HH:MI'
    , local_date date NOT NULL            -- Europe/London
    , local_time char(5) NOT NULL         -- Europe/London, eg '23:30'
    , timezone_adj smallint NOT NULL      -- 1 if BST, 0 if GMT
);
CREATE INDEX sm_periods_local_date ON sm_periods (local_date);

CREATE TABLE sm_accounts (
    account_id serial PRIMARY KEY
    , type_id smallint NOT NULL           -- 0 elec consumption, 1 gas, 2 elec export
    , first_period varchar(16) NOT NULL
    , last_period varchar(16) NOT NULL
    , last_updated timestamp NOT NULL
    , region char(1)
    , source_id smallint NOT NULL         -- 0 n3rgy, 1 octopus
    , session_id uuid
    , active bool NOT NULL DEFAULT true
);
CREATE INDEX sm_accounts_session ON sm_accounts (session_id);

CREATE TABLE sm_quantity (
    id serial PRIMARY KEY
    , account_id integer NOT NULL
    , period_id integer NOT NULL
    , quantity float(8) NOT NULL
);
CREATE INDEX sm_quantity_account ON sm_quantity (account_id, period_id);

CREATE TABLE sm_variables (
    var_id integer PRIMARY KEY
    , product varchar(32) NOT NULL
    , region char(1) NOT NULL             -- Z for variables without a region
    , type_id integer NOT NULL
    , granularity_id integer NOT NULL     -- 0 half-hourly, 1 daily
);

-- forecasts/views.py still queries the old sm_tariffs table name
CREATE VIEW sm_tariffs AS
    SELECT var_id, product, region, type_id, granularity_id FROM sm_variables;

CREATE TABLE sm_hh_variable_vals (
    id serial PRIMARY KEY
    , var_id integer NOT NULL
    , period_id integer NOT NULL
    , value float(8) NOT NULL
);
CREATE INDEX sm_hh_variable_vals_var ON sm_hh_variable_vals (var_id, period_id);

CREATE TABLE sm_d_variable_vals (
    id serial PRIMARY KEY
    , var_id integer NOT NULL
    , local_date date NOT NULL
    , value float(8) NOT NULL
);
CREATE INDEX sm_d_variable_vals_var ON sm_d_variable_vals (var_id, local_date);

CREATE TABLE sm_log (
    id serial PRIMARY KEY
    , datetime timestamp NOT NULL
    , url varchar(124) NOT NULL
    , method integer NOT NULL             -- 0 GET, 1 POST
    , session_id uuid
    , choice varchar(64)
    , http_user_agent varchar(124)
);

CREATE TABLE price_function (
    id smallserial PRIMARY KEY
    , date date NOT NULL
    , slope float(8) NOT NULL
    , intercept float(8) NOT NULL
    , r float(8) NOT NULL
    , created_on timestamp NOT NULL
);

CREATE TABLE price_forecast (
    id serial PRIMARY KEY
    , datetime timestamp NOT NULL
    , demand float(8) NOT NULL
    , solar float(8) NOT NULL
    , wind float(8) NOT NULL
    , price float(4) NOT NULL
    , created_on timestamp NOT NULL
);

CREATE TABLE forecast_demand (
    id serial PRIMARY KEY
    , forecast_for timestamp NOT NULL
    , forecast_at timestamp NOT NULL
    , forecast float(8) NOT NULL
);
CREATE TABLE forecast_wind (LIKE forecast_demand INCLUDING ALL);
CREATE TABLE forecast_solar (LIKE forecast_demand INCLUDING ALL);
