local _, FS = ...
local Nameplates = FS:RegisterModule("Nameplates", "AceTimer-3.0")
FS.Hud = Nameplates

local pi2, pi_2 = math.pi * 2, math.pi / 2

local hud = CreateFrame("Frame", "FSNameplateHUD", UIParent)
hud:SetFrameStrata("BACKGROUND")
hud:SetAllPoints()
hud:Hide()

local fakePlayerPlate = CreateFrame("Frame", "FSNameplatePlayerFake", hud)
fakePlayerPlate:SetWidth(10)
fakePlayerPlate:SetHeight(10)
fakePlayerPlate:SetPoint("BOTTOM", hud, "CENTER", 0, 0)
fakePlayerPlate:Show()
fakePlayerPlate.token = "player"

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

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------

local nameplates_defaults = {
	profile = {
		enable = true,
		clickthrough = false,
		offset = 0,
		nametext = false,
	}
}

local nameplates_config = {
	title = {
		type = "description",
		name = "|cff64b4ffNameplates HUD",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Provides a nameplate drawing API.\n",
		fontSize = "medium",
		order = 1,
	},
	enable = {
		type = "toggle",
		name = "Enable",
		descStyle = "inline",
		width = "full",
		get = function() return Nameplates.settings.enable end,
		set = function(_, v)
			Nameplates.settings.enable = v
			if v then
				Nameplates:Enable()
			else
				Nameplates:Disable()
			end
		end,
		order = 2
	},
	--[[clickthrough = {
		type = "toggle",
		name = "Click through friendly nameplates",
		descStyle = "inline",
		width = "full",
		get = function() return Nameplates.settings.clickthrough end,
		set = function(_, v)
			Nameplates.settings.clickthrough = v
			C_NamePlate.SetNamePlateFriendlyClickThrough(v)
		end,
		order = 3
	},]]
	offset = {
		type = "range",
		name = "Offset",
		min = -10000,
		max = 10000,
		softMin = -300,
		softMax = 300,
		bigStep = 1,
		get = function() return Nameplates.settings.offset end,
		set = function(_, value)
			Nameplates.settings.offset = value
			Nameplates:RefreshBidings()
		end,
		order = 10
	},
	nametext = {
		type = "toggle",
		name = "Add Names over the HUD",
		descStyle = "inline",
		width = "full",
		get = function() return Nameplates.settings.nametext end,
		set = function(_, v)
			Nameplates.settings.nametext = v
		end,
		order = 4
	},
}

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Nameplates:OnInitialize()
	self.db = FS.db:RegisterNamespace("Nameplates", nameplates_defaults)
	self.settings = self.db.profile
	FS.Config:Register("Nameplates HUD", nameplates_config)

	--C_NamePlate.SetNamePlateFriendlyClickThrough(self.settings.clickthrough)

	self.index = {}
	self.objects = {}
	self.registry = {}
end

function Nameplates:OnEnable()
	self:RegisterEvent("NAME_PLATE_CREATED")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	self:RegisterEvent("ENCOUNTER_END")
	self:ScheduleRepeatingTimer("GC", 60)
	if self.settings.enable then
		hud:Show()
	end
end

function Nameplates:OnDisable()
	hud:Hide()
end

function Nameplates:RefreshBidings()
	for owner, objects in pairs(self.objects) do
		local nameplate = self:GetNameplateByGUID(owner)
		if nameplate then
			for obj in pairs(objects) do
				obj:Attach(nameplate)
			end
		end
	end
end

function Nameplates:ENCOUNTER_END()
	for owner, objects in pairs(self.objects) do
		for obj, timestamp in pairs(objects) do
			obj:Remove()
		end
	end
end

function Nameplates:GC()
	if IsEncounterInProgress() then return end
	local now = GetTime()
	for owner, objects in pairs(self.objects) do
		local nameplate = self:GetNameplateByGUID(owner)
		if not nameplate then
			for obj, timestamp in pairs(objects) do
				if now - timestamp > 60 then
					obj:Remove()
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Index
-------------------------------------------------------------------------------

function Nameplates:GetNameplateByGUID(guid)
	if UnitExists(guid) then
		guid = UnitGUID(guid)
	end
	if guid == UnitGUID("player") then
		return fakePlayerPlate
	else
		local nameplate = self.index[guid]
		if nameplate then
			if UnitGUID(nameplate.token) == guid then
				return nameplate
			end
		end
	end
end

function Nameplates:RegisterObject(obj, name, remove)
	if remove then self:RemoveObject(name) end
	self.registry[obj] = name
end

function Nameplates:RemoveObject(name)
	for obj, key in pairs(self.registry) do
		if key == name then
			obj:Remove()
		end
	end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function Nameplates:NAME_PLATE_CREATED(_, nameplate)
	-- Nothing
end

function Nameplates:NAME_PLATE_UNIT_ADDED(_, token)
	if UnitIsUnit(token, "player") then return end
	local guid = UnitGUID(token)
	local nameplate = C_NamePlate.GetNamePlateForUnit(token)
	nameplate.token = token
	self.index[guid] = nameplate

	if self.objects[guid] then
		for obj in pairs(self.objects[guid]) do
			obj:Attach(nameplate)
		end
	end
end

function Nameplates:NAME_PLATE_UNIT_REMOVED(_, nameplate)
	if UnitIsUnit(nameplate, "player") then return end
	local guid = UnitGUID(nameplate)
	self.index[guid] = nil

	if self.objects[guid] then
		for obj in pairs(self.objects[guid]) do
			obj:Detach()
			self.objects[guid][obj] = GetTime()
		end
	end
end

-------------------------------------------------------------------------------
-- Frames Pool
-------------------------------------------------------------------------------

local alloc_frame, free_frame
do
	local pool = {}

	local function normalize(frame)
		frame:Hide()
		frame:SetFrameStrata("BACKGROUND")
		frame:ClearAllPoints()
		frame:SetAlpha(1)
		if frame.tex then frame.tex:Hide() end
		if frame.line then frame.line:Hide() end
		if frame.text then frame.text:Hide() end
		if frame.nametext then frame.nametext:Hide() end
		return frame
	end

	function alloc_frame()
		return normalize(#pool > 0 and table.remove(pool) or CreateFrame("Frame", nil, hud))
	end

	function free_frame(frame)
		frame:Hide()
		frame:SetScript("OnUpdate", nil)
		table.insert(pool, frame)
	end
end

-------------------------------------------------------------------------------
-- Object API
-------------------------------------------------------------------------------

local NameplateObject = {}

function NameplateObject:Attach(nameplate)
	self.frame:SetPoint("CENTER", nameplate, "BOTTOM", self.offset_x , self.offset_y + Nameplates.settings.offset)
	if not self.attached then
		self.frame:Show()
		self.attached = true
		if self.OnAttachChange then self:OnAttachChange(true, nameplate) end
	end
end

function NameplateObject:Detach()
	if self.attached then
		self.frame:Hide()
		self.frame:ClearAllPoints()
		self.attached = false
		if self.OnAttachChange then self:OnAttachChange(false) end
	end
end

function NameplateObject:IsAttached()
	return self.attached
end

function NameplateObject:UseTexture(path)
	if not self.frame.tex then
		self.frame.tex = self.frame:CreateTexture(nil, "ARTWORK")
	end
	local tex = self.frame.tex
	tex:SetAllPoints()
	tex:SetDrawLayer("BACKGROUND")
	tex:SetBlendMode("BLEND")
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetTexture(path)
	tex:Show()
	return tex
end

function NameplateObject:UseLine(thickness)
	if not self.frame.line then
		self.frame.line = self.frame:CreateLine()
	end
	local line = self.frame.line
	line:SetDrawLayer("BACKGROUND")
	line:SetBlendMode("ADD")
	line:SetColorTexture(1, 1, 1, 0.6)
	line:SetThickness(thickness)
	line:Show()
	return line
end

function NameplateObject:UseText()
	if not self.frame.text then
		self.frame.text = self.frame:CreateFontString(nil, "OVERLAY")
	end
	local text = self.frame.text
	text:SetAllPoints()
	text:SetJustifyH("CENTER")
	text:SetJustifyV("MIDDLE")
	text:SetTextColor(1, 1, 1)
	text:Show()
	return text
end

function NameplateObject:UseNameText()
	local guid = self.owner
	local _, class, _, _, _, name = GetPlayerInfoByGUID(guid)

	if name then
		if not self.frame.nametext then
			self.frame.nametext = self.frame:CreateFontString(nil, "OVERLAY")
		end
		local nametext = self.frame.nametext
		nametext:SetPoint('BOTTOM',self.frame,'TOP',0,-20)
		local size = 12
		local font = "Fonts\\FRIZQT__.TTF"
		local outline = "OUTLINE"
		nametext:SetFont(font, size, outline)
		nametext:SetTextColor(RAID_CLASS_COLORS[class].r,RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b)
		nametext:SetText(name)
		nametext:Show()
		return nametext
	end
end

function NameplateObject:SetOffset(x, y)
	self.offset_x = x
	self.offset_y = y
	if self.attached then
		self:Attach(Nameplates:GetNameplateByGUID(self.owner))
	end
	return self
end

function NameplateObject:SetSize(...)
	self.frame:SetSize(...)
	return self
end

function NameplateObject:SetColor(r, g, b, a, ...)
	if r > 1 then r = r / 255 end
	if g > 1 then g = g / 255 end
	if b > 1 then b = b / 255 end
	if a and a > 1 then a = a / 255 end
	if self.frame.tex then
		self.frame.tex:SetVertexColor(r, g, b, a, ...)
	end
	if self.frame.line then
		self.frame.line:SetColorTexture(r, g, b, a, ...)
	end
	if self.frame.text then
		self.frame.text:SetTextColor(r, g, b, a, ...)
	end
	if self.spinner then
		self.spinner:SetVertexColor(r, g, b, a, ...)
	end
	return self
end

function NameplateObject:SetMarkerColor(marker, a)
	local color = Makers_Color[marker]
	if color then
		local r, g, b = unpack(color)
		return self:SetColor(r, g, b, a)
	else
		return self
	end
end

function NameplateObject:SetBlendMode(...)
	if self.frame.tex then
		self.frame.tex:SetBlendMode(...)
	end
	return self
end

function NameplateObject:Register(name, remove)
	Nameplates:RegisterObject(self, name, remove)
	return self
end

function NameplateObject:Remove()
	if self.__removed then return end
	self.__removed = true
	Nameplates.registry[self] = nil
	local objects = Nameplates.objects[self.owner]
	objects[self] = nil
	if not next(objects) then
		Nameplates.objects[self.owner] = nil
	end
	if self.OnRemove then self:OnRemove() end
	free_frame(self.frame)
end

function Nameplates:CreateObject(guid, proto)
	if UnitExists(guid) then guid = UnitGUID(guid) end
	local obj = setmetatable(proto or {}, { __index = NameplateObject })

	obj.owner = guid
	obj.frame = alloc_frame()
	obj.tex = obj.frame.tex

	obj.offset_x = 0
	obj.offset_y = 0

	obj.frame:SetScript("OnUpdate", function(_, dt)
		if obj.OnUpdate then obj:OnUpdate(dt) end
		if obj.Update then obj:Update(dt) end
	end)

	local objects = self.objects[guid]
	if not objects then
		objects = {}
		self.objects[guid] = objects
	end
	objects[obj] = GetTime()

	local nameplate = self:GetNameplateByGUID(guid)
	if nameplate then
		obj:Attach(nameplate)
	end

	return obj
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------

-- Texture
function Nameplates:DrawTexture(guid, width, height, tex_path)
	if tex_path == nil then
		tex_path = height
		height = width
	end

	local texture = self:CreateObject(guid, { width = width, height = height })

	local tex = texture:UseTexture(tex_path)
	tex:SetDrawLayer("ARTWORK")
	tex:SetVertexColor(1, 1, 1, 1)

	function texture:SetSize(width, height)
		self.width = width
		self.height = height
		return self
	end

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
	end

	function texture:SetBlendMode(...)
		tex:SetBlendMode(...)
		return self
	end

	return texture
end

-- Raid target
function Nameplates:DrawMarker(guid, size, target)
	if target == nil then
		target = size
		size = 50
	end
	local path = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. target
	return self:DrawTexture(guid, size, size, path)
end

-- Generic circle
function Nameplates:DrawCircle(guid, radius, tex_path)
	local circle = self:CreateObject(guid, { radius = radius })

	local tex = circle:UseTexture(tex_path)
	tex:SetBlendMode("ADD")
	tex:SetVertexColor(0.8, 0.8, 0.8, 0.5)

	if self.settings.nametext then
		local nametext = circle:UseNameText()
	end

	function circle:SetRadius(radius)
		self.radius = radius
		return self
	end

	function circle:Update()
		local size = self.radius * 2
		if self.Rotate then
			size = size * (2 ^ 0.5)
			tex:SetRotation(self:Rotate() % pi2)
		end
		self.frame:SetSize(size, size)
	end

	circle:Update()
	return circle
end

-- Draw a radius circle
function Nameplates:DrawRadius(guid, radius)
	return self:DrawCircle(guid, radius, radius < 15 and "Interface\\AddOns\\FS_Core\\media\\radius_lg" or "Interface\\AddOns\\FS_Core\\media\\radius")
end

-- Area of Effect
function Nameplates:DrawArea(guid, radius)
	return self:DrawCircle(guid, radius, "Interface\\AddOns\\FS_Core\\media\\radar_circle")
end

-- Target reticle
function Nameplates:DrawTarget(guid, radius)
	local target = self:DrawCircle(guid, radius, "Interface\\AddOns\\FS_Core\\media\\alert_circle")
	function target:Rotate()
		return GetTime() * 1.5
	end
	return target
end

-- Timer
function Nameplates:DrawTimerOld(guid, radius, duration)
	local timer = self:DrawCircle(guid, radius, "Interface\\AddOns\\FS_Core\\media\\timer")

	-- Timer informations
	local done = false
	local rotate = 0

	if not duration then
		function timer:Progress()
			return 0
		end
	elseif (type(duration) == "string" or duration < 0) and UnitExists(guid) then
		local spell = type(duration) == "string" and duration or GetSpellInfo(-duration)
		function timer:Progress()
			local _, _, _, _, _, duration, expires = UnitAura(guid, spell)
			if not duration then return 0 end
			return 1 - (expires - GetTime()) / duration
		end
	else
		local start = GetTime()

		function timer:Progress()
			if not duration then return 0 end
			local dt = GetTime() - start
			return dt < duration and dt / duration or 0
		end

		function timer:Reset(d)
			start = GetTime()
			duration = d
			done = false
			return self
		end
	end

	-- Hook the Update() function directly to let the OnUpdate() hook available for user code
	local circle_update = timer.Update
	function timer:Update()
		local pct = self:Progress()
		if pct < 0 then pct = 0 end
		if pct > 1 then pct = 1 end
		if pct == 1 and not done then
			done = true
			if self.OnDone then self:OnDone() end
		end
		rotate = pi2 * pct
		circle_update(timer)
	end

	function timer:Rotate()
		return rotate
	end

	return timer
end

-- Line
function Nameplates:DrawLine(a, b, thickness)
	local anchorA = self:CreateObject(a):SetSize(1, 1)
	local anchorB = self:CreateObject(b):SetSize(1, 1)

	local line = anchorA:UseLine(thickness or 2)
	line:SetStartPoint("CENTER", anchorA.frame)
	line:SetEndPoint("CENTER", anchorB.frame)

	local function update_line_visibility()
		if anchorA:IsAttached() and anchorB:IsAttached() then
			line:Show()
		else
			line:Hide()
		end
	end

	anchorA.OnAttachChange = update_line_visibility
	anchorB.OnAttachChange = update_line_visibility

	function anchorA:SetThickness(thickness)
		line:SetThickness(thickness)
		return self
	end

	local obj_remove = anchorA.Remove
	function anchorA:Remove()
		obj_remove(anchorA)
		anchorB:Remove()
	end

	return anchorA
end

-- Text
function Nameplates:DrawText(owner, label, size)
	local obj = Nameplates:CreateObject(owner):SetSize(300, 300)

	local size = size or 20
	local font = "Fonts\\FRIZQT__.TTF"
	local outline = "OUTLINE"

	local text = obj:UseText()
	text:SetFont(font, size, outline)
	text:SetText(label)

	function obj:SetFont(s, f, o)
		size = s or size
		font = f or font
		outline = o or outline
		text:SetFont(font, size, outline)
		return self
	end

	function obj:SetText(...)
		text:SetText(...)
		return self
	end

	return obj
end

--- SPINNER ---

-- Usage:
-- spinner = CreateSpinner(parent)
-- spinner:SetTexture('texturePath')
-- spinner:SetBlendMode('blendMode')
-- spinner:SetVertexColor(r, g, b)
-- spinner:SetClockwise(boolean) -- true to fill clockwise, false to fill counterclockwise
-- spinner:SetReverse(boolean) -- true to empty the bar instead of filling it
-- spinner:SetValue(percent) -- value between 0 and 1 to fill the bar to

-- Some math stuff
local cos, sin, pi2, halfpi = math.cos, math.sin, math.rad(360), math.rad(90)
local function Transform(tx, x, y, angle, aspect) -- Translates texture to x, y and rotates about its center
    local c, s = cos(angle), sin(angle)
    local y, oy = y / aspect, 0.5 / aspect
    local ULx, ULy = 0.5 + (x - 0.5) * c - (y - oy) * s, (oy + (y - oy) * c + (x - 0.5) * s) * aspect
    local LLx, LLy = 0.5 + (x - 0.5) * c - (y + oy) * s, (oy + (y + oy) * c + (x - 0.5) * s) * aspect
    local URx, URy = 0.5 + (x + 0.5) * c - (y - oy) * s, (oy + (y - oy) * c + (x + 0.5) * s) * aspect
    local LRx, LRy = 0.5 + (x + 0.5) * c - (y + oy) * s, (oy + (y + oy) * c + (x + 0.5) * s) * aspect
    tx:SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
end

-- Permanently pause our rotation animation after it starts playing
local function OnPlayUpdate(self)
    self:SetScript('OnUpdate', nil)
    self:Pause()
end

local function OnPlay(self)
    self:SetScript('OnUpdate', OnPlayUpdate)
end

local function SetValue(self, value)
    -- Correct invalid ranges, preferably just don't feed it invalid numbers
    if value > 1 then value = 1
    elseif value < 0 then value = 0 end

    -- Reverse our normal behavior
    if self._reverse then
        value = 1 - value
    end

    -- Determine which quadrant we're in
    local q, quadrant = self._clockwise and (1 - value) or value -- 4 - floor(value / 0.25)
    if q >= 0.75 then
        quadrant = 1
    elseif q >= 0.5 then
        quadrant = 2
    elseif q >= 0.25 then
        quadrant = 3
    else
        quadrant = 4
    end

    if self._quadrant ~= quadrant then
        self._quadrant = quadrant
        -- Show/hide necessary textures if we need to
        if self._clockwise then
            for i = 1, 4 do
                self._textures[i]:SetShown(i < quadrant)
            end
        else
            for i = 1, 4 do
                self._textures[i]:SetShown(i > quadrant)
            end
        end
        -- Move scrollframe/wedge to the proper quadrant
        self._scrollframe:Hide();
        self._scrollframe:SetAllPoints(self._textures[quadrant])
        self._scrollframe:Show();
    end

    -- Rotate the things
    local rads = value * pi2
    if not self._clockwise then rads = -rads + halfpi end
    Transform(self._wedge, -0.5, -0.5, rads, self._aspect)
    self._rotation:SetDuration(0.000001)
    self._rotation:SetEndDelay(2147483647)
    self._rotation:SetOrigin('BOTTOMRIGHT', 0, 0)
    self._rotation:SetRadians(-rads);
    self._group:Play();
end

local function SetClockwise(self, clockwise)
    self._clockwise = clockwise
end

local function SetReverse(self, reverse)
    self._reverse = reverse
end

local function OnSizeChanged(self, width, height)
    self._wedge:SetSize(width, height) -- it's important to keep this texture sized correctly
    self._aspect = width / height -- required to calculate the texture coordinates
end

-- Creates a function that calls a method on all textures at once
local function CreateTextureFunction(func, self, ...)
    return function(self, ...)
        for i = 1, 4 do
            local tx = self._textures[i]
            tx[func](tx, ...)
        end
        self._wedge[func](self._wedge, ...)
    end
end

local function Hide(self)
	for i = 1, 4 do
		self._textures[i]:Hide();
	end
	self._wedge:Hide();
	if self._refresh then
		self._refresh:Hide()
	end
end

-- Pass calls to these functions on our frame to its textures
local TextureFunctions = {
    SetTexture = CreateTextureFunction('SetTexture'),
    SetBlendMode = CreateTextureFunction('SetBlendMode'),
    SetVertexColor = CreateTextureFunction('SetVertexColor'),
}

local function CreateSpinner(parent)
    local spinner = CreateFrame('Frame', nil, parent)

    -- ScrollFrame clips the actively animating portion of the spinner
    local scrollframe = CreateFrame('ScrollFrame', nil, spinner)
    scrollframe:SetPoint('BOTTOMLEFT', spinner, 'CENTER')
    scrollframe:SetPoint('TOPRIGHT')
    spinner._scrollframe = scrollframe

    local scrollchild = CreateFrame('frame', nil, scrollframe)
    scrollframe:SetScrollChild(scrollchild)
    scrollchild:SetAllPoints(scrollframe)

    -- Wedge thing
    local wedge = scrollchild:CreateTexture()
    wedge:SetPoint('BOTTOMRIGHT', spinner, 'CENTER')
    spinner._wedge = wedge

    -- Top Right
    local trTexture = spinner:CreateTexture()
    trTexture:SetPoint('BOTTOMLEFT', spinner, 'CENTER')
    trTexture:SetPoint('TOPRIGHT')
    trTexture:SetTexCoord(0.5, 1, 0, 0.5)

    -- Bottom Right
    local brTexture = spinner:CreateTexture()
    brTexture:SetPoint('TOPLEFT', spinner, 'CENTER')
    brTexture:SetPoint('BOTTOMRIGHT')
    brTexture:SetTexCoord(0.5, 1, 0.5, 1)

    -- Bottom Left
    local blTexture = spinner:CreateTexture()
    blTexture:SetPoint('TOPRIGHT', spinner, 'CENTER')
    blTexture:SetPoint('BOTTOMLEFT')
    blTexture:SetTexCoord(0, 0.5, 0.5, 1)

    -- Top Left
    local tlTexture = spinner:CreateTexture()
    tlTexture:SetPoint('BOTTOMRIGHT', spinner, 'CENTER')
    tlTexture:SetPoint('TOPLEFT')
    tlTexture:SetTexCoord(0, 0.5, 0, 0.5)

    -- /4|1\ -- Clockwise texture arrangement
    -- \3|2/ --

    spinner._textures = {trTexture, brTexture, blTexture, tlTexture}
    spinner._quadrant = nil -- Current active quadrant
    spinner._clockwise = true -- fill clockwise
    spinner._reverse = false -- Treat the provided value as its inverse, eg. 75% will display as 25%
    spinner._aspect = 1 -- aspect ratio, width / height of spinner frame
    spinner:HookScript('OnSizeChanged', OnSizeChanged)

    for method, func in pairs(TextureFunctions) do
        spinner[method] = func
    end

    spinner.SetClockwise = SetClockwise
    spinner.SetReverse = SetReverse
    spinner.SetValue = SetValue
    spinner.Hide = Hide

    local group = wedge:CreateAnimationGroup()
    group:SetScript('OnFinished', function() group:Play() end);
    local rotation = group:CreateAnimation('Rotation')
    spinner._rotation = rotation
    spinner._group = group;
    return spinner
end

function Nameplates:DrawTimer(guid, radius, duration)
	local timer = self:DrawCircle(guid, radius, "Interface\\AddOns\\FS_Core\\media\\circle512")
	local done = false

	timer.spinner = CreateSpinner(timer.frame)
	local spinner = timer.spinner
	spinner:SetPoint('CENTER', timer.frame, 'CENTER')
	local size = radius * 2.3
	spinner:SetTexture('Interface\\AddOns\\FS_Core\\media\\ring512')
	spinner:SetSize(size, size)
	spinner:SetBlendMode('BLEND')

	spinner:SetClockwise(true)
	spinner:SetReverse(true)

	if not duration then
		function timer:Progress()
			return 0
		end
	elseif (type(duration) == "string" or duration < 0) and UnitExists(guid) then
		local spell = type(duration) == "string" and duration or GetSpellInfo(-duration)
		function timer:Progress()
			local _, _, _, _, _, duration, expires = UnitDebuff(guid, spell)
			if not duration then return 1 end
			return 1 - (expires - GetTime()) / duration
		end
	else
		local start = GetTime()

		function timer:Progress()
			if not duration then return 0 end
			local dt = GetTime() - start
			return dt < duration and dt / duration or 1
		end

		function timer:Reset(d)
			start = GetTime()
			duration = d
			done = false
			return self
		end
	end

	-- Hook the Update() function directly to let the OnUpdate() hook available for user code
	local circle_update = timer.Update
	function timer:Update(dt)
		local pct = self:Progress()
		if pct < 0 then pct = 0 end
		if pct > 1 then pct = 1 end
		self.spinner:SetValue(pct)
		if pct == 1 and not done then
			done = true
			if self.OnDone then self:OnDone() end
		end
		circle_update(timer)
	end

	function timer:OnDone()
		self:OnRemove()
	end

	function timer:OnRemove()
		if self.spinner then
			self.Update = circle_update
			self.spinner:Hide()
			self.spinner = nil
			timer.OnRemove = nil
		end
	end
	return timer
end

function Nameplates:DrawThreat(unit, radius)
	if UnitExists(unit) and UnitCanAttack(unit, "player") then
		print("DrawThreat for " .. UnitName(unit))
		local unitTarget = unit .. "target"
		if not UnitExists(unitTarget) then return end
		local previous = UnitGUID(unitTarget)
		print("Found 1st target for " .. UnitName(unitTarget))
		local circle = self:DrawCircle(unitTarget, radius, "Interface\\AddOns\\FS_Core\\media\\circle512")

		local circle_update = circle.Update
		function circle:Update(dt)
			if not UnitExists(unit) then
				--circle.Update = circle_update
				self:Remove()
			end
			local unitTarget = unit .. "target"
			if UnitExists(unitTarget) and UnitDetailedThreatSituation(unitTarget, unit) and previous ~= UnitGUID(unitTarget) then
				previous = UnitGUID(unitTarget)
				self:Detach()
				local nameplate = self:GetNameplateByGUID(previous)
				if nameplate then
					self:Attach(nameplate)
				end
			end
			circle_update(circle)
		end
		return circle
	end
end