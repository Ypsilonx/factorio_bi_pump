---@diagnostic disable: undefined-global
--- Testy výzkumů BUS trubek: prerekvizity, cena, pokrytí základním výzkumem.
local A = require("assert")
local F = require("fake_raw")
local research = require("prototypes.research")

local RED = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 10 }
local GREEN = { count = 100, ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }, time = 15 }

--- Strom: automation → fluid-handling (pumpa), steel-processing (ocel), niobium za fluid-handling.
local function tree()
  local raw = F.new()
  F.item(raw, "pump", "pump")
  F.recipe(raw, "pump", "pump", {}, { enabled = false })
  F.item(raw, "steel-plate")
  F.recipe(raw, "steel-plate", "steel-plate", {}, { enabled = false })
  F.tech(raw, "automation", {}, {}, RED)
  F.tech(raw, "steel-processing", { "steel-plate" }, {}, RED)
  F.tech(raw, "fluid-handling", { "pump" }, { "automation" }, GREEN)
  F.tech(raw, "niobium", {}, { "fluid-handling" }, { count = 300, ingredients = GREEN.ingredients, time = 30 })
  return raw
end

--- Seřazený seznam z pole.
local function joined(list) table.sort(list) return table.concat(list, ",") end

return {
  { "techs_for_items: pumpa a ocel", function()
    local set = research.techs_for_items(tree(), { "pump", "steel-plate", "neexistuje" })
    A.truthy(set["fluid-handling"] and set["steel-processing"], "oba výzkumy")
  end },
  { "technology: prerekvizity bez tranzitivně zbytečných", function()
    local tech = research.technology(tree(), { ["fluid-handling"] = true, automation = true, ["steel-processing"] = true }, "x")
    A.eq(joined(tech.prerequisites), "fluid-handling,steel-processing", "automation plyne z fluid-handling")
  end },
  { "technology: cena = nejvíc druhů vědy, počet × násobič", function()
    local tech = research.technology(tree(), { ["fluid-handling"] = true, ["steel-processing"] = true }, "x")
    A.eq(#tech.unit.ingredients, 2, "dva druhy vědy")
    A.eq(tech.unit.count, 150, "100 × 1.5")
  end },
  { "technology: vlastní výzkumy fb- se do ceny nepočítají", function()
    local raw = tree()
    F.tech(raw, "fb-fluid-bus", {}, { "fluid-handling" }, { count = 10000, ingredients = GREEN.ingredients, time = 30 })
    local tech = research.technology(raw, { ["fb-fluid-bus"] = true, niobium = true }, "x")
    A.eq(tech.unit.count, 450, "300 × 1.5, ne 10000")
  end },
  { "technology: nic potřeba → nil", function()
    A.eq(research.technology(tree(), {}, "x"), nil, "bez výzkumu")
  end },
  { "technology: prerekvizity bez vědy → spouštěč výrobou", function()
    local raw = tree()
    F.tech(raw, "trigger-only", {}, {}, nil)
    local tech = research.technology(raw, { ["trigger-only"] = true }, "fb-bus-pipe")
    A.eq(tech.research_trigger.item, "fb-bus-pipe", "spouštěč")
  end },
  { "trigger_item: první existující předmět, který výzkum sám neodemyká", function()
    local raw = tree()
    A.eq(research.trigger_item(raw, { "neexistuje", "pump", "steel-plate" }), "pump", "pumpa")
    A.eq(research.trigger_item(raw, { "neexistuje" }), nil, "nic")
  end },
  { "covered: výzkum v uzávěru základních prerekvizit", function()
    local raw = tree()
    A.truthy(research.covered(raw, { "fluid-handling" }, { automation = true }), "automation v uzávěru")
    A.truthy(research.covered(raw, { "fluid-handling" }, {}), "nic = pokryto")
    A.eq(research.covered(raw, { "fluid-handling" }, { niobium = true }), false, "niobium je později")
  end },
}
