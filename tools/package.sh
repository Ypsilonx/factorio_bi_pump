#!/usr/bin/env bash
# Sestaví zip modu pro mod portál: dist/fluid-bus_<verze>.zip s kořenovou složkou fluid-bus_<verze>/.
# Používá PowerShell 7 (Compress-Archive v pwsh zapisuje cesty s lomítky, jak Factorio vyžaduje).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=$(grep -oE '"version"[^"]*"[^"]+"' "$ROOT/fluid-bus/info.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
NAME="fluid-bus_$VERSION"
STAGE="$ROOT/dist/stage"
rm -rf "$STAGE" "$ROOT/dist/$NAME.zip"
mkdir -p "$STAGE"
cp -r "$ROOT/fluid-bus" "$STAGE/$NAME"
pwsh -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$STAGE/$NAME")' -DestinationPath '$(cygpath -w "$ROOT/dist/$NAME.zip")'"
rm -rf "$STAGE"
echo "$ROOT/dist/$NAME.zip"
