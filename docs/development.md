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
  `drain`), skrytý kombinátor signálů (dva na spojku: červený a zelený drát).

Runtime (`control.lua` jen napojuje události):
- `scripts/registry.lua` – evidence spojek ve `storage`, skryté kombinátory (drát s původem `script`).
- `scripts/topology.lua` – segmenty na stranách spojek, zástupné BUS trubky, přestavba sítí (bez čtení hry).
- `scripts/network.lua` – čistá logika: segmenty + aktivní spojky → sítě (union-find).
- `scripts/balance_math.lua` – čistá logika: plán vyrovnání celé sítě (společné naplnění, přelití, konflikt).
- `scripts/balancer.lua` – každou síť jednou za `fb-balance-interval` ticků srovná celou v jednom ticku.
- `scripts/signals.lua` – signály (červený drát: [kapalina] = množství, zelený: [kapalina] = %), `custom_status` spojky.
- Řízení obvodem: vypnutí podmínkou (`topology.refresh` čte `control_behavior.disabled` → neaktivní hrana),
  signál `fb-balance-interval` (`topology.read_interval`, síť bere nejmenší hodnotu ze svých spojek).
- `scripts/remote.lua` – rozhraní `fb` (`network_of` vč. platného `interval`, `set_interval`, `rebuild`, `revalidate`, `stats`).

Princip: kapalina se čte a zapisuje přes **sousední BUS trubku** (`insert_fluid`/`remove_fluid` na trubce
pracují s celým segmentem; fluidbox stroje do potrubí neproudí – spec 8.1). Síť se vyrovná celá v jednom
ticku: přečtou se všechny segmenty, spočítá se společné naplnění (%), přebytky se odeberou a doplní tam,
kde chybí (s teplotou odebrané kapaliny). Po vyrovnání mají všechny segmenty stejné %; množství se zachovává.

Grafika:
- `blender/marking.py` – „B“ nastříkané sprejem (šablona, rozprašek, ohnutí kolem válce, lesk):
  `blender.exe -b --factory-startup -P blender/marking.py -- fluid-bus/graphics/entity`
- `blender/preview_marking.py` – náhled „B“ na vanilla trubkách (jen k ladění vzhledu):
  `blender.exe -b --factory-startup -P blender/preview_marking.py -- fluid-bus/graphics/entity <náhled.png>`
- `blender/build_overlay.py` – ikona „B“ do menu stavby
  (`blender.exe -b --factory-startup -P blender/build_overlay.py -- fluid-bus`).
- `blender/coupler/build_coupler.py` – spojka (manometrová armatura): sprity svisle i vodorovně, stín,
  kontrolka (bílá, hra ji obarví podle stavu) a ikona; náhled vedle vanilla trubek:
  `blender.exe -b --factory-startup -P blender/coupler/build_coupler.py -- fluid-bus [náhled.png]`
  (model `model.py`, materiály a render převzaté ze Storage Optimizeru `fb_materials.py`, `fb_render.py`).

## Kde ladit hodnoty
| Co | Kde |
|---|---|
| Odběr spojky (kW) | startup nastavení `fb-coupler-power` (výchozí 50) |
| Jak často se vyrovná celá síť (ticky) | nastavení **mapy** `fb-balance-interval` (výchozí 5, mění se za běhu) |
| Nejvýš segmentů vyrovnaných v jednom ticku (více sítí) | `fluid-bus/scripts/balancer.lua` – `SEGMENT_BUDGET` |
| Jak často se kontroluje napojení, proud a signály spojek | `fluid-bus/control.lua` – `CHECK_INTERVAL` |
| Odchylka, pod kterou se nepřelévá | `fluid-bus/scripts/balance_math.lua` – `TOLERANCE` |
| Zpoždění přestavby sítí po změně (slučování změn) | `fluid-bus/control.lua` – `REBUILD_DELAY` |
| Suroviny receptu spojky | `fluid-bus/prototypes/coupler.lua` – `INGREDIENTS` |
| Objem fluidboxu spojky | `fluid-bus/prototypes/coupler.lua` – `FLUID_VOLUME` |
| Vzhled spojky (rozměry, barvy tělesa, manometr, skříňka, „B“) | `blender/coupler/coupler.toml` (pak spustit build spojky) |
| Barvy kontrolky podle stavu | `fluid-bus/prototypes/coupler.lua` – `STATUS_COLORS` |
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
| vanilla | 38/38 (+1 přeskočen – recyklace jen s quality) | pipe, pipe-to-ground (výzkum `fb-fluid-bus` za `fluid-handling`) |
| Space Age | 39/39 | pipe, pipe-to-ground; recyklační recepty BUS předmětů i spojky vznikají |
| pymodpack 3.0.0 (pyindustry 3.0.21, pyhightech 3.0.19, pyalienlife 3.0.67, …) | 6/6 | pipe, niobium-pipe, ht-pipes, vessel + jejich podzemní; každá za vlastním výzkumem `fb-fluid-bus-<trubka>` |
| boblogistics 2.1.1 + boblibrary 2.1.0 | 6/6 | pipe, bob-copper-pipe, bob-steel-pipe, bob-plastic-pipe + jejich podzemní; plastová za `fb-fluid-bus-bob-plastic-pipe` (`plastics`) |
| pipe-tiers 1.0.2 | 6/6 | BUS varianty mají stejný extent jako původní (volitelná závislost `? pipe-tiers` – načte se před námi) |

Pozn.: Py umí podzemní trubky i odlít z roztaveného kovu (`casting-…`); párování s trubkou proto
prochází všechny recepty podzemní, ne jen ten nejdřív dostupný.
Mody, které v `data-final-fixes` mění trubky (Pipe Tiers), musí běžet před námi – patří do
volitelných závislostí v `fluid-bus/info.json` a do `tests/fluid-bus-tests/info.json` (kontrola extentu).

## Výkon (2026-10-04, Factorio 2.0.77, `tools/run-perf.sh <počet> 1800`, interval vyrovnávání 5 ticků)
Bus z úseků po 29 trubkách, voda z infinity pipe na začátku, odběr na konci, napájení velkými sloupy.
Stejný bus s vanilla pumpami jako srovnání. Čísla „skript“ = sloupec `scriptUpdate` po ustálení (tick ≥ 600).

| Bus | spojky: průměr / nejhorší tick | pumpy: průměr / nejhorší tick | skript (ustálený běh) |
|---|---|---|---|
| 110 úseků (≈ tvůj bus) | 0,235 / 1,0 ms | 0,141 / 0,45 ms | průměr 0,077 ms, max 0,43 ms |
| 1000 úseků (extrém) | 0,811 / 5,1 ms | 0,198 / 0,45 ms | vyrovnání celé sítě ~3,2 ms každých 5 ticků |

- Cena je úměrná **počtu segmentů v síti / interval**: vyrovnání sítě čte a zapisuje všechny segmenty
  v jednom ticku (~3 µs na segment). U obřích sítí zvětši `fb-balance-interval` (nastavení mapy).
- **Propustnost spojky**: mezi dvěma vyrovnáními se musí rozdíl vejít do segmentů. Při toku F (l/s),
  intervalu K ticků a segmentech o kapacitě C se naplnění mezi vyrovnáními rozejde o ≈ 2·F·K/60/C.
  Příklad: 12 000/s, K = 5, segment 100 trubek (10 000 l) → ±10 %; segment 300 trubek → ±3 %.
  Test „průtok 12 000/s přes spojku“ to hlídá (odběr nestrádá ani o litr).
- Přestavby sítě (změna topologie) nečtou hru, změny v okně 10 ticků se slučují (`REBUILD_DELAY`).
- Signály a stav spojek se zapisují rozloženě (`CHECK_INTERVAL`) a jen při změně.
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
5. Obvodová síť: červený drát ze spojky do lampy/kombinátoru ukáže [kapalina] = množství, zelený = %.
   Podmínka zapnutí v okně spojky ji vypne (stav „Vypnuto obvodovou sítí“, žlutá kontrolka); signál
   „Interval vyrovnávání busu“ jde vybrat a poslat konstantním kombinátorem.
6. Blueprint a kopírování spojky (skrytý kombinátor se nesmí objevit v blueprintu), zbourání spojky
   (kapalina zůstane v trubkách).
7. Vzhled spojky: sedí v řadě trubek (vodorovně i svisle), stín, kontrolka zelená s proudem, červená bez
   proudu, žlutá při nedostatku; v noci svítí.
