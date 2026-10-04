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
      -- Všechny recepty podzemní, ne jen ten nejdřív dostupný: Py ji umí i odlít z roztaveného kovu.
      for _, recipe in ipairs(av.recipes_for(raw, info.item)) do
        for _, ingredient in ipairs(raw.recipe[recipe].ingredients or {}) do
          entry = entry or by_item[ingredient.name]
        end
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
    -- Podzemní spoj smí mít jen jednu kategorii (engine to odmítne) a spojka se na něj nenapojuje.
    if connection.connection_type ~= "underground" then
      connection.connection_category = M.with_bus_category(connection.connection_category)
    end
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

return M
