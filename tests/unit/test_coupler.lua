---@diagnostic disable: undefined-global
--- Testy surovin receptu spojky (náhrady pro mody, které předměty odstraní).
local A = require("assert")
local F = require("fake_raw")
local coupler = require("prototypes.coupler")

return {
  { "suroviny: první existující kandidát, chybějící vynechány", function()
    local raw = F.new()
    F.item(raw, "pump")
    F.item(raw, "iron-plate")
    local list = coupler.ingredients(raw)
    local names = {}
    for _, i in ipairs(list) do names[#names + 1] = i.name .. "×" .. i.amount end
    A.eq(table.concat(names, ","), "pump×1,iron-plate×5", "pumpa a náhrada oceli, bez obvodů")
  end },
}
