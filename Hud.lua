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
	
	-- Projection settings
	self.px = 0
	self.py = 0
	self.sin = 0
	self.cos = 0
end

function Hud:OnEnable()
	self:DrawUnit("player")
	
	C_Timer.After(5, function()
		local x, y = UnitPosition("player")
		self:DrawPoint(x, y, { 0, 1, 0 })
	end)
end

function Hud:OnDisable()
	-- Clear all active objects on disable
	self:Clear()
end

--------------------------------------------------------------------------------
-- Visibility and updates

function Hud:Show()
	if self.visible then return end
	self:Print("activating HUD display")
	self.visible = true
	hud:SetAllPoints()
	hud:Show()
	self.ticker = C_Timer.NewTicker(0.035, function() self:OnUpdate() end)
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

function Hud:Project(x, y)
	local dx = self.px - x
	local dy = self.py - y
	local rx = dx * self.cos + dy * self.sin
	local ry = -dx * self.sin + dy * self.cos
	return rx, ry
end

function Hud:OnUpdate()
	-- Nothing to draw, auto-hide
	if self.num_objs == 0 then
		self:Hide()
		return
	end
	
	self.px, self.py = UnitPosition("player")
	local t = GetPlayerFacing() + pi_2
	self.cos = cos(t)
	self.sin = sin(t)
	
	for obj in next, self.objects do
		local x, y = obj:Position()
		if not x then
			obj:Remove()
		else
			if obj.Update then
				obj:Update()
			end
			local rx, ry = self:Project(x, y)
			obj.frame:SetPoint("CENTER", hud, "CENTER", rx * 10, ry * 10)
		end
	end
end

--------------------------------------------------------------------------------
-- Object frame pool

do
	local pool = {}
	
	local function normalize(frame)
		frame:SetFrameStrata("BACKGROUND")
		frame:ClearAllPoints()
		
		frame.tex:SetAllPoints()
		frame.tex:Hide()
		
		frame:Show()
		return frame
	end
	
	function Hud:AllocObjFrame()
		if #pool > 0 then
			return normalize(table.remove(pool))
		else
			local frame = CreateFrame("Frame", nil, hud)
			frame.tex = frame:CreateTexture(nil, "OVERLAY")
			return normalize(frame)
		end
	end
	
	function Hud:ReleaseObjFrame(frame)
		frame:Hide()
		table.insert(pool, tex)
	end
end

--------------------------------------------------------------------------------
-- Objects interface

local HudObject = {}

function HudObject:Init() end
function HudObject:Position() end

-- Alias to Hud:RemoveObject()
function HudObject:Remove()
	Hud:RemoveObject(self)
end

function HudObject:SetSize(w, h)
	self.frame:SetSize(w, h)
end

function HudObject:SetTex(path)
	self.tex:SetTexture(path)
	self.tex:Show()
end

function HudObject:SetTexColor(r, g, b)
	self.tex:SetVertexColor(r, g, b)
end

function Hud:CreateObject(proto)
	return setmetatable(proto or {}, { __index = HudObject })
end

--------------------------------------------------------------------------------
-- Scene management

-- Add a new object to the scene
function Hud:AddObject(obj)
	if self.objects[obj] then return obj end
	if obj._destroyed then error("Cannot add a destroyed object") end
	
	self.objects[obj] = true
	self.num_objs = self.num_objs + 1
	
	obj.frame = Hud:AllocObjFrame()
	obj.tex = obj.frame.tex
	
	obj:Init()
	Hud:Show()
	return obj
end

-- Remove an object from the scene
function Hud:RemoveObject(obj)
	if not self.objects[obj] then return end
	obj._destroyed = true
	
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

-- Point
do
	local gray = { 0.5, 0.5, 0.5 }
	
	function Hud:DrawPoint(x, y, color)
		local p = self:CreateObject({ x = x or 0, y = y or 0, color = color or gray })
		
		function p:Init()
			self:SetSize(16, 16)
			self:SetTex("Interface\\AddOns\\BigWigs\\Textures\\blip")
			self:SetTexColor(unpack(self.color))
		end
		
		function p:Position()
			return self.x, self.y
		end
		
		return self:AddObject(p)
	end
end

-- Units
do
	-- Currently drawn units
	local active_units = {}
	
	-- Draw a specific unit
	function Hud:DrawUnit(unit)
		local guid = UnitGUID(unit)
		if active_units[guid] then return end
		
		local point = self:DrawPoint(0, 0, { FS:GetClassColor(unit, true) })
		active_units[guid] = point
		
		-- Overload the Point.Position function
		function point:Position()
			return UnitPosition(unit)
		end
		
		-- Track user raid target icon
		local display_rt = nil
		local display_class = nil
		
		function point:Update()
			local rt = GetRaidTargetIndex(unit)
			if display_rt ~= rt then
				if rt then
					point:SetSize(24, 24)
					point:SetTex("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcon_" .. rt .. ".blp")
					point:SetTexColor(1, 1, 1)
					display_class = nil
				elseif not rt then
					point:SetSize(16, 16)
					point:SetTex("Interface\\AddOns\\BigWigs\\Textures\\blip")
				end
				display_rt = rt
			end
			
			local class = UnitClass(unit)
			if not rt and display_class ~= class then
				point:SetTexColor(FS:GetClassColor(unit, true))
				display_class = class
			end
		end
		
		function point:OnRemove()
			active_units[guid] = nil
		end
		
		return point
	end
	
	-- Draw all units of the raid
	function Hud:DrawAllUnits()
		if IsInRaid() then
			for i = 1, GetNumGroupMembers() do
				self:DrawUnit("raid" .. i)
			end
		end
	end
end
