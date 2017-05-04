local _, FS = ...

FS.Util.Spinner = {}

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
	elseif value < 0 then value = 0
	end

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

local function Show(self)
	for i = 1, 4 do
		self._textures[i]:Show();
	end
	self._wedge:Show();
	if self._refresh then
		self._refresh:Show()
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

function FS.Util.Spinner.Create()
	local spinner = CreateFrame('Frame', nil)

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

	spinner._textures = { trTexture, brTexture, blTexture, tlTexture }
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
	spinner.Show = Show
	spinner.Hide = Hide

	local group = wedge:CreateAnimationGroup()
	group:SetScript('OnFinished', function() group:Play() end);
	local rotation = group:CreateAnimation('Rotation')
	spinner._rotation = rotation
	spinner._group = group;
	return spinner
end
