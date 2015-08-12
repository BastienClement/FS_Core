local _, FS = ...
local Geometry = FS:RegisterModule("Geometry")

local sin, cos, atan2, abs = math.sin, math.cos, math.atan2
local abs, floor, min, max = math.abs, math.floor, math.min, math.max
local pi2, pi_2 = math.pi * 2, math.pi / 2

-- Distance between two points
local function Distance(sx, sy, ex, ey, squared)
	local dx = sx - ex
	local dy = sy - ey
	local d2 = dx * dx + dy * dy
	return squared and d2 or (d2 ^ 0.5)
end

-- Rotate a point
local function RotatePoint(x, y, a, cx, cy, sina, cosa)
	if cx and cy then
		x = x - cx
		y = y - cy
	end
	
	if not sina then sina = sin(a) end
	if not cosa then cosa = cos(a) end
	
	local rx = x * cosa + y * sina
	local ry = -x * sina + y * cosa
	
	if cx and cy then
		rx = rx + cx
		ry = ry + cy
	end
	
	return rx, ry
end

-- Angle difference
local function AngleDelta(a, b)
	return atan2(sin(b - a), cos(b - a))
end

-- Project a point on a vector
local function PointVectorProject(x, y, sx, sy, ex, ey)
	local dx = ex - sx
	local dy = ey - sy
	
	local l2 = Distance(sx, sy, ex, ey, true)
	local t = ((x - sx) * dx + (y - sy) * dy) / l2
	
	local px = sx + t * dx
	local py = sy + t * dy
	
	return px, py, t, l2
end

-- Distance between a point and a vector
local function PointVectorDistance(x, y, sx, sy, ex, ey, extend)
	-- Extend:
	-- 0 -> segment
	-- 1 -> ray
	-- 2 -> line
	
	local px, py, t, l2 = PointVectorProject(x, y, sx, sy, ex, ey)
		
	-- Outside the vector
	if l2 < 0.01 or (t < 0 and extend ~= 2) then
		return Distance(sx, sy, x, y), true
	elseif t > 1 and extend ~= 1 and extend ~= 2 then
		return Distance(ex, ey, x, y), true
	end
	
	-- On the vector
	return Distance(x, y, px, py), false
end

-- Check if a point is inside a triangle
local function PointInTriangle(x, y, x1, y1, x2, y2, x3, y3)
	-- http://stackoverflow.com/a/20861130
	
	local s = y1 * x3 - x1 * y3 + (y3 - y1) * x + (x1 - x3) * y
	local t = x1 * y2 - y1 * x2 + (y1 - y2) * x + (x2 - x1) * y
	
	if (s < 0) ~= (t < 0) then return false end
	
	local A = -y2 * x3 + y1 * (x3 - x2) + x1 * (y2 - y3) + x2 * y3
	
	if A < 0 then
		s = -s
		t = -t
		A = -A
	end
	
	return s > 0 and t > 0 and (s + t) < A
end

-- Check if a point is inside a polygon
local function PointInPolygon(x, y, vertex, nvert)
	-- http://www.ecse.rpi.edu/~wrf/Research/Short_Notes/pnpoly.html
	local inside = false
	
	for i = 1, nvert do
		local ix, iy = vertex(i)
		local jx, jy = vertex(i - 1)
		if ((iy > y) ~= (jy > y)) and (x < (jx - ix) * (y - iy) / (jy - iy) + ix) then
			inside = not inside
		end
	end
	
	return inside
end

Geometry.Distance = Distance
Geometry.RotatePoint = RotatePoint
Geometry.AngleDelta = AngleDelta
Geometry.PointVectorProject = PointVectorProject
Geometry.PointVectorDistance = PointVectorDistance
Geometry.PointInTriangle = PointInTriangle
Geometry.PointInPolygon = PointInPolygon
