--- Vlastní okno spojky místo nativního okna montážního stroje (to ukazuje volby, které spojka nepoužívá:
--- recept, čtení obsahu, čtení stavu práce – a hra je skrýt nedovolí). Rozvržení jako u inserteru:
--- vlevo přehled (scripts/gui/overview.lua), vpravo „Připojení obvodu“ (scripts/gui/circuit.lua), který se
--- přepíná tlačítkem v titulku. Podmínka zůstává v control behavior entity, okno ji jen čte a zapisuje.
--- Dokud je okno otevřené, obnovuje se stav, údaje o síti a připojení drátů.
local overview = require("scripts.gui.overview")
local circuit = require("scripts.gui.circuit")
local registry = require("scripts.registry")

local M = {}

local WINDOW = "fb_window"

--- Jak často se otevřená okna obnovují (ticky). Laditelná hodnota.
M.REFRESH_TICKS = 15

--- Otevřené okno hráče (nebo nil).
--- @param player LuaPlayer
--- @return LuaGuiElement|nil
local function window(player)
  local frame = player.gui.screen[WINDOW]
  return (frame and frame.valid) and frame or nil
end

--- Je panel „Připojení obvodu“ u hráče zobrazený? (Výchozí ano, hráč si ho přepíná.)
--- @param player_index integer
--- @return boolean
local function circuit_shown(player_index)
  return not (storage.gui_circuit_hidden and storage.gui_circuit_hidden[player_index])
end

--- Přidá titulek okna: název spojky, plocha pro přetažení, přepínač panelu obvodu a křížek.
--- @param frame LuaGuiElement
--- @param caption LocalisedString
--- @param shown boolean je panel obvodu zobrazený
local function add_titlebar(frame, caption, shown)
  local bar = frame.add({ type = "flow", name = "fb_titlebar", direction = "horizontal" })
  bar.drag_target = frame
  bar.style.horizontal_spacing = 8
  bar.add({ type = "label", caption = caption, style = "frame_title", ignored_by_interaction = true })
  local drag = bar.add({ type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true })
  drag.style.height = 24
  drag.style.horizontally_stretchable = true
  bar.add({ type = "sprite-button", name = "fb_circuit_toggle", sprite = "utility/circuit_network_panel",
            style = "frame_action_button", tooltip = { "fb-gui.circuit-tooltip" }, toggled = shown,
            tags = { fb = "toggle_circuit" } })
  bar.add({ type = "sprite-button", name = "fb_close", sprite = "utility/close", style = "frame_action_button",
            tags = { fb = "close" } })
end

--- Spojka, jejíž okno má hráč otevřené (nebo nil).
--- @param player_index integer
--- @return table|nil coupler, integer|nil unit
local function opened_coupler(player_index)
  local unit = storage.gui_target and storage.gui_target[player_index]
  local coupler = unit and storage.couplers[unit]
  if coupler and coupler.entity.valid then return coupler, unit end
end

--- Obnoví proměnlivé části okna.
--- @param frame LuaGuiElement
--- @param coupler table
--- @param unit integer
local function refresh_window(frame, coupler, unit)
  local body = frame.fb_body
  overview.refresh(body.fb_overview, coupler, unit)
  if body.fb_circuit.visible then circuit.refresh(body.fb_circuit, coupler) end
end

--- Zavře okno hráče a zapamatuje si jeho polohu.
--- @param player LuaPlayer
function M.close(player)
  local frame = window(player)
  if frame then
    storage.gui_location = storage.gui_location or {}
    storage.gui_location[player.index] = frame.location
    frame.destroy()
  end
  if storage.gui_target then storage.gui_target[player.index] = nil end
end

--- Otevře okno spojky (nahradí nativní okno entity).
--- @param player LuaPlayer
--- @param coupler table záznam ze storage.couplers
--- @param unit integer unit_number spojky
function M.open(player, coupler, unit)
  M.close(player)
  local shown = circuit_shown(player.index)
  local frame = player.gui.screen.add({ type = "frame", name = WINDOW, direction = "vertical" })
  add_titlebar(frame, coupler.entity.localised_name, shown)
  local body = frame.add({ type = "flow", name = "fb_body", direction = "horizontal" })
  body.style.horizontal_spacing = 12
  overview.fill(overview.build(body), coupler)
  local circuit_frame = circuit.build(body)
  circuit.fill(circuit_frame, coupler)
  circuit_frame.visible = shown
  refresh_window(frame, coupler, unit)

  local location = storage.gui_location and storage.gui_location[player.index]
  if location then frame.location = location else frame.auto_center = true end
  -- Přiřazení zavře nativní okno entity; E/Esc pak zavírá naše okno (on_gui_closed).
  player.opened = frame
  storage.gui_target = storage.gui_target or {}
  storage.gui_target[player.index] = unit
end

--- Otevření okna entity: u spojky místo nativního okna otevře vlastní.
--- @param event EventData.on_gui_opened
function M.on_opened(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == registry.COUPLER) then return end
  local coupler = storage.couplers[entity.unit_number]
  if coupler then M.open(game.get_player(event.player_index), coupler, entity.unit_number) end
end

--- Zavření (E, Esc, otevření jiného okna): u našeho okna ho zruší.
--- @param event EventData.on_gui_closed
function M.on_closed(event)
  local element = event.element
  if element and element.valid and element.name == WINDOW and element.get_mod() == script.mod_name then
    M.close(game.get_player(event.player_index))
  end
end

--- Prvek tohoto modu s akcí (tag `fb`), nebo nil.
--- @param element LuaGuiElement|nil
--- @return string|nil
local function action_of(element)
  if not (element and element.valid and element.get_mod() == script.mod_name) then return nil end
  return element.tags.fb
end

--- Klik: křížek a přepínač panelu obvodu (ostatní prvky reagují na své vlastní události).
--- @param event EventData.on_gui_click
function M.on_click(event)
  local action = action_of(event.element)
  local player = game.get_player(event.player_index)
  if action == "close" then
    M.close(player)
  elseif action == "toggle_circuit" then
    local shown = not circuit_shown(player.index)
    storage.gui_circuit_hidden = storage.gui_circuit_hidden or {}
    storage.gui_circuit_hidden[player.index] = not shown or nil
    event.element.toggled = shown
    local frame = window(player)
    local coupler, unit = opened_coupler(player.index)
    if frame and coupler then
      frame.fb_body.fb_circuit.visible = shown
      refresh_window(frame, coupler, unit)
    end
  end
end

--- Změna prvku okna (zaškrtnutí, signál, výběr, číslo): uloží nastavení do spojky a obnoví okno.
--- @param event EventData
function M.on_changed(event)
  local handler = circuit.handlers[action_of(event.element)]
  if not handler then return end
  local player = game.get_player(event.player_index)
  local coupler, unit = opened_coupler(event.player_index)
  if not coupler then
    M.close(player)
    return
  end
  handler(event, coupler)
  local frame = window(player)
  if frame then refresh_window(frame, coupler, unit) end
end

--- Periodické obnovení otevřených oken; zavře okna, jejichž spojka zmizela nebo je mimo dosah hráče.
function M.refresh()
  if not (storage.gui_target and next(storage.gui_target)) then return end
  for player_index in pairs(storage.gui_target) do
    local player = game.get_player(player_index)
    local coupler, unit = opened_coupler(player_index)
    local frame = player and window(player)
    local reachable = coupler and (player.controller_type ~= defines.controllers.character
      or player.can_reach_entity(coupler.entity))
    if frame and reachable then
      refresh_window(frame, coupler, unit)
    elseif player then
      M.close(player)
    else
      storage.gui_target[player_index] = nil
    end
  end
end

--- Po změně konfigurace zavře okna (struktura se mohla změnit).
function M.reset_all()
  for _, player in pairs(game.players) do M.close(player) end
end

return M
