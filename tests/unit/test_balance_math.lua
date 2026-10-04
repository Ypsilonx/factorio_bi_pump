---@diagnostic disable: undefined-global
--- Testy plánu vyrovnání celé sítě najednou (cílové naplnění, přelití, konflikt, tolerance).
local A = require("assert")
local m = require("scripts.balance_math")

--- Shoda čísel s tolerancí.
local function near(actual, expected, what)
  A.truthy(math.abs(actual - expected) < 1e-6, what .. ": čekáno " .. expected .. ", dostáno " .. actual)
end

--- Součet přelití (musí být 0 – nic nevzniká ani nemizí).
local function sum(deltas)
  local total = 0
  for _, d in ipairs(deltas) do total = total + d end
  return total
end

return {
  { "stejné kapacity: všechny segmenty na průměr", function()
    local plan = m.plan_network({ { fluid = "water", amount = 600, capacity = 1000 },
      { amount = 0, capacity = 1000 } })
    near(plan.fraction, 0.3, "naplnění")
    near(plan.deltas[1], -300, "odebrat 300")
    near(plan.deltas[2], 300, "doplnit 300")
    A.eq(plan.fluid, "water", "kapalina")
    A.eq(plan.conflict, false, "bez konfliktu")
  end },
  { "různé kapacity: stejné procento, ne stejné litry", function()
    local plan = m.plan_network({ { fluid = "water", amount = 600, capacity = 600 },
      { amount = 0, capacity = 300 }, { amount = 0, capacity = 1000 } })
    near(plan.fraction, 600 / 1900, "naplnění")
    near(600 + plan.deltas[1], plan.fraction * 600, "A na cíl")
    near(plan.deltas[3], plan.fraction * 1000, "C na cíl")
    near(sum(plan.deltas), 0, "součet nula")
  end },
  { "dvě kapaliny = konflikt, nic se nepřelévá", function()
    local plan = m.plan_network({ { fluid = "water", amount = 300, capacity = 1000 },
      { fluid = "crude-oil", amount = 300, capacity = 1000 } })
    A.eq(plan.conflict, true, "konflikt")
    near(plan.deltas[1], 0, "nic")
    near(plan.deltas[2], 0, "nic")
  end },
  { "prázdná síť nemá kapalinu ani přelití", function()
    local plan = m.plan_network({ { amount = 0, capacity = 1000 }, { amount = 0, capacity = 500 } })
    A.eq(plan.fluid, nil, "bez kapaliny")
    near(sum(plan.deltas), 0, "nic")
  end },
  { "odchylka pod tolerancí se nepřelévá a součet zůstane nula", function()
    local plan = m.plan_network({ { fluid = "water", amount = 501, capacity = 1000 },
      { amount = 499, capacity = 1000 }, { amount = 200, capacity = 1000 } })
    near(sum(plan.deltas), 0, "součet nula")
    A.truthy(plan.deltas[3] > 0, "nejprázdnější dostane")
  end },
}
