--- Označení BUS trubek: k obrázkům trubky přidá vrstvu s nastříkaným „B“ (rovné kusy bez okénka
--- a podzemní trubky) a „B“ do ikony, aby šla BUS trubka odlišit od běžné.
--- Sprite „B“ vyrábí blender/marking.py; umístění je v blender/marking.toml (vygenerované do
--- prototypes/bus_marking_data.lua). Bez globálů Factoria, testy: tests/unit/test_bus_overlay.lua.
local M = {}

--- Cesta ke grafice modu.
M.GRAPHICS = "__fluid-bus__/graphics/"

--- Tvar trubky (klíč PipePictures / Sprite4Way podzemní) → { shift, orientation }.
--- Klíče, které tu nejsou (okénka, rohy, T, kříž, konce, vizualizace), zůstanou beze změny.
M.PLACEMENT = require("prototypes.bus_marking_data")

--- Sprite nastříkaného „B“ pro daný tvar (64 px při scale 0.5 = 1 dlaždice).
--- @param key string klíč tvaru z M.PLACEMENT
--- @return table Sprite
local function marking_sprite(key)
  local place = M.PLACEMENT[key]
  return {
    filename = M.GRAPHICS .. "entity/b-" .. place.orientation .. ".png",
    priority = "extra-high",
    width = 64,
    height = 64,
    scale = 0.5,
    shift = { place.shift[1], place.shift[2] },
  }
end

--- Přidá „B“ do `pictures` BUS entity (trubky i podzemní).
--- @param new table BUS prototyp (už kopie, mění se na místě)
--- @param copy fun(t: table): table hloubková kopie
--- @return string[] klíče, které nešlo označit (např. podzemní jako `sheet`) – pro log
function M.decorate(new, copy)
  local missing = {}
  local pictures = new.pictures or {}
  for key, sprite in pairs(pictures) do
    if M.PLACEMENT[key] then
      if sprite.layers then
        local layered = copy(sprite)
        layered.layers[#layered.layers + 1] = marking_sprite(key)
        pictures[key] = layered
      else
        pictures[key] = { layers = { copy(sprite), marking_sprite(key) } }
      end
    elseif key == "sheet" or key == "sheets" then
      missing[#missing + 1] = key
    end
  end
  table.sort(missing)
  return missing
end

--- Vrstvy ikony BUS předmětu: původní ikona(y) + „B“.
--- @param source table původní předmět (icon/icon_size nebo icons)
--- @param copy fun(t: table): table
--- @return table[]
function M.icons(source, copy)
  local layers
  if source.icons then
    layers = copy(source.icons)
  else
    layers = { { icon = source.icon, icon_size = source.icon_size or 64 } }
  end
  layers[#layers + 1] = { icon = M.GRAPHICS .. "icons/b.png", icon_size = 64 }
  return layers
end

return M
