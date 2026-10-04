--- Integrační testy signálů a stavu spojky.
local H = require("helpers")

--- Svislá řada BUS trubek.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

return {
  {
    name = "červený drát = množství, zelený drát = procenta, obojí pod ikonou kapaliny; stav ok",
    setup = function(ctx)
      local top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 6)
      H.power(ctx, 0, 0)
      top.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local water = { type = "fluid", name = "water" }
      local amount = ctx.c.get_signal(water, defines.wire_connector_id.circuit_red)
      local percent = ctx.c.get_signal(water, defines.wire_connector_id.circuit_green)
      H.truthy(amount >= 590 and amount <= 600, "červený = množství (" .. amount .. ")")
      H.truthy(percent >= 45 and percent <= 55, "zelený = procenta (" .. percent .. ")")
      H.eq(ctx.c.custom_status.label[1], "fb-status.ok", "stav")
    end } },
  },
  {
    name = "nenapájená spojka hlásí Bez proudu",
    setup = function(ctx)
      column(ctx, 0, -3, -1)
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 3)
    end,
    steps = { { ticks = 200, run = function(ctx)
      H.eq(ctx.c.custom_status.label[1], "fb-status.no-power", "stav")
    end } },
  },
}
