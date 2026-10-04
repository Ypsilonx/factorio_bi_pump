-- Headless integrační testy modu fluid-bus (spouští tools/run-tests.sh).
local runner = require("runner")

runner.register(require("cases.smoke"))
runner.register(require("cases.bus_pipes"))
runner.register(require("cases.compat"))
runner.register(require("cases.coupler"))
runner.register(require("cases.network"))
runner.register(require("cases.balance"))
runner.register(require("cases.signals"))
runner.register(require("cases.control"))
runner.register(require("cases.lifecycle"))
runner.register(require("cases.robustness"))
runner.register(require("cases.flow"))

script.on_init(runner.on_init)
script.on_event(defines.events.on_tick, runner.on_tick)
