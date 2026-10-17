# Fluid Bus (mod do Factoria 2.0)

BUS varianty všech trubek ve hře a spojka busu, která propojí segmenty BUS trubek do jedné sítě
se stejným naplněním – celý hlavní bus se chová jako jedna nádrž.

- Návod pro hráče: `docs/user-guide.md`
- Text pro mod portál: `docs/mod-portal.md`
- Vývoj (struktura, kde ladit hodnoty, testy, výkon, ruční kontrola): `docs/development.md`
- Návrh (proč je to tak, jak to je): `docs/specs/`; stav a plán verzí: `STATUS.md`, `ROADMAP.md`

## Rychlý start vývoje
- Unit testy: `bash tools/run-unit.sh`
- Integrační testy: `bash tools/run-tests.sh vanilla` a `bash tools/run-tests.sh space-age`
- Kompatibilita: `bash tools/run-tests.sh mods pymodpack` (+ `boblogistics`, `pipe-tiers`)
- Výkon: `bash tools/run-perf.sh`
- Hrát rozpracovanou verzi: `bash tools/link-mod.sh` (junction do `%APPDATA%/Factorio/mods`)

Skripty v `tools/` jsou pro Git Bash (terminál VSCode s profilem Git Bash). Z PowerShellu:
`& "C:\Program Files\Git\bin\bash.exe" tools/run-unit.sh`.
