# Roadmap

## Vize

Hlavní kapalinový bus libovolné délky, který se chová jako jedna nádrž – v čisté hře i s velkými
overhaul mody, bez znatelné ceny v UPS.

## Milníky

### M1 – 0.1.0: BUS trubky a spojka ✅
- BUS varianty všech trubek (vanilla, Py, Bob, Pipe Tiers), spojka se síťovým vyrovnáním, signály, výzkumy.

### M2 – 0.2.0: oddělený bus, řízení, vlastní okno ✅
- BUS se napojí jen na BUS/spojku/pumpu, jeden signál, řízení obvodem, vlastní okno spojky, vydáno na portál.

### M3 – Další kompatibilita ⏳
- Cíl: mod funguje s dalšími mody, které mění nebo přidávají trubky a pumpy.
- Hotovo když: `run-tests.sh mods <mod>` projde a výsledek je v `docs/development.md` a `docs/mod-portal.md`.
- Které mody – otevřená otázka (`STATUS.md`).

### M4 – Rozšíření ⏳
- Kandidáti (z návrhu, zatím nerozhodnuto): vyvýšená BUS trubka (Elevated pipes), limit průtoku
  přes spojku, odběr energie úměrný přenosu.
- Hotovo když: upřesní se při výběru.

### 0.3.0 – Factorio 2.1 🔄
- Hotovo: přechod na fluid API v LuaEntity (LuaFluidBox v 2.1 zrušen), recyklace z modu `recycler`,
  unit + vanilla + Space Age zelené.
- Kompatibilita na 2.1 ověřena: Py 3.1, Bob 3.0; Pipe Tiers pro 2.1 zatím nevyšel.
- Spojka bez výstupního signálu – obsah busu čte BUS trubka (vanilla čtení 2.1).
- Zbývá: ruční kontrola ve hře, `run-perf.sh`, vydání.

## Mimo rozsah (vědomě neděláme)

- Napojení BUS trubek na běžné potrubí bez pumpy – bus má zůstat uzavřený celek (rozhodnutí 0.2.0).
