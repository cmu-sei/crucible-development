"""Create starter xAPI analytics dashboard in Superset via API."""
import requests
import json
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8088"
s = requests.Session()

# Login
r = s.post(f"{BASE}/api/v1/security/login", json={
    "username": "admin", "password": "admin", "provider": "db", "refresh": True
})
token = r.json()["access_token"]
s.headers["Authorization"] = f"Bearer {token}"

# Get CSRF token (need cookie session)
r = s.get(f"{BASE}/api/v1/security/csrf_token/")
csrf = r.json()["result"]
s.headers["X-CSRFToken"] = csrf
s.headers["Referer"] = BASE

# Check if dashboard exists
r = s.get(f"{BASE}/api/v1/dashboard/", params={"q": json.dumps({"filters": [{"col": "slug", "opr": "eq", "value": "xapi-analytics"}]})})
if r.json()["count"] > 0:
    print("xAPI Analytics dashboard already exists")
    sys.exit(0)

# Get LRsql database ID
r = s.get(f"{BASE}/api/v1/database/")
db_id = next(d["id"] for d in r.json()["result"] if "LRsql" in d["database_name"])
print(f"LRsql database ID: {db_id}")

# Create datasets
def create_dataset(name, sql):
    r = s.post(f"{BASE}/api/v1/dataset/", json={
        "database": db_id,
        "schema": "public",
        "table_name": name,
        "sql": sql,
        "is_managed_externally": False,
    })
    if r.status_code not in (200, 201):
        print(f"  ERROR creating {name}: {r.status_code} {r.text}")
        return None
    ds_id = r.json()["id"]
    print(f"  Dataset '{name}': {ds_id}")
    return ds_id

print("Creating datasets...")

ds_verbs = create_dataset("xapi_verb_frequency", """
SELECT
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    verb_iri,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided
GROUP BY verb_iri
ORDER BY statement_count DESC
""")

ds_timeline = create_dataset("xapi_activity_timeline", """
SELECT
    DATE_TRUNC('hour', timestamp) AS time_bucket,
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided AND timestamp IS NOT NULL
GROUP BY time_bucket, verb_iri
ORDER BY time_bucket
""")

ds_learners = create_dataset("xapi_learner_activity", """
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
ORDER BY statement_count DESC
""")

ds_objects = create_dataset("xapi_activity_objects", """
SELECT
    a.activity_iri,
    a.payload->>'name' AS activity_name,
    sta.usage AS context_type,
    COUNT(DISTINCT sta.statement_id) AS statement_count
FROM statement_to_activity sta
JOIN activity a ON a.activity_iri = sta.activity_iri
GROUP BY a.activity_iri, a.payload->>'name', sta.usage
ORDER BY statement_count DESC
""")

if not all([ds_verbs, ds_timeline, ds_learners, ds_objects]):
    print("Some datasets failed to create, aborting")
    sys.exit(1)

# Create charts
def create_chart(name, ds_id, viz_type, params):
    r = s.post(f"{BASE}/api/v1/chart/", json={
        "slice_name": name,
        "datasource_id": ds_id,
        "datasource_type": "table",
        "viz_type": viz_type,
        "params": json.dumps(params),
    })
    if r.status_code not in (200, 201):
        print(f"  ERROR creating chart '{name}': {r.status_code} {r.text}")
        return None
    chart_id = r.json()["id"]
    print(f"  Chart '{name}': {chart_id}")
    return chart_id

print("Creating charts...")

c_pie = create_chart("xAPI Verb Distribution", ds_verbs, "pie", {
    "viz_type": "pie",
    "groupby": ["verb"],
    "metric": {"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"},
    "row_limit": 20,
    "sort_by_metric": True,
    "color_scheme": "supersetColors",
    "show_labels": True,
    "label_type": "key_percent",
})

c_bar = create_chart("xAPI Verb Counts", ds_verbs, "dist_bar", {
    "viz_type": "dist_bar",
    "groupby": ["verb"],
    "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
    "row_limit": 20,
    "order_desc": True,
    "color_scheme": "supersetColors",
    "show_legend": False,
    "x_axis_label": "Verb",
    "y_axis_label": "Count",
})

c_timeline = create_chart("xAPI Activity Over Time", ds_timeline, "echarts_timeseries_line", {
    "viz_type": "echarts_timeseries_line",
    "x_axis": "time_bucket",
    "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
    "groupby": ["verb"],
    "row_limit": 10000,
    "color_scheme": "supersetColors",
    "show_legend": True,
    "rich_tooltip": True,
})

c_learners = create_chart("Top Learners by Activity", ds_learners, "table", {
    "viz_type": "table",
    "query_mode": "aggregate",
    "groupby": ["learner_name"],
    "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
    "order_desc": True,
    "row_limit": 50,
})

c_objects = create_chart("Most Active Learning Objects", ds_objects, "table", {
    "viz_type": "table",
    "query_mode": "aggregate",
    "groupby": ["activity_iri", "activity_name"],
    "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
    "order_desc": True,
    "row_limit": 50,
})

charts = [c_pie, c_bar, c_timeline, c_learners, c_objects]
if not all(charts):
    print("Some charts failed to create, aborting")
    sys.exit(1)

# Create dashboard
print("Creating dashboard...")

positions = {
    "DASHBOARD_VERSION_KEY": "v2",
    "ROOT_ID": {"type": "ROOT", "id": "ROOT_ID", "children": ["GRID_ID"]},
    "GRID_ID": {"type": "GRID", "id": "GRID_ID", "children": ["ROW-1", "ROW-2", "ROW-3"], "parents": ["ROOT_ID"]},
    "HEADER_ID": {"type": "HEADER", "id": "HEADER_ID", "meta": {"text": "xAPI Learning Analytics"}},
}

chart_info = [
    (c_pie, "xAPI Verb Distribution", 6, "ROW-1"),
    (c_bar, "xAPI Verb Counts", 6, "ROW-1"),
    (c_timeline, "xAPI Activity Over Time", 12, "ROW-2"),
    (c_learners, "Top Learners by Activity", 6, "ROW-3"),
    (c_objects, "Most Active Learning Objects", 6, "ROW-3"),
]

for row_id in ["ROW-1", "ROW-2", "ROW-3"]:
    children = [f"CHART-{i+1}" for i, (_, _, _, r) in enumerate(chart_info) if r == row_id]
    positions[row_id] = {
        "type": "ROW", "id": row_id, "children": children,
        "parents": ["ROOT_ID", "GRID_ID"],
        "meta": {"background": "BACKGROUND_TRANSPARENT"},
    }

for i, (cid, name, width, row) in enumerate(chart_info):
    key = f"CHART-{i+1}"
    positions[key] = {
        "type": "CHART", "id": key, "children": [],
        "parents": ["ROOT_ID", "GRID_ID", row],
        "meta": {"chartId": cid, "width": width, "height": 50, "sliceName": name},
    }

r = s.post(f"{BASE}/api/v1/dashboard/", json={
    "dashboard_title": "xAPI Learning Analytics",
    "slug": "xapi-analytics",
    "published": True,
    "position_json": json.dumps(positions),
})

if r.status_code not in (200, 201):
    print(f"ERROR creating dashboard: {r.status_code} {r.text}")
    sys.exit(1)

dash_id = r.json()["id"]
print(f"Dashboard ID: {dash_id}")

# PUT to sync dashboard-chart relationships (POST doesn't populate dashboard_slices)
r = s.put(f"{BASE}/api/v1/dashboard/{dash_id}", json={
    "position_json": json.dumps(positions),
    "json_metadata": json.dumps({
        "default_filters": "{}",
        "expanded_slices": {},
        "refresh_frequency": 0,
        "timed_refresh_immune_slices": [],
        "color_scheme": "supersetColors",
    }),
})
if r.status_code not in (200, 201):
    print(f"WARNING: PUT to sync charts failed: {r.status_code} {r.text}")

print(f"Dashboard: {BASE}/superset/dashboard/xapi-analytics/")
