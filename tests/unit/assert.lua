--- Pomocné aserce pro jednotkové testy mimo hru.
local A = {}

--- Selže, pokud se hodnoty nerovnají.
--- @param actual any
--- @param expected any
--- @param what string popis kontrolované hodnoty
function A.eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: čekáno %s, dostáno %s", what, tostring(expected), tostring(actual)), 2)
  end
end

--- Selže, pokud hodnota není pravdivá.
function A.truthy(value, what)
  if not value then error(what .. ": čekána pravdivá hodnota", 2) end
end

return A
