local _, FS = ...
local Encounters = FS:RegisterModule("Encounters", "AceTimer-3.0")

local Roster, Map, Network, BigWigs

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
		{":RegisterEncounter ( name , id ) -> mod", "Registers a new boss module bound to the given encounter id. If a new module is registered with the same name, the previous one is remplaced."},
	}, "FS.Encounters"),
	events = FS.Config:MakeDoc("Mod API", 3000, {
		{":OnEngage ( id , name , difficulty , size )", ""},
		{":OnReset ( kill )", ""},
		{":CombatLog ( event , handler , [ spells ... ] )", ""},
		{":Event ( event , handler , [ firstArgs ... ] )", ""},
		{":Death ( handler , [ mobIds ... ] )", ""},
		{":NetEvent ( event , handler )", ""},
		{":AceEvent ( event , handler )", ""},
		{":Message ( key , msg , color , sound )", ""},
		{":Emphasized ( key , msg , r , g , b , sound )", ""},
		{":Sound ( key , sound )", ""},
		{":Bar ( key , length , text , icon )", ""},
		{":StopBar ( key )", ""},
		{":Say ( key , msg , channel , target )", ""},
		{":Countdown ( key , time )", ""},
		{":Proximity ( key , range , player , isReverse )", ""},
		{":CloseProximity ( key )", ""},
		{":Flash ( key )", ""},
		{":Pusle ( key , icon )", ""},
		{":ScheduleAction ( key , delay , fn , ... )", ""},
		{":CancelAction ( key )", ""},
		{":CancelAllActions ( )", ""},
		{":Send ( event , data , target )", ""},
		{":Emit ( msg , ... )", ""},
		{":Difficulty ( ) -> number", ""},
		{":LFR ( ) -> boolean", ""},
		{":Easy ( ) -> boolean", ""},
		{":Normal ( ) -> boolean", ""},
		{":Heroic ( ) -> boolean", ""},
		{":Mythic ( ) -> boolean", ""},
		{":RaidSize ( ) -> number", ""},
		{":MobId ( mobGUID ) -> number", ""},
		{":Me ( unitGUID ) -> boolean", ""},
		{":Range ( playerA [, playerB ] ) -> number", ""},
		{":Role ( [ player ] ) -> tank | healer | melee | ranged", ""},
		{":Melee ( [ player ] ) -> boolean", ""},
		{":Ranged ( [ player ] ) -> boolean", ""},
		{":Tank ( [ player ] ) -> boolean", ""},
		{":Healer ( [ player ] ) -> boolean", ""},
		{":Damager ( [ player ] ) -> boolean", ""},
		{":IterateGroup ( [ limit [, sorted ]] ) -> [ units ]", ""},
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

-------------------------------------------------------------------------------
-- Life-cycle events
-------------------------------------------------------------------------------

function Encounters:OnInitialize()
	Roster = FS.Roster
	Map = FS.Map
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

function Encounters:ENCOUNTER_START(_, id, name, diff_id, size)
	if encounterInProgress then
		-- Fake an ENCOUNTER_END event if a new _START is detected
		self:ENCOUNTER_END(_, encounter, encounterName, difficulty, raidSize, 0)
	end

	self:Printf("Pulling |cff64b4ff%s |cff999999(%i, %i, %i)", name, id, diff_id, size)
	encounterInProgress = true

	if self.settings.transcriptor and Transcriptor then

		if self.settings.last_encounter ~= id and self.settings.auto_remove then
			self.settings.last_encounter = id
			Transcriptor:ClearAll()
		end
		Transcriptor:StartLog()
	end

	local mods = encounters[id]
	if not mods then return end

	encounter = id
	encounterName = name
	difficulty = diff_id
	raidSize = size

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
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		cleuBound = false
	end

	if msgBound then
		self:UnregisterMessage("FS_MSG_ENCOUNTERS")
		msgBound = false
	end

	for event in pairs(registered) do
		self:UnregisterEvent(event)
	end

	for event in pairs(aceRegistered) do
		self:UnregisterMessage(event)
	end

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
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		cleuBound = true
	end
end

local args = {}
function Encounters:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, _, extraSpellId, amount)
	if allowedCleu[event] then
		if event == "UNIT_DIED" then
			local _, _, _, _, _, id = strsplit("-", destGUID)
			local mobId = tonumber(id)
			args.mobId, args.destGUID, args.destName, args.destFlags, args.destRaidFlags = mobId, destGUID, destName, destFlags, destRaidFlags
			if mobId then
				args.mobId, args.destGUID, args.destName, args.destFlags, args.destRaidFlags = mobId, destGUID, destName, destFlags, destRaidFlags
				self:Dispatch(event, mobId, args)
			else
				self:Dispatch(event, -1, args)
			end
		else
			args.sourceGUID, args.sourceName, args.sourceFlags, args.sourceRaidFlags = sourceGUID, sourceName, sourceFlags, sourceRaidFlags
			args.destGUID, args.destName, args.destFlags, args.destRaidFlags = destGUID, destName, destFlags, destRaidFlags
			args.spellId, args.spellName, args.extraSpellId, args.extraSpellName, args.amount = spellId, spellName, extraSpellId, amount, amount
			self:Dispatch(event, spellId, args)
		end
	end
end

function Encounters:RegisterGenericEvent(module, event, unit, handler)
	events[event][unit][module] = handler
	if not registered[event] then
		self:RegisterEvent(event, "GENERIC_EVENT")
		registered[event] = true
	end
end

function Encounters:GENERIC_EVENT(event, unit, ...)
	self:Dispatch(event, unit, ...)
end

function Encounters:RegisterNetMessage(module, event, handler)
	events[event]["*"][module] = handler
	allowedMsg[event] = true
	if not msgBound then
		self:RegisterMessage("FS_MSG_ENCOUNTERS")
		msgBound = true
	end
end

function Encounters:FS_MSG_ENCOUNTERS(_, msg, channel, source)
	local event = msg.event
	if allowedMsg[event] then
		self:Dispatch(event, "*", msg.data, channel, source)
	end
end

function Encounters:RegisterAceEvent(module, event, handler)
	events[event]["*"][module] = handler
	if not aceRegistered[event] then
		self:RegisterMessage(event, "ACE_EVENT")
		aceRegistered[event] = true
	end
end

function Encounters:ACE_EVENT(event, ...)
	self:Dispatch(event, "*", ...)
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
		icons = BigWigs.spells
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

function Module:NetEvent(event, handler)
	if not handler then handler = event end
	Encounters:RegisterNetMessage(self, event, handler)
end

function Module:AceEvent(event, handler)
	if not handler then handler = event end
	Encounters:RegisterAceEvent(self, event, handler)
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

function Module:ScheduleAction(...)
	BigWigs:ScheduleAction(...)
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

function Module:MobId(guid)
	if not guid then return 1 end
	local _, _, _, _, _, id = strsplit("-", guid)
	return tonumber(id) or 1
end

function Module:Me(guid)
	return guid == playerGUID
end

function Module:Range(player, other)
	if not other then other = "player" end
	local tx, ty = UnitPosition(player)
	local ux, uy = UnitPosition(other)
	if not tx or not ux then
		return 200
	else
		return Map:GetDistance(tx, ty, ux, uy)
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
	return self:Role(player) == "tank"
end

function Module:Damager(player)
	return self:Role(player) == "tank"
end

function Module:IterateGroup(...)
	return Roster:Iterate(...)
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
