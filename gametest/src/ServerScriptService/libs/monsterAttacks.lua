local monsterAttacks = {}

local players = game:GetService("Players")
local sss = game:GetService("ServerScriptService")

local function getIslandHandler()
	return require(sss.libs.islandHandler)
end

-- Get players in range and filter by permission
function monsterAttacks.getPlayersInRange(monster, range)
	local islandHandler = getIslandHandler()
	local island = islandHandler.monsters and islandHandler.monsters[monster.model]
	if not island then return {} end

	local islandOwner = islandHandler.getIslandOwner(island)
	if not islandOwner then return {} end

	local validPlayers = {}

	for _, player in pairs(players:GetPlayers()) do
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local distance = (monster.model.PrimaryPart.Position - character.HumanoidRootPart.Position).Magnitude
			if distance < range and islandHandler.getPermission(islandOwner, player) then
				table.insert(validPlayers, player)
			end
		end
	end

	return validPlayers
end


-- Get attack pattern
function monsterAttacks.getAttackPattern(monsterName)
	local attackPatterns = {
		["Goblin"] = {
			sequence = {"defaultAttack", "defaultAttack", "defaultAttack", "roarAttack"}, --sequence
			attackDelays = {0.3, 0.3, 0.3, 1.5}, -- time between each attack in the sequence
			attackSequenceDelay = 1 -- time before sequence restarts
		},
		["Fire Elemental"] = {
			sequence = {monsterAttacks.Fireball, monsterAttacks.Explosion},
			attackDelays = {1, 1.5}, -- Fireball, then a delayed explosion
			attackSequenceDelay = 5
		},
		["Orc"] = {
			sequence = {monsterAttacks.smashAttack, monsterAttacks.defaultAttack, monsterAttacks.roarAttack},
			attackDelays = {1, 0.5, 2}, -- Smash > quick attack > longer roar
			attackSequenceDelay = 4
		},
	}

	return attackPatterns[monsterName] or { 
		sequence = {monsterAttacks.defaultAttack}, 
		attackDelays = {0.5}, 
		attackSequenceDelay = 3 
	}
end

function monsterAttacks.damagePlayer(monster, player, damage)
	-- Validate inputs
	if not monster or not player or not player.Character then return end

	local islandHandler = getIslandHandler()
	local island = islandHandler.monsters and islandHandler.monsters[monster.model]
	if not island then return end

	local islandOwner = islandHandler.getIslandOwner(island)
	if not (islandOwner and islandHandler.getPermission(islandOwner, player)) then
		warn("🚫", player.Name, "does NOT have permission to be attacked by", monster.model.Name)
		return
	end

	local humanoid = player.Character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
		print("💥", player.Name, "took", damage, "damage from", monster.model.Name)
	end
end

-- Function to get ground position
local function getGroundPosition(position, character)
	local rayOrigin = position + Vector3.new(0, 10, 0)  -- Start raycast slightly above target position
	local rayDirection = Vector3.new(0, -50, 0) -- Cast downward
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {character} -- Exclude player's character

	local maxAttempts = 5 -- Prevent infinite loop
	local raycastResult

	for _ = 1, maxAttempts do
		raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if raycastResult then
			local hitPart = raycastResult.Instance

			-- Check if the hit part is fully transparent (or has no collision)
			if hitPart.Transparency < 0.95 and hitPart.CanCollide then
				return raycastResult.Position -- Return only if it's a solid ground
			else
				-- Move the raycast slightly lower and try again
				rayOrigin = raycastResult.Position + Vector3.new(0, -1, 0)
			end
		else
			break -- No hit, exit loop
		end
	end

	return position -- Default to original position if no valid ground found
end















------------MOVES--------------


-- Default attack with warning and damage duration variables
function monsterAttacks.defaultAttack(monster)
	print("DEBUG: Executing defaultAttack for", monster.model.Name)
	if not monster or not monster.model or not monster.model.PrimaryPart then
		warn("monster is dead or missing")
		return
	end

	local WARNING_DURATION = 0.5 -- Time before damage part appears
	local DAMAGE_DURATION = 0.75 -- Time damage part stays before disappearing

	local nearbyPlayers = monsterAttacks.getPlayersInRange(monster, monster.range)
	if #nearbyPlayers == 0 then return end -- Safety check

	local targetPlayer = nearbyPlayers[math.random(1, #nearbyPlayers)]
	local targetPosition = targetPlayer.Character.HumanoidRootPart.Position

	local groundPosition = getGroundPosition(targetPosition, targetPlayer.Character) -- Get the correct ground position
	local speedScale = 1

	-- Create warning part
	local warningPart = Instance.new("Part")
	warningPart.Size = Vector3.new(0.25,10,8)
	warningPart.Position = groundPosition + Vector3.new(0, 0.1, 0) -- Slightly above ground
	warningPart.Color = Color3.fromRGB(255, 0, 0)
	warningPart.Material = Enum.Material.Neon
	warningPart.Anchored = true
	warningPart.CanCollide = false
	warningPart.Name = "warningPart"
	warningPart.Transparency = 0.01
	warningPart.Shape = Enum.PartType.Cylinder
	warningPart.Orientation = Vector3.new(0,0,90)

	warningPart.Parent = game.Workspace
	print("DEBUG: Spawned warning area at", warningPart.Position)

	-- Remove warning and spawn damage part
	task.delay(WARNING_DURATION * speedScale, function()
		warningPart:Destroy()
		print("DEBUG: Warning area removed, spawning damage part.")

		local dmgPart = Instance.new("Part")
		dmgPart.Size = Vector3.new(14,10,8)
		dmgPart.Position = groundPosition + Vector3.new(0, 5, 0) -- Raise it slightly above ground
		dmgPart.Color = Color3.fromRGB(255, 0, 0)
		dmgPart.Material = Enum.Material.Neon
		dmgPart.Anchored = true
		dmgPart.CanCollide = false
		dmgPart.Transparency = 0.5
		dmgPart.Name = "dmgPart"
		dmgPart.Shape = Enum.PartType.Cylinder
		dmgPart.Orientation = Vector3.new(0,0,90)

		dmgPart.Parent = game.Workspace
		print("DEBUG: Damage area spawned at", dmgPart.Position)

		local playersHit = {}

		-- Apply damage when player touches the damage part
		dmgPart.Touched:Connect(function(hit)
			local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
			if player and not playersHit[player] then
				playersHit[player] = true -- Mark as hit
				monsterAttacks.damagePlayer(monster, player, 15)
			end
		end)

		-- Remove damage part after delay
		task.delay(DAMAGE_DURATION * speedScale, function()
			dmgPart:Destroy()
			print("DEBUG: Damage area removed.")
		end)
	end)
end


-- Roar attack (AOE damage centered on monster)
function monsterAttacks.roarAttack(monster)
	print("DEBUG: Executing roarAttack for", monster.model.Name)
	
	if not monster or not monster.model or not monster.model.PrimaryPart then
		warn("monster is dead or missing")
		return
	end

	local WARNING_DURATION = 2 -- Time before roar damage part appears
	local DAMAGE_DURATION = .25 -- Time roar damage part stays before disappearing

	local monsterPosition = monster.model.PrimaryPart.Position
	local roarRadius = 20
	local damageAmount = 15
		
	-- Create warning part
	local warningPart = Instance.new("Part")
	warningPart.Size = Vector3.new(0.5, roarRadius * 2, roarRadius * 2)
	warningPart.Position = Vector3.new(monsterPosition.X, monsterPosition.Y - 4, monsterPosition.Z)
	warningPart.Color = Color3.fromRGB(255, 165, 0)
	warningPart.Material = Enum.Material.Neon
	warningPart.Anchored = true
	warningPart.CanCollide = false
	warningPart.Name = "warningPart"
	warningPart.Shape = Enum.PartType.Cylinder
	warningPart.Parent = game.Workspace
	warningPart.Orientation = Vector3.new(0,0,90)
	print("DEBUG: Spawned Roar warning area at", warningPart.Position)

	-- Remove warning and spawn damage part
	task.delay(WARNING_DURATION, function()
		warningPart:Destroy()
		print("DEBUG: Roar warning removed, spawning damage part.")

		local dmgPart = Instance.new("Part")
		dmgPart.Size = Vector3.new(14, roarRadius * 2, roarRadius * 2)
		dmgPart.Position = monsterPosition
		dmgPart.Color = Color3.fromRGB(255, 69, 0)
		dmgPart.Material = Enum.Material.Neon
		dmgPart.Anchored = true
		dmgPart.CanCollide = false
		dmgPart.Transparency = 0.5
		dmgPart.Name = "dmgPart"
		dmgPart.Shape = Enum.PartType.Cylinder
		dmgPart.Orientation = Vector3.new(0,0,90)

		dmgPart.Parent = game.Workspace
		print("DEBUG: Roar damage area spawned at", dmgPart.Position)

		local playersHit = {}

		-- Apply damage when player touches the damage part
		dmgPart.Touched:Connect(function(hit)
			local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
			if player and not playersHit[player] then
				playersHit[player] = true -- Mark as hit
				monsterAttacks.damagePlayer(monster, player, damageAmount)
			end
		end)

		-- Remove damage part after delay
		task.delay(DAMAGE_DURATION, function()
			dmgPart:Destroy()
			print("DEBUG: Roar damage area removed.")
		end)
	end)
end



return monsterAttacks
