#!/usr/bin/env bash
# Nahraje novou verzi modu na mods.factorio.com přes Mod upload API (sestaví zip přes tools/package.sh).
# Použití: tools/publish.sh [--details]
#   --details  navíc aktualizuje na portálu popis z docs/mod-portal.md a krátký popis z info.json
# API klíč (https://factorio.com/profile → API keys, oprávnění „ModPortal: Upload Mods“, pro --details
# i „ModPortal: Edit Mods“): proměnná FACTORIO_API_KEY, jinak soubor ~/.factorio-api-key. Nikdy ne do repozitáře.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="https://mods.factorio.com/api"
MOD="fluid-bus"
KEY="${FACTORIO_API_KEY:-$(cat "$HOME/.factorio-api-key" 2>/dev/null || true)}"
KEY="$(printf '%s' "$KEY" | tr -d '\r\n ')"
[ -z "$KEY" ] && { echo "Chybí API klíč: FACTORIO_API_KEY nebo ~/.factorio-api-key"; exit 1; }

VERSION=$(grep -oE '"version"[^"]*"[^"]+"' "$ROOT/$MOD/info.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
grep -q "^Version: $VERSION$" "$ROOT/$MOD/changelog.txt" || { echo "changelog.txt nemá sekci $VERSION"; exit 1; }
if curl -sS "$API/mods/$MOD" | grep -q "\"version\":\"$VERSION\""; then
  echo "Verze $VERSION už na portálu je – zvyš version v info.json."
  exit 1
fi
[ -n "$(git -C "$ROOT" status --porcelain -- "$MOD")" ] && echo "Pozor: $MOD má necommitnuté změny, nahrávají se tak, jak jsou."

ZIP="$(bash "$ROOT/tools/package.sh" | tail -1)"
echo "Nahrávám $ZIP"
INIT="$(curl -sS -H "Authorization: Bearer $KEY" -F "mod=$MOD" "$API/v2/mods/releases/init_upload")"
URL="$(printf '%s' "$INIT" | grep -oE '"upload_url" *: *"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/')"
[ -z "$URL" ] && { echo "init_upload selhal: $INIT"; exit 1; }
RESULT="$(curl -sS -F "file=@$(cygpath -m "$ZIP")" "$URL")"
printf '%s' "$RESULT" | grep -q '"success" *: *true' || { echo "Nahrání selhalo: $RESULT"; exit 1; }
echo "Verze $VERSION nahrána: https://mods.factorio.com/mod/$MOD"

if [ "${1:-}" = "--details" ]; then
  SUMMARY=$(grep -oE '"description" *: *"[^"]*"' "$ROOT/$MOD/info.json" | sed -E 's/^"description" *: *"(.*)"$/\1/')
  RESULT="$(curl -sS -H "Authorization: Bearer $KEY" -F "mod=$MOD" -F "summary=$SUMMARY" \
    -F "description=<$(cygpath -m "$ROOT/docs/mod-portal.md")" "$API/v2/mods/edit_details")"
  printf '%s' "$RESULT" | grep -q '"success" *: *true' || { echo "Úprava popisu selhala: $RESULT"; exit 1; }
  echo "Popis na portálu aktualizován."
fi
