local _, FS = ...
local BWAdapter = FS:RegisterModule("BigWigs")

local spells = setmetatable({}, {__index =
	function(self, key)
		local value
		if key > 0 then
			value = GetSpellInfo(key)
		else
			value = EJ_GetSectionInfo(-key)
		end
		self[key] = value
		return value
	end
})

local icons = setmetatable({}, {__index =
	function(self, key)
		local value
		if type(key) == "number" then
			if key > 0 then
				value = GetSpellTexture(key)
				if not value then
					BWAdapter:Print(format("An invalid spell id (%d) is being used in a bar/message.", key))
				end
			else
				local _, _, _, abilityIcon = EJ_GetSectionInfo(-key)
				if abilityIcon and abilityIcon:trim():len() > 0 then
					value = abilityIcon
				else
					value = false
				end
			end
		else
			value = "Interface\\Icons\\" .. key
		end
		self[key] = value
		return value
	end
})

function BWAdapter:OnEnable()
	self:RegisterMessage("FS_MSG")
	C_Timer.After(2, function()
		LoadAddOn("BigWigs_Core")
		if BigWigs then
			BigWigs:Enable()
		else
			BWAdapter:Disable()
		end
	end)
end

local delayed_actions = {}
function BWAdapter:CancelAll()
	for action, _ in pairs(delayed_actions) do
		action:Cancel()
		delayed_actions[action] = nil
	end
	BigWigs:SendMessage("BigWigs_StopBars", nil)
end

function BWAdapter:Message(msg, color)
	BigWigs:SendMessage("BigWigs_Message", nil, "fs", msg, color)
end

function BWAdapter:Emphasized(msg, r, g, b)
	BigWigs:SendMessage("BigWigs_EmphasizedMessage", msg, r, g, b)
end

function BWAdapter:Sound(sound)
	BigWigs:SendMessage("BigWigs_Sound", nil, "fs", sound)
end

function BWAdapter:Bar(key, length, text, icon)
	local textType = type(text)
	print(key, length, text, icon)
	BigWigs:SendMessage("BigWigs_StartBar", nil, key, textType == "string" and text or spells[text or key], length, icons[icon or textType == "number" and text or key])
end

function BWAdapter:StopBar(text)
	BigWigs:SendMessage("BigWigs_StopBar", nil, type(text) == "number" and spells[text] or text)
end

function BWAdapter:Say(what, channel, target)
	SendChatMessage(what, channel or "SAY", nil, target)
end

local function schedule_number(t, n)
	if t - n > 0 then
		C_Timer.After(t - n, function()
			BigWigs:SendMessage("BigWigs_PlayCountdownNumber", nil, n)
		end)
	end
end

function BWAdapter:Countdown(time)
	for i = 5, 1, -1 do
		schedule_number(time, i)
	end
end

do
	local function execute_action(action, ...)
		if BWAdapter[action] then
			BWAdapter[action](BWAdapter, ...)
		end
	end

	local function parse_action(action)
		if action.delay then
			local timer
			timer = C_Timer.NewTimer(action.delay, function()
				delayed_actions[timer] = nil
				execute_action(unpack(action))
			end)
			delayed_actions[timer] = true
		else
			execute_action(unpack(action))
		end
	end

	function BWAdapter:FS_MSG(_, prefix, data, channel, sender)
		if prefix ~= "BigWigs" or not FS:UnitIsTrusted(sender) or type(data) ~= "table" then return end
		if type(data[1]) == "table" then
			for i = 1, #data do
				parse_action(data[i])
			end
		else
			parse_action(data)
		end
	end
end
