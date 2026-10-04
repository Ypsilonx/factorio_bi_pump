# Vývoj – Fluid Bus

## Prostředí
Factorio 2.0.77 (Steam, proměnná `FACTORIO_EXE`), Lua 5.3 pro unit testy, Git Bash pro `tools/*.sh`,
Blender pro overlay grafiku (`blender/build_overlay.py`).

## Struktura
- `fluid-bus/data-final-fixes.lua` – generování BUS trubek ze všech trubek ve hře, výzkumy, `mod-data`.
- `fluid-bus/prototypes/availability.lua` – dostupnost předmětů (recepty, výzkumy, skryté prototypy).
- `fluid-bus/prototypes/bus_pipes.lua` – výběr trubek, párování s podzemními, BUS prototypy.
- `fluid-bus/prototypes/bus_overlay.lua` – nastříkané „B“ na spritech trubek a „B“ v ikonách.
- `fluid-bus/prototypes/bus_marking_data.lua` – umístění „B“, **generované** z `blender/marking.toml`.
- `fluid-bus/prototypes/research.lua` – výzkumy s dopočítanými prerekvizitami.
- `blender/marking.py` – „B“ nastříkané sprejem (šablona, rozprašek, ohnutí kolem válce, lesk):
  `blender.exe -b --factory-startup -P blender/marking.py -- fluid-bus/graphics/entity`
- `blender/preview_marking.py` – náhled „B“ na vanilla trubkách (jen k ladění vzhledu):
  `blender.exe -b --factory-startup -P blender/preview_marking.py -- fluid-bus/graphics/entity <náhled.png>`
- `blender/build_overlay.py` – ikona „B“ do menu stavby
  (`blender.exe -b --factory-startup -P blender/build_overlay.py -- fluid-bus`).

## Kde ladit hodnoty
| Co | Kde |
|---|---|
| Surovina značení v receptu (kandidáti) | `fluid-bus/prototypes/bus_pipes.lua` – `MARKING` |
| Množství značení na kus | `fluid-bus/prototypes/bus_pipes.lua` – `MARKING_PER_PIECE` |
| Doba výroby BUS varianty | `fluid-bus/prototypes/bus_pipes.lua` – `CRAFT_TIME` |
| Které tvary trubky mají „B“, posun a orientace | `blender/marking.toml` – `[placement]` (pak spustit build níže) |
| Svislé „B“ zdola nahoru / shora dolů | `blender/marking.toml` – `[orientation] vertical_rotation` |
| Barva, krytí, rozprašek nástřiku | `blender/marking.toml` – `[paint]` |
| Plasticita (zakřivení, lesk, světlo) | `blender/marking.toml` – `[shading]` |
| Velikost, tučnost, mezera šablony | `blender/marking.toml` – `[letter]` |
| Ikona „B“ v menu stavby | `blender/build_overlay.py` – `TEXT_SIZE`, `OUTLINE` |
| Cena výzkumu (násobič) | `fluid-bus/prototypes/research.lua` – `TECH_COUNT_MULTIPLIER` |
| Prerekvizity základního výzkumu | `fluid-bus/prototypes/research.lua` – `BASE_ITEMS` |

## Testy
- Unit: `bash tools/run-unit.sh`
- Integrační: `bash tools/run-tests.sh vanilla`, `bash tools/run-tests.sh space-age`
- Kompatibilita: `bash tools/run-tests.sh mods pymodpack`, `bash tools/run-tests.sh mods boblogistics`,
  `bash tools/run-tests.sh mods pipe-tiers`
- Log generování (co vzniklo, co se vynechalo a proč): `grep "fluid-bus:" .test-run/<varianta>/create.log`

## Kompatibilita (ověřeno 2026-10-04, Factorio 2.0.77)
| Mody | Výsledek | Vzniklé BUS varianty |
|---|---|---|
| vanilla | 12/12 (+1 přeskočen – recyklace jen s quality) | pipe, pipe-to-ground (výzkum `fb-fluid-bus` za `fluid-handling`) |
| Space Age | 13/13 | pipe, pipe-to-ground; recyklační recepty BUS předmětů vznikají |
| pymodpack 3.0.0 (pyindustry 3.0.21, pyhightech 3.0.19, pyalienlife 3.0.67, …) | 5/5 | pipe, niobium-pipe, ht-pipes, vessel + jejich podzemní; každá za vlastním výzkumem `fb-fluid-bus-<trubka>` |
| boblogistics 2.1.1 + boblibrary 2.1.0 | 5/5 | pipe, bob-copper-pipe, bob-steel-pipe, bob-plastic-pipe + jejich podzemní; plastová za `fb-fluid-bus-bob-plastic-pipe` (`plastics`) |
| pipe-tiers 1.0.2 | 5/5 | BUS varianty mají stejný extent jako původní (volitelná závislost `? pipe-tiers` – načte se před námi) |

Pozn.: Py umí podzemní trubky i odlít z roztaveného kovu (`casting-…`); párování s trubkou proto
prochází všechny recepty podzemní, ne jen ten nejdřív dostupný.
Mody, které v `data-final-fixes` mění trubky (Pipe Tiers), musí běžet před námi – patří do
volitelných závislostí v `fluid-bus/info.json` a do `tests/fluid-bus-tests/info.json` (kontrola extentu).

## Známá omezení enginu
- Podzemní spoj (`connection_type = "underground"`) smí mít jen jednu `connection_category` – BUS
  podzemní trubka ho má beze změny, `fb-bus` dostávají jen nadzemní konektory.

## Ruční kontrola ve hře (před vydáním)
Spustit `bash tools/link-mod.sh` a hru s modem, v editoru mapy (`/editor`) nebo s cheaty:
1. BUS trubky: černé nastříkané „B“ na rovných kusech (svisle otočené, čte se zdola nahoru) a na
   podzemních trubkách; sedí na těle trubky, nepřekrývá příruby, okénka a rohy jsou bez „B“;
   vypadá i na trubkách z modů (Py, Bob).
2. BUS trubka postavená přes běžnou (rychlá výměna) i **upgrade planner** z běžné trubky na BUS
   (v plánovači nastavit trubka → BUS: trubka) – zda je mapování dovolené a kapalina zůstane.
3. Ikony předmětů a výzkumů, názvy „BUS: Trubka“ v češtině i angličtině, popisky.
