local hero = {}

hero.__index = hero

local rs = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

function hero.new(player, heroName)
	local self = setmetatable({}, hero)
	
	--check if hero exists
	local heroTemplate = rs:FindFirstChild("heroes") and rs.heroes:FindFirstChild(heroName)
	if not heroTemplate then
		warn("hero not found", heroName)
		return nil
	end
	
	--model of hero
	self.model = heroTemplate:Clone()
	self.model.Parent = game.Workspace
	
	local character = player.Character
	if not character or not character.PrimaryPart then
		warn("player not found")
		return nil
	end
	
	local floatingPosition = Vector3.new(-3, 2, 0)
	self.model:SetPrimaryPartCFrame(character.PrimaryPart.CFrame + Vector3.new(floatingPosition))
	
	local bodyposition = Instance.new("BodyPosition")
	bodyposition.MaxForce = Vector3.new(5000,5000,5000) --make strrong enough to follow player smoothly
	bodyposition.D = 10 --how smooth
	bodyposition.P = 3000 --power (how responsive hero is)
	bodyposition.Parent = self.model.PrimaryPart
	
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(5000,5000,5000)
	bodyGyro.CFrame = self.model.PrimaryPart.CFrame
	bodyGyro.Parent = self.model.PrimaryPart
	
	self.followLoop = runService.Heartbeat:Connect(function()
		if character and character.PrimaryPart then
			local targetPosition = character.PrimaryPart.Position + floatingPosition
			bodyposition.Position = targetPosition
			bodyGyro.CFrame = character.PrimaryPart.CFrame
		end
	end)
	
	self.attackPower = self.model:GetAttribute("attackPower")
	self.attackSpeed = self.model:GetAttribute("attackSpeed")
	
	return self
	
	
end



return hero