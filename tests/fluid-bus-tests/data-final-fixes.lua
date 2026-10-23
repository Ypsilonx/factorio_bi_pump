-- Testovací mod: zapíše finální extent BUS a původních trubek a značku „B“ v ikoně BUS entit do mod-data
-- (runtime ani jedno nevystavuje). Běží po fluid-bus i po modech, které trubky upravují (volitelné
-- závislosti v info.json).
local extents, marked = {}, {}
for _, name in ipairs(data.raw["mod-data"]["fb-data"].data.bus_pipes) do
  local source = name:sub(#"fb-bus-" + 1)
  for _, type_name in ipairs({ "pipe", "pipe-to-ground" }) do
    local bus, original = data.raw[type_name][name], data.raw[type_name][source]
    if bus and original then
      extents[name] = { bus = bus.fluid_box.max_pipeline_extent or 0, source = original.fluid_box.max_pipeline_extent or 0 }
    end
    if bus then
      marked[name] = false
      for _, layer in ipairs(bus.icons or {}) do
        if layer.icon:find("/icons/b.png", 1, true) then marked[name] = true end
      end
    end
  end
end
data:extend({
  { type = "mod-data", name = "fb-test-extents", data = extents },
  { type = "mod-data", name = "fb-test-icons", data = marked },
})
