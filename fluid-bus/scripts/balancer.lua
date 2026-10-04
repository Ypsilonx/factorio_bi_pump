--- Vyrovnávání sítí busu: každá síť se jednou za `fb-balance-interval` ticků srovná celá najednou
--- v jednom ticku – přečte všechny segmenty, spočítá společné naplnění a přelije. Po vyrovnání mají
--- všechny segmenty sítě stejné procento naplnění (žádné zpoždění ani trvalý rozdíl mezi segmenty).
local m = require("scripts.balance_math")
local topology = require("scripts.topology")

local M = {}

--- Kolik segmentů nejvýš vyrovnat v jednom ticku (přes více sítí); jedna síť se ale vždy vyrovná celá.
--- Chrání před špičkou, když se ve stejném ticku sejde více velkých sítí. Laditelné.
M.SEGMENT_BUDGET = 300

--- Vyrovná jednu síť: přečte segmenty, odebere přebytky, doplní nedostatky (s teplotou odebrané
--- kapaliny); co by se nevešlo, vrátí zpět do segmentů, ze kterých se bralo.
--- @param net table síť ze storage.networks
local function balance(net)
  local reps, states = {}, {}
  for i, segment in ipairs(net.segments) do
    local rep = net.reps[segment]
    if not (rep and rep.valid) then
      storage.dirty = true
      return
    end
    local name, amount, capacity = topology.read(rep)
    reps[i], states[i] = rep, { fluid = name, amount = amount, capacity = capacity }
  end
  local plan = m.plan_network(states)
  net.conflict, net.fraction = plan.conflict, plan.fraction
  net.total_amount, net.total_capacity = plan.total, plan.capacity
  if not plan.conflict then net.fluid = plan.fluid end
  if plan.conflict or not plan.fluid then return end
  local removed, heat, donors = 0, 0, {}
  for i, delta in ipairs(plan.deltas) do
    if delta < 0 then
      local fluid = reps[i].fluidbox[1]
      local taken = reps[i].remove_fluid({ name = plan.fluid, amount = -delta })
      removed = removed + taken
      heat = heat + taken * (fluid and fluid.temperature or 0)
      donors[#donors + 1] = reps[i]
    end
  end
  if removed <= 0 then return end
  local temperature = heat / removed
  local left = removed
  for i, delta in ipairs(plan.deltas) do
    if delta > 0 and left > 0 then
      left = left - reps[i].insert_fluid({ name = plan.fluid, amount = math.min(delta, left), temperature = temperature })
    end
  end
  for _, rep in ipairs(donors) do
    if left <= 1e-9 then break end
    left = left - rep.insert_fluid({ name = plan.fluid, amount = left, temperature = temperature })
  end
  if left > 1e-6 then log("fluid-bus: při vyrovnání nešlo vrátit " .. left .. " " .. plan.fluid) end
end

--- Vyrovná sítě, které jsou na řadě (nejvýš SEGMENT_BUDGET segmentů za tick, aspoň jednu síť).
--- @param tick integer
--- @param interval integer interval vyrovnávání z nastavení mapy (síť ho může přebít signálem)
function M.step(tick, interval)
  local nets = storage.networks
  local count = #nets
  local budget = M.SEGMENT_BUDGET
  for _ = 1, count do
    local net = nets[storage.cursor]
    storage.cursor = storage.cursor % count + 1
    if net.next_due <= tick then
      balance(net)
      net.next_due = tick + (net.interval or interval)
      net.balanced_tick = tick
      budget = budget - #net.segments
      if budget <= 0 or storage.dirty then return end
    end
  end
end

return M
