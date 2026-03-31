const fetch = require('node-fetch');
const BASE = process.argv[2] || 'http://localhost:8088';

let sessionCookie = '';
let csrfToken = '';
let authToken = '';

async function api(method, path, body) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${authToken}`,
    'X-CSRFToken': csrfToken,
    'Referer': BASE,
    'Cookie': sessionCookie,
  };
  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(`${BASE}${path}`, opts);
  // Capture session cookies
  const cookies = r.headers.raw()['set-cookie'];
  if (cookies) {
    sessionCookie = cookies.map(c => c.split(';')[0]).join('; ');
  }
  const text = await r.text();
  try { return { status: r.status, data: JSON.parse(text) }; }
  catch { return { status: r.status, data: text }; }
}

async function main() {
  // Login
  let r = await api('POST', '/api/v1/security/login', {
    username: 'admin', password: 'admin', provider: 'db', refresh: true
  });
  authToken = r.data.access_token;

  // Get CSRF
  r = await api('GET', '/api/v1/security/csrf_token/');
  csrfToken = r.data.result;

  // Check existing dashboard
  r = await api('GET', '/api/v1/dashboard/?q=' + encodeURIComponent(JSON.stringify({
    filters: [{ col: 'slug', opr: 'eq', value: 'xapi-analytics' }]
  })));
  if (r.data.count > 0) { console.log('Dashboard already exists'); return; }

  // Get DB ID
  r = await api('GET', '/api/v1/database/');
  const dbId = r.data.result.find(d => d.database_name.includes('LRsql')).id;
  console.log(`LRsql database ID: ${dbId}`);

  // Create datasets
  async function createDataset(name, sql) {
    const r = await api('POST', '/api/v1/dataset/', { database: dbId, schema: 'public', table_name: name, sql });
    if (r.status >= 300) { console.log(`  ERROR ${name}: ${r.status}`, JSON.stringify(r.data).slice(0, 200)); return null; }
    console.log(`  Dataset '${name}': ${r.data.id}`);
    return r.data.id;
  }

  console.log('Creating datasets...');
  const dsVerbs = await createDataset('xapi_verb_frequency', `
    SELECT REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
      verb_iri, COUNT(*) AS statement_count
    FROM xapi_statement WHERE NOT is_voided GROUP BY verb_iri ORDER BY statement_count DESC`);

  const dsTimeline = await createDataset('xapi_activity_timeline', `
    SELECT DATE_TRUNC('hour', timestamp) AS time_bucket,
      REPLACE(REPLACE(verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
      COUNT(*) AS statement_count
    FROM xapi_statement WHERE NOT is_voided AND timestamp IS NOT NULL
    GROUP BY time_bucket, verb_iri ORDER BY time_bucket`);

  const dsLearners = await createDataset('xapi_learner_activity', `
    SELECT s.payload->'actor'->>'name' AS learner_name, sta.actor_ifi AS learner_id,
      REPLACE(REPLACE(s.verb_iri, 'http://adlnet.gov/expapi/verbs/', ''), 'https://w3id.org/xapi/dod-isd/verbs/', '') AS verb,
      COUNT(*) AS statement_count, MIN(s.timestamp) AS first_activity, MAX(s.timestamp) AS last_activity
    FROM xapi_statement s JOIN statement_to_actor sta ON sta.statement_id = s.statement_id AND sta.usage = 'Actor'
    WHERE NOT s.is_voided GROUP BY learner_name, learner_id, s.verb_iri ORDER BY statement_count DESC`);

  const dsObjects = await createDataset('xapi_activity_objects', `
    SELECT a.activity_iri, a.payload->>'name' AS activity_name, sta.usage AS context_type,
      COUNT(DISTINCT sta.statement_id) AS statement_count
    FROM statement_to_activity sta JOIN activity a ON a.activity_iri = sta.activity_iri
    GROUP BY a.activity_iri, a.payload->>'name', sta.usage ORDER BY statement_count DESC`);

  if (!dsVerbs || !dsTimeline || !dsLearners || !dsObjects) { console.log('Some datasets failed'); process.exit(1); }

  // Create charts
  async function createChart(name, dsId, vizType, params) {
    const r = await api('POST', '/api/v1/chart/', {
      slice_name: name, datasource_id: dsId, datasource_type: 'table', viz_type: vizType, params: JSON.stringify(params)
    });
    if (r.status >= 300) { console.log(`  ERROR chart '${name}': ${r.status}`, JSON.stringify(r.data).slice(0, 200)); return null; }
    console.log(`  Chart '${name}': ${r.data.id}`);
    return r.data.id;
  }

  console.log('Creating charts...');
  const cPie = await createChart('xAPI Verb Distribution', dsVerbs, 'pie', {
    viz_type: 'pie', groupby: ['verb'],
    metric: { label: 'statement_count', expressionType: 'SQL', sqlExpression: 'SUM(statement_count)' },
    row_limit: 20, sort_by_metric: true, color_scheme: 'supersetColors', show_labels: true, label_type: 'key_percent',
  });

  const cBar = await createChart('xAPI Verb Counts', dsVerbs, 'dist_bar', {
    viz_type: 'dist_bar', groupby: ['verb'],
    metrics: [{ label: 'statement_count', expressionType: 'SQL', sqlExpression: 'SUM(statement_count)' }],
    row_limit: 20, order_desc: true, color_scheme: 'supersetColors',
  });

  const cTimeline = await createChart('xAPI Activity Over Time', dsTimeline, 'echarts_timeseries_line', {
    viz_type: 'echarts_timeseries_line', x_axis: 'time_bucket',
    metrics: [{ label: 'statement_count', expressionType: 'SQL', sqlExpression: 'SUM(statement_count)' }],
    groupby: ['verb'], row_limit: 10000, color_scheme: 'supersetColors', show_legend: true, rich_tooltip: true,
  });

  const cLearners = await createChart('Top Learners by Activity', dsLearners, 'table', {
    viz_type: 'table', query_mode: 'aggregate', groupby: ['learner_name'],
    metrics: [{ label: 'total_statements', expressionType: 'SQL', sqlExpression: 'SUM(statement_count)' }],
    order_desc: true, row_limit: 50,
  });

  const cObjects = await createChart('Most Active Learning Objects', dsObjects, 'table', {
    viz_type: 'table', query_mode: 'aggregate', groupby: ['activity_iri', 'activity_name'],
    metrics: [{ label: 'total_statements', expressionType: 'SQL', sqlExpression: 'SUM(statement_count)' }],
    order_desc: true, row_limit: 50,
  });

  const charts = [cPie, cBar, cTimeline, cLearners, cObjects];
  if (charts.some(c => !c)) { console.log('Some charts failed'); process.exit(1); }

  // Build dashboard layout
  const chartInfo = [
    [cPie, 'xAPI Verb Distribution', 6, 'ROW-1'],
    [cBar, 'xAPI Verb Counts', 6, 'ROW-1'],
    [cTimeline, 'xAPI Activity Over Time', 12, 'ROW-2'],
    [cLearners, 'Top Learners by Activity', 6, 'ROW-3'],
    [cObjects, 'Most Active Learning Objects', 6, 'ROW-3'],
  ];

  const positions = {
    DASHBOARD_VERSION_KEY: 'v2',
    ROOT_ID: { type: 'ROOT', id: 'ROOT_ID', children: ['GRID_ID'] },
    GRID_ID: { type: 'GRID', id: 'GRID_ID', children: ['ROW-1', 'ROW-2', 'ROW-3'], parents: ['ROOT_ID'] },
    HEADER_ID: { type: 'HEADER', id: 'HEADER_ID', meta: { text: 'xAPI Learning Analytics' } },
  };

  for (const rowId of ['ROW-1', 'ROW-2', 'ROW-3']) {
    const children = chartInfo.filter(([,,, r]) => r === rowId).map(([,,, r], j) => {
      const idx = chartInfo.findIndex(ci => ci === chartInfo.filter(([,,, rr]) => rr === rowId)[j]);
      return `CHART-${idx + 1}`;
    });
    positions[rowId] = { type: 'ROW', id: rowId, children, parents: ['ROOT_ID', 'GRID_ID'], meta: { background: 'BACKGROUND_TRANSPARENT' } };
  }

  chartInfo.forEach(([cid, name, width, row], i) => {
    positions[`CHART-${i + 1}`] = {
      type: 'CHART', id: `CHART-${i + 1}`, children: [],
      parents: ['ROOT_ID', 'GRID_ID', row],
      meta: { chartId: cid, width, height: 50, sliceName: name },
    };
  });

  console.log('Creating dashboard...');
  r = await api('POST', '/api/v1/dashboard/', {
    dashboard_title: 'xAPI Learning Analytics',
    slug: 'xapi-analytics',
    published: true,
    position_json: JSON.stringify(positions),
  });

  if (r.status >= 300) {
    console.log(`ERROR: ${r.status}`, JSON.stringify(r.data).slice(0, 300));
    process.exit(1);
  }

  const dashId = r.data.id;
  console.log(`Dashboard ID: ${dashId}`);

  // PUT to sync dashboard-chart relationships (POST doesn't populate dashboard_slices)
  r = await api('PUT', `/api/v1/dashboard/${dashId}`, {
    position_json: JSON.stringify(positions),
    json_metadata: JSON.stringify({
      default_filters: '{}',
      expanded_slices: {},
      refresh_frequency: 0,
      timed_refresh_immune_slices: [],
      color_scheme: 'supersetColors',
    }),
  });
  if (r.status >= 300) {
    console.log(`WARNING: PUT to sync charts failed: ${r.status}`, JSON.stringify(r.data).slice(0, 200));
  }

  console.log(`Dashboard: ${BASE}/superset/dashboard/xapi-analytics/`);
}

main().catch(e => { console.error(e); process.exit(1); });
