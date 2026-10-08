-- Runtime modu: jen napojuje události na moduly ze scripts/.
local registry = require("scripts.registry")
local topology = require("scripts.topology")
local balancer = require("scripts.balancer")
local signals = require("scripts.signals")
local remote_api = require("scripts.remote")
local gui = require("scripts.gui")

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

--- Za kolik ticků projde rozložená kontrola všechny spojky (napojení, proud, signály, stav). Laditelné.
local CHECK_INTERVAL = 60

--- Rozložená kontrola: za CHECK_INTERVAL projde všechny spojky – topologie, proud a zapnutí obvodem
--- (změna → přestavba sítí), signál intervalu, výstupní signály a stav. Rozložení zabrání špičkám
--- ticku u velkých busů; řízení obvodem se proto projeví se zpožděním nejvýš CHECK_INTERVAL.
local function check_couplers()
  local list = storage.check_list
  if #list == 0 then return end
  for _ = 1, math.ceil(#list / CHECK_INTERVAL) do
    local unit = list[storage.check_cursor]
    local coupler = storage.couplers[unit]
    if not (coupler and coupler.entity.valid) or topology.refresh(coupler) then
      storage.dirty = true
    else
      topology.read_interval(unit, coupler)
      signals.update_coupler(unit, coupler)
    end
    storage.check_cursor = storage.check_cursor % #list + 1
  end
end

--- Za kolik ticků po první změně se sítě přestaví – změny během té doby (stavba busu roboty,
--- spojky postupně dostávající proud) se sloučí do jedné přestavby. Laditelné.
local REBUILD_DELAY = 10

--- Každý tick: přestavba sítí (se zpožděním), rozložená kontrola spojek a vyrovnání sítí na řadě.
--- Interval vyrovnávání je nastavení mapy – jde měnit za běhu.
--- @param event EventData.on_tick
local function on_tick(event)
  local interval = settings.global["fb-balance-interval"].value
  if storage.dirty then
    storage.dirty_tick = storage.dirty_tick or event.tick
    if event.tick - storage.dirty_tick >= REBUILD_DELAY then
      topology.rebuild(event.tick, interval)
      storage.dirty_tick = nil
    end
  end
  check_couplers()
  balancer.step(event.tick, interval)
end

script.on_init(registry.init)
script.on_configuration_changed(function()
  registry.init()
  registry.revalidate()
  gui.reset_all()
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
-- Vlastní okno spojky místo nativního.
script.on_event(defines.events.on_gui_opened, gui.on_opened)
script.on_event(defines.events.on_gui_closed, gui.on_closed)
script.on_event(defines.events.on_gui_click, gui.on_click)
for _, name in ipairs({ "on_gui_checked_state_changed", "on_gui_elem_changed", "on_gui_selection_state_changed",
  "on_gui_text_changed" }) do
  script.on_event(defines.events[name], gui.on_changed)
end
script.on_nth_tick(gui.REFRESH_TICKS, gui.refresh)
remote_api.register()
