--- Integrační testy skládání sítě busu ve hře.
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

return {
  {
    name = "dvě spojky v řadě = jedna síť tří segmentů",
    setup = function(ctx)
      column(ctx, 0, -9, -6)
      ctx.c1 = H.place(ctx, "fb-bus-coupler", 0, -5)
      column(ctx, 0, -4, -1)
      ctx.c2 = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 4)
      H.power(ctx, 0, -5)
      H.power(ctx, 0, 0)
    end,
    steps = { { ticks = 150, run = function(ctx)
      local info = remote.call("fb", "network_of", ctx.c1.unit_number)
      H.truthy(info, "síť existuje")
      H.eq(info.segments, 3, "tři segmenty")
      H.eq(remote.call("fb", "network_of", ctx.c2.unit_number).segments, 3, "druhá spojka ve stejné síti")
    end } },
  },
  {
    name = "trubka dostavěná později spojku připojí",
    setup = function(ctx)
      column(ctx, 0, -4, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      H.power(ctx, 0, 0)
    end,
    steps = {
      { ticks = 150, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "bez trubky dole není síť")
        column(ctx, 0, 1, 3)
      end },
      { ticks = 150, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number).segments, 2, "připojeno")
      end },
    },
  },
}
