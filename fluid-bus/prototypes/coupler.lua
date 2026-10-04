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
--- @param production_type string "input" | "output"
--- @param direction defines.direction strana napojení
--- @return table FluidBox
local function box(production_type, direction)
  return {
    production_type = production_type,
    volume = M.FLUID_VOLUME,
    pipe_connections = { { flow_direction = "input-output", direction = direction,
      position = { 0, 0 }, connection_category = { "fb-bus" } } },
  }
end

--- Dočasná grafika: obarvená vanilla trubka ve směru spojky.
--- @param file string "vertical" | "horizontal"
--- @return table Animation
local function sprite(file)
  return { filename = "__base__/graphics/entity/pipe/pipe-straight-" .. file .. ".png",
    width = 128, height = 128, scale = 0.5, frame_count = 1, tint = M.TINT }
end

--- Prototypy spojky (kategorie, entita, skrytý kombinátor, předmět, signál). Volá se v data.lua.
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
