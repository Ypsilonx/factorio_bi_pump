--- Čistá matematika vyrovnávání sítě busu: celá síť se srovná najednou na stejné procento naplnění
--- (stejný „tlak“ ve všech segmentech). Bez herního API, testy: tests/unit/test_balance_math.lua.
local M = {}

--- Odchylka od cíle (podíl kapacity segmentu): když ji nepřekročí žádný segment, síť se nepřelévá
--- (šetří UPS u ustálené sítě). Jakmile ji překročí aspoň jeden, srovná se celá síť. Laditelné.
M.TOLERANCE = 0.005
--- Nejmenší přelití v litrech; menší se vynechá (zbytečné volání hry). Laditelné.
M.MIN_DELTA = 0.01

--- Naplánuje přelití pro celou síť.
--- Tolerance se posuzuje za celou síť, ne po segmentech: jinak by u N segmentů jeden plný (zdroj) dával
--- ostatním jen 1/N svého přebytku, to by spadlo pod toleranci a síť by uvízla na ≈ 1 − N·TOLERANCE.
--- Součet přelití je vždy 0 (nic nevzniká ani nemizí): když se drobná přelití vynechají, zbylé přítoky
--- se poměrně zmenší (nebo odtoky), aby se součty rovnaly.
--- @param segments table[] { fluid = string|nil, amount = number, capacity = number }
--- @return table { conflict = boolean, fluid = string|nil, fraction = number, total = number,
---   capacity = number, deltas = number[] (>0 doplnit, <0 odebrat) }
function M.plan_network(segments)
  local plan = { conflict = false, total = 0, capacity = 0, fraction = 0, deltas = {} }
  for i, segment in ipairs(segments) do
    plan.deltas[i] = 0
    plan.total = plan.total + segment.amount
    plan.capacity = plan.capacity + segment.capacity
    if segment.fluid and segment.amount > 0 then
      if plan.fluid and plan.fluid ~= segment.fluid then plan.conflict = true end
      plan.fluid = plan.fluid or segment.fluid
    end
  end
  if plan.conflict or not plan.fluid or plan.capacity <= 0 then return plan end
  plan.fraction = math.min(1, plan.total / plan.capacity)
  local removal, addition, off = 0, 0, false
  for i, segment in ipairs(segments) do
    local delta = plan.fraction * segment.capacity - segment.amount
    if math.abs(delta) >= M.TOLERANCE * segment.capacity then off = true end
    if math.abs(delta) >= M.MIN_DELTA then
      plan.deltas[i] = delta
      if delta < 0 then removal = removal - delta else addition = addition + delta end
    end
  end
  if not off then
    for i in ipairs(plan.deltas) do plan.deltas[i] = 0 end
    return plan
  end
  -- Vyrovnat součty: přelít jen tolik, kolik se zároveň odebere i doplní.
  local moved = math.min(removal, addition)
  for i, delta in ipairs(plan.deltas) do
    if delta < 0 then
      plan.deltas[i] = delta * moved / removal
    elseif delta > 0 then
      plan.deltas[i] = delta * moved / addition
    end
  end
  return plan
end

return M
