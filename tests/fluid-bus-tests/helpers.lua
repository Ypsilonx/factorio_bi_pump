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
