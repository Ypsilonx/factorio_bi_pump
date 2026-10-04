# Fluid Bus – fáze 0 (spike) a fáze 1 (BUS trubky) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ověřit technickou proveditelnost spojky (spike) a postavit první funkční část modu:
generované BUS varianty všech trubek ve hře (vanilla i mody) s kategorií napojení `fb-bus`,
označením „BUS“/„B“, recepty a výzkumy, otestované ve vanilla, Space Age, Pyanodon a Bob's.

**Architecture:** Spike je samostatný zahazovací mod v `spike/` spouštěný headless Factoriem.
Mod `fluid-bus/` generuje BUS trubky v `data-final-fixes.lua` z čistých Lua modulů
(`prototypes/availability.lua`, `bus_pipes.lua`, `bus_overlay.lua`, `research.lua`), které se testují
mimo hru s falešným `data.raw`. Herní chování ověřují integrační testy v testovacím modu.

**Tech Stack:** Factorio 2.0.77 (Lua 5.2 ve hře), Lua 5.3 pro unit testy, Git Bash skripty,
Blender (headless, Workbench) pro PNG overlaye.

**Spec:** `docs/superpowers/specs/2026-10-04-fluid-bus-design.md`

**Rozsah:** Tento plán pokrývá spec sekce 3.1, 3.5 (bez spojky), 3.6, 6, 7 (část BUS trubek) a 8.
Spojka, runtime (sekce 3.2–3.4, 4, 5), grafika spojky a publikační dokumentace jsou v **plánu 2**,
který se napíše až podle výsledků spiku (typ prototypu a způsob zápisu do segmentu ovlivní celý
runtime).

## Global Constraints

- Factorio 2.0 (testováno na 2.0.77), funguje se Space Age i bez něj.
- Interní jméno modu `fluid-bus`, prefix prototypů `fb-`, tag logu testů `FB` (pracovní jméno – před
  publikací se může změnit záměnou textu).
- Kategorie napojení: `fb-bus`. Jména: `fb-bus-<jméno původní entity>`, výzkumy `fb-fluid-bus`
  a `fb-fluid-bus-<jméno původní trubky>`, mod-data `fb-data`.
- Komentáře a docstringy v kódu česky (`---` + `@param`/`@return`). Locale `en` i `cs` se stejnými
  klíči. Veřejné texty (info.json, changelog) anglicky.
- Autor `Ypsilonx`, licence MIT.
- Naše prototypy se v runtime/testech hledají podle `prototypes.mod_data["fb-data"]`, nikdy podle
  prefixu jména.
- **Commit jen na výslovný pokyn uživatele.** Kroky „Commit“ v tomto plánu znamenají: zkontrolovat
  `git status`, nabídnout uživateli commit s uvedenou zprávou a počkat. Zprávu zakončit řádky
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` a
  `Claude-Session: https://claude.ai/code/session_019Dq77DQiiRMGBdN1Dgm8iY`.
- Skripty `tools/*.sh` spouštět v Git Bash (Bash tool). `python` nepoužívat.
- Po sobě uklízet: žádné dočasné soubory mimo `.test-run/` (gitignored) a scratchpad.

## Review Focus

1. **Trubka z modu bez podzemní** (nebo podzemní s receptem, který trubku nepoužívá) → musí vzniknout
   aspoň BUS trubka a data stage nesmí spadnout. Test: Task 4, `collect` „trubka bez podzemní“.
2. **Konektor s vlastní kategorií** (Py `niobium`, `multipurpose`) → BUS varianta ji musí zachovat,
   jinak se BUS niobiová trubka nenapojí na běžnou niobiovou. Test: Task 5 „zachová kategorie Py“.
3. **Sprite s `layers` nebo podzemní ve formě `sheet`** (mody) → overlay nesmí rozbít prototyp; když
   nejde přidat, trubka zůstane bez označení a zapíše se do logu. Test: Task 6 „sheet se nezmění“.
4. **Recyklace Space Age** („vyrábí“ trubky skrytým receptem) → nesmí udělat trubku „dostupnou od
   začátku“, pokud není. Test: Task 3 „skrytý recept se ignoruje“.
5. **Hráč přestaví existující bus BUS trubkou** (rychlá výměna) → kapalina v segmentu zůstane.
   Test: Task 8 „rychlá výměna zachová kapalinu“.

---

### Task 1: Spike – ověření API a typu spojky (kód se zahodí)

**Files (dočasné, na konci tasku smazat):**
- Create: `spike/fb-spike/info.json`
- Create: `spike/fb-spike/data.lua`
- Create: `spike/fb-spike/control.lua`
- Create: `spike/run-spike.sh`
- Modify (trvale): `docs/superpowers/specs/2026-10-04-fluid-bus-design.md` – nová sekce
  „8.1 Výsledky spiku“

**Interfaces:**
- Consumes: nic.
- Produces: rozhodnutí zapsaná ve specifikaci: typ prototypu spojky, způsob zápisu do segmentu,
  maximální zápis na jedno volání, zda funguje `connection_category` na trubce.

**Otázky (z spec sekce 8):** Q1 čtení segmentu přes fluidbox spojky, Q2 zápis nad objem fluidboxu,
Q3 typ prototypu (dva oddělené segmenty, napájení, dráty, rotace), Q4 kategorie napojení,
Q5 upgrade planner (ručně ve hře – jen popsat postup uživateli).

- [ ] **Step 1: Vytvořit spike mod – `spike/fb-spike/info.json`**

```json
{
  "name": "fb-spike",
  "version": "0.0.1",
  "title": "Fluid Bus spike",
  "author": "Ypsilonx",
  "factorio_version": "2.0",
  "dependencies": ["base"]
}
```

- [ ] **Step 2: Prototypy kandidátů – `spike/fb-spike/data.lua`**

```lua
-- Spike: BUS trubka s kategorií napojení a dva kandidáti spojky (zahazovací kód).
local CAT = "fb-bus"

-- BUS trubka: kopie vanilla trubky, konektory {default, fb-bus}.
local bus = table.deepcopy(data.raw.pipe.pipe)
bus.name = "fb-spike-bus-pipe"
bus.minable = nil
bus.next_upgrade = nil
for _, connection in pairs(bus.fluid_box.pipe_connections) do
  connection.connection_category = { "default", CAT }
end

-- Kandidát A: assembling-machine 1×1 bez receptu se dvěma fluidboxy.
local am = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
am.name = "fb-spike-coupler-am"
am.minable = nil
am.next_upgrade = nil
am.fast_replaceable_group = nil
am.collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } }
am.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
am.crafting_categories = { "fb-spike" }
am.energy_usage = "50kW"
am.fluid_boxes_off_when_no_fluid_recipe = false
am.fluid_boxes = {
  {
    production_type = "input", volume = 1000,
    pipe_connections = { { flow_direction = "input-output", direction = defines.direction.north,
      position = { 0, 0 }, connection_category = { CAT } } },
  },
  {
    production_type = "output", volume = 1000,
    pipe_connections = { { flow_direction = "input-output", direction = defines.direction.south,
      position = { 0, 0 }, connection_category = { CAT } } },
  },
}

-- Kandidát B: pumpa zmenšená na 1×1.
local pump = table.deepcopy(data.raw.pump.pump)
pump.name = "fb-spike-coupler-pump"
pump.minable = nil
pump.fast_replaceable_group = nil
pump.collision_box = { { -0.29, -0.29 }, { 0.29, 0.29 } }
pump.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
pump.fluid_box.pipe_connections = {
  { direction = defines.direction.north, position = { 0, 0 }, flow_direction = "output", connection_category = { CAT } },
  { direction = defines.direction.south, position = { 0, 0 }, flow_direction = "input", connection_category = { CAT } },
}

data:extend({ { type = "recipe-category", name = "fb-spike" }, bus, am, pump })
```

- [ ] **Step 3: Měření – `spike/fb-spike/control.lua`**

```lua
-- Spike: postaví scény, změří čtení/zápis segmentů a vypíše řádky FB-SPIKE do logu.
local function out(label, value)
  log("FB-SPIKE " .. label .. " = " .. serpent.line(value))
end

--- Jméno stavu entity z defines.entity_status.
local function status_name(entity)
  for name, value in pairs(defines.entity_status) do
    if value == entity.status then return name end
  end
  return tostring(entity.status)
end

--- Svislá řada entit name na sloupci x pro y od y1 do y2.
local function line(surface, name, x, y1, y2)
  local list = {}
  for y = y1, y2 do
    list[#list + 1] = surface.create_entity({ name = name, position = { x + 0.5, y + 0.5 }, force = "player" })
  end
  return list
end

--- Napájení: sloup + nekonečný zdroj vedle spojky na (x, 0).
local function power(surface, x)
  surface.create_entity({ name = "small-electric-pole", position = { x + 1.5, 1.5 }, force = "player" })
  local eei = surface.create_entity({ name = "electric-energy-interface", position = { x + 3, 2 }, force = "player" })
  eei.electric_buffer_size = 1e9
  eei.power_production = 1e6
end

--- Popis všech fluidboxů entity: segment, kapacita, obsah, vlastní pohled, počet napojení.
local function describe(label, entity)
  local fb = entity.fluidbox
  out(label .. " #fluidbox", #fb)
  for i = 1, #fb do
    out(label .. " [" .. i .. "] segment", fb.get_fluid_segment_id(i))
    out(label .. " [" .. i .. "] capacity", fb.get_capacity(i))
    out(label .. " [" .. i .. "] contents", fb.get_fluid_segment_contents(i))
    out(label .. " [" .. i .. "] fluid", fb[i])
    out(label .. " [" .. i .. "] connections", #fb.get_connections(i))
  end
end

script.on_init(function()
  local s = game.surfaces[1]
  s.always_day = true
  storage.c = {}
  -- Scéna A (x=0) a B (x=10): BUS trubky – kandidát – BUS trubky, napájení.
  for _, scene in ipairs({ { key = "am", x = 0 }, { key = "pump", x = 10 } }) do
    local top = line(s, "fb-spike-bus-pipe", scene.x, -10, -1)
    storage.c[scene.key] = s.create_entity({ name = "fb-spike-coupler-" .. scene.key, position = { scene.x + 0.5, 0.5 }, force = "player" })
    line(s, "fb-spike-bus-pipe", scene.x, 1, 10)
    power(s, scene.x)
    top[1].insert_fluid({ name = "water", amount = 500 })
  end
  -- Scéna C (x=20): kandidát A mezi běžnými trubkami – nesmí se napojit.
  line(s, "pipe", 20, -3, -1)
  storage.c.am_plain = s.create_entity({ name = "fb-spike-coupler-am", position = { 20.5, 0.5 }, force = "player" })
  line(s, "pipe", 20, 1, 3)
  -- Scéna D (x=30): BUS trubka vedle běžné – musí se napojit.
  storage.c.bus_next_plain = s.create_entity({ name = "fb-spike-bus-pipe", position = { 30.5, 0.5 }, force = "player" })
  s.create_entity({ name = "pipe", position = { 30.5, 1.5 }, force = "player" })
  -- Scéna E (x=40): pára 500 °C – čtení teploty a zápis jiné teploty.
  local steam_top = line(s, "fb-spike-bus-pipe", 40, -5, -1)
  storage.c.steam = s.create_entity({ name = "fb-spike-coupler-am", position = { 40.5, 0.5 }, force = "player" })
  line(s, "fb-spike-bus-pipe", 40, 1, 5)
  power(s, 40)
  steam_top[1].insert_fluid({ name = "steam", amount = 200, temperature = 500 })
end)

script.on_nth_tick(60, function(event)
  local c = storage.c
  if event.tick == 60 then
    for _, key in ipairs({ "am", "pump" }) do
      local e = c[key]
      describe(key .. " start", e)
      out(key .. " energy", e.energy)
      out(key .. " status", status_name(e))
      out(key .. " red connector", e.get_wire_connector(defines.wire_connector_id.circuit_red, true) ~= nil)
      -- Zápis 1: přiřazení do fluidboxu nad jeho objem (1000).
      local ok, err = pcall(function() e.fluidbox[#e.fluidbox] = { name = "water", amount = 1500 } end)
      out(key .. " write fluidbox[last]=1500 ok", { ok, err })
      out(key .. " after write contents", e.fluidbox.get_fluid_segment_contents(#e.fluidbox))
      -- Zápis 2: insert_fluid / remove_fluid na entitě.
      out(key .. " insert_fluid 300", e.insert_fluid({ name = "water", amount = 300 }))
      out(key .. " remove_fluid 200", e.remove_fluid({ name = "water", amount = 200 }))
      -- Zápis 3: set_fluid do posledního úložiště.
      local ok3, res3 = pcall(function() return e.set_fluid(#e.fluidbox, { name = "water", amount = 5000 }) end)
      out(key .. " set_fluid(last, 5000)", { ok3, res3 })
      describe(key .. " after writes", e)
    end
    describe("am_plain", c.am_plain)
    describe("bus_next_plain", c.bus_next_plain)
    describe("steam start", c.steam)
    local ok, err = pcall(function() c.steam.fluidbox[2] = { name = "steam", amount = 100, temperature = 165 } end)
    out("steam write 165C ok", { ok, err })
  elseif event.tick == 120 then
    -- Přetrvá zápis i po simulaci enginu? Rotace mění segmenty?
    describe("am tick120", c.am)
    describe("pump tick120", c.pump)
    describe("steam tick120", c.steam)
    out("am rotate", c.am.rotate())
    describe("am rotated", c.am)
    out("DONE", true)
  end
end)
```

- [ ] **Step 4: Spouštěcí skript – `spike/run-spike.sh`**

```bash
#!/usr/bin/env bash
# Spike: vytvoří mapu jen se spike modem, odsimuluje 200 ticků a vypíše řádky FB-SPIKE.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO_EXE:-C:/STEAM/steamapps/common/Factorio/bin/x64/factorio.exe}"
VARIANT="${1:-vanilla}"
RUN="$ROOT/.test-run/spike-$VARIANT"
RUN_W="$(cygpath -m "$RUN")"
SA=false
[ "$VARIANT" = "space-age" ] && SA=true
rm -rf "$RUN"
mkdir -p "$RUN/mods" "$RUN/write-data"
cp -r "$ROOT/spike/fb-spike" "$RUN/mods/fb-spike"
cat > "$RUN/mods/mod-list.json" <<JSON
{"mods":[{"name":"base","enabled":true},{"name":"elevated-rails","enabled":$SA},{"name":"quality","enabled":$SA},
{"name":"space-age","enabled":$SA},{"name":"fb-spike","enabled":true}]}
JSON
cat > "$RUN/config.ini" <<INI
[path]
read-data=__PATH__executable__/../../data
write-data=$RUN_W/write-data
INI
ARGS=(--config "$RUN_W/config.ini" --mod-directory "$RUN_W/mods")
"$FACTORIO" "${ARGS[@]}" --create "$RUN_W/test.zip" > "$RUN/create.log" 2>&1 || true
[ -f "$RUN/test.zip" ] || { grep -A12 -E "Error|error" "$RUN/create.log" | head -40; exit 1; }
"$FACTORIO" "${ARGS[@]}" --benchmark "$RUN_W/test.zip" --benchmark-ticks 200 --disable-audio > "$RUN/bench.log" 2>&1 || true
grep -E "FB-SPIKE|Error" "$RUN/bench.log" | sed 's/.*FB-SPIKE/FB-SPIKE/'
```

Předtím vytvořit `.gitignore` s řádkem `.test-run/` a `spike/` (spike se nikdy necommituje).

- [ ] **Step 5: Spustit spike**

Run: `bash spike/run-spike.sh vanilla`
Expected: řádky `FB-SPIKE … = …` až po `FB-SPIKE DONE = true`. Pokud vytvoření mapy selže na
chybě prototypu (např. `flow_direction` u `output` fluidboxu, chybějící grafika pumpy 1×1), opravit
**jen spike** a spustit znovu; každou opravu zapsat do výsledků (je to zjištění o API).

- [ ] **Step 6: Vyhodnotit a zapsat výsledky do specifikace**

Přidat do specifikace za sekci 8 sekci „8.1 Výsledky spiku (2.0.77)“ s tabulkou
otázka → zjištění → rozhodnutí. Kritéria:
- **Q1:** `get_capacity`, `get_fluid_segment_contents` a `fluidbox[i]` (teplota) vracejí hodnoty
  **celého segmentu** (kapacita ≈ 10 trubek × 100 + objem fluidboxu kandidáta).
- **Q2:** který ze zápisů (`fluidbox[i] =`, `insert_fluid`, `remove_fluid`, `set_fluid`) změní obsah
  segmentu a kolik maximálně najednou; zda zápis přetrvá do ticku 120.
- **Q3:** kandidát má dva fluidboxy v **různých** segmentech, `energy > 0` při napájení, existuje
  konektor červeného drátu, `rotate()` funguje a změní segmenty. Pumpa (B) má pravděpodobně jen
  jeden fluidbox → pak je vybrán A.
- **Q4:** `am_plain` má 0 napojení na obou fluidboxech; `bus_next_plain` má ≥ 1 napojení.
- **Teplota:** zápis páry 165 °C do segmentu s 500 °C – jak se teplota změní.
- **Q5:** připravit pro uživatele postup ruční kontroly upgrade planneru (Task 8 dodá BUS trubky).

Pokud **Q2 selže úplně** (do segmentu nejde zapisovat skriptem žádným způsobem), **zastavit práci**
a probrat s uživatelem alternativy (spec sekce 1) – celý návrh na tom stojí.

- [ ] **Step 7: Úklid a checkpoint**

Smazat `spike/` a `.test-run/spike-*` (`rm -rf spike .test-run`). Ukázat uživateli výsledky
(tabulku 8.1) a počkat na potvrzení před Task 2.

---

### Task 2: Kostra projektu z šablon skillu

**Files:**
- Create: `fluid-bus/info.json`, `fluid-bus/changelog.txt`, `fluid-bus/data.lua`,
  `fluid-bus/data-final-fixes.lua`, `fluid-bus/control.lua`, `fluid-bus/locale/en/locale.cfg`,
  `fluid-bus/locale/cs/locale.cfg`
- Create (ze šablon `C:/Users/cibul/.claude/skills/factorio-mod/templates/`): `tools/run-unit.sh`,
  `tools/run-tests.sh`, `tools/link-mod.sh`, `tools/package.sh`, `tools/publish.sh`,
  `tests/unit/run.lua`, `tests/unit/assert.lua`, `tests/unit/test_locale.lua`,
  `tests/fluid-bus-tests/{control.lua,runner.lua,info.json,cases/smoke.lua}`, `.luacheckrc`,
  `.gitattributes`, `.gitignore`, `.vscode/tasks.json`, `.vscode/extensions.json`
- Modify: `.vscode/settings.json` (zachovat stávající obsah)
- Create: `README.md`

**Interfaces:**
- Produces: `tools/run-unit.sh` (výstup `UNIT pass=N fail=0`), `tools/run-tests.sh vanilla|space-age|mods …`
  (výstup `FB-TEST DONE pass=N fail=0 skip=M`), `tests/unit/run.lua` se seznamem `SUITES`,
  testovací mod `fluid-bus-tests` registrující cases v `control.lua`.

- [ ] **Step 1: Zkopírovat šablony a nahradit zástupné řetězce**

```bash
T="C:/Users/cibul/.claude/skills/factorio-mod/templates"
mkdir -p tools tests/unit tests/fluid-bus-tests/cases .vscode
cp "$T"/tools/*.sh tools/
cp "$T"/tests/unit/*.lua tests/unit/
cp "$T"/tests/integration/control.lua "$T"/tests/integration/runner.lua "$T"/tests/integration/info.json tests/fluid-bus-tests/
cp "$T"/tests/integration/cases/smoke.lua tests/fluid-bus-tests/cases/
cp "$T"/.luacheckrc "$T"/.gitattributes "$T"/.gitignore .
cp "$T"/vscode/tasks.json "$T"/vscode/extensions.json .vscode/
grep -rl "__MOD_NAME__\|__TEST_MOD__\|__TAG__\|__TAG_LOWER__\|__MOD_TITLE__" tools tests .vscode \
  | xargs sed -i 's/__MOD_NAME__/fluid-bus/g; s/__TEST_MOD__/fluid-bus-tests/g; s/__TAG_LOWER__/fb/g; s/__TAG__/FB/g; s/__MOD_TITLE__/Fluid Bus/g'
grep -rn "__PATH__executable__" tools/run-tests.sh   # token Factoria – musí zůstat beze změny
```

Do `.gitignore` přidat řádek `spike/`. Z `.vscode/tasks.json` odebrat úlohu „Výkonový test“
(`run-perf.sh` vznikne až v plánu 2) a přidat úlohy
`{ "label": "Kompatibilita (Pyanodon)", "type": "shell", "command": "tools/run-tests.sh mods pymodpack", "group": "test", "problemMatcher": [] }`
a totéž pro `boblogistics` s labelem „Kompatibilita (Bob's)“.

- [ ] **Step 2: `fluid-bus/info.json`**

```json
{
  "name": "fluid-bus",
  "version": "0.1.0",
  "title": "Fluid Bus",
  "author": "Ypsilonx",
  "factorio_version": "2.0",
  "description": "BUS variants of every pipe in the game. Bus couplers join all BUS pipe segments into one network with an even fill level – the whole main bus behaves like a single tank.",
  "dependencies": ["base >= 2.0.0"]
}
```

- [ ] **Step 3: `fluid-bus/changelog.txt`**

```
---------------------------------------------------------------------------------------------------
Version: 0.1.0
Date: 2026-10-04
  Features:
    - BUS variants of every pipe and underground pipe in the game, including pipes from other mods.
```

- [ ] **Step 4: Prázdné vstupní soubory a locale**

`fluid-bus/data.lua`:
```lua
-- Prototypy nezávislé na jiných modech (spojka – plán 2).
```
`fluid-bus/data-final-fixes.lua`:
```lua
-- Generování BUS trubek až po načtení všech modů, aby se zahrnuly i trubky z jiných modů.
```
`fluid-bus/control.lua`:
```lua
-- Runtime modu (spojka – plán 2). Jen napojuje události na moduly ze scripts/.
```
`fluid-bus/locale/en/locale.cfg`:
```
[mod-name]
fluid-bus=Fluid Bus

[mod-description]
fluid-bus=BUS variants of every pipe. Bus couplers join BUS pipe segments into one network with an even fill level.
```
`fluid-bus/locale/cs/locale.cfg`:
```
[mod-name]
fluid-bus=Fluid Bus

[mod-description]
fluid-bus=BUS varianty všech trubek. Spojky busu propojí segmenty BUS trubek do jedné sítě se stejným naplněním.
```

- [ ] **Step 5: `README.md`**

```markdown
# Fluid Bus (mod do Factoria 2.0)

BUS varianty všech trubek ve hře a spojka busu, která propojí segmenty BUS trubek do jedné sítě
se stejným naplněním – celý hlavní bus se chová jako jedna nádrž.

- Návrh: `docs/superpowers/specs/2026-10-04-fluid-bus-design.md`
- Plány: `docs/superpowers/plans/`

## Rychlý start vývoje
- Unit testy: `bash tools/run-unit.sh`
- Integrační testy: `bash tools/run-tests.sh vanilla` a `bash tools/run-tests.sh space-age`
- Kompatibilita: `bash tools/run-tests.sh mods pymodpack`, `bash tools/run-tests.sh mods boblogistics`
- Hrát rozpracovanou verzi: `bash tools/link-mod.sh` (junction do `%APPDATA%/Factorio/mods`)
```

- [ ] **Step 6: Ověřit kostru**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=1 fail=0`

Run: `bash tools/run-tests.sh vanilla` a pak `bash tools/run-tests.sh space-age`
Expected: v obou `FB-TEST PASS mod se načte a povrch existuje` a `FB-TEST DONE pass=1 fail=0 skip=0`.

- [ ] **Step 7: Commit (na pokyn uživatele)**

```bash
git add .gitignore .gitattributes .luacheckrc .vscode README.md fluid-bus tools tests docs
git commit -m "chore: kostra modu fluid-bus, nástroje a testy ze šablon"
```

---

### Task 3: Dostupnost předmětů (`prototypes/availability.lua`)

**Files:**
- Create: `fluid-bus/prototypes/availability.lua`
- Create: `tests/unit/fake_raw.lua` (sdílená stavebnice falešného `data.raw`)
- Create: `tests/unit/test_availability.lua`
- Modify: `tests/unit/run.lua` – `SUITES = { "test_locale", "test_availability" }`

**Interfaces:**
- Produces (modul `prototypes.availability`, žádné globály Factoria):
  - `sorted_keys(t) -> string[]`
  - `is_hidden(proto) -> boolean` (vlastnost `hidden` nebo `flags` obsahuje `"hidden"`)
  - `find_place_item(raw, entity_name) -> string|nil`
  - `tech_closure(raw, tech) -> table<string,true>`
  - `find_unlocking_tech(raw, recipe_name) -> string|nil`
  - `item_source(raw, item_name) -> recipe|nil, tech|nil` (tech nil = od začátku)
  - `copy(t) -> table` (hloubková kopie; unit testy nemají `table.deepcopy`)
- Produces (`tests/unit/fake_raw.lua`): `F.new() -> raw` (prázdné tabulky typů), `F.pipe(raw, name, opts)`,
  `F.underground(raw, name, opts)`, `F.item(raw, name, place_result)`, `F.recipe(raw, name, result, ingredients, opts)`,
  `F.tech(raw, name, recipes, prerequisites, unit)`.

- [ ] **Step 1: Stavebnice falešného data.raw – `tests/unit/fake_raw.lua`**

```lua
--- Stavebnice falešného data.raw pro unit testy generování (jen pole, která mod čte).
local F = {}

--- Prázdné data.raw se všemi typy, které mod prochází.
function F.new()
  return { pipe = {}, ["pipe-to-ground"] = {}, item = {}, recipe = {}, technology = {} }
end

--- Konektor trubky; category nil = výchozí kategorie.
local function connection(direction, category, underground)
  return { direction = direction, position = { 0, 0 }, connection_category = category,
    connection_type = underground and "underground" or nil, max_underground_distance = underground }
end

--- Přidá trubku. opts: hidden, category, extent.
function F.pipe(raw, name, opts)
  opts = opts or {}
  raw.pipe[name] = {
    type = "pipe", name = name, hidden = opts.hidden, fast_replaceable_group = "pipe",
    minable = { mining_time = 0.1, result = name },
    fluid_box = { volume = 100, max_pipeline_extent = opts.extent, pipe_connections = {
      connection(0, opts.category), connection(4, opts.category), connection(8, opts.category), connection(12, opts.category),
    } },
    pictures = { straight_horizontal = { filename = "h.png" }, corner_up_right = { filename = "c.png" } },
  }
  return raw.pipe[name]
end

--- Přidá podzemní trubku. opts: hidden, category, distance, pictures.
function F.underground(raw, name, opts)
  opts = opts or {}
  raw["pipe-to-ground"][name] = {
    type = "pipe-to-ground", name = name, hidden = opts.hidden, fast_replaceable_group = "pipe",
    minable = { mining_time = 0.1, result = name },
    fluid_box = { volume = 100, pipe_connections = {
      connection(0, opts.category), connection(8, opts.category, opts.distance or 10),
    } },
    pictures = opts.pictures or { north = { filename = "n.png" }, south = { filename = "s.png" },
      east = { filename = "e.png" }, west = { filename = "w.png" } },
  }
  return raw["pipe-to-ground"][name]
end

--- Přidá předmět stavějící entitu.
function F.item(raw, name, place_result)
  raw.item[name] = { type = "item", name = name, icon = name .. ".png", icon_size = 64,
    place_result = place_result, stack_size = 100, subgroup = "energy-pipe-distribution", order = "a" }
  return raw.item[name]
end

--- Přidá recept. ingredients = { {jméno, počet}… }. opts: enabled (výchozí true), hidden.
function F.recipe(raw, name, result, ingredients, opts)
  opts = opts or {}
  local list = {}
  for i, pair in ipairs(ingredients or {}) do list[i] = { type = "item", name = pair[1], amount = pair[2] } end
  raw.recipe[name] = { type = "recipe", name = name, enabled = opts.enabled ~= false and true or false,
    hidden = opts.hidden, ingredients = list, results = { { type = "item", name = result, amount = 1 } } }
  return raw.recipe[name]
end

--- Přidá výzkum odemykající recepty.
function F.tech(raw, name, recipes, prerequisites, unit)
  local effects = {}
  for i, recipe in ipairs(recipes or {}) do effects[i] = { type = "unlock-recipe", recipe = recipe } end
  raw.technology[name] = { type = "technology", name = name, effects = effects,
    prerequisites = prerequisites or {}, unit = unit }
  return raw.technology[name]
end

return F
```

- [ ] **Step 2: Failing testy – `tests/unit/test_availability.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy dostupnosti předmětů (recepty, výzkumy, skryté prototypy).
local A = require("assert")
local F = require("fake_raw")
local av = require("prototypes.availability")

local SCIENCE = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 10 }

return {
  { "předmět dostupný od začátku", function()
    local raw = F.new()
    F.item(raw, "pipe", "pipe")
    F.recipe(raw, "pipe", "pipe", { { "iron-plate", 1 } })
    local recipe, tech = av.item_source(raw, "pipe")
    A.eq(recipe, "pipe", "recept")
    A.eq(tech, nil, "výzkum")
  end },
  { "předmět za výzkumem", function()
    local raw = F.new()
    F.item(raw, "niobium-pipe", "niobium-pipe")
    F.recipe(raw, "niobium-pipe", "niobium-pipe", {}, { enabled = false })
    F.tech(raw, "niobium", { "niobium-pipe" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "niobium-pipe")
    A.eq(recipe, "niobium-pipe", "recept")
    A.eq(tech, "niobium", "výzkum")
  end },
  { "skrytý recept (recyklace) se ignoruje", function()
    local raw = F.new()
    F.item(raw, "x-pipe", "x-pipe")
    F.recipe(raw, "x-pipe", "x-pipe", {}, { enabled = false })
    F.recipe(raw, "x-pipe-recycling", "x-pipe", {}, { hidden = true })
    F.tech(raw, "x", { "x-pipe" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "x-pipe")
    A.eq(recipe, "x-pipe", "recept")
    A.eq(tech, "x", "výzkum")
  end },
  { "zamčený recept bez výzkumu = nedostupný", function()
    local raw = F.new()
    F.item(raw, "dead-pipe", "dead-pipe")
    F.recipe(raw, "dead-pipe", "dead-pipe", {}, { enabled = false })
    A.eq(av.item_source(raw, "dead-pipe"), nil, "recept")
  end },
  { "skrytý výzkum se nepočítá", function()
    local raw = F.new()
    F.item(raw, "p", "p")
    F.recipe(raw, "p", "p", {}, { enabled = false })
    F.tech(raw, "t", { "p" }, {}, SCIENCE).hidden = true
    A.eq(av.item_source(raw, "p"), nil, "recept")
  end },
  { "ze dvou výzkumů vyhraje ten s menším uzávěrem", function()
    local raw = F.new()
    F.item(raw, "p", "p")
    F.recipe(raw, "p-early", "p", {}, { enabled = false })
    F.recipe(raw, "p-late", "p", {}, { enabled = false })
    F.tech(raw, "a", {}, {}, SCIENCE)
    F.tech(raw, "b", {}, { "a" }, SCIENCE)
    F.tech(raw, "late", { "p-late" }, { "b" }, SCIENCE)
    F.tech(raw, "early", { "p-early" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "p")
    A.eq(recipe, "p-early", "recept")
    A.eq(tech, "early", "výzkum")
  end },
  { "tech_closure sbírá nepřímé prerekvizity", function()
    local raw = F.new()
    F.tech(raw, "a", {}, {}, SCIENCE)
    F.tech(raw, "b", {}, { "a" }, SCIENCE)
    F.tech(raw, "c", {}, { "b" }, SCIENCE)
    local set = av.tech_closure(raw, "c")
    A.truthy(set.a and set.b, "a i b v uzávěru")
    A.eq(set.c, nil, "výzkum sám v uzávěru není")
  end },
  { "is_hidden podle vlastnosti i flags", function()
    A.truthy(av.is_hidden({ hidden = true }), "hidden = true")
    A.truthy(av.is_hidden({ flags = { "placeable-neutral", "hidden" } }), "flags hidden")
    A.eq(av.is_hidden({ flags = { "placeable-neutral" } }), false, "běžný prototyp")
  end },
  { "find_place_item najde předmět podle place_result", function()
    local raw = F.new()
    F.item(raw, "pipe-item", "pipe")
    A.eq(av.find_place_item(raw, "pipe"), "pipe-item", "předmět")
    A.eq(av.find_place_item(raw, "nic"), nil, "neexistující entita")
  end },
}
```

- [ ] **Step 3: Spustit – musí selhat**

Run: `bash tools/run-unit.sh`
Expected: FAIL – `module 'prototypes.availability' not found`.

- [ ] **Step 4: Implementace – `fluid-bus/prototypes/availability.lua`**

```lua
--- Čistá logika dostupnosti: jak hráč k předmětu přijde (recept od začátku, nebo přes výzkum).
--- Nepoužívá globály Factoria, aby šla testovat mimo hru (tests/unit/test_availability.lua).
local M = {}

--- Vrátí klíče tabulky seřazené abecedně (deterministické pořadí v data stage).
--- @param t table|nil
--- @return string[]
function M.sorted_keys(t)
  local keys = {}
  for key in pairs(t or {}) do keys[#keys + 1] = key end
  table.sort(keys)
  return keys
end

--- Hloubková kopie tabulky (data stage má table.deepcopy, unit testy ne).
--- @param t any
--- @return any
function M.copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for key, value in pairs(t) do out[key] = M.copy(value) end
  return out
end

--- Je prototyp skrytý? (vlastnost `hidden` ve 2.0, příznak `hidden` ve starších modech)
--- @param proto table
--- @return boolean
function M.is_hidden(proto)
  if proto.hidden then return true end
  for _, flag in ipairs(proto.flags or {}) do
    if flag == "hidden" then return true end
  end
  return false
end

--- Najde předmět, který staví danou entitu.
--- @return string|nil
function M.find_place_item(raw, entity_name)
  for _, name in ipairs(M.sorted_keys(raw.item)) do
    if raw.item[name].place_result == entity_name then return name end
  end
end

--- Neskryté recepty, jejichž výsledkem je daný předmět. Skryté recepty (recyklace Space Age, která
--- „vyrábí“ suroviny a je enabled) hráč běžně nevyrábí, proto se nepočítají.
local function recipes_for(raw, item_name)
  local list = {}
  for _, name in ipairs(M.sorted_keys(raw.recipe)) do
    local recipe = raw.recipe[name]
    if not recipe.hidden then
      for _, result in ipairs(recipe.results or {}) do
        if result.name == item_name then
          list[#list + 1] = name
          break
        end
      end
    end
  end
  return list
end

--- Množina všech (i nepřímých) prerekvizit výzkumu.
--- @return table<string, true>
function M.tech_closure(raw, tech)
  local seen, stack = {}, { tech }
  while #stack > 0 do
    local proto = raw.technology[table.remove(stack)]
    for _, prerequisite in ipairs(proto and proto.prerequisites or {}) do
      if not seen[prerequisite] then
        seen[prerequisite] = true
        stack[#stack + 1] = prerequisite
      end
    end
  end
  return seen
end

--- Počet prvků množiny.
local function count(set)
  local n = 0
  for _ in pairs(set) do n = n + 1 end
  return n
end

--- Najde výzkum odemykající recept (skryté a vypnuté výzkumy hráč nevyzkoumá, nepočítají se).
--- @return string|nil
function M.find_unlocking_tech(raw, recipe_name)
  for _, name in ipairs(M.sorted_keys(raw.technology)) do
    local tech = raw.technology[name]
    if not M.is_hidden(tech) and tech.enabled ~= false then
      for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe_name then return name end
      end
    end
  end
end

--- Zjistí, jak hráč k předmětu přijde. Z více receptů (overhaul mody mají alternativní) vybere ten
--- dostupný nejdřív: od začátku, jinak přes výzkum s nejmenším uzávěrem prerekvizit.
--- @return string|nil recipe recept; nil = předmět nemá vyrobitelný recept
--- @return string|nil tech výzkum; nil = recept je dostupný od začátku
function M.item_source(raw, item_name)
  local best_recipe, best_tech, best_size
  for _, recipe in ipairs(recipes_for(raw, item_name)) do
    local tech = M.find_unlocking_tech(raw, recipe)
    if not tech and raw.recipe[recipe].enabled ~= false then return recipe, nil end
    if tech then
      local size = count(M.tech_closure(raw, tech))
      if not best_size or size < best_size then
        best_recipe, best_tech, best_size = recipe, tech, size
      end
    end
  end
  return best_recipe, best_tech
end

return M
```

Do `tests/unit/run.lua`: `local SUITES = { "test_locale", "test_availability" }`.

- [ ] **Step 5: Spustit – musí projít**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=10 fail=0`

- [ ] **Step 6: Commit (na pokyn uživatele)**

```bash
git add fluid-bus/prototypes/availability.lua tests/unit
git commit -m "feat: dostupnost předmětů z receptů a výzkumů"
```

---

### Task 4: Výběr a párování trubek (`bus_pipes.collect`)

**Files:**
- Create: `fluid-bus/prototypes/bus_pipes.lua` (část `collect`)
- Create: `tests/unit/test_bus_pipes.lua`
- Modify: `tests/unit/run.lua` – přidat `"test_bus_pipes"` do `SUITES`

**Interfaces:**
- Consumes: `prototypes.availability` (Task 3), `tests/unit/fake_raw.lua`.
- Produces: `bus_pipes.collect(raw) -> pairs, skipped`
  - `pairs`: pole seřazené podle `pipe`:
    `{ pipe, pipe_item, pipe_recipe, pipe_tech, underground?, underground_item?, underground_recipe?, underground_tech? }`
    (`*_tech` nil = od začátku)
  - `skipped`: pole `{ name, reason }` pro log (`reason` ∈ `"hidden"`, `"no-item"`, `"no-recipe"`, `"no-pair"`, `"duplicate-pair"`)

- [ ] **Step 1: Failing testy – `tests/unit/test_bus_pipes.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy výběru trubek a párování s podzemními trubkami.
local A = require("assert")
local F = require("fake_raw")
local bus = require("prototypes.bus_pipes")

local SCIENCE = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 10 }

--- Vanilla: trubka a podzemní (podzemní se vyrábí z trubek), obojí od začátku.
local function vanilla()
  local raw = F.new()
  F.pipe(raw, "pipe")
  F.item(raw, "pipe", "pipe")
  F.recipe(raw, "pipe", "pipe", { { "iron-plate", 1 } })
  F.underground(raw, "pipe-to-ground")
  F.item(raw, "pipe-to-ground", "pipe-to-ground")
  F.recipe(raw, "pipe-to-ground", "pipe-to-ground", { { "pipe", 10 }, { "iron-plate", 5 } })
  return raw
end

return {
  { "vanilla: jeden pár trubka + podzemní", function()
    local pairs_, skipped = bus.collect(vanilla())
    A.eq(#pairs_, 1, "počet párů")
    A.eq(pairs_[1].pipe, "pipe", "trubka")
    A.eq(pairs_[1].underground, "pipe-to-ground", "podzemní")
    A.eq(pairs_[1].pipe_tech, nil, "trubka od začátku")
    A.eq(#skipped, 0, "nic vynecháno")
  end },
  { "trubka z modu za výzkumem s vlastní podzemní (Py niobium)", function()
    local raw = vanilla()
    F.pipe(raw, "niobium-pipe", { category = { "niobium" }, extent = 640 })
    F.item(raw, "niobium-pipe", "niobium-pipe")
    F.recipe(raw, "niobium-pipe", "niobium-pipe", { { "niobium-plate", 1 } }, { enabled = false })
    F.underground(raw, "niobium-pipe-to-ground", { category = { "niobium" }, distance = 32 })
    F.item(raw, "niobium-pipe-to-ground", "niobium-pipe-to-ground")
    F.recipe(raw, "niobium-pipe-to-ground", "niobium-pipe-to-ground", { { "niobium-pipe", 10 } }, { enabled = false })
    F.tech(raw, "niobium", { "niobium-pipe", "niobium-pipe-to-ground" }, {}, SCIENCE)
    local pairs_ = bus.collect(raw)
    A.eq(#pairs_, 2, "počet párů")
    A.eq(pairs_[1].pipe, "niobium-pipe", "seřazeno podle jména")
    A.eq(pairs_[1].underground, "niobium-pipe-to-ground", "podzemní")
    A.eq(pairs_[1].pipe_tech, "niobium", "výzkum trubky")
    A.eq(pairs_[1].underground_tech, "niobium", "výzkum podzemní")
  end },
  { "trubka bez podzemní dostane jen BUS trubku", function()
    local raw = vanilla()
    F.pipe(raw, "lonely-pipe")
    F.item(raw, "lonely-pipe", "lonely-pipe")
    F.recipe(raw, "lonely-pipe", "lonely-pipe", { { "iron-plate", 1 } })
    local pairs_ = bus.collect(raw)
    A.eq(pairs_[1].pipe, "lonely-pipe", "trubka")
    A.eq(pairs_[1].underground, nil, "bez podzemní")
  end },
  { "podzemní, jejíž recept trubku nepoužívá, se vynechá", function()
    local raw = vanilla()
    F.underground(raw, "odd-to-ground")
    F.item(raw, "odd-to-ground", "odd-to-ground")
    F.recipe(raw, "odd-to-ground", "odd-to-ground", { { "stone", 5 } })
    local pairs_, skipped = bus.collect(raw)
    A.eq(#pairs_, 1, "počet párů")
    A.eq(skipped[1].name, "odd-to-ground", "vynechaná podzemní")
    A.eq(skipped[1].reason, "no-pair", "důvod")
  end },
  { "skrytá trubka a trubka bez receptu se vynechají", function()
    local raw = vanilla()
    F.pipe(raw, "secret-pipe", { hidden = true })
    F.item(raw, "secret-pipe", "secret-pipe")
    F.recipe(raw, "secret-pipe", "secret-pipe", {})
    F.pipe(raw, "no-recipe-pipe")
    F.item(raw, "no-recipe-pipe", "no-recipe-pipe")
    F.pipe(raw, "no-item-pipe")
    local pairs_, skipped = bus.collect(raw)
    A.eq(#pairs_, 1, "jen vanilla")
    local reasons = {}
    for _, s in ipairs(skipped) do reasons[s.name] = s.reason end
    A.eq(reasons["secret-pipe"], "hidden", "skrytá")
    A.eq(reasons["no-recipe-pipe"], "no-recipe", "bez receptu")
    A.eq(reasons["no-item-pipe"], "no-item", "bez předmětu")
  end },
  { "druhá podzemní ke stejné trubce se vynechá", function()
    local raw = vanilla()
    F.underground(raw, "pipe-to-ground-b")
    F.item(raw, "pipe-to-ground-b", "pipe-to-ground-b")
    F.recipe(raw, "pipe-to-ground-b", "pipe-to-ground-b", { { "pipe", 15 } })
    local pairs_, skipped = bus.collect(raw)
    A.eq(pairs_[1].underground, "pipe-to-ground", "první podle abecedy")
    A.eq(skipped[1].name, "pipe-to-ground-b", "druhá vynechaná")
    A.eq(skipped[1].reason, "duplicate-pair", "důvod")
  end },
}
```

- [ ] **Step 2: Spustit – musí selhat**

Run: `bash tools/run-unit.sh`
Expected: FAIL – `module 'prototypes.bus_pipes' not found`.

- [ ] **Step 3: Implementace – `fluid-bus/prototypes/bus_pipes.lua`**

```lua
--- Čistá logika BUS trubek: výběr trubek ve hře, párování s podzemními a stavba prototypů.
--- Nepoužívá globály Factoria (kopírovací funkci dostává parametrem), testy: tests/unit/test_bus_pipes.lua.
local av = require("prototypes.availability")

local M = {}

--- Prefix jmen BUS prototypů.
M.PREFIX = "fb-bus-"
--- Kategorie napojení, na kterou se připojí spojka busu.
M.CATEGORY = "fb-bus"

--- Zjistí dostupnost entity: předmět, recept a výzkum, nebo důvod vynechání.
--- @return table|nil info { item, recipe, tech }
--- @return string|nil reason důvod vynechání
local function source(raw, proto)
  if av.is_hidden(proto) then return nil, "hidden" end
  local item = av.find_place_item(raw, proto.name)
  if not item then return nil, "no-item" end
  local recipe, tech = av.item_source(raw, item)
  if not recipe then return nil, "no-recipe" end
  return { item = item, recipe = recipe, tech = tech }
end

--- Vybere použitelné trubky a spáruje je s podzemními podle receptu podzemní (surovina = předmět trubky).
--- @param raw table data.raw nebo jeho testovací náhrada
--- @return table[] pairs páry seřazené podle jména trubky
--- @return table[] skipped { name, reason } pro log
function M.collect(raw)
  local by_item, list, skipped = {}, {}, {}
  for _, name in ipairs(av.sorted_keys(raw.pipe)) do
    local info, reason = source(raw, raw.pipe[name])
    if info then
      local entry = { pipe = name, pipe_item = info.item, pipe_recipe = info.recipe, pipe_tech = info.tech }
      list[#list + 1] = entry
      by_item[info.item] = entry
    else
      skipped[#skipped + 1] = { name = name, reason = reason }
    end
  end
  for _, name in ipairs(av.sorted_keys(raw["pipe-to-ground"])) do
    local info, reason = source(raw, raw["pipe-to-ground"][name])
    local entry
    if info then
      for _, ingredient in ipairs(raw.recipe[info.recipe].ingredients or {}) do
        entry = entry or by_item[ingredient.name]
      end
      if not entry then
        reason = "no-pair"
      elseif entry.underground then
        reason, entry = "duplicate-pair", nil
      end
    end
    if entry then
      entry.underground, entry.underground_item = name, info.item
      entry.underground_recipe, entry.underground_tech = info.recipe, info.tech
    else
      skipped[#skipped + 1] = { name = name, reason = reason }
    end
  end
  return list, skipped
end

return M
```

Do `tests/unit/run.lua` přidat `"test_bus_pipes"` do `SUITES`.

- [ ] **Step 4: Spustit – musí projít**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=16 fail=0`

- [ ] **Step 5: Commit (na pokyn uživatele)**

```bash
git add fluid-bus/prototypes/bus_pipes.lua tests/unit
git commit -m "feat: výběr trubek ve hře a párování s podzemními"
```

---

### Task 5: Stavba BUS prototypů (entita, předmět, recept)

**Files:**
- Modify: `fluid-bus/prototypes/bus_pipes.lua` (přidat `with_bus_category`, `marking_item`, `entity`, `item`, `recipe`)
- Modify: `tests/unit/test_bus_pipes.lua` (přidat testy)

**Interfaces:**
- Consumes: `bus_pipes.collect` (Task 4), `availability.copy` (Task 3).
- Produces:
  - `bus_pipes.with_bus_category(category) -> string[]` – `nil` → `{"default","fb-bus"}`, řetězec → `{c,"fb-bus"}`,
    pole → kopie + `"fb-bus"` (bez duplikátu)
  - `bus_pipes.MARKING = { "steel-plate", "iron-plate" }` (laditelné), `bus_pipes.marking_item(raw) -> string|nil`
  - `bus_pipes.entity(proto, copy, decorate) -> table` – nový prototyp `fb-bus-<jméno>`; `decorate(new)`
    je volitelná funkce pro grafiku (Task 6), v testech `nil`
  - `bus_pipes.item(raw, source_item, entity_proto, icons) -> table` – předmět `fb-bus-<jméno entity>`
  - `bus_pipes.recipe(source_item, count, marking, result) -> table` – recept `result` (= jméno předmětu)

- [ ] **Step 1: Failing testy – přidat na konec pole v `tests/unit/test_bus_pipes.lua`**

Přidat před `return {` pomocné `local av = require("prototypes.availability")` a do vraceného pole:

```lua
  { "with_bus_category: výchozí, řetězec, pole, bez duplikátu", function()
    A.eq(table.concat(bus.with_bus_category(nil), ","), "default,fb-bus", "nil")
    A.eq(table.concat(bus.with_bus_category("niobium"), ","), "niobium,fb-bus", "řetězec")
    A.eq(table.concat(bus.with_bus_category({ "default", "x" }), ","), "default,x,fb-bus", "pole")
    A.eq(table.concat(bus.with_bus_category({ "fb-bus" }), ","), "fb-bus", "už obsahuje")
  end },
  { "entity: zachová kategorie Py a extent, přidá fb-bus", function()
    local raw = F.new()
    local proto = F.pipe(raw, "niobium-pipe", { category = { "niobium" }, extent = 640 })
    proto.next_upgrade = "something"
    local new = bus.entity(proto, av.copy)
    A.eq(new.name, "fb-bus-niobium-pipe", "jméno")
    A.eq(new.fluid_box.max_pipeline_extent, 640, "extent zděděn")
    for i, c in ipairs(new.fluid_box.pipe_connections) do
      A.eq(table.concat(c.connection_category, ","), "niobium,fb-bus", "kategorie konektoru " .. i)
    end
    A.eq(new.next_upgrade, nil, "next_upgrade vynulován")
    A.eq(new.minable.result, "fb-bus-niobium-pipe", "vytěží se BUS předmět")
    A.eq(new.fast_replaceable_group, "pipe", "rychlá výměna s původní")
    A.eq(proto.fluid_box.pipe_connections[1].connection_category[2], nil, "originál nezměněn")
  end },
  { "entity: podzemní konektor dostane kategorii a zachová dosah", function()
    local raw = F.new()
    local proto = F.underground(raw, "pipe-to-ground", { distance = 10 })
    local new = bus.entity(proto, av.copy)
    local under = new.fluid_box.pipe_connections[2]
    A.eq(under.max_underground_distance, 10, "dosah")
    A.eq(table.concat(under.connection_category, ","), "default,fb-bus", "kategorie")
  end },
  { "entity: lokalizovaný název odkazuje na původní", function()
    local raw = F.new()
    local new = bus.entity(F.pipe(raw, "pipe"), av.copy)
    A.eq(new.localised_name[1], "entity-name.fb-bus-pipe", "klíč")
    A.eq(new.localised_name[2][1], "entity-name.pipe", "původní jméno")
  end },
  { "marking_item: první existující kandidát", function()
    local raw = F.new()
    A.eq(bus.marking_item(raw), nil, "nic")
    F.item(raw, "iron-plate")
    A.eq(bus.marking_item(raw), "iron-plate", "náhrada")
    F.item(raw, "steel-plate")
    A.eq(bus.marking_item(raw), "steel-plate", "první kandidát")
  end },
  { "recipe: trubka + značení, bez značení jen trubka", function()
    local r = bus.recipe("pipe", 1, "steel-plate", "fb-bus-pipe")
    A.eq(r.name, "fb-bus-pipe", "jméno")
    A.eq(#r.ingredients, 2, "dvě suroviny")
    A.eq(r.ingredients[1].name, "pipe", "trubka")
    A.eq(r.results[1].amount, 1, "počet")
    local u = bus.recipe("pipe-to-ground", 2, nil, "fb-bus-pipe-to-ground")
    A.eq(#u.ingredients, 1, "bez značení")
    A.eq(u.results[1].amount, 2, "podzemní po dvou")
  end },
  { "item: převezme řazení a staví BUS entitu", function()
    local raw = F.new()
    F.item(raw, "pipe", "pipe")
    local entity = bus.entity(F.pipe(raw, "pipe"), av.copy)
    local it = bus.item(raw, "pipe", entity, { { icon = "x.png", icon_size = 64 } })
    A.eq(it.name, "fb-bus-pipe", "jméno")
    A.eq(it.place_result, "fb-bus-pipe", "staví")
    A.eq(it.subgroup, "energy-pipe-distribution", "podskupina")
    A.eq(it.order, "a-fb", "řazení za původní")
    A.eq(it.localised_name[1], "entity-name.fb-bus-pipe", "název")
  end },
```

- [ ] **Step 2: Spustit – musí selhat**

Run: `bash tools/run-unit.sh`
Expected: FAIL – `attempt to call a nil value (field 'with_bus_category')`.

- [ ] **Step 3: Implementace – přidat do `fluid-bus/prototypes/bus_pipes.lua` před `return M`**

```lua
--- Kandidáti suroviny „značení“ v receptu BUS varianty; první existující předmět vyhrává. Laditelné.
M.MARKING = { "steel-plate", "iron-plate" }
--- Množství značení na jeden kus receptu (trubka 1, podzemní dvojice 2). Laditelné.
M.MARKING_PER_PIECE = 1
--- Doba výroby receptu v sekundách. Laditelné.
M.CRAFT_TIME = 0.5

--- Kategorie konektoru rozšířené o kategorii busu (chybějící kategorie = "default").
--- @param category string|string[]|nil
--- @return string[]
function M.with_bus_category(category)
  local list = {}
  if category == nil then
    list = { "default" }
  elseif type(category) == "string" then
    list = { category }
  else
    for i, value in ipairs(category) do list[i] = value end
  end
  for _, value in ipairs(list) do
    if value == M.CATEGORY then return list end
  end
  list[#list + 1] = M.CATEGORY
  return list
end

--- Vybere surovinu značení podle M.MARKING.
--- @return string|nil
function M.marking_item(raw)
  for _, name in ipairs(M.MARKING) do
    if raw.item[name] then return name end
  end
end

--- Postaví BUS variantu entity (trubky nebo podzemní): kopie s kategorií busu na všech konektorech.
--- @param proto table původní prototyp
--- @param copy fun(t: table): table hloubková kopie (table.deepcopy ve hře)
--- @param decorate fun(new: table)|nil úprava grafiky (bus_overlay), v unit testech nil
--- @return table
function M.entity(proto, copy, decorate)
  local new = copy(proto)
  new.name = M.PREFIX .. proto.name
  new.next_upgrade = nil
  new.placeable_by = nil
  new.minable = { mining_time = proto.minable and proto.minable.mining_time or 0.1, result = new.name }
  new.localised_name = { "entity-name.fb-bus-pipe", proto.localised_name or { "entity-name." .. proto.name } }
  new.localised_description = { "entity-description.fb-bus-pipe" }
  for _, connection in ipairs(new.fluid_box.pipe_connections) do
    connection.connection_category = M.with_bus_category(connection.connection_category)
  end
  if decorate then decorate(new) end
  return new
end

--- Předmět stavějící BUS entitu; řazení hned za původní předmět.
--- @param raw table data.raw
--- @param source_item string původní předmět
--- @param entity_proto table BUS entita z M.entity
--- @param icons table[] vrstvy ikony
--- @return table
function M.item(raw, source_item, entity_proto, icons)
  local source = raw.item[source_item]
  return {
    type = "item",
    name = entity_proto.name,
    icons = icons,
    subgroup = source.subgroup,
    order = (source.order or "") .. "-fb",
    place_result = entity_proto.name,
    stack_size = source.stack_size,
    localised_name = entity_proto.localised_name,
    localised_description = { "item-description.fb-bus-pipe" },
  }
end

--- Recept BUS varianty: `count` původních kusů (+ značení) → `count` BUS kusů.
--- @param source_item string původní předmět
--- @param count integer 1 pro trubku, 2 pro podzemní
--- @param marking string|nil surovina značení (nil = bez ní)
--- @param result string jméno BUS předmětu
--- @return table
function M.recipe(source_item, count, marking, result)
  local ingredients = { { type = "item", name = source_item, amount = count } }
  if marking then
    ingredients[2] = { type = "item", name = marking, amount = count * M.MARKING_PER_PIECE }
  end
  return {
    type = "recipe",
    name = result,
    enabled = true,
    energy_required = M.CRAFT_TIME,
    ingredients = ingredients,
    results = { { type = "item", name = result, amount = count } },
  }
end
```

- [ ] **Step 4: Spustit – musí projít**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=23 fail=0`

- [ ] **Step 5: Commit (na pokyn uživatele)**

```bash
git add fluid-bus/prototypes/bus_pipes.lua tests/unit/test_bus_pipes.lua
git commit -m "feat: BUS varianta entity, předmětu a receptu s kategorií fb-bus"
```

---

### Task 6: Označení „BUS“ / „B“ (overlay grafika)

**Files:**
- Create: `blender/build_overlay.py`
- Create (výstup skriptu, commitovat): `fluid-bus/graphics/entity/bus-horizontal.png`,
  `fluid-bus/graphics/entity/bus-vertical.png`, `fluid-bus/graphics/entity/b.png`,
  `fluid-bus/graphics/icons/b.png`
- Create: `fluid-bus/prototypes/bus_overlay.lua`
- Create: `tests/unit/test_bus_overlay.lua`, `tests/unit/test_graphics.lua`
- Modify: `tests/unit/run.lua` – přidat `"test_bus_overlay", "test_graphics"`

**Interfaces:**
- Consumes: `availability.copy` (Task 3).
- Produces:
  - `bus_overlay.GRAPHICS = "__fluid-bus__/graphics/"`
  - `bus_overlay.LABELS` – tabulka klíč spritu → `"bus-horizontal" | "bus-vertical" | "b"`
  - `bus_overlay.OVERLAY_SHIFT` – klíč spritu → `{x, y}` (laditelné, chybějící = `{0, 0}`)
  - `bus_overlay.decorate(new, copy) -> string[]` – upraví `new.pictures` (trubka i podzemní), vrátí seznam
    klíčů, které **nešlo** označit (pro log)
  - `bus_overlay.icons(source_item_proto, copy) -> table[]` – původní vrstvy ikony + `b.png`

- [ ] **Step 1: Načíst skill `blender-workflow`** (pravidla pro skriptovaný render) – Skill tool.

- [ ] **Step 2: Skript overlayů – `blender/build_overlay.py`**

```python
"""Vyrenderuje průhledné PNG s označením BUS trubek (bílé písmo s tmavým obrysem).

Spuštění: blender -b -P blender/build_overlay.py -- <výstupní složka modu>
Výstupy: graphics/entity/bus-horizontal.png, bus-vertical.png, b.png (128×128, ve hře scale 0.5)
a graphics/icons/b.png (64×64).
"""
import math
import sys
from pathlib import Path

import bpy

# Laditelné hodnoty: velikost písma (v jednotkách kamery 1 = šířka obrázku) a tloušťka obrysu.
TEXT_SIZE = {"bus": 0.30, "b": 0.42}
OUTLINE = 0.025
FILL = (1.0, 1.0, 1.0, 1.0)
EDGE = (0.05, 0.05, 0.05, 1.0)


def reset_scene():
    """Prázdná scéna, Workbench s plochým světlem a průhledným pozadím."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "MATERIAL"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.0
    camera.location = (0, 0, 10)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return scene


def material(name, color):
    """Materiál s barvou pro Workbench."""
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def text(body, size, rotation, offset, color, z):
    """Vystředěný text; offset rozšíří obrys písmen (pro tmavý lem)."""
    curve = bpy.data.curves.new(f"text-{z}", "FONT")
    curve.body = body
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.offset = offset
    obj = bpy.data.objects.new(f"text-{z}", curve)
    obj.location = (0, 0, z)
    obj.rotation_euler = (0, 0, rotation)
    obj.data.materials.append(material(f"m-{z}", color))
    bpy.context.scene.collection.objects.link(obj)


def render(body, size, rotation, pixels, path):
    """Vyrenderuje jeden overlay do PNG."""
    scene = reset_scene()
    scene.render.resolution_x = pixels
    scene.render.resolution_y = pixels
    text(body, size, rotation, OUTLINE, EDGE, 0.0)
    text(body, size, rotation, 0.0, FILL, 0.01)
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    """Vstupní bod: cesta ke složce modu za oddělovačem --."""
    root = Path(sys.argv[sys.argv.index("--") + 1])
    render("BUS", TEXT_SIZE["bus"], 0.0, 128, root / "graphics/entity/bus-horizontal.png")
    render("BUS", TEXT_SIZE["bus"], math.pi / 2, 128, root / "graphics/entity/bus-vertical.png")
    render("B", TEXT_SIZE["b"], 0.0, 128, root / "graphics/entity/b.png")
    render("B", TEXT_SIZE["b"] * 1.6, 0.0, 64, root / "graphics/icons/b.png")


main()
```

- [ ] **Step 3: Vyrenderovat a zkontrolovat**

Run: `"C:/STEAM/steamapps/common/Blender/blender.exe" -b -P blender/build_overlay.py -- fluid-bus`
Expected: 4 PNG soubory. Otevřít je nástrojem Read (obrázek) a ověřit: čitelný bílý text s tmavým
lemem, průhledné pozadí, „BUS“ ve `bus-vertical.png` otočené o 90°. Když text přetéká okraj nebo je
malý, upravit `TEXT_SIZE` a spustit znovu.

- [ ] **Step 4: Failing testy – `tests/unit/test_graphics.lua`**

```lua
---@diagnostic disable: undefined-global
--- Rozměry PNG overlayů (headless hra sprity nenačítá, chybný rozměr by se projevil až ve hře).
local A = require("assert")

--- Přečte šířku a výšku PNG z hlavičky IHDR.
local function png_size(path)
  local file = assert(io.open(path, "rb"))
  local header = file:read(24)
  file:close()
  A.eq(header:sub(2, 4), "PNG", path .. " je PNG")
  return string.unpack(">I4I4", header, 17)
end

--- Test jednoho souboru.
local function size_case(path, expected)
  return { path .. " má " .. expected .. "×" .. expected, function()
    local w, h = png_size(path)
    A.eq(w, expected, "šířka")
    A.eq(h, expected, "výška")
  end }
end

return {
  size_case("fluid-bus/graphics/entity/bus-horizontal.png", 128),
  size_case("fluid-bus/graphics/entity/bus-vertical.png", 128),
  size_case("fluid-bus/graphics/entity/b.png", 128),
  size_case("fluid-bus/graphics/icons/b.png", 64),
}
```

`tests/unit/test_bus_overlay.lua`:

```lua
---@diagnostic disable: undefined-global
--- Testy přidání označení BUS/B do spritů trubek a ikon.
local A = require("assert")
local av = require("prototypes.availability")
local overlay = require("prototypes.bus_overlay")

--- Poslední vrstva spritu.
local function top(sprite) return sprite.layers[#sprite.layers] end

return {
  { "rovná vodorovná dostane BUS, roh B", function()
    local pipe = { type = "pipe", pictures = {
      straight_horizontal = { filename = "h.png" }, corner_up_right = { filename = "c.png" },
      straight_vertical = { filename = "v.png" }, fluid_background = { filename = "f.png" } } }
    local missing = overlay.decorate(pipe, av.copy)
    A.eq(top(pipe.pictures.straight_horizontal).filename, overlay.GRAPHICS .. "entity/bus-horizontal.png", "vodorovná")
    A.eq(top(pipe.pictures.straight_vertical).filename, overlay.GRAPHICS .. "entity/bus-vertical.png", "svislá")
    A.eq(top(pipe.pictures.corner_up_right).filename, overlay.GRAPHICS .. "entity/b.png", "roh")
    A.eq(pipe.pictures.straight_horizontal.layers[1].filename, "h.png", "původní vrstva první")
    A.eq(pipe.pictures.fluid_background.filename, "f.png", "pozadí kapaliny beze změny")
    A.eq(#missing, 0, "nic nechybí")
  end },
  { "sprite s layers dostane overlay navrch", function()
    local pipe = { type = "pipe", pictures = { cross = { layers = { { filename = "a.png" }, { filename = "b.png" } } } } }
    overlay.decorate(pipe, av.copy)
    A.eq(#pipe.pictures.cross.layers, 3, "tři vrstvy")
    A.eq(top(pipe.pictures.cross).filename, overlay.GRAPHICS .. "entity/b.png", "overlay navrch")
  end },
  { "podzemní 4 směry dostanou B", function()
    local ug = { type = "pipe-to-ground", pictures = { north = { filename = "n.png" }, south = { filename = "s.png" },
      east = { filename = "e.png" }, west = { filename = "w.png" } } }
    local missing = overlay.decorate(ug, av.copy)
    for _, dir in ipairs({ "north", "south", "east", "west" }) do
      A.eq(top(ug.pictures[dir]).filename, overlay.GRAPHICS .. "entity/b.png", dir)
    end
    A.eq(#missing, 0, "nic nechybí")
  end },
  { "podzemní ve formě sheet se nezmění a nahlásí se", function()
    local ug = { type = "pipe-to-ground", pictures = { sheet = { filename = "all.png" } } }
    local missing = overlay.decorate(ug, av.copy)
    A.eq(ug.pictures.sheet.filename, "all.png", "beze změny")
    A.eq(missing[1], "sheet", "nahlášeno")
  end },
  { "posun overlaye z OVERLAY_SHIFT", function()
    overlay.OVERLAY_SHIFT.t_up = { 0, -0.1 }
    local pipe = { type = "pipe", pictures = { t_up = { filename = "t.png" } } }
    overlay.decorate(pipe, av.copy)
    A.eq(top(pipe.pictures.t_up).shift[2], -0.1, "posun")
    overlay.OVERLAY_SHIFT.t_up = nil
  end },
  { "ikona: původní icons + B; jediná icon převedena na vrstvu", function()
    local icons = overlay.icons({ icon = "pipe.png", icon_size = 64 }, av.copy)
    A.eq(#icons, 2, "dvě vrstvy")
    A.eq(icons[1].icon, "pipe.png", "původní")
    A.eq(icons[2].icon, overlay.GRAPHICS .. "icons/b.png", "overlay")
    local layered = overlay.icons({ icons = { { icon = "a.png" }, { icon = "b.png", tint = { 1, 0, 0 } } } }, av.copy)
    A.eq(#layered, 3, "dvě původní + overlay")
  end },
}
```

Do `SUITES` přidat `"test_bus_overlay", "test_graphics"`.

- [ ] **Step 5: Spustit – musí selhat**

Run: `bash tools/run-unit.sh`
Expected: FAIL – `module 'prototypes.bus_overlay' not found` (test_graphics projde, pokud Step 3 vyrenderoval PNG).

- [ ] **Step 6: Implementace – `fluid-bus/prototypes/bus_overlay.lua`**

```lua
--- Označení BUS trubek: k obrázkům trubky přidá vrstvu s nápisem „BUS“ (rovné kusy) nebo „B“
--- (ostatní tvary, podzemní, ikona), aby šla BUS trubka na první pohled odlišit od běžné.
--- Bez globálů Factoria, testy: tests/unit/test_bus_overlay.lua.
local M = {}

--- Cesta ke grafice modu.
M.GRAPHICS = "__fluid-bus__/graphics/"

--- Který overlay patří ke kterému tvaru trubky (klíče PipePictures a Sprite4Way podzemní).
--- Klíče, které tu nejsou (vizualizace, pozadí a proudění kapaliny), zůstanou beze změny.
M.LABELS = {
  straight_horizontal = "bus-horizontal", straight_horizontal_window = "bus-horizontal",
  straight_vertical = "bus-vertical", straight_vertical_window = "bus-vertical",
  straight_vertical_single = "b",
  corner_up_right = "b", corner_up_left = "b", corner_down_right = "b", corner_down_left = "b",
  t_up = "b", t_down = "b", t_right = "b", t_left = "b", cross = "b",
  ending_up = "b", ending_down = "b", ending_right = "b", ending_left = "b",
  north = "b", south = "b", east = "b", west = "b",
}

--- Posun overlaye v dlaždicích podle tvaru – laditelné (např. aby nápis nezakrýval okénko trubky).
--- Chybějící klíč = střed kusu.
M.OVERLAY_SHIFT = {}

--- Sprite overlaye pro daný tvar.
local function overlay_sprite(key)
  return {
    filename = M.GRAPHICS .. "entity/" .. M.LABELS[key] .. ".png",
    priority = "extra-high",
    width = 128,
    height = 128,
    scale = 0.5,
    shift = M.OVERLAY_SHIFT[key] or { 0, 0 },
  }
end

--- Přidá overlay do `pictures` BUS entity (trubky i podzemní).
--- @param new table BUS prototyp (už kopie, mění se na místě)
--- @param copy fun(t: table): table hloubková kopie
--- @return string[] klíče, které nešlo označit (např. podzemní jako `sheet`) – pro log
function M.decorate(new, copy)
  local missing = {}
  local pictures = new.pictures or {}
  for key, sprite in pairs(pictures) do
    if M.LABELS[key] then
      if sprite.layers then
        local layered = copy(sprite)
        layered.layers[#layered.layers + 1] = overlay_sprite(key)
        pictures[key] = layered
      else
        pictures[key] = { layers = { copy(sprite), overlay_sprite(key) } }
      end
    elseif key == "sheet" or key == "sheets" then
      missing[#missing + 1] = key
    end
  end
  table.sort(missing)
  return missing
end

--- Vrstvy ikony BUS předmětu: původní ikona(y) + „B“.
--- @param source table původní předmět (icon/icon_size nebo icons)
--- @param copy fun(t: table): table
--- @return table[]
function M.icons(source, copy)
  local layers
  if source.icons then
    layers = copy(source.icons)
  else
    layers = { { icon = source.icon, icon_size = source.icon_size or 64 } }
  end
  layers[#layers + 1] = { icon = M.GRAPHICS .. "icons/b.png", icon_size = 64 }
  return layers
end

return M
```

- [ ] **Step 7: Spustit – musí projít**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=33 fail=0`

- [ ] **Step 8: Commit (na pokyn uživatele)**

```bash
git add blender/build_overlay.py fluid-bus/graphics fluid-bus/prototypes/bus_overlay.lua tests/unit
git commit -m "feat: označení BUS/B na BUS trubkách a ikonách"
```

---

### Task 7: Výzkumy BUS trubek (`prototypes/research.lua`)

**Files:**
- Create: `fluid-bus/prototypes/research.lua`
- Create: `tests/unit/test_research.lua`
- Modify: `tests/unit/run.lua` – přidat `"test_research"`

**Interfaces:**
- Consumes: `availability` (Task 3).
- Produces:
  - `research.BASE_TECH = "fb-fluid-bus"`, `research.BASE_ITEMS = { "pump" }` (plán 2 přidá suroviny spojky),
    `research.TECH_COUNT_MULTIPLIER = 1.5`, `research.PREFIX = "fb-"`
  - `research.techs_for_items(raw, items) -> table<string,true>` – výzkumy odemykající předměty
  - `research.covered(raw, base_prerequisites, techs) -> boolean` – každý výzkum z `techs` je jedna
    z `base_prerequisites` nebo v jejich uzávěru
  - `research.technology(raw, direct, trigger_item) -> nil | { prerequisites, unit? , research_trigger? }`
    (`direct` = množina přímých výzkumů; nil = nic není potřeba, recept od začátku)

- [ ] **Step 1: Failing testy – `tests/unit/test_research.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy výzkumů BUS trubek: prerekvizity, cena, pokrytí základním výzkumem.
local A = require("assert")
local F = require("fake_raw")
local research = require("prototypes.research")

local RED = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 10 }
local GREEN = { count = 100, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 15 }

--- Strom: automation → fluid-handling (pumpa), steel-processing (ocel), niobium za fluid-handling.
local function tree()
  local raw = F.new()
  F.item(raw, "pump", "pump")
  F.recipe(raw, "pump", "pump", {}, { enabled = false })
  F.item(raw, "steel-plate")
  F.recipe(raw, "steel-plate", "steel-plate", {}, { enabled = false })
  F.tech(raw, "automation", {}, {}, RED)
  F.tech(raw, "steel-processing", { "steel-plate" }, {}, RED)
  F.tech(raw, "fluid-handling", { "pump" }, { "automation" }, GREEN)
  F.tech(raw, "niobium", {}, { "fluid-handling" }, { count = 300, ingredients = GREEN.ingredients, time = 30 })
  return raw
end

--- Seřazený seznam z pole.
local function joined(list) table.sort(list) return table.concat(list, ",") end

return {
  { "techs_for_items: pumpa a ocel", function()
    local set = research.techs_for_items(tree(), { "pump", "steel-plate", "neexistuje" })
    A.truthy(set["fluid-handling"] and set["steel-processing"], "oba výzkumy")
  end },
  { "technology: prerekvizity bez tranzitivně zbytečných", function()
    local tech = research.technology(tree(), { ["fluid-handling"] = true, automation = true, ["steel-processing"] = true }, "x")
    A.eq(joined(tech.prerequisites), "fluid-handling,steel-processing", "automation plyne z fluid-handling")
  end },
  { "technology: cena = nejvíc druhů vědy, počet × násobič", function()
    local tech = research.technology(tree(), { ["fluid-handling"] = true, ["steel-processing"] = true }, "x")
    A.eq(#tech.unit.ingredients, 2, "dva druhy vědy")
    A.eq(tech.unit.count, 150, "100 × 1.5")
  end },
  { "technology: vlastní výzkumy fb- se do ceny nepočítají", function()
    local raw = tree()
    F.tech(raw, "fb-fluid-bus", {}, { "fluid-handling" }, { count = 10000, ingredients = GREEN.ingredients, time = 30 })
    local tech = research.technology(raw, { ["fb-fluid-bus"] = true, niobium = true }, "x")
    A.eq(tech.unit.count, 450, "300 × 1.5, ne 10000")
  end },
  { "technology: nic potřeba → nil", function()
    A.eq(research.technology(tree(), {}, "x"), nil, "bez výzkumu")
  end },
  { "technology: prerekvizity bez vědy → spouštěč výrobou", function()
    local raw = tree()
    F.tech(raw, "trigger-only", {}, {}, nil)
    local tech = research.technology(raw, { ["trigger-only"] = true }, "fb-bus-pipe")
    A.eq(tech.research_trigger.item, "fb-bus-pipe", "spouštěč")
  end },
  { "covered: výzkum v uzávěru základních prerekvizit", function()
    local raw = tree()
    A.truthy(research.covered(raw, { "fluid-handling" }, { automation = true }), "automation v uzávěru")
    A.truthy(research.covered(raw, { "fluid-handling" }, {}), "nic = pokryto")
    A.eq(research.covered(raw, { "fluid-handling" }, { niobium = true }), false, "niobium je později")
  end },
}
```

- [ ] **Step 2: Spustit – musí selhat**

Run: `bash tools/run-unit.sh`
Expected: FAIL – `module 'prototypes.research' not found`.

- [ ] **Step 3: Implementace – `fluid-bus/prototypes/research.lua`**

```lua
--- Čistá logika výzkumů: prerekvizity dopočítané z toho, co recepty potřebují, cena odvozená
--- z prerekvizit. Sedí i na stromy výzkumů přeskládané overhaul mody (Pyanodon, Bob's).
--- Bez globálů Factoria, testy: tests/unit/test_research.lua.
local av = require("prototypes.availability")

local M = {}

--- Prefix vlastních výzkumů; nepočítají se do základu ceny (cena by rostla geometricky).
M.PREFIX = "fb-"
--- Jméno základního výzkumu (spojka + BUS trubky dostupné spolu s ní).
M.BASE_TECH = "fb-fluid-bus"
--- Předměty, jejichž výzkumy jsou prerekvizitou základního výzkumu. Plán 2 přidá suroviny spojky.
M.BASE_ITEMS = { "pump" }
--- Násobič počtu jednotek proti nejdražší přímé prerekvizitě (mimo vlastní výzkumy). Laditelné.
M.TECH_COUNT_MULTIPLIER = 1.5

--- Klíče množiny seřazené abecedně.
local function sorted(set)
  local list = {}
  for key in pairs(set) do list[#list + 1] = key end
  table.sort(list)
  return list
end

--- Výzkumy, které odemykají dané předměty (předměty od začátku a neexistující nic nepřidají).
--- @param raw table data.raw
--- @param items string[]
--- @return table<string, true>
function M.techs_for_items(raw, items)
  local set = {}
  for _, name in ipairs(items) do
    if raw.item[name] then
      local _, tech = av.item_source(raw, name)
      if tech then set[tech] = true end
    end
  end
  return set
end

--- Jsou všechny výzkumy z `techs` dostupné nejpozději se základním výzkumem?
--- @param raw table data.raw
--- @param base_prerequisites string[] prerekvizity základního výzkumu
--- @param techs table<string, true>
--- @return boolean
function M.covered(raw, base_prerequisites, techs)
  local known = {}
  for _, name in ipairs(base_prerequisites) do
    known[name] = true
    for prerequisite in pairs(av.tech_closure(raw, name)) do known[prerequisite] = true end
  end
  for name in pairs(techs) do
    if not known[name] then return false end
  end
  return true
end

--- Vybere jednotku výzkumu s nejvíc druhy vědy (při shodě vyšší počet) – sadu vědy, kterou umí
--- laboratoř zpracovat i v modech s více laboratořemi.
local function template_unit(raw, techs)
  local best
  for _, name in ipairs(techs) do
    local unit = raw.technology[name].unit
    if unit and unit.count then
      if not best or #unit.ingredients > #best.ingredients
        or (#unit.ingredients == #best.ingredients and unit.count > best.count) then
        best = unit
      end
    end
  end
  return best
end

--- Sestaví výzkum z přímých prerekvizit: odebere ty, které plynou z jiné, cenu odvodí z cizích.
--- @param raw table data.raw (vlastní výzkumy, na které se odkazuje, už v něm musí být)
--- @param direct table<string, true> přímé prerekvizity
--- @param trigger_item string předmět, jehož výroba výzkum spustí, když prerekvizity nemají vědu
--- @return table|nil { prerequisites, unit | research_trigger }; nil = recept od začátku
function M.technology(raw, direct, trigger_item)
  local names = sorted(direct)
  if #names == 0 then return nil end
  local implied = {}
  for _, name in ipairs(names) do
    for prerequisite in pairs(av.tech_closure(raw, name)) do implied[prerequisite] = true end
  end
  local prerequisites, foreign = {}, {}
  for _, name in ipairs(names) do
    if not implied[name] then prerequisites[#prerequisites + 1] = name end
    if name:sub(1, #M.PREFIX) ~= M.PREFIX then foreign[#foreign + 1] = name end
  end
  local result = { prerequisites = prerequisites }
  local base = template_unit(raw, foreign)
  if base then
    result.unit = av.copy(base)
    local max_count = 0
    for _, name in ipairs(foreign) do
      local unit = raw.technology[name].unit
      if unit and unit.count and unit.count > max_count then max_count = unit.count end
    end
    result.unit.count = math.ceil(max_count * M.TECH_COUNT_MULTIPLIER)
  elseif template_unit(raw, names) then
    result.unit = av.copy(template_unit(raw, names))
  else
    result.research_trigger = { type = "craft-item", item = trigger_item }
  end
  return result
end

return M
```

- [ ] **Step 4: Spustit – musí projít**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=40 fail=0`

- [ ] **Step 5: Commit (na pokyn uživatele)**

```bash
git add fluid-bus/prototypes/research.lua tests/unit
git commit -m "feat: výzkumy BUS trubek s dopočítanými prerekvizitami"
```

---

### Task 8: Napojení do hry (`data-final-fixes.lua`, locale, integrační testy)

**Files:**
- Modify: `fluid-bus/data-final-fixes.lua`
- Modify: `fluid-bus/locale/en/locale.cfg`, `fluid-bus/locale/cs/locale.cfg`
- Create: `tests/fluid-bus-tests/helpers.lua`
- Create: `tests/fluid-bus-tests/cases/bus_pipes.lua`
- Modify: `tests/fluid-bus-tests/control.lua` – registrace `cases.bus_pipes`

**Interfaces:**
- Consumes: `bus_pipes.collect/entity/item/recipe/marking_item` (Tasks 4–5), `bus_overlay.decorate/icons`
  (Task 6), `research.*` (Task 7).
- Produces (pro plán 2 a testy): prototypy `fb-bus-<trubka>` a `fb-bus-<podzemní>` (entita, předmět,
  recept), výzkum `fb-fluid-bus` (pokud jsou potřeba výzkumy), výzkumy `fb-fluid-bus-<trubka>`,
  `prototypes.mod_data["fb-data"].data = { bus_pipes = { jména entit… } }`.
  Plán 2 do výzkumu `fb-fluid-bus` přidá recept spojky a do `fb-data` klíč `couplers`.

- [ ] **Step 1: Pomocné funkce testů – `tests/fluid-bus-tests/helpers.lua`**

```lua
--- Pomocné funkce integračních testů.
local H = {}

--- Selže, pokud se hodnoty nerovnají.
function H.eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: čekáno %s, dostáno %s", what, tostring(expected), tostring(actual)), 0)
  end
end

--- Selže, pokud hodnota není pravdivá.
function H.truthy(value, what)
  if not value then error(what .. ": čekána pravdivá hodnota", 0) end
end

--- Postaví entitu na dlaždici (x, y) relativně k výřezu testu.
function H.place(ctx, name, x, y, extra)
  local spec = { name = name, position = { ctx.origin.x + x + 0.5, ctx.origin.y + y + 0.5 }, force = "player" }
  for key, value in pairs(extra or {}) do spec[key] = value end
  local entity = ctx.surface.create_entity(spec)
  H.truthy(entity, "postavení " .. name)
  return entity
end

--- Výzkumy, které odemykají daný recept.
function H.unlocking_techs(recipe_name)
  local list = {}
  for name, tech in pairs(prototypes.technology) do
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe == recipe_name then list[#list + 1] = name end
    end
  end
  return list
end

--- Množina výzkumu a všech jeho (i nepřímých) prerekvizit.
local function closure(tech)
  local seen, stack = { [tech.name] = true }, { tech }
  while #stack > 0 do
    for name, prerequisite in pairs(table.remove(stack).prerequisites) do
      if not seen[name] then
        seen[name] = true
        stack[#stack + 1] = prerequisite
      end
    end
  end
  return seen
end

--- Suroviny receptů BUS trubek, které nejdou vyrobit nejpozději s výzkumem, jenž recept odemyká.
--- @return string prázdný řetězec = vše v pořádku
function H.unreachable_ingredients()
  local producers = {}
  for name, recipe in pairs(prototypes.recipe) do
    if not recipe.hidden then
      for _, product in ipairs(recipe.products) do
        producers[product.name] = producers[product.name] or {}
        table.insert(producers[product.name], name)
      end
    end
  end
  local problems = {}
  for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do
    local recipe = prototypes.recipe[name]
    local known = {}
    for _, tech in ipairs(H.unlocking_techs(name)) do
      for via in pairs(closure(prototypes.technology[tech])) do known[via] = true end
    end
    for _, ingredient in ipairs(recipe.ingredients) do
      local ok = producers[ingredient.name] == nil
      for _, producer in ipairs(producers[ingredient.name] or {}) do
        if prototypes.recipe[producer].enabled then ok = true end
        for _, via in ipairs(H.unlocking_techs(producer)) do
          if known[via] then ok = true end
        end
      end
      if not ok then problems[#problems + 1] = name .. ": " .. ingredient.name end
    end
  end
  table.sort(problems)
  return table.concat(problems, ", ")
end

return H
```

- [ ] **Step 2: Failing integrační testy – `tests/fluid-bus-tests/cases/bus_pipes.lua`**

```lua
--- Integrační testy BUS trubek ve vanilla / Space Age.
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

return {
  check("BUS trubka a podzemní existují a jsou v mod-data", function()
    H.truthy(prototypes.entity["fb-bus-pipe"], "fb-bus-pipe")
    H.truthy(prototypes.entity["fb-bus-pipe-to-ground"], "fb-bus-pipe-to-ground")
    local names = {}
    for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do names[name] = true end
    H.truthy(names["fb-bus-pipe"] and names["fb-bus-pipe-to-ground"], "obě v mod-data")
  end),
  check("recept je za výzkumem fb-fluid-bus", function()
    local recipe = prototypes.recipe["fb-bus-pipe"]
    H.truthy(recipe, "recept")
    H.eq(recipe.enabled, false, "zamčený")
    local techs = H.unlocking_techs("fb-bus-pipe")
    H.eq(techs[1], "fb-fluid-bus", "odemyká fb-fluid-bus")
    H.truthy(prototypes.technology["fb-fluid-bus"].prerequisites["fluid-handling"], "prerekvizita fluid-handling")
  end),
  {
    name = "BUS trubka se napojí na běžnou (jeden segment)",
    setup = function(ctx)
      ctx.plain = H.place(ctx, "pipe", 0, 0)
      ctx.bus = H.place(ctx, "fb-bus-pipe", 1, 0)
      ctx.plain.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(ctx.bus.fluidbox.get_fluid_segment_id(1), ctx.plain.fluidbox.get_fluid_segment_id(1), "stejný segment")
    end } },
  },
  {
    name = "BUS podzemní dvojice se propojí (vzdálenost 9 políček)",
    setup = function(ctx)
      ctx.a = H.place(ctx, "fb-bus-pipe-to-ground", 0, 0, { direction = defines.direction.west })
      ctx.b = H.place(ctx, "fb-bus-pipe-to-ground", 9, 0, { direction = defines.direction.east })
      ctx.a.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(ctx.a.fluidbox.get_fluid_segment_id(1), ctx.b.fluidbox.get_fluid_segment_id(1), "stejný segment")
    end } },
  },
  {
    name = "rychlá výměna běžné trubky za BUS zachová kapalinu",
    setup = function(ctx)
      ctx.left = H.place(ctx, "pipe", 0, 0)
      H.place(ctx, "pipe", 1, 0)
      H.place(ctx, "pipe", 2, 0)
      ctx.left.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 5, run = function(ctx)
        ctx.replaced = H.place(ctx, "fb-bus-pipe", 1, 0, { fast_replace = true, spill = false })
      end },
      { ticks = 5, run = function(ctx)
        H.eq(ctx.replaced.name, "fb-bus-pipe", "na místě je BUS trubka")
        local total = ctx.left.fluidbox.get_fluid_segment_contents(1).water or 0
        H.truthy(math.abs(total - 300) < 0.01, "voda zachována (" .. total .. ")")
      end },
    },
  },
  check("suroviny BUS receptů jsou dostupné nejpozději s výzkumem", function()
    H.eq(H.unreachable_ingredients(), "", "nedostupné suroviny")
  end),
}
```

V `tests/fluid-bus-tests/control.lua` nahradit registraci:

```lua
runner.register(require("cases.smoke"))
runner.register(require("cases.bus_pipes"))
```

- [ ] **Step 3: Spustit – musí selhat**

Run: `bash tools/run-tests.sh vanilla`
Expected: `FB-TEST FAIL BUS trubka a podzemní existují…` (prototypy ještě nevznikají), `fail` > 0.

- [ ] **Step 4: Implementace – `fluid-bus/data-final-fixes.lua`**

```lua
-- Generování BUS trubek až po načtení všech modů, aby se zahrnuly i trubky z jiných modů.
local bus_pipes = require("prototypes.bus_pipes")
local overlay = require("prototypes.bus_overlay")
local research = require("prototypes.research")

local pairs_, skipped = bus_pipes.collect(data.raw)
for _, entry in ipairs(skipped) do
  log("fluid-bus: vynecháno " .. entry.name .. " (" .. entry.reason .. ")")
end

local marking = bus_pipes.marking_item(data.raw)
local names = {}

--- Vytvoří BUS entitu, předmět a recept k jedné původní entitě; vrátí jméno receptu.
--- @param type_name string "pipe" | "pipe-to-ground"
--- @param source string jméno původní entity
--- @param source_item string původní předmět
--- @param count integer kusů na recept
local function create(type_name, source, source_item, count)
  local entity = bus_pipes.entity(data.raw[type_name][source], table.deepcopy, function(new)
    local missing = overlay.decorate(new, table.deepcopy)
    if #missing > 0 then log("fluid-bus: bez označení " .. new.name .. ": " .. table.concat(missing, ", ")) end
  end)
  local item = bus_pipes.item(data.raw, source_item, entity, overlay.icons(data.raw.item[source_item], table.deepcopy))
  local recipe = bus_pipes.recipe(source_item, count, marking, item.name)
  data:extend({ entity, item, recipe })
  names[#names + 1] = entity.name
  return recipe
end

-- Základní výzkum: prerekvizity = výzkumy pumpy a značení.
local base_items = { table.unpack(research.BASE_ITEMS) }
if marking then base_items[#base_items + 1] = marking end
local base_direct = research.techs_for_items(data.raw, base_items)
local base_spec = research.technology(data.raw, base_direct, bus_pipes.PREFIX .. "pipe")
local base_tech
if base_spec then
  base_tech = {
    type = "technology",
    name = research.BASE_TECH,
    icons = overlay.icons(data.raw.item.pipe or data.raw.item.pump, table.deepcopy),
    prerequisites = base_spec.prerequisites,
    unit = base_spec.unit,
    research_trigger = base_spec.research_trigger,
    effects = {},
  }
  data:extend({ base_tech })
end

for _, pair in ipairs(pairs_) do
  local recipes = { create("pipe", pair.pipe, pair.pipe_item, 1) }
  if pair.underground then
    recipes[2] = create("pipe-to-ground", pair.underground, pair.underground_item, 2)
  end
  local techs = {}
  if pair.pipe_tech then techs[pair.pipe_tech] = true end
  if pair.underground_tech then techs[pair.underground_tech] = true end
  local target
  if base_tech and research.covered(data.raw, base_tech.prerequisites, techs) then
    target = base_tech
  elseif next(techs) or base_tech then
    if base_tech then techs[research.BASE_TECH] = true end
    local spec = research.technology(data.raw, techs, recipes[1].name)
    target = {
      type = "technology",
      name = research.BASE_TECH .. "-" .. pair.pipe,
      localised_name = { "technology-name.fb-fluid-bus-pipe", data.raw.pipe[pair.pipe].localised_name or { "entity-name." .. pair.pipe } },
      localised_description = { "technology-description.fb-fluid-bus-pipe" },
      icons = data.raw.item[recipes[1].name].icons,
      prerequisites = spec.prerequisites,
      unit = spec.unit,
      research_trigger = spec.research_trigger,
      effects = {},
    }
    data:extend({ target })
  end
  for _, recipe in ipairs(recipes) do
    if target then
      recipe.enabled = false
      table.insert(target.effects, { type = "unlock-recipe", recipe = recipe.name })
    end
    log("fluid-bus: " .. recipe.name .. " ← " .. serpent.line(recipe.ingredients) .. " | výzkum: " .. (target and target.name or "od začátku")
      .. (target and (" | prerekvizity: " .. table.concat(target.prerequisites or {}, ", ")) or ""))
  end
end

data:extend({ { type = "mod-data", name = "fb-data", data = { bus_pipes = names } } })
```

- [ ] **Step 5: Locale – doplnit do `fluid-bus/locale/en/locale.cfg`**

```
[entity-name]
fb-bus-pipe=BUS: __1__

[entity-description]
fb-bus-pipe=Pipe for the main bus. Behaves like the original pipe and connects to ordinary pipes. Only BUS pipes accept a bus coupler. Marked "BUS" on straight pieces and "B" elsewhere.

[item-description]
fb-bus-pipe=Pipe for the main bus. Behaves like the original pipe and connects to ordinary pipes. Only BUS pipes accept a bus coupler. Marked "BUS" on straight pieces and "B" elsewhere.

[technology-name]
fb-fluid-bus=Fluid bus
fb-fluid-bus-pipe=Fluid bus: __1__

[technology-description]
fb-fluid-bus=BUS pipes for the main bus. Bus couplers join BUS pipe segments into one network with an even fill level.
fb-fluid-bus-pipe=BUS variant of this pipe for the main bus.
```

a do `fluid-bus/locale/cs/locale.cfg`:

```
[entity-name]
fb-bus-pipe=BUS: __1__

[entity-description]
fb-bus-pipe=Trubka pro hlavní bus. Chová se jako původní trubka a napojuje se i na běžné trubky. Spojku busu lze napojit jen na BUS trubky. Rovné kusy jsou označené „BUS“, ostatní „B“.

[item-description]
fb-bus-pipe=Trubka pro hlavní bus. Chová se jako původní trubka a napojuje se i na běžné trubky. Spojku busu lze napojit jen na BUS trubky. Rovné kusy jsou označené „BUS“, ostatní „B“.

[technology-name]
fb-fluid-bus=Kapalinový bus
fb-fluid-bus-pipe=Kapalinový bus: __1__

[technology-description]
fb-fluid-bus=BUS trubky pro hlavní bus. Spojky busu propojí segmenty BUS trubek do jedné sítě se stejným naplněním.
fb-fluid-bus-pipe=BUS varianta této trubky pro hlavní bus.
```

- [ ] **Step 6: Spustit všechny testy**

Run: `bash tools/run-unit.sh`
Expected: `UNIT pass=40 fail=0`

Run: `bash tools/run-tests.sh vanilla`
Expected: `FB-TEST DONE pass=7 fail=0 skip=0`

Run: `bash tools/run-tests.sh space-age`
Expected: `FB-TEST DONE pass=7 fail=0 skip=0`

Zkontrolovat log data stage v `.test-run/space-age/create.log` (`grep "fluid-bus:"`): BUS pipe a podzemní
za `fb-fluid-bus`, žádné neočekávané „vynecháno“ (recyklační recepty Space Age se nesmí projevit).

- [ ] **Step 7: Commit (na pokyn uživatele)**

```bash
git add fluid-bus tests/fluid-bus-tests
git commit -m "feat: generování BUS trubek ve hře, výzkum a integrační testy"
```

---

### Task 9: Kompatibilita s Pyanodon a Bob's

**Files:**
- Create: `tests/fluid-bus-tests/cases/compat.lua`
- Modify: `tests/fluid-bus-tests/control.lua` – registrace `cases.compat`
- Create: `docs/development.md` (sekce „Kompatibilita“, „Kde ladit hodnoty“, „Testy“)

**Interfaces:**
- Consumes: `fb-data`, `helpers.lua` (Task 8).
- Produces: obecné kontroly spouštěné i ve variantě `mods` (runner v ní nechá jen `cases.compat`).

- [ ] **Step 1: Test – `tests/fluid-bus-tests/cases/compat.lua`**

```lua
--- Obecné kontroly BUS trubek platné s jakoukoli sadou modů (spouští je i varianta „mods“).
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

return {
  check("kompatibilita: BUS varianty vznikly a jsou dostupné", function()
    local names = prototypes.mod_data["fb-data"].data.bus_pipes
    H.truthy(#names > 0, "aspoň jedna BUS trubka")
    for _, name in ipairs(names) do
      H.truthy(prototypes.entity[name], "entita " .. name)
      local recipe = prototypes.recipe[name]
      H.truthy(recipe, "recept " .. name)
      H.truthy(recipe.enabled or #H.unlocking_techs(name) > 0, "výzkum nebo recept od začátku " .. name)
    end
    log("FB-TEST INFO BUS trubky: " .. table.concat(names, ", "))
  end),
  check("kompatibilita: BUS konektory mají kategorii fb-bus i původní kategorie", function()
    for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do
      local source = prototypes.entity[name:sub(#"fb-bus-" + 1)]
      local bus_connections = prototypes.entity[name].fluidbox_prototypes[1].pipe_connections
      local source_connections = source.fluidbox_prototypes[1].pipe_connections
      for i, connection in ipairs(bus_connections) do
        local categories = {}
        for _, c in ipairs(connection.connection_category) do categories[c] = true end
        H.truthy(categories["fb-bus"], name .. " konektor " .. i .. " fb-bus")
        for _, c in ipairs(source_connections[i].connection_category) do
          H.truthy(categories[c], name .. " konektor " .. i .. " zachová " .. c)
        end
      end
    end
  end),
  check("kompatibilita: suroviny dostupné nejpozději s výzkumem", function()
    H.eq(H.unreachable_ingredients(), "", "nedostupné suroviny")
  end),
}
```

Pozn.: runtime `PipeConnectionDefinition` má pole `connection_category` (ověřeno v
`doc-html/runtime-api.json`); pokud ho hra vrací jako řetězec místo pole, převést ho před cyklem
na `{ hodnota }`.

Registrace v `control.lua`: `runner.register(require("cases.compat"))` (řádek musí obsahovat
`cases.compat`, aby ho varianta `mods` ponechala).

- [ ] **Step 2: Spustit vanilla, Space Age, Pyanodon a Bob's**

Run: `bash tools/run-tests.sh vanilla && bash tools/run-tests.sh space-age`
Expected: `FB-TEST DONE pass=10 fail=0 skip=0` v obou.

Run: `bash tools/run-tests.sh mods pymodpack`
Expected: `FB-TEST DONE pass=3 fail=0 skip=0`, v `FB-TEST INFO` mimo jiné `fb-bus-niobium-pipe`,
`fb-bus-niobium-pipe-to-ground`, `fb-bus-ht-pipes`, `fb-bus-ht-pipes-to-ground`.

Run: `bash tools/run-tests.sh mods boblogistics`
Expected: `FB-TEST DONE pass=3 fail=0 skip=0`, BUS varianty Bobových trubek.

Při selhání: přečíst `grep "fluid-bus:" .test-run/mods/create.log` (párování, výzkumy), opravit
logiku v `prototypes/*.lua` **s novým unit testem**, který případ zachytí, a spustit vše znovu.

- [ ] **Step 3: `docs/development.md`**

```markdown
# Vývoj – Fluid Bus

## Prostředí
Factorio 2.0.77 (Steam, `FACTORIO_EXE`), Lua 5.3 pro unit testy, Git Bash pro `tools/*.sh`,
Blender pro overlay grafiku (`blender/build_overlay.py`).

## Struktura
- `fluid-bus/data-final-fixes.lua` – generování BUS trubek ze všech trubek ve hře.
- `fluid-bus/prototypes/availability.lua` – dostupnost předmětů (recepty, výzkumy).
- `fluid-bus/prototypes/bus_pipes.lua` – výběr trubek, párování s podzemními, BUS prototypy.
- `fluid-bus/prototypes/bus_overlay.lua` – označení BUS/B.
- `fluid-bus/prototypes/research.lua` – výzkumy.

## Kde ladit hodnoty
| Co | Kde |
|---|---|
| Surovina značení v receptu (kandidáti) | `prototypes/bus_pipes.lua` – `MARKING` |
| Množství značení na kus | `prototypes/bus_pipes.lua` – `MARKING_PER_PIECE` |
| Doba výroby BUS varianty | `prototypes/bus_pipes.lua` – `CRAFT_TIME` |
| Který tvar trubky má „BUS“ / „B“ | `prototypes/bus_overlay.lua` – `LABELS` |
| Posun nápisu na tvaru trubky | `prototypes/bus_overlay.lua` – `OVERLAY_SHIFT` |
| Velikost písma a obrysu overlaye | `blender/build_overlay.py` – `TEXT_SIZE`, `OUTLINE` |
| Cena výzkumu (násobič) | `prototypes/research.lua` – `TECH_COUNT_MULTIPLIER` |

## Testy
- Unit: `bash tools/run-unit.sh`
- Integrační: `bash tools/run-tests.sh vanilla`, `bash tools/run-tests.sh space-age`
- Kompatibilita: `bash tools/run-tests.sh mods pymodpack`, `bash tools/run-tests.sh mods boblogistics`

## Kompatibilita (ověřeno <datum>, Factorio 2.0.77)
| Mody | Výsledek | Vzniklé BUS varianty |
|---|---|---|
| vanilla | … | … |
| Space Age | … | … |
| pymodpack <verze> | … | … |
| boblogistics <verze> | … | … |

## Ruční kontrola ve hře (před vydáním)
1. BUS trubky: nápis „BUS“ na rovných kusech (vodorovně i svisle), „B“ na rozích, T, kříži,
   koncích a podzemních; čitelné ve dne i v noci.
2. BUS trubka postavená přes běžnou (rychlá výměna) i upgrade planner z běžné na BUS.
3. Ikony předmětů a výzkumů.
```

Tabulku „Kompatibilita“ vyplnit skutečnými výsledky ze Step 2 (datum, verze modů ze jmen zipů,
seznam z `FB-TEST INFO`) – žádné `…` nesmí zůstat.

- [ ] **Step 4: Checkpoint s uživatelem**

Shrnout uživateli: výsledky všech čtyř variant, seznam vzniklých BUS variant, a požádat o ruční
kontrolu ve hře podle „Ruční kontrola“ (body 1–3, včetně Q5 – upgrade planner) po
`bash tools/link-mod.sh`. Pak navrhnout napsání plánu 2 (spojka a runtime) podle výsledků spiku.

- [ ] **Step 5: Commit (na pokyn uživatele)**

```bash
git add tests/fluid-bus-tests docs/development.md
git commit -m "test: kompatibilita BUS trubek s Pyanodon a Bob's"
```
