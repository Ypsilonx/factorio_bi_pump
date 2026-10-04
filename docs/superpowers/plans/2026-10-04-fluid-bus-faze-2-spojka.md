# Fluid Bus – fáze 2 (spojka busu a síťové vyrovnávání) – implementační plán

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spojka busu 1×1 (jen na BUS trubky, na elektřinu), která propojí segmenty BUS trubek do sítě,
rozloženě po ticích vyrovnává jejich naplnění (se zachováním množství i teploty), hlásí stav a vysílá
naplnění sítě do obvodové sítě; ověřené testy, výkonovým testem a s dokumentací pro hráče.

**Architecture:** Prototyp spojky = `assembling-machine` bez receptu se dvěma fluidboxy (kategorie
`fb-bus`), odběr elektřiny přes `drain` (engine). Čistá logika v `scripts/network.lua` (union-find
segmentů) a `scripts/balance_math.lua` (cílové naplnění, plán přelití, míchání teplot) – unit testy.
Runtime: `registry` (evidence spojek + skrytý kombinátor signálů), `topology` (segmenty, zástupné BUS
trubky, přestavba sítí), `balancer` (rozložený plánovač po ticích), `signals` (signály + stav). Čtení
i zápis kapaliny přes **sousední BUS trubku** (spec 8.1).

**Tech Stack:** Factorio 2.0.77, Lua 5.2 (hra) / 5.3 (unit), Git Bash, headless `--benchmark`.

**Spec:** `docs/superpowers/specs/2026-10-04-fluid-bus-design.md` (sekce 3.2–3.6, 4, 5, 7, 8.1, 10)

## Global Constraints

- Factorio 2.0 (2.0.77), vanilla i Space Age. Jméno modu `fluid-bus`, prefix `fb-`, tag testů `FB`.
- Spojka: `fb-bus-coupler`, skrytý kombinátor `fb-bus-coupler-signals`, kategorie receptů
  `fb-coupler`, signál `fb-fill`. Startup nastavení `fb-coupler-power` (kW, výchozí 50) a
  `fb-balance-interval` (ticky, výchozí 60).
- Naše prototypy se v runtime hledají přes `prototypes.mod_data["fb-data"].data`, ne podle prefixu.
- Stav jen ve `storage`; `on_load` ho nemění; před použitím uložené entity `valid`.
- Docstringy a komentáře česky, locale `en` + `cs` se stejnými klíči, veřejné texty anglicky.
- **Commit jen na výslovný pokyn uživatele** (kroky „Commit“ = nabídnout, nečekat).
- Žádná práce nad všemi entitami v každém ticku; vše rozložené přes `fb-balance-interval`.

## Review Focus

1. **Spojka postavená, než je vedle ní BUS trubka** (nebo trubka zbořena) → stav „Nepřipojeno“, nic
   nepadá, po dostavění se sama připojí. Test: Task 5 „trubka dostavěná později“.
2. **Zbourání spojky uprostřed přelévání** → kapalina v bufferu se vrátí do segmentů, celkové množství
   sedí. Test: Task 5 „odstranění spojky zachová množství“.
3. **Dvě různé kapaliny v jedné síti** → nic se nepřelije, stav „Různé kapaliny“. Test: Task 5.
4. **Výpadek proudu** → síť se rozpadne, nic se nepřelévá, stav „Bez proudu“. Test: Task 5.
5. **Starý save / změna modů** → `on_configuration_changed` obnoví evidenci a skryté kombinátory.
   Test: Task 7 „revalidace po ztrátě kombinátoru“.

---

### Task 1: Prototyp spojky, nastavení, signál, recept a výzkum

**Files:**
- Create: `fluid-bus/settings.lua`
- Create: `fluid-bus/prototypes/coupler.lua`
- Modify: `fluid-bus/data.lua`, `fluid-bus/data-final-fixes.lua`, `fluid-bus/prototypes/research.lua:15`
- Modify: `fluid-bus/locale/en/locale.cfg`, `fluid-bus/locale/cs/locale.cfg`
- Create: `tests/unit/test_coupler.lua`; Modify: `tests/unit/run.lua` (SUITES + `"test_coupler"`)
- Create: `tests/fluid-bus-tests/cases/coupler.lua`; Modify: `tests/fluid-bus-tests/control.lua`
- Modify: `tests/fluid-bus-tests/helpers.lua` (přidat `H.power`)

**Interfaces:**
- Produces: `coupler.NAME`, `coupler.SIGNALS`, `coupler.CATEGORY`, `coupler.FLUID_VOLUME`,
  `coupler.INGREDIENTS`, `coupler.ingredients(raw) -> table[]` (čistá), `coupler.prototypes(power_kw) -> table[]`
  (data stage). `fb-data` doplněno o `coupler`, `coupler_signals`, `interval`.
  `research.BASE_ITEMS = { "pump", "electronic-circuit" }`.
  `H.power(ctx, x, y)` – napájení dlaždice (x, y) v testu.

- [ ] **Step 1: Unit test surovin – `tests/unit/test_coupler.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy surovin receptu spojky (náhrady pro mody, které předměty odstraní).
local A = require("assert")
local F = require("fake_raw")
local coupler = require("prototypes.coupler")

return {
  { "suroviny: první existující kandidát, chybějící vynechány", function()
    local raw = F.new()
    F.item(raw, "pump")
    F.item(raw, "iron-plate")
    local list = coupler.ingredients(raw)
    local names = {}
    for _, i in ipairs(list) do names[#names + 1] = i.name .. "×" .. i.amount end
    A.eq(table.concat(names, ","), "pump×1,iron-plate×5", "pumpa a náhrada oceli, bez obvodů")
  end },
}
```

Run: `bash tools/run-unit.sh` → Expected: FAIL `module 'prototypes.coupler' not found`.

- [ ] **Step 2: `fluid-bus/settings.lua`**

```lua
-- Startup nastavení modu (mění prototypy, proto startup).
data:extend({
  { type = "double-setting", name = "fb-coupler-power", setting_type = "startup",
    default_value = 50, minimum_value = 0, maximum_value = 10000, order = "a" },
  { type = "int-setting", name = "fb-balance-interval", setting_type = "startup",
    default_value = 60, minimum_value = 10, maximum_value = 3600, order = "b" },
})
```

- [ ] **Step 3: `fluid-bus/prototypes/coupler.lua`**

```lua
--- Spojka busu: assembling-machine 1×1 bez receptu se dvěma oddělenými fluidboxy (kategorie fb-bus),
--- napájená elektřinou (drain), a skrytý konstantní kombinátor, přes který vysílá signály.
--- Typ zvolen podle spiku (spec 8.1): dva segmenty, napájení, dráty, rotace. Kapalinu přelévá skript.
local M = {}

M.NAME = "fb-bus-coupler"
M.SIGNALS = "fb-bus-coupler-signals"
M.CATEGORY = "fb-coupler"
--- Objem fluidboxu spojky – započítá se do kapacity segmentu, proto malý. Laditelné.
M.FLUID_VOLUME = 10
--- Suroviny receptu: { kandidáti, počet } – první existující předmět vyhrává. Laditelné.
M.INGREDIENTS = {
  { { "pump" }, 1 },
  { { "electronic-circuit" }, 5 },
  { { "steel-plate", "iron-plate" }, 5 },
}
--- Odstín dočasné grafiky (vanilla trubka). Laditelné.
M.TINT = { 0.55, 0.75, 1.0 }

--- Suroviny receptu z kandidátů; chybějící předměty se vynechají.
--- @param raw table data.raw
--- @return table[] suroviny ve formátu receptu
function M.ingredients(raw)
  local list = {}
  for _, spec in ipairs(M.INGREDIENTS) do
    for _, candidate in ipairs(spec[1]) do
      if raw.item[candidate] then
        list[#list + 1] = { type = "item", name = candidate, amount = spec[2] }
        break
      end
    end
  end
  return list
end

--- Fluidbox spojky na jedné straně (jen kategorie fb-bus → napojí se jen na BUS trubky).
local function box(production_type, direction)
  return {
    production_type = production_type,
    volume = M.FLUID_VOLUME,
    pipe_connections = { { flow_direction = "input-output", direction = direction,
      position = { 0, 0 }, connection_category = { "fb-bus" } } },
  }
end

--- Dočasná grafika: obarvená vanilla trubka ve směru spojky.
local function sprite(file)
  return { filename = "__base__/graphics/entity/pipe/pipe-straight-" .. file .. ".png",
    width = 128, height = 128, scale = 0.5, frame_count = 1, tint = M.TINT }
end

--- Prototypy spojky (entita, předmět, kategorie, skrytý kombinátor, signál). Volá se v data.lua.
--- @param power_kw number odběr spojky v kW (startup nastavení)
--- @return table[]
function M.prototypes(power_kw)
  local icons = { { icon = "__base__/graphics/icons/pump.png", icon_size = 64, tint = M.TINT },
    { icon = "__fluid-bus__/graphics/icons/b.png", icon_size = 64 } }
  local entity = {
    type = "assembling-machine",
    name = M.NAME,
    icons = icons,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.2, result = M.NAME },
    max_health = 150,
    corpse = "small-remnants",
    collision_box = { { -0.29, -0.29 }, { 0.29, 0.29 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    crafting_categories = { M.CATEGORY },
    crafting_speed = 1,
    energy_source = { type = "electric", usage_priority = "secondary-input", drain = power_kw .. "kW" },
    energy_usage = "1W",
    fluid_boxes_off_when_no_fluid_recipe = false,
    fluid_boxes = { box("input", defines.direction.north), box("output", defines.direction.south) },
    module_slots = 0,
    allowed_effects = {},
    circuit_wire_max_distance = 9,
    circuit_connector = table.deepcopy(data.raw.pump.pump.circuit_connector),
    graphics_set = { animation = {
      north = sprite("vertical"), south = sprite("vertical"),
      east = sprite("horizontal"), west = sprite("horizontal"),
    } },
    localised_description = { "entity-description.fb-bus-coupler" },
  }
  local signals = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
  signals.name = M.SIGNALS
  signals.hidden = true
  signals.flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid",
    "not-selectable-in-game", "hide-alt-info", "not-upgradable", "no-copy-paste" }
  signals.minable = nil
  signals.collision_mask = { layers = {} }
  signals.collision_box = nil
  signals.selection_box = nil
  signals.sprites = { filename = "__core__/graphics/empty.png", size = 1 }
  signals.activity_led_sprites = nil
  signals.draw_circuit_wires = false
  signals.circuit_wire_max_distance = 1
  return {
    { type = "recipe-category", name = M.CATEGORY },
    entity,
    signals,
    { type = "item", name = M.NAME, icons = icons, subgroup = "energy-pipe-distribution",
      order = "c[pump]-b[fb-bus-coupler]", place_result = M.NAME, stack_size = 50 },
    { type = "virtual-signal", name = "fb-fill", icons = icons, subgroup = "virtual-signal", order = "z[fb-fill]" },
  }
end

return M
```

- [ ] **Step 4: `fluid-bus/data.lua`**

```lua
-- Prototypy nezávislé na jiných modech: spojka busu a její pomocné prototypy.
local coupler = require("prototypes.coupler")

data:extend(coupler.prototypes(settings.startup["fb-coupler-power"].value))
```

- [ ] **Step 5: Recept spojky a výzkum – `fluid-bus/data-final-fixes.lua` a `research.lua`**

V `fluid-bus/prototypes/research.lua` změnit `M.BASE_ITEMS = { "pump" }` na
`M.BASE_ITEMS = { "pump", "electronic-circuit" }` (komentář: „suroviny spojky + pumpa“).

V `data-final-fixes.lua` přidat `local coupler = require("prototypes.coupler")` k ostatním require
a hned za blok, který vytváří `base_tech` (za `end` bloku `if base_spec then … end`), vložit:

```lua
-- Recept spojky (suroviny podle toho, co ve hře existuje) – odemyká ho základní výzkum.
local coupler_recipe = {
  type = "recipe",
  name = coupler.NAME,
  enabled = base_tech == nil,
  energy_required = 2,
  ingredients = coupler.ingredients(data.raw),
  results = { { type = "item", name = coupler.NAME, amount = 1 } },
}
data:extend({ coupler_recipe })
if base_tech then table.insert(base_tech.effects, { type = "unlock-recipe", recipe = coupler.NAME }) end
if mods["quality"] then
  require("__quality__.prototypes.recycling").generate_recycling_recipe(coupler_recipe)
end
log("fluid-bus: " .. coupler.NAME .. " ← " .. serpent.line(coupler_recipe.ingredients))
```

A poslední řádek (`mod-data`) nahradit:

```lua
data:extend({ { type = "mod-data", name = "fb-data", data = {
  bus_pipes = names,
  coupler = coupler.NAME,
  coupler_signals = coupler.SIGNALS,
  interval = settings.startup["fb-balance-interval"].value,
} } })
```

- [ ] **Step 6: Locale (en + cs)**

`en`:
```
[entity-name]
fb-bus-coupler=Bus coupler

[entity-description]
fb-bus-coupler=Joins segments of BUS pipes into one network with an even fill level. Connects only to BUS pipes and needs electricity. Place it in the bus instead of a pump.

[item-description]
fb-bus-coupler=Joins segments of BUS pipes into one network with an even fill level. Connects only to BUS pipes and needs electricity. Place it in the bus instead of a pump.

[virtual-signal-name]
fb-fill=Bus fill (%)

[mod-setting-name]
fb-coupler-power=Bus coupler power (kW)
fb-balance-interval=Balancing interval (ticks)

[mod-setting-description]
fb-coupler-power=Constant power consumption of one bus coupler.
fb-balance-interval=How often the whole bus network is balanced. Lower = faster balancing, higher UPS cost.

[fb-status]
ok=Bus: __1__ segments, __2__ %
no-power=No power
not-connected=Not connected to a BUS pipe
conflict=Different fluids in the bus network
```
`cs`:
```
[entity-name]
fb-bus-coupler=Spojka busu

[entity-description]
fb-bus-coupler=Propojí segmenty BUS trubek do jedné sítě se stejným naplněním. Napojí se jen na BUS trubky a potřebuje elektřinu. Stav se do busu místo pumpy.

[item-description]
fb-bus-coupler=Propojí segmenty BUS trubek do jedné sítě se stejným naplněním. Napojí se jen na BUS trubky a potřebuje elektřinu. Stav se do busu místo pumpy.

[virtual-signal-name]
fb-fill=Naplnění busu (%)

[mod-setting-name]
fb-coupler-power=Odběr spojky busu (kW)
fb-balance-interval=Interval vyrovnávání (ticky)

[mod-setting-description]
fb-coupler-power=Stálý odběr elektřiny jedné spojky busu.
fb-balance-interval=Jak často se vyrovná celá síť busu. Menší = rychlejší vyrovnání, vyšší zátěž UPS.

[fb-status]
ok=Bus: __1__ segmentů, __2__ %
no-power=Bez proudu
not-connected=Nepřipojeno k BUS trubce
conflict=V síti busu jsou různé kapaliny
```
Sekce `[entity-name]`, `[entity-description]`, `[item-description]` už existují – klíče přidat do nich
(ne druhou sekci).

- [ ] **Step 7: Pomocník napájení – přidat do `tests/fluid-bus-tests/helpers.lua` před `return H`**

```lua
--- Napájí dlaždici (x, y) testu: malý sloup vedle ní a nekonečný zdroj energie.
function H.power(ctx, x, y)
  H.place(ctx, "small-electric-pole", x + 1, y + 1)
  local eei = H.place(ctx, "electric-energy-interface", x + 3, y + 2)
  eei.electric_buffer_size = 1e9
  eei.power_production = 1e6
end
```

- [ ] **Step 8: Integrační testy prototypu – `tests/fluid-bus-tests/cases/coupler.lua`**

```lua
--- Integrační testy spojky busu: prototyp, napojení, napájení.
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

return {
  check("spojka existuje a odemyká ji fb-fluid-bus", function()
    local data = prototypes.mod_data["fb-data"].data
    H.eq(data.coupler, "fb-bus-coupler", "mod-data")
    H.truthy(prototypes.entity["fb-bus-coupler"], "entita")
    H.eq(H.unlocking_techs("fb-bus-coupler")[1], "fb-fluid-bus", "výzkum")
  end),
  {
    name = "spojka se na běžnou trubku nenapojí, na BUS ano (dva segmenty)",
    setup = function(ctx)
      H.place(ctx, "pipe", 0, -1)
      ctx.plain = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.place(ctx, "pipe", 0, 1)
      H.place(ctx, "fb-bus-pipe", 3, -1)
      ctx.bus = H.place(ctx, "fb-bus-coupler", 3, 0)
      H.place(ctx, "fb-bus-pipe", 3, 1)
    end,
    steps = { { ticks = 2, run = function(ctx)
      H.eq(#ctx.plain.fluidbox.get_connections(1) + #ctx.plain.fluidbox.get_connections(2), 0, "běžná trubka")
      H.eq(#ctx.bus.fluidbox.get_connections(1), 1, "BUS nahoře")
      H.eq(#ctx.bus.fluidbox.get_connections(2), 1, "BUS dole")
      H.truthy(ctx.bus.fluidbox.get_fluid_segment_id(1) ~= ctx.bus.fluidbox.get_fluid_segment_id(2), "dva segmenty")
    end } },
  },
  {
    name = "napájená spojka má energii, nenapájená ne",
    setup = function(ctx)
      ctx.on = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.power(ctx, 0, 0)
      ctx.off = H.place(ctx, "fb-bus-coupler", 8, 0)
    end,
    steps = { { ticks = 30, run = function(ctx)
      H.truthy(ctx.on.energy > 0, "napájená")
      H.eq(ctx.off.energy, 0, "nenapájená")
    end } },
  },
}
```

V `tests/fluid-bus-tests/control.lua` přidat `runner.register(require("cases.coupler"))`.

- [ ] **Step 9: Spustit vše**

Run: `bash tools/run-unit.sh` → Expected: `UNIT pass=42 fail=0`
Run: `bash tools/run-tests.sh vanilla` → Expected: `FB-TEST DONE pass=15 fail=0 skip=1`
Run: `bash tools/run-tests.sh space-age` → Expected: `FB-TEST DONE pass=16 fail=0 skip=0`
Když načtení selže na poli prototypu (např. `circuit_connector` pumpy, grafika `animation`), opravit
podle chybové hlášky a rozhodnutí zapsat do ledgeru.

- [ ] **Step 10: Commit (na pokyn)** – `feat: prototyp spojky busu, nastavení, recept a výzkum`

---

### Task 2: Sítě segmentů (`scripts/network.lua`, čistá logika)

**Files:**
- Create: `fluid-bus/scripts/network.lua`, `tests/unit/test_network.lua`; Modify: `tests/unit/run.lua`

**Interfaces:**
- Produces: `network.build(edges) -> networks`; `edges[i] = { id = unit_number, a = seg|nil, b = seg|nil, active = bool }`;
  `networks[i] = { segments = int[] (vzestupně), couplers = int[] (vzestupně) }`, pořadí sítí podle
  nejmenšího segmentu. Hrana se použije jen když `active`, `a` i `b` jsou čísla a `a ~= b`.

- [ ] **Step 1: Failing testy – `tests/unit/test_network.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy skládání sítí ze segmentů a spojek.
local A = require("assert")
local network = require("scripts.network")

--- Seznam čísel jako text.
local function list(t) return table.concat(t, ",") end

return {
  { "řetěz dvou spojek = jedna síť tří segmentů", function()
    local nets = network.build({ { id = 1, a = 10, b = 11, active = true }, { id = 2, a = 11, b = 12, active = true } })
    A.eq(#nets, 1, "sítě")
    A.eq(list(nets[1].segments), "10,11,12", "segmenty")
    A.eq(list(nets[1].couplers), "1,2", "spojky")
  end },
  { "neaktivní spojka síť rozdělí", function()
    local nets = network.build({ { id = 1, a = 10, b = 11, active = true }, { id = 2, a = 11, b = 12, active = false },
      { id = 3, a = 12, b = 13, active = true } })
    A.eq(#nets, 2, "dvě sítě")
    A.eq(list(nets[1].segments), "10,11", "první")
    A.eq(list(nets[2].segments), "12,13", "druhá")
  end },
  { "spojka bez trubky na jedné straně nebo se stejným segmentem se nepoužije", function()
    local nets = network.build({ { id = 1, a = nil, b = 11, active = true }, { id = 2, a = 5, b = 5, active = true } })
    A.eq(#nets, 0, "žádná síť")
  end },
  { "paralelní spojky mezi stejnými segmenty = jedna síť", function()
    local nets = network.build({ { id = 7, a = 20, b = 21, active = true }, { id = 3, a = 21, b = 20, active = true } })
    A.eq(#nets, 1, "jedna síť")
    A.eq(list(nets[1].couplers), "3,7", "obě spojky, seřazené")
  end },
}
```

Do `SUITES` přidat `"test_network"`. Unit runner hledá moduly v `fluid-bus/?.lua`, takže
`require("scripts.network")` funguje. Run: `bash tools/run-unit.sh` → Expected: FAIL `module 'scripts.network' not found`.

- [ ] **Step 2: Implementace – `fluid-bus/scripts/network.lua`**

```lua
--- Čistá logika sítí busu: segmenty (uzly) spojené aktivními spojkami (hrany) → komponenty.
--- Bez herního API, testy: tests/unit/test_network.lua.
local M = {}

--- Kořen prvku v union-find (s kompresí cesty).
--- @param parent table<integer, integer>
--- @param x integer
--- @return integer
local function find(parent, x)
  while parent[x] ~= x do
    parent[x] = parent[parent[x]]
    x = parent[x]
  end
  return x
end

--- Složí sítě z hran. Deterministické pořadí: segmenty i spojky vzestupně, sítě podle nejmenšího segmentu.
--- @param edges table[] { id, a, b, active }
--- @return table[] { segments = integer[], couplers = integer[] }
function M.build(edges)
  local parent, used = {}, {}
  for _, edge in ipairs(edges) do
    if edge.active and edge.a and edge.b and edge.a ~= edge.b then
      parent[edge.a] = parent[edge.a] or edge.a
      parent[edge.b] = parent[edge.b] or edge.b
      local ra, rb = find(parent, edge.a), find(parent, edge.b)
      if ra ~= rb then
        if ra < rb then parent[rb] = ra else parent[ra] = rb end
      end
      used[#used + 1] = edge
    end
  end
  local by_root, roots = {}, {}
  for segment in pairs(parent) do
    local root = find(parent, segment)
    if not by_root[root] then
      by_root[root] = { segments = {}, couplers = {} }
      roots[#roots + 1] = root
    end
    table.insert(by_root[root].segments, segment)
  end
  for _, edge in ipairs(used) do table.insert(by_root[find(parent, edge.a)].couplers, edge.id) end
  table.sort(roots)
  local result = {}
  for _, root in ipairs(roots) do
    local net = by_root[root]
    table.sort(net.segments)
    table.sort(net.couplers)
    result[#result + 1] = net
  end
  return result
end

return M
```

Run: `bash tools/run-unit.sh` → Expected: `UNIT pass=46 fail=0`

- [ ] **Step 3: Commit (na pokyn)** – `feat: skládání sítí segmentů (union-find)`

---

### Task 3: Matematika vyrovnávání (`scripts/balance_math.lua`, čistá logika)

**Files:**
- Create: `fluid-bus/scripts/balance_math.lua`, `tests/unit/test_balance_math.lua`; Modify: `tests/unit/run.lua`

**Interfaces:**
- Produces: `TOLERANCE` (podíl kapacity), `target_fraction(total, buffer, capacity) -> number`,
  `plan(amount, capacity, fraction, buffer) -> delta` (>0 doplnit ze zásobníku, <0 odebrat do něj),
  `mix(buffer, amount, temperature) -> buffer`, `take(buffer, amount) -> buffer`;
  `buffer = { amount = number, temperature = number|nil }`.

- [ ] **Step 1: Failing testy – `tests/unit/test_balance_math.lua`**

```lua
---@diagnostic disable: undefined-global
--- Testy matematiky vyrovnávání: cílové naplnění, plán přelití, míchání teplot.
local A = require("assert")
local m = require("scripts.balance_math")

--- Shoda čísel s tolerancí.
local function near(actual, expected, what)
  A.truthy(math.abs(actual - expected) < 1e-6, what .. ": čekáno " .. expected .. ", dostáno " .. actual)
end

return {
  { "cílové naplnění zahrnuje zásobník a je nejvýš 1", function()
    near(m.target_fraction(300, 100, 1000), 0.4, "0.4")
    near(m.target_fraction(2000, 0, 1000), 1, "strop 1")
    near(m.target_fraction(0, 0, 0), 0, "nulová kapacita")
  end },
  { "plán: přebytek odebrat, nedostatek doplnit jen kolik zásobník má", function()
    near(m.plan(800, 1000, 0.5, 0), -300, "odebrat 300")
    near(m.plan(100, 1000, 0.5, 250), 250, "doplnit jen 250")
    near(m.plan(100, 1000, 0.5, 9999), 400, "doplnit 400")
  end },
  { "plán: v toleranci nic", function()
    near(m.plan(499, 1000, 0.5, 100), 0, "odchylka 1 < tolerance")
  end },
  { "míchání: vážený průměr teplot", function()
    local b = m.mix({ amount = 1000, temperature = 500 }, 1000, 165)
    near(b.amount, 2000, "množství")
    near(b.temperature, 332.5, "teplota")
    local empty = m.mix({ amount = 0 }, 10, 15)
    near(empty.temperature, 15, "prázdný zásobník převezme teplotu")
  end },
  { "odběr ze zásobníku: zbytek nebo prázdný", function()
    local b = m.take({ amount = 100, temperature = 200 }, 40)
    near(b.amount, 60, "zbytek")
    near(b.temperature, 200, "teplota zůstává")
    local e = m.take({ amount = 100, temperature = 200 }, 100)
    near(e.amount, 0, "prázdný")
    A.eq(e.temperature, nil, "bez teploty")
  end },
}
```

Do `SUITES` přidat `"test_balance_math"`. Run → Expected: FAIL `module 'scripts.balance_math' not found`.

- [ ] **Step 2: Implementace – `fluid-bus/scripts/balance_math.lua`**

```lua
--- Čistá matematika vyrovnávání sítě busu. Kapalina se přelévá přes zásobník sítě (buffer):
--- přebytek segmentu se do něj odebere, nedostatek se z něj doplní – množství se tak přesně zachovává.
--- Bez herního API, testy: tests/unit/test_balance_math.lua.
local M = {}

--- Odchylka od cíle (podíl kapacity segmentu), pod kterou se nepřelévá – šetří UPS. Laditelné.
M.TOLERANCE = 0.005

--- Cílové naplnění sítě (0–1): veškerá kapalina včetně zásobníku rozdělená na celkovou kapacitu.
--- @param total_amount number součet kapaliny v segmentech
--- @param buffer_amount number kapalina v zásobníku sítě
--- @param total_capacity number součet kapacit segmentů
--- @return number
function M.target_fraction(total_amount, buffer_amount, total_capacity)
  if total_capacity <= 0 then return 0 end
  return math.min(1, (total_amount + buffer_amount) / total_capacity)
end

--- Kolik kapaliny přelít u segmentu.
--- @param amount number kapalina v segmentu
--- @param capacity number kapacita segmentu
--- @param fraction number cílové naplnění
--- @param buffer_amount number kolik má zásobník
--- @return number >0 doplnit ze zásobníku, <0 odebrat do zásobníku, 0 nic
function M.plan(amount, capacity, fraction, buffer_amount)
  local delta = fraction * capacity - amount
  if math.abs(delta) < M.TOLERANCE * capacity then return 0 end
  if delta > 0 then return math.min(delta, buffer_amount) end
  return delta
end

--- Přidá kapalinu do zásobníku; teplota = vážený průměr.
--- @param buffer table { amount, temperature? }
--- @param amount number
--- @param temperature number|nil teplota přidávané kapaliny (nil = převezme teplotu zásobníku)
--- @return table nový zásobník
function M.mix(buffer, amount, temperature)
  if amount <= 0 then return buffer end
  temperature = temperature or buffer.temperature
  local total = buffer.amount + amount
  local mixed = temperature
  if buffer.temperature and temperature then
    mixed = (buffer.temperature * buffer.amount + temperature * amount) / total
  end
  return { amount = total, temperature = mixed }
end

--- Odebere kapalinu ze zásobníku.
--- @param buffer table
--- @param amount number
--- @return table nový zásobník (prázdný = bez teploty)
function M.take(buffer, amount)
  local left = buffer.amount - amount
  if left <= 1e-9 then return { amount = 0 } end
  return { amount = left, temperature = buffer.temperature }
end

return M
```

Run → Expected: `UNIT pass=51 fail=0`

- [ ] **Step 3: Commit (na pokyn)** – `feat: matematika vyrovnávání sítě busu`

---

### Task 4: Evidence spojek a topologie (runtime)

**Files:**
- Create: `fluid-bus/scripts/registry.lua`, `fluid-bus/scripts/topology.lua`
- Modify: `fluid-bus/control.lua`
- Create: `fluid-bus/scripts/remote.lua`
- Create: `tests/fluid-bus-tests/cases/network.lua`; Modify: `tests/fluid-bus-tests/control.lua`

**Interfaces:**
- Consumes: `network.build` (Task 2), `fb-data.coupler`, `fb-data.coupler_signals`.
- Produces:
  - `storage.couplers[unit] = { entity, signals, sides = { {seg, rep}, {seg, rep} }, powered }`,
    `storage.networks[i] = { segments, couplers, reps = {[seg]=LuaEntity}, amounts, capacities,
    total_amount, total_capacity, buffer = {amount, temperature?}, fluid?, conflict, fraction }`,
    `storage.queue = { {net, seg}… }`, `storage.cursor`, `storage.check_list`, `storage.check_cursor`,
    `storage.dirty`.
  - `registry.init()`, `registry.add(entity)`, `registry.remove(unit)`, `registry.revalidate()`.
  - `topology.refresh(c) -> boolean` (změna), `topology.rebuild()`, `topology.record(net, seg, amount, capacity)`.
  - Remote `fb`: `network_of(unit) -> { fill, amount, fluid, segments, buffer, conflict } | nil`,
    `rebuild()`.

- [ ] **Step 1: Failing integrační test – `tests/fluid-bus-tests/cases/network.lua`**

```lua
--- Integrační testy skládání sítě busu ve hře.
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

return {
  {
    name = "dvě spojky v řadě = jedna síť tří segmentů",
    setup = function(ctx)
      column(ctx, 0, -9, -6)
      ctx.c1 = H.place(ctx, "fb-bus-coupler", 0, -5)
      column(ctx, 0, -4, -1)
      ctx.c2 = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 4)
      H.power(ctx, 0, -5)
      H.power(ctx, 0, 0)
    end,
    steps = { { ticks = 150, run = function(ctx)
      local info = remote.call("fb", "network_of", ctx.c1.unit_number)
      H.truthy(info, "síť existuje")
      H.eq(info.segments, 3, "tři segmenty")
      H.eq(remote.call("fb", "network_of", ctx.c2.unit_number).segments, 3, "druhá spojka ve stejné síti")
    end } },
  },
  {
    name = "trubka dostavěná později spojku připojí",
    setup = function(ctx)
      column(ctx, 0, -4, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.power(ctx, 0, 0)
    end,
    steps = {
      { ticks = 150, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "bez trubky dole není síť")
        column(ctx, 0, 1, 3)
      end },
      { ticks = 150, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number).segments, 2, "připojeno")
      end },
    },
  },
}
```

Registrovat v `control.lua` testů (`runner.register(require("cases.network"))`).
Run: `bash tools/run-tests.sh vanilla` → Expected: FAIL (remote rozhraní `fb` neexistuje).

- [ ] **Step 2: `fluid-bus/scripts/registry.lua`**

```lua
--- Evidence spojek busu ve storage a jejich skrytých kombinátorů signálů.
local data = prototypes.mod_data["fb-data"].data

local M = {}

M.COUPLER = data.coupler
M.SIGNALS = data.coupler_signals

--- Doplní chybějící tabulky ve storage (on_init i on_configuration_changed).
function M.init()
  storage.couplers = storage.couplers or {}
  storage.networks = storage.networks or {}
  storage.queue = storage.queue or {}
  storage.cursor = storage.cursor or 1
  storage.check_list = storage.check_list or {}
  storage.check_cursor = storage.check_cursor or 1
  storage.dirty = true
end

--- Vytvoří skrytý kombinátor na pozici spojky a propojí ho s ní drátem (původ script = hráč ho nevidí).
--- @param entity LuaEntity spojka
--- @return LuaEntity
local function create_signals(entity)
  local signals = entity.surface.create_entity({ name = M.SIGNALS, position = entity.position, force = entity.force })
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    entity.get_wire_connector(id, true).connect_to(signals.get_wire_connector(id, true), false, defines.wire_origin.script)
  end
  return signals
end

--- Zaeviduje novou spojku.
--- @param entity LuaEntity
function M.add(entity)
  storage.couplers[entity.unit_number] = { entity = entity, signals = create_signals(entity), sides = { {}, {} } }
  storage.dirty = true
end

--- Vyřadí spojku z evidence a zruší její kombinátor.
--- @param unit integer unit_number spojky
function M.remove(unit)
  local coupler = storage.couplers[unit]
  if not coupler then return end
  if coupler.signals and coupler.signals.valid then coupler.signals.destroy() end
  storage.couplers[unit] = nil
  storage.dirty = true
end

--- Úklid po změně modů / starém savu: neplatné spojky pryč, chybějící kombinátory znovu.
function M.revalidate()
  for unit, coupler in pairs(storage.couplers) do
    if not coupler.entity.valid then
      M.remove(unit)
    elseif not (coupler.signals and coupler.signals.valid) then
      coupler.signals = create_signals(coupler.entity)
    end
  end
  storage.dirty = true
end

return M
```

- [ ] **Step 3: `fluid-bus/scripts/topology.lua`**

```lua
--- Topologie busu ve hře: segmenty na stranách spojek, zástupné BUS trubky a přestavba sítí.
--- Kapalina se čte a zapisuje přes sousední BUS trubku (fluidbox stroje do potrubí neproudí – spec 8.1).
local network = require("scripts.network")

local M = {}

--- Přečte obě strany spojky (segment a sousední BUS trubku) a napájení.
--- @param coupler table záznam ze storage.couplers
--- @return boolean true, pokud se něco změnilo
function M.refresh(coupler)
  local entity = coupler.entity
  local fluidbox = entity.fluidbox
  local changed = false
  for i = 1, 2 do
    local side = coupler.sides[i]
    local connections = fluidbox.get_connections(i)
    local rep = connections[1] and connections[1].owner or nil
    local segment = rep and fluidbox.get_fluid_segment_id(i) or nil
    if side.seg ~= segment or side.rep ~= rep then changed = true end
    side.seg, side.rep = segment, rep
  end
  local powered = entity.energy > 0
  if coupler.powered ~= powered then changed = true end
  coupler.powered = powered
  return changed
end

--- Zapíše naměřené množství a kapacitu segmentu a průběžně upraví součty sítě.
--- @param net table síť ze storage.networks
--- @param segment integer
--- @param amount number
--- @param capacity number
function M.record(net, segment, amount, capacity)
  net.total_amount = net.total_amount + amount - (net.amounts[segment] or 0)
  net.total_capacity = net.total_capacity + capacity - (net.capacities[segment] or 0)
  net.amounts[segment], net.capacities[segment] = amount, capacity
end

--- Přečte segment přes zástupnou trubku: kapalina, množství, kapacita.
--- @return string|nil, number, number
function M.read(rep)
  local fluidbox = rep.fluidbox
  local name, amount = next(fluidbox.get_fluid_segment_contents(1) or {})
  return name, amount or 0, fluidbox.get_capacity(1)
end

--- Vrátí zásobníky starých sítí do jejich segmentů (před přestavbou se sítě zahodí).
local function flush_buffers()
  for _, net in pairs(storage.networks) do
    local left = net.buffer.amount
    if left > 0 and net.fluid then
      for _, segment in ipairs(net.segments) do
        local rep = net.reps[segment]
        if left <= 0 then break end
        if rep and rep.valid then
          left = left - rep.insert_fluid({ name = net.fluid, amount = left, temperature = net.buffer.temperature })
        end
      end
      if left > 1e-6 then log("fluid-bus: při přestavbě sítě ztraceno " .. left .. " " .. net.fluid) end
    end
  end
end

--- Přestaví sítě ze současného stavu spojek. Jednou přečte všechny segmenty (výchozí součty),
--- pak už se jen průběžně aktualizují v plánovači.
function M.rebuild()
  flush_buffers()
  local edges, check = {}, {}
  for unit, coupler in pairs(storage.couplers) do
    if coupler.entity.valid then
      M.refresh(coupler)
      check[#check + 1] = unit
      edges[#edges + 1] = { id = unit, a = coupler.sides[1].seg, b = coupler.sides[2].seg, active = coupler.powered }
    end
  end
  table.sort(check)
  storage.networks, storage.queue = {}, {}
  for index, built in ipairs(network.build(edges)) do
    local net = { segments = built.segments, couplers = built.couplers, reps = {}, amounts = {}, capacities = {},
      total_amount = 0, total_capacity = 0, buffer = { amount = 0 }, conflict = false, fraction = 0 }
    for _, unit in ipairs(built.couplers) do
      for _, side in ipairs(storage.couplers[unit].sides) do
        if side.seg and not net.reps[side.seg] then net.reps[side.seg] = side.rep end
      end
    end
    for _, segment in ipairs(net.segments) do
      local name, amount, capacity = M.read(net.reps[segment])
      M.record(net, segment, amount, capacity)
      if name and net.fluid and name ~= net.fluid then net.conflict = true end
      net.fluid = net.fluid or name
      storage.queue[#storage.queue + 1] = { net = index, seg = segment }
    end
    storage.networks[index] = net
  end
  storage.check_list, storage.check_cursor, storage.cursor = check, 1, 1
  storage.dirty = false
end

--- Síť, ve které je spojka (nebo nil).
--- @param unit integer
--- @return table|nil, integer|nil
function M.network_of(unit)
  for index, net in pairs(storage.networks) do
    for _, member in ipairs(net.couplers) do
      if member == unit then return net, index end
    end
  end
end

return M
```

- [ ] **Step 4: `fluid-bus/scripts/remote.lua`**

```lua
--- Remote rozhraní „fb“ pro testy a jiné mody.
local topology = require("scripts.topology")

local M = {}

--- Zaregistruje rozhraní (volá control.lua při načtení).
function M.register()
  remote.add_interface("fb", {
    --- Souhrn sítě, ve které je spojka; nil = spojka v žádné síti není.
    network_of = function(unit)
      local net = topology.network_of(unit)
      if not net then return nil end
      return { fill = net.fraction, amount = net.total_amount + net.buffer.amount, fluid = net.fluid,
        segments = #net.segments, buffer = net.buffer.amount, conflict = net.conflict }
    end,
    --- Vynutí přestavbu sítí v příštím ticku.
    rebuild = function() storage.dirty = true end,
  })
end

return M
```

- [ ] **Step 5: `fluid-bus/control.lua` (bez vyrovnávání – to přidá Task 5)**

```lua
-- Runtime modu: jen napojuje události na moduly ze scripts/.
local registry = require("scripts.registry")
local topology = require("scripts.topology")
local remote_api = require("scripts.remote")

local FILTER = { { filter = "name", name = registry.COUPLER } }

--- Postavení spojky libovolnou cestou (hráč, robot, platforma, skript, klonování).
local function on_built(event)
  local entity = event.entity or event.destination
  if entity and entity.valid and entity.name == registry.COUPLER then registry.add(entity) end
end

--- Odstranění spojky libovolnou cestou.
local function on_removed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == registry.COUPLER then registry.remove(entity.unit_number) end
end

--- Rozložená kontrola topologie: za interval projde všechny spojky; změna → přestavba sítí.
local function check_topology()
  local list = storage.check_list
  if #list == 0 then return end
  local interval = prototypes.mod_data["fb-data"].data.interval
  for _ = 1, math.ceil(#list / interval) do
    local coupler = storage.couplers[list[storage.check_cursor]]
    if not (coupler and coupler.entity.valid) or topology.refresh(coupler) then storage.dirty = true end
    storage.check_cursor = storage.check_cursor % #list + 1
  end
end

--- Každý tick: přestavba sítí, je-li potřeba, a rozložená kontrola topologie.
local function on_tick()
  if storage.dirty then topology.rebuild() end
  check_topology()
end

script.on_init(registry.init)
script.on_configuration_changed(function()
  registry.init()
  registry.revalidate()
end)
for _, name in ipairs({ "on_built_entity", "on_robot_built_entity", "on_space_platform_built_entity",
  "script_raised_built", "script_raised_revive", "on_entity_cloned" }) do
  script.on_event(defines.events[name], on_built, FILTER)
end
for _, name in ipairs({ "on_player_mined_entity", "on_robot_mined_entity", "on_space_platform_mined_entity",
  "on_entity_died", "script_raised_destroy" }) do
  script.on_event(defines.events[name], on_removed, FILTER)
end
script.on_event(defines.events.on_player_rotated_entity, function(event)
  if event.entity.name == registry.COUPLER then storage.dirty = true end
end)
script.on_event(defines.events.on_tick, on_tick)
remote_api.register()
```

Pozn.: integrační testy staví spojky přes `create_entity` bez `raise_built` – v `H.place` proto přidat
`raise_built = true` do `spec` (jinak by je mod neevidoval). Upravit `tests/fluid-bus-tests/helpers.lua`
`H.place`: `local spec = { …, force = "player", raise_built = true }`.

- [ ] **Step 6: Spustit**

Run: `bash tools/run-tests.sh vanilla` → Expected: `FB-TEST DONE pass=17 fail=0 skip=1`
Run: `bash tools/run-tests.sh space-age` → Expected: `pass=18 fail=0 skip=0`

- [ ] **Step 7: Commit (na pokyn)** – `feat: evidence spojek, topologie a sítě busu ve hře`

---

### Task 5: Vyrovnávání (balancer)

**Files:**
- Create: `fluid-bus/scripts/balancer.lua`; Modify: `fluid-bus/control.lua` (on_tick)
- Create: `tests/fluid-bus-tests/cases/balance.lua`; Modify: `tests/fluid-bus-tests/control.lua`

**Interfaces:**
- Consumes: `topology.read/record/rebuild`, `balance_math.*`, `storage.queue/cursor/networks`.
- Produces: `balancer.step()` – zpracuje `ceil(#queue / interval)` segmentů; po dokončení kola
  zavolá `on_cycle(net_index)` callback, který nastaví Task 6 (`balancer.on_cycle = fn`).

- [ ] **Step 1: Failing testy – `tests/fluid-bus-tests/cases/balance.lua`**

```lua
--- Integrační testy vyrovnávání sítě busu (množství, teplota, konflikt, proud, odstranění).
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

--- Obsah segmentu, ve kterém je trubka: jméno a množství.
local function contents(pipe)
  local name, amount = next(pipe.fluidbox.get_fluid_segment_contents(1) or {})
  return name, amount or 0
end

--- Scéna: segment A (6 trubek) – spojka – segment B (6 trubek), volitelně napájená.
local function two_segments(ctx, powered)
  ctx.a = column(ctx, 0, -6, -1)[1]
  ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
  ctx.b = column(ctx, 0, 1, 6)[1]
  if powered then H.power(ctx, 0, 0) end
end

return {
  {
    name = "dva segmenty se vyrovnají a množství se zachová",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local _, a = contents(ctx.a)
      local _, b = contents(ctx.b)
      local info = remote.call("fb", "network_of", ctx.c.unit_number)
      H.truthy(math.abs(a - b) < 30, "vyrovnáno (" .. a .. " / " .. b .. ")")
      H.truthy(math.abs(a + b + info.buffer - 600) < 0.01, "zachováno (" .. (a + b + info.buffer) .. ")")
    end } },
  },
  {
    name = "řetěz čtyř segmentů se zdrojem na konci se vyrovná",
    setup = function(ctx)
      ctx.pipes = {}
      for i = 0, 3 do
        ctx.pipes[i + 1] = column(ctx, 0, i * 6 - 12, i * 6 - 8)[1]
        if i < 3 then
          local c = H.place(ctx, "fb-bus-coupler", 0, i * 6 - 7)
          H.power(ctx, 0, i * 6 - 7)
          ctx.c = c
        end
      end
      ctx.pipes[1].insert_fluid({ name = "water", amount = 1000 })
    end,
    steps = { { ticks = 900, run = function(ctx)
      for i, pipe in ipairs(ctx.pipes) do
        local _, amount = contents(pipe)
        H.truthy(math.abs(amount - 250) < 40, "segment " .. i .. ": " .. amount)
      end
    end } },
  },
  {
    name = "pára: teplota se přenese a množství se zachová",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "steam", amount = 600, temperature = 500 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local _, b = contents(ctx.b)
      H.truthy(b > 200, "pára přetekla (" .. b .. ")")
      H.truthy(math.abs(ctx.b.fluidbox[1].temperature - 500) < 1, "teplota 500 °C")
    end } },
  },
  {
    name = "různé kapaliny: nic se nepřelije",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 300 })
      ctx.b.insert_fluid({ name = "crude-oil", amount = 300 })
    end,
    steps = { { ticks = 300, run = function(ctx)
      local _, a = contents(ctx.a)
      local _, b = contents(ctx.b)
      H.eq(a, 300, "voda beze změny")
      H.eq(b, 300, "ropa beze změny")
      H.truthy(remote.call("fb", "network_of", ctx.c.unit_number).conflict, "konflikt")
    end } },
  },
  {
    name = "bez proudu se nepřelévá",
    setup = function(ctx)
      two_segments(ctx, false)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 300, run = function(ctx)
      local _, b = contents(ctx.b)
      H.eq(b, 0, "nic nepřeteklo")
      H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "bez sítě")
    end } },
  },
  {
    name = "odstranění spojky zachová množství",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = {
      { ticks = 100, run = function(ctx) ctx.c.destroy({ raise_destroy = true }) end },
      { ticks = 5, run = function(ctx)
        local _, a = contents(ctx.a)
        local _, b = contents(ctx.b)
        H.truthy(math.abs(a + b - 600) < 0.01, "zachováno (" .. (a + b) .. ")")
      end },
    },
  },
}
```

Registrovat v `control.lua` testů. Run: `bash tools/run-tests.sh vanilla` → Expected: FAIL u
„vyrovnají“, „řetěz“, „pára“ (nic se nepřelévá); ostatní mohou projít.

- [ ] **Step 2: `fluid-bus/scripts/balancer.lua`**

```lua
--- Rozložené vyrovnávání sítí busu: každý tick zpracuje díl fronty segmentů tak, aby celá fronta
--- prošla jednou za interval. Přebytek segmentu jde do zásobníku sítě, nedostatek se z něj doplní.
local m = require("scripts.balance_math")
local topology = require("scripts.topology")

local M = {}

--- Volá se po dokončení kola sítě (index sítě) – nastaví signals.lua.
--- @type fun(net_index: integer)|nil
M.on_cycle = nil

--- Zpracuje jeden segment: přečte stav, porovná s cílem sítě a přelije přes zásobník.
--- @param entry table { net, seg }
local function process(entry)
  local net = storage.networks[entry.net]
  if not net or net.conflict then return end
  local rep = net.reps[entry.seg]
  if not (rep and rep.valid) then
    storage.dirty = true
    return
  end
  local name, amount, capacity = topology.read(rep)
  topology.record(net, entry.seg, amount, capacity)
  if name and net.fluid and name ~= net.fluid then
    net.conflict = true
    return
  end
  net.fluid = net.fluid or name
  if not net.fluid then return end
  net.fraction = m.target_fraction(net.total_amount, net.buffer.amount, net.total_capacity)
  local delta = m.plan(amount, capacity, net.fraction, net.buffer.amount)
  if delta < 0 then
    local fluid = rep.fluidbox[1]
    local removed = rep.remove_fluid({ name = net.fluid, amount = -delta })
    net.buffer = m.mix(net.buffer, removed, fluid and fluid.temperature)
    topology.record(net, entry.seg, amount - removed, capacity)
  elseif delta > 0 then
    local inserted = rep.insert_fluid({ name = net.fluid, amount = delta, temperature = net.buffer.temperature })
    net.buffer = m.take(net.buffer, inserted)
    topology.record(net, entry.seg, amount + inserted, capacity)
  end
end

--- Zpracuje díl fronty pro tento tick; na konci kola sítě zavolá M.on_cycle.
function M.step()
  local queue = storage.queue
  if #queue == 0 then return end
  local interval = prototypes.mod_data["fb-data"].data.interval
  for _ = 1, math.ceil(#queue / interval) do
    local entry = queue[storage.cursor]
    process(entry)
    local nxt = storage.cursor % #queue + 1
    if (queue[nxt] and queue[nxt].net ~= entry.net or nxt == 1) and M.on_cycle then M.on_cycle(entry.net) end
    storage.cursor = nxt
    if storage.dirty then return end
  end
end

return M
```

V `control.lua` přidat `local balancer = require("scripts.balancer")` a v `on_tick` za
`check_topology()` řádek `balancer.step()`.

- [ ] **Step 3: Spustit**

Run: `bash tools/run-tests.sh vanilla` → Expected: `FB-TEST DONE pass=23 fail=0 skip=1`
Run: `bash tools/run-tests.sh space-age` → Expected: `pass=24 fail=0 skip=0`
Při selhání vyrovnání: vypsat `remote.call("fb","network_of",…)` do logu testu a hledat příčinu
(superpowers:systematic-debugging), ne zvyšovat toleranci testu.

- [ ] **Step 4: Commit (na pokyn)** – `feat: rozložené vyrovnávání sítě busu přes zásobník`

---

### Task 6: Signály a stav spojky

**Files:**
- Create: `fluid-bus/scripts/signals.lua`; Modify: `fluid-bus/control.lua`
- Create: `tests/fluid-bus-tests/cases/signals.lua`; Modify: `tests/fluid-bus-tests/control.lua`

**Interfaces:**
- Consumes: `balancer.on_cycle`, `storage.networks`, `storage.couplers`.
- Produces: `signals.update_network(index)`, `signals.update_unattached()`; signál `fb-fill` = round(% naplnění),
  signál kapaliny = celkové množství (+ zásobník); `custom_status` s klíči `fb-status.*`.

- [ ] **Step 1: Failing test – `tests/fluid-bus-tests/cases/signals.lua`**

```lua
--- Integrační testy signálů a stavu spojky.
local H = require("helpers")

--- Svislá řada BUS trubek.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

return {
  {
    name = "spojka vysílá naplnění a množství, stav ok",
    setup = function(ctx)
      local top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 6)
      H.power(ctx, 0, 0)
      top.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local red = defines.wire_connector_id.circuit_red
      local fill = ctx.c.get_signal({ type = "virtual", name = "fb-fill" }, red)
      local water = ctx.c.get_signal({ type = "fluid", name = "water" }, red)
      H.truthy(fill >= 45 and fill <= 55, "naplnění ~50 % (" .. fill .. ")")
      H.truthy(water >= 590 and water <= 600, "množství (" .. water .. ")")
      H.eq(ctx.c.custom_status.label[1], "fb-status.ok", "stav")
    end } },
  },
  {
    name = "nenapájená spojka hlásí Bez proudu",
    setup = function(ctx)
      column(ctx, 0, -3, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 3)
    end,
    steps = { { ticks = 200, run = function(ctx)
      H.eq(ctx.c.custom_status.label[1], "fb-status.no-power", "stav")
    end } },
  },
}
```

Run → Expected: FAIL (`custom_status` nil / signál 0).

- [ ] **Step 2: `fluid-bus/scripts/signals.lua`**

```lua
--- Signály a stav spojek: naplnění sítě (%) a množství kapaliny do obvodové sítě, custom_status v GUI.
local M = {}

local GREEN, YELLOW, RED = defines.entity_status_diode.green, defines.entity_status_diode.yellow,
  defines.entity_status_diode.red
--- Strop hodnoty signálu (int32).
local MAX_SIGNAL = 2147483647

--- Zapíše signály do skrytého kombinátoru spojky (nil hodnoty = signál smazat).
--- @param coupler table záznam ze storage.couplers
--- @param fill integer|nil
--- @param fluid string|nil
--- @param amount number|nil
local function write(coupler, fill, fluid, amount)
  if not (coupler.signals and coupler.signals.valid) then return end
  local behavior = coupler.signals.get_or_create_control_behavior()
  if behavior.sections_count == 0 then behavior.add_section() end
  local section = behavior.get_section(1)
  if fill then
    section.set_slot(1, { value = { type = "virtual", name = "fb-fill", quality = "normal" }, min = fill })
  else
    section.clear_slot(1)
  end
  if fluid then
    section.set_slot(2, { value = { type = "fluid", name = fluid, quality = "normal" },
      min = math.min(MAX_SIGNAL, math.floor(amount)) })
  else
    section.clear_slot(2)
  end
end

--- Aktualizuje signály a stav všech spojek sítě (po kole vyrovnávání).
--- @param index integer index sítě ve storage.networks
function M.update_network(index)
  local net = storage.networks[index]
  if not net then return end
  local fill = math.floor(net.fraction * 100 + 0.5)
  for _, unit in ipairs(net.couplers) do
    local coupler = storage.couplers[unit]
    if coupler and coupler.entity.valid then
      if net.conflict then
        write(coupler, nil, nil, nil)
        coupler.entity.custom_status = { diode = RED, label = { "fb-status.conflict" } }
      else
        write(coupler, fill, net.fluid, net.total_amount + net.buffer.amount)
        coupler.entity.custom_status = { diode = GREEN, label = { "fb-status.ok", #net.segments, fill } }
      end
    end
  end
end

--- Spojky mimo síť: stav Bez proudu / Nepřipojeno, signály smazat. Volá se po přestavbě sítí.
function M.update_unattached()
  local member = {}
  for _, net in pairs(storage.networks) do
    for _, unit in ipairs(net.couplers) do member[unit] = true end
  end
  for unit, coupler in pairs(storage.couplers) do
    if not member[unit] and coupler.entity.valid then
      write(coupler, nil, nil, nil)
      if not coupler.powered then
        coupler.entity.custom_status = { diode = RED, label = { "fb-status.no-power" } }
      else
        coupler.entity.custom_status = { diode = YELLOW, label = { "fb-status.not-connected" } }
      end
    end
  end
end

return M
```

V `control.lua`: `local signals = require("scripts.signals")`, po `require` balanceru
`balancer.on_cycle = signals.update_network`, a v `on_tick`:
`if storage.dirty then topology.rebuild(); signals.update_unattached() end`.

- [ ] **Step 3: Spustit**

Run: `bash tools/run-tests.sh vanilla` → Expected: `FB-TEST DONE pass=25 fail=0 skip=1`
Run: `bash tools/run-tests.sh space-age` → Expected: `pass=26 fail=0 skip=0`
Pokud `set_slot` odmítne `quality` u fluidu, odebrat `quality` z hodnoty fluidu a zapsat do ledgeru.

- [ ] **Step 4: Commit (na pokyn)** – `feat: signály naplnění busu a stav spojky`

---

### Task 7: Odolnost – rotace, revalidace, kompatibilita

**Files:**
- Create: `tests/fluid-bus-tests/cases/lifecycle.lua`; Modify: `tests/fluid-bus-tests/control.lua`
- Modify: `tests/fluid-bus-tests/cases/compat.lua` (spojka vznikla, recept dostupný)

**Interfaces:**
- Consumes: `registry.revalidate`, remote `fb`.

- [ ] **Step 1: Testy – `tests/fluid-bus-tests/cases/lifecycle.lua`**

```lua
--- Integrační testy životního cyklu spojky: rotace, ztráta kombinátoru, revalidace.
local H = require("helpers")

return {
  {
    name = "rotace spojky ji odpojí (strany míří jinam) a přestaví sítě",
    setup = function(ctx)
      H.place(ctx, "fb-bus-pipe", 0, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.place(ctx, "fb-bus-pipe", 0, 1)
      H.power(ctx, 0, 0)
    end,
    steps = {
      { ticks = 150, run = function(ctx)
        H.truthy(remote.call("fb", "network_of", ctx.c.unit_number), "síť před rotací")
        ctx.c.rotate()
        remote.call("fb", "rebuild")
      end },
      { ticks = 10, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "po rotaci bez sítě")
      end },
    },
  },
  {
    name = "revalidace po ztrátě kombinátoru vytvoří nový",
    setup = function(ctx)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
    end,
    steps = { { ticks = 5, run = function(ctx)
      local hidden = ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position })
      H.eq(#hidden, 1, "jeden kombinátor")
      hidden[1].destroy()
      remote.call("fb", "revalidate")
      H.eq(#ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position }), 1,
        "obnoven")
    end } },
  },
}
```

Do remote rozhraní (`scripts/remote.lua`) přidat `revalidate = function() registry.revalidate() end`
(+ `local registry = require("scripts.registry")`) – slouží testům a jiným modům.

Do `compat.lua` přidat:

```lua
  check("kompatibilita: spojka vznikla a je dostupná", function()
    local name = prototypes.mod_data["fb-data"].data.coupler
    H.truthy(prototypes.entity[name], "entita spojky")
    H.truthy(prototypes.recipe[name].enabled or #H.unlocking_techs(name) > 0, "recept spojky dostupný")
  end),
```

- [ ] **Step 2: Spustit vše včetně kompatibility**

Run: `bash tools/run-unit.sh` → `UNIT pass=51 fail=0`
Run: vanilla → `pass=28 fail=0 skip=1`; space-age → `pass=29 fail=0 skip=0`;
`mods pymodpack`, `mods boblogistics`, `mods pipe-tiers` → `pass=6 fail=0` (+ log
`grep "fluid-bus: fb-bus-coupler" .test-run/mods/create.log` – suroviny spojky v Py).

- [ ] **Step 3: Commit (na pokyn)** – `test: životní cyklus spojky a kompatibilita`

---

### Task 8: Výkonový test

**Files:**
- Create: `tests/perf/fb-perf/info.json`, `tests/perf/fb-perf/control.lua`, `tools/run-perf.sh`
- Modify: `.vscode/tasks.json` (úloha „Výkonový test“), `docs/development.md` (výsledky)

**Interfaces:**
- Produces: `bash tools/run-perf.sh <počet_spojek>` → řádky `FB-PERF couplers <ms/tick>` a
  `FB-PERF pumps <ms/tick>`.

- [ ] **Step 1: Perf mod – `tests/perf/fb-perf/info.json`**

```json
{ "name": "fb-perf", "version": "0.1.0", "title": "Fluid Bus – perf", "author": "Ypsilonx",
  "factorio_version": "2.0", "dependencies": ["base", "? fluid-bus"] }
```

- [ ] **Step 2: `tests/perf/fb-perf/control.lua`**

```lua
-- Výkonový scénář: dlouhý bus (N úseků po 29 trubkách) se spojkami (s modem fluid-bus) nebo s pumpami
-- (bez něj), napájení velkými sloupy, zdroj vody na začátku a odběr na konci (infinity pipe).
-- Počet úseků zapisuje tools/run-perf.sh do souboru count.lua vedle tohoto skriptu.

script.on_init(function()
  local count = require("count")
  local surface = game.surfaces[1]
  surface.always_day = true
  local bus = script.active_mods["fluid-bus"] ~= nil
  local pipe = bus and "fb-bus-pipe" or "pipe"
  local x = 0
  local previous_pole
  local function pole(px)
    local p = surface.create_entity({ name = "big-electric-pole", position = { px, -2 }, force = "player" })
    if previous_pole then
      p.get_wire_connector(defines.wire_connector_id.pole_copper, true)
        .connect_to(previous_pole.get_wire_connector(defines.wire_connector_id.pole_copper, true), false)
    end
    previous_pole = p
  end
  local source = surface.create_entity({ name = "infinity-pipe", position = { x + 0.5, 0.5 }, force = "player" })
  source.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "at-least" })
  local eei = surface.create_entity({ name = "electric-energy-interface", position = { 1, -4 }, force = "player" })
  eei.electric_buffer_size = 1e12
  eei.power_production = 1e9
  pole(1)
  for _ = 1, count do
    for _ = 1, bus and 29 or 28 do
      x = x + 1
      surface.create_entity({ name = pipe, position = { x + 0.5, 0.5 }, force = "player" })
    end
    x = x + 1
    if bus then
      surface.create_entity({ name = "fb-bus-coupler", position = { x + 0.5, 0.5 }, force = "player",
        direction = defines.direction.east, raise_built = true })
    else
      surface.create_entity({ name = "pump", position = { x + 1, 0.5 }, force = "player",
        direction = defines.direction.east })
      x = x + 1
    end
    pole(x)
  end
  local sink = surface.create_entity({ name = "infinity-pipe", position = { x + 1.5, 0.5 }, force = "player" })
  sink.set_infinity_pipe_filter({ name = "water", percentage = 0, mode = "at-most" })
  log("FB-PERF built " .. count .. " " .. (bus and "couplers" or "pumps") .. " length " .. x)
end)
```

- [ ] **Step 3: `tools/run-perf.sh`**

```bash
#!/usr/bin/env bash
# Výkonový test: dlouhý bus se spojkami fluid-bus proti stejnému busu s vanilla pumpami.
# Použití: tools/run-perf.sh [počet_úseků=1000] [ticků=1800]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FACTORIO="${FACTORIO_EXE:-C:/STEAM/steamapps/common/Factorio/bin/x64/factorio.exe}"
COUNT="${1:-1000}"
TICKS="${2:-1800}"

run() {
  local variant="$1" with_mod="$2"
  local RUN="$ROOT/.test-run/perf-$variant"
  local RUN_W; RUN_W="$(cygpath -m "$RUN")"
  rm -rf "$RUN"; mkdir -p "$RUN/mods" "$RUN/write-data"
  cp -r "$ROOT/tests/perf/fb-perf" "$RUN/mods/fb-perf"
  echo "return $COUNT" > "$RUN/mods/fb-perf/count.lua"
  [ "$with_mod" = true ] && cp -r "$ROOT/fluid-bus" "$RUN/mods/fluid-bus"
  cat > "$RUN/mods/mod-list.json" <<JSON
{"mods":[{"name":"base","enabled":true},{"name":"elevated-rails","enabled":false},{"name":"quality","enabled":false},
{"name":"space-age","enabled":false},{"name":"fluid-bus","enabled":$with_mod},{"name":"fb-perf","enabled":true}]}
JSON
  printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s/write-data\n' "$RUN_W" > "$RUN/config.ini"
  local ARGS=(--config "$RUN_W/config.ini" --mod-directory "$RUN_W/mods")
  "$FACTORIO" "${ARGS[@]}" --create "$RUN_W/perf.zip" > "$RUN/create.log" 2>&1 || true
  [ -f "$RUN/perf.zip" ] || { grep -A10 -E "Error" "$RUN/create.log" | head -30; exit 1; }
  "$FACTORIO" "${ARGS[@]}" --benchmark "$RUN_W/perf.zip" --benchmark-ticks "$TICKS" --disable-audio > "$RUN/bench.log" 2>&1 || true
  grep "FB-PERF built" "$RUN/bench.log" | sed 's/.*FB-PERF/FB-PERF/' || true
  local line; line="$(grep -E "Performed [0-9]+ updates in" "$RUN/bench.log" | tail -1)"
  echo "FB-PERF $variant $(echo "$line" | sed -E 's/.*Performed ([0-9]+) updates in ([0-9.]+) ms.*/\2 \1/' | awk '{printf "%.3f ms\/tick", $1\/$2}')"
}

run couplers true
run pumps false
```

- [ ] **Step 4: Spustit a zapsat výsledky**

Run: `bash tools/run-perf.sh 1000`
Expected: dva řádky `FB-PERF couplers X ms/tick`, `FB-PERF pumps Y ms/tick`. Cíl ze specifikace:
spojky ≤ 1 ms/tick nad baseline pump. Výsledek (verze hry, počet, délka busu, obě čísla) zapsat do
`docs/development.md`, sekce „Výkon“. Když je cíl překročen, zastavit a probrat s uživatelem
(interval, tolerance).

- [ ] **Step 5: Commit (na pokyn)** – `test: výkonový scénář dlouhého busu`

---

### Task 9: Dokumentace pro hráče a portál

**Files:**
- Create: `docs/user-guide.md` (CZ), `docs/mod-portal.md` (EN)
- Modify: `fluid-bus/changelog.txt`, `README.md`, `docs/development.md` („Kde ladit hodnoty“, ruční kontrola)

- [ ] **Step 1: `docs/user-guide.md`** – podle spec sekce 10, body 1–5: jak poznat BUS trubku (černé
  nastříkané „B“), postup krok za krokem (BUS trubky / upgrade planner, spojky místo pump, elektřina,
  vstupy a výstupy přes běžnou trubku a pumpu u busu), ASCII schéma zapojení a „dřív → teď“, časté
  chyby (spojka na běžné trubce, bez proudu, dvě kapaliny, pára různých teplot, dlouhé odbočky),
  obvodová síť (příklady „spal přebytek nad 90 %“ a „zapni záložní zdroj pod 30 %“ se signálem
  „Naplnění busu“), nastavení modu (`fb-coupler-power`, `fb-balance-interval`).
- [ ] **Step 2: `docs/mod-portal.md`** – anglicky totéž stručněji + sekce Compatibility (vanilla, Space Age,
  Pyanodon, Bob's, Pipe Tiers – z tabulky v development.md) a Performance (čísla z Task 8).
- [ ] **Step 3: `changelog.txt`** – do sekce 0.1.0 doplnit `Features` (bus coupler, network balancing,
  fill signal, coupler status) a `Compatibility` (tested mody). Zachovat striktní formát (99 pomlček,
  2/4 mezery).
- [ ] **Step 4: `docs/development.md`** – do „Kde ladit hodnoty“: `fb-coupler-power`, `fb-balance-interval`
  (startup nastavení), `balance_math.TOLERANCE`, `coupler.INGREDIENTS`, `coupler.FLUID_VOLUME`,
  `coupler.TINT`; do „Ruční kontrola“: spojka se nenapojí na běžnou trubku, stav v GUI, signál
  v obvodové síti, rotace, blueprint spojky.
- [ ] **Step 5: Ověřit** – `bash tools/run-unit.sh` (locale klíče) a vanilla integrační test.
- [ ] **Step 6: Commit (na pokyn)** – `docs: návod pro hráče, portál, changelog`
