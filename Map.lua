local _, FS = ...
local Map = FS:RegisterModule("Map")

local pi_2, pi2 = math.pi / 2, math.pi * 2
local atan2 = math.atan2

--------------------------------------------------------------------------------
-- Distance and orientation

-- Compute distance between two points
function Map:GetDistance(ax, ay, bx, by)
	local dx = ax - bx
	local dy = ay - by
	return (dx * dx + dy * dy) ^ 0.5
end

-- Compute angle between two points
-- Facing is angle (in radian) CCW from north
-- Result between [0, 2*PI] CCW relative to facing
function Map:GetAngle(ax, ay, bx, by, afacing)
	local dx = bx - ax
	local dy = ay - by
	return (atan2(dx, dy) - GetPlayerFacing() - pi_2) % pi2
end

-- Return both distance and angle between two points
function Map:GetDirection(ax, ay, bx, by, afacing)
	local d = self:GetDistance(ax, ay, bx, by)
	local a = self:GetAngle(ax, ay, bx, by, afacing)
	return d, a
end

--------------------------------------------------------------------------------
-- Player centered versions

function Map:GetPlayerDistance(x, y)
	local px, py = UnitPosition("player")
	return self:GetDistance(px, py, x, y)
end

function Map:GetPlayerAngle(x, y)
	local px, py = UnitPosition("player")
	return self:GetAngle(px, py, x, y, GetPlayerFacing())
end

function Map:GetPlayerDirection(x, y)
	local px, py = UnitPosition("player")
	local d = self:GetDistance(px, py, x, y)
	local a = self:GetAngle(px, py, x, y, GetPlayerFacing())
	return d, a
end
