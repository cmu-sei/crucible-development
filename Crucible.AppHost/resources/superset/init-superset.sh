#!/bin/bash
set -e

# Run database migrations
superset db upgrade

# Create admin user (ignore error if already exists)
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@crucible.local \
  --password admin || true

# Initialize Superset (roles, permissions, etc.)
superset init

# Register LRsql database connection if URI is provided
if [ -n "$LRSQL_SQLALCHEMY_URI" ]; then
  python -c "
from superset.app import create_app
app = create_app()
with app.app_context():
    from superset import db
    from superset.models.core import Database
    existing = db.session.query(Database).filter_by(database_name='LRsql (xAPI)').first()
    if not existing:
        lrsql_db = Database(
            database_name='LRsql (xAPI)',
            sqlalchemy_uri='$LRSQL_SQLALCHEMY_URI',
            expose_in_sqllab=True,
            allow_run_async=False,
            allow_ctas=False,
            allow_cvas=False,
            allow_dml=False,
        )
        db.session.add(lrsql_db)
        db.session.commit()
        print('LRsql database connection registered successfully')
    else:
        existing.sqlalchemy_uri = '$LRSQL_SQLALCHEMY_URI'
        existing.allow_run_async = False
        db.session.commit()
        print('LRsql database connection updated')
"
fi

# Start Superset
superset run -h 0.0.0.0 -p 8088 --with-threads
