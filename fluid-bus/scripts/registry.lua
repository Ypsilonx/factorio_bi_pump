--- Evidence spojek busu ve storage.
local data = prototypes.mod_data["fb-data"].data

local M = {}

M.COUPLER = data.coupler

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

--- Zaeviduje novou spojku (opakované ohlášení téže spojky se ignoruje).
--- @param entity LuaEntity
function M.add(entity)
  if storage.couplers[entity.unit_number] then return end
  storage.couplers[entity.unit_number] = { entity = entity, sides = { {}, {} } }
  storage.dirty = true
end

--- Vyřadí spojku z evidence.
--- @param unit integer unit_number spojky
function M.remove(unit)
  if not storage.couplers[unit] then return end
  storage.couplers[unit] = nil
  storage.dirty = true
end

--- Úklid po změně modů / starém savu: neplatné spojky pryč.
function M.revalidate()
  -- Šipky směru z vývojové verze 0.2.0 (mod jiné vykreslené objekty nemá).
  rendering.clear(script.mod_name)
  for unit, coupler in pairs(storage.couplers) do
    coupler.arrow = nil
    -- Skryté kombinátory výstupního signálu (do 0.2.0) – prototyp zrušen, hra je při načtení smazala.
    coupler.signals, coupler.signal_key = nil, nil
    if not coupler.entity.valid then M.remove(unit) end
  end
  storage.dirty = true
end

return M
