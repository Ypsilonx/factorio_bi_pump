-- Headless integrační testy modu fluid-bus (spouští tools/run-tests.sh).
local runner = require("runner")

runner.register(require("cases.smoke"))
runner.register(require("cases.bus_pipes"))
runner.register(require("cases.compat"))

script.on_init(runner.on_init)
script.on_event(defines.events.on_tick, runner.on_tick)
