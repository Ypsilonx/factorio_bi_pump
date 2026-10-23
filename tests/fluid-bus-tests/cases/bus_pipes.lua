--- Integrační testy BUS trubek ve vanilla / Space Age.
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

return {
  check("BUS trubka a podzemní existují a jsou v mod-data", function()
    H.truthy(prototypes.entity["fb-bus-pipe"], "fb-bus-pipe")
    H.truthy(prototypes.entity["fb-bus-pipe-to-ground"], "fb-bus-pipe-to-ground")
    local names = {}
    for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do names[name] = true end
    H.truthy(names["fb-bus-pipe"] and names["fb-bus-pipe-to-ground"], "obě v mod-data")
  end),
  check("recept je za výzkumem fb-fluid-bus", function()
    local recipe = prototypes.recipe["fb-bus-pipe"]
    H.truthy(recipe, "recept")
    H.eq(recipe.enabled, false, "zamčený")
    local techs = H.unlocking_techs("fb-bus-pipe")
    H.eq(techs[1], "fb-fluid-bus", "odemyká fb-fluid-bus")
    H.truthy(H.requires("fb-fluid-bus", "fluid-handling"), "vyžaduje fluid-handling (i nepřímo)")
  end),
  {
    name = "BUS trubka se na běžnou nenapojí",
    setup = function(ctx)
      ctx.plain = H.place(ctx, "pipe", 0, 0)
      ctx.bus = H.place(ctx, "fb-bus-pipe", 1, 0)
      ctx.plain.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(#(ctx.bus.get_fluid_box_neighbours(1) or {}), 0, "BUS bez napojení")
      H.eq(select(2, H.segment_fluid(ctx.bus, "water")), nil, "voda nepřetekla")
    end } },
  },
  {
    name = "pumpa se napojí na BUS trubku i na běžnou (přechod busu)",
    setup = function(ctx)
      ctx.pump = H.place(ctx, "pump", 0, 0)
      local p = ctx.pump.position
      ctx.bus = ctx.surface.create_entity({ name = "fb-bus-pipe", position = { p.x, p.y - 1.5 }, force = "player" })
      ctx.plain = ctx.surface.create_entity({ name = "pipe", position = { p.x, p.y + 1.5 }, force = "player" })
    end,
    steps = { { ticks = 5, run = function(ctx)
      local owners = {}
      for _, box in ipairs(ctx.pump.get_fluid_box_neighbours(1) or {}) do owners[box.entity.name] = true end
      H.truthy(owners["fb-bus-pipe"], "pumpa – BUS trubka")
      H.truthy(owners["pipe"], "pumpa – běžná trubka")
    end } },
  },
  {
    name = "BUS podzemní se nespáruje s běžnou podzemní",
    setup = function(ctx)
      ctx.a = H.place(ctx, "fb-bus-pipe-to-ground", 0, 0, { direction = defines.direction.west })
      ctx.b = H.place(ctx, "pipe-to-ground", 5, 0, { direction = defines.direction.east })
      ctx.a.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(select(2, H.segment_fluid(ctx.b, "water")), nil, "voda nepřetekla")
    end } },
  },
  {
    name = "BUS podzemní dvojice se propojí (vzdálenost 9 políček)",
    setup = function(ctx)
      ctx.a = H.place(ctx, "fb-bus-pipe-to-ground", 0, 0, { direction = defines.direction.west })
      ctx.b = H.place(ctx, "fb-bus-pipe-to-ground", 9, 0, { direction = defines.direction.east })
      ctx.a.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(ctx.a.get_fluid_segment_id(1), ctx.b.get_fluid_segment_id(1), "stejný segment")
    end } },
  },
  {
    name = "rychlá výměna běžné trubky za BUS zachová kapalinu",
    setup = function(ctx)
      -- Jediná trubka: BUS varianta se na běžné sousedy už nenapojí, kapalina by se rozdělila.
      ctx.left = H.place(ctx, "pipe", 1, 0)
      ctx.left.insert_fluid({ name = "water", amount = 80 })
    end,
    steps = {
      { ticks = 5, run = function(ctx)
        ctx.replaced = H.place(ctx, "fb-bus-pipe", 1, 0, { fast_replace = true, spill = false })
      end },
      { ticks = 5, run = function(ctx)
        H.eq(ctx.replaced.name, "fb-bus-pipe", "na místě je BUS trubka")
        local total = select(2, H.segment_fluid(ctx.replaced, "water")) or 0
        H.truthy(math.abs(total - 80) < 0.01, "voda zachována (" .. total .. ")")
      end },
    },
  },
  {
    name = "se Space Age jdou BUS trubky recyklovat",
    requires = "recycler",
    steps = { { ticks = 1, run = function()
      for _, name in ipairs(prototypes.mod_data["fb-data"].data.bus_pipes) do
        H.truthy(prototypes.recipe[name .. "-recycling"], "recyklace " .. name)
      end
    end } },
  },
  check("suroviny BUS receptů jsou dostupné nejpozději s výzkumem", function()
    H.eq(H.unreachable_ingredients(), "", "nedostupné suroviny")
  end),
}
