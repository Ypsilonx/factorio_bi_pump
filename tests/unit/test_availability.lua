---@diagnostic disable: undefined-global
--- Testy dostupnosti předmětů (recepty, výzkumy, skryté prototypy).
local A = require("assert")
local F = require("fake_raw")
local av = require("prototypes.availability")

local SCIENCE = { count = 50, ingredients = { { "automation-science-pack", 1 } }, time = 10 }

return {
  { "předmět dostupný od začátku", function()
    local raw = F.new()
    F.item(raw, "pipe", "pipe")
    F.recipe(raw, "pipe", "pipe", { { "iron-plate", 1 } })
    local recipe, tech = av.item_source(raw, "pipe")
    A.eq(recipe, "pipe", "recept")
    A.eq(tech, nil, "výzkum")
  end },
  { "předmět za výzkumem", function()
    local raw = F.new()
    F.item(raw, "niobium-pipe", "niobium-pipe")
    F.recipe(raw, "niobium-pipe", "niobium-pipe", {}, { enabled = false })
    F.tech(raw, "niobium", { "niobium-pipe" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "niobium-pipe")
    A.eq(recipe, "niobium-pipe", "recept")
    A.eq(tech, "niobium", "výzkum")
  end },
  { "skrytý recept (recyklace) se ignoruje", function()
    local raw = F.new()
    F.item(raw, "x-pipe", "x-pipe")
    F.recipe(raw, "x-pipe", "x-pipe", {}, { enabled = false })
    F.recipe(raw, "x-pipe-recycling", "x-pipe", {}, { hidden = true })
    F.tech(raw, "x", { "x-pipe" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "x-pipe")
    A.eq(recipe, "x-pipe", "recept")
    A.eq(tech, "x", "výzkum")
  end },
  { "zamčený recept bez výzkumu = nedostupný", function()
    local raw = F.new()
    F.item(raw, "dead-pipe", "dead-pipe")
    F.recipe(raw, "dead-pipe", "dead-pipe", {}, { enabled = false })
    A.eq(av.item_source(raw, "dead-pipe"), nil, "recept")
  end },
  { "skrytý výzkum se nepočítá", function()
    local raw = F.new()
    F.item(raw, "p", "p")
    F.recipe(raw, "p", "p", {}, { enabled = false })
    F.tech(raw, "t", { "p" }, {}, SCIENCE).hidden = true
    A.eq(av.item_source(raw, "p"), nil, "recept")
  end },
  { "ze dvou výzkumů vyhraje ten s menším uzávěrem", function()
    local raw = F.new()
    F.item(raw, "p", "p")
    F.recipe(raw, "p-early", "p", {}, { enabled = false })
    F.recipe(raw, "p-late", "p", {}, { enabled = false })
    F.tech(raw, "a", {}, {}, SCIENCE)
    F.tech(raw, "b", {}, { "a" }, SCIENCE)
    F.tech(raw, "late", { "p-late" }, { "b" }, SCIENCE)
    F.tech(raw, "early", { "p-early" }, {}, SCIENCE)
    local recipe, tech = av.item_source(raw, "p")
    A.eq(recipe, "p-early", "recept")
    A.eq(tech, "early", "výzkum")
  end },
  { "tech_closure sbírá nepřímé prerekvizity", function()
    local raw = F.new()
    F.tech(raw, "a", {}, {}, SCIENCE)
    F.tech(raw, "b", {}, { "a" }, SCIENCE)
    F.tech(raw, "c", {}, { "b" }, SCIENCE)
    local set = av.tech_closure(raw, "c")
    A.truthy(set.a and set.b, "a i b v uzávěru")
    A.eq(set.c, nil, "výzkum sám v uzávěru není")
  end },
  { "is_hidden podle vlastnosti i flags", function()
    A.truthy(av.is_hidden({ hidden = true }), "hidden = true")
    A.truthy(av.is_hidden({ flags = { "placeable-neutral", "hidden" } }), "flags hidden")
    A.eq(av.is_hidden({ flags = { "placeable-neutral" } }), false, "běžný prototyp")
  end },
  { "find_place_item najde předmět podle place_result", function()
    local raw = F.new()
    F.item(raw, "pipe-item", "pipe")
    A.eq(av.find_place_item(raw, "pipe"), "pipe-item", "předmět")
    A.eq(av.find_place_item(raw, "nic"), nil, "neexistující entita")
  end },
}
