--- Stav spojek pro hru a GUI: custom_status a coupler.state – síť a naplnění / bez proudu / vypnuto
--- obvodem / nepřipojeno / různé kapaliny. Do obvodové sítě spojka nic neposílá (obsah busu čte drátem
--- BUS trubka – vanilla „Číst obsah potrubí“, 2.1).
--- Aktualizuje se po jedné spojce, rozloženě po ticích (volá kontrola v control.lua), a do hry se zapisuje
--- jen při změně – zápis do tisíce spojek najednou by způsobil viditelnou špičku ticku.
local topology = require("scripts.topology")

local M = {}

local GREEN = defines.entity_status_diode.green
local YELLOW = defines.entity_status_diode.yellow
local RED = defines.entity_status_diode.red

--- Barva kontrolky stavu podle coupler.state.
local DIODES = { ok = GREEN, ["no-power"] = RED, disabled = YELLOW, ["not-connected"] = YELLOW, conflict = RED }

--- Nastaví stav spojky (coupler.state a custom_status), jen pokud se změnil.
--- @param coupler table
--- @param state string klíč stavu (fb-status.<state>)
--- @param ... any parametry popisku
local function set(coupler, state, ...)
  local label = { "fb-status." .. state, ... }
  local key = table.concat({ state, tostring(label[2] or ""), tostring(label[3] or "") }, "|")
  coupler.state = state
  if coupler.status_key == key then return end
  coupler.status_key = key
  coupler.entity.custom_status = { diode = DIODES[state], label = label }
end

--- Aktualizuje stav jedné spojky podle sítě, ve které je, nebo podle jejího napájení a zapnutí.
--- @param unit integer
--- @param coupler table záznam ze storage.couplers
function M.update_coupler(unit, coupler)
  if not coupler.entity.valid then return end
  local net = topology.network_of(unit)
  if not net then
    if not coupler.powered then
      set(coupler, "no-power")
    elseif coupler.enabled == false then
      set(coupler, "disabled")
    else
      set(coupler, "not-connected")
    end
  elseif net.conflict then
    set(coupler, "conflict")
  else
    set(coupler, "ok", #net.segments, math.floor(net.fraction * 100 + 0.5))
  end
end

return M
