#!/bin/bash
# Database connection monitoring script for Crucible PostgreSQL

set -e

CONTAINER="crucible-postgres"
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"
COLOR_CYAN="\033[0;36m"

# Function to run psql commands in the container
run_query() {
    docker exec "$CONTAINER" bash -c "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -d postgres -c \"$1\""
}

echo -e "${COLOR_BLUE}======================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}  Crucible Database Connection Stats${COLOR_RESET}"
echo -e "${COLOR_BLUE}  $(date)${COLOR_RESET}"
echo -e "${COLOR_BLUE}======================================${COLOR_RESET}"
echo

# Overall connection stats
echo -e "${COLOR_CYAN}📊 Overall Connection Status:${COLOR_RESET}"
run_query "
SELECT
    count(*) as total_connections,
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') as max_connections,
    round(100.0 * count(*) / (SELECT setting::int FROM pg_settings WHERE name = 'max_connections'), 1) as percent_used
FROM pg_stat_activity;
"
echo

# Connections by database
echo -e "${COLOR_CYAN}🗄️  Connections by Database:${COLOR_RESET}"
run_query "
SELECT
    COALESCE(datname, '<system>') as database,
    count(*) as connections,
    round(avg(EXTRACT(EPOCH FROM (now() - backend_start))), 1) as avg_age_seconds
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC, database;
"
echo

# Connections by state
echo -e "${COLOR_CYAN}🔄 Connections by State:${COLOR_RESET}"
run_query "
SELECT
    COALESCE(datname, '<system>') as database,
    state,
    count(*) as count
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname, state
ORDER BY datname, count DESC;
"
echo

# Active queries (non-idle)
echo -e "${COLOR_CYAN}⚡ Active Queries (non-idle):${COLOR_RESET}"
ACTIVE_COUNT=$(docker exec "$CONTAINER" bash -c "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -d postgres -t -c \"SELECT count(*) FROM pg_stat_activity WHERE state <> 'idle' AND pid <> pg_backend_pid();\"" | xargs)

if [ "$ACTIVE_COUNT" -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ No active queries (all connections idle)${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}⚠️  $ACTIVE_COUNT active queries:${COLOR_RESET}"
    run_query "
    SELECT
        pid,
        datname,
        usename,
        state,
        EXTRACT(EPOCH FROM (now() - query_start))::int as query_duration_sec,
        LEFT(query, 100) as query_preview
    FROM pg_stat_activity
    WHERE state <> 'idle'
      AND pid <> pg_backend_pid()
    ORDER BY query_start;
    "
fi
echo

# Blocked queries
echo -e "${COLOR_CYAN}🔒 Blocked Queries:${COLOR_RESET}"
BLOCKED_COUNT=$(docker exec "$CONTAINER" bash -c "PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -d postgres -t -c \"
SELECT COUNT(*)
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
WHERE NOT blocked_locks.granted;
\"" | xargs)

if [ "$BLOCKED_COUNT" -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ No blocked queries${COLOR_RESET}"
else
    echo -e "${COLOR_RED}⚠️  $BLOCKED_COUNT blocked queries detected!${COLOR_RESET}"
    run_query "
    SELECT
        blocked_locks.pid AS blocked_pid,
        blocked_activity.usename AS blocked_user,
        blocked_activity.datname AS blocked_db,
        blocking_locks.pid AS blocking_pid,
        blocking_activity.usename AS blocking_user
    FROM pg_catalog.pg_locks blocked_locks
    JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
    JOIN pg_catalog.pg_locks blocking_locks
        ON blocking_locks.locktype = blocked_locks.locktype
        AND blocking_locks.pid <> blocked_locks.pid
    JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
    WHERE NOT blocked_locks.granted
    LIMIT 10;
    "
fi
echo

# Database sizes
echo -e "${COLOR_CYAN}💾 Database Sizes:${COLOR_RESET}"
run_query "
SELECT
    datname as database,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
WHERE datname IN (
    'player', 'player_vm', 'player_vm_logging', 'caster', 'alloy',
    'steamfitter', 'cite', 'gallery', 'blueprint', 'gameboard',
    'topomojo', 'keycloak', 'moodle', 'lrsql'
)
ORDER BY pg_database_size(datname) DESC;
"
echo

# Connection age summary
echo -e "${COLOR_CYAN}⏱️  Connection Age Summary:${COLOR_RESET}"
run_query "
SELECT
    COALESCE(datname, '<system>') as database,
    count(*) as connections,
    to_char(max(now() - backend_start), 'HH24:MI:SS') as oldest,
    to_char(min(now() - backend_start), 'HH24:MI:SS') as newest
FROM pg_stat_activity
GROUP BY datname
HAVING count(*) > 0
ORDER BY count(*) DESC;
"

echo
echo -e "${COLOR_BLUE}======================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}✓ Check complete${COLOR_RESET}"
echo -e "${COLOR_BLUE}======================================${COLOR_RESET}"
