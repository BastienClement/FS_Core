local _, FS = ...

FS.Util.Spinner = {}

local spinnerFunctions = {};

function spinnerFunctions.SetTexture(self, texture)
	for i = 1, 3 do
		self.textures[i]:SetTexture(texture)
	end
end

function spinnerFunctions.SetDesaturated(self, desaturate)
	for i = 1, 3 do
		self.textures[i]:SetDesaturated(desaturate)
	end
end

function spinnerFunctions.SetBlendMode(self, blendMode)
	for i = 1, 3 do
		self.textures[i]:SetBlendMode(blendMode)
	end
end

function spinnerFunctions.Show(self)
	for i = 1, 3 do
		self.textures[i]:Show()
	end
end

function spinnerFunctions.Hide(self)
	for i = 1, 3 do
		self.textures[i]:Hide()
	end
end

function spinnerFunctions.Color(self, r, g, b, a)
	for i = 1, 3 do
		self.textures[i]:SetVertexColor(r, g, b, a)
	end
end

function spinnerFunctions.SetProgress(self, region, angle1, angle2)
	local scalex = 1
	local scaley = 1
	local rotation = 0
	local mirror_h = false
	local mirror_v = false

	if (angle2 - angle1 >= 360) then
		-- SHOW everything
		self.coords[1]:SetFull()
		self.coords[1]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[1]:Show()

		self.coords[2]:Hide()
		self.coords[3]:Hide()
		return
	end
	if (angle1 == angle2) then
		self.coords[1]:Hide()
		self.coords[2]:Hide()
		self.coords[3]:Hide()
		return
	end

	local index1 = floor((angle1 + 45) / 90)
	local index2 = floor((angle2 + 45) / 90)

	if (index1 + 1 >= index2) then
		self.coords[1]:SetAngle(angle1, angle2);
		self.coords[1]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[1]:Show()
		self.coords[2]:Hide()
		self.coords[3]:Hide()
	elseif (index1 + 3 >= index2) then
		local firstEndAngle = (index1 + 1) * 90 + 45
		self.coords[1]:SetAngle(angle1, firstEndAngle)
		self.coords[1]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[1]:Show()

		self.coords[2]:SetAngle(firstEndAngle, angle2)
		self.coords[2]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[2]:Show()

		self.coords[3]:Hide()
	else
		local firstEndAngle = (index1 + 1) * 90 + 45
		local secondEndAngle = firstEndAngle + 180

		self.coords[1]:SetAngle(angle1, firstEndAngle)
		self.coords[1]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[1]:Show()

		self.coords[2]:SetAngle(firstEndAngle, secondEndAngle)
		self.coords[2]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[2]:Show()

		self.coords[3]:SetAngle(secondEndAngle, angle2)
		self.coords[3]:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		self.coords[3]:Show()
	end
end

function spinnerFunctions.SetBackgroundOffset(self, region, offset)
	for i = 1, 3 do
		self.textures[i]:SetPoint('TOPRIGHT', region, offset, offset)
		self.textures[i]:SetPoint('BOTTOMRIGHT', region, offset, -offset)
		self.textures[i]:SetPoint('BOTTOMLEFT', region, -offset, -offset)
		self.textures[i]:SetPoint('TOPLEFT', region, -offset, offset)
	end
end

function spinnerFunctions:SetSize(width, height)
	self.frame:SetSize(width, height)
	for i = 1, 3 do
		self.textures[i]:SetHeight(height)
	end
	for i = 1, 3 do
		self.textures[i]:SetWidth(width)
	end
end

local defaultTexCoord = {
	ULx = 0,
	ULy = 0,
	LLx = 0,
	LLy = 1,
	URx = 1,
	URy = 0,
	LRx = 1,
	LRy = 1,
};

local function createTexCoord(texture)
	local coord = {
		ULx = 0,
		ULy = 0,
		LLx = 0,
		LLy = 1,
		URx = 1,
		URy = 0,
		LRx = 1,
		LRy = 1,
		ULvx = 0,
		ULvy = 0,
		LLvx = 0,
		LLvy = 0,
		URvx = 0,
		URvy = 0,
		LRvx = 0,
		LRvy = 0,
		texture = texture
	}

	function coord:MoveCorner(corner, x, y)
		local width, height = self.texture:GetSize()
		local rx = defaultTexCoord[corner .. "x"] - x
		local ry = defaultTexCoord[corner .. "y"] - y
		coord[corner .. "vx"] = -rx * width
		coord[corner .. "vy"] = ry * height

		coord[corner .. "x"] = x
		coord[corner .. "y"] = y
	end

	function coord:Hide()
		coord.texture:Hide()
	end

	function coord:Show()
		coord:Apply()
		coord.texture:Show()
	end

	function coord:SetFull()
		coord.ULx = 0
		coord.ULy = 0
		coord.LLx = 0
		coord.LLy = 1
		coord.URx = 1
		coord.URy = 0
		coord.LRx = 1
		coord.LRy = 1

		coord.ULvx = 0
		coord.ULvy = 0
		coord.LLvx = 0
		coord.LLvy = 0
		coord.URvx = 0
		coord.URvy = 0
		coord.LRvx = 0
		coord.LRvy = 0
	end

	function coord:Apply()
		coord.texture:SetVertexOffset(UPPER_RIGHT_VERTEX, coord.URvx, coord.URvy)
		coord.texture:SetVertexOffset(UPPER_LEFT_VERTEX, coord.ULvx, coord.ULvy)
		coord.texture:SetVertexOffset(LOWER_RIGHT_VERTEX, coord.LRvx, coord.LRvy)
		coord.texture:SetVertexOffset(LOWER_LEFT_VERTEX, coord.LLvx, coord.LLvy)

		coord.texture:SetTexCoord(coord.ULx, coord.ULy, coord.LLx, coord.LLy, coord.URx, coord.URy, coord.LRx, coord.LRy)
	end

	local exactAngles = {
		{ 0.5, 0 }, -- 0°
		{ 1, 0 }, -- 45°
		{ 1, 0.5 }, -- 90°
		{ 1, 1 }, -- 135°
		{ 0.5, 1 }, -- 180°
		{ 0, 1 }, -- 225°
		{ 0, 0.5 }, -- 270°
		{ 0, 0 } -- 315°
	}

	local function angleToCoord(angle)
		angle = angle % 360

		if (angle % 45 == 0) then
			local index = floor(angle / 45) + 1
			return exactAngles[index][1], exactAngles[index][2]
		end

		if (angle < 45) then
			return 0.5 + tan(angle) / 2, 0
		elseif (angle < 135) then
			return 1, 0.5 + tan(angle - 90) / 2
		elseif (angle < 225) then
			return 0.5 - tan(angle) / 2, 1
		elseif (angle < 315) then
			return 0, 0.5 - tan(angle - 90) / 2
		elseif (angle < 360) then
			return 0.5 + tan(angle) / 2, 0
		end
	end

	local pointOrder = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }

	function coord:SetAngle(angle1, angle2)
		local index = floor((angle1 + 45) / 90)

		local middleCorner = pointOrder[index + 1]
		local startCorner = pointOrder[index + 2]
		local endCorner1 = pointOrder[index + 3]
		local endCorner2 = pointOrder[index + 4]

		-- LL => 32, 32
		-- UL => 32, -32
		self:MoveCorner(middleCorner, 0.5, 0.5)
		self:MoveCorner(startCorner, angleToCoord(angle1))

		local edge1 = floor((angle1 - 45) / 90)
		local edge2 = floor((angle2 - 45) / 90)

		if (edge1 == edge2) then
			self:MoveCorner(endCorner1, angleToCoord(angle2))
		else
			self:MoveCorner(endCorner1, defaultTexCoord[endCorner1 .. "x"], defaultTexCoord[endCorner1 .. "y"])
		end

		self:MoveCorner(endCorner2, angleToCoord(angle2))
	end

	local function TransformPoint(x, y, scalex, scaley, rotation, mirror_h, mirror_v)
		-- 1) Translate texture-coords to user-defined center
		x = x - 0.5
		y = y - 0.5

		-- 2) Shrink texture by 1/sqrt(2)
		--x = x * 1.4142
		--y = y * 1.4142

		-- Not yet supported for circular progress
		-- 3) Scale texture by user-defined amount
		x = x / scalex
		y = y / scaley

		-- 4) Apply mirroring if defined
		if mirror_h then
			x = -x
		end
		if mirror_v then
			y = -y
		end

		local cos_rotation = cos(rotation)
		local sin_rotation = sin(rotation)

		-- 5) Rotate texture by user-defined value
		x, y = cos_rotation * x - sin_rotation * y, sin_rotation * x + cos_rotation * y

		-- 6) Translate texture-coords back to (0,0)
		x = x + 0.5
		y = y + 0.5

		return x, y
	end

	function coord:Transform(scalex, scaley, rotation, mirror_h, mirror_v)
		coord.ULx, coord.ULy = TransformPoint(coord.ULx, coord.ULy, scalex, scaley, rotation, mirror_h, mirror_v)
		coord.LLx, coord.LLy = TransformPoint(coord.LLx, coord.LLy, scalex, scaley, rotation, mirror_h, mirror_v)
		coord.URx, coord.URy = TransformPoint(coord.URx, coord.URy, scalex, scaley, rotation, mirror_h, mirror_v)
		coord.LRx, coord.LRy = TransformPoint(coord.LRx, coord.LRy, scalex, scaley, rotation, mirror_h, mirror_v)
	end

	return coord
end

function FS.Util.Spinner.Create()
	local spinner = {}
	spinner.frame = CreateFrame("Frame", nil)

	local clockwise = true
	local reverse = true

	spinner.textures = {}
	spinner.coords = {}

	for i = 1, 3 do
		local texture = spinner.frame:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints(spinner.frame)
		spinner.textures[i] = texture

		spinner.coords[i] = createTexCoord(texture)
	end

	for k, v in pairs(spinnerFunctions) do
		spinner[k] = v
	end

	function spinner:SetClockwise(cw)
		clockwise = cw
	end

	function spinner:SetReverse(rev)
		reverse = rev
	end

	function spinner:SetValue(progress)
		progress = progress or 0
		if reverse then progress = 1 - progress end
		spinner.progress = progress

		if (progress < 0) then
			progress = 0
		end

		if (progress > 1) then
			progress = 1
		end

		if (not clockwise) then
			progress = 1 - progress
		end

		local pAngle = 360 * progress

		if (clockwise) then
			spinner:SetProgress(spinner, 0, pAngle)
		else
			spinner:SetProgress(spinner, pAngle, 360)
		end
	end

	return spinner
end
