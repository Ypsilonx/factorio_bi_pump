#!/usr/bin/env bash
# Výkonový test: dlouhý bus se spojkami fluid-bus proti stejnému busu s vanilla pumpami.
# Použití: tools/run-perf.sh [počet_úseků=1000] [ticků=1800] [interval_vyrovnávání=5] [úseků_na_síť=0 (= jedna síť)]   (cestu k Factoriu lze změnit proměnnou FACTORIO_EXE)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO_EXE:-C:/STEAM/steamapps/common/Factorio/bin/x64/factorio.exe}"
COUNT="${1:-1000}"
TICKS="${2:-1800}"
INTERVAL="${3:-5}"
GROUP="${4:-0}"

# Postaví mapu varianty (couplers / pumps), odsimuluje TICKS ticků a vypíše průměrný čas ticku.
run() {
  local variant="$1" with_mod="$2"
  local RUN="$ROOT/.test-run/perf-$variant"
  local RUN_W
  RUN_W="$(cygpath -m "$RUN")"
  rm -rf "$RUN"
  mkdir -p "$RUN/mods" "$RUN/write-data"
  cp -r "$ROOT/tests/perf/fb-perf" "$RUN/mods/fb-perf"
  echo "return { $COUNT, $INTERVAL, $GROUP }" > "$RUN/mods/fb-perf/count.lua"
  if [ "$with_mod" = true ]; then cp -r "$ROOT/fluid-bus" "$RUN/mods/fluid-bus"; fi
  cat > "$RUN/mods/mod-list.json" <<JSON
{"mods":[{"name":"base","enabled":true},{"name":"elevated-rails","enabled":false},{"name":"quality","enabled":false},{"name":"recycler","enabled":false},
{"name":"space-age","enabled":false},{"name":"fluid-bus","enabled":$with_mod},{"name":"fb-perf","enabled":true}]}
JSON
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/write-data\n' "$RUN_W" > "$RUN/config.ini"
  local ARGS=(--config "$RUN_W/config.ini" --mod-directory "$RUN_W/mods")
  "$FACTORIO" "${ARGS[@]}" --create "$RUN_W/perf.zip" > "$RUN/create.log" 2>&1 || true
  if [ ! -f "$RUN/perf.zip" ]; then
    grep -A10 -E "Error" "$RUN/create.log" | head -30
    exit 1
  fi
  "$FACTORIO" "${ARGS[@]}" --benchmark "$RUN_W/perf.zip" --benchmark-ticks "$TICKS" --benchmark-verbose all \
    --disable-audio > "$RUN/bench.log" 2>&1 || true
  grep -h "FB-PERF" "$RUN/create.log" "$RUN/bench.log" | sed "s/.*FB-PERF/FB-PERF/" || true
  local line max
  line="$(grep -E "Performed [0-9]+ updates in" "$RUN/bench.log" | tail -1)"
  # Nejhorší tick (špičky) ze souhrnu podrobného výstupu benchmarku.
  max="$(grep -E "avg: [0-9.]+ ms, min: [0-9.]+ ms, max: [0-9.]+ ms" "$RUN/bench.log" | tail -1 \
    | sed -E 's/.*max: ([0-9.]+) ms.*/\1/')"
  echo "$line" | sed -E 's/.*Performed ([0-9]+) updates in ([0-9.]+) ms.*/\1 \2/' \
    | awk -v v="$variant" -v m="$max" '{ printf "FB-PERF %s %.3f ms/tick, max %s ms\n", v, $2 / $1, m }'
  # Čas samotného skriptu (sloupec scriptUpdate v ns) po ustálení – od ticku 600.
  awk -F, -v v="$variant" '/^t[0-9]+,/ { t = substr($1, 2) + 0; if (t >= 600) { s = $43 / 1e6; sum += s; n++; if (s > mx) mx = s } }
    END { if (n) printf "FB-PERF %s skript po ustálení: průměr %.3f ms, max %.3f ms\n", v, sum / n, mx }' "$RUN/bench.log"
}

run couplers true
run pumps false
