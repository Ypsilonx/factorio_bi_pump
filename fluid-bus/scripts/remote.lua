--- Remote rozhraní „fb“ pro testy a jiné mody.
local registry = require("scripts.registry")
local topology = require("scripts.topology")

local M = {}

--- Zaregistruje rozhraní (volá control.lua při načtení).
function M.register()
  remote.add_interface("fb", {
    --- Souhrn sítě, ve které je spojka; nil = spojka v žádné síti není.
    network_of = function(unit)
      local net = topology.network_of(unit)
      if not net then return nil end
      return { fill = net.fraction, amount = net.total_amount + net.buffer.amount, fluid = net.fluid,
        segments = #net.segments, buffer = net.buffer.amount, conflict = net.conflict }
    end,
    --- Diagnostika: počet přestaveb sítí od začátku hry.
    stats = function() return { rebuilds = storage.rebuilds or 0 } end,
    --- Vynutí přestavbu sítí v příštím ticku.
    rebuild = function() storage.dirty = true end,
    --- Úklid evidence a obnova skrytých kombinátorů (jako po změně modů).
    revalidate = function() registry.revalidate() end,
  })
end

return M
