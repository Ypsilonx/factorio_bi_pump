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

--- Kapalina v segmentu, ve kterém je trubka (fluidbox 1).
--- @param pipe LuaEntity
--- @param fluid string|nil jen tato kapalina; jiná kapalina v segmentu vrátí nil
--- @return string|nil jméno, number|nil množství
function H.segment_fluid(pipe, fluid)
  local content = pipe.get_fluid_segment_fluid(1)
  if not content or (fluid and content.name ~= fluid) then return nil, nil end
  return content.name, content.amount
end

--- Postaví entitu na dlaždici (x, y) relativně k výřezu testu.
function H.place(ctx, name, x, y, extra)
  local spec = { name = name, position = { ctx.origin.x + x + 0.5, ctx.origin.y + y + 0.5 }, force = "player",
    raise_built = true }
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

--- Suroviny receptů spojky a BUS trubek, které nejdou vyrobit nejpozději s výzkumem, jenž recept odemyká.
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
  local data = prototypes.mod_data["fb-data"].data
  local recipes = { data.coupler, table.unpack(data.bus_pipes) }
  for _, name in ipairs(recipes) do
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

--- Napájí dlaždici (x, y) testu: malý sloup vedle ní a nekonečný zdroj energie (vrátí zdroj).
function H.power(ctx, x, y)
  H.place(ctx, "small-electric-pole", x + 1, y + 1)
  local eei = H.place(ctx, "electric-energy-interface", x + 3, y + 2)
  eei.electric_buffer_size = 1e9
  eei.power_production = 1e6
  return eei
end

--- Vyžaduje výzkum (i nepřímo) jiný výzkum?
--- @param tech string
--- @param required string
--- @return boolean
function H.requires(tech, required)
  return closure(prototypes.technology[tech])[required] == true
end

--- Zapíše do logu prerekvizity a cenu výzkumu (diagnostika napříč mody).
--- @param name string
function H.log_tech(name)
  local tech = prototypes.technology[name]
  local packs = {}
  for _, pack in ipairs(tech.research_unit_ingredients) do packs[#packs + 1] = pack.name end
  local prerequisites = {}
  for prerequisite in pairs(tech.prerequisites) do prerequisites[#prerequisites + 1] = prerequisite end
  log("fluid-bus test: " .. name .. " ← " .. table.concat(prerequisites, ", ") .. "; "
    .. tech.research_unit_count .. "× " .. table.concat(packs, "+"))
end

return H
