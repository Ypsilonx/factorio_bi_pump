--- Integrační testy stavu spojky a řízení obvodem (spojka nic nevysílá, signál čte BUS trubka).
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
local MODE = defines.control_behavior.single_fluid_box.exclusive_mode

--- Propojí trubku se spojkou zeleným drátem a nastaví trubce režim čtení.
--- @param pipe LuaEntity BUS trubka
--- @param coupler LuaEntity
--- @param mode defines.control_behavior.single_fluid_box.exclusive_mode
local function wire(pipe, coupler, mode)
  H.truthy(pipe.get_wire_connector(GREEN_WIRE, true).connect_to(coupler.get_wire_connector(GREEN_WIRE, true)),
    "BUS trubka má obvodový konektor")
  pipe.get_or_create_control_behavior().circuit_exclusive_mode_of_operation = mode
end

return {
  {
    name = "spojka do obvodové sítě nic neposílá; stav ok",
    setup = function(ctx)
      local top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      local bottom = column(ctx, 0, 1, 6)[1]
      H.power(ctx, 0, 0)
      wire(bottom, ctx.c, MODE.none)
      top.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      H.eq(ctx.c.get_signal(WATER, GREEN_WIRE), 0, "zelený prázdný")
      H.eq(ctx.c.get_signal(WATER, RED_WIRE), 0, "červený prázdný")
      H.eq(ctx.c.custom_status.label[1], "fb-status.ok", "stav")
    end } },
  },
  {
    name = "podmínka ze BUS trubky (Číst obsah potrubí): pod prahem nepouští, nad prahem ano",
    setup = function(ctx)
      ctx.top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      ctx.bottom = column(ctx, 0, 1, 6)[1]
      H.power(ctx, 0, 0)
      wire(ctx.bottom, ctx.c, MODE.send_segment_contents)
      local behavior = ctx.c.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = { comparator = ">", first_signal = WATER, constant = 400 }
      -- Kapalina na výstupní straně: na směru spojky nezáleží.
      ctx.bottom.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        local read = ctx.c.get_signal(WATER, GREEN_WIRE)
        H.truthy(read >= 290 and read <= 310, "trubka posílá množství segmentu (" .. read .. ")")
        H.eq(select(2, H.segment_fluid(ctx.top, "water")), nil, "pod prahem nepouští")
        H.eq(ctx.c.custom_status.label[1], "fb-status.disabled", "stav")
        ctx.bottom.insert_fluid({ name = "water", amount = 300 })
      end },
      { ticks = 300, run = function(ctx)
        local water = select(2, H.segment_fluid(ctx.top, "water")) or 0
        H.truthy(water > 0, "nad prahem pouští dál (" .. water .. ")")
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
