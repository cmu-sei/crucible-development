# Apache Superset Integration

Apache Superset provides business intelligence and data visualization for xAPI learning analytics data stored in LRsql.

## Architecture

- **Superset container** runs on port 8088 with a custom Dockerfile (`Dockerfile.SupersetCustom`) that adds PostgreSQL and OAuth dependencies
- **PostgreSQL** stores Superset's own metadata in a `superset` database
- **LRsql database** is auto-registered as a data source on startup
- **Keycloak** provides OAuth SSO authentication

## Configuration Files

| File | Purpose |
|------|---------|
| `Dockerfile.SupersetCustom` | Custom image with psycopg2-binary and authlib |
| `superset_config.py` | Superset configuration (OAuth, cache, security) |
| `init-superset.sh` | Startup script: migrations, admin user, LRsql registration, dashboard creation |
| `create-dashboard-orm.py` | Creates the starter xAPI analytics dashboard using Superset's internal ORM |
| `create-dashboard.py` | Alternative: REST API-based dashboard creation (Python) |
| `create-dashboard.js` | Alternative: REST API-based dashboard creation (Node.js) |
| `create-dashboard.sh` | Alternative: REST API-based dashboard creation (bash) |

## Starter Dashboard

The `xAPI Learning Analytics` dashboard is automatically created on first startup with 7 charts:

1. **Activity by Client App** (pie) - Statement distribution across Crucible apps (Blueprint, CITE, Gallery, Steamfitter, etc.)
2. **Client App Verb Breakdown** (stacked bar) - Which verbs each app generates
3. **xAPI Verb Distribution** (pie) - Overall verb frequency
4. **xAPI Verb Counts** (bar) - Verb counts ranked
5. **xAPI Activity Over Time** (timeline) - Statement volume over time by verb
6. **Top Learners by Activity** (table) - Most active learners
7. **Most Active Learning Objects** (table) - Most referenced activity IRIs

## Authentication

- **Local admin**: `admin` / `admin` (created on startup)
- **Keycloak SSO**: Click the Keycloak login option on the login page

## Accessing Superset

- Dashboard URL: http://localhost:8088/superset/dashboard/xapi-analytics/
- SQL Lab: http://localhost:8088/sqllab/ (query LRsql data directly)

## xAPI Data Model

The LRsql database uses these key tables for analytics:

| Table | Purpose |
|-------|---------|
| `xapi_statement` | Core xAPI statements with verb_iri, timestamp, JSON payload |
| `statement_to_actor` | Links statements to actors (Actor, Team, Authority) |
| `statement_to_activity` | Links statements to activities (Object, context) |
| `activity` | Activity definitions with IRI and JSON payload |
| `actor` | Actor definitions |

### Client App Detection

Client applications are identified by port number in activity IRIs:

| Port | Application |
|------|-------------|
| 4724 | Blueprint |
| 4720, 4721 | CITE |
| 4722, 4723 | Gallery |
| 4300, 4301 | Player |
| 4400, 4401 | Steamfitter |
| 4403 | Alloy |
| 4310 | Caster |
| 5000 | TopoMojo |
| 8081 | Moodle |

### Cross-App Correlation

Activities across multiple Crucible apps can be correlated using:

- **Registration ID** (`registration` column) - UUID linking statements from a single exercise execution
- **Context Activities** (`context.contextActivities.grouping` in payload) - Shared MSEL/exercise activity IRI

For full cross-app correlation, orchestrators (Alloy, Blueprint) should pass a shared registration UUID to all downstream apps when launching exercises.
