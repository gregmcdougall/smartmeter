-- Synthetic seed data for local development. Run after schema.sql.
-- Everything here is made up; it only needs to look plausible enough for pages to render.

SELECT setseed(0.42);

-- Half-hour periods from 2019-01-01 to the end of 2027
INSERT INTO sm_periods (period_id, period, local_date, local_time, timezone_adj)
SELECT
    (extract(epoch FROM ts - timestamp '2019-01-01') / 1800)::int
    , to_char(ts, 'YYYY-MM-DD HH24:MI')
    , ((ts AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/London')::date
    , to_char((ts AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/London', 'HH24:MI')
    , extract(hour FROM ((ts AT TIME ZONE 'UTC') AT TIME ZONE 'Europe/London') - ts)::smallint
FROM generate_series(timestamp '2019-01-01', timestamp '2027-12-31 23:30', interval '30 minutes') ts;

-- Periods covered by the synthetic data. The pages' default date ranges are hardcoded
-- (eg smcharts.py end='2025-01-01', smtest.py 2023/01/01-2023/08/31), so the demo user's
-- history sits in Jan-Aug 2023. Prices also cover recent and upcoming days for /forecasts.
CREATE TEMP TABLE win AS
SELECT period_id, local_date, local_time,
       substr(local_time, 1, 2)::int + substr(local_time, 4, 2)::int / 60.0 AS hr,
       local_date BETWEEN '2023-01-01' AND '2023-08-31' AS demo
FROM sm_periods
WHERE local_date BETWEEN '2023-01-01' AND '2023-08-31'
   OR local_date BETWEEN current_date - 30 AND current_date + 8;

-- Variables: Octopus products for every region, plus national carbon intensity and a load profile
INSERT INTO sm_variables (var_id, product, region, type_id, granularity_id)
SELECT row_number() OVER (ORDER BY p.product, r.region), p.product, r.region, p.type_id, p.granularity_id
FROM (VALUES ('AGILE-18-02-21', 0, 0), ('AGILE-22-07-22', 0, 0), ('AGILE-FLEX-22-11-25', 0, 0),
             ('AGILE-OUTGOING-19-05-13', 2, 0), ('SILVER-2017-1', 1, 1)) p(product, type_id, granularity_id)
CROSS JOIN unnest(ARRAY['A','B','C','D','E','F','G','H','J','K','L','M','N','P']) r(region);

INSERT INTO sm_variables (var_id, product, region, type_id, granularity_id)
SELECT max(var_id) + 1, 'CO2_National', 'Z', 0, 0 FROM sm_variables;
INSERT INTO sm_variables (var_id, product, region, type_id, granularity_id)
SELECT max(var_id) + 1, 'Profile_1', 'Z', 0, 0 FROM sm_variables;

-- Half-hourly import prices (p/kWh ex VAT): cheap overnight, peak 16:00-19:00, regional multiplier
INSERT INTO sm_hh_variable_vals (var_id, period_id, value)
SELECT v.var_id, w.period_id,
       round(((12 + 6 * sin((w.hr - 6) / 24 * 2 * pi()) + CASE WHEN w.hr >= 16 AND w.hr < 19 THEN 14 ELSE 0 END
               + random() * 4) * (0.95 + ascii(v.region) % 7 * 0.02))::numeric, 2)
FROM sm_variables v CROSS JOIN win w
WHERE v.product LIKE 'AGILE-%' AND v.product <> 'AGILE-OUTGOING-19-05-13';

-- Export prices
INSERT INTO sm_hh_variable_vals (var_id, period_id, value)
SELECT v.var_id, w.period_id,
       round((5 + 3 * sin((w.hr - 6) / 24 * 2 * pi()) + CASE WHEN w.hr >= 16 AND w.hr < 19 THEN 8 ELSE 0 END
              + random() * 2)::numeric, 2)
FROM sm_variables v CROSS JOIN win w
WHERE v.product = 'AGILE-OUTGOING-19-05-13';

-- Carbon intensity (gCO2/kWh) and a normalised domestic load profile
INSERT INTO sm_hh_variable_vals (var_id, period_id, value)
SELECT v.var_id, w.period_id,
       round((180 + 60 * sin((w.hr - 9) / 24 * 2 * pi()) + random() * 40)::numeric, 1)
FROM sm_variables v CROSS JOIN win w WHERE v.product = 'CO2_National';

INSERT INTO sm_hh_variable_vals (var_id, period_id, value)
SELECT v.var_id, w.period_id,
       round((0.12 + 0.08 * greatest(sin((w.hr - 5) / 24 * 2 * pi()), 0)
              + CASE WHEN w.hr >= 17 AND w.hr < 21 THEN 0.15 ELSE 0 END)::numeric, 4)
FROM sm_variables v CROSS JOIN win w WHERE v.product = 'Profile_1';

-- Daily gas tracker prices
INSERT INTO sm_d_variable_vals (var_id, local_date, value)
SELECT v.var_id, d::date, round((3.5 + random() * 1.5)::numeric, 3)
FROM sm_variables v
CROSS JOIN (SELECT DISTINCT local_date AS d FROM win) d
WHERE v.product = 'SILVER-2017-1';

-- Demo user (the session id hardcoded in myutils/smutils.py get_sm_id), with
-- electricity, gas and export accounts covering Jan-Aug 2023
INSERT INTO sm_accounts (type_id, first_period, last_period, last_updated, region, source_id, session_id, active)
SELECT t, min(w.period), max(w.period), now(), 'C', 1, 'e4280c7d-9d06-4bbe-87b4-f9e106ede788', true
FROM generate_series(0, 2) t
CROSS JOIN (SELECT p.period FROM win JOIN sm_periods p USING (period_id) WHERE win.demo) w
GROUP BY t;

INSERT INTO sm_quantity (account_id, period_id, quantity)
SELECT a.account_id, w.period_id,
       round((CASE a.type_id
           WHEN 0 THEN 0.15 + 0.2 * greatest(sin((w.hr - 5) / 24 * 2 * pi()), 0)
                       + CASE WHEN w.hr >= 17 AND w.hr < 21 THEN 0.35 ELSE 0 END + random() * 0.15
           WHEN 1 THEN CASE WHEN (w.hr >= 6 AND w.hr < 9) OR (w.hr >= 17 AND w.hr < 22) THEN 1.5 + random() ELSE random() * 0.2 END
           ELSE greatest(1.2 * sin((w.hr - 6) / 12 * pi()), 0) * (0.5 + random() * 0.5)
       END)::numeric, 3)
FROM sm_accounts a
CROSS JOIN win w
WHERE a.session_id = 'e4280c7d-9d06-4bbe-87b4-f9e106ede788' AND w.demo;

-- Hourly demand/wind/solar forecasts (MW) for the forecasts page, issued an hour ago
INSERT INTO forecast_demand (forecast_for, forecast_at, forecast)
SELECT h, now()::timestamp - interval '1 hour',
       round((26000 + 6000 * sin((extract(hour FROM h) - 6) / 24 * 2 * pi()) + random() * 1500)::numeric)
FROM generate_series(date_trunc('day', now()::timestamp), date_trunc('day', now()::timestamp) + interval '8 days', interval '1 hour') h;

INSERT INTO forecast_wind (forecast_for, forecast_at, forecast)
SELECT h, now()::timestamp - interval '1 hour', round((4000 + random() * 8000)::numeric)
FROM generate_series(date_trunc('day', now()::timestamp), date_trunc('day', now()::timestamp) + interval '8 days', interval '1 hour') h;

INSERT INTO forecast_solar (forecast_for, forecast_at, forecast)
SELECT h, now()::timestamp - interval '1 hour',
       round(greatest(5000 * sin((extract(hour FROM h) - 6) / 12 * pi()), 0)::numeric)
FROM generate_series(date_trunc('day', now()::timestamp), date_trunc('day', now()::timestamp) + interval '8 days', interval '1 hour') h;

ANALYZE;
