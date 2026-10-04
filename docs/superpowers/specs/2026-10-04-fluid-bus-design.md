# Fluid Bus – návrh (specifikace)

- **Datum:** 2026-10-04
- **Autor modu:** Ypsilonx
- **Licence:** MIT
- **Cílová verze hry:** Factorio 2.0 (testováno na 2.0.77), funguje se Space Age i bez něj.
  Factorio 2.1 se řeší až při přechodu serveru (krátký test kompatibility).
- **Interní název modu:** `fluid-bus`, prefix `fb` – **pracovní**, finální jméno se vybere před
  prvním nahráním na portál (po publikaci neměnné). Na portálu ověřeno volné: `fluid-bus`,
  `fluid-mainbus`, `mainbus-pipes`.

## 1. Cíl a problém

Ve Factoriu 2.0 tvoří souvislé trubky jeden **fluid segment**: kapalina je v něm sdílená a hladina
všude stejná. Segment ale smí mít rozsah nejvýš `default_pipeline_extent = 320` políček
(`data/core/prototypes/utility-constants.lua:539`), proto se dlouhý bus dělí **pumpami**. Pumpa je
jednosměrná (1200/s), takže bus je řetěz segmentů, kde kapalina teče jen jedním směrem.

Na reálném busu (např. 35 000 trubek ≈ 110 segmentů, ~10 vstupů, ~50 výstupů) to znamená:
- vedlejší zdroj „po proudu“ nezásobí nic „proti proudu“,
- přes každý spoj projde max 1200/s → před spojem přeplnění (stojí výroba), za ním nedostatek
  (stojí spotřeba),
- dvojice pump/ventilů proti sobě vyrovnává jen sousedy (pomalá difuze přes desítky spojů).

**Cíl:** celý bus se má chovat jako **jedna nádrž** – všechny segmenty propojené spojkami mají
stejné procento naplnění, bez ohledu na délku a polohu vstupů/výstupů.

### Co hráč dostane
- **BUS trubky** – ke každé trubce ve hře (vanilla i z modů) varianta s označením „BUS“.
  Parametry (dosah podzemní, extent, zdraví) zůstávají podle původní trubky. Napojují se na běžné
  trubky normálně a dají se postavit přímo přes existující trubky (retrofit busu bez bourání).
- **Spojka busu** 1×1 na elektřinu – staví se do linky BUS trubek místo jednoho kusu trubky.
  Připojí se **jen na BUS trubky**. Segmenty na obou stranách logicky spojí: všechny segmenty
  propojené spojkami tvoří **síť**, ve které skript průběžně vyrovnává naplnění.
- **Obvodová síť (jen čtení):** spojka vysílá naplnění celé sítě v % a celkové množství kapaliny.
  Hráč podle toho řídí výrobu nebo vypouštění přebytků.
- Bez proudu spojka nefunguje a segmenty zůstanou oddělené.

### Typické zapojení
```
 vstup ─[pumpa]─┐                      ┌─[pumpa]─ fabrika
 ════BUS════════╧═══[S]═══BUS═══…═══[S]╧══════BUS════
              segment 1   segment 2         segment N
 [S] = spojka busu; odbočky z běžných trubek patří do segmentu busu až po pumpu
```
Pumpa u fabriky odbočku od busu oddělí – návod doporučí stavět ji co nejblíž busu, aby odbočky
nezvětšovaly extent segmentu.

### Mimo rozsah v0.1
- Limit průtoku přes spojku (balanc) – připravit jako budoucí startup nastavení, v0.1 bez limitu.
- Spotřeba energie úměrná přenesenému množství (v0.1 konstantní odběr).
- Vlastní model trubky / spojky z Blenderu (v0.1 overlay „BUS“ + dočasná grafika spojky).
- Vyvýšená BUS trubka (integrace s modem Elevated pipes) – v0.2.
- Vlastní GUI panel spojky (v0.1 stačí stav entity a signály v obvodové síti).
- Řízení spojky obvodovou sítí (zapnout/vypnout) – v0.1 jen čtení.

## 2. Klíčová rozhodnutí

| Rozhodnutí | Volba | Důvod |
|---|---|---|
| Princip | síťové vyrovnání všech segmentů na stejné % | lokální obousměrné pumpy = pomalá difuze, úzké hrdlo 1200/s na spoj |
| Omezení „OP“ | spojka jen na BUS trubky přes `connection_category` | vynucuje engine při stavbě, nula UPS, hráč vidí hned, že se nenapojí |
| BUS trubky | generované z `data.raw` v `data-final-fixes.lua` | funguje s vanilla, Py, Bob i neznámými mody bez údržby |
| Parametry BUS trubky | zděděné z původní trubky | materiálové tiery (Py, Bob) zůstávají smysluplné |
| Grafika BUS trubky | vrstva původního spritu + náš overlay „BUS“ | jedna sada overlayů pro libovolnou trubku; cizí sprity nejde „ztloustnout“ |
| Redukce | **není** – BUS trubka se napojuje i na běžné | segment busu odděluje pumpa u fabriky, kterou hráči stejně staví |
| Přenos kapaliny | skript, rozložený po ticích, s „mezipamětí sítě“ (buffer) | žádné špičky ticku, přesné zachování množství i teploty |
| Topologie | rovná linka i větvení fungují stejně (graf segmentů) | bez limitu průtoku na tvaru nezáleží |
| Signál | jen čtení: % naplnění + množství | řízení fabrik/přebytků si hráč staví sám |

## 3. Prototypy (data stage)

### 3.1 Generování BUS trubek – `data-final-fixes.lua`
Čistá funkce `prototypes/bus_pipes.lua: collect(raw)` (testovatelná s falešným `data.raw`)
vrátí seznam párů, `create(raw, pairs)` z nich vytvoří prototypy.

**Výběr zdrojových trubek:**
1. Projde `raw.pipe`. Vyřadí trubku, pokud je `hidden` (vlastnost nebo `flags`), nemá předmět,
   který ji staví (`place_result`), nebo nemá **dostupný** recept (viz pravidla v skillu: ignorovat
   `hidden` recepty – recyklace; recept `enabled` nebo odemykaný nevyřazeným výzkumem).
2. Vyřadí naše vlastní prototypy (podle seznamu, ne podle prefixu jména) a `infinity-pipe`
   (jiný typ, ale pro jistotu i jména z `raw["infinity-pipe"]`).
3. **Párování s podzemní trubkou:** pro každou `raw["pipe-to-ground"]` (stejné filtry) hledá
   recept, který ji vyrábí; jeho **surovina typu předmět stavějící trubku z kroku 1** určuje pár.
   Vanilla, Py (`niobium-pipe` → `niobium-pipe-to-ground`, `ht-pipes` → `ht-pipes-to-ground`)
   i Bob tímto pravidlem projdou. Podzemní bez páru se vynechá (log), trubka bez podzemní dostane
   jen BUS trubku.
4. Výsledek se zapíše do logu data stage (`log(...)`): každý pár, recept a výzkum.

**Co vznikne pro každý pár:** `fb-bus-<jméno trubky>` (+ `fb-bus-<jméno podzemní>`) –
entita (`table.deepcopy` původní), předmět, recept.
- **Kategorie napojení:** každému nadzemnímu `pipe_connection` se nastaví
  `connection_category = původní ∪ {"fb-bus"}` (chybějící = `{"default"}`). Podzemní spoj
  (`connection_type = "underground"`) zůstane beze změny – engine u něj povoluje nejvýš jednu kategorii
  (ověřeno 2.0.77) a spojka se na něj stejně nenapojuje. Engine podporuje
  víc kategorií na konektor (vanilla Space Age tak upravuje `infinity-pipe`,
  `data/space-age/base-data-updates.lua:238`; Py používá vlastní kategorie u niobium/ht trubek).
- **Zděděno:** `fluid_box` (volume, `max_pipeline_extent`, podzemní dosah), zdraví, odolnosti,
  rozměry, `fast_replaceable_group` (= přestavění přes původní trubku, upgrade planner).
- **Vynulováno:** `next_upgrade` (cizí řetěz upgradů nepřebíráme), `minable.result` → náš předmět.
- **Lokalizace:** `{"entity-name.fb-bus-pipe", <lokalizovaný název původní trubky>}` →
  „BUS: Niobiová trubka“. Stejně pro předmět.
- **Grafika:** každý obrázek z `pictures` se obalí do `layers = { původní, overlay }`, aby byla
  BUS trubka na první pohled odlišitelná od běžné **na každém kusu**:
  - rovné kusy (`straight_vertical*`, `straight_horizontal*`) → nápis **„BUS“**,
  - všechny ostatní tvary (rohy, T, kříž, konce, samostatný kus) → písmeno **„B“**,
  - podzemní trubka (vstup/výstup) → **„B“**,
  - ikona: `icons = { původní ikona(y), overlay "B" }`.

  Overlay je samostatné PNG (bílé písmo s tmavým obrysem, čitelné na libovolné barvě materiálu).
  Pozice nápisu na každém tvaru je laditelná konstanta (tabulka `OVERLAY_SHIFT` v
  `prototypes/bus_overlay.lua`). Výchozí je střed kusu. Svítící (fluorescentní) pruh pro noc je
  mimo rozsah v0.1.
- **Recept:** 1× původní trubka + 1× surovina značení (kandidáti `{"steel-plate", "iron-plate"}`,
  první existující) → 1× BUS trubka. Podzemní: 2× původní podzemní + 2× surovina → 2× BUS
  podzemní. Laditelné konstanty nahoře v `prototypes/bus_pipes.lua`.

### 3.2 Spojka busu – `data.lua`
Jedna entita `fb-bus-coupler` (+ předmět, recept).
- 1×1, dva **oddělené** fluidboxy na protilehlých stranách (sever/jih, rotace R mění osu),
  konektory `connection_category = {"fb-bus"}` – na běžnou trubku, stroj ani pumpu se nenapojí.
- Elektřina: konstantní odběr (startup nastavení, výchozí 50 kW). Bez proudu je spojka neaktivní.
- Konektory obvodové sítě (červený/zelený drát).
- **Typ prototypu vybere spike (fáze 0).** Kandidáti:
  1. `assembling-machine` bez receptu, `fluid_boxes_off_when_no_fluid_recipe = false`,
     signály přes skrytý `constant-combinator` připojený drátem s `defines.wire_origin.script`;
     energii strhává skript z `entity.energy` (stroj bez receptu neodebírá).
  2. `pump` upravená na 1×1, `disabled_by_script` (vlastní čerpání vypnuté).
  Kritéria: dva oddělené segmenty, rotace, blueprint, napájení a jeho detekce, dráty, stav
  entity (`custom_status`).
- Dočasná grafika: obarvená vanilla pumpa / trubka, finální model v0.2.
- Recept: kandidáti `{"pump"}` 1×, `{"electronic-circuit"}` 5×, `{"steel-plate"}` 5×.

### 3.3 Signál
Vlastní `virtual-signal` `fb-fill` („Naplnění busu, %“). Množství se vysílá signálem dané kapaliny.

### 3.4 Startup nastavení (`settings.lua`)
| Název | Typ | Výchozí | Význam |
|---|---|---|---|
| `fb-coupler-power` | double (kW) | 50 | odběr spojky |
| `fb-balance-interval` | int (ticky) | 60 | za kolik ticků projde vyrovnání celou sítí |

### 3.5 Výzkum
Podle pravidel skillu (vlastní výzkum, prerekvizity dopočítané, cena z prerekvizit).
- **`fb-fluid-bus`** – odemyká spojku a BUS varianty trubek, které jsou dostupné od začátku nebo
  jejichž výzkum je v uzávěru prerekvizit. Prerekvizity: výzkum pumpy (`fluid-handling` ve vanilla)
  + výzkumy surovin spojky.
- **`fb-fluid-bus-<trubka>`** – pro každou zdrojovou trubku odemykanou pozdějším výzkumem
  (Py niobium, ht; Bob tiery). Prerekvizity: `fb-fluid-bus` + výzkum původní trubky + výzkumy
  surovin receptu; vyřadit tranzitivně zbytečné. Ikona = ikona BUS trubky.

### 3.6 Sdílená data pro runtime
`mod-data` `fb-data`: `{ bus_pipes = {jména}, couplers = {"fb-bus-coupler"} }` – runtime ani testy
nehledají naše prototypy podle prefixu (Py přidává recepty `<předmět>-pyvoid`).

## 4. Runtime (control stage)

### 4.1 Moduly (`scripts/`)
| Modul | Odpovědnost |
|---|---|
| `registry.lua` | evidence spojek (`storage.couplers[unit_number]`), stavba/odstranění |
| `topology.lua` | segmenty a sítě (graf: segment = uzel, spojka = hrana), přepočet při změně |
| `balancer.lua` | rozložené vyrovnávání, buffer sítě, teplota |
| `signals.lua` | zápis % a množství do obvodové sítě |
| `power.lua` | detekce napájení a strhávání energie (podle typu ze spiku) |
| `status.lua` | `custom_status` spojky (síť, % naplnění, chyby) |
| `remote.lua` | remote interface `fb` (testy, jiné mody) |

`control.lua` jen napojuje události na moduly.

### 4.2 Topologie
- Každá spojka má dva fluidboxy → dvě ID segmentů (`LuaFluidBox.get_fluid_segment_id`).
- Segmenty se mění bez události (hráč postaví/zboří trubku kdekoli). Proto **spojka při svém
  zpracování znovu přečte ID svých segmentů**; když se změnila, síť se označí jako špinavá
  a přepočítá (union-find v čisté Lua nad `storage`, bez API volání).
- Síť = komponenta grafu. Pro každý segment se zvolí **zástupce**: BUS trubka sousedící se spojkou
  (`fluidbox.get_connections(i)[1].owner`), přes kterou se segment čte a zapisuje (viz 8.1).
- **Konflikt kapalin:** segmenty sítě s různými kapalinami (prázdné nevadí) → síť se zastaví,
  spojky ukážou stav „Různé kapaliny v síti“. Nic se nepřelévá.
- Spojka bez proudu = chybějící hrana (síť se rozpadne na části).

### 4.3 Vyrovnávání (balancer)
Cíl: všechny segmenty sítě na stejné naplnění `f = (Σ množství + buffer) / Σ kapacita`.

- Práce je **rozložená**: segmenty všech sítí jsou v plánovači po ticích tak, aby každý přišel
  na řadu jednou za `fb-balance-interval` ticků. Žádná špička, i když má síť stovky segmentů.
- Zpracování segmentu: přečte množství, teplotu a kapacitu (`get_fluid_segment_contents`,
  `get_capacity`, fluidbox), spočítá cíl `f × kapacita`:
  - nad cílem → přebytek odebere do **bufferu sítě** (v `storage`),
  - pod cílem → doplní z bufferu, kolik buffer má.
  Množství se tak **přesně zachovává** (nic nevzniká ani nemizí), jen se přechodně drží v bufferu.
- `f` se aktualizuje průběžně z posledních hodnot každého segmentu (klouzavý součet).
- **Teplota:** buffer drží vážený průměr teploty přijaté kapaliny; doplnění vkládá kapalinu
  s teplotou bufferu → v segmentu se engine smíchá stejně jako ve vanille.
- **Zánik sítě / odstranění spojky:** zbytek bufferu se vrátí do segmentů sítě (kolik se vejde);
  co se nevejde, propadne (log). Buffer je malý (≈ jeden interval přelévání).
- Uspávání: síť, jejíž segmenty jsou všechny v toleranci (výchozí ±1 % kapacity), prodlouží
  interval na 4× (probudí ji odchylka nebo změna topologie).

### 4.4 Signály a stav
- Každá spojka vysílá `fb-fill` = round(f × 100) a `[kapalina]` = Σ množství sítě (+ buffer).
- `custom_status`: „Síť: N segmentů, X %“ / „Bez proudu“ / „Různé kapaliny v síti“ /
  „Nepřipojeno k BUS trubce“.

### 4.5 Životní cyklus
- Všechny cesty stavby/odstranění: hráč, robot, platforma, `script_raised_*`, `on_entity_died`;
  rotace (změna osy = nové segmenty). Event filtry na `fb-bus-coupler`.
- Blueprint / copy-paste: spojka nemá vlastní nastavení → nic k přenosu.
- `on_configuration_changed`: doplnit tabulky, uklidit neplatné spojky, přestavět topologii
  a plán. Starší save musí projít.
- Determinismus: stav jen ve `storage`, `on_load` ho nemění.

## 5. Výkon
Cíl (ověřuje výkonový test): **1000 spojek / ~110 segmentů na síť ≤ 1 ms/tick průměrně,
bez špiček > 2 ms**. Odhad: zpracování segmentu ≈ 5–10 volání API (10–20 µs), při intervalu
60 ticků a rozložení ≈ jednotky segmentů na tick.

## 6. Kompatibilita
- **Vanilla, Space Age:** integrační testy (obě varianty).
- **Pyanodon** (nainstalovaný u uživatele): niobium a ht trubky mají vlastní kategorie napojení
  a extent 640/1280 – BUS varianty je musí zachovat. Test `mods pymodpack`.
- **Bob's Logistics** (nainstalovaný): materiálové tiery trubek. Test `mods boblogistics`.
- **Pipe Tiers** (nainstalovaný): mění extent trubek – BUS varianta převezme hodnotu.
- Výsledky (s čím, kdy, jaké páry vznikly) do `docs/development.md` a `docs/mod-portal.md`.

## 7. Testy
1. **Unit** (Lua 5.3): `collect` nad falešným `data.raw` – filtry (hidden, bez receptu, recyklace),
   párování trubka↔podzemní, kategorie (chybějící = default, vlastní Py), recepty, výzkumy;
   union-find topologie; matematika bufferu (zachování množství, vážená teplota); locale klíče.
2. **Integrační** (headless, vanilla + Space Age): BUS trubky vznikly a mají kategorii; spojka se
   nenapojí na běžnou trubku; vyrovnání dvou a N segmentů; zdroj na jednom konci, spotřeba na
   druhém; pára (teplota); konflikt kapalin; výpadek proudu; stavba/zboření trubky uprostřed sítě;
   odstranění spojky (zachování množství).
3. **Kompatibilita:** `mods pymodpack`, `mods boblogistics` – obecné kontroly (páry vznikly,
   každý recept má výzkum, suroviny vyrobitelné).
4. **Výkon:** scénář s dlouhým busem a 1000 spojkami, ms/tick proti vanilla pumpám.

## 8. Fáze 0 – spike (první krok, kód se zahodí)
Ověřit headless testem dřív, než vznikne zbytek modu:
1. **Čtení segmentu přes fluidbox spojky:** množství, teplota, kapacita celého segmentu.
2. **Zápis do segmentu:** jde přidat/odebrat víc, než je objem fluidboxu spojky
   (`set_fluid` „může odmítnout nad objem fluidboxu“)? Když ne → velký `volume` fluidboxu spojky,
   nebo víc zápisů. **Na tomhle stojí celý návrh.**
3. **Typ prototypu spojky** (kandidáti v 3.2): dva oddělené segmenty, napájení, dráty, rotace.
4. **Kategorie napojení:** vygenerovaná BUS trubka se napojí na běžnou trubku; spojka na běžnou ne.
5. **Upgrade planner** z běžné trubky na BUS (stejná `fast_replaceable_group`) – ručně ve hře.

### 8.1 Výsledky spiku (2.0.77, vanilla i Space Age, 2026-10-04)

| Otázka | Zjištění | Rozhodnutí |
|---|---|---|
| Q1 čtení | `get_fluid_segment_contents` přes fluidbox spojky vrací obsah **celého segmentu**. `get_capacity` přes fluidbox **stroje** vrací jen objem jeho boxu; přes **trubku** vrací kapacitu celého segmentu (50 trubek + box spojky = 6000). `fluidbox[1]` trubky vrací její podíl **včetně teploty**. | Množství, kapacitu i teplotu číst přes **sousední BUS trubku**. |
| Q2 zápis | Zápis přes fluidbox spojky (`fluidbox[i] =`, `set_fluid`, `insert_fluid`) plní jen vlastní box stroje (max. objem) a do potrubí se **nepřelije** (stroj bez receptu neproudí). `insert_fluid` / `remove_fluid` na **trubce** pracuje s **celým segmentem**: vloženo 3000 přes jednu trubku, přeplnění se ořízne na kapacitu, odebrání 2000 přes vzdálenou trubku. Vložení jiné kapaliny vrátí 0. | Zapisovat přes **sousední BUS trubku** (`fluidbox.get_connections(i)[1].owner`). Návrh je proveditelný. |
| Teplota | Vložení páry 165 °C do páry 500 °C (1000 + 1000) dá 332,5 °C – vážený průměr dělá engine sám. `remove_fluid` teplotu nevrací. | Teplotu bufferu brát z `fluidbox[1].temperature` trubky před odebráním. |
| Q3 typ | `assembling-machine` 1×1 bez receptu: dva fluidboxy v **různých** segmentech, energie z napájení (`energy > 0`, stav `no_recipe`), konektor drátů existuje, `rotate()` funguje. Pumpa 1×1 má jen **jeden** fluidbox bez segmentu → druhou stranu nevidí. | Spojka = `assembling-machine` (kandidát 1). Box spojky malý objem – započítá se do kapacity segmentu. Odběr energie strhává skript. |
| Q4 kategorie | Spojka s kategorií `fb-bus` mezi běžnými trubkami: 0 napojení. BUS trubka `{default, fb-bus}` vedle běžné: napojí se. | `connection_category` funguje dle návrhu. |
| Q5 upgrade planner | Ruční kontrola ve hře po Task 8 (BUS trubky vzniknou). | – |

**Dopad na návrh:** sekce 3.2 a 4.3 platí s tím, že čtení i zápis jdou přes **zástupnou BUS trubku**
sousedící se spojkou (místo fluidboxu spojky). Spojka bez sousední BUS trubky na dané straně = hrana
chybí (stav „Nepřipojeno k BUS trubce“).

## 9. Grafika
- v0.1: overlay „BUS“ (PNG, průmyslové značení) z Blenderu nebo 2D; ikona spojky; thumbnail
  144×144.
- v0.2: model spojky z Blenderu (projekce dle skillu), případně vyvýšená BUS trubka.

## 10. Dokumentace a vydání
Podle skillu: `README.md`, `docs/user-guide.md` (CZ, včetně doporučeného zapojení), 
`docs/development.md` (CZ, tabulka „Kde ladit hodnoty“, výsledky testů a výkonu, checklist ruční
kontroly), `docs/mod-portal.md` (EN, schéma „dřív → teď“, benchmark, kompatibilita),
`changelog.txt`, locale `en` + `cs`. Publikace přes `tools/publish.sh` až na pokyn.

**Návod pro hráče je součást produktu, ne doplněk.** Mechanika je nová, takže `docs/user-guide.md`
i `docs/mod-portal.md` musí obsahovat:
1. **Jak poznat BUS trubku:** „BUS“ na rovných kusech, „B“ na ostatních (obrázek).
2. **Postup krok za krokem:** postav bus z BUS trubek (nebo přestav stávající přes upgrade
   planner), místo dosavadních pump vlož spojky, připoj elektřinu, vstupy a výstupy připoj přes
   běžnou trubku a **pumpu co nejblíž busu**.
3. **Schéma zapojení** (ASCII i screenshot) a „dřív → teď“.
4. **Časté chyby:** spojka na běžné trubce (nenapojí se), chybí proud, dvě kapaliny v jedné síti,
   míchání páry různých teplot, dlouhé odbočky bez pumpy (extent segmentu).
5. **Obvodová síť:** příklad „spal přebytek nad 90 %“ a „zapni záložní zdroj pod 30 %“.

Hra sama hráči pomůže: popis předmětu spojky a BUS trubky (`item-description`) stručně vysvětlí,
kam patří, a stav spojky (4.4) říká, co je špatně.
