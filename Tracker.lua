local _, FS = ...
local Tracker = FS:RegisterModule("Tracker")

local MELEE_SPELLS = {}
local SMALL_AOES = {}
do
	local melee = {
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
		22570, -- Maim
		1822, -- Rake
		
		-- Monk
		100780, -- Jab
		115693, -- Jab
		115695, -- Jab
		115687, -- Jab
		115698, -- Jab
		108557, -- Jab
		100787, -- Tiger Palm
		100784, -- Blackout Kick
		115080, -- Touch of Death
		116705, -- Spear Hand Strike
		107428, -- Rising Sun Kick
		116095, -- Disable
		122470, -- Touch of Karma
		
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
		1776, -- Gouge
		1833, -- Cheap Shot
		408, -- Kidney Shot
		703, -- Garrote
		5938, -- Shiv
		53, -- Backstab
		111240, -- Dispatch
		32645, -- Envenom
		16511, -- Hemorrhage
		1329, -- Mutilate
		84617, -- Revealing Strike
		1943, -- Rupture
		
		-- Shaman
		73899, -- Primal Strike
		60103, -- Lava Lash
		17364, -- Stormstrike
		
		-- Warrior
		78, -- Heroic Strike
		34428, -- Victory Rush
		6552, -- Pummel
		1715, -- Hamstring
		167105, -- Colossus Smash
		12294, -- Mortal Strike
		85288, -- Raging Blow
		772, -- Rend
		23922, -- Shield Slam
		20243, -- Devastate
		163201, -- Execute
		5308, -- Execute
		6572, -- Revenge
		100130, -- Wild Strike
	}
	
	local aoe = {
		53595,  -- Hammer of the Righteous
		106785, -- Swipe
		101546, -- Spinning Crane Kick
		51723, -- Fan of Knives
		113656, -- Fists of Fury
		101423, -- Seal of Righteousness
		1680, -- Whirlwind
		53385, -- Divine Storm
		--50842, -- Blood Boil
		121411, -- Crimsom Tempest
		6544, -- Heroic Leap
		46924, -- Blade Storm
	}
	
	for i = 1, #melee do
		MELEE_SPELLS[melee[i]] = true
	end
	
	for i = 1, #aoe do
		SMALL_AOES[aoe[i]] = true
	end
end

local Distance, SmallestEnclosingCircle
local max = math.max

-------------------------------------------------------------------------------
-- Tracker config
--------------------------------------------------------------------------------

local tracker_default = {
	profile = {
		enable = true,
		use_aoe = true,
		use_single = true
	}
}

local tracker_config = {
	title = {
		type = "description",
		name = "|cff64b4ffHostile Tracker",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Track nearby hostile units and estimate their position.\n",
		fontSize = "medium",
		order = 1
	},
	enable = {
		type = "toggle",
		name = "Enable",
		width = "full",
		get = function()
			return Tracker.settings.enable
		end,
		set = function(_, value)
			Tracker.settings.enable = value
			if value then
				Tracker:Enable()
			else
				Tracker:Disable()
			end
		end,
		order = 5
	},
	enable_warn = {
		type = "description",
		name = "|cff999999This module gather many useful informations about hostile units.\nDisabling it can prevent other modules from working effectively.",
		order = 6
	},
	spacing_9 = {
		type = "description",
		name = "\n",
		order = 9
	},
	use_single = {
		type = "toggle",
		name = "Track single-target spells",
		desc = "Track single-target melee casts (in addition to melee swings) for hostile units position estimation.",
		width = "full",
		get = function()
			return Tracker.settings.use_single
		end,
		set = function(_, value)
			Tracker.settings.use_single = value
		end,
		order = 20
	},
	use_aoe = {
		type = "toggle",
		name = "Track AoE spells",
		desc = "Track AoE abilities for hostile units position estimation.",
		width = "full",
		get = function()
			return Tracker.settings.use_aoe
		end,
		set = function(_, value)
			Tracker.settings.use_aoe = value
		end,
		order = 21
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":GetUnit ( guid ) -> unitid", "Return a unitid for the given mob, if known."},
		{":GetPosition ( guid ) -> x , y , good", "Return an estimated position for the given mob, if known.\n" ..
			"Also return a flag indicating if this estimation is accurate."},
			
		{":ParseGUID ( guid ) -> ...", "Parse a GUID string and return components."},
	}, "FS.Tracker"),
	events = FS.Config:MakeDoc("Emitted events", 3000, {
		{"_FOUND ( guid , npcid )", "Emitted when a new unit is discovered."},
		{"_DIED ( guid )", "Emitted when a tracked unit has died."},
		{"_LOST ( guid )", "Emitted when a tracked unit was lost." ..
			"A unit is considered lost if no events involving this unit was received in the last 5 sec and no one is targetting it."},
		{"_REMOVE ( guid , npcid )", "Emitted when a tracked unit has died or was lost."},
	}, "FS_TRACKER")
}

--------------------------------------------------------------------------------

function Tracker:OnInitialize()
	Distance = FS.Geometry.Distance
	SmallestEnclosingCircle = FS.Geometry.SmallestEnclosingCircle
	
	self.db = FS.db:RegisterNamespace("Tracker", tracker_default)
	self.settings = self.db.profile
	
	self:SetEnabledState(self.settings.enable)
	
	self.mobs = {}
	self.mobs_id = {}
	
	FS.Config:Register("Hostile Tracker", tracker_config)
end

function Tracker:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_TARGET")
	self.gc = C_Timer.NewTicker(5, function() self:GC() end)
end

function Tracker:OnDisable()
	self.gc:Cancel()
end

--------------------------------------------------------------------------------
-- Private
--------------------------------------------------------------------------------

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
			near_good = false,
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
		local unit = self:GetUnit(guid, data)
		if not unit and now - data.ping > 5 then
			self:SendMessage("FS_TRACKER_LOST", guid, data.id)
			self:RemoveMob(guid)
		end
	end
end

--------------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------------

function Tracker:ParseGUID(guid, only_type)
	local offset = guid:find("-")
	local unit_type = guid:sub(1, offset - 1)
	if only_type then return unit_type end
	if unit_type == "Player" then
		local s, u = guid:match("(.-)-(.+)", offset + 1)
		return unit_type, tonumber(s), u
	else
		local x, s, i, z, m, u = guid:match("(.-)-(.-)-(.-)-(.-)-(.-)-(.+)", offset + 1)
		return unit_type, tonumber(x), tonumber(s), tonumber(i), tonumber(z), tonumber(m), u
	end
end

function Tracker:GetUnit(guid, mob)
	if not mob then mob = self:GetMob(guid) end
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
	
	local function purge(max_dist, x, y)
		-- Check points too far away
		local updated = false
		for i = #S, 1, -1 do
			if Distance(S[i].x, S[i].y, x, y) > max_dist then
				table.remove(S, i)
				updated = true
			end
		end
		
		return updated
	end
	
	local function ComputePosition(guid, mob, final)
		local x, y = SmallestEnclosingCircle(S_Accessor, #S)
		
		-- If this is the last iteration, do not try to enhance the result
		if final then return x, y end
		
		-- Attempt to be smart by finding the tank
		-- We also check that this tank is *near* the target
		local unitid = Tracker:GetUnit(guid)
		if unitid then
			local target_guid = UnitGUID(unitid .. "target")
			local target_data = target_guid and mob.near[target_guid]
			if target_data then
				-- Drop unit more than 50% away than the tank
				local max_dist = max(Distance(target_data.x, target_data.y, x, y), 5) * 1.5
				
				if purge(max_dist, x, y) then
					-- At least one unit was removed, recompute
					return ComputePosition(guid, mob, true)
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
		
		local max_dist = max((sum / count), 5) * 1.5
		
		if purge(max_dist, x, y) then
			-- At least one unit was removed, recompute
			return ComputePosition(guid, mob, true)
		else
			return x, y
		end
	end
	
	function Tracker:GetPosition(guid, mob)
		if not mob then mob = self:GetMob(guid) end
		if not mob then return end
		
		if mob.near_updated then
			local now = GetTime()
			if now - mob.near_last > 0.1 then
				-- Register now as last refresh of mob position
				mob.near_last = now
				mob.near_updated = false
				
				-- Wipe the near units set
				wipe(S)
				
				for guid, data in pairs(mob.near) do
					if now - data.t < 3 then
						S[#S + 1] = data
					else
						mob.near[guid] = nil
					end
				end
				
				if #S > 0 then
					mob.near_good = true
					mob.x, mob.y = ComputePosition(guid, mob)
				else
					mob.near_good = false
				end
			end
		end
			
		return mob.x, mob.y, mob.near_good
	end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Tracker:COMBAT_LOG_EVENT_UNFILTERED(_, timestamp, event, _, ...)
	if self[event] then
		self[event](self, ...)
	end
end

do
	local function update_near(near, guid, name, ts)
		local near_data = near[guid]
		if near_data and (ts - near_data.t) < 0.5 then return false end
		
		name = Ambiguate(name, "short")
		
		if UnitExists(name) then
			local x, y = UnitPosition(name)
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
		
		return true
	end
	
	function Tracker:SWING_DAMAGE(source, sourceName, _, _, dest, destName)
		local source_t = self:ParseGUID(source, true)
		local dest_t = self:ParseGUID(dest, true)
		local now = GetTime()

		if source_t == "Creature" and dest_t == "Player" then
			local source_m = self:GetMob(source, now)
			if update_near(source_m.near, dest, destName, now) then
				source_m.near_updated = true
			end
		end

		if dest_t == "Creature" and source_t == "Player" then
			local dest_m = self:GetMob(dest, now)
			if update_near(dest_m.near, source, sourceName, now) then
				dest_m.near_updated = true
			end
		end
	end
	
	function Tracker:SPELL_DAMAGE(source, sourceName, _, _, dest, destName, _, _, spell)
		if not Tracker.settings.use_aoe then return end
		if SMALL_AOES[spell] then
			local source_t = self:ParseGUID(source, true)
			local dest_t = self:ParseGUID(dest, true)
			if source_t == "Player" and dest_t == "Creature" then
				local now = GetTime()
				local dest_m = self:GetMob(dest, now)
				update_near(dest_m.near, source, sourceName, now)
				dest_m.near_updated = true
			end
		end
	end
end

function Tracker:SPELL_CAST_SUCCESS(source, sourceName, _, _, dest, destName, _, _, spell)
	if not Tracker.settings.use_single then return end
	if MELEE_SPELLS[spell] then
		self:SWING_DAMAGE(source, sourceName, nil, nil, dest, destName)
	end
end

function Tracker:UNIT_DIED(source, _, _, _, dest)
	if self.mobs[dest] then
		self:SendMessage("FS_TRACKER_DIED", guid)
		self:RemoveMob(dest)
	end
end

Tracker.UNIT_DESTROYED = Tracker.UNIT_DIED

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
