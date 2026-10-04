---@diagnostic disable: undefined-global
--- Testy surovin receptu spojky (náhrady pro mody, které předměty odstraní).
local A = require("assert")
local F = require("fake_raw")
local coupler = require("prototypes.coupler")

--- Suroviny jako text „jméno×počet,…“.
local function joined(list)
  local names = {}
  for _, i in ipairs(list) do names[#names + 1] = i.name .. "×" .. i.amount end
  return table.concat(names, ",")
end

return {
  { "suroviny: pumpa, obvody, pokročilé obvody a trubky", function()
    local raw = F.new()
    for _, name in ipairs({ "pump", "electronic-circuit", "advanced-circuit", "pipe", "iron-plate" }) do
      F.item(raw, name)
    end
    A.eq(joined(coupler.ingredients(raw)), "pump×1,electronic-circuit×5,advanced-circuit×2,pipe×5", "vanilla")
  end },
  { "suroviny: první existující kandidát, chybějící vynechány", function()
    local raw = F.new()
    F.item(raw, "pump")
    F.item(raw, "iron-plate")
    A.eq(joined(coupler.ingredients(raw)), "pump×1,iron-plate×5", "pumpa a náhrada trubky, bez obvodů")
  end },
  { "výzkum spojky čeká na výzkumy všech jejích surovin", function()
    A.eq(table.concat(coupler.ingredient_names(
      { item = { pump = {}, ["advanced-circuit"] = {}, pipe = {} } }), ","), "pump,advanced-circuit,pipe", "jména")
  end },
}
