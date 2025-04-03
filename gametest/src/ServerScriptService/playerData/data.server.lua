local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")

local playerClass = require(script.Parent.playerClass)
local profileService = require(sss.libs.ProfileService)
local dataManager = require(script.Parent.dataManager)

local profilestore = profileService.GetProfileStore("test", playerClass) --holds data for all players

local function giveleaderstats(player: Player)
	local profile = dataManager.Profiles[player]
	if not profile then return end --no profile, stop.
	
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local gold = Instance.new("NumberValue", leaderstats)
	gold.Name = "Gold"
	gold.Value = profile.Data.Gold
	
	player:SetAttribute("clickPower", profile.Data.clickPower)
end



local function PlayerAdded(player: Player)
	local profile = profilestore:LoadProfileAsync("Player_"..player.UserId)
	
	if profile == nil then
		player:Kick(("Trouble loading save. ."))
		return
	end
	
	profile:AddUserId(player.UserId) --tags saved data/profile with a userid
	profile:Reconcile() -- fills in missing variables from profile teplate. accounts for adding new things to game such as stats or currency
	
	profile:ListenToRelease(function() --checks if another profile is on another server. if so,
		dataManager.Profiles[player] = nil --gets rid of player data from game
		player:Kick("Error. Please rejoin.")
	end)
	
	if player:IsDescendantOf(players) == true then --checks if player has properly joined
		dataManager.Profiles[player] = profile
		giveleaderstats(player)
	else
		profile:Release()
	end
	
end

for _, player in players:GetPlayers() do
	task.spawn(PlayerAdded, player)
end

players.PlayerAdded:Connect(PlayerAdded)

players.PlayerRemoving:Connect(function(player: Player)
	local profile = dataManager.Profiles[player]
	if not profile then return end
	profile:Release()
end)