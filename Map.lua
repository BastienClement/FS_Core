local _, FS = ...
local Map = FS:RegisterModule("Map")

local pi_2 = math.pi / 2
local atan2 = math.atan2
local sqrt = math.sqrt

function Map:GetDistance(targetX, targetY)
	if not targetX then return end
	local playerX, playerY = UnitPosition("player")
	
	local dx, dy = playerX - targetX, playerY - targetY
	local distance = sqrt(dx * dx + dy * dy)
	
	local angle = atan2(playerX - targetX, -(playerY - targetY)) - GetPlayerFacing() + pi_2
	
	return distance, angle
end
