-- Testovací mod: zapíše finální extent BUS a původních trubek do mod-data (runtime ho nevystavuje).
-- Běží po fluid-bus i po modech, které trubky upravují (volitelné závislosti v info.json).
local extents = {}
for _, name in ipairs(data.raw["mod-data"]["fb-data"].data.bus_pipes) do
  local source = name:sub(#"fb-bus-" + 1)
  for _, type_name in ipairs({ "pipe", "pipe-to-ground" }) do
    local bus, original = data.raw[type_name][name], data.raw[type_name][source]
    if bus and original then
      extents[name] = { bus = bus.fluid_box.max_pipeline_extent or 0, source = original.fluid_box.max_pipeline_extent or 0 }
    end
  end
end
data:extend({ { type = "mod-data", name = "fb-test-extents", data = extents } })
