-- Startup nastavení modu (mění prototypy, proto startup).
data:extend({
  { type = "double-setting", name = "fb-coupler-power", setting_type = "startup",
    default_value = 50, minimum_value = 1, maximum_value = 10000, order = "a" },
  { type = "int-setting", name = "fb-balance-interval", setting_type = "startup",
    default_value = 60, minimum_value = 10, maximum_value = 3600, order = "b" },
})
