# Copyright 2026 Carnegie Mellon University. All Rights Reserved.
# Released under a MIT (SEI)-style license. See LICENSE.md in the project root for license information.

"""Create starter xAPI analytics dashboard using Superset's internal ORM.

This script runs inside the Superset container after init, using direct
database access to properly populate the dashboard_slices relationship
that the REST API doesn't handle.
"""
import json
import sys

from superset.app import create_app

app = create_app()

with app.app_context():
    from superset import db
    from superset.models.core import Database
    from superset.connectors.sqla.models import SqlaTable
    from superset.models.slice import Slice
    from superset.models.dashboard import Dashboard

    # Check if dashboard already exists
    existing = db.session.query(Dashboard).filter_by(slug="xapi-analytics").first()
    if existing:
        print("xAPI Analytics dashboard already exists")
        sys.exit(0)

    # Get LRsql database
    lrsql_db = db.session.query(Database).filter(
        Database.database_name.contains("LRsql")
    ).first()
    if not lrsql_db:
        print("LRsql database not found, skipping dashboard creation")
        sys.exit(0)

    print(f"LRsql database ID: {lrsql_db.id}")

    # Create virtual datasets
    datasets_config = [
        ("xapi_client_activity", """
SELECT
    CASE
        WHEN a.activity_iri LIKE '%:4724/%' OR a.activity_iri LIKE '%blueprint%' THEN 'Blueprint'
        WHEN a.activity_iri LIKE '%:4720/%' OR a.activity_iri LIKE '%cite%' THEN 'CITE'
        WHEN a.activity_iri LIKE '%:4722/%' OR a.activity_iri LIKE '%gallery%' THEN 'Gallery'
        WHEN a.activity_iri LIKE '%:4300/%' OR a.activity_iri LIKE '%:4301/%' OR a.activity_iri LIKE '%player%' THEN 'Player'
        WHEN a.activity_iri LIKE '%:4400/%' OR a.activity_iri LIKE '%:4401/%' OR a.activity_iri LIKE '%steamfitter%' THEN 'Steamfitter'
        WHEN a.activity_iri LIKE '%:4403/%' OR a.activity_iri LIKE '%alloy%' THEN 'Alloy'
        WHEN a.activity_iri LIKE '%:4310/%' OR a.activity_iri LIKE '%caster%' THEN 'Caster'
        WHEN a.activity_iri LIKE '%:5000/%' OR a.activity_iri LIKE '%topomojo%' THEN 'TopoMojo'
        WHEN a.activity_iri LIKE '%:4303/%' THEN 'Player VM'
        WHEN a.activity_iri LIKE '%:8081/%' OR a.activity_iri LIKE '%moodle%' THEN 'Moodle'
        ELSE 'Other'
    END AS client_app,
    REPLACE(REPLACE(s.verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    COUNT(DISTINCT s.statement_id) AS statement_count
FROM xapi_statement s
JOIN statement_to_activity sta ON sta.statement_id = s.statement_id AND sta.usage = 'Object'
JOIN activity a ON a.activity_iri = sta.activity_iri
WHERE NOT s.is_voided
GROUP BY client_app, s.verb_iri
ORDER BY statement_count DESC"""),
        ("xapi_verb_frequency", """
SELECT
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    verb_iri,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided
GROUP BY verb_iri
ORDER BY statement_count DESC"""),
        ("xapi_activity_timeline", """
SELECT
    DATE_TRUNC('hour', timestamp) AS time_bucket,
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided AND timestamp IS NOT NULL
GROUP BY time_bucket, verb_iri
ORDER BY time_bucket"""),
        ("xapi_learner_activity", """
SELECT
    s.payload->'actor'->>'name' AS learner_name,
    sta.actor_ifi AS learner_id,
    REPLACE(REPLACE(s.verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    COUNT(*) AS statement_count,
    MIN(s.timestamp) AS first_activity,
    MAX(s.timestamp) AS last_activity
FROM xapi_statement s
JOIN statement_to_actor sta ON sta.statement_id = s.statement_id AND sta.usage = 'Actor'
WHERE NOT s.is_voided
GROUP BY learner_name, learner_id, s.verb_iri
ORDER BY statement_count DESC"""),
        ("xapi_activity_objects", """
SELECT
    a.activity_iri,
    a.payload->>'name' AS activity_name,
    sta.usage AS context_type,
    COUNT(DISTINCT sta.statement_id) AS statement_count
FROM statement_to_activity sta
JOIN activity a ON a.activity_iri = sta.activity_iri
GROUP BY a.activity_iri, a.payload->>'name', sta.usage
ORDER BY statement_count DESC"""),
    ]

    datasets = {}
    print("Creating datasets...")
    for name, sql in datasets_config:
        ds = db.session.query(SqlaTable).filter_by(
            table_name=name, database_id=lrsql_db.id
        ).first()
        if not ds:
            ds = SqlaTable(
                table_name=name,
                database_id=lrsql_db.id,
                schema="public",
                sql=sql,
                is_managed_externally=False,
            )
            db.session.add(ds)
            db.session.flush()
            print(f"  Dataset '{name}': {ds.id}")
        else:
            print(f"  Dataset '{name}' already exists: {ds.id}")
        # Sync column metadata from the SQL query
        try:
            ds.fetch_metadata()
            print(f"    Synced {len(ds.columns)} columns")
        except Exception as e:
            print(f"    Warning: could not sync columns: {e}")
        datasets[name] = ds

    # Create charts
    charts_config = [
        ("Activity by Client App", "xapi_client_activity", "pie", {
            "viz_type": "pie",
            "groupby": ["client_app"],
            "metric": {"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"},
            "row_limit": 20,
            "sort_by_metric": True,
            "color_scheme": "supersetColors",
            "show_labels": True,
            "label_type": "key_percent",
        }),
        ("Client App Verb Breakdown", "xapi_client_activity", "dist_bar", {
            "viz_type": "dist_bar",
            "groupby": ["client_app"],
            "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
            "columns": ["verb"],
            "row_limit": 50,
            "order_desc": True,
            "color_scheme": "supersetColors",
            "show_legend": True,
            "x_axis_label": "Client Application",
            "y_axis_label": "Statement Count",
        }),
        ("xAPI Verb Distribution", "xapi_verb_frequency", "pie", {
            "viz_type": "pie",
            "groupby": ["verb"],
            "metric": {"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"},
            "row_limit": 20,
            "sort_by_metric": True,
            "color_scheme": "supersetColors",
            "show_labels": True,
            "label_type": "key_percent",
        }),
        ("xAPI Verb Counts", "xapi_verb_frequency", "dist_bar", {
            "viz_type": "dist_bar",
            "groupby": ["verb"],
            "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
            "row_limit": 20,
            "order_desc": True,
            "color_scheme": "supersetColors",
            "show_legend": False,
            "x_axis_label": "Verb",
            "y_axis_label": "Count",
        }),
        ("xAPI Activity Over Time", "xapi_activity_timeline", "echarts_timeseries_line", {
            "viz_type": "echarts_timeseries_line",
            "x_axis": "time_bucket",
            "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
            "groupby": ["verb"],
            "row_limit": 10000,
            "color_scheme": "supersetColors",
            "show_legend": True,
            "rich_tooltip": True,
        }),
        ("Top Learners by Activity", "xapi_learner_activity", "table", {
            "viz_type": "table",
            "query_mode": "aggregate",
            "groupby": ["learner_name"],
            "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
            "order_desc": True,
            "row_limit": 50,
        }),
        ("Most Active Learning Objects", "xapi_activity_objects", "table", {
            "viz_type": "table",
            "query_mode": "aggregate",
            "groupby": ["activity_iri", "activity_name"],
            "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
            "order_desc": True,
            "row_limit": 50,
        }),
    ]

    slices = []
    print("Creating charts...")
    for name, ds_name, viz_type, params in charts_config:
        ds = datasets[ds_name]
        chart = db.session.query(Slice).filter_by(slice_name=name).first()
        if not chart:
            chart = Slice(
                slice_name=name,
                datasource_id=ds.id,
                datasource_type="table",
                viz_type=viz_type,
                params=json.dumps(params),
            )
            db.session.add(chart)
            db.session.flush()
            print(f"  Chart '{name}': {chart.id}")
        else:
            print(f"  Chart '{name}' already exists: {chart.id}")
        slices.append(chart)

    # Build dashboard layout
    chart_layout = [
        (0, "Activity by Client App", 6, "ROW-1"),
        (1, "Client App Verb Breakdown", 6, "ROW-1"),
        (2, "xAPI Verb Distribution", 6, "ROW-2"),
        (3, "xAPI Verb Counts", 6, "ROW-2"),
        (4, "xAPI Activity Over Time", 12, "ROW-3"),
        (5, "Top Learners by Activity", 6, "ROW-4"),
        (6, "Most Active Learning Objects", 6, "ROW-4"),
    ]

    row_ids = ["ROW-1", "ROW-2", "ROW-3", "ROW-4"]
    positions = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]},
        "GRID_ID": {"type": "GRID", "id": "GRID_ID", "children": row_ids, "parents": ["ROOT_ID"]},
        "HEADER_ID": {"type": "HEADER", "id": "HEADER_ID", "meta": {"text": "xAPI Learning Analytics"}},
    }

    for row_id in row_ids:
        children = [f"CHART-{i+1}" for i, _, _, r in chart_layout if r == row_id]
        positions[row_id] = {
            "type": "ROW", "id": row_id, "children": children,
            "parents": ["ROOT_ID", "GRID_ID"],
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
        }

    for i, (idx, name, width, row) in enumerate(chart_layout):
        key = f"CHART-{i+1}"
        positions[key] = {
            "type": "CHART", "id": key, "children": [],
            "parents": ["ROOT_ID", "GRID_ID", row],
            "meta": {"chartId": slices[idx].id, "width": width, "height": 50, "sliceName": name},
        }

    # Create dashboard with slices properly associated
    print("Creating dashboard...")
    dashboard = Dashboard(
        dashboard_title="xAPI Learning Analytics",
        slug="xapi-analytics",
        published=True,
        position_json=json.dumps(positions),
        json_metadata=json.dumps({
            "default_filters": "{}",
            "expanded_slices": {},
            "refresh_frequency": 0,
            "timed_refresh_immune_slices": [],
            "color_scheme": "supersetColors",
        }),
    )
    dashboard.slices = slices  # This properly populates dashboard_slices!
    db.session.add(dashboard)
    db.session.commit()

    print(f"Dashboard created with {len(slices)} charts")
    print("Dashboard URL: /superset/dashboard/xapi-analytics/")
