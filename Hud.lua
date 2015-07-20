local _, FS = ...
local Hud = FS:RegisterModule("Hud")

local sin, cos = math.sin, math.cos
local pi_2 = math.pi / 2

--------------------------------------------------------------------------------
-- HUD Frame

local hud
do
	hud = CreateFrame("Frame", "FSHud", UIParent)
	hud:Hide()
end

--------------------------------------------------------------------------------
-- Module initialization

function Hud:OnInitialize()
	self.objects = {}
	self.num_objs = 0
	self.visible = false
end

function Hud:OnEnable()
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function Hud:OnDisable()
	-- Clear all active objects on disable
	self:Clear()
end

--------------------------------------------------------------------------------
-- Object frame pool

do
	local pool = {}
	
	local function normalize(frame, use_tex)
		frame:SetFrameStrata("BACKGROUND")
		frame:ClearAllPoints()
		
		frame.tex:SetAllPoints()
		frame.tex:SetDrawLayer("ARTWORK")
		if use_tex then
			frame.tex:Show()
		else
			frame.tex:Hide()
		end
		
		frame:Show()
		return frame
	end
	
	-- Recycle an old frame or allocate a new one
	function Hud:AllocObjFrame(use_tex)
		if #pool > 0 then
			return normalize(table.remove(pool), use_tex)
		else
			local frame = CreateFrame("Frame", nil, hud)
			frame.tex = frame:CreateTexture(nil, "ARTWORK")
			return normalize(frame, use_tex)
		end
	end
	
	-- Put the given frame back in the pool
	function Hud:ReleaseObjFrame(frame)
		frame:Hide()
		table.insert(pool, tex)
	end
end

--------------------------------------------------------------------------------
-- Points

do
	local points = {}
	local aliases = {}

	-- Construct a point
	function Hud:CreatePoint(name, ...)
		-- Generate a random name if anonymous
		if not name then
			name = tostring(GetTime()) + tostring(math.random())
		end
		
		if points[name] then return points[name] end
		
		local point = { __is_point = true }
		
		point.name = name
		points[name] = point
		
		point.aliases = {}
		
		if ... then
			local als = { ... }
			for _, alias in ipairs(als) do
				aliases[alias] = pointd
				table.insert(point.aliases, alias)
			end
		end
		
		point.frame = Hud:AllocObjFrame(true)
		point.tex = point.frame.tex
		
		point.frame:SetSize(16, 16)
		point.tex:SetTexture("Interface\\AddOns\\BigWigs\\Textures\\blip")
		point.tex:SetVertexColor(1, 1, 1, 0)
		point.tex:SetDrawLayer("OVERLAY")
		
		point.x = 0
		point.y = 0
		
		point.attached = {}
		
		-- Define the corresponding unit
		function point:SetUnit(unit)
			self.unit = unit
		end
		
		-- Change the point color
		function point:SetColor(r, g, b, a)
			self.tex:SetVertexColor(r, g, b, a or 1)
		end
		
		-- Update the point position
		function point:Update()
			-- Fetch point position
			local x, y = self:Position()
			if not x then return end
			
			-- Project point
			self.real_x, self.real_y = x, y
			x, y = Hud:Project(x, y)
			
			-- Save
			self.x = x
			self.y = y
			
			-- Place the point
			self.frame:SetPoint("CENTER", hud, "CENTER", x, y)
			
			-- Unit raid target icon and class color
			if self.unit then
				local rt = GetRaidTargetIndex(self.unit)
				if self.unit_rt ~= rt then
					if rt then
						self.frame:SetSize(24, 24)
						self.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. rt .. ".blp")
						self.tex:SetVertexColor(1, 1, 1)
						self.unit_class = nil
					elseif not rt then
						self.frame:SetSize(16, 16)
						self.tex:SetTexture("Interface\\AddOns\\BigWigs\\Textures\\blip")
						self.tex:SetVertexColor(0.5, 0.5, 0.5)
					end
					self.unit_rt = rt
				end
				
				local class = UnitClass(self.unit)
				if not rt and self.unit_class ~= class then
					self.tex:SetVertexColor(FS:GetClassColor(self.unit, true))
					self.unit_class = class
				end
			end
		end
		
		-- Attach an object to this point
		-- The object will be :Remove()'ed when this point is removed.
		function point:AttachObject(obj)
			if not self.attached[obj] then
				self.attached[obj] = true
			end
		end
		
		-- Remove the point and any attached objects
		local removed = false
		function point:Remove()
			-- Ensure the function is not called two times
			if removed then return end
			removed = true
			
			-- Release frame
			Hud:ReleaseObjFrame(self.frame)
			
			-- Point itself
			points[self.name] = nil
			
			-- Any aliases
			for _, alias in ipairs(self.aliases) do
				-- Check that the alias is actually pointing to self
				if aliases[alias] == self then
					aliases[alias] = nil
				end
			end
			
			-- Remove attached objects
			for obj in pairs(self.attached) do
				obj:Remove()
			end
		end
		
		-- Detach an object
		function point:DetachObject(obj)
			-- Do not remove object once the point deletion process has started
			if removed then return end
			self.attached[obj] = nil
		end
		
		return point
	end
	
	-- Create a static point
	function Hud:CreateStaticPoint(x, y, ...)
		local pt = self:CreatePoint(...)
		function pt:Position() return x, y end
		return pt
	end
	
	-- Iterates over all points
	function Hud:IteratePoints()
		return pairs(points)
	end
	
	-- Return a point
	function Hud:GetPoint(name)
		if name.__is_point then return name end
		return points[name] or aliases[name]
	end
	
	-- Find point position
	function Hud:GetPointPosition(name)
		local pt = self:GetPoint(name)
		if pt then
			return pt.real_x or 0, pt.real_y or 0
		else
			return 0, 0
		end
	end
	
	-- Remove a point
	function Hud:RemovePoint(name)
		local pt = self:GetPoint(name)
		if pt then
			pt:Remove()
		end
	end
end

-- Automatically create points for raid units
do
	-- Player point
	local player_pt = Hud:CreatePoint("player", UnitName("player"), UnitGUID("player"))
	player_pt:SetUnit("player")
	player_pt.frame:SetFrameStrata("HIGH")
	function player_pt:Position()
		return UnitPosition("player")
	end
	
	-- Raid members points
	local raid_pts = {}
	local first_done = false
	function Hud:GROUP_ROSTER_UPDATE()
		-- Do not update if encounter is in progress
		if first_done and FS:EncounterInProgress() then return end
		first_done = true
		
		-- Remove old raid points
		for _, pt in pairs(raid_pts) do
			pt:Remove()
		end
		wipe(raid_pts)
		
		-- Reconstruct
		if IsInRaid() then
			for i = 1, GetNumGroupMembers() do
				local unit = "raid" .. i
				-- Player unit is always present
				if not UnitIsUnit(unit, "player") then
					local pt = Hud:CreatePoint(unit, UnitName(unit), UnitGUID(unit))
					pt:SetUnit(unit)
					function pt:Position()
						return UnitPosition(unit)
					end
					raid_pts[unit] = pt
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Visibility and updates

function Hud:Show(force)
	if self.visible then return end
	self:Print("activating HUD display")
	self.visible = true
	self.force = force
	hud:SetAllPoints()
	hud:Show()
	self.ticker = C_Timer.NewTicker(0.035, function() self:OnUpdate() end)
	self:GROUP_ROSTER_UPDATE()
	self:OnUpdate()
end

function Hud:Hide()
	if not self.visible then return end
	self:Print("disabling HUD display")
	self.visible = false
	self.ticker:Cancel()
	hud:Hide()
	self:Clear()
end

do
	local px = 0
	local py = 0
	local sin_t = 0
	local cos_t = 0
	local zoom = 10
	
	function Hud:SetZoom(z)
		zoom = z
	end
	
	function Hud:Project(x, y)
		local dx = px - x
		local dy = py - y
		local rx = dx * cos_t + dy * sin_t
		local ry = -dx * sin_t + dy * cos_t
		return rx * zoom, ry * zoom
	end

	function Hud:OnUpdate()
		-- Nothing to draw, auto-hide
		if not self.force and self.num_objs == 0 then
			self:Hide()
			return
		end
		
		-- Fetch player position and facing for projection
		px, py = UnitPosition("player")
		local t = GetPlayerFacing() + pi_2
		cos_t = cos(t)
		sin_t = sin(t)
		
		-- Update all points
		for name, obj in self:IteratePoints() do
			obj:Update()
		end
		
		-- Update all objects
		for obj in next, self.objects do
			obj:Update()
		end
	end
end

--------------------------------------------------------------------------------
-- Objects interface

local HudObject = {}

function HudObject:Remove()
	Hud:RemoveObject(self)
end

function HudObject:UsePoint(name)
	local pt = Hud:GetPoint(name)
	if pt then
		table.insert(self.attached, pt)
		pt:AttachObject(self)
	end
	return pt
end

function HudObject:SetColor(...)
	self.tex:SetVertexColor(...)
end

function Hud:CreateObject(proto, ...)
	return self:AddObject(setmetatable(proto or {}, { __index = HudObject }), ...)
end

--------------------------------------------------------------------------------
-- Scene management

-- Add a new object to the scene
function Hud:AddObject(obj, use_tex)
	if self.objects[obj] then return obj end
	if obj._destroyed then error("Cannot add a destroyed object") end
	
	self.objects[obj] = true
	self.num_objs = self.num_objs + 1
	
	obj.frame = Hud:AllocObjFrame(use_tex)
	obj.tex = obj.frame.tex
	obj.attached = {}
	
	C_Timer.After(0, function() Hud:Show() end)
	return obj
end

-- Remove an object from the scene
function Hud:RemoveObject(obj)
	if not self.objects[obj] then return end
	obj._destroyed = true
	
	for i, pt in ipairs(obj.attached) do
		pt:DetachObject(obj)
	end
	
	self.objects[obj] = nil
	self.num_objs = self.num_objs - 1
	
	if obj.OnRemove then obj:OnRemove() end
	Hud:ReleaseObjFrame(obj.frame)
end

-- Clear the whole scene
function Hud:Clear()
	for obj in next, self.objects do
		obj:Remove()
	end
end

--------------------------------------------------------------------------------
-- API

-- Line
do
	function Hud:DrawLine(from, to, width)
		local line = self:CreateObject({ width = width or 32 }, true)
		
		from = line:UsePoint(from)
		to = line:UsePoint(to)
		
		line.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\line")
		line.tex:SetVertexColor(0.5, 0.5, 0.5, 1)
		
		function line:Update()
			local sx, sy = from.x, from.y
			local ex, ey = to.x, to.y
			
			-- Determine dimensions and center point of line
			local dx, dy = ex - sx, ey - sy
			local cx, cy = (sx + ex) / 2, (sy + ey) / 2
			local w = self.width
			
			-- Normalize direction if necessary
			if dx < 0 then
				dx, dy = -dx, -dy;
			end
			
			-- Calculate actual length of line
			local l = (dx * dx + dy * dy) ^ 0.5
			
			-- Quick escape if it's zero length
			if l == 0 then
				self.frame:ClearAllPoints()
				self.frame:SetPoint("BOTTOMLEFT", hud, "CENTER", cx, cy)
				self.frame:SetPoint("TOPRIGHT",   hud, "CENTER", cx, cy)
				self.tex:SetTexCoord(0,0,0,0,0,0,0,0)
				return
			end
			
			-- Sin and Cosine of rotation, and combination (for later)
			local s, c = -dy / l, dx / l
			local sc = s * c
			
			-- Calculate bounding box size and texture coordinates
			local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
			if dy >= 0 then
				Bwid = ((l * c) - (w * s)) / 2
				Bhgt = ((w * c) - (l * s)) / 2
				BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
				BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
				TRy = BRx;
			else
				Bwid = ((l * c) + (w * s)) / 2
				Bhgt = ((w * c) + (l * s)) / 2
				BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
				BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
				TRx = TLy
			end
			
			self.frame:ClearAllPoints()
			self.frame:SetPoint("BOTTOMLEFT", hud, "CENTER", cx - Bwid, cy - Bhgt)
			self.frame:SetPoint("TOPRIGHT",   hud, "CENTER", cx + Bwid, cy + Bhgt)
			self.tex:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
		end
		
		return line
	end
end

function Hud:DrawCircle(center, radius)
	
end

function Hud:DrawAoE(center, radius)
	local aoe = self:CreateObject({ radius = radius or 10 }, true)
	
	center = aoe:UsePoint(center)
	
	line.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\line")
	line.tex:SetVertexColor(0.5, 0.5, 0.5, 1)
end

function FS_TEST()
	local x, y = UnitPosition("player")
	local pt = Hud:CreateStaticPoint(x, y, "foo")
	pt:SetColor(0.5, 0.5, 0.5)
	Hud:DrawLine("player", pt, 52)
end
