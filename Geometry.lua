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

-- Compute the smallest enclosing circle of a set of points
local SmallestEnclosingCircle
do
	local ws = {}
	local ws_len = 0
	
	local function ws_add(x, y)
		ws_len = ws_len + 1
		local point = ws[ws_len]
		if point then
			point[1] = x
			point[2] = y
		else
			ws[ws_len] = { x, y }
		end
	end
	
	local function ws_remove(i)
		if i < ws_len then
			ws[i] = ws[ws_len]
		end
		ws_len = ws_len - 1
	end
	
	local function ws_get(i)
		local point = ws[i]
		if not point then return end
		return point[1], point[2]
	end
	
	local cx, cy, cr
	
	local function is_in_circle(px, py)
		return cx and Distance(cx, cy, px, py) < cr + 1e-12
	end
	
	local function cross_product(x0, y0, x1, y1, x2, y2)
		return (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
	end
	
	local function make_circumcircle(ax, ay, bx, by, cx, cy)
		local d = (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by)) * 2
		if d == 0 then return end
		
		local a2 = ax * ax + ay * ay
		local b2 = bx * bx + by * by
		local c2 = cx * cx + cy * cy
		
		local x = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
		local y = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
		
		return x, y, Distance(x, y, ax, ay)
	end
	
	function SmallestEnclosingCircle(point, npts)
		ws_len = 0
		
		for i = 1, npts do
			ws_add(point(i))
		end
		
		if npts < 1 then
			error("You need at least 1 point to compute the smallest enclosing circle")
		end
		
		cx = nil
		
		-- Progressively add points to circle or recompute circle
		for i = 1, npts do
			local px, py = ws_get(i)
			
			if not is_in_circle(px, py) then
				-- makeCircleOnePoint
				cx, cy, cr = px, py, 0
				
				for j = 1, i do
					local qx, qy = ws_get(j)
					
					if not is_in_circle(qx, qy) then
						local _cr = cr
						
						-- makeDiameter
						cx = (px + qx) / 2
						cy = (py + qy) / 2
						cr = Distance(px, py, qx, qy) / 2
						
						if _cr > 0 then
							-- makeCircleTwoPoints
							local contains_all = true
							for k = 1, j do
								local tx, ty = ws_get(k)
								if not is_in_circle(tx, ty) then
									contains_all = false
									break
								end
							end
							
							if not contains_all then
								local lx, ly, lr
								local rx, ry, rr
								
								for k = 1, j do
									local tx, ty = ws_get(k)
									
									local cross = cross_product(px, py, qx, qy, tx, ty)
									local wx, wy, wr = make_circumcircle(px, py, qx, qy, tx, ty)
									
									if wx then
										if cross > 0 and (not lx or cross_product(px, py, qx, qy, wx, wy) > cross_product(px, py, qx, qy, lx, ly)) then
											lx, ly, lr = wx, wy, wr
										elseif cross < 0 and (not rx or cross_product(px, py, qx, qy, wx, wy) < cross_product(px, py, qx, qy, rx, ry)) then
											rx, ry, rr = wx, wy, wr
										end
									end
								end
								
								if not rx or (lx and lr <= rr) then
									cx, cy, cr = lx, ly, lr
								else
									cx, cy, cr = rx, ry, rr
								end
							end
						end
					end
				end
			end
		end
		
		return cx, cy, cr
	end
end

Geometry.Distance = Distance
Geometry.RotatePoint = RotatePoint
Geometry.AngleDelta = AngleDelta
Geometry.PointVectorProject = PointVectorProject
Geometry.PointVectorDistance = PointVectorDistance
Geometry.PointInTriangle = PointInTriangle
Geometry.PointInPolygon = PointInPolygon
Geometry.SmallestEnclosingCircle = SmallestEnclosingCircle
