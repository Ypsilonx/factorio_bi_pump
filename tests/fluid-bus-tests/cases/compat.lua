--- Obecné kontroly BUS trubek platné s jakoukoli sadou modů (spouští je i varianta „mods“).
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

--- Kategorie konektoru jako množina (runtime může vrátit řetězec i pole).
local function category_set(value)
  local set = {}
  for _, c in ipairs(type(value) == "table" and value or { value or "default" }) do set[c] = true end
  return set
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
        local categories = category_set(connection.connection_category)
        -- Podzemní spoj má jen původní kategorii (engine víc nedovolí).
        if connection.connection_type ~= "underground" then
          H.truthy(categories["fb-bus"], name .. " konektor " .. i .. " fb-bus")
        end
        for c in pairs(category_set(source_connections[i].connection_category)) do
          H.truthy(categories[c], name .. " konektor " .. i .. " zachová " .. c)
        end
      end
    end
  end),
  check("kompatibilita: BUS varianta má stejný extent jako původní (mody upravující trubky)", function()
    for name, extent in pairs(prototypes.mod_data["fb-test-extents"].data) do
      H.eq(extent.bus, extent.source, "extent " .. name)
    end
  end),
  check("kompatibilita: spouštěč výzkumu nečeká na předmět, který sám odemyká", function()
    for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do
      for _, tech_name in ipairs(H.unlocking_techs(name)) do
        local trigger = prototypes.technology[tech_name].research_trigger
        if trigger and trigger.type == "craft-item" then
          local item = type(trigger.item) == "table" and trigger.item.name or trigger.item
          H.truthy(item ~= name, tech_name .. " čeká na " .. name)
        end
      end
    end
  end),
  check("kompatibilita: spojka vznikla a je dostupná", function()
    local name = prototypes.mod_data["fb-data"].data.coupler
    H.truthy(prototypes.entity[name], "entita spojky")
    H.truthy(prototypes.recipe[name].enabled or #H.unlocking_techs(name) > 0, "recept spojky dostupný")
    H.log_tech("fb-fluid-bus")
  end),
  check("kompatibilita: suroviny dostupné nejpozději s výzkumem", function()
    H.eq(H.unreachable_ingredients(), "", "nedostupné suroviny")
  end),
}
