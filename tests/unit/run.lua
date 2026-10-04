---@diagnostic disable: undefined-global
--- Runner jednotkových testů čisté Lua logiky modu (spouští se z kořene repozitáře: lua tests/unit/run.lua).
package.path = "fluid-bus/?.lua;tests/unit/?.lua;" .. package.path

--- Seznam testovacích sad; každá vrací pole { "název", funkce }.
local SUITES = { "test_locale", "test_availability", "test_bus_pipes", "test_bus_overlay", "test_graphics", "test_research" }

local pass, fail = 0, 0
for _, suite in ipairs(SUITES) do
  for _, case in ipairs(require(suite)) do
    local ok, err = pcall(case[2])
    if ok then
      pass = pass + 1
    else
      fail = fail + 1
      print("FAIL " .. suite .. " :: " .. case[1] .. ": " .. tostring(err))
    end
  end
end
print(string.format("UNIT pass=%d fail=%d", pass, fail))
os.exit(fail == 0 and 0 or 1)
