--- Rozložené vyrovnávání sítí busu: každý tick zpracuje díl fronty segmentů tak, aby celá fronta
--- prošla jednou za interval. Přebytek segmentu jde do zásobníku sítě, nedostatek se z něj doplní.
local m = require("scripts.balance_math")
local topology = require("scripts.topology")

local M = {}

--- Zpracuje jeden segment: vždy ho změří (i při konfliktu, aby se konflikt mohl zrušit); přelévá jen,
--- když síť zná všechny segmenty, má jednu kapalinu a segment má stejnou kapalinu.
--- @param entry table { net = index sítě, seg = segment }
local function process(entry)
  local net = storage.networks[entry.net]
  if not net then return end
  local rep = net.reps[entry.seg]
  if not (rep and rep.valid) then
    storage.dirty = true
    return
  end
  local name, amount, capacity = topology.read(rep)
  topology.record(net, entry.seg, name, amount, capacity)
  if name and amount > 0 then
    if net.fluid == nil then
      net.fluid = name
    elseif name ~= net.fluid then
      net.conflict = true
    end
  end
  if net.conflict or not net.fluid or net.known < #net.segments then return end
  net.fraction = m.target_fraction(net.total_amount, net.buffer.amount, net.total_capacity)
  local delta = m.plan(amount, capacity, net.fraction, net.buffer.amount)
  if delta < 0 then
    local fluid = rep.fluidbox[1]
    local removed = rep.remove_fluid({ name = net.fluid, amount = -delta })
    net.buffer = m.mix(net.buffer, removed, fluid and fluid.temperature)
    topology.record(net, entry.seg, net.fluid, amount - removed, capacity)
  elseif delta > 0 then
    local inserted = rep.insert_fluid({ name = net.fluid, amount = delta, temperature = net.buffer.temperature })
    net.buffer = m.take(net.buffer, inserted)
    topology.record(net, entry.seg, net.fluid, amount + inserted, capacity)
  end
end

--- Zpracuje díl fronty pro tento tick; na konci kola sítě přepočítá její kapalinu a konflikt.
function M.step()
  local queue = storage.queue
  if #queue == 0 then return end
  local interval = prototypes.mod_data["fb-data"].data.interval
  for _ = 1, math.ceil(#queue / interval) do
    local entry = queue[storage.cursor]
    process(entry)
    local nxt = storage.cursor % #queue + 1
    if nxt == 1 or queue[nxt].net ~= entry.net then
      local net = storage.networks[entry.net]
      if net then topology.update_fluid(net) end
    end
    storage.cursor = nxt
    if storage.dirty then return end
  end
end

return M
