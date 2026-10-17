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

### Factorio 2.1 ⏳
- Přechod až s přechodem serveru: krátký test kompatibility, nová řada `factorio_version`.

## Mimo rozsah (vědomě neděláme)

- Napojení BUS trubek na běžné potrubí bez pumpy – bus má zůstat uzavřený celek (rozhodnutí 0.2.0).
