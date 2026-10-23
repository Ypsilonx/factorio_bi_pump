---@diagnostic disable: lowercase-global
--- Test okna spojky bez hry: herní GUI prvky (LuaGuiElement) nahrazuje jednoduchá napodobenina, takže se
--- ověří, že scripts/gui.lua a části v scripts/gui/ okno staví, plní, obnovují, obsluhují události a zapisují
--- podmínku do spojky. (Headless Factorio nemá hráče, okno se v integračních testech nevytvoří.)
local A = require("assert")

--- Vlastnosti stylu, které hra dovolí jen u flow a table.
local SPACING = { vertical_spacing = true, horizontal_spacing = true }

--- Napodobenina LuaGuiElement: děti dostupné podle jména, add/destroy/get_mod, tags, style a běžné vlastnosti.
local function element(spec, parent)
  local e = {}
  for key, value in pairs(spec) do e[key] = value end
  e.parent, e.enabled, e.valid = parent, true, true
  if e.visible == nil then e.visible = true end
  e.text, e.children, e.tags = spec.text or "", {}, spec.tags or {}
  -- Mezery mezi dětmi umí jen flow a table (hra jinak spadne: „Expected Table or Flow … but was Frame“).
  e.style = setmetatable({}, { __newindex = function(style, key, value)
    if SPACING[key] then
      assert(e.type == "flow" or e.type == "table", key .. " na prvku typu " .. tostring(e.type))
    end
    rawset(style, key, value)
  end })
  function e.add(child_spec)
    local child = element(child_spec, e)
    e.children[#e.children + 1] = child
    if child_spec.name then
      assert(not e[child_spec.name], "duplicitní jméno prvku " .. child_spec.name)
      e[child_spec.name] = child
    end
    return child
  end
  function e.destroy()
    e.valid = false
    if parent and e.name then parent[e.name] = nil end
  end
  function e.get_mod() return "fluid-bus" end
  return e
end

prototypes = { mod_data = { ["fb-data"] = { data = {
  coupler = "fb-bus-coupler", interval_signal = "fb-balance-interval",
} } } }
defines = {
  wire_connector_id = { circuit_red = 1, circuit_green = 2 },
  wire_origin = { player = 0, script = 2 },
  controllers = { character = 1, god = 0 },
}
script = { mod_name = "fluid-bus" }

local behavior = { circuit_enable_disable = true,
  circuit_condition = { first_signal = { type = "fluid", name = "water" }, comparator = ">", constant = 50 } }
--- Drát hráče jen na červeném konektoru, zelený má jen skrytý drát skriptu.
local connectors = {
  [1] = { connections = { { origin = 0 } } },
  [2] = { connections = { { origin = 2 } } },
}
local entity = {
  name = "fb-bus-coupler", valid = true, unit_number = 7, localised_name = "Bus coupler",
  energy = 50, electric_buffer_size = 100, custom_status = { label = { "fb-status.disabled" } },
  get_control_behavior = function() return behavior end,
  get_or_create_control_behavior = function() return behavior end,
  get_wire_connector = function(id) return connectors[id] end,
  get_circuit_network = function(id) return { network_id = id == 1 and 11 or 22 } end,
}
--- Strana s BUS trubkou: segment 5 (v žádné síti) – naplnění se čte z trubky.
local rep = {
  valid = true,
  get_fluid_segment_fluid = function() return { name = "water", amount = 300, temperature = 15 } end,
  get_fluid_segment_capacity = function() return 1000 end,
}
local coupler = { entity = entity, sides = { { seg = 5, rep = rep }, {} }, state = "disabled" }
storage = { couplers = { [7] = coupler }, networks = {}, coupler_net = {}, segment_net = {} }

local player = {
  index = 1, controller_type = 1, gui = { screen = element({ type = "root" }) },
  can_reach_entity = function() return true end,
}
game = { players = { player }, get_player = function() return player end }

local gui = require("scripts.gui")

--- Otevře okno jako událost on_gui_opened a vrátí jeho tělo.
local function open()
  gui.on_opened({ entity = entity, player_index = 1 })
  return player.gui.screen.fb_window.fb_body
end

return {
  { "okno: přehled i panel obvodu, náhled a podmínka ze spojky", function()
    local body = open()
    A.eq(player.opened, player.gui.screen.fb_window, "okno nahradí nativní")
    A.eq(body.fb_overview.fb_preview_frame.fb_preview.entity, entity, "náhled")
    A.eq(body.fb_circuit.visible, true, "panel obvodu výchozí zobrazený")
    A.eq(body.fb_circuit.fb_enable.state, true, "Povolit/Zakázat")
    local row = body.fb_circuit.fb_condition
    A.eq(row.fb_first.elem_value.name, "water", "signál")
    A.eq(row.fb_comparator.selected_index, 1, "porovnání >")
    A.eq(row.fb_constant.text, "50", "číslo")
    A.eq(storage.gui_target[1], 7, "cíl okna")
  end },
  { "přehled mimo síť: stav ze spojky a naplnění stran", function()
    local overview = open().fb_overview
    A.eq(overview.fb_status_row.fb_status_icon.sprite, "utility/status_yellow", "žlutá tečka")
    A.eq(overview.fb_status_row.fb_status.caption[1], "fb-status.disabled", "popisek stavu")
    A.eq(overview.fb_network.visible, false, "bez sítě")
    A.eq(overview.fb_sides.visible, true, "strany")
    A.eq(overview.fb_sides.caption[2], "[fluid=water] ", "ikona kapaliny")
    A.eq(overview.fb_sides.caption[3][2], "30", "naplnění strany")
    A.eq(overview.fb_sides.caption[3][3], "–", "strana bez trubky")
    A.eq(overview.fb_energy.fb_bar.value, 0.5, "elektřina")
  end },
  { "přehled v síti: segmenty, naplnění a množství", function()
    storage.networks[1] = { segments = { 5, 6, 8 }, fluid = "water", fraction = 0.426, total_amount = 1278.9 }
    storage.coupler_net[7] = 1
    local overview = open().fb_overview
    A.eq(overview.fb_network.caption[2], 3, "segmenty")
    A.eq(overview.fb_fill.caption[3][2], "43", "naplnění %")
    A.eq(overview.fb_amount.caption[2], "1278", "množství")
    A.eq(overview.fb_sides.visible, false, "strany skryté")
    storage.networks[1], storage.coupler_net[7] = nil, nil
  end },
  { "připojeno k: jen sítě s drátem hráče", function()
    local circuit = open().fb_circuit
    A.eq(circuit.fb_connected.caption[2], "[color=red]11[/color]", "jen červená (zelená má jen skrytý drát)")
  end },
  { "změna podmínky a Povolit/Zakázat se zapíše do spojky", function()
    local circuit = open().fb_circuit
    local row = circuit.fb_condition
    row.fb_comparator.selected_index = 2
    row.fb_constant.text = "30"
    gui.on_changed({ element = row.fb_constant, player_index = 1 })
    A.eq(behavior.circuit_condition.comparator, "<", "porovnání")
    A.eq(behavior.circuit_condition.constant, 30, "číslo")
    A.eq(behavior.circuit_condition.first_signal.name, "water", "signál zůstal")
    circuit.fb_enable.state = false
    gui.on_changed({ element = circuit.fb_enable, player_index = 1 })
    A.eq(behavior.circuit_enable_disable, false, "zakázáno")
    A.eq(row.fb_constant.enabled, false, "podmínka bez Povolit/Zakázat neupravitelná")
  end },
  { "přepínač panelu obvodu skryje panel a hráč si to pamatuje", function()
    local body = open()
    gui.on_click({ element = player.gui.screen.fb_window.fb_titlebar.fb_circuit_toggle, player_index = 1 })
    A.eq(body.fb_circuit.visible, false, "skrytý")
    A.eq(open().fb_circuit.visible, false, "skrytý i po znovuotevření")
    gui.on_click({ element = player.gui.screen.fb_window.fb_titlebar.fb_circuit_toggle, player_index = 1 })
    A.eq(player.gui.screen.fb_window.fb_body.fb_circuit.visible, true, "znovu zobrazený")
  end },
  { "zavření okna (E/Esc) ho zruší a zapamatuje polohu; zmizelá spojka okno zavře", function()
    open()
    local frame = player.gui.screen.fb_window
    frame.location = { x = 10, y = 20 }
    gui.on_closed({ element = frame, player_index = 1 })
    A.eq(player.gui.screen.fb_window, nil, "zavřeno")
    A.eq(storage.gui_location[1].x, 10, "poloha")
    A.eq(storage.gui_target[1], nil, "bez cíle")
    open()
    entity.valid = false
    gui.refresh()
    A.eq(player.gui.screen.fb_window, nil, "zavřeno po zmizení spojky")
    entity.valid = true
  end },
}
