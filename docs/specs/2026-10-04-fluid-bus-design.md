# Fluid Bus – návrh (specifikace)

- **Založeno:** 2026-10-04, aktualizováno k verzi 0.2.0 (2026-10-08)
- **Autor:** Ypsilonx, licence MIT
- **Hra:** Factorio 2.0 (testováno na 2.0.77), se Space Age i bez něj.
- **Interní jméno:** `fluid-bus` (publikováno, neměnné), prefix `fb`.

Podrobnosti implementace (moduly, kde ladit hodnoty, výsledky testů a výkonu) jsou v
`docs/development.md`, tady jen cíl a rozhodnutí s důvody.

## 1. Cíl a problém

Ve Factoriu 2.0 tvoří souvislé trubky jeden **fluid segment** se společnou hladinou. Segment smí mít
rozsah nejvýš `default_pipeline_extent = 320` políček (`data/core/prototypes/utility-constants.lua`),
proto se dlouhý bus dělí **pumpami**. Pumpa je jednosměrná a nejvýš 1200/s, takže na reálném busu
(35 000 trubek ≈ 110 segmentů, ~10 vstupů, ~50 výstupů):
- vedlejší zdroj „po proudu“ nezásobí nic „proti proudu“,
- před každou pumpou přeplnění (stojí výroba), za ní nedostatek (stojí spotřeba),
- dvojice pump proti sobě vyrovnává jen sousedy (pomalá difuze přes desítky spojů).

**Cíl:** celý bus se chová jako **jedna nádrž** – všechny segmenty propojené spojkami mají stejné
procento naplnění, bez ohledu na délku a polohu vstupů a výstupů.

### Co hráč dostane
- **BUS trubky** – ke každé trubce ve hře (vanilla i z modů) varianta s nastříkaným „B“. Parametry
  (dosah podzemní, extent, zdraví) podle původní trubky. Napojí se **jen na BUS trubky, spojku a pumpu**;
  pumpa je brána mezi busem a běžným potrubím.
- **Spojka busu** 1×1 na elektřinu ve linii BUS trubek. Segmenty propojené spojkami tvoří **síť**,
  kterou skript drží na stejném naplnění. Bez proudu nebo vypnutá obvodem = segmenty oddělené.
- **Obvodová síť:** spojka nic neposílá; obsah busu čte drátem BUS trubka (vanilla „Číst obsah potrubí“,
  2.1 – zděděno z trubky). Spojka má podmínku zapnutí/vypnutí a signál `fb-balance-interval`.
- **Vlastní okno spojky** místo nativního okna stroje (stav, síť, naplnění, elektřina, připojení obvodu).

### Typické zapojení
```
 vstup ─[pumpa]─┐                      ┌─[pumpa]─ fabrika
 ════BUS════════╧═══[S]═══BUS═══…═══[S]╧══════BUS════
              segment 1   segment 2         segment N
 [S] = spojka busu; běžné trubky se na bus napojí jen přes pumpu
```

## 2. Klíčová rozhodnutí

| Rozhodnutí | Volba | Důvod |
|---|---|---|
| Princip | síťové vyrovnání všech segmentů na stejné % | lokální obousměrné pumpy = pomalá difuze, hrdlo 1200/s na spoj |
| Oddělení busu | `connection_category`: BUS trubka má místo původních kategorií `fb-bus` (za `default`) a `fb-bus-<X>` (za vlastní kategorii X, např. Py `niobium-pipe`); spojka všechny kategorie busu, pumpy (i z modů) navíc k původním | vynucuje engine při stavbě, nula UPS; bus je uzavřený celek bez přimíchaných běžných trubek, nádrží a strojů (v0.1 se BUS napojovala i na běžné), hranice = pumpa; tiery Py zůstanou oddělené |
| Generování BUS trubek | z `data.raw` v `data-final-fixes.lua`, čistá funkce `collect(raw)` | vanilla, Py, Bob i neznámé mody bez údržby |
| Párování trubka ↔ podzemní | podle suroviny **libovolného** receptu podzemní | Py vyrábí podzemní i odléváním (`casting-…`) |
| Parametry BUS trubky | zděděné (`deepcopy`), vynulované `next_upgrade`, stejná `fast_replaceable_group` | tiery modů zůstanou smysluplné, retrofit přestavěním a upgrade plannerem |
| Typ spojky | `assembling-machine` 1×1 bez receptu, 2 fluidboxy | pumpa 1×1 má jen jeden fluidbox bez segmentu (spike) |
| Přenos kapaliny | čtení i zápis přes **sousední BUS trubku** (`insert_fluid`/`remove_fluid` pracují s celým segmentem) | fluidbox stroje bez receptu si s potrubím kapalinu nevyměňuje |
| Vyrovnání | každá síť jednou za `fb-balance-interval` ticků (mapa, výchozí 5) **celá v jednom ticku**; mezi sítěmi rozpočet `SEGMENT_BUDGET` | bez bufferu a zpoždění – po vyrovnání všude stejné %, množství se zachová; rozložení po segmentech (v0.1 návrh) dávalo trvalé rozdíly |
| Tolerance | posuzuje se za **celou síť** (nikdo neodchyluje víc než `TOLERANCE` → nepřelévat) | tolerance po segmentech nechala síť uvíznout pod plným (bug 0.1.0) |
| Teplota | doplňuje se s teplotou odebrané kapaliny, míchání dělá engine | vážený průměr zdarma |
| Topologie | čistá logika (`network.lua`, union-find) nad segmenty z rozložené kontroly; změny se slučují (`REBUILD_DELAY`) | přestavba nečte hru, žádné špičky |
| Signál | spojka žádný (od 0.3.0); čte BUS trubka – vanilla čtení obsahu segmentu (množství) | vlastní % signál ze spojky se na jednom drátu sčítal (dvě spojky = 120 %) a od 2.1 duplikoval vanilla čtení trubek; množství jde přepočítat na % |
| Řízení | podmínka v control behavior stroje (blueprint, kopírování zdarma); signál intervalu – síť bere nejmenší | nic vlastního k přenosu nastavení |
| GUI | vlastní okno (`player.opened = frame`) | nativní okno stroje ukazuje recept a volby, které spojka ignoruje |
| Grafika | „B“ nastříkané sprejem z Blenderu jako vrstva přes původní sprite; spojka = manometrová armatura (Blender) | jedna sada overlayů pro libovolnou trubku; cizí sprity nejde upravit |
| Výzkum | `fb-fluid-bus` (za `fluid-handling` + suroviny spojky) a `fb-fluid-bus-<trubka>` pro trubky z pozdějších výzkumů | podle pravidel skillu, žádné recepty v cizích výzkumech |

## 3. Mimo rozsah (zatím)

- Limit průtoku přes spojku a spotřeba energie úměrná přenosu (teď konstantní odběr).
- Vyvýšená BUS trubka (Elevated pipes), Factorio 2.1 – viz `ROADMAP.md`.

## 4. Známá omezení

- BUS podzemní dostane jen první kategorii (`fb-bus`) – engine povoluje u podzemního spoje jen jednu.
- Propustnost spojky omezuje kapacita segmentů mezi dvěma vyrovnáními (vzorec v `docs/development.md`).
- Starý save z 0.1: BUS trubky dotýkající se běžných trubek/nádrží se po aktualizaci odpojí.
