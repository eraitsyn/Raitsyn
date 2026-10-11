--!strict
-- Mounts the game's source folders exactly as default.project.json maps them,
-- so specs can require real modules: Game.get("ReplicatedStorage.Shared.Logic.Odds").

local Loader = require("./Loader")

Loader.init(".", {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
})

return Loader
