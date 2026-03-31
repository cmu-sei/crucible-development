#!/bin/bash
# Create starter xAPI analytics dashboard via Superset API
set -e

SUPERSET_URL="${1:-http://localhost:8088}"

# Get access token
TOKEN=$(curl -sf -X POST "$SUPERSET_URL/api/v1/security/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin","provider":"db","refresh":true}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])')

AUTH="Authorization: Bearer $TOKEN"

# Get CSRF token
CSRF=$(curl -sf "$SUPERSET_URL/api/v1/security/csrf_token/" -H "$AUTH" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["result"])')

# Check if dashboard already exists
EXISTING=$(curl -sf "$SUPERSET_URL/api/v1/dashboard/?q=(filters:!((col:slug,opr:eq,value:xapi-analytics)))" \
  -H "$AUTH" | python3 -c 'import sys,json; print(json.load(sys.stdin)["count"])')

if [ "$EXISTING" != "0" ]; then
  echo "xAPI Analytics dashboard already exists"
  exit 0
fi

# Get LRsql database ID
DB_ID=$(curl -sf "$SUPERSET_URL/api/v1/database/" -H "$AUTH" \
  | python3 -c 'import sys,json; dbs=json.load(sys.stdin)["result"]; print(next(d["id"] for d in dbs if "LRsql" in d["database_name"]))')

echo "LRsql database ID: $DB_ID"

# Helper function to create a dataset
create_dataset() {
  local name="$1"
  local sql="$2"
  local result
  result=$(curl -sf -X POST "$SUPERSET_URL/api/v1/dataset/" \
    -H "$AUTH" \
    -H "X-CSRFToken: $CSRF" \
    -H "Content-Type: application/json" \
    -H "Referer: $SUPERSET_URL" \
    -d "$(python3 -c "
import json
print(json.dumps({
    'database': $DB_ID,
    'schema': 'public',
    'table_name': '$name',
    'sql': '''$sql''',
    'is_managed_externally': False,
}))
")")
  echo "$result" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
}

# Create datasets
echo "Creating datasets..."

DS_VERBS=$(create_dataset "xapi_verb_frequency" "
SELECT
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    verb_iri,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided
GROUP BY verb_iri
ORDER BY statement_count DESC
")
echo "  Verb frequency dataset: $DS_VERBS"

DS_TIMELINE=$(create_dataset "xapi_activity_timeline" "
SELECT
    DATE_TRUNC('hour', timestamp) AS time_bucket,
    REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
    COUNT(*) AS statement_count
FROM xapi_statement
WHERE NOT is_voided AND timestamp IS NOT NULL
GROUP BY time_bucket, verb_iri
ORDER BY time_bucket
")
echo "  Activity timeline dataset: $DS_TIMELINE"

DS_LEARNERS=$(create_dataset "xapi_learner_activity" "
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
")
echo "  Learner activity dataset: $DS_LEARNERS"

DS_OBJECTS=$(create_dataset "xapi_activity_objects" "
SELECT
    a.activity_iri,
    a.payload->>'name' AS activity_name,
    sta.usage AS context_type,
    COUNT(DISTINCT sta.statement_id) AS statement_count
FROM statement_to_activity sta
JOIN activity a ON a.activity_iri = sta.activity_iri
GROUP BY a.activity_iri, a.payload->>'name', sta.usage
ORDER BY statement_count DESC
")
echo "  Activity objects dataset: $DS_OBJECTS"

# Helper to create a chart
create_chart() {
  local name="$1"
  local ds_id="$2"
  local viz_type="$3"
  local params="$4"
  local result
  result=$(curl -sf -X POST "$SUPERSET_URL/api/v1/chart/" \
    -H "$AUTH" \
    -H "X-CSRFToken: $CSRF" \
    -H "Content-Type: application/json" \
    -H "Referer: $SUPERSET_URL" \
    -d "$(python3 -c "
import json
print(json.dumps({
    'slice_name': '$name',
    'datasource_id': $ds_id,
    'datasource_type': 'table',
    'viz_type': '$viz_type',
    'params': json.dumps($params),
}))
")")
  echo "$result" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])'
}

echo "Creating charts..."

CHART_PIE=$(create_chart "xAPI Verb Distribution" "$DS_VERBS" "pie" '{
  "viz_type": "pie",
  "groupby": ["verb"],
  "metric": {"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"},
  "row_limit": 20,
  "sort_by_metric": true,
  "color_scheme": "supersetColors",
  "show_labels": true,
  "label_type": "key_percent"
}')
echo "  Verb distribution pie: $CHART_PIE"

CHART_BAR=$(create_chart "xAPI Verb Counts" "$DS_VERBS" "dist_bar" '{
  "viz_type": "dist_bar",
  "groupby": ["verb"],
  "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
  "row_limit": 20,
  "order_desc": true,
  "color_scheme": "supersetColors",
  "show_legend": false,
  "x_axis_label": "Verb",
  "y_axis_label": "Count"
}')
echo "  Verb counts bar: $CHART_BAR"

CHART_TIMELINE=$(create_chart "xAPI Activity Over Time" "$DS_TIMELINE" "echarts_timeseries_line" '{
  "viz_type": "echarts_timeseries_line",
  "x_axis": "time_bucket",
  "metrics": [{"label": "statement_count", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
  "groupby": ["verb"],
  "row_limit": 10000,
  "color_scheme": "supersetColors",
  "show_legend": true,
  "rich_tooltip": true
}')
echo "  Activity timeline: $CHART_TIMELINE"

CHART_LEARNERS=$(create_chart "Top Learners by Activity" "$DS_LEARNERS" "table" '{
  "viz_type": "table",
  "query_mode": "aggregate",
  "groupby": ["learner_name"],
  "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
  "order_desc": true,
  "row_limit": 50
}')
echo "  Top learners table: $CHART_LEARNERS"

CHART_OBJECTS=$(create_chart "Most Active Learning Objects" "$DS_OBJECTS" "table" '{
  "viz_type": "table",
  "query_mode": "aggregate",
  "groupby": ["activity_iri", "activity_name"],
  "metrics": [{"label": "total_statements", "expressionType": "SQL", "sqlExpression": "SUM(statement_count)"}],
  "order_desc": true,
  "row_limit": 50
}')
echo "  Learning objects table: $CHART_OBJECTS"

# Create dashboard
echo "Creating dashboard..."

POSITION_JSON=$(python3 -c "
import json
charts = [
    ($CHART_PIE, 'xAPI Verb Distribution', 6),
    ($CHART_BAR, 'xAPI Verb Counts', 6),
    ($CHART_TIMELINE, 'xAPI Activity Over Time', 12),
    ($CHART_LEARNERS, 'Top Learners by Activity', 6),
    ($CHART_OBJECTS, 'Most Active Learning Objects', 6),
]
pos = {
    'DASHBOARD_VERSION_KEY': 'v2',
    'ROOT_ID': {'type': 'ROOT', 'id': 'ROOT_ID', 'children': ['GRID_ID']},
    'GRID_ID': {'type': 'GRID', 'id': 'GRID_ID', 'children': ['ROW-1', 'ROW-2', 'ROW-3'], 'parents': ['ROOT_ID']},
    'HEADER_ID': {'type': 'HEADER', 'id': 'HEADER_ID', 'meta': {'text': 'xAPI Learning Analytics'}},
}
rows = [['ROW-1', [0, 1]], ['ROW-2', [2]], ['ROW-3', [3, 4]]]
for row_id, chart_indices in rows:
    children = [f'CHART-{i+1}' for i in chart_indices]
    pos[row_id] = {'type': 'ROW', 'id': row_id, 'children': children, 'parents': ['ROOT_ID', 'GRID_ID'], 'meta': {'background': 'BACKGROUND_TRANSPARENT'}}

for i, (chart_id, name, width) in enumerate(charts):
    cid = f'CHART-{i+1}'
    row = 'ROW-1' if i < 2 else ('ROW-2' if i == 2 else 'ROW-3')
    pos[cid] = {'type': 'CHART', 'id': cid, 'children': [], 'parents': ['ROOT_ID', 'GRID_ID', row], 'meta': {'chartId': chart_id, 'width': width, 'height': 50, 'sliceName': name}}

print(json.dumps(pos))
")

DASH_RESULT=$(curl -sf -X POST "$SUPERSET_URL/api/v1/dashboard/" \
  -H "$AUTH" \
  -H "X-CSRFToken: $CSRF" \
  -H "Content-Type: application/json" \
  -H "Referer: $SUPERSET_URL" \
  -d "$(python3 -c "
import json, sys
pos = json.loads('''$POSITION_JSON''')
print(json.dumps({
    'dashboard_title': 'xAPI Learning Analytics',
    'slug': 'xapi-analytics',
    'published': True,
    'position_json': json.dumps(pos),
}))
")")

DASH_ID=$(echo "$DASH_RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
echo "Created dashboard ID: $DASH_ID"

# PUT to sync dashboard-chart relationships (POST doesn't populate dashboard_slices)
curl -sf -X PUT "$SUPERSET_URL/api/v1/dashboard/$DASH_ID" \
  -H "$AUTH" \
  -H "X-CSRFToken: $CSRF" \
  -H "Content-Type: application/json" \
  -H "Referer: $SUPERSET_URL" \
  -d "$(python3 -c "
import json
pos = json.loads('''$POSITION_JSON''')
print(json.dumps({
    'position_json': json.dumps(pos),
    'json_metadata': json.dumps({
        'default_filters': '{}',
        'expanded_slices': {},
        'refresh_frequency': 0,
        'timed_refresh_immune_slices': [],
        'color_scheme': 'supersetColors',
    }),
}))
")" > /dev/null

echo "Dashboard URL: $SUPERSET_URL/superset/dashboard/xapi-analytics/"
echo "Done!"
