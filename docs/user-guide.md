# Fluid Bus – návod pro hráče

Mod řeší dlouhý kapalinový „main bus“. Ve Factoriu 2.0 se dlouhé potrubí dělí pumpami na segmenty
(segment smí mít nejvýš 320 políček) a pumpa tlačí jen jedním směrem a nejvýš 1200/s. Vedlejší zdroj
pak nezásobí nic „proti proudu“, před pumpou se bus přeplní a za ní chybí kapalina.

**Spojka busu** propojí všechny segmenty BUS trubek do jedné sítě a průběžně jim srovnává naplnění –
celý bus se chová jako **jedna nádrž**, bez ohledu na délku a na to, kde jsou vstupy a výstupy.

## Jak poznat BUS trubku
BUS trubka je kopie běžné trubky (vanilla i z modů – Pyanodon, Bob's…) se stejnými parametry.
Pozná se podle **černého nastříkaného „B“** na rovných kusech, kusech s okénkem, T-kusech a kříži
(na svislých otočené) a na podzemních
trubkách. V menu stavby má ikona „B“ v rohu. Jmenuje se „BUS: <původní trubka>“.

**BUS trubka se napojí jen na BUS trubky, spojku busu a pumpu** – na běžnou trubku, nádrž ani stroj ne.
Pumpa je jediný přechod mezi busem a běžným potrubím. **Spojka busu se napojí jen na BUS trubky.**

> **Přechod z verze 0.1:** od 0.2.0 se BUS trubka nenapojí na běžnou trubku, nádrž ani stroj. Ve
> stávajícím savu se taková napojení po aktualizaci rozpojí – mezi bus a běžné potrubí dej pumpu.

## Postup krok za krokem
1. Vyzkoumej **Kapalinový bus** (ve vanille po pokročilých obvodech, v modech po výzkumech surovin
   spojky). Trubky z modů za pozdějším výzkumem mají vlastní
   výzkum „Kapalinový bus: <trubka>“.
2. Postav bus z **BUS trubek** – nebo stávající bus **přestav**: BUS trubku můžeš postavit přímo přes
   běžnou (kapalina zůstane), případně použij upgrade planner (trubka → BUS: trubka).
3. **Místo dosavadních pump** v busu vlož **spojky busu** (1×1, natočené po směru busu).
4. Spojky **připoj k elektřině** (výchozí odběr 50 kW). Bez proudu spojka nefunguje.
5. Vstupy a výstupy připoj **pumpou přímo na BUS trubku** (jinak se na bus nenapojí) a za ní běžnou
   trubkou. Pumpa zároveň odbočku od busu oddělí, takže nezvětšuje segment busu (limit 320 políček).

```
 dřív:  zdroj ─══════[P]══════[P]══════[P]══════─ (kapalina teče jen doprava, max 1200/s)

 teď:   vstup ─[pumpa]─┐                    ┌─[pumpa]─ fabrika
        ═══B═══════════╧═══[S]═══B═══…═══[S]╧══════B═══
           segment 1         segment 2           segment N
        [S] = spojka busu   B = BUS trubka      celý bus = jedna nádrž
```

## Stav spojky
Kontrolka na elektrické skříňce spojky: **zelená** = má proud a pracuje, **žlutá** = málo proudu,
**červená** = bez proudu. V noci svítí.

Kliknutím na spojku se otevře její okno (rozvržení jako u inserteru):
- **vlevo** stav s barevnou tečkou, náhled spojky, **Síť: N segmentů**, **Naplnění** a **Množství**
  (u spojky mimo síť naplnění obou stran) a elektřina,
- **vpravo** panel **Připojení obvodu** (přepíná se tlačítkem v titulku): čísla sítí připojených drátem,
  **Povolit/Zakázat** s podmínkou a co spojka vysílá.

Stavy spojky:
- **Bus: N segmentů, X %** – vše v pořádku, síť má N segmentů naplněných na X %.
- **Bez proudu** – spojka nemá elektřinu, segmenty na jejích stranách zůstanou oddělené.
- **Vypnuto obvodovou sítí** – podmínka Povolit/Zakázat není splněná.
- **Nepřipojeno k BUS trubce** – na jedné ze stran chybí BUS trubka (běžná trubka se nenapojí).
  Spojka pracuje, jen když má BUS trubku na **obou** stranách.
- **V síti busu jsou různé kapaliny** – ve spojených segmentech jsou dvě kapaliny; nic se nepřelévá,
  dokud jednu z nich neodstraníš.

## Obvodová síť
Spojka vysílá jediný signál na **zeleném drátu**: **[kapalina] = naplnění v %** (0–100), pod ikonou
kapaliny, která busem teče (voda, ropa, pára…).
- Zapnutá spojka posílá naplnění celé sítě.
- Vypnutá (nebo nenapájená) spojka posílá naplnění **plnější ze svých dvou stran** – díky tomu ji
  podmínka „[voda] > 50“ umí zase zapnout.

Signály stejné barvy se ve Factoriu sčítají – zelený drát od spojky proto nevěď do sítě, kde už je
stejná kapalina z jiného zdroje (např. z nádrže), jinak se procenta sečtou.

Příklady (zelený drát ze spojky):
- **Spal / vylij přebytek jen nad 90 %**: zelený drát do pumpy u spalovny, podmínka „[voda] > 90“.
- **Zapni záložní zdroj pod 30 %**: zelený drát do pumpy záložního zdroje, podmínka „[voda] < 30“.

### Řízení spojky
Bez podmínky spojka pracuje pořád (stačí proud a BUS trubky na obou stranách).
- **Povolit/Zakázat** – v okně spojky zaškrtni „Povolit/Zakázat“ a nastav podmínku (jako u pumpy).
  Vypnutá spojka nepřelévá, segmenty na jejích stranách se oddělí a stav ukáže **Vypnuto obvodovou
  sítí** (žlutá kontrolka). Hodí se např. k odstavení části busu při údržbě.
- **Přednostní plnění (přepad)** – podmínka **„[voda] > 50“**: dokud není bus aspoň na jedné straně
  spojky z poloviny plný, strany zůstanou oddělené; nad 50 % se spojí a srovnají (klesne-li pak
  naplnění pod 50 %, spojka se zase vypne – pulzuje, to je v pořádku). Funguje **i bez drátů** –
  spojka vidí svůj vlastní signál. Hodí se, když má mít část busu (např. elektrárna) přednost.
- **Interval vyrovnávání** – pošli do spojky signál **Interval vyrovnávání busu** (ikona hodin)
  s hodnotou N (1–600): celá její síť se pak vyrovnává každých N ticků místo nastavení mapy.
  Pošle-li se do jedné sítě víc hodnot, platí nejmenší. Bez signálu (nebo 0) platí nastavení mapy.
  Příklad: v noci, kdy bus jen stojí, pošli 60 a ušetříš výkon; při špičce 2.

Spojka změnu podmínky nebo signálu zaregistruje do **1 sekundy**.

## Časté chyby
- **Spojka na běžné trubce** – nenapojí se; vyměň trubky kolem spojky za BUS trubky.
- **BUS trubka vedle běžné trubky nebo nádrže** – nenapojí se; mezi bus a běžné potrubí patří pumpa.
- **Chybí proud** – stav „Bez proudu“.
- **Dvě kapaliny v jedné síti** – stav „Různé kapaliny“; každá kapalina potřebuje vlastní bus.
- **Pára různých teplot** v jedné síti se smíchá (vážený průměr) – pára 165 °C z kotlů a 500 °C
  z výměníků veď zvlášť, jinak turbíny vyrobí méně energie.
- **Dlouhé odbočky bez pumpy** zvětšují segment busu – pumpu dej hned u busu.
- **Dvě spojky těsně vedle sebe** nefungují (stav „Nepřipojeno k BUS trubce“) – mezi spojkami musí být
  aspoň jedna BUS trubka.

## Nastavení modu
- **Odběr spojky busu (kW)** – Nastavení → Mody → Při spuštění, výchozí 50.
- **Interval vyrovnávání (ticky)** – Nastavení → Mody → **Mapa**, mění se **za běhu** (i na serveru),
  výchozí 5. Spojka každých N ticků srovná celou síť najednou – po vyrovnání mají všechny segmenty
  stejné procento naplnění.
  - **Menší interval** = menší výkyvy mezi segmenty a vyšší propustnost, ale víc práce pro hru.
  - **Větší interval** = levnější, ale mezi vyrovnáními se segmenty víc rozejdou.

### Rychlé pumpy (mody s pumpami 12 000/s apod.)
Spojka nemá pevný strop průtoku. Mezi dvěma vyrovnáními se ale přítok a odběr musí vejít do segmentů:
naplnění se rozejde zhruba o **2 × průtok × interval / kapacita segmentu**. Příklad pro 12 000/s
a interval 5 ticků: segment o 100 trubkách ±10 %, o 300 trubkách ±3 %. Dlouhé segmenty busu tedy
zvládnou i velmi rychlé pumpy; u krátkých segmentů a velkých průtoků zmenši interval.

## Výkon
Bus se 110 spojkami (interval 5) stojí skript v průměru ~0,08 ms na tick, nejhůř ~0,4 ms
(Factorio 2.0.77). Extrémní bus s 1000 spojkami v jedné síti stojí ~3 ms jednou za interval – u takového
busu interval zvětši.
