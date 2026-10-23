# Stav projektu

Aktualizováno: 2026-10-23

## Cíl

0.3.0 – přechod na Factorio 2.1 (2.1.23); spojka bez výstupního signálu (obsah busu čte BUS trubka).

## Hotovo

- 0.2.0 vydaná na portál (2026-10-08) pro Factorio 2.0.
- 0.3.0 (nevydaná): `factorio_version` 2.1, runtime na nové fluid API `LuaEntity` (`get_fluid_box_neighbours`,
  `get_fluid_segment_fluid/capacity/id`, `get_fluid`, `extract_fluid`), recyklace z `__recycler__.recycling`,
  `run-tests.sh`/`run-perf.sh` znají vestavěný mod `recycler` a závislosti `+`.
- 0.3.0: spojka nic nevysílá (zrušen skrytý kombinátor, `signals.lua` → `status.lua`), podmínka a signál
  intervalu beze změny; obsah busu čte drátem BUS trubka (zděděné vanilla čtení 2.1). Starý save se
  skrytým kombinátorem ověřen jednorázovým scénářem: načte se bez chyby, kombinátor zmizí, síť jede.
- Ikona BUS entit má „B“ (dřív jen předmět – v editoru mapy chybělo); hlídá `compat.lua`.
- Testy 2026-10-23 na 2.1.23: unit 71/71, vanilla 44/44 (+1 skip recyklace), Space Age 45/45,
  obecné kontroly s Py 3.1 a Bob 3.0 8/8.
- Kompatibilita 2026-10-23: pymodpack 3.1.0 7/7, boblogistics 3.0.2 7/7, pipe-tiers 1.0.2 7/7 jen
  s ručně přepsanou `factorio_version` (pro 2.1 nevyšel, hra ho nenačte) – viz `docs/development.md`.

## Rozpracováno

- Ruční kontrola 0.3.0 ve hře (checklist v `docs/development.md`).

## Další krok

1. Ruční kontrola ve hře podle checklistu (bod 5 – obvodová síť je nový: konektor BUS trubky, čtení obsahu,
   podmínka spojky z drátu, tip v okně spojky).
2. Před vydáním: `run-perf.sh` a zápis do `docs/development.md` (sekce Výkon je ještě z 2.0.77).
3. Až vyjde Pipe Tiers pro 2.1: `mods pipe-tiers` znovu.

## Otevřené otázky / slepé uličky

- Které mody patří do M3? Co z M4 dělat jako první?
- ❌ Zápis/čtení kapaliny přes fluidbox spojky (`set_fluid`, `insert_fluid` na stroji) – plní jen box
  stroje, do potrubí se nepřelije (stroj bez receptu neproudí). Používat sousední BUS trubku.
- ❌ Spojka jako `pump` 1×1 – má jen jeden fluidbox bez segmentu, druhou stranu nevidí.
- ❌ Vyrovnávání rozložené po segmentech s bufferem sítě (návrh v0.1) – zpoždění a trvalý rozdíl
  za spojkou; nahrazeno vyrovnáním celé sítě v jednom ticku.
- ❌ Tolerance posuzovaná po segmentech – síť uvízla pod plným (opraveno v 0.2.0).
- ❌ `flow_direction` jiný než `input-output` na fluidboxu spojky – odpojí ji od trubek.
