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

--- Drát, kterým spojka vysílá naplnění ([kapalina] = %).
local GREEN = defines.wire_connector_id.circuit_green

--- Zruší skryté kombinátory spojky (formát { green }, starší { red, green } i nejstarší jediný kombinátor).
--- @param signals table|LuaEntity|nil
local function destroy_signals(signals)
  if not signals then return end
  -- Nejstarší verze ukládala přímo kombinátor (LuaEntity má object_name, prostá tabulka ne).
  local list = signals.object_name and { signals } or signals
  for _, entity in pairs(list) do
    if entity.valid then entity.destroy() end
  end
end

--- Vytvoří skrytý kombinátor na pozici spojky propojený zeleným drátem (původ script = hráč ho nevidí).
--- Případné staré kombinátory na stejném místě (klon, cizí mod) se nejdřív zruší.
--- @param entity LuaEntity spojka
--- @return table { green = LuaEntity }
local function create_signals(entity)
  for _, old in pairs(entity.surface.find_entities_filtered({ name = M.SIGNALS, position = entity.position })) do
    old.destroy()
  end
  local combinator = entity.surface.create_entity({ name = M.SIGNALS, position = entity.position, force = entity.force })
  -- Plošné poškození (výbuch, kyselina) by ho jinak zničilo a signál by tiše zmizel.
  combinator.destructible = false
  entity.get_wire_connector(GREEN, true).connect_to(combinator.get_wire_connector(GREEN, true), false,
    defines.wire_origin.script)
  return { green = combinator }
end

--- Je kombinátor spojky v pořádku (aktuální formát, platný)?
--- @param signals table|LuaEntity|nil
--- @return boolean
local function signals_ok(signals)
  return signals ~= nil and not signals.object_name and signals.red == nil and signals.green ~= nil
    and signals.green.valid
end

--- Zajistí platný kombinátor spojky (převede starší save, obnoví zničený).
--- @param coupler table záznam ze storage.couplers
function M.ensure_signals(coupler)
  if signals_ok(coupler.signals) then return end
  destroy_signals(coupler.signals)
  coupler.signals = create_signals(coupler.entity)
  coupler.signal_key = nil
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
  destroy_signals(coupler.signals)
  storage.couplers[unit] = nil
  storage.dirty = true
end

--- Úklid po změně modů / starém savu: neplatné spojky pryč, chybějící kombinátory znovu.
function M.revalidate()
  -- Šipky směru z vývojové verze 0.2.0 (mod jiné vykreslené objekty nemá).
  rendering.clear(script.mod_name)
  for unit, coupler in pairs(storage.couplers) do
    coupler.arrow = nil
    if not coupler.entity.valid then
      M.remove(unit)
    else
      M.ensure_signals(coupler)
    end
  end
  storage.dirty = true
end

return M
