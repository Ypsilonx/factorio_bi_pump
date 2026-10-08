--- Pravá část okna spojky „Připojení obvodu“ (jako u inserteru): čísla sítí připojených drátem hráče,
--- Povolit/Zakázat s podmínkou [signál] [porovnání] [číslo] a popis vysílaného signálu.
--- Podmínku drží engine v control behavior spojky (přenáší ji v blueprintech, kopírování a sám ji
--- vyhodnocuje – topology.refresh čte `disabled`), okno ji jen čte a zapisuje.
local M = {}

local RED = defines.wire_connector_id.circuit_red
local GREEN = defines.wire_connector_id.circuit_green

--- Porovnání v pořadí rozbalovacího seznamu (stejné jako v nativním okně).
M.COMPARATORS = { ">", "<", "=", "≥", "≤", "≠" }
--- Zápisy porovnání, které engine také přijímá, převedené na tvar ze seznamu.
local COMPARATOR_ALIASES = { [">="] = "≥", ["<="] = "≤", ["!="] = "≠" }

--- Postaví část do rodiče.
--- @param parent LuaGuiElement
--- @return LuaGuiElement rámeček části
function M.build(parent)
  local frame = parent.add({ type = "frame", name = "fb_circuit", direction = "vertical",
                             style = "inside_shallow_frame_with_padding" })
  frame.add({ type = "label", caption = { "fb-gui.circuit-title" }, style = "caption_label" })
  frame.add({ type = "label", name = "fb_connected" })
  frame.add({ type = "line", direction = "horizontal" })
  frame.add({ type = "checkbox", name = "fb_enable", state = false, caption = { "fb-gui.enable" },
              tooltip = { "fb-gui.enable-tooltip" }, tags = { fb = "enable" } })
  local row = frame.add({ type = "flow", name = "fb_condition", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.style.left_margin = 24
  row.add({ type = "choose-elem-button", name = "fb_first", elem_type = "signal", style = "slot_button_in_shallow_frame",
            tags = { fb = "condition" } })
  row.add({ type = "drop-down", name = "fb_comparator", items = M.COMPARATORS, selected_index = 2,
            style = "circuit_condition_comparator_dropdown", tags = { fb = "condition" } })
  local constant = row.add({ type = "textfield", name = "fb_constant", numeric = true, allow_decimal = false,
                             allow_negative = true, tags = { fb = "condition" } })
  constant.style.width = 60
  constant.style.horizontal_align = "center"
  frame.add({ type = "line", direction = "horizontal" })
  frame.add({ type = "label", caption = { "fb-gui.output" } })
  return frame
end

--- Index porovnání v seznamu (neznámé = „<“, výchozí podmínka enginu).
--- @param comparator string|nil
--- @return integer
local function comparator_index(comparator)
  comparator = COMPARATOR_ALIASES[comparator] or comparator
  for index, value in ipairs(M.COMPARATORS) do
    if value == comparator then return index end
  end
  return 2
end

--- Naplní část z control behavior spojky (při otevření okna).
--- @param frame LuaGuiElement rámeček části
--- @param coupler table záznam ze storage.couplers
function M.fill(frame, coupler)
  local behavior = coupler.entity.get_control_behavior()
  local condition = behavior and behavior.circuit_condition or {}
  frame.fb_enable.state = behavior and behavior.circuit_enable_disable or false
  frame.fb_condition.fb_first.elem_value = condition.first_signal
  frame.fb_condition.fb_comparator.selected_index = comparator_index(condition.comparator)
  frame.fb_condition.fb_constant.text = tostring(condition.constant or 0)
end

--- Čísla sítí připojených drátem hráče jako rich text (skrytý drát spojky k vlastnímu kombinátoru se
--- nepočítá – jinak by spojka byla „připojená“ vždy).
--- @param entity LuaEntity spojka
--- @return string|nil nil = žádný drát hráče
function M.network_ids(entity)
  local parts = {}
  for _, wire in ipairs({ { RED, "red" }, { GREEN, "green" } }) do
    local connector = entity.get_wire_connector(wire[1], false)
    local wired = false
    for _, connection in ipairs(connector and connector.connections or {}) do
      if connection.origin == defines.wire_origin.player then wired = true end
    end
    local network = wired and entity.get_circuit_network(wire[1])
    if network then parts[#parts + 1] = "[color=" .. wire[2] .. "]" .. network.network_id .. "[/color]" end
  end
  return #parts > 0 and table.concat(parts, " ") or nil
end

--- Obnoví připojení a povolení prvků podmínky.
--- @param frame LuaGuiElement rámeček části
--- @param coupler table záznam ze storage.couplers
function M.refresh(frame, coupler)
  local ids = M.network_ids(coupler.entity)
  frame.fb_connected.caption = ids and { "fb-gui.connected", ids } or { "fb-gui.not-wired" }
  local enabled = frame.fb_enable.state
  for _, name in ipairs({ "fb_first", "fb_comparator", "fb_constant" }) do frame.fb_condition[name].enabled = enabled end
end

--- Obsluha událostí podle tagu `fb`; zapisuje do control behavior spojky.
M.handlers = {
  enable = function(event, coupler)
    coupler.entity.get_or_create_control_behavior().circuit_enable_disable = event.element.state
  end,
  condition = function(event, coupler)
    local row = event.element.parent
    coupler.entity.get_or_create_control_behavior().circuit_condition = {
      first_signal = row.fb_first.elem_value,
      comparator = M.COMPARATORS[row.fb_comparator.selected_index] or "<",
      constant = tonumber(row.fb_constant.text) or 0,
    }
  end,
}

return M
