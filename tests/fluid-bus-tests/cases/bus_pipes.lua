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
    H.truthy(prototypes.technology["fb-fluid-bus"].prerequisites["fluid-handling"], "prerekvizita fluid-handling")
  end),
  {
    name = "BUS trubka se napojí na běžnou (jeden segment)",
    setup = function(ctx)
      ctx.plain = H.place(ctx, "pipe", 0, 0)
      ctx.bus = H.place(ctx, "fb-bus-pipe", 1, 0)
      ctx.plain.insert_fluid({ name = "water", amount = 100 })
    end,
    steps = { { ticks = 5, run = function(ctx)
      H.eq(ctx.bus.fluidbox.get_fluid_segment_id(1), ctx.plain.fluidbox.get_fluid_segment_id(1), "stejný segment")
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
      H.eq(ctx.a.fluidbox.get_fluid_segment_id(1), ctx.b.fluidbox.get_fluid_segment_id(1), "stejný segment")
    end } },
  },
  {
    name = "rychlá výměna běžné trubky za BUS zachová kapalinu",
    setup = function(ctx)
      ctx.left = H.place(ctx, "pipe", 0, 0)
      H.place(ctx, "pipe", 1, 0)
      H.place(ctx, "pipe", 2, 0)
      ctx.left.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 5, run = function(ctx)
        ctx.replaced = H.place(ctx, "fb-bus-pipe", 1, 0, { fast_replace = true, spill = false })
      end },
      { ticks = 5, run = function(ctx)
        H.eq(ctx.replaced.name, "fb-bus-pipe", "na místě je BUS trubka")
        local total = ctx.left.fluidbox.get_fluid_segment_contents(1).water or 0
        H.truthy(math.abs(total - 300) < 0.01, "voda zachována (" .. total .. ")")
      end },
    },
  },
  {
    name = "se Space Age jdou BUS trubky recyklovat",
    requires = "quality",
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
