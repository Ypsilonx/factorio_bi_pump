#!/usr/bin/env bash
# Nahraje mod na mods.factorio.com přes API (zip sestaví tools/package.sh).
# Mod na portálu ještě není → první publikace (Mod publish API) s popisem, kategorií a licencí;
# jinak nahraje novou verzi (Mod upload API).
# Použití: tools/publish.sh [--details | --details-only]
#   --details       navíc aktualizuje na portálu popis z docs/mod-portal.md, krátký popis z info.json a štítky
#   --details-only  jen aktualizuje popis a štítky (bez nahrání verze)
# API klíč (https://factorio.com/profile → API keys) s oprávněními „ModPortal: Publish Mods“ (první
# publikace), „ModPortal: Upload Mods“ (nové verze) a „ModPortal: Edit Mods“ (--details):
# proměnná FACTORIO_API_KEY, jinak soubor ~/.factorio-api-key (je-li to složka, all_api_key.txt v ní;
# jiný soubor proměnnou FACTORIO_API_KEY_FILE).
# Nikdy ne do repozitáře.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="https://mods.factorio.com/api"
MOD="fluid-bus"
# Údaje portálu (laditelné): kategorie, licence a štítky – hodnoty viz https://wiki.factorio.com/Mod_details_API
CATEGORY="content"
LICENSE="default_mit"
TAGS=("fluids" "circuit-network" "logistics")
DESCRIPTION="$ROOT/docs/mod-portal.md"
SOURCE_URL="https://github.com/Ypsilonx/factorio_bi_pump"

KEY_FILE="$HOME/.factorio-api-key"
# Složka s klíči: all_api_key.txt má všechna oprávnění (Publish, Upload, Edit).
[ -d "$KEY_FILE" ] && KEY_FILE="$KEY_FILE/all_api_key.txt"
KEY_FILE="${FACTORIO_API_KEY_FILE:-$KEY_FILE}"
KEY="${FACTORIO_API_KEY:-$(cat "$KEY_FILE" 2>/dev/null || true)}"
KEY="$(printf '%s' "$KEY" | tr -d '\r\n ')"
[ -z "$KEY" ] && { echo "Chybí API klíč: FACTORIO_API_KEY nebo ~/.factorio-api-key"; exit 1; }

# Aktualizuje na portálu krátký popis (z info.json), popis (docs/mod-portal.md), kategorii, zdroj a štítky.
update_details() {
  # Krátký popis jde do curl ze souboru – v argumentu by curl na Windows rozbil znaky mimo ASCII (pomlčku).
  local summary_file result
  summary_file="$(mktemp)"
  grep -oE '"description" *: *"[^"]*"' "$ROOT/$MOD/info.json" | sed -E 's/^"description" *: *"(.*)"$/\1/' \
    | tr -d '\r\n' > "$summary_file"
  local tag_args=()
  for tag in "${TAGS[@]}"; do tag_args+=(-F "tags=$tag"); done
  result="$(curl -sS -H "Authorization: Bearer $KEY" -F "mod=$MOD" -F "summary=<$(cygpath -m "$summary_file")" \
    -F "description=<$(cygpath -m "$DESCRIPTION")" -F "category=$CATEGORY" -F "source_url=$SOURCE_URL" \
    "${tag_args[@]}" "$API/v2/mods/edit_details")"
  rm -f "$summary_file"
  printf '%s' "$result" | grep -q '"success" *: *true' || { echo "Úprava popisu selhala: $result"; exit 1; }
  echo "Popis a štítky na portálu aktualizovány."
}

if [ "${1:-}" = "--details-only" ]; then
  update_details
  exit 0
fi

VERSION=$(grep -oE '"version"[^"]*"[^"]+"' "$ROOT/$MOD/info.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
grep -q "^Version: $VERSION$" "$ROOT/$MOD/changelog.txt" || { echo "changelog.txt nemá sekci $VERSION"; exit 1; }
STATUS="$(curl -sS -o /dev/null -w '%{http_code}' "$API/mods/$MOD")"
if [ "$STATUS" = "200" ] && curl -sS "$API/mods/$MOD" | grep -q "\"version\":\"$VERSION\""; then
  echo "Verze $VERSION už na portálu je – zvyš version v info.json."
  exit 1
fi
[ -n "$(git -C "$ROOT" status --porcelain -- "$MOD")" ] && echo "Pozor: $MOD má necommitnuté změny, nahrávají se tak, jak jsou."

ZIP="$(bash "$ROOT/tools/package.sh" | tail -1)"
FILE="$(cygpath -m "$ZIP")"
if [ "$STATUS" = "404" ]; then
  echo "První publikace $MOD $VERSION ($ZIP)"
  INIT="$(curl -sS -H "Authorization: Bearer $KEY" -F "mod=$MOD" "$API/v2/mods/init_publish")"
  EXTRA=(-F "description=<$(cygpath -m "$DESCRIPTION")" -F "category=$CATEGORY" -F "license=$LICENSE"
    -F "source_url=$SOURCE_URL")
else
  echo "Nahrávám verzi $VERSION ($ZIP)"
  INIT="$(curl -sS -H "Authorization: Bearer $KEY" -F "mod=$MOD" "$API/v2/mods/releases/init_upload")"
  EXTRA=()
fi
URL="$(printf '%s' "$INIT" | grep -oE '"upload_url" *: *"[^"]+"' | sed -E 's/.*"(https[^"]+)"/\1/' || true)"
[ -z "$URL" ] && { echo "Inicializace selhala: $INIT"; exit 1; }
RESULT="$(curl -sS -F "file=@$FILE" "${EXTRA[@]}" "$URL")"
printf '%s' "$RESULT" | grep -q '"success" *: *true' || { echo "Nahrání selhalo: $RESULT"; exit 1; }
echo "Hotovo: https://mods.factorio.com/mod/$MOD"

[ "${1:-}" = "--details" ] && update_details
exit 0
