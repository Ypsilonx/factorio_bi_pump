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

--- Předmět pro spouštěč výzkumu „vyrob předmět“ (když prerekvizity nemají vědu). Musí to být existující
--- předmět, který výzkum sám neodemyká – jinak by se strom zasekl (BUS předmět jde vyrobit až po výzkumu).
--- @param raw table data.raw
--- @param candidates string[] kandidáti v pořadí preference (např. pumpa, původní trubka)
--- @return string|nil
function M.trigger_item(raw, candidates)
  for _, name in ipairs(candidates) do
    if raw.item[name] then return name end
  end
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
