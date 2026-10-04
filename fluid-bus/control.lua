-- Runtime modu: jen napojuje události na moduly ze scripts/.
local registry = require("scripts.registry")
local topology = require("scripts.topology")
local balancer = require("scripts.balancer")
local signals = require("scripts.signals")
local remote_api = require("scripts.remote")

local FILTER = { { filter = "name", name = registry.COUPLER } }
--- Klonování: i skrytý kombinátor (klon spojky dostane vlastní, naklonovaný se zahodí).
local CLONE_FILTER = { { filter = "name", name = registry.COUPLER }, { filter = "name", name = registry.SIGNALS } }

--- Postavení spojky libovolnou cestou (hráč, robot, platforma, skript, klonování).
local function on_built(event)
  local entity = event.entity or event.destination
  if not (entity and entity.valid) then return end
  if entity.name == registry.SIGNALS then
    entity.destroy()
  elseif entity.name == registry.COUPLER then
    registry.add(entity)
  end
end

--- Odstranění spojky libovolnou cestou.
local function on_removed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == registry.COUPLER then registry.remove(entity.unit_number) end
end

--- Rozložená kontrola: za interval projde všechny spojky – topologie (změna → přestavba sítí)
--- a signály se stavem. Rozložení zabrání špičkám ticku u velkých busů.
local function check_couplers()
  local list = storage.check_list
  if #list == 0 then return end
  local interval = prototypes.mod_data["fb-data"].data.interval
  for _ = 1, math.ceil(#list / interval) do
    local unit = list[storage.check_cursor]
    local coupler = storage.couplers[unit]
    if not (coupler and coupler.entity.valid) or topology.refresh(coupler) then
      storage.dirty = true
    else
      signals.update_coupler(unit, coupler)
    end
    storage.check_cursor = storage.check_cursor % #list + 1
  end
end

--- Za kolik ticků po první změně se sítě přestaví – změny během té doby (stavba busu roboty,
--- spojky postupně dostávající proud) se sloučí do jedné přestavby. Laditelné.
local REBUILD_DELAY = 10

--- Každý tick: přestavba sítí (se zpožděním), rozložená kontrola spojek a díl vyrovnávání.
--- @param event EventData.on_tick
local function on_tick(event)
  if storage.dirty then
    storage.dirty_tick = storage.dirty_tick or event.tick
    if event.tick - storage.dirty_tick >= REBUILD_DELAY then
      topology.rebuild()
      storage.dirty_tick = nil
    end
  end
  check_couplers()
  balancer.step()
end

script.on_init(registry.init)
script.on_configuration_changed(function()
  registry.init()
  registry.revalidate()
end)
for _, name in ipairs({ "on_built_entity", "on_robot_built_entity", "on_space_platform_built_entity",
  "script_raised_built", "script_raised_revive" }) do
  script.on_event(defines.events[name], on_built, FILTER)
end
script.on_event(defines.events.on_entity_cloned, on_built, CLONE_FILTER)
for _, name in ipairs({ "on_player_mined_entity", "on_robot_mined_entity", "on_space_platform_mined_entity",
  "on_entity_died", "script_raised_destroy" }) do
  script.on_event(defines.events[name], on_removed, FILTER)
end
--- Otočení spojky hráčem: strany míří jinam – přeměřit hned a přestavět sítě.
script.on_event(defines.events.on_player_rotated_entity, function(event)
  local coupler = event.entity.name == registry.COUPLER and storage.couplers[event.entity.unit_number]
  if coupler then
    topology.refresh(coupler)
    storage.dirty = true
  end
end)
script.on_event(defines.events.on_tick, on_tick)
remote_api.register()
