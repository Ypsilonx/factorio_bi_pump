--- Topologie busu ve hře: segmenty na stranách spojek, zástupné BUS trubky a přestavba sítí.
--- Kapalina se čte a zapisuje přes sousední BUS trubku (fluidbox stroje do potrubí neproudí – spec 8.1).
---
--- Přestavba je levná (jen Lua, žádné čtení hry): strany spojek udržuje rozložená kontrola v control.lua.
local network = require("scripts.network")

local COUPLER = prototypes.mod_data["fb-data"].data.coupler

local M = {}

--- Přečte obě strany spojky (segment a sousední BUS trubku) a napájení.
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
  return changed
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
    edges[#edges + 1] = { id = unit, a = coupler.sides[1].seg, b = coupler.sides[2].seg, active = coupler.powered }
  end
  storage.networks, storage.coupler_net = {}, {}
  for index, built in ipairs(network.build(edges)) do
    local net = { segments = built.segments, couplers = built.couplers, reps = {}, conflict = false,
      fraction = 0, total_amount = 0, total_capacity = 0, next_due = tick + (index - 1) % interval }
    for _, unit in ipairs(built.couplers) do
      storage.coupler_net[unit] = index
      for _, side in ipairs(storage.couplers[unit].sides) do
        if side.seg and not net.reps[side.seg] then net.reps[side.seg] = side.rep end
      end
    end
    storage.networks[index] = net
  end
  storage.check_list = check
  storage.check_cursor = math.min(storage.check_cursor, math.max(#check, 1))
  storage.cursor = math.min(storage.cursor, math.max(#storage.networks, 1))
  storage.dirty = false
end

--- Síť, ve které je spojka.
--- @param unit integer
--- @return table|nil síť, integer|nil její index
function M.network_of(unit)
  local index = storage.coupler_net and storage.coupler_net[unit]
  if index then return storage.networks[index], index end
end

return M
