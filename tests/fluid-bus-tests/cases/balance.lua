--- Integrační testy vyrovnávání sítě busu (množství, teplota, konflikt, proud, odstranění).
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

--- Obsah segmentu, ve kterém je trubka: jméno a množství.
local function contents(pipe)
  local name, amount = next(pipe.fluidbox.get_fluid_segment_contents(1) or {})
  return name, amount or 0
end

--- Scéna: segment A (6 trubek) – spojka – segment B (6 trubek), volitelně napájená.
local function two_segments(ctx, powered)
  ctx.a = column(ctx, 0, -6, -1)[1]
  ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
  ctx.b = column(ctx, 0, 1, 6)[1]
  if powered then H.power(ctx, 0, 0) end
end

return {
  {
    name = "dva segmenty se vyrovnají a množství se zachová",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local _, a = contents(ctx.a)
      local _, b = contents(ctx.b)
      local info = remote.call("fb", "network_of", ctx.c.unit_number)
      H.truthy(math.abs(a - b) < 30, "vyrovnáno (" .. a .. " / " .. b .. ")")
      H.truthy(math.abs(a + b + info.buffer - 600) < 0.01, "zachováno (" .. (a + b + info.buffer) .. ")")
    end } },
  },
  {
    name = "řetěz čtyř segmentů se zdrojem na konci se vyrovná",
    setup = function(ctx)
      ctx.pipes = {}
      for i = 0, 3 do
        ctx.pipes[i + 1] = column(ctx, 0, i * 6 - 12, i * 6 - 8)[1]
        if i < 3 then
          ctx.c = H.place(ctx, "fb-bus-coupler", 0, i * 6 - 7)
          H.power(ctx, 0, i * 6 - 7)
        end
      end
      -- Segment má 5 trubek (500) + box spojky – vložit jen tolik, kolik se vejde.
      ctx.pipes[1].insert_fluid({ name = "water", amount = 500 })
    end,
    steps = { { ticks = 900, run = function(ctx)
      for i, pipe in ipairs(ctx.pipes) do
        local _, amount = contents(pipe)
        H.truthy(math.abs(amount - 125) < 20, "segment " .. i .. ": " .. amount)
      end
    end } },
  },
  {
    name = "pára: teplota se přenese a množství se zachová",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "steam", amount = 600, temperature = 500 })
    end,
    steps = { { ticks = 400, run = function(ctx)
      local _, b = contents(ctx.b)
      H.truthy(b > 200, "pára přetekla (" .. b .. ")")
      H.truthy(math.abs(ctx.b.fluidbox[1].temperature - 500) < 1, "teplota 500 °C")
    end } },
  },
  {
    name = "různé kapaliny: nic se nepřelije",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 300 })
      ctx.b.insert_fluid({ name = "crude-oil", amount = 300 })
    end,
    steps = { { ticks = 300, run = function(ctx)
      local _, a = contents(ctx.a)
      local _, b = contents(ctx.b)
      H.eq(a, 300, "voda beze změny")
      H.eq(b, 300, "ropa beze změny")
      H.truthy(remote.call("fb", "network_of", ctx.c.unit_number).conflict, "konflikt")
    end } },
  },
  {
    name = "bez proudu se nepřelévá",
    setup = function(ctx)
      two_segments(ctx, false)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = { { ticks = 300, run = function(ctx)
      local _, b = contents(ctx.b)
      H.eq(b, 0, "nic nepřeteklo")
      H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "bez sítě")
    end } },
  },
  {
    name = "odstranění spojky zachová množství",
    setup = function(ctx)
      two_segments(ctx, true)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = {
      { ticks = 100, run = function(ctx) ctx.c.destroy({ raise_destroy = true }) end },
      { ticks = 5, run = function(ctx)
        local _, a = contents(ctx.a)
        local _, b = contents(ctx.b)
        H.truthy(math.abs(a + b - 600) < 0.01, "zachováno (" .. (a + b) .. ")")
      end },
    },
  },
}
