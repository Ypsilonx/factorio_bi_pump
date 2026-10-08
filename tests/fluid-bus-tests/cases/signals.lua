--- Integrační testy signálů a stavu spojky.
local H = require("helpers")

--- Svislá řada BUS trubek.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

local INPUT = { type = "virtual", name = "fb-input-fill", quality = "normal" }
local OUTPUT = { type = "virtual", name = "fb-output-fill", quality = "normal" }

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
    name = "vypnutá spojka posílá naplnění vstupu a výstupu; vlastní podmínka vstup > 50 ji zapne bez drátů",
    setup = function(ctx)
      -- Vstup spojky otočené na sever je nahoře.
      ctx.top = column(ctx, 0, -6, -1)[1]
      ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
      ctx.bottom = column(ctx, 0, 1, 6)[1]
      H.power(ctx, 0, 0)
      local behavior = ctx.c.get_or_create_control_behavior()
      behavior.circuit_enable_disable = true
      behavior.circuit_condition = { comparator = ">", first_signal = INPUT, constant = 50 }
      ctx.top.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        local input = ctx.c.get_signal(INPUT, defines.wire_connector_id.circuit_green)
        H.truthy(input >= 45 and input <= 55, "vstup ≈ 50 % (" .. input .. ")")
        H.eq(ctx.c.get_signal(OUTPUT, defines.wire_connector_id.circuit_green), 0, "výstup prázdný")
        H.eq(ctx.bottom.fluidbox.get_fluid_segment_contents(1).water, nil, "pod 50 % nepouští")
        H.eq(ctx.c.custom_status.label[1], "fb-status.disabled", "stav")
        ctx.top.insert_fluid({ name = "water", amount = 300 })
      end },
      { ticks = 300, run = function(ctx)
        local water = ctx.bottom.fluidbox.get_fluid_segment_contents(1).water or 0
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
