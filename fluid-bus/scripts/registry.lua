--- Evidence spojek busu ve storage a jejich skrytých kombinátorů signálů.
local data = prototypes.mod_data["fb-data"].data

local M = {}

M.COUPLER = data.coupler
M.SIGNALS = data.coupler_signals

--- Doplní chybějící tabulky ve storage (on_init i on_configuration_changed).
function M.init()
  storage.couplers = storage.couplers or {}
  storage.networks = storage.networks or {}
  storage.cursor = storage.cursor or 1
  storage.check_list = storage.check_list or {}
  storage.check_cursor = storage.check_cursor or 1
  storage.coupler_net = storage.coupler_net or {}
  -- Pozůstatky starší verze (rozložené vyrovnávání se zásobníkem).
  storage.queue, storage.segments = nil, nil
  storage.dirty = true
end

--- Vytvoří skrytý kombinátor na pozici spojky a propojí ho s ní drátem (původ script = hráč ho nevidí).
--- Případný starý kombinátor na stejném místě (klon, cizí mod) se nejdřív zruší, aby se signály nezdvojily.
--- @param entity LuaEntity spojka
--- @return LuaEntity
local function create_signals(entity)
  for _, old in pairs(entity.surface.find_entities_filtered({ name = M.SIGNALS, position = entity.position })) do
    old.destroy()
  end
  local signals = entity.surface.create_entity({ name = M.SIGNALS, position = entity.position, force = entity.force })
  -- Plošné poškození (výbuch, kyselina) by ho jinak zničilo a signály by tiše zmizely.
  signals.destructible = false
  for _, id in ipairs({ defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green }) do
    entity.get_wire_connector(id, true).connect_to(signals.get_wire_connector(id, true), false, defines.wire_origin.script)
  end
  return signals
end

--- Zaeviduje novou spojku (opakované ohlášení téže spojky se ignoruje).
--- @param entity LuaEntity
function M.add(entity)
  if storage.couplers[entity.unit_number] then return end
  storage.couplers[entity.unit_number] = { entity = entity, signals = create_signals(entity), sides = { {}, {} } }
  storage.dirty = true
end

--- Vyřadí spojku z evidence a zruší její kombinátor.
--- @param unit integer unit_number spojky
function M.remove(unit)
  local coupler = storage.couplers[unit]
  if not coupler then return end
  if coupler.signals and coupler.signals.valid then coupler.signals.destroy() end
  storage.couplers[unit] = nil
  storage.dirty = true
end

--- Úklid po změně modů / starém savu: neplatné spojky pryč, chybějící kombinátory znovu.
function M.revalidate()
  for unit, coupler in pairs(storage.couplers) do
    if not coupler.entity.valid then
      M.remove(unit)
    elseif not (coupler.signals and coupler.signals.valid) then
      coupler.signals = create_signals(coupler.entity)
      coupler.signal_key = nil
    end
  end
  storage.dirty = true
end

return M
