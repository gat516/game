local TweenService = game:GetService("TweenService")

-- Variables
local currentLevel = 1
local maxLevel = 10
local minLevel = 1

local leftButton = script.Parent.leftButton
local rightButton = script.Parent.rightButton

local iconTemplate = script.Parent.iconTemplate
iconTemplate.Visible = false -- Hide the template

local iconsContainer = script.Parent.Parent.iconsContainer
iconsContainer.ClipsDescendants = true -- Hide icons outside the container

local tweenDuration = 0.3 -- Duration of the tween in seconds
local debounce = false -- Debounce variable to prevent multiple presses

-- Positions for icons (left, middle, right)
local positions = {
	UDim2.new(0.05, 0, 0, 0),  -- Left
	UDim2.new(0.375, 0, 0, 0), -- Middle
	UDim2.new(0.7, 0, 0, 0)    -- Right
}

-- The tween offset is the gap between positions (0.375 - 0.05 = 0.325)
local tweenOffset = UDim2.new(0.325, 0, 0, 0)

-- Table to hold the current icons
local icons = {}

--------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------

-- Returns a table of levels that should be visible for a given current level.
local function getVisibleLevels(level)
	if level == minLevel then
		-- At level 1, show only levels 1 and 2.
		return { level, level + 1 }
	elseif level == maxLevel then
		-- At max level, show only levels (max-1) and max.
		return { level - 1, level }
	else
		-- Otherwise, show three icons.
		return { level - 1, level, level + 1 }
	end
end

-- Returns the proper UDim2 positions for the given visible levels.
local function getPositionsForVisibleLevels(visibleLevels, level)
	if #visibleLevels == 2 then
		if level == minLevel then
			-- For levels 1 and 2, place them on the right (middle & right positions).
			return { positions[2], positions[3] }
		elseif level == maxLevel then
			-- For the last two levels, place them on the left (left & middle positions).
			return { positions[1], positions[2] }
		end
	else
		-- For three icons, use all positions.
		return positions
	end
end

-- Function to create an icon.
local function createIcon(level, position)
	local icon = iconTemplate:Clone()
	icon.Parent = iconsContainer
	icon.Position = position
	icon.Text = "Level " .. tostring(level)
	icon.Visible = true
	-- Use attributes to store the level.
	icon:SetAttribute("Level", level)
	return icon
end

--------------------------------------------------------------------
-- Setup and Tweening Functions
--------------------------------------------------------------------

-- Sets up the icons initially based on currentLevel.
local function setupIcons()
	for _, icon in ipairs(icons) do
		icon:Destroy()
	end
	icons = {}

	local visibleLevels = getVisibleLevels(currentLevel)
	local targetPositions = getPositionsForVisibleLevels(visibleLevels, currentLevel)
	for i, lvl in ipairs(visibleLevels) do
		local icon = createIcon(lvl, targetPositions[i])
		table.insert(icons, icon)
	end
end

-- Tween icons in the given direction ("left" means moving to the next level, "right" means moving to the previous level).
local function tweenIcons(direction, callback)
	if debounce then return end
	debounce = true

	local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweensCompleted = 0
	local totalTweens = 0

	-- Determine the new current level based on the direction.
	local newLevel
	if direction == "left" then
		newLevel = currentLevel + 1
	elseif direction == "right" then
		newLevel = currentLevel - 1
	end

	local targetLevels = getVisibleLevels(newLevel)
	local targetPositions = getPositionsForVisibleLevels(targetLevels, newLevel)

	-- Check which levels are missing from our current icons.
	local missingLevels = {}
	for _, lvl in ipairs(targetLevels) do
		local found = false
		for _, icon in ipairs(icons) do
			if icon:GetAttribute("Level") == lvl then
				found = true
				break
			end
		end
		if not found then
			table.insert(missingLevels, lvl)
		end
	end

	-- Create any missing icon off-screen.
	if direction == "left" then
		if #missingLevels > 0 then
			local lvl = missingLevels[1]
			-- For a left slide (to next level), spawn off-screen to the right.
			local startPos = targetPositions[#targetPositions] + tweenOffset
			local newIcon = createIcon(lvl, startPos)
			table.insert(icons, newIcon)
		end
		-- Tween all icons left by tweenOffset.
		for _, icon in ipairs(icons) do
			totalTweens = totalTweens + 1
			local targetPos = icon.Position - tweenOffset
			local tween = TweenService:Create(icon, tweenInfo, { Position = targetPos })
			tween:Play()
			tween.Completed:Connect(function()
				tweensCompleted = tweensCompleted + 1
				if tweensCompleted == totalTweens then
					callback(newLevel, targetLevels, targetPositions)
				end
			end)
		end
	elseif direction == "right" then
		if #missingLevels > 0 then
			local lvl = missingLevels[1]
			-- For a right slide (to previous level), spawn off-screen to the left.
			local startPos = targetPositions[1] - tweenOffset
			local newIcon = createIcon(lvl, startPos)
			table.insert(icons, newIcon)
		end
		-- Tween all icons right by tweenOffset.
		for _, icon in ipairs(icons) do
			totalTweens = totalTweens + 1
			local targetPos = icon.Position + tweenOffset
			local tween = TweenService:Create(icon, tweenInfo, { Position = targetPos })
			tween:Play()
			tween.Completed:Connect(function()
				tweensCompleted = tweensCompleted + 1
				if tweensCompleted == totalTweens then
					callback(newLevel, targetLevels, targetPositions)
				end
			end)
		end
	end
end

-- After tweening, update currentLevel and reassign icons.
local function updateIcons(direction)
	tweenIcons(direction, function(newLevel, targetLevels, targetPositions)
		currentLevel = newLevel

		-- Remove any icons not part of the target set.
		local updatedIcons = {}
		for _, icon in ipairs(icons) do
			local keep = false
			for _, lvl in ipairs(targetLevels) do
				if icon:GetAttribute("Level") == lvl then
					keep = true
					break
				end
			end
			if keep then
				table.insert(updatedIcons, icon)
			else
				icon:Destroy()
			end
		end
		icons = updatedIcons

		-- Sort icons by level.
		table.sort(icons, function(a, b)
			return a:GetAttribute("Level") < b:GetAttribute("Level")
		end)

		-- Reassign exact positions so they end up at the intended UDim2s.
		for i, icon in ipairs(icons) do
			icon.Position = targetPositions[i]
		end

		debounce = false
	end)
end

--------------------------------------------------------------------
-- Button Handlers
--------------------------------------------------------------------

local function slideRight()
	if debounce then return end
	if currentLevel < maxLevel then
		-- Slide icons left to reveal the next level.
		updateIcons("left")
	end
end

local function slideLeft()
	if debounce then return end
	if currentLevel > minLevel then
		-- Slide icons right to reveal the previous level.
		updateIcons("right")
	end
end

leftButton.MouseButton1Click:Connect(slideLeft)
rightButton.MouseButton1Click:Connect(slideRight)

--------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------

setupIcons()
