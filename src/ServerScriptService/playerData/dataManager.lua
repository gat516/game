local dataManager = {}

dataManager.Profiles = {}
dataManager.PendingProfiles = {} -- Table to hold awaiting threads

function dataManager:hasProfile(player)
	return self.Profiles[player] ~= nil
end

function dataManager:GetData(player, timeout)
	timeout = timeout or 5
	local startTime = tick()

	-- If profile already exists, return immediately
	if self.Profiles[player] then
		return self.Profiles[player]
	end

	-- If there's already a thread waiting for this profile, yield on it
	if self.PendingProfiles[player] then
		return self.PendingProfiles[player]:wait()
	end

	-- Create a Promise-like waiting system
	local thread = coroutine.running()
	self.PendingProfiles[player] = thread

	repeat
		task.wait() -- Yield and wait until the profile loads
	until self.Profiles[player] or tick() - startTime > timeout

	self.PendingProfiles[player] = nil -- Clean up

	if self.Profiles[player] then
		return self.Profiles[player]
	else
		warn("dataManager: Timed out waiting for data for " .. player.Name)
		return nil
	end
end

function dataManager:adjustStat(player: Player, stat: string, value)
	local profile = self:GetData(player)
	if profile then
		if profile.Data[stat] ~= nil then
			if typeof(profile.Data[stat]) == typeof(value) then
				profile.Data[stat] += value
				if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild(stat) then
					player.leaderstats[stat].Value += value
				end
			else
				warn("dataManager: Mismatched data types for " .. stat .. " on player " .. player.Name)
			end
		else
			warn("dataManager: Invalid stat for player " .. player.Name)
		end
	else
		warn("dataManager: No profile for player " .. player.Name)
	end
end

function dataManager:setStat(player: Player, stat: string, value)
	local profile = self:GetData(player)
	if profile then
		if profile.Data[stat] ~= nil then
			if typeof(profile.Data[stat]) == typeof(value) then
				profile.Data[stat] = value
				-- also update GUIs or something here
			else
				warn("dataManager: Mismatched data types for " .. stat .. " on player " .. player.Name)
			end
		else
			warn("dataManager: Invalid stat for player " .. player.Name)
		end
	else
		warn("dataManager: No profile for player " .. player.Name)
	end
end

return dataManager
