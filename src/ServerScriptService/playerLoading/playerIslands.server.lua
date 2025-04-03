local Players = game:GetService("Players")
local islandHandler = require(game.ServerScriptService.libs.islandHandler)
local heroModule = require(game.ServerScriptService.libs.heroModule)

-- When a player joins, create their map
Players.PlayerAdded:Connect(function(player)
	islandHandler.createPlayerMap(player)
	islandHandler.spawnMonster(player, "Goblin", 1)
	heroModule.new(player, "defaultHero")
end)

-- When a player leaves, clean up their map
Players.PlayerRemoving:Connect(function(player)
	islandHandler.cleanupPlayerMap(player)
end)