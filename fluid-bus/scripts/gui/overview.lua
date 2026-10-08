--- Levá část okna spojky (jako nativní okno inserteru): stav s barevnou tečkou, živý náhled spojky,
--- údaje o síti (počet segmentů, naplnění, množství), u spojky mimo síť naplnění obou stran, pruh elektřiny.
local topology = require("scripts.topology")

local M = {}

--- Šířka náhledu spojky v pixelech. Laditelná hodnota.
M.PREVIEW_WIDTH = 320
--- Výška náhledu spojky v pixelech. Laditelná hodnota.
M.PREVIEW_HEIGHT = 148

--- Tečka stavu podle coupler.state (stejné sprity jako nativní okna).
local STATUS_SPRITES = {
  ok = "utility/status_working",
  disabled = "utility/status_yellow",
  ["not-connected"] = "utility/status_yellow",
}

--- Postaví část do rodiče.
--- @param parent LuaGuiElement
--- @return LuaGuiElement rámeček části
function M.build(parent)
  local frame = parent.add({ type = "frame", name = "fb_overview", direction = "vertical",
                             style = "inside_shallow_frame_with_padding" })
  local status = frame.add({ type = "flow", name = "fb_status_row", direction = "horizontal" })
  status.style.vertical_align = "center"
  status.add({ type = "sprite", name = "fb_status_icon", style = "status_image" })
  status.add({ type = "label", name = "fb_status" })

  local preview_frame = frame.add({ type = "frame", name = "fb_preview_frame", style = "deep_frame_in_shallow_frame" })
  local preview = preview_frame.add({ type = "entity-preview", name = "fb_preview" })
  preview.style.width = M.PREVIEW_WIDTH
  preview.style.height = M.PREVIEW_HEIGHT

  frame.add({ type = "label", name = "fb_network" })
  frame.add({ type = "label", name = "fb_fill" })
  frame.add({ type = "label", name = "fb_amount" })
  frame.add({ type = "label", name = "fb_sides" })
  local energy = frame.add({ type = "flow", name = "fb_energy", direction = "horizontal" })
  energy.style.vertical_align = "center"
  energy.add({ type = "label", caption = { "fb-gui.energy" } })
  local bar = energy.add({ type = "progressbar", name = "fb_bar", value = 0 })
  bar.style.horizontally_stretchable = true
  return frame
end

--- Napojí náhled na spojku.
--- @param frame LuaGuiElement rámeček části
--- @param coupler table záznam ze storage.couplers
function M.fill(frame, coupler)
  frame.fb_preview_frame.fb_preview.entity = coupler.entity
end

--- Popisek s ikonou kapaliny (rich text) před textem.
--- @param fluid string|nil
--- @param text LocalisedString
--- @return LocalisedString
local function with_icon(fluid, text)
  return fluid and { "", "[fluid=" .. fluid .. "] ", text } or text
end

--- Procenta z podílu jako text (nil = „–“).
--- @param fraction number|nil
--- @return string
local function percent(fraction)
  return fraction and tostring(math.floor(fraction * 100 + 0.5)) or "–"
end

--- Obnoví stav, údaje o síti a elektřinu.
--- @param frame LuaGuiElement rámeček části
--- @param coupler table záznam ze storage.couplers
--- @param unit integer unit_number spojky
function M.refresh(frame, coupler, unit)
  local entity = coupler.entity
  local state = coupler.state or "not-connected"
  frame.fb_status_row.fb_status_icon.sprite = STATUS_SPRITES[state] or "utility/status_not_working"
  frame.fb_status_row.fb_status.caption = entity.custom_status and entity.custom_status.label
    or { "fb-status." .. state }

  local net = topology.network_of(unit)
  local in_network = net ~= nil and not net.conflict
  frame.fb_network.visible = in_network
  frame.fb_fill.visible = in_network
  frame.fb_amount.visible = in_network
  frame.fb_sides.visible = not in_network
  if in_network then
    frame.fb_network.caption = { "fb-gui.network", #net.segments }
    frame.fb_fill.caption = with_icon(net.fluid, { "fb-gui.fill", percent(net.fraction) })
    frame.fb_amount.caption = { "fb-gui.amount", tostring(math.floor(net.total_amount)) }
  else
    local a, fluid_a = topology.side_fill(coupler.sides[1])
    local b, fluid_b = topology.side_fill(coupler.sides[2])
    frame.fb_sides.caption = with_icon(fluid_a or fluid_b, { "fb-gui.sides", percent(a), percent(b) })
  end

  local buffer = entity.electric_buffer_size
  frame.fb_energy.fb_bar.value = (buffer and buffer > 0) and math.min(entity.energy / buffer, 1) or 0
end

return M
