"""Build forecasts/cache.pkl from the forecast_* tables, for local development.

In production scripts/priceforecast.py writes this file. Run from the repo root:
    uv run python -m db.make_forecast_cache
"""
import os
import pickle
import pandas as pd

from myutils.utils import loadDataFromDb


def latest(kind):
    s = f'''
    with d1 as (select forecast_for, max(forecast_at) as forecast_at from forecast_{kind}
    where forecast_for>=date_trunc('day', now()) group by forecast_for order by 1 limit 168)
    select d1.forecast_for, d1.forecast_at as {kind}_at, f.forecast as {kind}
    from d1 inner join forecast_{kind} f on d1.forecast_for=f.forecast_for and d1.forecast_at=f.forecast_at
    '''
    return loadDataFromDb(s, returndf=True).set_index('forecast_for')


# Mirrors the ?before= branch of forecasts/views.py inner()
d = pd.concat([latest(k) for k in ['demand', 'wind', 'solar']], axis=1).iloc[:168]
d['solar'] = d.solar.fillna(0)
d['demand'] = d.demand + d.solar
d['created_on'] = max(d.demand_at.max(), d.solar_at.max(), d.wind_at.max())
data = d.reset_index().rename(columns={'forecast_for': 'datetime'})

path = os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), 'forecasts', 'cache.pkl')
with open(path, 'wb') as f:
    pickle.dump(data, f)
print(f'Wrote {len(data)} rows to {path}')
