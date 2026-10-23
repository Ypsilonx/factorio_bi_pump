--- Tipy a triky (nativní okno nápovědy). Texty jsou v locale.
--- Bez `trigger`: `starting_status` je ukáže od začátku hry (výchozí „locked“ by je skryl).
--- Texty nepoužívají ikony BUS trubek ([entity=…]) – jejich jména se generují podle trubek ve hře
--- a s jinými mody by se ikona nemusela najít. Spojka a signál intervalu existují vždy.
data:extend({
  { type = "tips-and-tricks-item-category", name = "fluid-bus", order = "z-[fluid-bus]" },
  { type = "tips-and-tricks-item", name = "fluid-bus", category = "fluid-bus", order = "a",
    is_title = true, starting_status = "suggested" },
  { type = "tips-and-tricks-item", name = "fb-bus-pipes", category = "fluid-bus",
    order = "b", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "fb-coupler", category = "fluid-bus",
    order = "c", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "fb-status", category = "fluid-bus",
    order = "d", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "fb-circuit", category = "fluid-bus",
    order = "e", indent = 1, starting_status = "unlocked" },
  { type = "tips-and-tricks-item", name = "fb-interval", category = "fluid-bus",
    order = "f", indent = 1, starting_status = "unlocked" },
})
