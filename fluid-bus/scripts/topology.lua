--- Topologie busu ve hře: segmenty na stranách spojek, zástupné BUS trubky a přestavba sítí.
--- Kapalina se čte a zapisuje přes sousední BUS trubku (fluidbox stroje do potrubí neproudí – spec 8.1).
---
--- Přestavba je levná (jen Lua, žádné čtení hry): strany spojek udržuje rozložená kontrola v control.lua.
local network = require("scripts.network")

local DATA = prototypes.mod_data["fb-data"].data
local COUPLER = DATA.coupler
local INTERVAL = { type = "virtual", name = DATA.interval_signal }
local RED = defines.wire_connector_id.circuit_red
local GREEN = defines.wire_connector_id.circuit_green
--- Rozsah intervalu ze signálu (stejný jako nastavení mapy fb-balance-interval).
local MIN_INTERVAL, MAX_INTERVAL = 1, 600

local M = {}

--- Je spojka zapnutá? Vypnout ji jde podmínkou obvodové sítě (jako pumpu).
--- @param entity LuaEntity spojka
--- @return boolean
local function enabled(entity)
  local behavior = entity.get_control_behavior()
  return not (behavior and behavior.disabled)
end

--- Přečte obě strany spojky (segment a sousední BUS trubku), napájení a zapnutí.
--- Zástupcem nesmí být jiná spojka: její fluidbox do potrubí neproudí a kapacitu segmentu nevrací.
--- @param coupler table záznam ze storage.couplers
--- @return boolean true, pokud se něco změnilo
function M.refresh(coupler)
  local entity = coupler.entity
  local fluidbox = entity.fluidbox
  local changed = false
  for i = 1, 2 do
    local side = coupler.sides[i]
    local connections = fluidbox.get_connections(i)
    local owner = connections[1] and connections[1].owner
    local rep = owner and owner.name ~= COUPLER and owner or nil
    local segment = rep and fluidbox.get_fluid_segment_id(i) or nil
    if side.seg ~= segment or side.rep ~= rep then changed = true end
    side.seg, side.rep = segment, rep
  end
  local powered = entity.energy > 0
  if coupler.powered ~= powered then changed = true end
  coupler.powered = powered
  local on = enabled(entity)
  if coupler.enabled ~= on then changed = true end
  coupler.enabled = on
  return changed
end

--- Interval sítě: nejmenší interval ze signálu na jejích spojkách, nil = platí nastavení mapy.
--- @param net table síť ze storage.networks
--- @return integer|nil
local function network_interval(net)
  local best
  for _, unit in ipairs(net.couplers) do
    local value = storage.couplers[unit].interval
    if value and (not best or value < best) then best = value end
  end
  return best
end

--- Přečte signál intervalu na spojce (oba dráty); při změně přepočte interval její sítě.
--- @param unit integer
--- @param coupler table záznam ze storage.couplers
function M.read_interval(unit, coupler)
  local value = coupler.entity.get_signal(INTERVAL, RED, GREEN)
  value = value > 0 and math.min(math.max(value, MIN_INTERVAL), MAX_INTERVAL) or nil
  if coupler.interval == value then return end
  coupler.interval = value
  local net = M.network_of(unit)
  if net then net.interval = network_interval(net) end
end

--- Přečte segment přes zástupnou trubku.
--- @param rep LuaEntity BUS trubka v segmentu
--- @return string|nil kapalina, number množství, number kapacita segmentu
function M.read(rep)
  local fluidbox = rep.fluidbox
  local name, amount = next(fluidbox.get_fluid_segment_contents(1) or {})
  return name, amount or 0, fluidbox.get_capacity(1)
end

--- Přestaví sítě z uloženého stavu spojek (bez čtení hry). Vyrovnání sítí rozloží do intervalu,
--- aby se více sítí nevyrovnávalo ve stejném ticku.
--- @param tick integer aktuální tick
--- @param interval integer interval vyrovnávání (ticky)
function M.rebuild(tick, interval)
  storage.rebuilds = (storage.rebuilds or 0) + 1
  local edges, check = {}, {}
  -- Bez volání hry (ani `valid`): neplatné spojky odhalí události a rozložená kontrola.
  for unit, coupler in pairs(storage.couplers) do
    check[#check + 1] = unit
    edges[#edges + 1] = { id = unit, a = coupler.sides[1].seg, b = coupler.sides[2].seg,
      active = coupler.powered and coupler.enabled ~= false }
  end
  storage.networks, storage.coupler_net, storage.segment_net = {}, {}, {}
  for index, built in ipairs(network.build(edges)) do
    local net = { segments = built.segments, couplers = built.couplers, reps = {}, conflict = false,
      fraction = 0, total_amount = 0, total_capacity = 0, next_due = tick + (index - 1) % interval }
    for _, unit in ipairs(built.couplers) do
      storage.coupler_net[unit] = index
      for _, side in ipairs(storage.couplers[unit].sides) do
        if side.seg and not net.reps[side.seg] then net.reps[side.seg] = side.rep end
      end
    end
    for _, segment in ipairs(built.segments) do storage.segment_net[segment] = index end
    net.interval = network_interval(net)
    storage.networks[index] = net
  end
  storage.check_list = check
  storage.check_cursor = math.min(storage.check_cursor, math.max(#check, 1))
  storage.cursor = math.min(storage.cursor, math.max(#storage.networks, 1))
  storage.dirty = false
end

--- Naplnění jedné strany spojky: naplnění sítě, do které patří segment strany (i přes jiné spojky),
--- jinak samotného segmentu. Vypnutá spojka tak zná naplnění obou stran, které odděluje.
--- @param side table strana spojky { seg, rep }
--- @return number|nil podíl 0–1, nil = strana bez BUS trubky
--- @return string|nil kapalina
function M.side_fill(side)
  if not (side.rep and side.rep.valid) then return nil end
  local index = storage.segment_net and storage.segment_net[side.seg]
  local net = index and storage.networks[index]
  if net and not net.conflict then return net.fraction, net.fluid end
  local name, amount, capacity = M.read(side.rep)
  return capacity > 0 and amount / capacity or 0, name
end

--- Síť, ve které je spojka.
--- @param unit integer
--- @return table|nil síť, integer|nil její index
function M.network_of(unit)
  local index = storage.coupler_net and storage.coupler_net[unit]
  if index then return storage.networks[index], index end
end

return M
