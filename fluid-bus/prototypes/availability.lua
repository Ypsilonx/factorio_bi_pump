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
--- @param raw table data.raw
--- @param item_name string
--- @return string[] jména receptů seřazená abecedně
function M.recipes_for(raw, item_name)
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
  for _, recipe in ipairs(M.recipes_for(raw, item_name)) do
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
