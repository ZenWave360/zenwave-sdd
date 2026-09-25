#!/usr/bin/env bash
# Export the DDL Hibernate runs for a Spring Boot + JPA project, without changing the project's config.
#
# It boots one Spring test (a repository integration test, which ZenWave generates for every JPA
# entity) with JPA schema-generation settings passed as -D system properties. Surefire forwards them
# to the test JVM, and Spring Boot gives them precedence over application-*.yml.
# The script is written while the EntityManagerFactory starts, before data.sql runs, so it works even
# when data.sql is empty or broken; a test failure after that point doesn't matter.
#
# Usage (from the project root):
#   export-ddl.sh [-t <TestClass>] [-o <output.sql>] [-- <extra maven args>]
#     -t  test class to boot (default: the first *RepositoryIntegrationTest found under src/test)
#     -o  output file (default: target/ddl/schema.sql)
#   e.g. export-ddl.sh -- -o            # pass -o (offline) to maven
set -euo pipefail

TEST=""
OUT="target/ddl/schema.sql"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -t) TEST="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TEST" ]]; then
  f=$(find src/test -name '*RepositoryIntegrationTest.*' 2>/dev/null | sort | head -1)
  [[ -n "$f" ]] || { echo "no *RepositoryIntegrationTest found under src/test; pass -t <TestClass>" >&2; exit 2; }
  TEST=$(basename "${f%.*}")
fi

mkdir -p target "$(dirname "$OUT")"
rm -f "$OUT"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
P=spring.jpa.properties

echo "Booting $TEST to export the DDL to $OUT ..."
set +e
mvn -Dtest="$TEST" -Dsurefire.failIfNoSpecifiedTests=false \
  -D$P.jakarta.persistence.schema-generation.database.action=drop-and-create \
  -D$P.jakarta.persistence.schema-generation.scripts.action=create \
  "-D$P.jakarta.persistence.schema-generation.scripts.create-target=$OUT_ABS" \
  -D$P.hibernate.hbm2ddl.schema-generation.script.append=false \
  "-D$P.hibernate.hbm2ddl.delimiter=;" \
  -D$P.hibernate.format_sql=true \
  "$@" test > target/export-ddl.log 2>&1
MVN_EXIT=$?
set -e

if [[ -s "$OUT" ]]; then
  echo "DDL written to $OUT ($(grep -c 'create table' "$OUT") tables). Maven exit code: $MVN_EXIT (a test failure after boot is fine)."
else
  echo "No DDL was written: the Spring context failed before Hibernate started. See target/export-ddl.log:" >&2
  grep -m5 'Caused by\|ERROR\]' target/export-ddl.log >&2 || true
  exit 1
fi
