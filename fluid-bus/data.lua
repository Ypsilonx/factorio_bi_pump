-- Prototypy nezávislé na jiných modech: spojka busu a její pomocné prototypy.
local coupler = require("prototypes.coupler")

data:extend(coupler.prototypes(settings.startup["fb-coupler-power"].value))
