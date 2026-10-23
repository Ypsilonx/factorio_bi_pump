--- Integrační testy odolnosti (nálezy z review): konflikt kapalin, změna kapaliny, výpadek proudu,
--- skrytý kombinátor, klonování, dvojí registrace, spojky vedle sebe.
local H = require("helpers")

--- Svislá řada BUS trubek ve sloupci x pro řádky y1..y2.
local function column(ctx, x, y1, y2)
  local list = {}
  for y = y1, y2 do list[#list + 1] = H.place(ctx, "fb-bus-pipe", x, y) end
  return list
end

--- Množství kapaliny v segmentu, ve kterém je trubka.
local function amount(pipe)
  local _, value = H.segment_fluid(pipe)
  return value or 0
end

--- Scéna: segment A (6 trubek) – spojka – segment B (6 trubek), napájená.
local function two_segments(ctx)
  ctx.a = column(ctx, 0, -6, -1)[1]
  ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0)
  ctx.b = column(ctx, 0, 1, 6)[1]
  ctx.eei = H.power(ctx, 0, 0)
end

--- Počet skrytých kombinátorů na pozici spojky.
local function hidden_count(ctx, coupler)
  return #ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = coupler.position })
end

return {
  {
    name = "konflikt kapalin se po odstranění druhé kapaliny zruší",
    setup = function(ctx)
      two_segments(ctx)
      ctx.a.insert_fluid({ name = "water", amount = 300 })
      ctx.b.insert_fluid({ name = "crude-oil", amount = 300 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        H.truthy(remote.call("fb", "network_of", ctx.c.unit_number).conflict, "nejdřív konflikt")
        ctx.b.extract_fluid({ name = "crude-oil", amount = 1000 })
      end },
      { ticks = 400, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number).conflict, false, "konflikt zrušen")
        H.truthy(amount(ctx.b) > 100, "voda přetekla (" .. amount(ctx.b) .. ")")
      end },
    },
  },
  {
    name = "vyprázdněný bus přijme jinou kapalinu",
    setup = function(ctx)
      two_segments(ctx)
      ctx.a.insert_fluid({ name = "water", amount = 300 })
    end,
    steps = {
      { ticks = 300, run = function(ctx)
        ctx.a.extract_fluid({ name = "water", amount = 1000 })
        ctx.b.extract_fluid({ name = "water", amount = 1000 })
      end },
      { ticks = 200, run = function(ctx)
        ctx.a.insert_fluid({ name = "steam", amount = 300, temperature = 165 })
      end },
      { ticks = 400, run = function(ctx)
        local info = remote.call("fb", "network_of", ctx.c.unit_number)
        H.eq(info.conflict, false, "bez konfliktu")
        H.eq(info.fluid, "steam", "kapalina sítě je pára")
        H.truthy(amount(ctx.b) > 100, "pára přetekla (" .. amount(ctx.b) .. ")")
      end },
    },
  },
  {
    name = "výpadek proudu u běžící sítě síť rozpadne a hlásí Bez proudu",
    setup = function(ctx)
      two_segments(ctx)
      ctx.a.insert_fluid({ name = "water", amount = 600 })
    end,
    steps = {
      { ticks = 200, run = function(ctx)
        H.truthy(remote.call("fb", "network_of", ctx.c.unit_number), "síť běží")
        ctx.eei.destroy()
      end },
      { ticks = 300, run = function(ctx)
        H.eq(remote.call("fb", "network_of", ctx.c.unit_number), nil, "síť rozpadlá")
        H.eq(ctx.c.custom_status.label[1], "fb-status.no-power", "stav")
      end },
    },
  },
  {
    name = "skrytý kombinátor je nezničitelný",
    setup = function(ctx) ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0) end,
    steps = { { ticks = 2, run = function(ctx)
      local hidden = ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position })[1]
      H.eq(hidden.destructible, false, "nezničitelný")
    end } },
  },
  {
    name = "klonování spojky nevyrobí druhý kombinátor",
    setup = function(ctx) ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0) end,
    steps = { { ticks = 2, run = function(ctx)
      local hidden = ctx.surface.find_entities_filtered({ name = "fb-bus-coupler-signals", position = ctx.c.position })
      ctx.surface.clone_entities({ entities = { ctx.c, hidden[1] }, destination_offset = { 4, 0 } })
      local clone = ctx.surface.find_entities_filtered({ name = "fb-bus-coupler",
        position = { ctx.c.position.x + 4, ctx.c.position.y } })[1]
      H.truthy(clone, "klon spojky")
      H.eq(hidden_count(ctx, clone), 1, "jeden kombinátor u klonu")
    end } },
  },
  {
    name = "dvojí ohlášení stavby nevyrobí druhý kombinátor",
    setup = function(ctx) ctx.c = H.place(ctx, "fb-bus-coupler", 0, 0) end,
    steps = { { ticks = 2, run = function(ctx)
      script.raise_script_built({ entity = ctx.c })
      H.eq(hidden_count(ctx, ctx.c), 1, "jeden kombinátor")
    end } },
  },
  {
    name = "dvě spojky těsně vedle sebe netvoří síť (zástupce nesmí být spojka)",
    setup = function(ctx)
      column(ctx, 0, -3, -1)
      ctx.c1 = H.place(ctx, "fb-bus-coupler", 0, 0)
      ctx.c2 = H.place(ctx, "fb-bus-coupler", 0, 1)
      column(ctx, 0, 2, 4)
      H.power(ctx, 0, 0)
    end,
    steps = { { ticks = 150, run = function(ctx)
      H.eq(remote.call("fb", "network_of", ctx.c1.unit_number), nil, "bez sítě")
      H.eq(ctx.c1.custom_status.label[1], "fb-status.not-connected", "stav")
    end } },
  },
}
