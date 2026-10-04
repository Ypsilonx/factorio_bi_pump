---@diagnostic disable: undefined-global
--- Rozměry PNG overlayů (headless hra sprity nenačítá, chybný rozměr by se projevil až ve hře).
local A = require("assert")

--- Přečte šířku a výšku PNG z hlavičky IHDR.
local function png_size(path)
  local file = assert(io.open(path, "rb"))
  local header = file:read(24)
  file:close()
  A.eq(header:sub(2, 4), "PNG", path .. " je PNG")
  return string.unpack(">I4I4", header, 17)
end

--- Test jednoho souboru.
local function size_case(path, expected)
  return { path .. " má " .. expected .. "×" .. expected, function()
    local w, h = png_size(path)
    A.eq(w, expected, "šířka")
    A.eq(h, expected, "výška")
  end }
end

return {
  size_case("fluid-bus/graphics/entity/b-horizontal.png", 64),
  size_case("fluid-bus/graphics/entity/b-vertical.png", 64),
  size_case("fluid-bus/graphics/icons/b.png", 64),
}
