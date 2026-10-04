--- Integrační testy spojky busu: prototyp, napojení, napájení.
local H = require("helpers")

--- Jednokrokový test bez setupu.
local function check(name, fn)
  return { name = name, steps = { { ticks = 1, run = fn } } }
end

return {
  check("spojka existuje a odemyká ji fb-fluid-bus", function()
    local data = prototypes.mod_data["fb-data"].data
    H.eq(data.coupler, "fb-bus-coupler", "mod-data")
    H.truthy(prototypes.entity["fb-bus-coupler"], "entita")
    H.eq(H.unlocking_techs("fb-bus-coupler")[1], "fb-fluid-bus", "výzkum")
  end),
  check("výzkum spojky je až po pokročilých obvodech (pokud ve hře jsou)", function()
    H.log_tech("fb-fluid-bus")
    local circuit_tech = H.unlocking_techs("advanced-circuit")[1]
    if circuit_tech then H.truthy(H.requires("fb-fluid-bus", circuit_tech), "vyžaduje " .. circuit_tech) end
  end),
  {
    name = "spojka se na běžnou trubku nenapojí, na BUS ano (dva segmenty)",
    setup = function(ctx)
      H.place(ctx, "pipe", 0, -1)
      ctx.plain = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.place(ctx, "pipe", 0, 1)
      H.place(ctx, "fb-bus-pipe", 3, -1)
      ctx.bus = H.place(ctx, "fb-bus-coupler", 3, 0)
      H.place(ctx, "fb-bus-pipe", 3, 1)
    end,
    steps = { { ticks = 2, run = function(ctx)
      H.eq(#ctx.plain.fluidbox.get_connections(1) + #ctx.plain.fluidbox.get_connections(2), 0, "běžná trubka")
      H.eq(#ctx.bus.fluidbox.get_connections(1), 1, "BUS nahoře")
      H.eq(#ctx.bus.fluidbox.get_connections(2), 1, "BUS dole")
      H.truthy(ctx.bus.fluidbox.get_fluid_segment_id(1) ~= ctx.bus.fluidbox.get_fluid_segment_id(2), "dva segmenty")
    end } },
  },
  {
    name = "napájená spojka má energii, nenapájená ne",
    setup = function(ctx)
      ctx.on = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.power(ctx, 0, 0)
      ctx.off = H.place(ctx, "fb-bus-coupler", 8, 0)
    end,
    steps = { { ticks = 30, run = function(ctx)
      H.truthy(ctx.on.energy > 0, "napájená")
      H.eq(ctx.off.energy, 0, "nenapájená")
    end } },
  },
}
