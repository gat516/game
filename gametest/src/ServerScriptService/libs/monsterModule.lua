local Monster = {}
Monster.__index = Monster

local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local dataManager = require(sss.playerData.dataManager)
local monsterAttacks = require(sss.libs.monsterAttacks)
local RESPAWN_TIME = 5

-- Utility function to get islandHandler
local function getIslandHandler()
	return require(sss.libs.islandHandler)
end

-- 🦖 Constructor: Create a Monster
function Monster.new(monsterName, player, level)
	local self = setmetatable({}, Monster)

	local monsterTemplate = rs:FindFirstChild("monsters") and rs.monsters:FindFirstChild(monsterName)
	if not monsterTemplate then
		warn("❌ Monster not found:", monsterName)
		return nil
	end

	self.model = monsterTemplate:Clone()
	self.humanoid = self.model:FindFirstChild("Humanoid")

	if not self.humanoid then
		warn("❌ Monster missing Humanoid!")
		self.model:Destroy()
		return nil
	end

	self.player = player
	self.level = level
	
	--health	
	self.maxHealth = self.model:GetAttribute("maxHealth")
	self.model.Humanoid.Health = self.maxHealth
	self.health = self.model.Humanoid.Health
	--range
	self.range = self.model:GetAttribute("range")
	--isdead check
	self.isDead = false
	--attackpattern
	self.attackPattern = monsterAttacks.getAttackPattern(monsterName)
	-- Register monster with islandHandler
	local islandHandler = getIslandHandler()
	local playerIsland = islandHandler.getPlayerIsland(player)
	if not playerIsland then
		warn("❌ Could not get player's island for monster registration!")
		return nil
	end

	islandHandler.monsters = islandHandler.monsters or {}
	islandHandler.monsters[self.model] = playerIsland
	print("DEBUG: Registered monster", self.model.Name, "to island", playerIsland)

	-- Start attack loop
	self:startAttackLoop()

	-- Handle click damage
	local clickDetector = self.model:FindFirstChild("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function(attackingPlayer)
			self:takeDamage(attackingPlayer)
		end)
	end

	return self
end

-- ⚔️ Monster takes damage
function Monster:takeDamage(attackingPlayer)
	if self.isDead then return end
	print("DEBUG: Monster", self.model.Name, "took damage from", attackingPlayer.Name)

	local islandHandler = getIslandHandler()
	local island = islandHandler.monsters and islandHandler.monsters[self.model]
	if not island then return end

	local owner = islandHandler.getIslandOwner(island)
	if not (owner and islandHandler.getPermission(owner, attackingPlayer)) then
		warn("🚫", attackingPlayer.Name, "does NOT have permission to attack this monster!")
		return
	end

	local damage = attackingPlayer:GetAttribute("clickPower") or 1
	self.health = self.health - damage
	self.humanoid:TakeDamage(damage)

	if self.health <= 0 then
		self:onDeath(attackingPlayer)
	end
end

-- ☠️ Monster Death Handling
function Monster:onDeath(killer)
	if self.isDead then return end
	self.isDead = true

	dataManager:adjustStat(killer, "Gold", 2)

	local islandHandler = getIslandHandler()
	islandHandler.monsters[self.model] = nil
	self.model:Destroy()

	task.delay(RESPAWN_TIME, function()
		islandHandler.spawnMonster(self.player, self.model.Name, self.level)
	end)
end

-- 🔄 Start attack loop with burst patterns and total delay
function Monster:startAttackLoop()
	print("DEBUG: Preparing attack loop for", self.model.Name)

	task.spawn(function()
		while not self.isDead do
			local nearbyPlayers = monsterAttacks.getPlayersInRange(self, self.range)

			-- 🚨 Check if there are players nearby
			if #nearbyPlayers > 0 then
				print("DEBUG: Players detected! Starting attack loop for", self.model.Name)

				-- Continue attacking while players are nearby
				while not self.isDead and #nearbyPlayers > 0 do
					local attackSequence = self.attackPattern.sequence or {"defaultAttack"} -- Default attack sequence
					local attackDelays = self.attackPattern.attackDelays or {} -- Per attack delays
					local attackSequenceDelay = self.attackPattern.attackSequenceDelay or 3 -- Delay before restarting sequence

					for i, attackName in ipairs(attackSequence) do
						local attackFunction = monsterAttacks[attackName] -- Look up function dynamically
						if attackFunction then 
							print("DEBUG: Executing", attackName, "for", self.model.Name)
							attackFunction(self) 
						else
							warn("⚠️ Attack function not found:", attackName)
						end

						-- Delay after each attack in the sequence
						local delayTime = attackDelays[i] or 0.5 -- Default to 0.5s delay if not specified
						task.wait(delayTime)
					end

					-- Wait before restarting attack sequence
					task.wait(attackSequenceDelay)

					-- Check if players are still nearby
					nearbyPlayers = monsterAttacks.getPlayersInRange(self, self.range)
				end

				-- 🚨 Stop attacks if no players are nearby
				print("DEBUG: No players detected. Stopping attack loop for", self.model.Name)
			end

			-- Check again for nearby players every second
			task.wait(1)
		end
	end)
end


return Monster
