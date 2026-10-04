--- Integrační testy řízení spojky obvodovou sítí: zapnutí/vypnutí podmínkou a interval signálem.
local H = require("helpers")

--- Svislá řada BUS trubek.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

--- Napájená spojka mezi dvěma řadami BUS trubek; horní řada dostane vodu.
--- @return LuaEntity spojka, LuaEntity horní trubka, LuaEntity dolní trubka
local function bus(ctx)
  local top = column(ctx, 0, -6, -1)[1]
  local coupler = H.place(ctx, "fb-bus-coupler", 0, 0)
  local bottom = column(ctx, 0, 1, 6)[6]
  H.power(ctx, 0, 0)
  return coupler, top, bottom
end

--- Konstantní kombinátor s jedním signálem, propojený zeleným drátem se spojkou.
local function sender(ctx, coupler, x, signal, value)
  local combinator = H.place(ctx, "constant-combinator", x, 0)
  combinator.get_control_behavior().get_section(1).set_slot(1, { value = signal, min = value })
  combinator.get_wire_connector(defines.wire_connector_id.circuit_green, true)
    .connect_to(coupler.get_wire_connector(defines.wire_connector_id.circuit_green, true))
  return combinator
end

local SIGNAL_A = { type = "virtual", name = "signal-A", quality = "normal" }
local INTERVAL = { type = "virtual", name = "fb-balance-interval", quality = "normal" }

return {
  {
    name = "podmínka obvodu spojku vypne (segmenty oddělené) a znovu zapne",
    setup = function(ctx)
      ctx.c, ctx.top, ctx.bottom = bus(ctx)
      ctx.cc = sender(ctx, ctx.c, -3, SIGNAL_A, 1)
      local behavior = ctx.c.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = { comparator = "=", first_signal = SIGNAL_A, constant = 0 }
      ctx.top.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        H.eq(ctx.bottom.fluidbox.get_fluid_segment_contents(1).water, nil, "vypnutá spojka nepřelévá")
        H.eq(ctx.c.custom_status.label[1], "fb-status.disabled", "stav")
        ctx.cc.get_control_behavior().get_section(1).set_slot(1, { value = SIGNAL_A, min = 0 })
      end },
      { ticks = 300, run = function(ctx)
        local water = ctx.bottom.fluidbox.get_fluid_segment_contents(1).water or 0
        H.truthy(water > 250, "zapnutá spojka přelévá (" .. water .. ")")
        H.eq(ctx.c.custom_status.label[1], "fb-status.ok", "stav")
      end },
    },
  },
  {
    name = "signál intervalu nastaví interval sítě, bez signálu platí nastavení mapy",
    setup = function(ctx)
      ctx.c = bus(ctx)
      ctx.cc = sender(ctx, ctx.c, -3, INTERVAL, 120)
    end,
    steps = {
      { ticks = 200, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number).interval, 120, "interval ze signálu")
        ctx.cc.get_control_behavior().get_section(1).clear_slot(1)
      end },
      { ticks = 200, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number).interval,
          settings.global["fb-balance-interval"].value, "interval z nastavení")
      end },
    },
  },
}
