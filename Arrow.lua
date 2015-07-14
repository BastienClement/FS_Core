local _, FS = ...

local Arrow = FS:RegisterModule("Arrow")
local Map, Console

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

function Arrow:OnInitialize()
	Map = FS:GetModule("Map")
	Console = FS:GetModule("Console")
	Console:RegisterCommand("arrow", self)
end

function Arrow:OnEnable()
	self:RegisterMessage("FS_MSG")
	self.mode = "off"
end

function Arrow:Show()
	if self.mode == "off" then
		self:Print("Arrow module must be shown via PointTo[Unit|Location]() functions")
		return
	end
	self:OnUpdate()
	self.ticker = C_Timer.NewTicker(1 / 30, function() self:OnUpdate() end)
	anchor:Show()
	self._tal = 0
	self:SendMessage("FS_ARROW_VISIBLE", self)
end

function Arrow:Hide()
	anchor:Hide()
	self.ticker:Cancel()
	self.mode = "off"
	self:SendMessage("FS_ARROW_HIDDEN", self)
end

function Arrow:IsVisible()
	return self.mode ~= "off"
end

function Arrow:GetDistance()
	if self.mode == "unit" then
		return Map:GetDistance(UnitPosition(self.unit))
	elseif self.mode == "location" then
		return Map:GetDistance(self.x, self.y)
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
		-- Fetch distance and direction
		local distance, direction = self:GetDistance()
		if not distance then
			self:Hide()
			return
		end
		
		if distance < 3 then
			-- Transition Pointed -> Down
			if not showDownArrow then
				anchor:SetHeight(65)
				arrow:SetTexture("Interface\\AddOns\\FS_Core\\media\\Arrow-UP.blp")
				showDownArrow = true
			end
			
			-- Hide on arrival
			self._tal = self._tal + 1
			if self._tal > 50 and self.options.auto_hide then
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
			
			local cell = floor(direction / pi2 * 108 + 0.5) % 108
			
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
		elseif self.mode == "unit" then
			text:SetText(unit_format:format(FS:Icon(GetRaidTargetIndex(self.unit)), self.unitclass, self.unitname, floor(distance)))
		elseif self.mode == "location" then
			text:SetText(location_format:format(floor(distance)))
		end
	end
end

function Arrow:PointToUnit(unit, options)
	self.mode = "unit"
	self.unit = unit
	self.unitname = UnitName(unit)
	self.unitclass = FS:GetClassColor(unit)
	self:SetOptions(options)
	self:Show()
end

function Arrow:PointToLocation(x, y, options)
	self.mode = "location"
	self.x, self.y = x, y
	self:SetOptions(options)
	self:Show()
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
	options.auto_hide = options.auto_hide or true
end

function Arrow:OnSlashCmd(arg1, arg2)
	if not arg1 then
		if self:IsVisible() then
			self:Hide()
		else
			self:PointToLocation(UnitPosition("player"))
		end
	elseif UnitExists(arg1) then
		self:PointToUnit(arg1)
	elseif arg1 and arg2 then
		self:PointToLocation(tonumber(arg1), tonumber(arg2))
	end
end

function Arrow:FS_MSG(_, prefix, data, channel, sender)
	-- Require the sender to be in the raid group
	if prefix ~= "Arrow" or not FS:UnitIsTrusted(sender) then return end
	local action = data.action or "nil"
	if action == "show" then
		if data.unit then
			print("point to", data.unit)
			self:PointToUnit(data.unit, data.options)
		elseif data.location then
			local x, y = unpack(data.location)
			self:PointToLocation(x, y, data.options)
		end
	elseif action == "hide" then
		self:Hide()
	else
		self:Print("Unknown action: " .. action)
	end
end
