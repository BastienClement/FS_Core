local _, FS = ...
local Tracker = FS:RegisterModule("Tracker")
local max = math.max

-------------------------------------------------------------------------------
-- Tracker config
--------------------------------------------------------------------------------

local tracker_config = {
	title = {
		type = "description",
		name = "|cff64b4ffHostile tracker",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Track nearby hostile units and provides GUID to UnitID service.\n",
		fontSize = "medium",
		order = 1
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":GetUnit ( guid ) -> unitid", "Return a unitid for the given mob, if known."},
		{":ParseGUID ( guid ) -> ...", "Parse a GUID string and return components."},
	}, "FS.Tracker"),
	events = FS.Config:MakeDoc("Emitted events", 3000, {
		{"_FOUND ( guid , npcid )", "Emitted when a new unit is discovered."},
		{"_DIED ( guid )", "Emitted when a tracked unit has died."},
		{"_LOST ( guid )", "Emitted when a tracked unit was lost. " ..
			"A unit is considered lost if no events involving this unit was received in the last 5 sec and no one is targetting it."},
		{"_REMOVE ( guid , npcid )", "Emitted when a tracked unit has died or was lost."},
	}, "FS_TRACKER")
}

--------------------------------------------------------------------------------

function Tracker:OnInitialize()
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
			unitids = {}
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

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function Tracker:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, _, ...)
	if self[event] then
		self[event](self, ...)
	end
end

function Tracker:SWING_DAMAGE(source, _, _, _, dest, _)
	local source_t = self:ParseGUID(source, true)
	local dest_t = self:ParseGUID(dest, true)
	local now = GetTime()

	if source_t == "Creature" or source_t == "Vehicule" then self:GetMob(source, now) end
	if dest_t == "Creature" or dest_t == "Vehicule" then self:GetMob(dest, now) end
end

Tracker.SPELL_DAMAGE = Tracker.SWING_DAMAGE
Tracker.SPELL_CAST_SUCCESS = Tracker.SWING_DAMAGE

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
