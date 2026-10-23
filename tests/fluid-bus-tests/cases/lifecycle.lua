--- Integrační testy životního cyklu spojky: rotace.
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
}
