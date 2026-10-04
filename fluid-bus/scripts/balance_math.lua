--- Čistá matematika vyrovnávání sítě busu: celá síť se srovná najednou na stejné procento naplnění
--- (stejný „tlak“ ve všech segmentech). Bez herního API, testy: tests/unit/test_balance_math.lua.
local M = {}

--- Odchylka od cíle (podíl kapacity segmentu), pod kterou se nepřelévá – šetří UPS. Laditelné.
M.TOLERANCE = 0.005

--- Naplánuje přelití pro celou síť.
--- Součet přelití je vždy 0 (nic nevzniká ani nemizí): když se kvůli toleranci některé segmenty
--- vynechají, zbylé přítoky se poměrně zmenší (nebo odtoky), aby se součty rovnaly.
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
  local removal, addition = 0, 0
  for i, segment in ipairs(segments) do
    local delta = plan.fraction * segment.capacity - segment.amount
    if math.abs(delta) >= M.TOLERANCE * segment.capacity then
      plan.deltas[i] = delta
      if delta < 0 then removal = removal - delta else addition = addition + delta end
    end
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
