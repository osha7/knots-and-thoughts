#!/usr/bin/env bash
# Total the time recorded in docs/BUILD-LOG.md.
#
# BUILD-LOG is the single source of truth. This total is computed on demand and
# never written anywhere, so it cannot drift out of sync with the entries.
#
# Expected line format, one per session entry:
#   **Time:** 1.5h · 2026-08-11 17:00-18:30 CDT · Phase 0
#
# Only the leading `N.Nh` and an optional `Phase N` are parsed; everything else
# on the line is for humans.

set -euo pipefail

log="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docs/BUILD-LOG.md"

if [[ ! -f $log ]]; then
  echo "time-report: no such file: $log" >&2
  exit 1
fi

# Emit one `phase<TAB>hours` record per session entry, so both passes below can
# be plain aggregations rather than parsing markdown twice.
#
# Lines inside ``` fences are skipped. The document carries blank templates that
# contain a literal `**Time:**` line, and counting those as sessions inflates
# both the total and the session count.
records=$(awk '
  /^```/            { in_fence = !in_fence; next }
  in_fence          { next }
  !/^\*\*Time:\*\*/ { next }
  {
    hours = 0
    phase = "(unassigned)"
    if (match($0, /[0-9]+(\.[0-9]+)?h/))
      hours = substr($0, RSTART, RLENGTH - 1) + 0
    if (match($0, /Phase [0-9]+/))
      phase = substr($0, RSTART, RLENGTH)
    printf "%s\t%s\n", phase, hours
  }
' "$log")

if [[ -z $records ]]; then
  echo "No **Time:** entries in BUILD-LOG yet."
  exit 0
fi

printf '%-14s %7s %9s\n' PHASE HOURS SESSIONS
awk -F'\t' '
  { hours[$1] += $2; sessions[$1] += 1 }
  END { for (p in hours) printf "%-14s %7.2f %9d\n", p, hours[p], sessions[p] }
' <<<"$records" | sort

awk -F'\t' '
  { total += $2; count += 1 }
  END {
    printf "\n%-14s %7.2f %9d\n", "TOTAL", total, count
    printf "%-14s %7.2f\n", "avg/session", total / count

    # 60-80h is the whole-project estimate from the 2026-07-27 planning session.
    printf "\nAgainst the 60-80h estimate: %.0f%%-%.0f%% spent, ", \
      total / 80 * 100, total / 60 * 100
    if (total < 60)
      printf "%.1fh-%.1fh remaining\n", 60 - total, 80 - total
    else if (total < 80)
      printf "up to %.1fh remaining\n", 80 - total
    else
      printf "%.1fh over the high estimate\n", total - 80
  }
' <<<"$records"
