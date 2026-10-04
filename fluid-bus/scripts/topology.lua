--- Topologie busu ve hře: segmenty na stranách spojek, zástupné BUS trubky a přestavba sítí.
--- Kapalina se čte a zapisuje přes sousední BUS trubku (fluidbox stroje do potrubí neproudí – spec 8.1).
---
--- Přestavba je levná (jen Lua, žádné čtení hry): strany spojek udržuje rozložená kontrola v control.lua
--- a naměřené hodnoty segmentů se drží v `storage.segments` napříč přestavbami. Segment, který ještě nebyl
--- změřen, se změří v plánovači; dokud síť nezná všechny své segmenty, nic se nepřelévá.
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

--- Zapíše naměřený stav segmentu do cache a průběžně upraví součty sítě.
--- @param net table síť ze storage.networks
--- @param segment integer
--- @param fluid string|nil
--- @param amount number
--- @param capacity number
function M.record(net, segment, fluid, amount, capacity)
  local old = storage.segments[segment]
  if old then
    net.total_amount = net.total_amount - old.amount
    net.total_capacity = net.total_capacity - old.capacity
  else
    net.known = net.known + 1
  end
  storage.segments[segment] = { fluid = fluid, amount = amount, capacity = capacity }
  net.total_amount = net.total_amount + amount
  net.total_capacity = net.total_capacity + capacity
end

--- Přečte segment přes zástupnou trubku.
--- @param rep LuaEntity BUS trubka v segmentu
--- @return string|nil kapalina, number množství, number kapacita segmentu
function M.read(rep)
  local fluidbox = rep.fluidbox
  local name, amount = next(fluidbox.get_fluid_segment_contents(1) or {})
  return name, amount or 0, fluidbox.get_capacity(1)
end

--- Kapalina a konflikt sítě z cache segmentů (volá se na konci kola a po přestavbě).
--- Prázdné segmenty se nepočítají; prázdná síť bez zásobníku nemá kapalinu (může přijmout jinou).
--- @param net table
function M.update_fluid(net)
  local found, count = nil, 0
  for _, segment in ipairs(net.segments) do
    local state = storage.segments[segment]
    if state and state.fluid and state.amount > 0 and state.fluid ~= found then
      if found == nil then
        found, count = state.fluid, 1
      else
        count = count + 1
      end
    end
  end
  if net.buffer.amount > 0 and net.fluid and found and net.fluid ~= found then count = count + 1 end
  net.conflict = count > 1
  if not net.conflict then
    net.fluid = found or (net.buffer.amount > 0 and net.fluid or nil)
  end
end

--- Vrátí zásobníky starých sítí do jejich segmentů (před přestavbou se sítě zahodí).
--- Zkusí zástupce sítě i aktuální zástupce spojek (původní trubka mohla být zbořena).
local function flush_buffers()
  for _, net in pairs(storage.networks) do
    local left = net.buffer.amount
    if left > 0 and net.fluid then
      local targets = {}
      for _, segment in ipairs(net.segments) do targets[#targets + 1] = net.reps[segment] end
      for _, unit in ipairs(net.couplers) do
        local coupler = storage.couplers[unit]
        if coupler then
          for _, side in ipairs(coupler.sides) do targets[#targets + 1] = side.rep end
        end
      end
      for _, rep in ipairs(targets) do
        if left <= 0 then break end
        if rep and rep.valid then
          left = left - rep.insert_fluid({ name = net.fluid, amount = left, temperature = net.buffer.temperature })
        end
      end
      if left > 1e-6 then log("fluid-bus: při přestavbě sítě ztraceno " .. left .. " " .. net.fluid) end
    end
  end
end

--- Přestaví sítě z uloženého stavu spojek – bez čtení hry (kromě vrácení zásobníků); nové spojky
--- změří až rozložená kontrola v control.lua (pak vyvolá další přestavbu). Pozici plánovače zachová, aby časté přestavby nezastavily vyrovnávání konce fronty.
function M.rebuild()
  storage.rebuilds = (storage.rebuilds or 0) + 1
  flush_buffers()
  local edges, check = {}, {}
  -- Bez volání hry (ani `valid`): neplatné spojky odhalí události a rozložená kontrola.
  for unit, coupler in pairs(storage.couplers) do
    check[#check + 1] = unit
    edges[#edges + 1] = { id = unit, a = coupler.sides[1].seg, b = coupler.sides[2].seg, active = coupler.powered }
  end
  local used = {}
  storage.networks, storage.queue, storage.coupler_net = {}, {}, {}
  for index, built in ipairs(network.build(edges)) do
    local net = { segments = built.segments, couplers = built.couplers, reps = {}, known = 0,
      total_amount = 0, total_capacity = 0, buffer = { amount = 0 }, conflict = false, fraction = 0 }
    for _, unit in ipairs(built.couplers) do
      storage.coupler_net[unit] = index
      for _, side in ipairs(storage.couplers[unit].sides) do
        if side.seg and not net.reps[side.seg] then net.reps[side.seg] = side.rep end
      end
    end
    for _, segment in ipairs(net.segments) do
      used[segment] = true
      local state = storage.segments[segment]
      if state then
        net.known = net.known + 1
        net.total_amount = net.total_amount + state.amount
        net.total_capacity = net.total_capacity + state.capacity
      end
      storage.queue[#storage.queue + 1] = { net = index, seg = segment }
    end
    M.update_fluid(net)
    storage.networks[index] = net
  end
  for segment in pairs(storage.segments) do
    if not used[segment] then storage.segments[segment] = nil end
  end
  storage.check_list = check
  storage.check_cursor = math.min(storage.check_cursor, math.max(#check, 1))
  storage.cursor = math.min(storage.cursor, math.max(#storage.queue, 1))
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
