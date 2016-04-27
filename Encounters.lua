local _, FS = ...
local Encounters = FS:RegisterModule("Encounters", "AceTimer-3.0")
local Events = LibStub("AceAddon-3.0"):NewAddon("FS_Core_Encounters_Event", "AceEvent-3.0")

local Roster, Tracker, Map, Geometry, Network, BigWigs

-------------------------------------------------------------------------------
-- Encounters config
--------------------------------------------------------------------------------

local encounters_config = {
	title = {
		type = "description",
		name = "|cff64b4ffEncounters",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Framework for building boss encounter mods in Pacman.\n",
		fontSize = "medium",
		order = 1
	},
	transcriptor = {
		type = "toggle",
		name = "Enable Transcriptor integration",
		order = 2,
		width = "full",
		disabled = function() return not Transcriptor end,
		get = function() return Encounters.settings.transcriptor end,
		set = function(_, v) Encounters.settings.transcriptor = v end
	},
	transcriptor_desc = {
		type = "description",
		name = "|cff999999Transcriptor recording will be started and stopped automatically on boss pull / wipe.\n",
		order = 2.5,
		width = "full"
	},
	autoremove = {
		type = "toggle",
		name = "Automatically delete old transcripts",
		order = 4,
		width = "full",
		disabled = function() return not Transcriptor end,
		get = function() return Encounters.settings.auto_remove end,
		set = function(_, v) Encounters.settings.auto_remove = v end
	},
	autoremove_desc = {
		type = "description",
		name = "|cff999999When engaging a new encounter, transcripts from old ones are automatically removed.\n",
		order = 5,
		width = "full"
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":RegisterEncounter ( name , id ) -> mod", "Registers a new boss module bound to the given encounter id. If a new module is registered with the same name, the previous one is replaced."},
	}, "FS.Encounters"),
	events = FS.Config:MakeDoc("Mod API", 3000, {
		{":OnEngage ( id , name , difficulty , size )", "Called on encounter start.\nModules should override this method."},
		{":OnReset ( kill )", "Called on encounter end.\nModules should override this method.\n"},
		{":CombatLog ( event , handler , [ spells ... ] )", "Binds a combat log listener. The given handler method will be invoked whenever a combat log event matching both the requested `event` type and one of the `spell` id is received."},
		{":Event ( event , handler , [ firstArgs ... ] )", "Binds an event listener. The given handler method will be invoked whenever a Blizzard event matching both the requested `event` type and one of the `firstArg` is received."},
		{":Death ( handler , [ mobIds ... ] )", "Binds an death listener. The given handler method will be invoked whenever a death event matching one of the requested `mobId` is received."},
		{":Network ( type , handler )", "Binds a network message listener. The given handler method will be invoked whenever a network message matching the requested `type` is received."},
		{":Ace ( type , handler )", "Binds an Ace3 message listener. The given handler method will be invoked whenever an Ace3 message matching the requested `type` is received."},
		{":Intercept ( handler , msg )", "Intercepts and transform BigWigs internal messages to dynamically alter bars and messages.\n"},
		{":Message ( key , msg , color , sound )", "Displays a message"},
		{":Emphasized ( key , msg , r , g , b , sound )", "Displays an emphasized message."},
		{":Sound ( key , sound )", "Play the requested sound.\n`sound` can be Long, Info, Alert, Alarm or Warning."},
		{":Bar ( key , duration , text , icon )", "Starts a BigWigs bar for the requested duration."},
		{":StopBar ( key )", "Cancels a bar started with :Bar()."},
		{":Say ( key , msg , channel , target )", "/say."},
		{":Countdown ( key , time )", "Starts a vocal countdown."},
		{":Proximity ( key , range , player , isReverse )", "Opens BigWigs proximity display."},
		{":CloseProximity ( key )", "Closes BigWigs proximity display."},
		{":Flash ( key )", "Flashes the screen."},
		{":Pulse ( key , icon )", "Displays a BigWigs pulse icon."},
		{":Mark ( guid , callback )", "Mark the requested unit with the first available sign.\nCallback is called when marking is done with (guid, icon_idx) as parameters."},
		{":Unmark ( guid )", "Remove the mark from the given unit.\n"},
		{":ScheduleAction ( key , delay , handler , ... )", "Schedules an action to be executed after `delay` seconds. Additional arguments will be given to the handler function."},
		{":CancelAction ( key )", "Cancels a scheduled action."},
		{":CancelAllActions ( )", "Cancels all scheduled actions.\n"},
		{":Send ( type , data , target )", "Sends a network message."},
		{":Emit ( msg , ... )", "Emits an Ace3 event.\n"},
		{":Difficulty ( ) -> number", "Returns the encounter difficulty ID."},
		{":LFR ( ) -> boolean", "Returns true if currently fighting a LFR encounter."},
		{":Easy ( ) -> boolean", "Returns true if currently fighting a Easy encounter."},
		{":Normal ( ) -> boolean", "Returns true if currently fighting a Normal encounter."},
		{":Heroic ( ) -> boolean", "Returns true if currently fighting a Heroic encounter."},
		{":Mythic ( ) -> boolean", "Returns true if currently fighting a Mythic encounter."},
		{":RaidSize ( ) -> number", "Returns the number of players participating in the encounter.\n"},
		{":MobId ( mobGUID ) -> number", "Returns the MobId from a creature GUID."},
		{":Me ( unitGUID ) -> boolean", "Checks if the given GUID is the player."},
		{":Range ( playerA [, playerB ] , squared ) -> number", "Returns the distance between playerA and playerB. If playerB is not given, it defaults to the player. If squared is true, returned number is the squared value of the distance."},
		{":Role ( [ unit ] ) -> tank | healer | melee | ranged", "Returns the role of the given unit. Defaults to the player."},
		{":Melee ( [ unit ] ) -> boolean", "Returns true if the given unit is a melee damager."},
		{":Ranged ( [ unit ] ) -> boolean", "Returns true if the given unit is a ranged damager."},
		{":Tank ( [ unit ] ) -> boolean", "Returns true if the given unit is a tank."},
		{":Healer ( [ unit ] ) -> boolean", "Returns true if the given unit is a header."},
		{":Damager ( [ unit ] ) -> boolean", "Returns true if the given unit is a damager (melee or ranged).\n"},
		{":IterateGroup ( [ limit [, sorted ]] ) -> [ units ]", "Iterates over every units in the group. See Roster:Iterate()."},
	}, "mod")
}

local encounters_default = {
	profile = {
		transcriptor = false,
		auto_remove = true,
		last_encounter = 0,
	}
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local autoTable = {}
autoTable.__index = function(self, key)
	local t = setmetatable({}, autoTable)
	self[key] = t
	return t
end

local function get(t, k, ...)
	if not t then return nil end
	if not k then return t end
	return get(rawget(t, k), ...)
end

local function wrap(self, handler)
	return function(...)
		self[handler](self, ...)
	end
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------

local modules = {}
local encounters = {}
local actives = {}

local encounterInProgress = false
local playerRegenEnabled = true
local transcriptorLogging = false

local encounter = 0
local encounterName = ""
local difficulty = 0
local raidSize = 0

local playerGUID = ""
local role = "NONE"

local events = setmetatable({}, autoTable)

local registered = {}
local aceRegistered = {}
local allowedCleu = {}
local cleuBound = false
local allowedMsg = {}
local msgBound = false

local marks = {}
local marks_queue = {}
local marks_count = 0
local marked = {}
local marked_callback = {}
local marks_scanner

-------------------------------------------------------------------------------
-- Life-cycle events
-------------------------------------------------------------------------------

function Encounters:OnInitialize()
	Roster = FS.Roster
	Tracker = FS.Tracker
	Map = FS.Map
	Geometry = FS.Geometry
	Network = FS.Network
	BigWigs = FS.BigWigs

	self.db = FS.db:RegisterNamespace("Encounters", encounters_default)
	self.settings = self.db.profile
	FS.Config:Register("Encounters", encounters_config)
end

function Encounters:OnEnable()
	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("ENCOUNTER_END")
	self:RegisterEvent("BOSS_KILL")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterMessage("FS_TRACKER_DIED")
end

function Encounters:OnDisable()
end

function Encounters:UpdateData()
	playerGUID = UnitGUID("player")

	local tree = GetSpecialization()
	if tree then
		role = GetSpecializationRole(tree)
		if role == "DAMAGER" then
			local _, class = UnitClass("player")
			if class == "MAGE" or class == "WARLOCK" or
					(class == "HUNTER" and tree ~= 3) or
					(class == "DRUID" and tree == 1) or
					(class == "PRIEST" and tree == 3) or
					(class == "SHAMAN" and tree == 1)
			then
				role = "ranged"
			else
				role = "melee"
			end
		elseif role == "TANK" then
			role = "tank"
		elseif role == "HEALER" then
			role = "healer"
		else
			role = "NONE"
		end
	else
		role = "NONE"
	end
end

function Encounters:UnitId(guid)
	if UnitExists(guid) then
		return guid
	elseif guid:sub(1, 6) == "Player" then
		return Roster:GetUnit(guid)
	else
		return Tracker:GetUnit(guid)
	end
end

function Encounters:ENCOUNTER_START(_, id, name, diff_id, size)
	if encounterInProgress then
		-- Fake an ENCOUNTER_END event if a new _START is detected
		self:ENCOUNTER_END(_, encounter, encounterName, difficulty, raidSize, 0)
	end

	self:Printf("Pulling |cff64b4ff%s |cff999999(%i, %i, %i)", name, id, diff_id, size)
	encounterInProgress = true

	encounter = id
	encounterName = name
	difficulty = diff_id
	raidSize = size

	if self.settings.transcriptor and Transcriptor then
		self:TranscriptorStart(id)
	end

	local mods = encounters[id]
	if not mods then return end

	self:UpdateData()

	for mod in pairs(mods) do
		mod:Engage(id, name, diff_id, size)
		actives[mod] = true
	end
end

function Encounters:ENCOUNTER_END(_, id, name, diff_id, size, kill)
	if not encounterInProgress then return end

	kill = kill == 1
	self:Printf("%s |cff64b4ff%s |cff999999(%i, %i, %i)", kill and "Killed" or "Wiped on", name, id, diff_id, size)
	encounterInProgress = false

	if transcriptorLogging then
		self:TranscriptorEnd(true)
	end

	for mod in pairs(actives) do
		mod:Reset(kill)
	end

	if cleuBound then
		Events:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		cleuBound = false
	end

	if msgBound then
		Events:UnregisterMessage("FS_MSG_ENCOUNTERS")
		msgBound = false
	end

	for event in pairs(registered) do
		Events:UnregisterEvent(event)
	end

	for event in pairs(aceRegistered) do
		Events:UnregisterMessage(event)
	end

	self:UnmarkAll()
	BigWigs:ClearIntercepts()

	wipe(actives)
	wipe(events)
	wipe(registered)
	wipe(aceRegistered)
	wipe(allowedCleu)
	wipe(allowedMsg)
end


function Encounters:BOSS_KILL(_, id, name)
	self:ENCOUNTER_END("ENCOUNTER_END", id, name, difficulty, raidSize, 1)
end

function Encounters:PLAYER_REGEN_DISABLED()
	playerRegenEnabled = false
end

function Encounters:PLAYER_REGEN_ENABLED()
	playerRegenEnabled = true
	if not encounterInProgress then return end
	self:ScheduleTimer("CheckForWipe", 2)
end

function Encounters:CheckForWipe()
	if not encounterInProgress or not playerRegenEnabled then return end
	if not IsEncounterInProgress() then
		self:ENCOUNTER_END("ENCOUNTER_END", encounter, encounterName, difficulty, raidSize, 0)
	else
		self:ScheduleTimer("CheckForWipe", 2)
	end
end

function Encounters:TranscriptorStart(id)
	if transcriptorLogging then self:TranscriptorEnd(false) end
	transcriptorLogging = true

	if self.settings.last_encounter ~= id and self.settings.auto_remove then
		self.settings.last_encounter = id
		Transcriptor:ClearAll()
	end

	Transcriptor:StartLog()
end

function Encounters:TranscriptorEnd(delayed)
	if not transcriptorLogging then return end
	if delayed then
		C_Timer.After(3, function()
			self:TranscriptorEnd(false)
		end)
	else
		transcriptorLogging = false
		local name = Transcriptor:StopLog()
		if name then
			local log = Transcriptor:Get(name)
			if #log.total == 0 or tonumber(log.total[#log.total]:match("^<(.-)%s")) < 30 then
				Transcriptor:Clear(name)
				self:Printf("Removed a < 30 sec transcript")
			end
		end
	end
end

do
	local function do_dispatch(event, filters, key, orig_key, ...)
		local match = get(filters, key)
		if match then
			for module, handler in pairs(match) do
				if type(handler) == "function" then
					if orig_key == "*" then
						handler(event, ...)
					else
						handler(event, orig_key, ...)
					end
				elseif type(module[handler]) == "function" then
					if orig_key == "*" then
						module[handler](module, event, ...)
					else
						module[handler](module, event, orig_key, ...)
					end
				else
					Encounters:Printf("|cffffff00Unable to invoke handler %s", handler)
				end
			end
		end
	end

	function Encounters:Dispatch(event, key, ...)
		local filters = get(events, event)
		if filters then
			if key then
				do_dispatch(event, filters, key, key, ...)
			end
			if key == "*" then
				return
			end
			do_dispatch(event, filters, "*", key, ...)
		end
	end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function Encounters:RegisterCombatLog(module, event, id, handler)
	events[event][id][module] = handler
	allowedCleu[event] = true
	if not cleuBound then
		Events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		cleuBound = true
	end
end

local args = {}
function Events:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount)
	if allowedCleu[event] then
		if event == "UNIT_DIED" then
			local _, _, _, _, _, id = strsplit("-", destGUID)
			local mobId = tonumber(id)
			args.mobId, args.destGUID, args.destName, args.destFlags, args.destRaidFlags = mobId, destGUID, destName, destFlags, destRaidFlags
			if mobId then
				args.mobId, args.destGUID, args.destName, args.destFlags, args.destRaidFlags = mobId, destGUID, destName, destFlags, destRaidFlags
				Encounters:Dispatch(event, mobId, args)
			else
				Encounters:Dispatch(event, -1, args)
			end
		else
			args.sourceGUID, args.sourceName, args.sourceFlags, args.sourceRaidFlags = sourceGUID, sourceName, sourceFlags, sourceRaidFlags
			args.destGUID, args.destName, args.destFlags, args.destRaidFlags = destGUID, destName, destFlags, destRaidFlags
			args.spellId, args.spellName, args.extraSpellId, args.extraSpellName, args.amount = spellId, spellName, extraSpellId, amount, amount
			args.destKey = destGUID .. spellId
			Encounters:Dispatch(event, spellId, args)
		end
	end
end

function Encounters:RegisterGenericEvent(module, event, unit, handler)
	events[event][unit][module] = handler
	if not registered[event] then
		Events:RegisterEvent(event, "GENERIC_EVENT")
		registered[event] = true
	end
end

function Events:GENERIC_EVENT(event, unit, ...)
	Encounters:Dispatch(event, unit, ...)
end

function Encounters:RegisterNetMessage(module, event, handler)
	events[event]["*"][module] = handler
	allowedMsg[event] = true
	if not msgBound then
		Events:RegisterMessage("FS_MSG_ENCOUNTERS")
		msgBound = true
	end
end

function Events:FS_MSG_ENCOUNTERS(_, msg, channel, source)
	local event = msg.event
	if allowedMsg[event] then
		Encounters:Dispatch(event, "*", msg.data, channel, source)
	end
end

function Encounters:RegisterAceEvent(module, event, firstArg, handler)
	events[event][firstArg][module] = handler
	if not aceRegistered[event] then
		Events:RegisterMessage(event, "ACE_EVENT")
		aceRegistered[event] = true
	end
end

function Events:ACE_EVENT(event, firstArg, ...)
	Encounters:Dispatch(event, firstArg, ...)
end

-------------------------------------------------------------------------------
-- Module prototype
-------------------------------------------------------------------------------

local Module = {}
Module.__index = Module

function Module:New(name, encounter)
	return setmetatable({
		name = name,
		encounter = encounter,
		spells = BigWigs.spells,
		spell = BigWigs.spells,
		icons = BigWigs.icons,
		icon = BigWigs.icons
	}, Module)
end

function Module:Engage(id, name, diff_id, size)
	if self.OnEngage then
		self:OnEngage(id, name, diff_id, size)
	end
end

function Module:Reset(kill)
	if self.OnReset then
		self:OnReset(kill)
	end
end

-------------------------------------------------------------------------------
-- Bindings
-------------------------------------------------------------------------------

function Module:CombatLog(event, handler, ...)
	if not handler then handler = event end
	local n = select("#", ...)
	if n < 1 then
		Encounters:RegisterCombatLog(self, event, "*", handler)
	else
		for i = 1, n do
			local id = select(i, ...)
			Encounters:RegisterCombatLog(self, event, id, handler)
		end
	end
end

function Module:Event(event, handler, ...)
	if not handler then handler = event end
	local n = select("#", ...)
	if n < 1 then
		Encounters:RegisterGenericEvent(self, event, "*", handler)
	else
		for i = 1, n do
			local id = select(i, ...)
			Encounters:RegisterGenericEvent(self, event, id, handler)
		end
	end
end

function Module:Death(handler, ...)
	return self:CombatLog("UNIT_DIED", handler, ...)
end

function Module:Network(event, handler)
	if not handler then handler = event end
	Encounters:RegisterNetMessage(self, event, handler)
end

function Module:Ace(event, handler, ...)
	if not handler then handler = event end
	local n = select("#", ...)
	if n < 1 then
		Encounters:RegisterAceEvent(self, event, "*", handler)
	else
		for i = 1, n do
			local id = select(i, ...)
			Encounters:RegisterAceEvent(self, event, id, handler)
		end
	end
end

function Module:Intercept(handler, ...)
	local n = select("#", ...)
	if n < 1 then error("Usage: mod:Intercept(handler, msg, ...)") end

	if type(handler) == "string" then handler = wrap(self, handler) end

	for i = 1, n do
		local msg = select(i, ...)
		BigWigs:Intercept("BigWigs_" .. msg, handler)
	end
end

-------------------------------------------------------------------------------
-- Displays
-------------------------------------------------------------------------------

function Module:Message(...)
	BigWigs:Message(...)
end

function Module:Emphasized(...)
	BigWigs:Emphasized(...)
end

function Module:Sound(...)
	BigWigs:Sound(...)
end

function Module:Bar(...)
	BigWigs:Bar(...)
end

function Module:StopBar(...)
	BigWigs:StopBar(...)
end

function Module:Say(...)
	BigWigs:Say(...)
end

function Module:Countdown(...)
	BigWigs:Countdown(...)
end

function Module:Proximity(...)
	BigWigs:Proximity(...)
end

function Module:Flash(...)
	BigWigs:Flash(...)
end

function Module:Pulse(...)
	BigWigs:Pulse(...)
end

function Module:ScheduleAction(key, delay, handler, ...)
	if type(handler) == "string" then handler = wrap(self, handler) end
	BigWigs:ScheduleAction(key, delay, handler, ...)
end

function Module:ScheduleActionOnce(key, delay, handler, ...)
	if type(handler) == "string" then handler = wrap(self, handler) end
	BigWigs:ScheduleActionOnce(key, delay, handler, ...)
end

function Module:CancelActions(...)
	BigWigs:CancelActions(...)
end

function Module:CancelAllActions(...)
	BigWigs:CancelAllActions(...)
end

-------------------------------------------------------------------------------
-- Emits
-------------------------------------------------------------------------------

function Module:Send(event, data, target)
	FS:Send("ENCOUNTERS", { event = event, data = data }, target)
end

function Module:Emit(msg, ...)
	Encounters:SendMessage(msg, ...)
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

function Module:Difficulty()
	return difficulty
end

function Module:LFR()
	return difficulty == 7 or difficulty == 17
end

function Module:Easy()
	return difficulty == 14 or difficulty == 17
end

function Module:Normal()
	return difficulty == 1 or difficulty == 3 or difficulty == 4 or difficulty == 14
end

function Module:Heroic()
	return difficulty == 2 or difficulty == 5 or difficulty == 6 or difficulty == 15
end

function Module:Mythic()
	return difficulty == 16
end

function Module:RaidSize()
	return Encounters.raidSize
end

function Module:UnitId(guid)
	return Encounters:UnitId(guid)
end

function Module:MobId(guid)
	if UnitExists(guid) then guid = UnitGUID(guid) end
	if not guid then return 1 end
	local _, _, _, _, _, id = strsplit("-", guid)
	return tonumber(id) or 1
end

function Module:Me(guid)
	if guid == playerGUID then
		return true
	elseif UnitExists(guid) and UnitIsUnit(guid, "player") then
		return true
	else
		return false
	end
end

function Module:Range(player, other, squared)
	if not other then other = "player" end
	local tx, ty = UnitPosition(player)
	local ux, uy = UnitPosition(other)
	if not tx or not ux then
		return 200
	else
		return Geometry.Distance(tx, ty, ux, uy, squared)
	end
end

function Module:Role(player)
	if player then
		if UnitExists(player) then
			player = UnitGUID(player)
		end
		local info = Roster:GetInfo(player)
		return info and info.spec_role_detailed or "NONE"
	else
		return role
	end
end

function Module:Melee(player)
	local role = self:Role(player)
	return role == "melee" or role == "tank"
end

function Module:Ranged(player)
	local role = self:Role(player)
	return role == "ranged" or role == "healer"
end

function Module:Tank(player)
	return self:Role(player) == "tank"
end

function Module:Healer(player)
	return self:Role(player) == "healer"
end

function Module:Damager(player)
	return self:Role(player) == "melee" or self:Role(player) == "ranged"
end

function Module:Mark(guid, callback)
	if type(callback) == "string" then callback = wrap(self, callback) end
	Encounters:Mark(guid, callback)
end

function Module:Unmark(guid)
	Encounters:Unmark(guid)
end

function Module:UnmarkAll()
	Encounters:UnmarkAll()
end

function Module:IterateGroup(...)
	return Roster:Iterate(...)
end

-------------------------------------------------------------------------------
-- Configuration generator
-------------------------------------------------------------------------------

do
	local function config_builder(t)
		local order = 0
		local builder = {}

		function builder:Add(ct)
			order = order + 1
			ct.order = order
			t["_opt" .. order] = ct
		end

		return builder
	end

	function Module:Options(env)
		local db = env.db
		if not db.opts then db.opts = {} end
		local opts = db.opts

		return function(confs)
			local config = {}
			local keys = {}
			env.config = config
			local builder = config_builder(config)

			-- Options defaults to true
			for key, data in pairs(confs) do
				table.insert(keys, key)

				local default = data.default
				if default == nil then default = true end

				if opts[key] == nil then
					opts[key] = default
				end
			end

			table.sort(keys, function(a, b)
				return (confs[a]._order or 0) < (confs[b]._order or 0)
			end)

			-- Build option table
			for _, key in ipairs(keys) do
				local data = confs[key]
				local spell, suffix, desc = unpack(data)

				if type(spell) ~= "number" then
					desc = suffix
					suffix = spell
					spell = nil
				end

				if not desc then
					desc = suffix
					suffix = nil
				end

				local name
				if spell then
					local spellname, _, icon = GetSpellInfo(spell)
					name = (" |T%s:18|t %s"):format(icon, spellname)
				else
					name = " " .. suffix
					suffix = nil
				end

				if suffix then
					name = name .. " |cffff7d0a(" .. suffix .. ")"
				end

				builder:Add({
					type = "toggle",
					name = name,
					width = "full",
					desc = GetSpellDescription(spell),
					get = function() return opts[key] end,
					set = function(_, v)
						opts[key] = v
						if self.OnOptionChanged then
							self:OnOptionChanged(key, v)
						end
					end
				})

				builder:Add({
					type = "description",
					name = "|cff999999" .. (desc and (desc .. "\n") or "")
				})
			end

			-- Cleanup
			for _, key in pairs(keys) do
				if not confs[key] then
					opts[key] = nil
				end
			end

			return opts
		end
	end

	local opt_counter = 1

	function Module:opt(t)
		t._order = opt_counter
		opt_counter = opt_counter + 1
		return t
	end
end

-------------------------------------------------------------------------------
-- Encounter definition
-------------------------------------------------------------------------------

-- Registers a new encounter module
function Encounters:RegisterEncounter(name, encounter)
	local mod = modules[name]

	if mod then
		local old_encounter = mod.encounter
		local mods = encounters[old_encounter]
		mods[mod] = nil
		if not next(mods) then
			encounters[old_encounter] = nil
		end
	end

	mod = Module:New(name, encounter)
	modules[name] = mod

	local mods = encounters[encounter]
	if mods then
		mods[mod] = true
	else
		encounters[encounter] = { [mod] = true }
	end

	return mod
end

-------------------------------------------------------------------------------
-- Marking helper
-------------------------------------------------------------------------------

function Encounters:Mark(guid, callback)
	if not marked[guid] then
		marked[guid] = 0
		table.insert(marks_queue, guid)
		if type(callback) == "function" then
			marked_callback[guid] = callback
		end
		if marks_count < 8 and not marks_scanner then
			marks_scanner = self:ScheduleRepeatingTimer("MarkScan", 0.1)
		end
	end
end

function Encounters:Unmark(guid)
	local mark = marked[guid]
	if mark then
		if mark > 0 then
			local unit = self:UnitId(guid)
			if unit then
				SetRaidTarget(unit, 0)
			end
			marks[mark] = nil
			marks_count = marks_count - 1
			if marks_count == 7 and #marks_queue > 0 and not marks_scanner then
				marks_scanner = self:ScheduleRepeatingTimer("MarkScan", 0.1)
			end
		else
			for i, g in ipairs(marks_queue) do
				if g == guid then
					table.remove(marks_queue, i)
					break
				end
			end
		end
		marked[guid] = nil
	end
end

function Encounters:MarkScan()
	if #marks_queue == 0 or marks_count == 8 then
		self:CancelTimer(marks_scanner)
		marks_scanner = nil
	else
		local i = 1
		while i <= #marks_queue and marks_count < 8 do
			local guid = marks_queue[i]
			local unit = self:UnitId(guid)
			if unit then
				for j = 1, 8 do
					if not marks[j] then
						marks[j] = guid
						marked[guid] = j
						local callback = marked_callback[guid]
						SetRaidTarget(unit, j)
						if callback then
							pcall(callback, guid, j)
							marked_callback[guid] = nil
						end
						table.remove(marks_queue, i)
						marks_count = marks_count + 1
						break
					end
				end
			else
				i = i + 1
			end
		end
	end
end

function Encounters:UnmarkAll()
	if marks_scanner then
		self:CancelTimer(marks_scanner)
		marks_scanner = nil
	end

	for i, guid in pairs(marks) do
		local unit = self:UnitId(guid)
		if unit then SetRaidTarget(unit, 0) end
	end

	wipe(marks)
	wipe(marks_queue)
	wipe(marked)
	marks_count = 0
end

function Encounters:FS_TRACKER_DIED(_, guid)
	self:Unmark(guid)
end
