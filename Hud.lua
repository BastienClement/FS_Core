local _, FS = ...
local Hud = FS:RegisterModule("Hud")
local Map, Geometry, Tracker

-- Math aliases
local sin, cos, atan2, abs = math.sin, math.cos, math.atan2
local abs, floor, min, max = math.abs, math.floor, math.min, math.max
local pi2, pi_2 = math.pi * 2, math.pi / 2

-- Geometry aliases
local GDistance, GRotatePoint, GAngleDelta, GPointVectorDistance
local GPointInTriangle, GPointInPolygon

local Makers_Color = {
	{ 0.98, 0.93, 0.33 },
	{ 1.00, 0.57, 0.00 },
	{ 0.84, 0.30, 0.91 },
	{ 0.16, 0.89, 0.13 },
	{ 0.46, 0.69, 0.93 },
	{ 0.00, 0.57, 1.00 },
	{ 1.00, 0.23, 0.20 },
	{ 1.00, 0.98, 0.98 }
}

--------------------------------------------------------------------------------
-- HUD Frame

local hud
do
	hud = CreateFrame("Frame", "FSHud", UIParent)
	hud:Hide()
end

--------------------------------------------------------------------------------
-- Hud config

local hud_defaults = {
	profile = {
		enable = true,
		fps = 120,
		alpha = 1,
		scale = 10,
		offset_x = 0,
		offset_y = 0,
		smoothing = true,
		smoothing_click = true,
		fade = true
	}
}

local function hud_test()
	local x, y = UnitPosition("player")
	
	local s1 = Hud:CreateStaticPoint(x+20, y+20):SetColor(0.8, 0, 0.8, 1)
	local s2 = Hud:CreateStaticPoint(x+30, y):SetColor(0, 0.8, 0.8, 1)
	local s3 = Hud:CreateSnapshotPoint("player"):SetColor(0.8, 0.8, 0, 1)

	local a1 = Hud:DrawArea(s1, 15)
	local a2 = Hud:DrawTarget(s2, 10):Fade(false)
	local a3 = Hud:DrawTimer(s3, 10, 10):SetColor(0.8, 0.8, 0, 0.5)
	local a4 = Hud:DrawRadius(s3, 20)
	
	function a2:OnUpdate()
		self:SetColor(abs(sin(GetTime())), abs(sin(GetTime() / 2)), abs(sin(GetTime() / 3)), 0.8)
	end
	
	function a3:OnDone()
		a3:Remove()
		a4:Remove()
	end
	
	Hud:DrawLine("player", s1, 128)
	Hud:DrawLine("player", s2):SetColor(0, 0.5, 0.8, 0.8)
	local l3 = Hud:DrawLine(s1, s2, 128)

	function l3:OnUpdate()
		if self:UnitDistance("player", true) < 1.5 then
			self:SetColor(0.8, 0, 0, 0.8)
		else
			self:SetColor(0, 0.8, 0, 0.8)
		end
	end
	
	function a1:OnUpdate()
	   self.radius = 15 + math.sin(GetTime() * 3)
	end
	
	local vertices = {}
	
	for i = 1, 8 do
		local r = math.random()
		table.insert(vertices, x + sin(i * pi2 / 8) * r * 40)
		table.insert(vertices, y + cos(i * pi2 / 8) * r * 40)
	end
	
	local poly = Hud:DrawPolygon(vertices)
	
	for _, t in ipairs(poly.triangles) do
		function t:OnUpdate()
			if self:UnitIsInside("player") then
				self:SetColor(0.4, 0.8, 0, 0.2)
			else
				self:SetColor(0.8, 0.4, 0, 0.2)
			end
		end
	end
	
	function poly:OnUpdate()
		if self:UnitIsInside("player", true) then
			self:SetBorderColor(0.4, 0.8, 0, 0.2)
		else
			self:SetBorderColor(0.8, 0.4, 0, 0.2)
		end
	end
end

local hud_config = {
	title = {
		type = "description",
		name = "|cff64b4ffHead-up display (HUD)",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Visual radar-like display over the whole screen used to show various boss abilities area of effect.\n",
		fontSize = "medium",
		order = 1
	},
	enable = {
		type = "toggle",
		name = "Enable",
		width = "full",
		get = function()
			return Hud.settings.enable
		end,
		set = function(_, value)
			Hud.settings.enable = value
			if value then
				Hud:Enable()
				if Hud.num_objs > 0 then
					Hud:Show()
				end
			else
				Hud:Disable()
			end
		end,
		order = 5
	},
	spacing_9 = {
		type = "description",
		name = "\n",
		order = 9
	},
	offset_x = {
		type = "range",
		name = "Offset X",
		min = -10000, max = 10000,
		softMin = -960, softMax = 960,
		bigStep = 1,
		get = function()
			return Hud.settings.offset_x
		end,
		set = function(_, value)
			Hud.settings.offset_x = value
			hud:SetPoint("CENTER", UIParent, "CENTER", value, Hud.settings.offset_y)
		end,
		order = 20
	},
	offset_y = {
		type = "range",
		name = "Offset Y",
		min = -10000, max = 10000,
		softMin = -540, softMax = 540,
		bigStep = 1,
		get = function()
			return Hud.settings.offset_y
		end,
		set = function(_, value)
			Hud.settings.offset_y = value
			hud:SetPoint("CENTER", UIParent, "CENTER", Hud.settings.offset_x, value)
		end,
		order = 21
	},
	fps = {
		type = "range",
		name = "Refresh rate",
		desc = "Number of refresh per seconds. Reducing this value can greatly reduce CPU usage. It will never be faster than your in-game FPS.",
		min = 10,
		max = 120,
		bigStep = 5,
		get = function()
			return Hud.settings.fps
		end,
		set = function(_, value)
			Hud.settings.fps = value
		end,
		order = 30
	},
	scale = {
		type = "range",
		name = "Scale",
		desc = "Number of pixels corresponding to 1 yard. You should keep the default 10 px/yd in most cases.",
		min = 2,
		max = 50,
		bigStep = 1,
		hidden = function()
			return FS.version ~= "dev"
		end,
		get = function()
			return Hud.settings.scale
		end,
		set = function(_, value)
			Hud.settings.scale = value
			Hud:SetZoom(value)
		end,
		order = 35
	},
	spacing_59 = {
		type = "description",
		name = "\n\n",
		order = 59
	},
	smooth = {
		type = "toggle",
		name = "Enable rotation smoothing",
		desc = "Enable smooth rotation when your character abruptly changes orientation.",
		width = "full",
		get = function()
			return Hud.settings.smoothing
		end,
		set = function(_, value)
			Hud.settings.smoothing = value
		end,
		order = 60
	},
	smooth_click = {
		type = "toggle",
		name = "Smooth right-click rotation",
		desc = "Smooth rotation even when done manually by right-clicking on the game world.",
		width = "full",
		get = function()
			return Hud.settings.smoothing_click
		end,
		set = function(_, value)
			Hud.settings.smoothing_click = value
		end,
		disabled = function()
			return not Hud.settings.smoothing
		end,
		order = 61
	},
	fade = {
		type = "toggle",
		name = "Enable fade-in-out animations",
		desc = "Enable animations on objects creation and removal.",
		width = "full",
		get = function()
			return Hud.settings.fade
		end,
		set = function(_, value)
			Hud.settings.fade = value
		end,
		order = 62
	},
	spacing_89 = {
		type = "description",
		name = "\n",
		order = 89
	},
	test = {
		type = "execute",
		name = "Test",
		func = hud_test,
		order = 100,
	},
	clear = {
		type = "execute",
		name = "Clear",
		func = function()
			Hud:Clear()
		end,
		order = 101,
	},
	cmds_spacing = {
		type = "description",
		name = "\n",
		order = 1000
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	cmds = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"clear", "Reset the HUD and removes every objects on it."},
		{"test", "Displays test objects."},
	}, "/fs hud "),
	public_api = FS.Config:MakeDoc("Public API", 3000, {
		{":Project ( x , y ) -> x , y", "Project the given game-world coordinates to on-screen coordinates, relative to the HUD center (player)."},
		{":Unproject ( x , y , raw ) -> x , y", "Perform the inverse operation. If raw, will not consider the HUD zoom factor."},
		{":Clear ( )", "Remove every created objects from the HUD."},
	}, "FS.Hud"),
	points_api = FS.Config:MakeDoc("Points API", 3100, {
		{":CreatePoint ( name ) -> point", "Create a generic point object. You must provide a point:Position() method returning game-world coordinates for this point. If name is not given a random name will be generated."},
		{":CreateStaticPoint ( x , y , name ) -> point", "Create a point object with static world coordinates."},
		{":CreateFixedPoint ( x , y , name ) -> point", "Create a point object with fixed on-screen coordinates. Coordinates are in yards, relative to the player. You must overload the point:FixedPosition() if you want dynamic x and y."},
		{":CreateSnapshotPoint ( point , name ) -> point", "Create a static point object at the current location of another point."},
		{":CreateShadowPoint ( point , name , fast ) -> point", "Create a point object replicating the position of another point. The reference point is available as point.ref. If fast, ref:FastPosition() will be used instead of ref:Position()."},
		{":RegisterTrackerPoint ( guid ) -> point", "Create a point object at the estimated location of an hostile unit, as provided by the Tracker module."},
		{":GetPoint ( name , exact ) -> point", "Return the point with the given name. If given a point instead of the name, return this point. If there is no point with the given name but exact is false or nil, attempt to find a point by treating name as an unitid or a GUID."},
		{":RemovePoint ( name )", "Remove a point from the HUD."},
		{":IteratePoints ( ) -> [ name , point ]", "Return an iterator over every created points."},
		{":Distance ( point , point ) -> number", "Return the distance between the two points."},
	}, "FS.Hud"),
	points_instance_api = FS.Config:MakeDoc("Point instance API", 3200, {
		{":SetColor ( r , g , b , a ) -> point", "Set the point color."},
		{":SetMarkerColor ( marker , a ) -> point", "Set the point color to match a raid marker color."},
		{":AlwaysVisible ( state ) -> point", "Set the point to be always visible. By default, points with no attached objects are not visible."},
		{":Persistent ( state ) -> point", "Define the persistent flag. Persistent points are not removed on ENCOUNTER_END."},
		{":Position ( ) -> x , y", "Return the game-world position of this point."},
		{":FastPosition ( ) -> x , y", "Same as point:Position() but can be one frame late because of caching."},
		{":PointDistance ( x , y ) -> number", "Return the game-world distance between this point and the given coordinates."},
		{":UnitDistance ( unit ) -> number", "Return the game-world distance between this point and the given unit."},
		{":Remove ( )", "Remove the point. Should not be called on HUD-managed points like raid units."},
		{":OnRemove ( )", "You can implement this method to be notified when the point has been removed."},
	}, "point"),
	obj_api = FS.Config:MakeDoc("Objects API", 3500, {
		{":CreateObject ( proto , use_tex ) -> object", "Generic object factory. Look at code to learn how to use it."},
		{":RemoveObject ( name )", "Remove an object with the given name. You must have called object:Register() on it."},
		{":IterateObjects ( ) -> [ object ]", "Return an iterator over every created ojects."},
		{":DrawLine ( from , to , width ) -> line_object", "Draw a line between points from and to. Width is optional and defaults to 64."},
		{":DrawTexture ( center , width , height , texture ) -> tex_object", "Draw a texture. If height is not given, texture is supposed to be square."},
		{":DrawMarker ( center , size , idx ) -> tex_object", "Draw a raid target marker texture with given size in yard."},
		{":DrawCircle ( center , radius , tex ) -> circle_object", "Draw a circle texture with given radius in yard."},
		{":DrawRadius ( center , radius ) -> circle_object", "Draw a radius circle."},
		{":DrawArea ( center , radius  ) -> circle_object", "Draw a filled area circle."},
		{":DrawTarget ( center , radius ) -> circle_object", "Draw a rotating filled target circle."},
		{":DrawTimer ( center , radius , duration ) -> timer_object", "Draw a rotating filled target circle."},
		{":DrawTriangle ( a , b , c ) -> polygon_object", "Draw a triangle between the three given points."},
		{":DrawPolygon ( args , border , border_only ) -> polygon_object", "Draw a polygon. args can be a list of points or a list of coordinates { ax, ay, bx, by, ... }. Border will be given to :DrawLine. If border-only, the polygon will not be filled. You should not draw complex polygons."},
		{":DrawPolyLine ( from , to , width , border ) -> polyline_object", "Draw a line between from and to, as a polygon. In constrast to :DrawLine(), width is given in yards. The border argument is given to :DrawPolygon."},
		{":DrawDummy ( point ) -> dummy_object", "Create an invisible dummy object."},
	}, "FS.Hud"),
	obj_instance_api = FS.Config:MakeDoc("Generic HudObject instance API", 3600, {
		{":SetColor ( r , g , b , a ) -> object", "Set the object color."},
		{":SetMarkerColor ( marker , a ) -> object", "Set the object color to match a raid marker color."},
		{":ShowAllPoints ( state ) -> object", "If state is true, this object will make every points visible until removed."},
		{":Persistent ( state ) -> point", "Define the persistent flag. Persistent objects are not removed on ENCOUNTER_END."},
		{":Fade ( state ) -> object", "If state is false, fade-in-out animations will be disabled for this object."},
		{":Register ( name ) -> object", "Define a name for this object. If another object already exists with this name, it is removed."},
		{":Remove ( )", "Remove the object."},
		{":OnUpdate ( )", "You can implement this method to be notified when the object has been updated."},
		{":OnRemove ( )", "You can implement this method to be notified when the object has been removed."},
	}, "object"),
	line_instance_api = FS.Config:MakeDoc("LineObject instance API (extends HudObject)", 3700, {
		{".width", "The line width."},
		{":PointDistance ( x , y , strict ) -> number", "Return the distance from this point to the line. If the point's projection falls outside the segment and strict is true, -1 is returned; else the distance to the closest end is returned."},
		{":UnitDistance ( unit , strict ) -> number", "Same as PointDistance, but with the unit's position."},
	}, "line_object"),
	tex_instance_api = FS.Config:MakeDoc("TexObject instance API (extends HudObject)", 3710, {
		{":SetBlendMode ( blend ) -> tex_object", "Change the texture blending mode. See Texture:SetBlendMode()."},
	}, "tex_object"),
	circle_instance_api = FS.Config:MakeDoc("CircleObject instance API (extends HudObject)", 3720, {
		{".radius", "The circle radius"},
		{":PointIsInside ( x , y ) -> bool", "Check if the given world coordinates are inside the circle."},
		{":UnitIsInside ( unit ) -> bool", "Check if the given unit is inside the circle."},
		{":UnitsInside ( ) -> { unitids }", "Return the list of group units inside the circle."},
		{":Rotate ( ) -> number", "You can define this method to add a rotate effect to the circle."},
	}, "circle_object"),
	timer_instance_api = FS.Config:MakeDoc("TimerObject instance API (extends CircleObject)", 3730, {
		{":Reset ( duration ) -> timer_object", "Restart the time with the given duration."},
	}, "timer_object"),
	polygon_instance_api = FS.Config:MakeDoc("PolygonObject instance API (extends HudObject)", 3740, {
		{":PointIsInside ( x , y ) -> bool", "Check if the given world coordinates are inside the polygon."},
		{":UnitIsInside ( unit ) -> bool", "Check if the given unit is inside the polygon."},
	}, "polygon_object"),
	polyline_instance_api = FS.Config:MakeDoc("PolyLineObject instance API (extends PolygonObject)", 3750, {
		{":Overrun ( v ) -> polyline_object", "Define the line overrun distance."},
	}, "polyline_object"),
	events = FS.Config:MakeDoc("Emitted events", 5000, {
		{"_UPDATE ( )", "Emitted at the begining of an HUD update."},
	}, "FS_HUD")
}

--------------------------------------------------------------------------------
-- Module initialization

function Hud:OnInitialize()
	Map = FS:GetModule("Map")
	Geometry = FS:GetModule("Geometry")
	Tracker = FS:GetModule("Tracker")
	
	GDistance = Geometry.Distance
	GRotatePoint = Geometry.RotatePoint
	GAngleDelta = Geometry.AngleDelta
	GPointVectorDistance = Geometry.PointVectorDistance
	GPointInTriangle = Geometry.PointInTriangle
	GPointInPolygon = Geometry.PointInPolygon
	
	-- Create config database
	self.db = FS.db:RegisterNamespace("HUD", hud_defaults)
	self.settings = self.db.profile
	
	-- Config enable state
	self:SetEnabledState(self.settings.enable)
	
	-- Set HUD global settings
	hud:SetAlpha(self.settings.alpha)
	self:SetZoom(self.settings.scale)
	
	-- Points
	self.points = {}
	
	-- Object currently drawn on the HUD
	self.objects = {}
	self.num_objs = 0
	
	FS:GetModule("Config"):Register("Head-up display", hud_config)
	FS:GetModule("Console"):RegisterCommand("hud", self)
end

function Hud:OnEnable()
	-- Refresh raid points if the group roster changes
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "RefreshRaidPoints")
	
	-- Clear the HUD on ENCOUNTER_END
	-- This prevents bogus modules or encounters to keep the HUD open
	self:RegisterEvent("ENCOUNTER_END", "ClearEncounter")
	
	self:UpdateGeometrySnapshot()
end

function Hud:OnDisable()
	-- Clear all active objects on disable
	self:Clear()
end

function Hud:OnSlash(arg1, arg2)
	if arg1 == "clear" then
		self:Clear()
	elseif arg1 == "test" then
		hud_test()
	end
end

--------------------------------------------------------------------------------
-- Object frame pool

do
	local pool = {}
	
	local function normalize(frame, use_tex)
		frame:SetFrameStrata("BACKGROUND")
		frame:SetAlpha(1)
		frame:ClearAllPoints()
		
		frame.tex:SetAllPoints()
		frame.tex:SetDrawLayer("ARTWORK")
		frame.tex:SetBlendMode("BLEND")
		frame.tex:SetTexCoord(0, 1, 0, 1)
		
		if use_tex then
			frame.tex:Show()
		else
			frame.tex:Hide()
		end
		
		--frame:Show()
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
		table.insert(pool, frame)
	end
end

--------------------------------------------------------------------------------
-- Points

do
	-- Construct a point
	function Hud:CreatePoint(name)
		-- Generate a random name if anonymous
		if not name then
			name = tostring(GetTime()) + tostring(math.random())
		end
		
		-- If the point is already defined, return the old one
		-- This behaviour is intended to be exceptional, a point should not
		-- be created multiple times under normal circumstances
		if self.points[name] then
			self:Printf("Detected name conflict on point creation ('%s')", name)
			return self.points[name]
		end
		
		local point
		
		local function alloc_frame()
			if point.has_frame then return end
			
			point.frame = Hud:AllocObjFrame(true)
			point.tex = point.frame.tex
			
			point.frame:SetSize(16, 16)
			point.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\blip")
			point.tex:SetVertexColor(1, 1, 1, 0)
			point.tex:SetDrawLayer("OVERLAY")
					
			point.has_frame = true
		end
		
		point = setmetatable({ __point = true }, {
			__index = function(self, key)
				if key == "frame" or key == "tex" then
					alloc_frame()
					return self[key]
				end
			end
		})
		
		point.name = name
		self.points[name] = point
		
		--[[
		point.frame = Hud:AllocObjFrame(true)
		point.tex = point.frame.tex
		
		point.frame:SetSize(16, 16)
		point.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\blip")
		point.tex:SetVertexColor(1, 1, 1, 0)
		point.tex:SetDrawLayer("OVERLAY")
		]]
		point.has_frame = false
		point.hidden = true
		
		point.x = 0
		point.y = 0
		point.world_x = -1
		point.world_y = -1
		point.fixed = false
		
		point.attached = {}
		point.num_attached = 0
		
		point.persistent = false
		
		-- Define the corresponding unit for this point
		function point:SetUnit(unit)
			self.unit = unit
			self:RefreshUnit()
			alloc_frame()
			return self
		end
		
		-- Change the point color
		function point:SetColor(r, g, b, a)
			self.tex:SetVertexColor(r, g, b, a or 1)
			return self
		end
		
		function point:SetMarkerColor(marker, a)
			local color = Makers_Color[marker]
			if color then
				local r, g, b = unpack(color)
				return self:SetColor(r, g, b, a)
			else
				return self
			end
		end
		
		-- Define the always_visible flag
		-- An always_visible point is shown event if no show_all_points objects
		-- are currently present
		function point:AlwaysVisible(state)
			if state == nil then
				return self.always_visible
			end
			self.always_visible = state
			return self
		end
		
		-- Define the persistent flag
		-- Persistent points are not removed on ENCOUNTER_END
		function point:Persistent(state)
			if state == nil then
				return self.persistent
			end
			self.persistent = state
			return self
		end
		
		-- Update the point position and properties
		function point:Update()
			-- Ensure unit still exists
			if self.unit and not UnitExists(self.unit) then
				self:Remove()
				return
			end
			
			if self.fixed then
				local fx, fy = self:FixedPosition()
				local zoom = Hud:GetZoom()
				
				self.x = fx * zoom
				self.y = fy * zoom
				
				-- Set world x and y coordinates
				self.world_x, self.world_y = self:Position()
			else
				-- Fetch point position
				local x, y = self:Position()
				if not x then return end
				
				-- Set world x and y coordinates
				self.world_x = x
				self.world_y = y
				
				-- Project point
				self.x, self.y = Hud:Project(x, y)
			end
			
			-- Decide if the point is visible or not
			if self.has_frame then
				if self.num_attached > 0 -- If the point has an attached object
				or self.always_visible   -- If the point is always_visible
				or Hud.show_all_points   -- If at least one object requests all points to be visible
				or Hud.force then        -- If the HUD is in forced mode
					-- Place the point
					self.frame:SetPoint("CENTER", hud, "CENTER", self.x, self.y)
					if self.hidden then
						-- Show the point if currently hidden
						self.hidden = false
						self.frame:Show()
					end
				elseif not self.hidden then
					-- Hide the wrapper frame to keep point color intact
					self.hidden = true
					self.frame:Hide()
					return
				end
				
				-- Unit point specifics
				if self.unit then
					-- Hide the point if the unit is dead
					if UnitIsDeadOrGhost(self.unit) then
						if not self.unit_ghost then
							self.tex:SetVertexColor(1, 1, 1, 0)
							self.unit_ghost = true
						end
						return
					elseif self.unit_ghost then
						self.unit_ghost = false
						
						-- Reset the unit class, this will cause the color to be reset 
						self.unit_class = nil
					end
					
					-- Ensure the point color reflect the unit class
					local class = UnitClass(self.unit)
					if not self.unit_ghost and self.unit_class ~= class then
						self.tex:SetVertexColor(FS:GetClassColor(self.unit, true))
						self.unit_class = class
					end
				end
			end
		end
			
		
		-- Ensure the unit association of this point is correct
		function point:RefreshUnit()
			if self.unit then
				-- Check that "raidX" is still the same player
				local guid = UnitGUID(self.unit)
				if guid ~= self.name then
					-- Attempt to find the new raid unit corresponding to the player
					for _, unit in FS:IterateGroup() do
						if UnitGUID(unit) == self.name then
							-- Update the unit id
							self.unit = unit
							return
						end
					end
					
					-- This player is no longer in the raid
					-- Remove the point
					self:Remove()
				end
			end
		end
		
		-- Attach an object to this point
		-- The object will be :Remove()'ed when this point is removed
		function point:AttachObject(obj)
			if not self.attached[obj] then
				self.attached[obj] = true
				point.num_attached = point.num_attached + 1
			end
		end
		
		-- Remove the point and any attached objects
		local removed = false
		function point:Remove()
			-- Impossible to remove player point
			if self.unit == "player" then return end
			
			-- Ensure the function is not called two times
			if removed then return end
			removed = true
			
			-- Release frame
			if self.has_frame then
				Hud:ReleaseObjFrame(self.frame)
			end
			
			-- Point itself
			Hud.points[self.name] = nil
			
			-- Remove attached objects
			local do_ghost = false
			for obj in pairs(self.attached) do
				if obj.fade then do_ghost = true end
				obj:Remove()
			end
			
			if do_ghost then
				local ghost_start = GetTime()
				local ticker
				ticker = C_Timer.NewTicker(0.033, function()
					point.x, point.y = Hud:Project(point.world_x, point.world_y)
					if GetTime() - ghost_start > 0.5 then
						ticker:Cancel()
						ticker = nil
					end
				end)
			end
			
			-- Remove handler
			if self.OnRemove then
				self:OnRemove()
			end
		end
		
		-- Detach an object
		function point:DetachObject(obj)
			-- Do not remove object once the point deletion process has started
			if removed then return end
			if self.attached[obj] then
				self.attached[obj] = nil
				point.num_attached = point.num_attached - 1
			end
		end
		
		-- Point distance to this point
		function point:PointDistance(x, y)
			if not x or not y then return end
			return GDistance(x, y, self.world_x, self.world_y)
		end
		
		-- Unit distance to this point
		function point:UnitDistance(unit)
			return self:PointDistance(UnitPosition(unit))
		end
		
		-- Return the cached world position for this point
		function point:FastPosition()
			if self.world_x < 0 then
				self.world_x, self.world_y = self:Position(true)
			end
			return self.world_x, self.world_y
		end
		
		function point:AttachTo(parent)
			parent = Hud:GetPoint(parent)
			if parent then
				if self.parent then
					self.parent:DetachObject(self)
				end
				parent:AttachObject(self)
				self.parent = parent
			end
			return self
		end
		
		function point:OnRemove()
			if self.parent then
				self.parent:DetachObject(self)
				self.parent = nil
			end
		end
		
		return point
	end
	
	-- Create a static point
	function Hud:CreateStaticPoint(x, y, name)
		local pt = self:CreatePoint(name)
		function pt:Position() return x, y end
		return pt
	end
	
	-- Create a fixed point
	function Hud:CreateFixedPoint(x, y, name)
		local pt = self:CreatePoint(name)
		
		pt.fixed = true
		function pt:FixedPosition() return x, y end
		
		function pt:Position()
			local x, y = self:FixedPosition()
			return Hud:Unproject(x, y, true)
		end
		
		function pt:Lock(no_snapshot)
			if not no_snapshot then
				local zoom = Hud:GetZoom()
				local x, y = self:FixedPosition()
				self.x = x * zoom
				self.y = y * zoom
				self.world_x, self.world_y = self:Position()
			end
			Hud.points[self.name] = nil
			return self
		end
		
		function pt:Unlock()
			Hud.points[self.name] = self
			return self
		end
		
		return pt
	end
	
	-- Snapshot point is a static point at another point current location
	function Hud:CreateSnapshotPoint(pt, name)
		-- Snapshot points requires raid points
		self:RefreshRaidPoints()
		
		local ref = self:GetPoint(pt)
		if not ref then
			self:Printf("Snapshot point creation failed: unable to get the reference point ('%s')", tostring(pt))
			return
		end
		
		local x, y = ref:Position(true)
		return self:CreateStaticPoint(x, y, name)
	end
	
	-- Create a shadow point
	function Hud:CreateShadowPoint(pt, name, fast)
		-- Shadow points are actually half object
		-- Since we usually attach them to unit point, refresh them now
		self:RefreshRaidPoints()
		
		-- Get the reference point
		local ref = self:GetPoint(pt)
		if not ref then
			self:Printf("Shadow point creation failed: unable to get the reference point ('%s')", tostring(pt))
			return
		end
		
		local shadow = self:CreatePoint(name)
		shadow.ref = ref
		
		-- Mirror reference point
		if fast then
			function shadow:Position()
				return ref:FastPosition()
			end
		else
			function shadow:Position()
				return ref:Position()
			end
		end
		
		-- Consider the shadow point as an object attached to the reference point
		-- This will cause the shadow point to be removed if the reference point is removed
		return shadow:AttachTo(ref)
	end
	
	-- Create a point following the estimated position of an hostile unit
	function Hud:RegisterTrackerPoint(guid)
		local pt = self:GetPoint(guid, true)
		if pt then return pt end
		
		pt = self:CreatePoint(guid)
		pt.guid = guid
		
		local lx, ly = -1, -1
		
		function pt:Position(force)
			if self.num_attached < 1 and not force then
				return lx, ly
			end
		
			local x, y = Tracker:GetPosition(guid)
			if not x then
				C_Timer.After(0, function() self:Remove() end)
				return lx, ly
			end
			
			if lx then
				local dx = x - lx
				local dy = y - ly
				if (dx * dx + dy * dy) < 2500 then
					x = lx + dx / 5
					y = ly + dy / 5
				end
			end
			
			lx, ly = x, y
			return x, y
		end
		
		return pt
	end
	
	-- Iterates over all points
	function Hud:IteratePoints()
		return pairs(self.points)
	end
	
	-- Return a point
	function Hud:GetPoint(name, exact)
		-- Y U NO HAZ NAME ?
		if not name then
			self:Print("Attempted to get a point with a nil name")
			return
		end
		
		-- We actually got a point, return it
		if name.__point then return name end
		
		-- Fetch by name
		local pt = self.points[name]
		
		if pt or exact then
			return pt
		elseif UnitExists(name) then
			-- Requested a unit point, lookup by GUID
			return self:GetPoint(UnitGUID(name))
		elseif select(2, name:gsub("%-", "", 2)) == 1 then
			-- No point found, but the name has one "-" in it. This may be the case
			-- with cross-realm units. Try again without the server name.
			return self:GetPoint(name:match("^[^-]+"))
		end
		
		-- No point matches
		-- Returning nothing
	end
	
	-- Remove a point
	function Hud:RemovePoint(name)
		local pt = self:GetPoint(name)
		if pt then
			pt:Remove()
		end
	end
	
	-- Distance between two points
	function Hud:Distance(pt1, pt2)
		pt1 = self:GetPoint(pt1)
		pt2 = self:GetPoint(pt2)
		if not pt1 or not pt2 then
			return
		else
			local x, y = pt2:FastPosition()
			return pt1:PointDistance(x, y)
		end
	end
	
	-- Create a vector from pt1 to pt2
	function Hud:Vector(pt1, pt2, length)
		pt1 = self:GetPoint(pt1)
		pt2 = self:GetPoint(pt2)
		if not pt1 or not pt2 then return end
		
		-- Default to unit vector
		if not length then length = 1 end
		
		local pt1x, pt1y = pt1:FastPosition()
		local pt2x, pt2y = pt2:FastPosition()
		
		local l = GDistance(pt1x, pt1y, pt2x, pt2y)
		if l == 0 then return 0, 0 end
		
		local dx, dy = pt2x - pt1x, pt2y - pt1y
		
		return dx * length / l, dy * length / l
	end
end

-- Automatically create points for raid units
do
	-- Create point for a specific unit
	local function create_raid_point(unit)
		if not Hud:GetPoint(unit) and not UnitIsUnit(unit, "player") then
			local unit_name = UnitName(unit)
			-- Ensure unit name is currently available
			if unit_name and unit_name ~= UNKNOWNOBJECT then
				local pt = Hud:CreatePoint(UnitGUID(unit))
				pt:SetUnit(unit)
				function pt:Position()
					return UnitPosition(self.unit)
				end
			end
		end
	end
	
	-- Refresh all raid members points
	local player_pt
	local refresh_done = false
	function Hud:RefreshRaidPoints()
		-- Prevent more than one raid point refresh per frame
		if refresh_done then return end
		C_Timer.After(0, function() refresh_done = false end)
		refresh_done = true
		
		-- Create the player point if not already done
		if not player_pt and UnitName("player") ~= UNKNOWNOBJECT then
			player_pt = Hud:CreatePoint(UnitGUID("player"))
			player_pt:SetUnit("player")
			function player_pt:Position()
				return UnitPosition("player")
			end
		
			-- The player point is always visible
			player_pt:AlwaysVisible(true)
			
			-- The player point should be drawn over everything else
			player_pt.frame:SetFrameStrata("HIGH")
		end
		
		-- Refresh units of all raid points
		for n, pt in self:IteratePoints() do
			pt:RefreshUnit()
		end
		
		-- Find unit currently available without associated raid points
		for _, unit in FS:IterateGroup() do
			local pt = self:GetPoint(UnitGUID(unit))
			if not pt or pt.unit ~= unit then
				-- We got a point, but that is a bad one
				if pt then pt:Remove() end
				create_raid_point(unit)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Visibility and updates

function Hud:Show(force)
	if self.visible or not self:IsEnabled() then return end
	
	self.visible = true
	self.force = force
	
	-- Update show all points setting
	self:UpdateShowAllPoints()
	
	-- Reset the rotation smoothing feature
	self:ResetRotationSmoothing()
	
	-- Create the update ticker
	-- TODO: use 0.035 for low CPU mode, but using the game framerate feel much better
	self.ticker = C_Timer.NewTicker(1 / self.settings.fps, function() self:OnUpdate() end)
	
	-- Delay the first update a bit to prevent side effects on Show() call
	C_Timer.After(0, function() self:OnUpdate() end)
	
	-- Display the master frame
	hud:SetSize(UIParent:GetSize())
	hud:SetPoint("CENTER", UIParent, "CENTER", self.settings.offset_x, self.settings.offset_y)
	hud:Show()
end

function Hud:Hide()
	if not self.visible then return end
	
	-- This the master frame
	self.visible = false
	hud:Hide()
	
	-- Stop the update ticker
	self.ticker:Cancel()
	
	-- Clear all points on hide
	self:Clear()
end

do
	-- Variables used for point projection
	-- Player position
	local px = 0
	local py = 0
	
	-- Sine and cosine of player facing angle
	local a, last_a = 0, 0
	local sin_a, sin_am = 0, 0
	local cos_a, cos_am = 0, 0
	
	-- Zoom factor
	local zoom = 10
	
	function Hud:UpdateGeometrySnapshot()
		-- Fetch player position and facing for projection
		px, py = UnitPosition("player")
		a = GetPlayerFacing() + pi_2
		
		local ea
		if self.settings.smoothing and (not IsMouseButtonDown(2) or self.settings.smoothing_click) then
			local da = GAngleDelta(last_a, a)
			ea = (abs(da) < 0.1) and a or (last_a + (da / 3))
		else
			ea = a
		end
		
		last_a = ea
		cos_a, cos_am = cos(ea), cos(-ea)
		sin_a, sin_am = sin(ea), sin(-ea)
	end
	
	-- Set the zoom factor, 1yd is equal to this value in pixels
	function Hud:SetZoom(z)
		zoom = z
	end
	
	-- Get the HUD zoom factor
	function Hud:GetZoom()
		return zoom
	end
	
	-- Reset the last rotation angle to prevent rotation smoothing on show
	function Hud:ResetRotationSmoothing()
		last_a = GetPlayerFacing() + pi_2
	end
	
	-- Project a world point on the screen
	function Hud:Project(x, y)
		-- Delta relative to player position
		local dx = px - x
		local dy = py - y
		
		-- Rotate according to player facing direction
		local rx, ry = GRotatePoint(dx, dy, a, nil, nil, sin_a, cos_a)
		
		-- Multiply by zoom factor
		return rx * zoom, ry * zoom
	end
	
	-- Inverse function of Project
	function Hud:Unproject(zx, zy, unzoomed)
		local rx, ry
		if unzoomed then
			rx, ry = zx, zy
		else
			rx, ry = zx / zoom, zy / zoom
		end
		local dx, dy = GRotatePoint(rx, ry, -a, nil, nil, sin_am, cos_am)
		return px - dx, py - dy
	end
	
	-- Safety helper to update points and objects
	local function obj_update(obj)
		-- Use pcall to prevent an external error to freeze the HUD
		local success, err = pcall(obj.Update, obj)
		if not success then
			-- If more than 5 failures are caused by this object, remove it
			obj._err_count = (obj._err_count or 0) + 1
			if obj._err_count > 5 then
				if FS.version == "dev" then
					Hud:Printf("Error during update...\n%s", err)
				end
				obj:Remove()
			end
		end
	end

	-- Update the HUD
	function Hud:OnUpdate()
		-- Nothing to draw, auto-hide
		if not self.force and self.num_objs == 0 then
			self:Hide()
			return
		end
		
		self:UpdateGeometrySnapshot()
		self:SendMessage("FS_HUD_UPDATE")
		
		-- Update all points
		for name, obj in self:IteratePoints() do
			obj_update(obj)
		end
		
		-- Update all objects
		for obj in Hud:IterateObjects() do
			obj_update(obj)
		end
	end
end

--------------------------------------------------------------------------------
-- Objects interface

local HudObject = {}

-- Dummy update function
function HudObject:Update()
	if self.OnUpdate then self:OnUpdate() end
end

-- Helper function to get a point and register the object with it
function HudObject:UsePoint(name)
	local pt = Hud:GetPoint(name)
	if not pt then
		Hud:Printf("Failed to find a point required by a new object ('%s')", name or "nil")
		return
	end
	table.insert(self.attached, pt)
	pt:AttachObject(self)
	return pt
end

-- Set the obejct color
function HudObject:SetColor(r, g, b, a)
	self.tex:SetVertexColor(r, g, b, a or 0.5)
	return self
end

function HudObject:SetMarkerColor(marker, a)
	local color = Makers_Color[marker]
	if color then
		local r, g, b = unpack(color)
		return self:SetColor(r, g, b, a)
	else
		return self
	end
end

-- Get the object color
function HudObject:GetColor()
	return self.tex:GetVertexColor()
end

-- Set the show_all_points flag of this object
-- If at least one such object is currently defined, all unit points will
-- be shown even if no objects are attached to them
function HudObject:ShowAllPoints(state)
	if state == nil then
		return self.show_all_points
	end
	
	self.show_all_points = state
	Hud:UpdateShowAllPoints()
	return self
end

-- Set the persistent flag
function HudObject:Persistent(state)
	if state == nil then
		return self.persistent
	end
	
	self.persistent = state
	return self
end

-- Set fade flag
-- If this flag is set, the object will be animated with a fade-in-out
function HudObject:Fade(state)
	if state == nil then
		return self.fade
	end
	
	-- Prevent setting the fade flags if globally disabled
	if not Hud.settings.fade then return self end
	
	if not state and self.fade_init then
		self.frame:SetAlpha(1)
		self.frame:Show()
	end
	
	self.fade = state
	return self
end

-- Set a key for this object
function HudObject:Register(key, replace)
	if not key then return end
	
	-- If replace, remove objects with the same key
	if replace then
		Hud:RemoveObject(key)
	end
	
	-- Define the key for this object
	Hud.objects[self] = key
	
	return self
end

-- Remove the object by calling Hud:RemoveObject
function HudObject:Remove()
	-- Object itself given
	if not Hud.objects[self] or self._destroyed then return end
	self._destroyed = true
	
	-- Detach this object from every points it was attached to
	for i, pt in ipairs(self.attached) do
		pt:DetachObject(self)
	end
	
	local function do_remove()
		Hud.objects[self] = nil
		Hud.num_objs = Hud.num_objs - 1
		
		-- Release the wrapper frame of this object
		Hud:ReleaseObjFrame(self.frame)
	end
	
	-- Call the remove handler if defined
	if self.OnRemove then self:OnRemove() end
	
	-- Fade out animation
	if self.fade then
		if self.fade_in then
			self.fade_in:Cancel()
		end
		
		local start = GetTime()
		local ticker
		ticker = C_Timer.NewTicker(0.01, function()
			local pct = (GetTime() - start) / 0.20
			if pct > 1 then
				self.frame:SetAlpha(0)
				ticker:Cancel()
				ticker = nil
				do_remove()
			else
				self.frame:SetAlpha(1 - pct)
			end
		end)
	else
		do_remove()
	end
	
	-- Check if we still need to show all points
	if self.show_all_points then
		Hud:UpdateShowAllPoints()
	end
end

-- Factory function
function Hud:CreateObject(proto, use_tex)
	-- Object usually require raid points to be available
	self:RefreshRaidPoints()
	
	local obj = setmetatable(proto or {}, { __index = HudObject })
	obj.__object = true
	
	self.objects[obj] = true
	self.num_objs = self.num_objs + 1
	
	obj.persistent = false
	
	obj.frame = self:AllocObjFrame(use_tex)
	obj.tex = obj.frame.tex
	obj.attached = {}
	obj.fade = Hud.settings.fade
	
	obj.fade_init = true
	obj.frame:SetAlpha(0)
	obj.frame:Hide()
	
	-- Fade in if not disabled
	C_Timer.After(0, function()
		obj.fade_init = false
		if obj.fade then
			local created = GetTime()
			obj.frame:SetAlpha(0)
			obj.fade_in = C_Timer.NewTicker(0.01, function()
				local pct = (GetTime() - created) / 0.20
				if pct > 1 then
					obj.frame:SetAlpha(1)
					obj.fade_in:Cancel()
					obj.fade_in = nil
				else
					obj.frame:SetAlpha(pct)
				end
			end)
		else
			obj.frame:SetAlpha(1)
		end
		obj.frame:Show()
	end)
	
	-- Show() may cause some weird side effects, call it on tick later
	C_Timer.After(0, function() Hud:Show() end)
	
	return obj
end

--------------------------------------------------------------------------------
-- Scene management

-- Remove an object from the scene
function Hud:RemoveObject(key)
	if key.__object then
		key:Remove()
		return
	else
		for o, k in self:IterateObjects() do
			if k == key then
				o:Remove()
			end
		end
	end
end
	
-- Iterates over all objects
function Hud:IterateObjects()
	return pairs(self.objects)
end

-- Check if at least one show_all_points object is present in the scene
function Hud:UpdateShowAllPoints()
	for obj in Hud:IterateObjects() do
		if obj.show_all_points then
			self.show_all_points = true
			return
		end
	end
	self.show_all_points = false
end

-- Clear the whole scene
function Hud:Clear(soft)
	-- Remove all points unrelated to raid units
	-- This prevent bogus modules to keep invisible points on the scene forever
	for name, point in self:IteratePoints() do
		if not point.unit and (not soft or not point.persistent) then
			point:Remove()
		end
	end
	
	-- Remove all objects
	for obj in self:IterateObjects() do
		if not soft or not obj.persistent then
			obj:Remove()
		end
	end
end

-- Clear encounter object at ENCOUNTER_END
function Hud:ClearEncounter()
	self:Clear(true)
end

--------------------------------------------------------------------------------
-- API

-- Invisible object
function Hud:DrawDummy(parent)
	local dummy = self:CreateObject({})
	
	parent = dummy:UsePoint(parent)
	if not parent then return end
	
	return dummy
end

-- Line
function Hud:DrawLine(from, to, width)
	local line = self:CreateObject({ width = width or 64 }, true)
	
	from = line:UsePoint(from)
	to = line:UsePoint(to)
	if not from or not to then return end
	
	line.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\line")
	line.tex:SetVertexColor(0.5, 0.5, 0.5, 1)
	line.tex:SetBlendMode("ADD")
	
	local lsx, lsy, lex, ley, lw
	
	function line:Update()
		if self.OnUpdate then self:OnUpdate() end
		
		local sx, sy = from.x, from.y
		local ex, ey = to.x, to.y
		local w = self.width
		
		if lsx == sx and lsy == sy and lex == ex and ley == ey and lw == w then
			return
		else
			lsx, lsy, lex, ley, lw = sx, sy, ex, ey, w
		end
		
		-- Determine dimensions and center point of line
		local dx, dy = (ex - sx) * 1.015, (ey - sy) * 1.015
		local cx, cy = (sx + ex) / 2, (sy + ey) / 2
		
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
			self.frame:SetPoint("TOPRIGHT", hud, "CENTER", cx, cy)
			self.tex:SetTexCoord(0, 0, 0, 0, 0, 0, 0, 0)
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
		
		self.frame:SetPoint("BOTTOMLEFT", hud, "CENTER", cx - Bwid, cy - Bhgt)
		self.frame:SetPoint("TOPRIGHT", hud, "CENTER", cx + Bwid, cy + Bhgt)
		self.tex:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
	end
	
	-- Return a shortest distance between a point and the line
	-- If strict, the function will return -1 if the point projection
	-- falls outside of the segment. Otherwise it will return the distance
	-- to the closest end
	function line:PointDistance(x, y, strict)
		if not x or not y then return end
		
		local fx, fy = from:FastPosition()
		local tx, ty = to:FastPosition()
		
		local d, outside = GPointVectorDistance(x, y, fx, fy, tx, ty)
		return (outside and strict) and -1 or d
	end
	
	-- Return unit distance to the line
	function line:UnitDistance(unit, strict)
		local px, py = UnitPosition(unit)
		return self:PointDistance(px, py, strict)
	end
	
	return line
end

-- Texture
function Hud:DrawTexture(center, width, height, tex)
	if tex == nil then
		tex = height
		height = width
	end
	
	local texture = self:CreateObject({ width = width, height = height }, true)
	
	center = texture:UsePoint(center)
	if not center then return end
	
	texture.tex:SetTexture(tex)
	texture.tex:SetBlendMode("BLEND")
	texture.tex:SetVertexColor(1, 1, 1, 1)
	
	function texture:Update()
		if self.OnUpdate then self:OnUpdate() end
		
		local width, height = self.width, self.height
		
		if self.Rotate then
			-- Rotation require a multiplier on size
			width = width * (2 ^ 0.5)
			height = height * (2 ^ 0.5)
			self.tex:SetRotation(self:Rotate() % pi2)
		end
		
		self.frame:SetSize(width, height)
		self.frame:SetPoint("CENTER", hud, "CENTER", center.x, center.y)
	end
	
	function texture:SetBlendMode(...)
		texture.tex:SetBlendMode(...)
		return self
	end
	
	return texture
end

-- Raid target
function Hud:DrawMarker(center, size, target)
	if target == nil then
		target = size
		size = 20
	end
	local path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. target
	return self:DrawTexture(center, size, size, path)
end

-- Circle
function Hud:DrawCircle(center, radius, tex)
	local circle = self:CreateObject({ radius = radius }, true)
	
	center = circle:UsePoint(center)
	if not center then return end
	
	circle.tex:SetTexture(tex)
	circle.tex:SetBlendMode("ADD")
	circle.tex:SetVertexColor(0.8, 0.8, 0.8, 0.5)
	
	-- Check if a specific point is inside the circle
	function circle:PointIsInside(x, y)
		if not x or not y then return end
		return center:PointDistance(x, y) < self.radius
	end
	
	-- Check if a given unit is inside the circle
	function circle:UnitIsInside(unit)
		return not UnitIsDeadOrGhost(unit) and center:UnitDistance(unit) < self.radius
	end
	
	-- Get the list of units inside the circle
	function circle:UnitsInside(filter)
		local players = {}
		for _, unit in FS:IterateGroup() do
			if type(filter) ~= "function" or filter(unit) then
				if self:UnitIsInside(unit) then
					players[#players + 1] = unit
				end
			end
		end
		return players
	end
	
	function circle:Update()
		if self.OnUpdate then self:OnUpdate() end
		
		local size = self.radius * 2 * Hud:GetZoom()
		
		if self.Rotate then
			-- Rotation require a multiplier on size
			size = size * (2 ^ 0.5)
			self.tex:SetRotation(self:Rotate() % pi2)
		end
		
		self.frame:SetSize(size, size)
		self.frame:SetPoint("CENTER", hud, "CENTER", center.x, center.y)
	end
	
	return circle
end

-- Draw a radius circle
function Hud:DrawRadius(center, radius)
	return self:DrawCircle(center, radius, radius < 15 and "Interface\\AddOns\\FS_Core\\media\\radius_lg" or "Interface\\AddOns\\FS_Core\\media\\radius")
end

-- Area of Effect
function Hud:DrawArea(center, radius)
	return self:DrawCircle(center, radius, "Interface\\AddOns\\FS_Core\\media\\radar_circle")
end

-- Target reticle
function Hud:DrawTarget(center, radius)
	local target = self:DrawCircle(center, radius, "Interface\\AddOns\\FS_Core\\media\\alert_circle")
	if not target then return end
	
	function target:Rotate()
		return GetTime() * 1.5
	end
	
	return target
end

-- Timer
function Hud:DrawTimer(center, radius, duration)
	local timer = self:DrawCircle(center, radius, "Interface\\AddOns\\FS_Core\\media\\timer")
	if not timer then return end
	
	-- Timer informations
	local start = GetTime()
	timer.pct = 0
	
	local done = false
	
	-- Hook the Update() function directly to let the OnUpdate() hook available for user code
	local circle_update = timer.Update
	function timer:Update()
		local dt = GetTime() - start
		if dt < duration then
			self.pct = dt / duration
		else
			self.pct = 1
		end
		
		if self.pct == 1 and not done then
			done = true
			if self.OnDone then
				self:OnDone()
			end
		end
		
		circle_update(timer)
	end
	
	function timer:Rotate()
		return pi2 * self.pct
	end
	
	function timer:Reset(d)
		start = GetTime()
		duration = d
		done = false
		return self
	end
	
	return timer
end

-- Triangle
function Hud:DrawTriangle(a, b, c)
	local triangle = self:CreateObject(nil, true)
	
	a = triangle:UsePoint(a)
	b = triangle:UsePoint(b)
	c = triangle:UsePoint(c)
	
	if not a or not b or not c then return end
	
	triangle.tex:SetTexture("Interface\\AddOns\\FS_Core\\media\\triangle")
	triangle.tex:SetBlendMode("ADD")
	triangle.tex:SetVertexColor(0.8, 0.8, 0.8, 0.5)
	
	function triangle:PointIsInside(x, y)
		if not x or not y then return end
		
		local x1, y1 = a:FastPosition()
		local x2, y2 = b:FastPosition()
		local x3, y3 = c:FastPosition()
		
		return GPointInTriangle(x, y, x1, y1, x2, y2, x3, y3)
	end
	
	function triangle:UnitIsInside(unit)
		local x, y = UnitPosition(unit)
		return self:PointIsInside(x, y)
	end
	
	local lx1, lx2, lx3, ly1, ly2, ly3
	
	function triangle:Update()
		if self.OnUpdate then self:OnUpdate() end
		
		local x1, x2, x3 = a.x, b.x, c.x
		local y1, y2, y3 = a.y, b.y, c.y
		
		if lx1 == x1 and lx2 == x2 and lx3 == x3 and ly1 == y1 and ly2 == y2 and ly3 == y3 then
			return
		else
			lx1, lx2, lx3, ly1, ly2, ly3 = x1, x2, x3, y1, y2, y3
		end
		
		-- Taken from the good old AVR
		
		local minx = min(x1, x2, x3)
		local miny = min(y1, y2, y3)
		local maxx = max(x1, x2, x3)
		local maxy = max(y1, y2, y3)
		
		local dx = maxx - minx
		local dy = maxy - miny
		
		if dx == 0 or dy == 0 then
			return
		end
		
		local tx3, ty1, ty2, ty3
		if x1 == minx then
			if x2 == maxx then
				tx3, ty1, ty2, ty3 = (x3 - minx) / dx, (maxy - y1), (maxy - y2), (maxy - y3)
			else
				tx3, ty1, ty2, ty3 = (x2 - minx) / dx, (maxy - y1), (maxy - y3), (maxy - y2)
			end
		elseif x2 == minx then
			if x1 == maxx then
				tx3, ty1, ty2, ty3 = (x3 - minx) / dx, (maxy - y2), (maxy - y1), (maxy - y3)
			else
				tx3, ty1, ty2, ty3 = (x1 - minx) / dx, (maxy - y2), (maxy - y3), (maxy - y1)
			end
		else -- x3 == minx
			if x2 == maxx then
				tx3, ty1, ty2, ty3 = (x1 - minx) / dx, (maxy - y3), (maxy - y2), (maxy - y1)
			else
				tx3, ty1, ty2, ty3 = (x2 - minx) / dx, (maxy - y3), (maxy - y1), (maxy - y2)
			end
		end
		
		local t1 = -0.99609375 / (ty3 - tx3 * ty2 + (tx3 - 1) * ty1) -- 0.99609375 = 510/512
		local t2 = dy * t1
		x1 = 0.001953125 - t1 * tx3 * ty1 -- 0.001953125 = 1/512
		x2 = 0.001953125 + t1 * ty1
		x3 = t2 * tx3 + x1
		y1 = t1 * (ty2 - ty1)
		y2 = t1 * (ty1 - ty3)
		y3 = -t2 + x2
		
		if abs(t2) >= 9000 then
			return
		end
		
		triangle.frame:SetPoint("BOTTOMLEFT", hud, "CENTER", minx, miny)
		triangle.frame:SetPoint("TOPRIGHT", hud, "CENTER", maxx, maxy)
		triangle.tex:SetTexCoord(x1, x2, x3, y3, x1 + y2, x2 + y1, y2 + x3, y1 + y3)
	end
	
	return triangle
end

-- Polygon
do
	-- Used to make table circular
	local circular = {
		__index = function(t, k)
			if type(k) == "number" then
				return rawget(t, ((k - 1) % #t) + 1)
			else
				return nil
			end
		end
	}
	
	-- Draw a polygon
	--
	-- The polygon will automatically be decomposed into triangles
	--
	-- *** IMPORTANT ***
	-- The polygon must be convex or concave (not complex).
	-- Be cautious when giving moving vertices, it's easy to make the resulting
	-- polygon a complex one.
	--
	function Hud:DrawPolygon(args, border, border_only)
		-- Create the polygon object
		local polygon = self:CreateObject()
		
		-- Normalize border
		if type(border) ~= "number" then
			if border ~= false then
				border = 32
			end
		elseif border < 10 then
			border = false
		end
		
		-- Allocated static points
		local points = {}
		
		-- Vertices points objects
		local vertices = setmetatable({}, circular)
		polygon.vertices = vertices
		
		-- Sub-triangles
		local triangles = {}
		polygon.triangles = triangles
		
		-- Border lines
		local lines = {}
		polygon.lines = lines
		
		-- Parse arguments
		local i, e = 1, #args
		while i <= e do
			local x = args[i]
			if type(x) == "number" then
				-- (x, y) given
				local y = args[i + 1]
				if type(y) ~= "number" then
					self:Printf("Missing Y coordinate for vertex (got '%s')", tostring(y))
					return
				end
				local pt = self:CreateStaticPoint(x, y)
				table.insert(vertices, pt)
				table.insert(points, pt)
				i = i + 2
			else
				-- Point given
				local pt = self:GetPoint(x)
				if not pt then
					self:Printf("Unable to get point for vertex '%s'", tostring(x))
					return
				end
				table.insert(vertices, pt)
				i = i + 1
			end
		end
		
		-- Check that we have at lease 3 vertices
		if #vertices < 3 then
			self:Print("At least 3 vertices are required to draw a polygon")
			return
		end
		
		-- Register used points and draw border
		for i, pt in ipairs(vertices) do
			polygon:UsePoint(pt)
			if border then
				table.insert(lines, self:DrawLine(pt, vertices[i + 1], border))
			end
		end
		
		-- Check if a specific point is inside the polygon
		function polygon:PointIsInside(x, y, complex)
			if not x or not y then return end
			
			-- If the polygon can be complex (it really shouldn't be), this
			-- slower check is way more accurate. Sub-triangles doesn't
			-- care if the polygon is complex or not.
			if complex and not border_only then
				for _, t in ipairs(triangles) do
					if t:PointIsInside(x, y) then return true end
				end
				return false
			end
			
			local function vertex(i) return vertices[i]:FastPosition() end
			return GPointInPolygon(x, y, vertex, #vertices)
		end
		
		-- Check if a unit is inside the polygon
		function polygon:UnitIsInside(unit, complex)
			local x, y = UnitPosition(unit)
			return self:PointIsInside(x, y, complex)
		end
		
		-- Polygon triangulation
		if not border_only then
			-- Vertices available for triangulation
			local tvertices = setmetatable({}, circular)
			for k in ipairs(vertices) do tvertices[k] = k end
			
			-- Run until only 3 vertices are left
			while #tvertices > 3 do
				local success = false
				
				-- Search an ear
				for i = 1, #tvertices do
					-- Previous and next point
					local p = vertices[tvertices[i - 1]]
					local n = vertices[tvertices[i + 1]]
					
					local px, py = p:FastPosition()
					local nx, ny = n:FastPosition()
					
					-- Compute the middle of the diagonal
					local tx = (px + nx) / 2
					local ty = (py + ny) / 2
					
					-- If the diagonal is inside the polygon, we found an ear
					if polygon:PointIsInside(tx, ty) then
						-- Draw the triangle with these 3 points
						table.insert(triangles, self:DrawTriangle(p, vertices[tvertices[i]], n))
						
						-- Remove the vertex from the list of usable ones
						table.remove(tvertices, i)
						
						success = true
						break
					end
				end
				
				-- Failed to find an ear, unable to triangulate
				if not success then
					self:Print("Failed to triangulate. No ear found.")
					return
				end
			end
			
			-- Draw the remaining triangle
			table.insert(triangles, self:DrawTriangle(
				vertices[tvertices[1]],
				vertices[tvertices[2]],
				vertices[tvertices[3]]
			))
		end
		
		-- Set both the triangles color and the border color
		function polygon:SetColor(...)
			if border then self:SetBorderColor(...) end
			return self:SetFillColor(...)
		end
		
		function polygon:SetMarkerColor(marker, a)
			local color = Makers_Color[marker]
			if color then
				local r, g, b = unpack(color)
				return self:SetColor(r, g, b, a)
			else
				return self
			end
		end
		
		-- Set the color of all triangles composing this polygon
		function polygon:SetFillColor(...)
			for _, triangle in ipairs(triangles) do triangle:SetColor(...) end
			return self
		end
		
		-- Set the color of the border
		function polygon:SetBorderColor(...)
			for _, line in ipairs(lines) do line:SetColor(...) end
			return self
		end
		
		-- Return the color of the first triangle of this polygon, should be
		-- the color of the whole polygon
		function polygon:GetColor()
			return triangles[1]:GetColor()
		end
		
		-- Alias as GetFillColor
		polygon.GetFillColor = polygon.GetColor
		
		-- Return the color of the border
		function polygon:GetBorderColor()
			if not border then return end
			return lines[1]:GetColor()
		end
		
		-- Set Fade flags
		function polygon:Fade(state)
			for _, triangle in ipairs(triangles) do triangle:Fade(state) end
			for _, line in ipairs(lines) do line:Fade(state) end
			return HudObject.Fade(self, state)
		end
		
		-- Set Persistent flags
		function polygon:Persistent(state)
			for _, triangle in ipairs(triangles) do triangle:Persistent(state) end
			for _, line in ipairs(lines) do line:Persistent(state) end
			return HudObject.Persistent(self, state)
		end
		
		-- Remove triangles and static points on polygon removal
		function polygon:Remove()
			for _, triangle in ipairs(triangles) do triangle:Remove() end
			for _, line in ipairs(lines) do line:Remove() end
			for _, pt in ipairs(points) do pt:Remove() end
			HudObject.Remove(self)
		end
		
		return polygon
	end
end

-- Exact line using polygon
function Hud:DrawPolyLine(from, to, width, border)
	local ray = self:CreateObject()
	local poly -- Placeholder for the polygon object
	
	from = ray:UsePoint(from)
	to = ray:UsePoint(to)
	if not from or not to then return end
	
	-- Normal unit vector
	local nx, ny
	
	-- Prevent more than one update per frame
	local updated = false
	
	-- Update vectors informations
	local function update_vectors()
		-- Get unit vector
		local vx, vy = Hud:Vector(from, to)
		
		-- Create a normal vector
		nx = vy + 0.01
		ny = -vx + 0.01
		
		-- Prevent another update until next frame
		updated = true
	end
	
	-- Object are always updated after points
	-- We use this to unlock vector updating for the next frame
	function ray:Update()
		updated = false
	end
	
	-- Create one vertex of the ray
	local function create_point(ref, dir, o)
		local pt = self:CreateShadowPoint(ref)
		function pt:Position()
			if not updated then update_vectors() end
			local x, y = ref:Position()
			local w = (poly and poly.width or width) / 2
			local overrun = poly and poly.overrun or 1
			return
				x + ny * overrun * o + nx * w * dir,
				y - nx * overrun * o + ny * w * dir
		end
		return pt
	end
	
	local p1 = create_point(from, 1, 1)
	local p2 = create_point(from, -1, 1)
	local p3 = create_point(to, -1, -1)
	local p4 = create_point(to, 1, -1)
	
	-- The ray polygon
	poly = self:DrawPolygon({ p1, p2, p3, p4 }, border)
	poly.width = width
	poly.overrun = 0
	
	function poly:Overrun(value)
		if not value then return self.overrun end
		self.overrun = value
		return self
	end
	
	-- Cleanup
	local poly_remove = poly.Remove
	function poly:Remove()
		poly_remove(self)
		ray:Remove()
		p1:Remove()
		p2:Remove()
		p3:Remove()
		p4:Remove()
	end
	
	return poly
end
