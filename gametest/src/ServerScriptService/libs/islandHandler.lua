local islandHandler = {}
islandHandler.__index = islandHandler

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local dataManager = require(game.ServerScriptService.playerData.dataManager)
local monsterModule = require(game.ServerScriptService.libs.monsterModule)

local MAP_SPACING = 200
local ROW_SIZE = 3
local spawnIndex = 0

local playerMaps = {} -- dictionary that has key: player value: island
local mapPositions = {} -- Stores assigned map positions
local islandPermissions = {} -- Stores island permissions
local monsters = {} -- Tracks which island a monster belongs to

-- 🔹 Find the player's assigned island
function islandHandler.getPlayerIsland(player)
	return playerMaps[player]
end

-- 🔹 Find the `monsterSpawnArea` block on the island
function islandHandler.getMonsterSpawnArea(island)
	return island and island:FindFirstChild("monsterSpawnArea") or nil
end

function islandHandler.createPlayerMap(player)
	print("🚀 Creating map for:", player.Name)

	-- Wait for player data to load
	local profile = dataManager:GetData(player)
	if not profile then
		warn("❌ Data missing for", player.Name)
		return
	end
	print("✅ Data loaded:", profile)

	-- Verify maps folder exists
	local mapsFolder = ReplicatedStorage:FindFirstChild("maps")
	if not mapsFolder then
		warn("❌ Maps folder not found!")
		return
	end

	-- Select map
	local selectedMapName = profile.CurrentMap or "DefaultMap"
	local mapTemplate = mapsFolder:FindFirstChild(selectedMapName)
	if not mapTemplate then
		warn("❌ Map", selectedMapName, "not found! Using DefaultMap.")
		mapTemplate = mapsFolder:FindFirstChild("DefaultMap")
	end
	if not mapTemplate then
		warn("❌ No DefaultMap found! Cannot assign a map.")
		return
	end

	-- Clone the map
	local playerMap = mapTemplate:Clone()
	if not playerMap then
		warn("❌ Failed to clone map!")
		return
	end

	-- Assign a dynamic position
	spawnIndex += 1 -- Increment spawn index
	local row = math.floor((spawnIndex - 1) / ROW_SIZE) -- Determine row number
	local col = (spawnIndex - 1) % ROW_SIZE -- Determine column number

	local mapPosition = Vector3.new(col * MAP_SPACING, 0, row * MAP_SPACING) -- Grid layout

	-- Position the map
	if playerMap.PrimaryPart then
		playerMap:SetPrimaryPartCFrame(CFrame.new(mapPosition))
		print("✅ Map positioned correctly at:", mapPosition)
	else
		warn("⚠️ Map missing PrimaryPart! Cannot position it.")
	end

	-- Store in tables
	playerMap.Parent = game.Workspace
	playerMaps[player] = playerMap
	mapPositions[player] = mapPosition

	print("✅", player.Name, "has been assigned their map at", mapPosition)

	-- Load the player's character
	player:LoadCharacter()

	-- Position the player at their island
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

	if playerMap.PrimaryPart then
		humanoidRootPart.CFrame = playerMap.PrimaryPart.CFrame + Vector3.new(0, 10, 0) -- Spawn above the island
		print("✅ Player", player.Name, "spawned at their island.")
	else
		warn("⚠️ Map missing PrimaryPart! Cannot position player.")
	end

	--grant payer access to their island
	if not islandPermissions[player] then
		islandPermissions[player] = {} -- Initialize if missing
	end
	islandPermissions[player][player] = true -- Owner always has permission
	print("✅", player.Name, "now has permission on their island.")

	print(islandPermissions)


	-- Return the player's map for reference
	return playerMap
end

-- 🔹 Grant a player permission to access an island
function islandHandler.grantPermission(owner, guest)
	if not islandPermissions[owner] then
		warn("❌ Owner's island does not exist!")
		return false
	end

	if islandPermissions[owner][guest] then
		warn("⚠️", guest.Name, "already has permission to", owner.Name .. "'s island.")
		return false
	end

	islandPermissions[owner][guest] = true
	print("✅", guest.Name, "has been granted permission to", owner.Name .. "'s island.")
	return true
end

-- 🔹 Revoke a player's permission from an island
function islandHandler.revokePermission(owner, guest)
	if not islandPermissions[owner] then
		warn("❌ Owner's island does not exist!")
		return false
	end

	if not islandPermissions[owner][guest] then
		warn("⚠️", guest.Name, "does not have permission to", owner.Name .. "'s island.")
		return false
	end

	islandPermissions[owner][guest] = nil
	print("✅", guest.Name, "permission revoked from", owner.Name .. "'s island.")
	return true
end

-- 🔹 Check if a player has permission to access an island
function islandHandler.getPermission(owner, guest)
	if not islandPermissions[owner] then
		return false
	end
	return islandPermissions[owner][guest] == true -- Ensure it’s `true`
end

function islandHandler.getIslandOwner(island)
	for player, playerIsland in pairs(playerMaps) do
		if playerIsland == island then
			
			return player
		end
	end
	return nil
end


-- 🔹 Generate a random position within a spawn area
function islandHandler.getRandomPosition(area)
	local size = area.Size
	local position = area.Position
	local spacing = 5

	local randomX = math.random(-size.X / 2, size.X / 2)
	local randomZ = math.random(-size.Z / 2, size.Z / 2)

	local finalX = position.X + math.floor(randomX / spacing) * spacing
	local finalZ = position.Z + math.floor(randomZ / spacing) * spacing

	return Vector3.new(finalX, position.Y + 2, finalZ)
end

-- 🔹 Spawn a monster on a player's island
function islandHandler.spawnMonster(owner, monsterName, level)
	local island = islandHandler.getPlayerIsland(owner)
	if not island then
		warn("❌ Island does not exist for", owner.Name)
		return
	end

	local spawnArea = islandHandler.getMonsterSpawnArea(island)
	if not spawnArea then
		warn("❌ Spawn area does not exist on", owner.Name .. "'s island")
		return
	end

	local position = islandHandler.getRandomPosition(spawnArea)
	local monster = monsterModule.new(monsterName, owner, level)

	if monster and monster.model and monster.model.PrimaryPart then
		monster.model.Parent = island
		monster.model:SetPrimaryPartCFrame(CFrame.new(position))

		-- ✅ Make sure `monsters` table exists
		if not islandHandler.monsters then
			islandHandler.monsters = {} -- ✅ Initialize if it was `nil`
		end

		-- ✅ Store the monster properly
		islandHandler.monsters[monster.model] = island

		-- ✅ Debugging: Print the table
		print("🦖 Monster added! Current monsters table:")
		for key, value in pairs(islandHandler.monsters) do
			print("Monster:", key, "-> Island:", value)
		end
	else
		warn("❌ Failed to spawn monster")
	end
end


-- 🔹 Clean up a player's island and all related data
function islandHandler.cleanupPlayerMap(player)
	local island = playerMaps[player]

	-- Remove all monsters
	for monster, monsterIsland in pairs(monsters) do
		if monsterIsland == island then
			monster:Destroy()
			monsters[monster] = nil
		end
	end

	-- Clean up island if it exists
	if island then
		island:Destroy()
	end

	playerMaps[player] = nil
	mapPositions[player] = nil
	islandPermissions[player] = nil

	print("✅ Cleaned up island and permissions for player:", player.Name)
end

return islandHandler
