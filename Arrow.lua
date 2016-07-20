local _, FS = ...

local Arrow = FS:RegisterModule("Arrow")
local Map, Console

--------------------------------------------------------------------------------
-- Frames

-- Anchor
local anchor = CreateFrame("Button", "FSArrow", UIParent)
anchor:Hide()
anchor:SetFrameStrata("HIGH")
anchor:SetWidth(69)
anchor:SetHeight(52)
anchor:SetPoint("CENTER", 0, 0)
anchor:SetMovable(true)
anchor:SetClampedToScreen(true)
anchor:RegisterForDrag("LeftButton", "RightButton")
anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
anchor:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Arrow
local arrow = anchor:CreateTexture(nil, "OVERLAY")
arrow:SetTexture("Interface\\AddOns\\FS_Core\\media\\Arrow.blp")
arrow:SetAllPoints(anchor)
arrow:SetVertexColor(0.3, 1, 0)

-- Text
local text = anchor:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 20)
text:SetShadowColor(0, 0, 0)
text:SetShadowOffset(1, -2)
text:SetPoint("TOP", arrow, "BOTTOM", 0, -7)

--------------------------------------------------------------------------------
-- Config infos

local arrow_default = {
	profile = {
		enable = true,
		allow_remote = true
	}
}

local arrow_config_infos = {
	title = {
		type = "description",
		name = "|cff64b4ffArrow",
		fontSize = "large",
		order = 0,
	},
	desc = {
		type = "description",
		name = "Arrow module.\n",
		fontSize = "medium",
		order = 1,
	},
	enable = {
		type = "toggle",
		name = "Enable",
		width = "full",
		get = function()
			return Arrow.settings.enable
		end,
		set = function(_, value)
			Arrow.settings.enable = value
			if value then
				Arrow:Enable()
			else
				Arrow:Disable()
			end
		end,
		order = 5
	},
	remote = {
		type = "toggle",
		name = "Allow remote activation",
		desc = "Allow trusted raid members to remotely activate the arrow.",
		width = "full",
		get = function() return Arrow.settings.allow_remote end,
		set = function(_, v) Arrow.settings.allow_remote = v end,
		order = 6
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	cmds = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"arrow", "Hide the arrow if visible.\nIf it isn't, displays an arrow pointing to the player."},
		{"arrow <unit>", "Display an arrow pointing to the specified unit."},
		{"arrow <raid-target-id>", "Display an arrow pointing to the player with the specified raid target marker."},
		{"arrow <x> <y>", "Display an arrow pointing to the specified location."},
	}, "/fs "),
	api = FS.Config:MakeDoc("Public API", 3000, {
		{":PointToUnit ( unit , options )", "Display an arrow pointing to the specified unit."},
		{":PointToLocation ( x , y , options )", "Display an arrow pointing to the specified location."},
		{":PointToRaidTarget ( index , options )", "Display an arrow pointing to the player with the specified raid target marker."},
		{":Hide ( )", "Hide the arrow."}
	}, "FS.Arrow"),
}

--------------------------------------------------------------------------------
-- Module initialization

function Arrow:OnInitialize()
	Map = FS:GetModule("Map")
	Console = FS:GetModule("Console")
	Console:RegisterCommand("arrow", self)

	self.db = FS.db:RegisterNamespace("Arrow", arrow_default)
	self.settings = self.db.profile

	self:SetEnabledState(self.settings.enable)

	FS:GetModule("Config"):Register("Arrow", arrow_config_infos)
end

function Arrow:OnEnable()
	self:RegisterMessage("FS_MSG_ARROW")
	self.visible = false
end

function Arrow:OnDisable()
	self:Hide()
end

function Arrow:Show()
	if not self:IsEnabled() then return end
	if self:IsVisible() then return end
	self._tal = 0
	self.visible = true
	anchor:Show()
	self:SendMessage("FS_ARROW_VISIBLE", self)
	self.ticker = C_Timer.NewTicker(0.035, function() self:OnUpdate() end)
	self:OnUpdate()
end

function Arrow:Hide()
	if not self:IsVisible() then return end
	self.mode = "off"
	self.visible = false
	self.ticker:Cancel()
	anchor:Hide()
	self:SendMessage("FS_ARROW_HIDDEN", self)
end

function Arrow:IsVisible()
	return self.visible
end

--------------------------------------------------------------------------------
-- Display

function Arrow:GetDirection()
	if self.mode == "unit" then
		return Map:GetPlayerDirection(UnitPosition(self.unit))
	elseif self.mode == "location" then
		return Map:GetPlayerDirection(self.x, self.y)
	elseif self.mode == "raidtarget" then
		if not self.unit or GetRaidTargetIndex(self.unit) ~= self.raidtarget then
			self.unit = nil
			for i = 1, GetNumGroupMembers() do
				local unit = (IsInRaid() and "raid" or "party") .. i
				if GetRaidTargetIndex(unit) == self.raidtarget then
					self.unit = unit
					self:UpdateUnit()
					break
				end
			end
		end
		if not self.unit then return end
		return Map:GetPlayerDirection(UnitPosition(self.unit))
	end
end

do
	local currentCell
	local showDownArrow, count = false, 0
	local pi2 = math.pi * 2
	local floor = math.floor

	local unit_format = "%s |c%s%s|r \n|cffffe359%d yd|r"
	local location_format = "|cffffe359%d yd|r"
	local label_format = "%s\n|cffffe359%d yd|r"

	function Arrow:OnUpdate(dt)
		-- Fetch distance and angle
		local distance, angle = self:GetDirection()
		if not distance then
			self:Hide()
			return
		end

		if distance < self.options.near then
			-- Transition Pointed -> Down
			if not showDownArrow then
				anchor:SetHeight(65)
				arrow:SetTexture("Interface\\AddOns\\FS_Core\\media\\Arrow-UP.blp")
				showDownArrow = true
			end

			-- Hide on arrival
			self._tal = self._tal + 1
			if self._tal > 50 and self.options.autohide then
				self:Hide()
				return
			end

			-- Arrow rotation
			count = count + 1
			if count >= 55 then
				count = 0
			end

			local cell = count
			local column = cell % 9
			local row = floor(cell / 9)
			local xstart = column * 53 / 512
			local ystart = row * 70 / 512
			local xend = (column + 1) * 53 / 512
			local yend = (row + 1) * 70 / 512
			arrow:SetTexCoord(xstart, xend, ystart, yend)
		else
			-- Transition Down -> Pointed
			if showDownArrow then
				anchor:SetHeight(52)
				arrow:SetTexture("Interface\\AddOns\\FS_Core\\media\\Arrow.blp")
				showDownArrow = false
				currentCell = nil
				self._tal = 0
			end

			local cell = floor(angle / pi2 * 108 + 0.5) % 108

			if cell ~= currentCell then
				currentCell = cell
				local column = cell % 9
				local row = floor(cell / 9)
				local xStart = column * 56 / 512
				local yStart = row * 42 / 512
				local xEnd = (column + 1) * 56 / 512
				local yEnd = (row + 1) * 42 / 512
				arrow:SetTexCoord(xStart, xEnd, yStart, yEnd)
			end
		end

		-- Arrow label
		if self.options.label then
			text:SetText(label_format:format(self.options.label, floor(distance)))
		elseif self.mode == "unit" or self.mode == "raidtarget" then
			text:SetText(unit_format:format(FS:Icon(GetRaidTargetIndex(self.unit)), self.unitclass, self.unitname, floor(distance)))
		elseif self.mode == "location" then
			text:SetText(location_format:format(floor(distance)))
		end
	end
end

--------------------------------------------------------------------------------
-- API

function Arrow:PointToUnit(unit, options)
	if self:IsVisible() then self:Hide() end
	self.mode = "unit"
	self.unit = unit
	self:UpdateUnit()
	self:SetOptions(options)
	self:Show()
end

function Arrow:PointToLocation(x, y, options)
	if self:IsVisible() then self:Hide() end
	self.mode = "location"
	self.x, self.y = x, y
	self:SetOptions(options)
	self:Show()
end

function Arrow:PointToRaidTarget(index, options)
	if self:IsVisible() then self:Hide() end
	self.mode = "raidtarget"
	self.raidtarget = index
	self:SetOptions(options)
	self:Show()
end

-- Update name and class of the pointed unit
function Arrow:UpdateUnit()
	self.unitname = UnitName(self.unit)
	self.unitclass = FS:GetClassColor(self.unit)
end

function Arrow:SetOptions(options)
	if not options or type(options) ~= "table" then
		options = {}
	end
	self.options = options

	-- Auto hide after timeout
	if self.hide_timeout then
		self.hide_timeout:Cancel()
		self.hide_timeout = nil
	end
	if options.timeout then
		self.hide_timeout = C_Timer.NewTimer(options.timeout, function()
			self:Hide()
		end)
	end

	-- Auto hide on arrival
	if options.autohide == nil then
		options.autohide = false
	end

	-- The "near" threshold
	if options.near == nil then
		options.near = 2
	end
end

--------------------------------------------------------------------------------
-- Slash command handler

function Arrow:OnSlash(arg1, arg2)
	if not arg1 then
		if self:IsVisible() then
			self:Hide()
		else
			self:PointToLocation(UnitPosition("player"))
		end
	elseif arg1 == "hide" then
		self:Hide()
	elseif UnitExists(arg1) then
		self:PointToUnit(arg1)
	elseif arg1 == "target" then
		self:PointToRaidTarget(tonumber(arg2))
	elseif tonumber(arg1) and tonumber(arg2) then
		self:PointToLocation(tonumber(arg1), tonumber(arg2))
	end
end

--------------------------------------------------------------------------------
-- Network messages handler

function Arrow:FS_MSG_ARROW(_, prefix, data, channel, sender)
	if not self.settings.allow_remote then return end

	-- Require the sender to be in the raid group
	if not FS:UnitIsTrusted(sender) then return end

	local action = data.action

	if action == "show" then
		-- Display the arrow
		if data.unit then
			self:PointToUnit(data.unit, data.options)
		elseif data.location then
			local x, y = unpack(data.location)
			self:PointToLocation(x, y, data.options)
		elseif data.raidtarget then
			self:PointToRaidTarget(data.raidtarget, data.options)
		end
	elseif action == "hide" then
		-- Hide the arrow
		self:Hide()
	else
		-- Unknown action
		self:Print("Unknown action: " .. (action or "nil"))
	end
end
