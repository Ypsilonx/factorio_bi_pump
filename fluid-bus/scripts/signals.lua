--- Signály a stav spojek: naplnění sítě (%) a množství kapaliny do obvodové sítě, custom_status v GUI.
--- Aktualizuje se po jedné spojce, rozloženě po ticích (volá kontrola topologie v control.lua), a do hry
--- se zapisuje jen při změně – zápis do tisíce spojek najednou by způsobil viditelnou špičku ticku.
local topology = require("scripts.topology")

local M = {}

local GREEN = defines.entity_status_diode.green
local YELLOW = defines.entity_status_diode.yellow
local RED = defines.entity_status_diode.red
--- Strop hodnoty signálu (int32).
local MAX_SIGNAL = 2147483647

--- Zapíše signály do skrytého kombinátoru spojky, jen pokud se změnily (nil = signál smazat).
--- @param coupler table záznam ze storage.couplers
--- @param fill integer|nil naplnění v %
--- @param fluid string|nil kapalina sítě
--- @param amount integer|nil množství kapaliny v síti
local function write(coupler, fill, fluid, amount)
  local key = tostring(fill) .. "|" .. tostring(fluid) .. "|" .. tostring(amount)
  if coupler.signal_key == key or not (coupler.signals and coupler.signals.valid) then return end
  coupler.signal_key = key
  local behavior = coupler.signals.get_or_create_control_behavior()
  if behavior.sections_count == 0 then behavior.add_section() end
  local section = behavior.get_section(1)
  if fill then
    section.set_slot(1, { value = { type = "virtual", name = "fb-fill", quality = "normal" }, min = fill })
  else
    section.clear_slot(1)
  end
  if fluid then
    section.set_slot(2, { value = { type = "fluid", name = fluid, quality = "normal" }, min = amount })
  else
    section.clear_slot(2)
  end
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
    else
      status(coupler, YELLOW, { "fb-status.not-connected" })
    end
  elseif net.conflict then
    write(coupler, nil, nil, nil)
    status(coupler, RED, { "fb-status.conflict" })
  else
    local fill = math.floor(net.fraction * 100 + 0.5)
    local amount = net.fluid and math.min(MAX_SIGNAL, math.floor(net.total_amount + net.buffer.amount)) or nil
    write(coupler, net.fluid and fill or nil, net.fluid, amount)
    status(coupler, GREEN, { "fb-status.ok", #net.segments, fill })
  end
end

return M
