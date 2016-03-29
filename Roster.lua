local _, FS = ...
local Roster = FS:RegisterModule("Roster", "AceTimer-3.0")
local LGIST = LibStub:GetLibrary("LibGroupInSpecT-1.1")

-------------------------------------------------------------------------------
-- Roster config
--------------------------------------------------------------------------------

local roster_config = {
	title = {
		type = "description",
		name = "|cff64b4ffRoster Tracker",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Tracks spec and talents from allied units.\n",
		fontSize = "medium",
		order = 1
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
		{":Iterate ( sorted ) -> [ unit ]", "Returns an iterator over the group members.\nIf sorted is given and you are in a raid group, units are sorted by role."},
		{":GetUnit ( guid ) -> unit", "Returns the unitid for a given GUID, if known."},
		{":GetInfo ( guid ) -> InfoTable", "Returns talents and glyphs information for a player. See LibGroupInSpec_T for more information."}
	}, "FS.Roster"),
	events = FS.Config:MakeDoc("Emitted events", 3000, {
		{"_JOINED ( guid , unit )", "Emitted when a new unit has joined the group."},
		{"_UPDATE ( guid , info , info )", "Emitted when talents info are updated for a unit."},
		{"_LEFT ( guid )", "Emitted when a unit has left the group."},
	}, "FS_ROSTER")
}

--------------------------------------------------------------------------------

function Roster:OnInitialize()
	FS.Config:Register("Roster Tracker", roster_config)
	self.group = {}
	LGIST.RegisterCallback(self, "GroupInSpecT_Update", "RosterUpdate")
	LGIST.RegisterCallback(self, "GroupInSpecT_Remove", "RosterRemove")
end

function Roster:OnEnable()
end

function Roster:OnDisable()
end

--------------------------------------------------------------------------------

do
	local role_order = {
		["tank"] = 1,
		["melee"] = 2,
		["ranged"] = 3,
		["healer"] = 4,
		["unknown"] = 5
	}

	local function solo_iterator()
		local done = false
		return function()
			if not done then
				done = true
				return "player", 1
			end
		end
	end

	local function party_iterator()
		local i = -1
		return function()
			i = i + 1
			if i < GetNumGroupMembers() then
				return i == 0 and "player" or ("party" .. i), i + 1
			end
		end
	end

	local function raid_iterator(sorted)
		local i = 0
		local limit = 40
		local order

		if sorted then
			order = {}
			local role = {}
			local idx = {}

			for unit, idx in Roster:IterateRoster() do
				table.insert(order, unit)
				local info = Roster:GetInfo(UnitGUID(unit))
				role[unit] = info and info.spec_role_detailed or "unknown"
				idx[unit] = idx
			end

			table.sort(order, function(a, b)
				if role[a] ~= role[b] then
					return role_order[role[a]] < role_order[role[b]]
				else
					return idx[a] < idx[b]
				end
			end)
		end

		local function it()
			i = i + 1
			local unit

			if i > limit or i > GetNumGroupMembers() then
				return
			elseif order then
				unit = order[i]
			else
				unit = "raid" .. i
			end

			if UnitIsUnit("player", unit) then
				return "player", i
			else
				return unit, i
			end
		end

		local function check_state()
			if i ~= 0 then
				error("Cannot change iterator state once iteration started")
			end
		end

		function it:Limit(n)
			check_state()
			limit = n
			return self
		end

		return it
	end

	function Roster:Iterate(sorted)
		if not IsInGroup() then
			return solo_iterator()
		elseif not IsInRaid() then
			return party_iterator()
		else
			return raid_iterator(sorted)
		end
	end
end

--------------------------------------------------------------------------------

function Roster:GetUnit(guid)
	return LGIST:GuidToUnit(guid)
end

function Roster:GetInfo(guid)
	return LGIST:GetCachedInfo(guid)
end

--------------------------------------------------------------------------------

function Roster:RosterUpdate(_, guid, unit, info)
	if not self.group[guid] then
		self:SendMessage("FS_ROSTER_JOINED", guid, unit)
		self.group[guid] = true
	end
	self:SendMessage("FS_ROSTER_UPDATE", guid, unit, info)
end

function Roster:RosterRemove(_, guid)
	self.group[guid] = nil
	self:SendMessage("FS_ROSTER_LEFT", guid)
end
