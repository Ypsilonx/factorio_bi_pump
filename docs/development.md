# Vývoj – Fluid Bus

## Prostředí
Factorio 2.0.77 (Steam, proměnná `FACTORIO_EXE`), Lua 5.3 pro unit testy, Git Bash pro `tools/*.sh`,
Blender pro grafiku (`blender/*.py`).

## Struktura
Data stage:
- `fluid-bus/settings.lua` – startup nastavení (odběr spojky, interval vyrovnávání).
- `fluid-bus/data.lua` – spojka busu (`prototypes/coupler.lua`).
- `fluid-bus/data-final-fixes.lua` – BUS trubky ze všech trubek ve hře, recept spojky, výzkumy, `mod-data` `fb-data`.
- `fluid-bus/prototypes/availability.lua` – dostupnost předmětů (recepty, výzkumy, skryté prototypy).
- `fluid-bus/prototypes/bus_pipes.lua` – výběr trubek, párování s podzemními, BUS prototypy.
- `fluid-bus/prototypes/bus_overlay.lua` – nastříkané „B“ na spritech trubek a „B“ v ikonách.
- `fluid-bus/prototypes/bus_marking_data.lua` – umístění „B“, **generované** z `blender/marking.toml`.
- `fluid-bus/prototypes/research.lua` – výzkumy s dopočítanými prerekvizitami.
- `fluid-bus/prototypes/coupler.lua` – spojka (assembling-machine 1×1 bez receptu, 2 fluidboxy `fb-bus`,
  `drain`), skrytý kombinátor signálů, signál `fb-fill`.

Runtime (`control.lua` jen napojuje události):
- `scripts/registry.lua` – evidence spojek ve `storage`, skryté kombinátory (drát s původem `script`).
- `scripts/topology.lua` – segmenty na stranách spojek, zástupné BUS trubky, přestavba sítí, vrácení
  zásobníků do segmentů.
- `scripts/network.lua` – čistá logika: segmenty + aktivní spojky → sítě (union-find).
- `scripts/balance_math.lua` – čistá logika: cílové naplnění, plán přelití, míchání teplot.
- `scripts/balancer.lua` – rozložený plánovač: za `fb-balance-interval` projde všechny segmenty.
- `scripts/signals.lua` – signály `fb-fill` a množství kapaliny, `custom_status` spojky.
- `scripts/remote.lua` – rozhraní `fb` (`network_of`, `rebuild`, `revalidate`).

Princip: kapalina se čte a zapisuje přes **sousední BUS trubku** (`insert_fluid`/`remove_fluid` na trubce
pracují s celým segmentem; fluidbox stroje do potrubí neproudí – spec 8.1). Přebytek segmentu jde do
zásobníku sítě, nedostatek se z něj doplní, takže množství se přesně zachovává.

Grafika:
- `blender/marking.py` – „B“ nastříkané sprejem (šablona, rozprašek, ohnutí kolem válce, lesk):
  `blender.exe -b --factory-startup -P blender/marking.py -- fluid-bus/graphics/entity`
- `blender/preview_marking.py` – náhled „B“ na vanilla trubkách (jen k ladění vzhledu):
  `blender.exe -b --factory-startup -P blender/preview_marking.py -- fluid-bus/graphics/entity <náhled.png>`
- `blender/build_overlay.py` – ikona „B“ do menu stavby
  (`blender.exe -b --factory-startup -P blender/build_overlay.py -- fluid-bus`).

## Kde ladit hodnoty
| Co | Kde |
|---|---|
| Odběr spojky (kW) | startup nastavení `fb-coupler-power` (výchozí 50) |
| Jak často se vyrovná celá síť (ticky) | startup nastavení `fb-balance-interval` (výchozí 60) |
| Odchylka, pod kterou se nepřelévá | `fluid-bus/scripts/balance_math.lua` – `TOLERANCE` |
| Zpoždění přestavby sítí po změně (slučování změn) | `fluid-bus/control.lua` – `REBUILD_DELAY` |
| Suroviny receptu spojky | `fluid-bus/prototypes/coupler.lua` – `INGREDIENTS` |
| Objem fluidboxu spojky | `fluid-bus/prototypes/coupler.lua` – `FLUID_VOLUME` |
| Odstín dočasné grafiky spojky | `fluid-bus/prototypes/coupler.lua` – `TINT` |
| Surovina značení v receptu BUS trubky | `fluid-bus/prototypes/bus_pipes.lua` – `MARKING` |
| Množství značení na kus | `fluid-bus/prototypes/bus_pipes.lua` – `MARKING_PER_PIECE` |
| Doba výroby BUS varianty | `fluid-bus/prototypes/bus_pipes.lua` – `CRAFT_TIME` |
| Které tvary trubky mají „B“, posun a orientace | `blender/marking.toml` – `[placement]` (pak spustit build) |
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
- Výkon: `bash tools/run-perf.sh [počet_úseků=1000] [ticků=1800]`
- Log generování (co vzniklo, co se vynechalo a proč): `grep "fluid-bus:" .test-run/<varianta>/create.log`

## Kompatibilita (ověřeno 2026-10-04, Factorio 2.0.77)
| Mody | Výsledek | Vzniklé BUS varianty |
|---|---|---|
| vanilla | 36/36 (+1 přeskočen – recyklace jen s quality) | pipe, pipe-to-ground (výzkum `fb-fluid-bus` za `fluid-handling`) |
| Space Age | 37/37 | pipe, pipe-to-ground; recyklační recepty BUS předmětů i spojky vznikají |
| pymodpack 3.0.0 (pyindustry 3.0.21, pyhightech 3.0.19, pyalienlife 3.0.67, …) | 6/6 | pipe, niobium-pipe, ht-pipes, vessel + jejich podzemní; každá za vlastním výzkumem `fb-fluid-bus-<trubka>` |
| boblogistics 2.1.1 + boblibrary 2.1.0 | 6/6 | pipe, bob-copper-pipe, bob-steel-pipe, bob-plastic-pipe + jejich podzemní; plastová za `fb-fluid-bus-bob-plastic-pipe` (`plastics`) |
| pipe-tiers 1.0.2 | 6/6 | BUS varianty mají stejný extent jako původní (volitelná závislost `? pipe-tiers` – načte se před námi) |

Pozn.: Py umí podzemní trubky i odlít z roztaveného kovu (`casting-…`); párování s trubkou proto
prochází všechny recepty podzemní, ne jen ten nejdřív dostupný.
Mody, které v `data-final-fixes` mění trubky (Pipe Tiers), musí běžet před námi – patří do
volitelných závislostí v `fluid-bus/info.json` a do `tests/fluid-bus-tests/info.json` (kontrola extentu).

## Výkon (2026-10-04, Factorio 2.0.77, `tools/run-perf.sh 1000 1800`)
Bus dlouhý 30 000 dlaždic, 1000 úseků po 29 trubkách, voda z infinity pipe na začátku, odběr na konci,
napájení velkými sloupy. Stejný bus s vanilla pumpami jako srovnání. Interval vyrovnávání 60 ticků.

| Varianta | průměr ms/tick | nejhorší tick |
|---|---|---|
| vanilla pumpy (1000 ks) | 0,202 | 0,55 ms |
| spojky busu (1000 ks, jedna síť 1000 segmentů) | 0,526 | 3,05 ms (přestavba sítě) |
| **rozdíl** | **+0,32** (cíl ≤ 1 ms) | ustálený běh ~1 ms |

- Nejhorší ticky jsou **přestavby sítě** (změna topologie: stavba/zboření u spojky, výpadek nebo náběh
  proudu). Přestavba nečte hru, stojí ~3 ms na síť s 1000 spojkami (≈ 0,3 ms u busu se 110 spojkami)
  a změny v okně 10 ticků se slučují (`REBUILD_DELAY` v `control.lua`). V ustáleném běhu žádné špičky.
- Dřívější verze zapisovala signály celé sítě v jednom ticku (špičky 7–14 ms každou sekundu) – teď se
  signály a stav spojek zapisují rozloženě a jen při změně.
- Scénář během běhu vypisuje stav sítě a počet přestaveb (`FB-PERF network … segments, fill …, rebuilds N`)
  – bez toho by šlo měřit nečinný bus (stalo se při prvním měření: zdroj energie mimo dosah sloupu).
- Rozbor po ticích: `.test-run/perf-couplers/bench.log` (CSV v ns, sloupec `scriptUpdate`).

## Známá omezení enginu
- Podzemní spoj (`connection_type = "underground"`) smí mít jen jednu `connection_category` – BUS
  podzemní trubka ho má beze změny, `fb-bus` dostávají jen nadzemní konektory.
- Fluidbox stroje bez receptu se s potrubím nevyměňuje – spojka proto přelévá přes sousední BUS trubku.
- `max_pipeline_extent` není za běhu čitelný – kontrola extentu běží přes `mod-data` testovacího modu.

## Ruční kontrola ve hře (před vydáním)
Spustit `bash tools/link-mod.sh` a hru s modem, v editoru mapy (`/editor`) nebo s cheaty:
1. BUS trubky: černé nastříkané „B“ na rovných kusech, okénkách (přes okénko), T-kusech a kříži (svisle
   otočené, čte se zdola nahoru) a na
   podzemních trubkách; sedí na těle trubky, nepřekrývá příruby; rohy a konce jsou bez „B“;
   vypadá i na trubkách z modů (Py, Bob).
2. BUS trubka postavená přes běžnou (rychlá výměna) i **upgrade planner** z běžné trubky na BUS
   (v plánovači nastavit trubka → BUS: trubka) – zda je mapování dovolené a kapalina zůstane.
3. Ikony předmětů a výzkumů, názvy „BUS: Trubka“ a „Spojka busu“ v češtině i angličtině, popisky.
4. Spojka: na běžnou trubku se nenapojí (konektory se nespojí), na BUS ano; rotace R; stav v okně
   spojky („Bus: N segmentů, X %“, „Bez proudu“, „Nepřipojeno k BUS trubce“, „Různé kapaliny“).
5. Obvodová síť: drát ze spojky do lampy/kombinátoru ukáže signály „Naplnění busu (%)“ a množství kapaliny.
6. Blueprint a kopírování spojky (skrytý kombinátor se nesmí objevit v blueprintu), zbourání spojky
   (kapalina zůstane v trubkách).
7. Dočasná grafika spojky (obarvená trubka) – finální model je v0.2.
