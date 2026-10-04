# Fluid Bus (mod do Factoria 2.0)

BUS varianty všech trubek ve hře a spojka busu, která propojí segmenty BUS trubek do jedné sítě
se stejným naplněním – celý hlavní bus se chová jako jedna nádrž.

- Návrh: `docs/superpowers/specs/2026-10-04-fluid-bus-design.md`
- Plány: `docs/superpowers/plans/`

## Rychlý start vývoje
- Unit testy: `bash tools/run-unit.sh`
- Integrační testy: `bash tools/run-tests.sh vanilla` a `bash tools/run-tests.sh space-age`
- Kompatibilita: `bash tools/run-tests.sh mods pymodpack`, `bash tools/run-tests.sh mods boblogistics`
- Hrát rozpracovanou verzi: `bash tools/link-mod.sh` (junction do `%APPDATA%/Factorio/mods`)
