local _, Core = ...
FS = LibStub("AceAddon-3.0"):NewAddon(Core, "FS")

LibStub("AceEvent-3.0"):Embed(FS)
LibStub("AceConsole-3.0"):Embed(FS)

FS:SetDefaultModuleLibraries("AceEvent-3.0", "AceConsole-3.0")

FS.version = "@project-version@"

function Core:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("FSDB", nil, true)
end

function Core:OnEnable()
	self:RegisterEvent("ENCOUNTER_START")
	self:RegisterEvent("ENCOUNTER_END")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:Print("Core Loaded")
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

	function Core:IterateGroup()
		return function(_, last)
			if not IsInRaid() and not IsInGroup() then
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

-- Debug helper
function Core:Dump(t)
	local dump_cache = {}
	local function sub_dump(t,indent)
		if (dump_cache[tostring(t)]) then
			print(indent.."*"..tostring(t))
		else
			dump_cache[tostring(t)]=true
			if (type(t)=="table") then
				for pos,val in pairs(t) do
					if (type(val)=="table") then
						print(indent.."["..pos.."] => "..tostring(t).." {")
						sub_dump(val,indent..string.rep(" ",string.len(pos)+8))
						print(indent..string.rep(" ",string.len(pos)+6).."}")
					elseif (type(pos)=="table") then
						print(indent.."["..tostring(pos).."] => "..tostring(t).." {")
						sub_dump(pos,indent..string.rep(" ",string.len(tostring(pos))+8))
						print(indent..string.rep(" ",string.len(tostring(pos))+6).."}")
					else
						print(indent.."["..tostring(pos).."] => "..tostring(val))
					end
				end
			else
				print(indent..tostring(t))
			end
		end
	end
	sub_dump(t," ")
end
