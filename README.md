# smartmeter
A database / website for viewing smart meter data

This project is primarily a django website on top of a postgresql database, designed to allow
UK energy smart meter owners to load and analyse their data. This website can be accessed at 
https://energy.guylipman.com/sm/home.

For more information about the project visit the docs folder, or the blogpost at https://medium.com/@guylipman/a-website-for-viewing-your-smart-meter-data-4d4c84b2bc33.

This project also includes a subproject:

The forecasts folder produces forecasts of hourly electricity prices for the next 7 days. You can see these endpoints on https://energy.guylipman.com/forecasts?region=C for region C retail prices for Octopus Agile, or https://energy.guylipman.com/forecasts for wholesale prices.

## Running locally

Needs Python 3.14, [uv](https://docs.astral.sh/uv/) and PostgreSQL.

```
uv venv --python 3.14 && uv pip install -r requirements.txt
cp django_project/local_settings.example.py django_project/local_settings.py
# create myutils/keys.py (see the names imported from myutils.keys), pointing DJANGO_DB at a local database
sh db/setup.sh          # creates the schema, synthetic demo data and forecasts/cache.pkl
uv run python manage.py runserver
```

Then open http://localhost:8000/sm/home. The demo user's data covers Jan–Aug 2023, to match the
pages' default date ranges.
