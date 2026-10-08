--- Signál a stav spojek do obvodové sítě a GUI:
---   zelený drát – [kapalina] = naplnění v % (0–100): síť, ve které spojka je; vypnutá / nenapájená spojka
---                 posílá naplnění plnější ze svých stran (podmínka „[kapalina] > 50“ ji tak umí znovu zapnout),
---   custom_status a coupler.state – síť a naplnění / bez proudu / vypnuto obvodem / nepřipojeno / různé kapaliny.
--- Aktualizuje se po jedné spojce, rozloženě po ticích (volá kontrola v control.lua), a do hry se zapisuje
--- jen při změně – zápis do tisíce spojek najednou by způsobil viditelnou špičku ticku.
local registry = require("scripts.registry")
local topology = require("scripts.topology")

local M = {}

local GREEN = defines.entity_status_diode.green
local YELLOW = defines.entity_status_diode.yellow
local RED = defines.entity_status_diode.red

--- Barva kontrolky a stavu podle coupler.state (sdílí i okno spojky).
M.DIODES = { ok = GREEN, ["no-power"] = RED, disabled = YELLOW, ["not-connected"] = YELLOW, conflict = RED }

--- Zapíše signál spojky, jen pokud se změnil (fluid nil = signál smazat).
--- @param coupler table záznam ze storage.couplers
--- @param fluid string|nil kapalina
--- @param percent integer|nil naplnění v %
local function write(coupler, fluid, percent)
  local key = tostring(fluid) .. "|" .. tostring(percent)
  if coupler.signal_key == key then return end
  registry.ensure_signals(coupler)
  coupler.signal_key = key
  local behavior = coupler.signals.green.get_or_create_control_behavior()
  if behavior.sections_count == 0 then behavior.add_section() end
  local section = behavior.get_section(1)
  if fluid and percent then
    section.set_slot(1, { value = { type = "fluid", name = fluid, quality = "normal" }, min = percent })
  else
    section.clear_slot(1)
  end
end

--- Nastaví stav spojky (coupler.state a custom_status), jen pokud se změnil.
--- @param coupler table
--- @param state string klíč stavu (fb-status.<state>)
--- @param ... any parametry popisku
local function status(coupler, state, ...)
  local label = { "fb-status." .. state, ... }
  local key = table.concat({ state, tostring(label[2] or ""), tostring(label[3] or "") }, "|")
  coupler.state = state
  if coupler.status_key == key then return end
  coupler.status_key = key
  coupler.entity.custom_status = { diode = M.DIODES[state], label = label }
end

--- Procenta z podílu (zaokrouhlená).
--- @param fraction number
--- @return integer
local function percent(fraction)
  return math.floor(fraction * 100 + 0.5)
end

--- Naplnění plnější strany spojky, která není v síti (nil = žádná strana nemá kapalinu).
--- @param coupler table
--- @return number|nil podíl, string|nil kapalina
function M.fuller_side(coupler)
  local best, best_fluid
  for _, side in ipairs(coupler.sides) do
    local fraction, fluid = topology.side_fill(side)
    if fluid and fraction and (not best or fraction > best) then best, best_fluid = fraction, fluid end
  end
  return best, best_fluid
end

--- Aktualizuje signál a stav jedné spojky podle sítě, ve které je, nebo podle jejích stran.
--- @param unit integer
--- @param coupler table záznam ze storage.couplers
function M.update_coupler(unit, coupler)
  if not coupler.entity.valid then return end
  local net = topology.network_of(unit)
  if not net then
    local fraction, fluid = M.fuller_side(coupler)
    write(coupler, fluid, fraction and percent(fraction))
    if not coupler.powered then
      status(coupler, "no-power")
    elseif coupler.enabled == false then
      status(coupler, "disabled")
    else
      status(coupler, "not-connected")
    end
  elseif net.conflict then
    write(coupler, nil, nil)
    status(coupler, "conflict")
  else
    local fill = percent(net.fraction)
    write(coupler, net.fluid, net.fluid and fill or nil)
    status(coupler, "ok", #net.segments, fill)
  end
end

return M
