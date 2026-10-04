--- Signály a stav spojek do obvodové sítě a GUI:
---   červený drát – [kapalina] = množství kapaliny v síti,
---   zelený drát  – [kapalina] = naplnění sítě v % (0–100),
---   custom_status – síť a naplnění / bez proudu / vypnuto obvodem / nepřipojeno / různé kapaliny.
--- Aktualizuje se po jedné spojce, rozloženě po ticích (volá kontrola v control.lua), a do hry se zapisuje
--- jen při změně – zápis do tisíce spojek najednou by způsobil viditelnou špičku ticku.
local registry = require("scripts.registry")
local topology = require("scripts.topology")

local M = {}

local GREEN = defines.entity_status_diode.green
local YELLOW = defines.entity_status_diode.yellow
local RED = defines.entity_status_diode.red
--- Strop hodnoty signálu (int32).
local MAX_SIGNAL = 2147483647

--- Nastaví (nebo smaže, je-li fluid nil) jediný signál kombinátoru.
--- @param combinator LuaEntity skrytý konstantní kombinátor
--- @param fluid string|nil
--- @param value integer|nil
local function set(combinator, fluid, value)
  local behavior = combinator.get_or_create_control_behavior()
  if behavior.sections_count == 0 then behavior.add_section() end
  local section = behavior.get_section(1)
  if fluid then
    section.set_slot(1, { value = { type = "fluid", name = fluid, quality = "normal" }, min = value })
  else
    section.clear_slot(1)
  end
end

--- Zapíše signály spojky, jen pokud se změnily (fluid nil = signály smazat).
--- @param coupler table záznam ze storage.couplers
--- @param fluid string|nil kapalina sítě
--- @param amount integer|nil množství kapaliny v síti
--- @param percent integer|nil naplnění v %
local function write(coupler, fluid, amount, percent)
  local key = tostring(fluid) .. "|" .. tostring(amount) .. "|" .. tostring(percent)
  if coupler.signal_key == key then return end
  registry.ensure_signals(coupler)
  coupler.signal_key = key
  set(coupler.signals.red, fluid, amount)
  set(coupler.signals.green, fluid, percent)
end

--- Nastaví custom_status spojky, jen pokud se změnil.
--- @param coupler table
--- @param diode defines.entity_status_diode
--- @param label LocalisedString
local function status(coupler, diode, label)
  local key = table.concat({ label[1], label[2] or "", label[3] or "" }, "|")
  if coupler.status_key == key then return end
  coupler.status_key = key
  coupler.entity.custom_status = { diode = diode, label = label }
end

--- Aktualizuje signály a stav jedné spojky podle sítě, ve které je.
--- @param unit integer
--- @param coupler table záznam ze storage.couplers
function M.update_coupler(unit, coupler)
  if not coupler.entity.valid then return end
  local net = topology.network_of(unit)
  if not net then
    write(coupler, nil, nil, nil)
    if not coupler.powered then
      status(coupler, RED, { "fb-status.no-power" })
    elseif coupler.enabled == false then
      status(coupler, YELLOW, { "fb-status.disabled" })
    else
      status(coupler, YELLOW, { "fb-status.not-connected" })
    end
  elseif net.conflict then
    write(coupler, nil, nil, nil)
    status(coupler, RED, { "fb-status.conflict" })
  else
    local fill = math.floor(net.fraction * 100 + 0.5)
    local amount = net.fluid and math.min(MAX_SIGNAL, math.floor(net.total_amount)) or nil
    write(coupler, net.fluid, amount, net.fluid and fill or nil)
    status(coupler, GREEN, { "fb-status.ok", #net.segments, fill })
  end
end

return M
