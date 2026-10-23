--- Integrační testy signálů a stavu spojky.
local H = require("helpers")

--- Svislá řada BUS trubek.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

local WATER = { type = "fluid", name = "water", quality = "normal" }
local RED_WIRE = defines.wire_connector_id.circuit_red
local GREEN_WIRE = defines.wire_connector_id.circuit_green

return {
  {
    name = "jediný signál: zelený drát [kapalina] = naplnění v %, červený prázdný; stav ok",
    setup = function(ctx)
      local top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      column(ctx, 0, 1, 6)
      H.power(ctx, 0, 0)
      top.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local percent = ctx.c.get_signal(WATER, GREEN_WIRE)
      H.truthy(percent >= 45 and percent <= 55, "zelený = procenta (" .. percent .. ")")
      H.eq(ctx.c.get_signal(WATER, RED_WIRE), 0, "červený prázdný")
      H.eq(ctx.c.custom_status.label[1], "fb-status.ok", "stav")
    end } },
  },
  {
    name = "vypnutá spojka posílá naplnění plnější strany; vlastní podmínka [voda] > 50 ji zapne bez drátů",
    setup = function(ctx)
      ctx.top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      ctx.bottom = column(ctx, 0, 1, 6)[1]
      H.power(ctx, 0, 0)
      local behavior = ctx.c.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = { comparator = ">", first_signal = WATER, constant = 50 }
      -- Kapalina na výstupní straně: na směru spojky nezáleží.
      ctx.bottom.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        local fill = ctx.c.get_signal(WATER, GREEN_WIRE)
        H.truthy(fill >= 45 and fill <= 55, "plnější strana ≈ 50 % (" .. fill .. ")")
        H.eq(select(2, H.segment_fluid(ctx.top, "water")), nil, "pod 50 % nepouští")
        H.eq(ctx.c.custom_status.label[1], "fb-status.disabled", "stav")
        ctx.bottom.insert_fluid({ name = "water", amount = 300 })
      end },
      { ticks = 300, run = function(ctx)
        local water = select(2, H.segment_fluid(ctx.top, "water")) or 0
        H.truthy(water > 0, "nad 50 % pouští dál (" .. water .. ")")
      end },
    },
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
