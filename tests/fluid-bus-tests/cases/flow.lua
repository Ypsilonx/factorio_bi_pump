--- Integrační testy vyrovnávání při toku: celá síť najednou, vysoký průtok, nastavení intervalu.
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

--- Naplnění segmentu trubky (0–1).
local function fill(pipe)
  local _, amount = next(pipe.fluidbox.get_fluid_segment_contents(1) or {})
  return (amount or 0) / pipe.fluidbox.get_capacity(1)
end

--- Řetěz segmentů po `length` trubkách se spojkami mezi nimi (napájenými). Vrátí první trubky segmentů.
local function chain(ctx, count, length)
  local pipes, y = {}, 0
  for i = 1, count do
    pipes[i] = column(ctx, 0, y, y + length - 1)[1]
    y = y + length
    if i < count then
      ctx.coupler = H.place(ctx, "fb-bus-coupler", 0, y)
      H.power(ctx, 0, y)
      y = y + 1
    end
  end
  return pipes
end

--- Kroky po jednom ticku: `check(ctx)` (stav po vyrovnání, před tokem) a pak tok `rate` l/tick do prvního
--- a z posledního segmentu; `ctx.taken` = kolik se v předchozím ticku podařilo odebrat.
local function flow_steps(ticks, rate, check)
  local steps = {}
  for _ = 1, ticks do
    steps[#steps + 1] = { ticks = 1, run = function(ctx)
      -- Kontrola před tokem tohoto ticku: mod vyrovnává v on_tick dřív než testovací mod.
      check(ctx)
      ctx.pipes[1].insert_fluid({ name = "water", amount = rate })
      ctx.taken = ctx.pipes[#ctx.pipes].remove_fluid({ name = "water", amount = rate })
    end }
  end
  return steps
end

--- Spojí kroky: náběh (bez kontroly) + měření + závěrečné vyhodnocení.
local function scenario(warmup, measure, rate, check, verdict)
  local steps = { { ticks = 1, run = function() end } }
  for _, step in ipairs(flow_steps(warmup, rate, function() end)) do steps[#steps + 1] = step end
  for _, step in ipairs(flow_steps(measure, rate, check)) do steps[#steps + 1] = step end
  steps[#steps + 1] = { ticks = 1, run = verdict }
  return steps
end

return {
  {
    name = "po vyrovnání jsou všechny segmenty sítě stejně naplněné i při toku",
    setup = function(ctx)
      ctx.pipes = chain(ctx, 3, 20)
      ctx.pipes[1].insert_fluid({ name = "water", amount = 3000 })
      ctx.samples, ctx.worst = 0, 0
    end,
    steps = scenario(120, 120, 20, function(ctx)
      local info = remote.call("fb", "network_of", ctx.coupler.unit_number)
      if info and info.balanced_tick == game.tick then
        ctx.samples = ctx.samples + 1
        local a, b, c = fill(ctx.pipes[1]), fill(ctx.pipes[2]), fill(ctx.pipes[3])
        ctx.worst = math.max(ctx.worst, math.abs(a - b), math.abs(b - c), math.abs(a - c))
      end
    end, function(ctx)
      H.truthy(ctx.samples > 0, "aspoň jedno vyrovnání v měřeném okně")
      H.truthy(ctx.worst < 0.011, "po vyrovnání stejné naplnění (nejhorší rozdíl " .. ctx.worst .. ")")
    end),
  },
  {
    name = "průtok 12 000/s přes spojku: odběr nestrádá",
    setup = function(ctx)
      ctx.pipes = chain(ctx, 2, 100)
      ctx.pipes[1].insert_fluid({ name = "water", amount = 10000 })
      ctx.short = 0
    end,
    steps = scenario(120, 600, 200, function(ctx)
      ctx.short = ctx.short + (200 - (ctx.taken or 200))
    end, function(ctx)
      H.truthy(ctx.short < 1, "odběru chybělo " .. ctx.short .. " l")
    end),
  },
  {
    name = "interval vyrovnávání je nastavení mapy (měnitelné za běhu)",
    steps = { { ticks = 1, run = function()
      local setting = settings.global["fb-balance-interval"]
      H.truthy(setting, "nastavení existuje")
      H.eq(setting.value, 5, "výchozí 5 ticků")
    end } },
  },
}
