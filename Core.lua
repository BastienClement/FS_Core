local _, Core = ...
FS = LibStub("AceAddon-3.0"):NewAddon(Core, "FS")

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

	-- DEPREACTED
	function Core:IterateGroup()
		return function(_, last)
			if not IsInGroup() then
				if not last then return 1, "player" end
			end
			local num = (last or 0) + 1
			if num <= GetNumGroupMembers() then
				local unit = IsInRaid() and ("raid" .. num) or ("party" .. num)
				if not UnitExists(unit) then unit = "player" end
				return num, unit
			end
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

-- Debug helper
function Core:Dump(t)
	local dump_cache = {}
	local function to_string(v)
		local prefix = "|cff00ff96"
		local suffix = "|r"
		local tpe = type(v)

		if tpe == "string" then
			prefix = "|cfffff569\""
			suffix = "\"|r"
		elseif tpe == "number" then
			prefix = "|cffff7d0a"
		elseif tpe == "table" then
			prefix = "|cffabd473"
		elseif tpe == "function" then
			prefix = "|cff69ccf0"
		end

		return prefix .. tostring(v) .. suffix
	end
	local function sub_dump(t, indent)
		local t_str = to_string(t)
		if dump_cache[t_str] then
			print(indent .. "*" .. t_str)
		else
			dump_cache[t_str] = true
			if type(t) == "table" then
				for pos, val in pairs(t) do
					if type(val) == "table" then
						print(indent .. to_string(pos) .. " => " .. to_string(val) .." {")
						sub_dump(val, indent .. (" "):rep(4))
						print(indent .. "}")
					else
						print(indent .. to_string(pos) .. " => " .. to_string(val))
					end
				end
			else
				print(indent .. t_str)
			end
		end
	end
	sub_dump(t, " ")
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

