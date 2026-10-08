-- Generování BUS trubek až po načtení všech modů, aby se zahrnuly i trubky z jiných modů.
local bus_pipes = require("prototypes.bus_pipes")
local overlay = require("prototypes.bus_overlay")
local research = require("prototypes.research")
local coupler = require("prototypes.coupler")
local av = require("prototypes.availability")

local pairs_, skipped = bus_pipes.collect(data.raw)
for _, entry in ipairs(skipped) do
  log("fluid-bus: skipped " .. entry.name .. " (" .. entry.reason .. ")")
end

local marking = bus_pipes.marking_item(data.raw)
local names = {}
--- Kategorie napojení všech BUS variant (pro spojku a pumpy), v pořadí prvního výskytu.
local categories, seen_category = {}, {}

--- Vytvoří BUS entitu, předmět a recept k jedné původní entitě; vrátí recept.
--- @param type_name string "pipe" | "pipe-to-ground"
--- @param source string jméno původní entity
--- @param source_item string původní předmět
--- @param count integer kusů na recept
--- @return table recept
local function create(type_name, source, source_item, count)
  local entity = bus_pipes.entity(data.raw[type_name][source], table.deepcopy, function(new)
    local missing = overlay.decorate(new, table.deepcopy)
    if #missing > 0 then log("fluid-bus: no marking on " .. new.name .. ": " .. table.concat(missing, ", ")) end
  end)
  local item = bus_pipes.item(data.raw, source_item, entity, overlay.icons(data.raw.item[source_item], table.deepcopy))
  local recipe = bus_pipes.recipe(source_item, count, marking, item.name)
  data:extend({ entity, item, recipe })
  -- Recyklaci generuje quality v data-updates, tedy dřív než my – BUS předměty ji musí dostat zde.
  if mods["quality"] then
    require("__quality__.prototypes.recycling").generate_recycling_recipe(recipe)
  end
  names[#names + 1] = entity.name
  for _, connection in ipairs(entity.fluid_box.pipe_connections) do
    if connection.connection_type ~= "underground" then
      for _, category in ipairs(connection.connection_category) do
        if not seen_category[category] then
          categories[#categories + 1], seen_category[category] = category, true
        end
      end
    end
  end
  return recipe
end

-- Základní výzkum: prerekvizity = výzkumy všech surovin spojky (pumpa první = spouštěč) a značení.
local base_items = coupler.ingredient_names(data.raw)
if marking then base_items[#base_items + 1] = marking end
local base_spec = research.technology(data.raw, research.techs_for_items(data.raw, base_items),
  research.trigger_item(data.raw, base_items))
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
    local spec = research.technology(data.raw, techs, research.trigger_item(data.raw, { pair.pipe_item }))
    target = {
      type = "technology",
      name = research.BASE_TECH .. "-" .. pair.pipe,
      localised_name = { "technology-name.fb-fluid-bus-pipe",
        data.raw.pipe[pair.pipe].localised_name or { "entity-name." .. pair.pipe } },
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
    log("fluid-bus: " .. recipe.name .. " ← " .. serpent.line(recipe.ingredients)
      .. " | technology: " .. (target and target.name or "from start")
      .. (target and (" | prerequisites: " .. table.concat(target.prerequisites or {}, ", ")) or ""))
  end
end

-- BUS trubky se napojí jen na sebe, spojku a pumpu: spojka dostane jen kategorie busu, pumpy (i z jiných
-- modů) je dostanou navíc k původním – pumpa je jediný přechod mezi busem a běžným potrubím.
for _, fluid_box in ipairs(data.raw["assembling-machine"][coupler.NAME].fluid_boxes) do
  for _, connection in ipairs(fluid_box.pipe_connections) do connection.connection_category = categories end
end
for _, name in ipairs(av.sorted_keys(data.raw.pump)) do
  for _, connection in ipairs(data.raw.pump[name].fluid_box.pipe_connections) do
    if connection.connection_type ~= "underground" then bus_pipes.add_categories(connection, categories) end
  end
end
log("fluid-bus: bus connection categories: " .. table.concat(categories, ", "))

data:extend({ { type = "mod-data", name = "fb-data", data = {
  bus_pipes = names,
  coupler = coupler.NAME,
  coupler_signals = coupler.SIGNALS,
  interval_signal = coupler.INTERVAL_SIGNAL,
} } })
