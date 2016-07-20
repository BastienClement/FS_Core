local _, Core = ...

FS = LibStub("AceAddon-3.0"):NewAddon(Core, "FS")
FS.Util = {}

LibStub("AceEvent-3.0"):Embed(FS)
LibStub("AceConsole-3.0"):Embed(FS)

FS:SetDefaultModuleLibraries("AceEvent-3.0", "AceConsole-3.0")

-- Version
do
	local version_str = "@project-version@"
	local dev_version = "@project" .. "-version@"
	FS.version = version_str == dev_version and "dev" or version_str
end

function Core:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("FSDB", nil, true)
	if not self.db.global.PLAYER_KEY then
		self.db.global.PLAYER_KEY = "PK:" .. FS:UUID() .. ":" .. time()
	end
end

function Core:OnEnable()
	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("ENCOUNTER_END")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:Printf("Core Loaded [%s]", FS.version)
end

function Core:RegisterModule(name, ...)
	local mod = self:NewModule(name, ...)
	self[name] = mod
	return mod
end

-- Encounter tracking
do
	function Core:ENCOUNTER_START(id, name, difficulty, size)
		self.encounter = { id = id, name = name, difficulty = difficulty, size = size }
	end

	function Core:ENCOUNTER_END()
		self.encounter = nil
	end

	function Core:EncounterInProgress()
		return self.encounter
	end
end

-- Players tracking
do
	function Core:NormalizeName(name)
		if not name then return name end
		return name:match("([^\\-]+)") or name
	end

	local guild_members = {}
	function Core:GUILD_ROSTER_UPDATE()
		if self:EncounterInProgress() then return end
		wipe(guild_members)
		for i = 1, GetNumGuildMembers() do
			local name = self:NormalizeName(GetGuildRosterInfo(i))
			if name then guild_members[name] = true end
		end
	end

	function Core:UnitIsInGuild(unit)
		return guild_members[UnitName(unit) or unit] or false
	end

	function Core:UnitIsTrusted(unit)
		return UnitIsUnit("player", unit)
			or UnitIsGroupLeader(unit)
			or UnitIsGroupAssistant(unit)
	end
end

-- UUID
do
	local chars = {}
	for i = 48, 57 do chars[#chars + 1] = string.char(i) end
	for i = 65, 90 do chars[#chars + 1] = string.char(i) end
	for i = 97, 122 do chars[#chars + 1] = string.char(i) end

	local floor, random = math.floor, math.random

	function Core:UUID(length)
		if not length then length = 64 end
		local uuid = ""
		for i = 1, length do
			uuid = uuid .. chars[floor(random() * #chars + 1)]
		end
		return uuid
	end
end

-- PlayerKey
function Core:PlayerKey()
	if not self.db then return end
	return self.db.global.PLAYER_KEY
end

-- Deep cloning helper
function Core:Clone(source)
	local clone = {}
	for k, v in pairs(source) do
		if type(v) == "table" then
			clone[k] = Core:Clone(v)
		else
			clone[k] = v
		end
	end
	return clone
end

