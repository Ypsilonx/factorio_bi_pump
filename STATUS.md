# Stav projektu

Aktualizováno: 2026-10-17

## Cíl

Další milník z `ROADMAP.md` (M3 kompatibilita / M4 rozšíření) – zatím nevybráno.

## Hotovo

- 0.2.0 vydaná na portál (2026-10-08), ruční kontrola ve hře podle checklistu proběhla.
- Testy: unit 71/71, vanilla 46/46 (+1 skip, 2026-10-17); Space Age a mody (Py, Bob, Pipe Tiers)
  ověřeny k vydání 0.2.0 – viz `docs/development.md`.

## Rozpracováno

- Nic.

## Další krok

1. Vybrat mody pro M3 (které další mody s trubkami/pumpami má smysl otestovat) nebo rozšíření pro M4.

## Otevřené otázky / slepé uličky

- Které mody patří do M3? Co z M4 dělat jako první?
- ❌ Zápis/čtení kapaliny přes fluidbox spojky (`set_fluid`, `insert_fluid` na stroji) – plní jen box
  stroje, do potrubí se nepřelije (stroj bez receptu neproudí). Používat sousední BUS trubku.
- ❌ Spojka jako `pump` 1×1 – má jen jeden fluidbox bez segmentu, druhou stranu nevidí.
- ❌ Vyrovnávání rozložené po segmentech s bufferem sítě (návrh v0.1) – zpoždění a trvalý rozdíl
  za spojkou; nahrazeno vyrovnáním celé sítě v jednom ticku.
- ❌ Tolerance posuzovaná po segmentech – síť uvízla pod plným (opraveno v 0.2.0).
- ❌ `flow_direction` jiný než `input-output` na fluidboxu spojky – odpojí ji od trubek.
