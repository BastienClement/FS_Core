local _, FS = ...
local BW = FS:RegisterModule("BigWigs")

--------------------------------------------------------------------------------
-- Spell name and icon extractors
-- Take from BigWigs

local spells = setmetatable({}, {__index =
	function(self, key)
		local value
		if type(key) == "string" then
			value = key
		elseif key > 0 then
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
					BW:Print(format("An invalid spell id (%d) is being used in a bar/message.", key))
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

--------------------------------------------------------------------------------

function BW:OnEnable()
	-- Force BigWigs loading
	C_Timer.After(2, function()
		LoadAddOn("BigWigs_Core")
		if BigWigs then
			BigWigs:Enable()
		else
			BW:Disable()
		end
	end)
	
	self:RegisterMessage("FS_MSG_BIGWIGS")
	self:RegisterEvent("ENCOUNTER_END")
end

function BW:ENCOUNTER_END()
	self:CancelAll()
	BigWigs:SendMessage("BigWigs_StopBars", nil)
end

--------------------------------------------------------------------------------

do
	local actions = {}

	function BW:ScheduleAction(key, delay, fn, ...)
		-- Default value for action key
		if not key then
			key = "none"
		end
		
		-- The action timer
		local timer
		local args = { ... }
		timer = C_Timer.NewTimer(delay, function()
			actions[timer] = nil
			fn(unpack(args))
		end)
		
		-- Register the timer
		actions[timer] = key
	end
	
	function BW:CancelActions(key)
		-- Timer to cancel
		local canceling
		
		-- Search for timer with matching key
		for timer, akey in pairs(actions) do
			if akey == key then
				if not canceling then canceling = {} end
				table.insert(canceling, timer)
			end
		end
		
		-- No timer found
		if not canceling then return end
		
		-- Timer to cancel
		for _, timer in ipairs(canceling) do
			timer:Cancel()
			actions[timer] = nil
		end
	end

	function BW:CancelAllActions()
		for timer, _ in pairs(actions) do
			timer:Cancel()
		end
		wipe(actions)
	end
end

--------------------------------------------------------------------------------

function BW:Message(key, msg, color)
	BigWigs:SendMessage("BigWigs_Message", nil, key, msg, color)
end

function BW:Emphasized(key, msg, r, g, b)
	BigWigs:SendMessage("BigWigs_EmphasizedMessage", msg, r, g, b)
end

function BW:Sound(key, sound)
	BigWigs:SendMessage("BigWigs_Sound", nil, key, sound)
end

function BW:Say(key, what, channel, target)
	SendChatMessage(what, channel or "SAY", nil, target)
end

-- Bars
do
	local bar_text = {}
	
	function BW:Bar(key, length, text, icon)
		-- Determine bar text
		local textType = type(text)
		local text = textType == "string" and text or spells[text or key]
		
		-- Create BW bar
		BigWigs:SendMessage("BigWigs_StartBar", nil, key, text, length, icons[icon or textType == "number" and text or key])
		
		-- Save the text for canceling
		bar_text[key] = text
		self:ScheduleAction(key, length, function()
			bar_texts[key] = nil
		end)
	end

	function BW:StopBar(key)
		local text = bar_text[key] or key
		BigWigs:SendMessage("BigWigs_StopBar", nil, type(text) == "number" and spells[text] or text)
	end
end

-- Countdown
do
	local function schedule_number(key, t, n)
		if t - n > 0 then
			BW:ScheduleAction(key, t - n, function()
				BigWigs:SendMessage("BigWigs_PlayCountdownNumber", nil, n)
			end)
		end
	end

	function BW:Countdown(key, time)
		for i = 5, 1, -1 do
			schedule_number(key, time, i)
		end
	end
end

--------------------------------------------------------------------------------

do
	local function execute_action(action, ...)
		if BW[action] then
			BW[action](BW, ...)
		end
	end

	local function schedule_action(action)
		if action.delay then
			BW:ScheduleAction(action[2], action.delay, execute_action, unpack(action))
		else
			execute_action(unpack(action))
		end
	end

	function BW:FS_MSG_BIGWIGS(_, data, channel, sender)
		if not FS:UnitIsTrusted(sender) or type(data) ~= "table" then return end
		if type(data[1]) == "table" then
			for i = 1, #data do
				schedule_action(data[i])
			end
		else
			schedule_action(data)
		end
	end
end
