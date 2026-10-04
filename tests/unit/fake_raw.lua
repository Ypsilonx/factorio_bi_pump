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
  raw.recipe[name] = { type = "recipe", name = name, enabled = opts.enabled ~= false,
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
