#!/usr/bin/env bash
set -euo pipefail
# Requires hey, running API and 100K seeded products. Run twice with identical URL:
# 1. Redis enabled, 2. Redis disabled (DB fallback), then compare the output files.
BASE_URL="${BASE_URL:-http://localhost:3000}"
REQUESTS="${REQUESTS:-2000}"
CONCURRENCY="${CONCURRENCY:-20}"
LABEL="${LABEL:-cached}"
OUT="${OUT:-catalog-results}"
mkdir -p "$OUT"
URL="${BASE_URL}/api/products?page=1&limit=20"
for i in $(seq 1 20); do curl -fsS "$URL" >/dev/null; done
hey -n "$REQUESTS" -c "$CONCURRENCY" "$URL" | tee "$OUT/$LABEL.txt"
echo "Saved $OUT/$LABEL.txt; compare req/s and P95 against the other mode."
