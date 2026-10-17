# Fluid Bus (mod do Factoria 2.0)

BUS varianty všech trubek ve hře a spojka busu, která drží všechny propojené segmenty na stejném
naplnění – celý hlavní bus se chová jako jedna nádrž. Publikováno na mods.factorio.com (`fluid-bus`).
Velikost: L.

Doména: `factorio-mod` – obecná pravidla (struktura, testy, UPS, přenos nastavení, vydání) jsou ve
skillu, tady se neopakují.

## Spuštění a ověření

- Ověřit po změně: `bash tools/run-unit.sh` + `bash tools/run-tests.sh vanilla`
- Před milníkem/vydáním navíc: `bash tools/run-tests.sh space-age`, `mods pymodpack | boblogistics |
  pipe-tiers`, `bash tools/run-perf.sh` (výsledky zapsat do `docs/development.md`)
- Hrát rozpracovanou verzi: `bash tools/link-mod.sh`; vydání: `bash tools/publish.sh [--details]`

## Mapa projektu

- Mod `fluid-bus/`, testy `tests/`, nástroje `tools/`, grafika `blender/`.
- Moduly, kde ladit hodnoty, výkon, kompatibilita, checklist ruční kontroly: `docs/development.md`.
- Proč je to tak, jak to je: `docs/specs/2026-10-04-fluid-bus-design.md`.

## Rozhodnutí a pravidla tohoto projektu

- Prefix `fb` (prototypy, nastavení, GUI, remote `fb`, log tag `FB-TEST`).
- Kapalina se čte i zapisuje **přes sousední BUS trubku**, nikdy přes fluidbox spojky.
- BUS trubky se napojují jen na BUS, spojku a pumpu – změna kategorií napojení rozbíjí staré savy,
  vždy s poznámkou v changelogu.
- Mody měnící trubky v `data-final-fixes` (Pipe Tiers) patří do volitelných závislostí v
  `fluid-bus/info.json` i `tests/fluid-bus-tests/info.json`.

Stav práce: `STATUS.md`, plán verzí: `ROADMAP.md`.
