#!/usr/bin/env bash
# Nightly refresh of the anonymized analytics copy (Scalingo Scheduler, dedicated web-less app
# mobilic-analytics that owns the copy addon; Metabase connects to it via that addon's connection URI).
# ANALYTICS_DATABASE_URL must point to the COPY, never to a metadata database (a pg_restore
# --clean would otherwise destroy the target).
# Requirements: postgresql-client (PG >= prod) + scalingo CLI in the container, masking_rules.sql
# alongside, read-only Metabase user already created on the copy.
set -euo pipefail

readonly PROD_APP="mobilic-api"
readonly PROD_ADDON="ad-5a4c2adf-3cfc-4ee6-8ebf-e52a0558ac12"
readonly RULES="$(dirname "$0")/masking_rules.sql"
readonly DOWNLOAD_TIMEOUT="1h"

log()       { echo ">>> $*"; }
psql_admin() { psql "$ANALYTICS_DATABASE_URL" -v ON_ERROR_STOP=1 "$@"; }

require_env() {
  : "${ANALYTICS_DATABASE_URL:?ANALYTICS_DATABASE_URL missing}"
  : "${SCALINGO_API_TOKEN:?SCALINGO_API_TOKEN missing}"
  : "${METABASE_DB_USER:?METABASE_DB_USER missing}"
}

lock_metabase() {
  psql_admin -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM \"$METABASE_DB_USER\";
                 ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON SEQUENCES FROM \"$METABASE_DB_USER\";
                 REVOKE SELECT ON ALL TABLES IN SCHEMA public FROM \"$METABASE_DB_USER\";
                 REVOKE SELECT ON ALL SEQUENCES IN SCHEMA public FROM \"$METABASE_DB_USER\";"
}

unlock_metabase() {
  psql_admin -c "GRANT USAGE ON SCHEMA public TO \"$METABASE_DB_USER\";
                 GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"$METABASE_DB_USER\";
                 GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO \"$METABASE_DB_USER\";
                 ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO \"$METABASE_DB_USER\";
                 ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO \"$METABASE_DB_USER\";"
}

download_backup() {
  timeout "$DOWNLOAD_TIMEOUT" \
    scalingo --app "$PROD_APP" --addon "$PROD_ADDON" backups-download --output "$1"
}

assert_restore_populated() {
  local users
  users="$(psql_admin -tAc 'SELECT count(*) FROM "user";')"
  if [[ "${users// /}" == "0" ]]; then
    echo "ALERT: empty restore (0 user) -> corrupt/stale backup? failing (Metabase access left locked)" >&2
    exit 1
  fi
}

restore_stream() {
  tar -xzOf "$1" --wildcards '*.pgsql' \
    | pg_restore --clean --if-exists --no-owner --no-privileges \
        --single-transaction -d "$ANALYTICS_DATABASE_URL"
}

apply_masking() {
  psql_admin -c "CREATE EXTENSION IF NOT EXISTS anon;"
  psql_admin -f "$RULES"
  psql_admin -c "SELECT anon.anonymize_database();"
}

assert_no_unmasked_pii() {
  local left
  left="$(psql "$ANALYTICS_DATABASE_URL" -tAc "
    SELECT count(*)
    FROM anon.detect('fr_FR') d
    LEFT JOIN anon.all_rules r
      ON r.table_name = d.table_name AND r.column_name = d.column_name
    WHERE r.column_name IS NULL;")"
  if [[ "${left// /}" != "0" ]]; then
    echo "ALERT: $left PII column(s) without a masking rule -> failing (Metabase access left locked)" >&2
    exit 1
  fi
}

main() {
  require_env
  local work; work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
  export PGOPTIONS="-c synchronous_commit=off -c maintenance_work_mem=512MB -c lock_timeout=300000"

  log "Scalingo auth";           scalingo login --api-token "$SCALINGO_API_TOKEN" >/dev/null
  log "Download backup";         download_backup "$work/prod.tar.gz"
  log "Lock Metabase access";    lock_metabase
  log "Streaming restore";       restore_stream "$work/prod.tar.gz"
  log "Check restore populated"; assert_restore_populated
  log "Masking";                 apply_masking
  log "Guard anon.detect";       assert_no_unmasked_pii
  log "Unlock Metabase access";  unlock_metabase
  log "OK: masked copy up to date ($(date -u))"
}

main "$@"
