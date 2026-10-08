--- Signály a stav spojek do obvodové sítě a GUI:
---   červený drát – [kapalina] = množství kapaliny v síti,
---   zelený drát  – [kapalina] = naplnění sítě v % (0–100),
---                  [vstup] / [výstup] = naplnění na vstupní / výstupní straně spojky v % (i když je vypnutá),
---   custom_status – síť a naplnění / bez proudu / vypnuto obvodem / nepřipojeno / různé kapaliny.
--- Aktualizuje se po jedné spojce, rozloženě po ticích (volá kontrola v control.lua), a do hry se zapisuje
--- jen při změně – zápis do tisíce spojek najednou by způsobil viditelnou špičku ticku.
local registry = require("scripts.registry")
local topology = require("scripts.topology")

local DATA = prototypes.mod_data["fb-data"].data
local INPUT = { type = "virtual", name = DATA.input_signal, quality = "normal" }
local OUTPUT = { type = "virtual", name = DATA.output_signal, quality = "normal" }

local M = {}

local GREEN = defines.entity_status_diode.green
local YELLOW = defines.entity_status_diode.yellow
local RED = defines.entity_status_diode.red
--- Strop hodnoty signálu (int32).
local MAX_SIGNAL = 2147483647

--- Nastaví sloty kombinátoru podle seznamu; slot s value nil se smaže.
--- @param combinator LuaEntity skrytý konstantní kombinátor
--- @param slots table[] { signal = SignalID|nil, value = integer|nil } v pořadí slotů
local function set(combinator, slots)
  local behavior = combinator.get_or_create_control_behavior()
  if behavior.sections_count == 0 then behavior.add_section() end
  local section = behavior.get_section(1)
  for i, slot in ipairs(slots) do
    if slot.signal and slot.value then
      section.set_slot(i, { value = slot.signal, min = slot.value })
    else
      section.clear_slot(i)
    end
  end
end

--- Procenta z podílu (zaokrouhlená), nil zůstane nil.
--- @param fraction number|nil
--- @return integer|nil
local function percent(fraction)
  return fraction and math.floor(fraction * 100 + 0.5) or nil
end

--- Zapíše signály spojky, jen pokud se změnily (fluid nil = signály sítě smazat).
--- @param coupler table záznam ze storage.couplers
--- @param fluid string|nil kapalina sítě
--- @param amount integer|nil množství kapaliny v síti
--- @param fill integer|nil naplnění sítě v %
--- @param input integer|nil naplnění vstupní strany v %
--- @param output integer|nil naplnění výstupní strany v %
local function write(coupler, fluid, amount, fill, input, output)
  local key = table.concat({ tostring(fluid), tostring(amount), tostring(fill), tostring(input), tostring(output) }, "|")
  if coupler.signal_key == key then return end
  registry.ensure_signals(coupler)
  coupler.signal_key = key
  local signal = fluid and { type = "fluid", name = fluid, quality = "normal" }
  set(coupler.signals.red, { { signal = signal, value = amount } })
  set(coupler.signals.green, { { signal = signal, value = fill }, { signal = INPUT, value = input },
    { signal = OUTPUT, value = output } })
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

--- Aktualizuje signály a stav jedné spojky podle sítě, ve které je, a podle jejích stran.
--- @param unit integer
--- @param coupler table záznam ze storage.couplers
function M.update_coupler(unit, coupler)
  if not coupler.entity.valid then return end
  local input = percent(topology.side_fill(coupler.sides[1]))
  local output = percent(topology.side_fill(coupler.sides[2]))
  local net = topology.network_of(unit)
  if not net then
    write(coupler, nil, nil, nil, input, output)
    if not coupler.powered then
      status(coupler, RED, { "fb-status.no-power" })
    elseif coupler.enabled == false then
      status(coupler, YELLOW, { "fb-status.disabled" })
    else
      status(coupler, YELLOW, { "fb-status.not-connected" })
    end
  elseif net.conflict then
    write(coupler, nil, nil, nil, input, output)
    status(coupler, RED, { "fb-status.conflict" })
  else
    local fill = percent(net.fraction)
    local amount = net.fluid and math.min(MAX_SIGNAL, math.floor(net.total_amount)) or nil
    write(coupler, net.fluid, amount, net.fluid and fill or nil, input, output)
    status(coupler, GREEN, { "fb-status.ok", #net.segments, fill })
  end
end

return M
