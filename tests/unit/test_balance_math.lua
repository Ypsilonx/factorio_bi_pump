---@diagnostic disable: undefined-global
--- Testy matematiky vyrovnávání: cílové naplnění, plán přelití, míchání teplot.
local A = require("assert")
local m = require("scripts.balance_math")

--- Shoda čísel s tolerancí.
local function near(actual, expected, what)
  A.truthy(math.abs(actual - expected) < 1e-6, what .. ": čekáno " .. expected .. ", dostáno " .. actual)
end

return {
  { "cílové naplnění zahrnuje zásobník a je nejvýš 1", function()
    near(m.target_fraction(300, 100, 1000), 0.4, "0.4")
    near(m.target_fraction(2000, 0, 1000), 1, "strop 1")
    near(m.target_fraction(0, 0, 0), 0, "nulová kapacita")
  end },
  { "plán: přebytek odebrat, nedostatek doplnit jen kolik zásobník má", function()
    near(m.plan(800, 1000, 0.5, 0), -300, "odebrat 300")
    near(m.plan(100, 1000, 0.5, 250), 250, "doplnit jen 250")
    near(m.plan(100, 1000, 0.5, 9999), 400, "doplnit 400")
  end },
  { "plán: v toleranci nic", function()
    near(m.plan(499, 1000, 0.5, 100), 0, "odchylka 1 < tolerance")
  end },
  { "míchání: vážený průměr teplot", function()
    local b = m.mix({ amount = 1000, temperature = 500 }, 1000, 165)
    near(b.amount, 2000, "množství")
    near(b.temperature, 332.5, "teplota")
    local empty = m.mix({ amount = 0 }, 10, 15)
    near(empty.temperature, 15, "prázdný zásobník převezme teplotu")
  end },
  { "odběr ze zásobníku: zbytek nebo prázdný", function()
    local b = m.take({ amount = 100, temperature = 200 }, 40)
    near(b.amount, 60, "zbytek")
    near(b.temperature, 200, "teplota zůstává")
    local e = m.take({ amount = 100, temperature = 200 }, 100)
    near(e.amount, 0, "prázdný")
    A.eq(e.temperature, nil, "bez teploty")
  end },
}
