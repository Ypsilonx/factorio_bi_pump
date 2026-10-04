---@diagnostic disable: undefined-global
--- Testy přidání nastříkaného „B“ do spritů trubek a ikon.
local A = require("assert")
local av = require("prototypes.availability")
local overlay = require("prototypes.bus_overlay")

--- Poslední vrstva spritu.
local function top(sprite) return sprite.layers[#sprite.layers] end

--- Posun overlaye pro tvar podle vygenerovaných dat (blender/marking.toml).
local function shift(key) return overlay.PLACEMENT[key].shift end

return {
  { "rovná vodorovná a svislá dostanou B ve správné orientaci a posunu", function()
    local pipe = { type = "pipe", pictures = {
      straight_horizontal = { filename = "h.png" }, straight_vertical = { filename = "v.png" } } }
    local missing = overlay.decorate(pipe, av.copy)
    local h, v = top(pipe.pictures.straight_horizontal), top(pipe.pictures.straight_vertical)
    A.eq(h.filename, overlay.GRAPHICS .. "entity/b-horizontal.png", "vodorovná")
    A.eq(v.filename, overlay.GRAPHICS .. "entity/b-vertical.png", "svislá")
    A.eq(h.shift[2], shift("straight_horizontal")[2], "posun vodorovné")
    A.eq(h.width, 64, "sprite 64 px = 1 dlaždice")
    A.eq(h.scale, 0.5, "scale")
    A.eq(pipe.pictures.straight_horizontal.layers[1].filename, "h.png", "původní vrstva první")
    A.eq(#missing, 0, "nic nechybí")
  end },
  { "okénko, roh, kříž a pozadí kapaliny zůstanou beze změny", function()
    local pipe = { type = "pipe", pictures = {
      straight_horizontal_window = { filename = "w.png" }, corner_up_right = { filename = "c.png" },
      cross = { filename = "x.png" }, fluid_background = { filename = "f.png" } } }
    overlay.decorate(pipe, av.copy)
    A.eq(pipe.pictures.straight_horizontal_window.filename, "w.png", "okénko")
    A.eq(pipe.pictures.corner_up_right.filename, "c.png", "roh")
    A.eq(pipe.pictures.cross.filename, "x.png", "kříž")
    A.eq(pipe.pictures.fluid_background.filename, "f.png", "pozadí")
  end },
  { "sprite s layers dostane overlay navrch", function()
    local pipe = { type = "pipe", pictures = { straight_vertical = { layers = { { filename = "a.png" }, { filename = "b.png" } } } } }
    overlay.decorate(pipe, av.copy)
    A.eq(#pipe.pictures.straight_vertical.layers, 3, "tři vrstvy")
    A.eq(top(pipe.pictures.straight_vertical).filename, overlay.GRAPHICS .. "entity/b-vertical.png", "overlay navrch")
  end },
  { "podzemní: sever/jih svislé B, východ/západ vodorovné", function()
    local ug = { type = "pipe-to-ground", pictures = { north = { filename = "n.png" }, south = { filename = "s.png" },
      east = { filename = "e.png" }, west = { filename = "w.png" } } }
    local missing = overlay.decorate(ug, av.copy)
    A.eq(top(ug.pictures.north).filename, overlay.GRAPHICS .. "entity/b-vertical.png", "north")
    A.eq(top(ug.pictures.south).filename, overlay.GRAPHICS .. "entity/b-vertical.png", "south")
    A.eq(top(ug.pictures.east).filename, overlay.GRAPHICS .. "entity/b-horizontal.png", "east")
    A.eq(top(ug.pictures.west).filename, overlay.GRAPHICS .. "entity/b-horizontal.png", "west")
    A.eq(top(ug.pictures.east).shift[1], shift("east")[1], "posun east")
    A.eq(#missing, 0, "nic nechybí")
  end },
  { "podzemní ve formě sheet se nezmění a nahlásí se", function()
    local ug = { type = "pipe-to-ground", pictures = { sheet = { filename = "all.png" } } }
    local missing = overlay.decorate(ug, av.copy)
    A.eq(ug.pictures.sheet.filename, "all.png", "beze změny")
    A.eq(missing[1], "sheet", "nahlášeno")
  end },
  { "ikona: původní icons + B; jediná icon převedena na vrstvu", function()
    local icons = overlay.icons({ icon = "pipe.png", icon_size = 64 }, av.copy)
    A.eq(#icons, 2, "dvě vrstvy")
    A.eq(icons[1].icon, "pipe.png", "původní")
    A.eq(icons[2].icon, overlay.GRAPHICS .. "icons/b.png", "overlay")
    local layered = overlay.icons({ icons = { { icon = "a.png" }, { icon = "b.png", tint = { 1, 0, 0 } } } }, av.copy)
    A.eq(#layered, 3, "dvě původní + overlay")
  end },
}
