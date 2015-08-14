local _, FS = ...
local Tracker = FS:RegisterModule("Tracker")

local MELEE_SPELLS = {}
do
	local spells = {
		-- Death Knight
		45462, -- Plague Strike
		49998, -- Death Strike
		47528, -- Mind Freeze
		49143, -- Frost Stike
		49020, -- Obliterate
		55090, -- Scourge Strike
		
		-- Druid
		22568, -- Ferocious Bite
		5221, -- Shred
		33917, -- Mangle
		1079, -- Rip
		33745, -- Lacerate
		6807, -- Maul
		80313, -- Pulverize
		
		-- Monk
		100780, -- Jab
		115693, -- Jab
		115695, -- Jab
		115687, -- Jab
		115698, -- Jab
		108557, -- Jab
		100787, -- Tiger Palm
		100784, -- Blackout Kick
		116705, -- Spear Hand Strike
		107428, -- Rising Sun Kick
		
		-- Paladin
		35395, -- Crusader Strike
		96231, -- Rebuke
		53595, -- Hammer of the Righteous
		85256, -- Templar's Verdict
		53600, -- Shield of the Righteousw
		
		-- Rogue
		1752, -- Sinister Strike
		2098, -- Eviscerate
		8676, -- Ambush
		1766, -- Kick
		703, -- Garrote
		53, -- Backstab
		
		-- Shaman
		73899, -- Primal Strike
		60103, -- Lava Lash
		17364, -- Stormstrike
		
		-- Warrior
		78, -- Heroic Strike
		167105, -- Colossus Smash
		12294, -- Mortal Strike
		85288, -- Raging Blow
		772, -- Rend
		23922, -- Shield Slam
	}
	
	for i = 1, #spells do
		local spell = spells[i]
		local name, _, _, _, _, maxRange = GetSpellInfo(spell)
		if not name then
			Tracker:Printf("|cffff9f00Failed to get spell infos for spell #%d.", spell)
		elseif maxRange ~= 0 then
			Tracker:Printf("|cffff9f00Spell #%d [%s] is listed as a melee-range spell but its max range is %dyd. Please report.", spell, name, maxRange)
		else
			MELEE_SPELLS[spells[i]] = true
		end
	end
	
	--[[
	local good = {}
	local bad = {}
	for t = 2, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(t)
		for i = offset + 1, offset + numSpells do
			if not IsPassiveSpell(i, "spell") and IsHarmfulSpell(i, "spell") then
				local name, _, _, _, _, maxRange, spellID = GetSpellInfo(i, "spell")
				local desc = GetSpellDescription(i, "spell")
				local suspicious = desc:match("yards") or desc:match("area") or desc:match("yd")
				if not suspicious and maxRange == 0 then
					good[spellID] = name
				else
					bad[spellID] = name
				end
			end
		end
	end
	
	for id, name in pairs(good) do
		Tracker:Printf("GOOD %d - %s", id, name)
	end
	
	for id, name in pairs(bad) do
		Tracker:Printf("BAD %d - %s", id, name)
	end
	]]
end

local Distance, SmallestEnclosingCircle

function Tracker:OnInitialize()
	self.mobs = {}
	self.mobs_id = {}
	Distance = FS.Geometry.Distance
	SmallestEnclosingCircle = FS.Geometry.SmallestEnclosingCircle
end

function Tracker:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_TARGET")
	self.gc = C_Timer.NewTicker(5, function() self:GC() end)
end

function Tracker:OnDisable()
	self.gc:Cancel()
end

function Tracker:GetMob(guid, timestamp)
	local mob = self.mobs[guid]
	if not mob and timestamp then
		local unit_type, zero, s, i, z, m, w = self:ParseGUID(guid)
		if unit_type ~= "Creature" then return end
		
		mob = {
			guid = guid,
			server = s,
			instance = i,
			zone = z,
			id = m,
			spawn = w,
			ping = timestamp,
			unitids = {},
			x = -1,
			y = -1,
			near = {},
			near_bad = true,
			near_updated = false,
			near_last = 0
		}
		
		if not self.mobs_id[m] then
			self.mobs_id[m] = { guid }
		else
			table.insert(self.mobs_id[m], guid)
		end
		
		self.mobs[guid] = mob
		self:SendMessage("FS_TRACKER_FOUND", guid, m)
	elseif timestamp and timestamp > mob.ping then
		mob.ping = timestamp
	end
	return mob
end

do
	local function ret_helper(...) return ... end
	
	function Tracker:ParseGUID(guid, only_type)
		local _, offset, unit_type = guid:find("^([^-]+)")
		if only_type then return unit_type end
		if unit_type == "Player" then
			local s, u = guid:match("(.-)-(.+)", offset + 2)
			return ret_helper(unit_type, tonumber(s), u)
		else
			local x, s, i, z, m, u = guid:match("(.-)-(.-)-(.-)-(.-)-(.-)-(.+)", offset + 2)
			return ret_helper(unit_type, tonumber(x), tonumber(s), tonumber(i), tonumber(z), tonumber(m), u)
		end
	end
end

function Tracker:RemoveMob(guid)
	local data = self.mobs[guid]
	if not data then return end
	
	local id = data.id
	self.mobs[guid] = nil
	
	local list = self.mobs_id[id]
	for i, g in ipairs(list) do
		if g == guid then
			table.remove(list, i)
			break
		end
	end
	
	if #list == 0 then
		self.mobs_id[id] = nil
	end
	
	self:SendMessage("FS_TRACKER_REMOVE", guid, data.id)
end

function Tracker:GC()
	local now = GetTime()
	for guid, data in pairs(self.mobs) do
		if now - data.ping > 5 then
			self:SendMessage("FS_TRACKER_LOST", guid, data.id)
			self:RemoveMob(guid)
		end
	end
end

--------------------------------------------------------------------------------

function Tracker:GetMobUnit(guid)
	local mob = self:GetMob(guid)
	if not mob then return end
	
	for unit in pairs(mob.unitids) do
		if UnitGUID(unit) == guid then
			return unit
		else
			mob.unitids[unit] = nil
		end
	end
end

do
	local S = {}
	
	local function S_Accessor(i)
		return S[i].x, S[i].y
	end
	
	local function ComputePosition(guid, mob)
		local x, y = SmallestEnclosingCircle(S_Accessor, #S)
		
		-- Attempt to be smart by finding the tank
		-- We also check that this tank is *near* the target
		local unitid = Tracker:GetMobUnit(guid)
		if unitid then
			local target_guid = UnitGUID(unitid .. "target")
			local target_data = target_guid and mob.near[target_guid]
			if target_data then
				-- Drop unit more than 50% away than the tank
				local max_dist = Distance(target_data.x, target_data.y, x, y) * 1.5
				
				local updated = false
				for i = #S, 1, -1 do
					if Distance(S[i].x, S[i].y, x, y) > max_dist then
						table.remove(S, i)
						updated = true
					end
				end
				
				-- At least one unit was removed, recompute
				if updated then
					return ComputePosition()
				else
					return x, y
				end
			end
		end
		
		-- Be a bit less smart and check based on average distance
		local sum = 0
		local count = 0
		
		for _, data in ipairs(S) do
			sum = sum + Distance(data.x, data.y, x, y)
			count = count + 1
		end
		
		local max_dist = (sum / count) * 1.5
		
		local updated = false
		for i = #S, 1, -1 do
			if Distance(S[i].x, S[i].y, x, y) > max_dist then
				table.remove(S, i)
				updated = true
			end
		end
		
		-- At least one unit was removed, recompute
		if updated then
			return ComputePosition()
		else
			return x, y
		end
	end
	
	function Tracker:GetMobPosition(guid)
		local mob = self:GetMob(guid)
		if not mob then return end
		
		if mob.near_updated then
			local now = GetTime()
			if now - mob.near_last > 0.033 then
				-- Register now as last refresh of mob position
				mob.near_last = now
				mob.near_updated = false
				
				-- Wipe the near units set
				wipe(S)
				
				for guid, data in pairs(mob.near) do
					if now - data.t < 3.5 then
						S[#S + 1] = data
					else
						mob.near[guid] = nil
					end
				end
				
				if #S > 0 then
					mob.near_bad = false
					mob.x, mob.y = ComputePosition(guid, mob)
				else
					mob.near_bad = true
				end
			end
		end
			
		return mob.x, mob.y, mob.near_bad
	end
end

function Tracker:PingMob(guid, ts)
	if self:ParseGUID(guid, true) == "Creature" then
		return self:GetMob(guid, ts or GetTime())
	end
end

--------------------------------------------------------------------------------

function Tracker:COMBAT_LOG_EVENT_UNFILTERED(_, timestamp, event, _, ...)
	if self[event] then
		self[event](self, GetTime(), ...)
	end
end

do
	local function update_near(near, guid, name, ts)
		name = Ambiguate(name, "short")
		if UnitExists(name) then
			local x, y = UnitPosition(name)
			local near_data = near[guid]
			if near_data then
				near_data.x = x
				near_data.y = y
				near_data.t = ts
			else
				near[guid] = {
					x = x,
					y = y,
					t = ts,
					n = name
				}
			end
		end
	end
	
	function Tracker:SWING_DAMAGE(ts, source, sourceName, _, _, dest, destName)
		local source_t = self:ParseGUID(source, true)
		local dest_t = self:ParseGUID(dest, true)

		if source_t == "Creature" then
			local source_m = self:GetMob(source, ts)
			if dest_t == "Player" then
				update_near(source_m.near, dest, destName, ts)
				source_m.near_updated = true
			end
		end

		if dest_t == "Creature" then
			local dest_m = self:GetMob(dest, ts)
			if source_t == "Player" then
				update_near(dest_m.near, source, sourceName, ts)
				dest_m.near_updated = true
			end
		end
	end
end

function Tracker:SPELL_CAST_SUCCESS(ts, source, sourceName, _, _, dest, destName, _, _, spell)
	if MELEE_SPELLS[spell] then
		self:SWING_DAMAGE(ts, source, sourceName, nil, nil, dest, destName)
	end
end

function Tracker:SPELL_DAMAGE(ts, source, sourceName, _, _, dest, destName, _, _, spell)
	self:PingMob(source, ts)
	self:PingMob(dest, ts)
end

function Tracker:UNIT_DIED(ts, source, _, _, _, dest)
	if self.mobs[dest] then
		self:SendMessage("FS_TRACKER_DIED", guid)
		self:RemoveMob(dest)
	end
end

function Tracker:UNIT_TARGET(_, unit)
	local target = unit .. "target"
	if not UnitExists(target) then return end
	
	local target_guid = UnitGUID(target)
	local target_type = self:ParseGUID(target_guid, true)
	
	if target_type == "Creature" then
		local mob = self:GetMob(target_guid, GetTime())
		mob.unitids[target] = true
	end
end
