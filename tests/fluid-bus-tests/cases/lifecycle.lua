--- Integrační testy životního cyklu spojky: rotace, ztráta kombinátoru, revalidace.
local H = require("helpers")

return {
  {
    name = "rotace spojky ji odpojí (strany míří jinam) a přestaví sítě",
    setup = function(ctx)
      H.place(ctx, "fb-bus-pipe", 0, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.place(ctx, "fb-bus-pipe", 0, 1)
      H.power(ctx, 0, 0)
    end,
    steps = {
      { ticks = 150, run = function(ctx)
        H.truthy(remote.call("fb", "network_of", ctx.c.unit_number), "síť před rotací")
        -- rotate() skriptem nevyvolá on_player_rotated_entity – změnu zachytí rozložená kontrola (≤ interval).
        ctx.c.rotate()
      end },
      { ticks = 150, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "po rotaci bez sítě")
      end },
    },
  },
  {
    name = "revalidace po ztrátě kombinátoru vytvoří nový",
    setup = function(ctx)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
    end,
    steps = { { ticks = 5, run = function(ctx)
      local hidden = ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position })
      H.eq(#hidden, 2, "dva kombinátory")
      hidden[1].destroy()
      remote.call("fb", "revalidate")
      H.eq(#ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position }), 2,
        "obnoveny oba")
    end } },
  },
}
