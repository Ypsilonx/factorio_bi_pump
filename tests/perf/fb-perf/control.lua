-- Výkonový scénář: dlouhý bus (N úseků po 29 trubkách) se spojkami (s modem fluid-bus) nebo s pumpami
-- (bez něj), napájení velkými sloupy, zdroj vody na začátku a odběr na konci (infinity pipe,
-- u busu přes pumpu).
-- Počet úseků a interval vyrovnávání zapisuje tools/run-perf.sh do souboru count.lua vedle tohoto skriptu
-- (require jde jen při načítání souboru, ne v on_init).
local COUNT, INTERVAL, GROUP = table.unpack(require("count"))

script.on_init(function()
  if INTERVAL and script.active_mods["fluid-bus"] then
    remote.call("fb", "set_interval", INTERVAL)
  end
  local surface = game.surfaces[1]
  surface.always_day = true
  local bus = script.active_mods["fluid-bus"] ~= nil
  local pipe = bus and "fb-bus-pipe" or "pipe"
  local x = 0
  local previous_pole

  --- Velký sloup u x, propojený měděným drátem s předchozím.
  local function pole(px)
    local p = surface.create_entity({ name = "big-electric-pole", position = { px, -1 }, force = "player" })
    if previous_pole then
      p.get_wire_connector(defines.wire_connector_id.pole_copper, true)
        .connect_to(previous_pole.get_wire_connector(defines.wire_connector_id.pole_copper, true), false)
    end
    previous_pole = p
  end

  local source = surface.create_entity({ name = "infinity-pipe", position = { x + 0.5, 0.5 }, force = "player" })
  source.set_infinity_pipe_filter({ name = "water", percentage = 1, mode = "at-least" })
  --- Pumpa mezi infinity pipe a busem (BUS trubka se na běžné potrubí nenapojí); posune x za ni.
  local function gateway()
    surface.create_entity({ name = "pump", position = { x + 2, 0.5 }, force = "player", direction = defines.direction.east })
    x = x + 2
  end
  if bus then gateway() end
  local eei = surface.create_entity({ name = "electric-energy-interface", position = { 3, -2 }, force = "player" })
  eei.electric_buffer_size = 1e12
  eei.power_production = 1e9
  pole(1)
  for index = 1, COUNT do
    -- Každých GROUP úseků vanilla pumpa místo spojky: bus se rozdělí na samostatné sítě.
    local split = GROUP and GROUP > 0 and index % GROUP == 0
    for _ = 1, bus and 29 or 28 do
      x = x + 1
      surface.create_entity({ name = pipe, position = { x + 0.5, 0.5 }, force = "player" })
    end
    x = x + 1
    if bus and not split then
      local coupler = surface.create_entity({ name = "fb-bus-coupler", position = { x + 0.5, 0.5 }, force = "player",
        direction = defines.direction.east, raise_built = true })
      storage.first = storage.first or coupler.unit_number
    else
      surface.create_entity({ name = "pump", position = { x + 1, 0.5 }, force = "player",
        direction = defines.direction.east })
      x = x + 1
    end
    pole(x)
  end
  if bus then gateway() end
  local sink = surface.create_entity({ name = "infinity-pipe", position = { x + 1.5, 0.5 }, force = "player" })
  sink.set_infinity_pipe_filter({ name = "water", percentage = 0, mode = "at-most" })
  log("FB-PERF built " .. COUNT .. " " .. (bus and "couplers" or "pumps") .. " length " .. x)
end)

--- Průběžný stav sítě během benchmarku (důkaz, že spojky pracují).
script.on_nth_tick(600, function()
  if storage.first and remote.interfaces.fb then
    local info = remote.call("fb", "network_of", storage.first)
    log("FB-PERF network " .. (info and (info.segments .. " segments, fill " .. string.format("%.3f", info.fill)) or "none")
      .. ", rebuilds " .. remote.call("fb", "stats").rebuilds)
  end
end)
