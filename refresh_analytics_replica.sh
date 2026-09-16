#!/usr/bin/env bash
set -euo pipefail

readonly PROD_APP="mobilic-api"
RULES="$(dirname "$0")/masking_rules.sql"; readonly RULES
readonly DOWNLOAD_TIMEOUT="1h"

log()       { echo ">>> $*"; }
psql_admin() { psql "$ANALYTICS_DATABASE_URL" -v ON_ERROR_STOP=1 "$@"; }

sentry_checkin() {
  [ -n "${SENTRY_CRONS_URL:-}" ] || return 0
  curl -fsS -m 10 "${SENTRY_CRONS_URL}?status=$1" >/dev/null 2>&1 || true
}

cleanup() {
  local code=$?
  [ -n "${work:-}" ] && rm -rf "$work"
  [ "$code" -ne 0 ] && sentry_checkin error
}

ensure_scalingo_cli() {
  command -v scalingo >/dev/null && return
  install-scalingo-cli || curl -sSL https://cli-dl.scalingo.com/install | bash
}

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
  local addon
  addon="$(scalingo --app "$PROD_APP" addons \
    | awk 'tolower($0) ~ /postgresql/ && match($0, /ad-[-0-9a-f]+/) { print substr($0, RSTART, RLENGTH); exit }')"
  : "${addon:?could not resolve the PostgreSQL addon of $PROD_APP}"
  timeout "$DOWNLOAD_TIMEOUT" \
    scalingo --app "$PROD_APP" --addon "$addon" backups-download --output "$1"
}

assert_restore_populated() {
  local users
  users="$(psql_admin -tAc 'SELECT count(*) FROM "user";')"
  if [[ "${users// /}" == "0" ]]; then
    echo "ALERT: empty restore (0 user) -> corrupt/stale backup? failing (Metabase access left locked)" >&2
    exit 1
  fi
}

readonly_toc() {
  local dump="$1" names
  names="$(pg_restore -f - --section=post-data "$dump" 2>/dev/null \
    | grep -oE 'ADD CONSTRAINT [^ ]+ (FOREIGN KEY|UNIQUE|EXCLUDE|CHECK)' \
    | awk '{print $3}' | sort -u)"
  if [ -n "$names" ]; then
    pg_restore -l "$dump" | grep -vwF -f <(printf '%s\n' "$names")
  else
    pg_restore -l "$dump"
  fi
}

restore_dump() {
  local dump toc; dump="$(dirname "$1")/dump.pgsql"; toc="$(dirname "$1")/toc.keep"
  tar -xzOf "$1" --wildcards '*.pgsql' > "$dump"
  [ -s "$dump" ] || { echo "ERROR: empty dump extracted from $1" >&2; exit 1; }
  readonly_toc "$dump" > "$toc"
  pg_restore -L "$toc" --clean --if-exists --no-owner --no-privileges \
    --jobs 4 -d "$ANALYTICS_DATABASE_URL" "$dump" \
    || log "pg_restore reported ignored errors (non-fatal), continuing"
}

apply_masking() {
  psql_admin -c "CREATE EXTENSION IF NOT EXISTS anon;"
  psql_admin -f "$RULES"
  psql_admin <<'SQL'
DO $$
DECLARE r record; expr text;
BEGIN
  FOR r IN
    SELECT c.oid::regclass::text AS tbl, a.attname AS col, sl.label
    FROM pg_seclabel sl
    JOIN pg_class c     ON c.oid = sl.objoid
    JOIN pg_attribute a ON a.attrelid = sl.objoid AND a.attnum = sl.objsubid
    WHERE sl.provider = 'anon' AND sl.label LIKE 'MASKED WITH %'
  LOOP
    expr := CASE
      WHEN r.label LIKE 'MASKED WITH FUNCTION %' THEN substring(r.label FROM 'MASKED WITH FUNCTION (.*)')
      WHEN r.label LIKE 'MASKED WITH VALUE %'    THEN substring(r.label FROM 'MASKED WITH VALUE (.*)')
    END;
    IF expr IS NULL THEN
      RAISE EXCEPTION 'unsupported anon label on %.%: %', r.tbl, r.col, r.label;
    END IF;
    EXECUTE format('UPDATE %s SET %I = %s WHERE %I IS NOT NULL', r.tbl, r.col, expr, r.col);
  END LOOP;
END $$;
SQL
}

assert_no_unmasked_pii() {
  local left
  left="$(psql "$ANALYTICS_DATABASE_URL" -tAc "
    SELECT count(*)
    FROM anon.detect('fr_FR') d
    JOIN pg_class c     ON c.oid = d.table_name
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = d.column_name AND a.attnum > 0
    LEFT JOIN pg_seclabel sl
           ON sl.classoid = 'pg_class'::regclass
          AND sl.objoid   = a.attrelid
          AND sl.objsubid = a.attnum
          AND sl.provider = 'anon'
    WHERE c.relkind = 'r'
      AND n.nspname = 'public'
      AND c.relname NOT LIKE 'anon\_%'
      AND d.identifiers_category <> 'account_id'
      AND NOT (c.relname = 'company' AND a.attname = 'siren')
      AND sl.objoid IS NULL;")"
  if [[ "${left// /}" != "0" ]]; then
    echo "ALERT: $left PII column(s) without a masking rule -> failing (Metabase access left locked)" >&2
    exit 1
  fi

  local leaked
  leaked="$(psql_admin -tAc "SELECT count(*) FROM \"user\" WHERE email LIKE '%@%';")"
  if [[ "${leaked// /}" != "0" ]]; then
    echo "ALERT: $leaked user.email still look unmasked -> masking did not run, failing (Metabase access left locked)" >&2
    exit 1
  fi
}

main() {
  require_env
  work="$(mktemp -d)"
  sentry_checkin in_progress
  trap cleanup EXIT
  export PGOPTIONS="-c synchronous_commit=off -c maintenance_work_mem=512MB -c lock_timeout=300000"

  log "Ensure Scalingo CLI";     ensure_scalingo_cli
  log "Scalingo auth";           scalingo login --api-token "$SCALINGO_API_TOKEN" >/dev/null
  log "Download backup";         download_backup "$work/prod.tar.gz"
  log "Lock Metabase access";    lock_metabase
  log "Parallel restore";        restore_dump "$work/prod.tar.gz"
  log "Check restore populated"; assert_restore_populated
  log "Masking";                 apply_masking
  log "Guard anon.detect";       assert_no_unmasked_pii
  log "Unlock Metabase access";  unlock_metabase
  log "OK: masked copy up to date ($(date -u))"
  sentry_checkin ok
}

usage() {
  cat <<EOF
usage: $(basename "$0") [command]

  refresh   full nightly cycle (default): download, restore, mask, guard, unlock
  lock      revoke Metabase read access on the copy
  unlock    restore Metabase read access (recovery when a failed run left it locked)
  mask      (re)apply masking rules and mask populated rows
  guard     assert no unmasked PII remains
EOF
}

case "${1:-refresh}" in
  refresh) main ;;
  lock)    require_env; lock_metabase ;;
  unlock)  require_env; unlock_metabase ;;
  mask)    require_env; apply_masking ;;
  guard)   require_env; assert_no_unmasked_pii ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
