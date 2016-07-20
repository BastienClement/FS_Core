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
		130736, -- Soul Reaper
		206930, -- Heart Strike
		195182, -- Marrowrend
		85948, -- Festering Strike
		49020, -- Obliterate
		49143, -- Frost Stike
		55090, -- Scourge Strike

		-- Demon Hunter
		162794, -- Chaos Strike
		162243, -- Demon's Bite
		203782, -- Shear
		209795, -- Fracture

		-- Druid
		33745, -- Lacerate
		5221, -- Shred
		22568, -- Ferocious Bite
		1822, -- Rake
		33917, -- Mangle
		6807, -- Maul
		1079, -- Rip
		22570, -- Maim
		80313, -- Pulverize

		-- Hunter
		186270, -- Raptor Strike
		202800, -- Flanking Strike
		190928, -- Mongoose Bite
		187707, -- Muzzle

		-- Monk
		100780, -- Tiger Palm
		100784, -- Blackout Kick
		205523, -- Blackout Strike
		107428, -- Rising Sun Kick
		115080, -- Touch of Death
		116705, -- Spear Hand Strike

		-- Paladin
		35395, -- Crusader Strike
		85256, -- Templar's Verdict
		53595, -- Hammer of the Righteous
		184575, -- Blade of Justice
		96231, -- Rebuke
		53600, -- Shield of the Righteous
		202270, -- Blade of Wrath
		215661, -- Justicar's Vengeance

		-- Rogue
		209783, -- Goremaw's Bite
		32645, -- Envenom
		2098, -- Run Through
		53, -- Backstab
		196819, -- Evicerate
		193315, -- Saber Slash
		8676, -- Ambush
		16511, -- Hemorrhage
		196937, -- Ghostly Stike
		1766, -- Kick
		200758, -- Gloomblade
		185438, -- Shadowstrike
		1943, -- Rupture
		195452, -- Nightblade
		703, -- Garrote
		200806, -- Exsanguinate
		206237, -- Enveloping Shadows
		5171, -- Slice and Dice

		-- Shaman
		60103, -- Lava Lash
		193786, -- Rockbiter
		201897, -- Boulderfist
		201898, -- Windsong
		196834, -- Frostbrand
		17364, -- Stormstrike
		32175, -- Stormstrike


		-- Warrior
		1464, -- Slam
		12294, -- Mortal Strike
		163201, -- Execute
		5308, -- Execute
		100130, -- Furious Slash
		23922, -- Shield Slam
		34428, -- Victory Rush
		20243, -- Devastate
		23881, -- Bloodthrist
		96103, -- Raging Blow
		85384, -- Raging Blow
		85288, -- Raging Blow
		107570, -- Storm Bolt
		167105, -- Colossus Smash
		6552, -- Pummel
		202168, -- Impending Victory
	}

	local aoe = {
		178740, -- Immolation Aura
		214743, -- Soul Cleave
		106832, -- Trash
		106830, -- Trash
		77758, -- Trash
		213764, -- Swipe
		202028, -- Brutal Slash
		187708, -- Carve
		107270, -- Spinning Crane Kick
		117418, -- Fists of Fury
		121253, -- Keg Smash
		220357, -- Cyclone Stike
		124081, -- Zen Pulse
		115072, -- Expel Harm
		113656, -- Fists of Fury
		101546, -- Spinning Crane Kick
		196743, -- Chi Orbit | TODO: check spell ID
		53595, -- Hammer of the Righteous
		204019, -- Blessed Hammer
		152261, -- Holy Shield | TODO: check reflect ID
		53385, -- Divine Storm
		198034, -- Divine Hammer
		205191, -- Eye for an Eye
		210220, -- Holy Wrath
		13877, -- Blade Flurry
		51723, -- Fan of Knives
		197835, -- Shuriken Storm
		197211, -- Fury of Air
		187874, -- Crash Lightning
		50622, -- Bladestorm
		202161, -- Sweeping Stikes | TODO: check cleave ID
		46968, -- Shockwave
		6343, -- Thunder Clap
		6572, -- Revenge
		1680, -- Whirlwind
		190411, -- Whirlwind
		845, -- Cleave
		227847, -- Bladestorm
		46924, -- Bladestorm
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
		name = "|cff64b4ffHostile tracker",
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

	FS.Config:Register("Hostile tracker", tracker_config)
end

function Tracker:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_TARGET")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
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
		if unit_type ~= "Creature" and unit_type ~= "Vehicule" then return end

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
	if not offset then return guid end
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
		if UnitExists(unit) and UnitGUID(unit) == guid then
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

		if (source_t == "Creature" or source_t == "Vehicule") and dest_t == "Player" then
			local source_m = self:GetMob(source, now)
			if update_near(source_m.near, dest, destName, now) then
				source_m.near_updated = true
			end
		end

		if (dest_t == "Creature" or dest_t == "Vehicule") and source_t == "Player" then
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
			if source_t == "Player" and (dest_t == "Creature" or dest_t == "Vehicule") then
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
		self:SendMessage("FS_TRACKER_DIED", dest)
		self:RemoveMob(dest)
	end
end

Tracker.UNIT_DESTROYED = Tracker.UNIT_DIED
Tracker.UNIT_DISSIPATES = Tracker.UNIT_DIED

function Tracker:UNIT_TARGET(_, unit)
	local target = unit .. "target"
	if not UnitExists(target) then return end

	local target_guid = UnitGUID(target)
	local target_type = self:ParseGUID(target_guid, true)

	if target_type == "Creature" or target_type == "Vehicule" then
		local mob = self:GetMob(target_guid, GetTime())
		mob.unitids[target] = true
	end
end

function Tracker:NAME_PLATE_UNIT_ADDED(_, nameplate)
	local nameplate_guid = UnitGUID(nameplate)
	local nameplate_type = self:ParseGUID(nameplate_guid, true)

	if nameplate_type == "Creature" or nameplate_type == "Vehicule" then
		local mob = self:GetMob(nameplate_guid, GetTime())
		mob.unitids[nameplate] = true
	end
end
