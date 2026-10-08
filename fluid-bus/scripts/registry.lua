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

--- Barvy drátů a jejich konektory: každý skrytý kombinátor vysílá jen do jedné barvy
--- (červená = množství, zelená = procenta – obojí pod ikonou kapaliny).
local WIRES = { red = defines.wire_connector_id.circuit_red, green = defines.wire_connector_id.circuit_green }

--- Zruší skryté kombinátory spojky (nový formát { red, green } i starší jediný kombinátor).
--- @param signals table|LuaEntity|nil
local function destroy_signals(signals)
  if not signals then return end
  -- Starší verze ukládala jediný kombinátor (LuaEntity má object_name, prostá tabulka ne).
  local list = signals.object_name and { signals } or { signals.red, signals.green }
  for _, entity in pairs(list) do
    if entity.valid then entity.destroy() end
  end
end

--- Vytvoří dva skryté kombinátory na pozici spojky, každý propojený jedním drátem (původ script = hráč
--- je nevidí). Případné staré kombinátory na stejném místě (klon, cizí mod) se nejdřív zruší.
--- @param entity LuaEntity spojka
--- @return table { red = LuaEntity, green = LuaEntity }
local function create_signals(entity)
  for _, old in pairs(entity.surface.find_entities_filtered({ name = M.SIGNALS, position = entity.position })) do
    old.destroy()
  end
  local signals = {}
  for color, id in pairs(WIRES) do
    local combinator = entity.surface.create_entity({ name = M.SIGNALS, position = entity.position, force = entity.force })
    -- Plošné poškození (výbuch, kyselina) by ho jinak zničilo a signály by tiše zmizely.
    combinator.destructible = false
    entity.get_wire_connector(id, true).connect_to(combinator.get_wire_connector(id, true), false,
      defines.wire_origin.script)
    signals[color] = combinator
  end
  return signals
end

--- Jsou kombinátory spojky v pořádku (nový formát, oba platné)?
--- @param signals table|LuaEntity|nil
--- @return boolean
local function signals_ok(signals)
  return signals ~= nil and not signals.object_name and signals.red ~= nil and signals.red.valid
    and signals.green ~= nil and signals.green.valid
end

--- Zajistí platné kombinátory spojky (převede starší save, obnoví zničené).
--- @param coupler table záznam ze storage.couplers
function M.ensure_signals(coupler)
  if signals_ok(coupler.signals) then return end
  destroy_signals(coupler.signals)
  coupler.signals = create_signals(coupler.entity)
  coupler.signal_key = nil
end

--- Šipka směru vstup → výstup v alt režimu (sprite spojky je souměrný, vstup by nešlo poznat).
--- Volá se při stavbě, rotaci hráčem i z rozložené kontroly (rotace skriptem/jiným modem událost nevyvolá).
--- Vstup je na straně, kam spojka „míří“, šipka proto ukazuje opačně (k výstupu).
--- @param coupler table záznam ze storage.couplers
function M.ensure_arrow(coupler)
  local entity = coupler.entity
  local orientation = (entity.orientation + 0.5) % 1
  if coupler.arrow and coupler.arrow.valid then
    if coupler.arrow.orientation ~= orientation then coupler.arrow.orientation = orientation end
    return
  end
  coupler.arrow = rendering.draw_sprite({ sprite = "utility/indication_arrow", target = entity, surface = entity.surface,
    orientation = orientation, x_scale = 0.6, y_scale = 0.6, only_in_alt_mode = true })
end

--- Zaeviduje novou spojku (opakované ohlášení téže spojky se ignoruje).
--- @param entity LuaEntity
function M.add(entity)
  if storage.couplers[entity.unit_number] then return end
  storage.couplers[entity.unit_number] = { entity = entity, signals = create_signals(entity), sides = { {}, {} } }
  M.ensure_arrow(storage.couplers[entity.unit_number])
  storage.dirty = true
end

--- Vyřadí spojku z evidence a zruší její kombinátory.
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
  for unit, coupler in pairs(storage.couplers) do
    if not coupler.entity.valid then
      M.remove(unit)
    else
      M.ensure_signals(coupler)
      M.ensure_arrow(coupler)
    end
  end
  storage.dirty = true
end

return M
