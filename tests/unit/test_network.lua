---@diagnostic disable: undefined-global
--- Testy skládání sítí ze segmentů a spojek.
local A = require("assert")
local network = require("scripts.network")

--- Seznam čísel jako seřazený text (pořadí uvnitř sítě není specifikované).
local function list(t)
  local copy = { table.unpack(t) }
  table.sort(copy)
  return table.concat(copy, ",")
end

return {
  { "řetěz dvou spojek = jedna síť tří segmentů", function()
    local nets = network.build({ { id = 1, a = 10, b = 11, active = true }, { id = 2, a = 11, b = 12, active = true } })
    A.eq(#nets, 1, "sítě")
    A.eq(list(nets[1].segments), "10,11,12", "segmenty")
    A.eq(list(nets[1].couplers), "1,2", "spojky")
  end },
  { "neaktivní spojka síť rozdělí", function()
    local nets = network.build({ { id = 1, a = 10, b = 11, active = true }, { id = 2, a = 11, b = 12, active = false },
      { id = 3, a = 12, b = 13, active = true } })
    A.eq(#nets, 2, "dvě sítě")
    A.eq(list(nets[1].segments), "10,11", "první")
    A.eq(list(nets[2].segments), "12,13", "druhá")
  end },
  { "spojka bez trubky na jedné straně nebo se stejným segmentem se nepoužije", function()
    local nets = network.build({ { id = 1, a = nil, b = 11, active = true }, { id = 2, a = 5, b = 5, active = true } })
    A.eq(#nets, 0, "žádná síť")
  end },
  { "paralelní spojky mezi stejnými segmenty = jedna síť", function()
    local nets = network.build({ { id = 7, a = 20, b = 21, active = true }, { id = 3, a = 21, b = 20, active = true } })
    A.eq(#nets, 1, "jedna síť")
    A.eq(list(nets[1].couplers), "3,7", "obě spojky")
  end },
}
