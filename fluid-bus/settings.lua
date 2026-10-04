-- Nastavení modu: odběr spojky mění prototyp (startup), interval vyrovnávání jde měnit za běhu (mapa).
data:extend({
  { type = "double-setting", name = "fb-coupler-power", setting_type = "startup",
    default_value = 50, minimum_value = 1, maximum_value = 10000, order = "a" },
  { type = "int-setting", name = "fb-balance-interval", setting_type = "runtime-global",
    default_value = 5, minimum_value = 1, maximum_value = 600, order = "b" },
})
