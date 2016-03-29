local _, FS = ...
local Cooldowns = FS:RegisterModule("Cooldowns")

-------------------------------------------------------------------------------
-- Cooldowns config
--------------------------------------------------------------------------------

local cooldowns_config = {
	title = {
		type = "description",
		name = "|cff64b4ffCooldowns Tracker",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Track group members' spell cooldowns.\n",
		fontSize = "medium",
		order = 1
	},
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Public API", 2000, {
	}, "FS.Cooldowns"),
	events = FS.Config:MakeDoc("Emitted events", 3000, {
	}, "FS_COOLDOWNS")
}

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

Cooldowns.spells = {}
Cooldowns.units = {}

function Cooldowns:OnInitialize()
	FS.Config:Register("Cooldowns Tracker", cooldowns_config)
end

function Cooldowns:OnEnable()
	self:RegisterMessage("FS_ROSTER_UPDATE")
	self:RegisterMessage("FS_ROSTER_LEFT")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("ENCOUNTER_END")
end

function Cooldowns:OnDisable()
end

-------------------------------------------------------------------------------
-- Directory
-------------------------------------------------------------------------------

local tag_aliases = {
	["IMMUNE"] = { "IMMUNE_MAGICAL", "IMMUNE_PHYSICAL", "REDUCE_HUGE" },
	["REDUCE_HUGE"] = { "REDUCE_HUGE_MAGICAL", "REDUCE_HUGE_PHYSICAL", "REDUCE_BIG" },
	["REDUCE_BIG"] = { "REDUCE_BIG_MAGICAL", "REDUCE_BIG_PHYSICAL", "REDUCE_SMALL" },
	["REDUCE_SMALL"] = { "REDUCE_SMALL_MAGICAL", "REDUCE_SMALL_PHYSICAL" },

	["IMMUNE_MAGICAL"] = { "REDUCE_HUGE_MAGICAL" },
	["REDUCE_HUGE_MAGICAL"] = { "REDUCE_BIG_MAGICAL" },
	["REDUCE_BIG_MAGICAL"] = { "REDUCE_SMALL_MAGICAL" },

	["IMMUNE_PHYSICAL"] = { "REDUCE_HUGE_PHYSICAL" },
	["REDUCE_HUGE_PHYSICAL"] = { "REDUCE_BIG_PHYSICAL" },
	["REDUCE_BIG_PHYSICAL"] = { "REDUCE_SMALL_PHYSICAL" },

	["SILENCE"] = { "INTERRUPT" },
}

function Cooldowns:RegisterSpells(class, cooldowns)
	if type(class) == "table" then
		cooldowns = class
		class = nil
	end

	for id, data in pairs(cooldowns) do
		data.id = id

		if class and not data.class then data.class = class end
		if not data.cooldown then data.cooldown = 1.5 end

		local tag_queue = {}
		local tags = {}
		local level = 1

		local function drain()
			while #tag_queue > 0 do
				local tag = table.remove(tag_queue, 1)
				if not tags[tag] then
					tags[tag] = level
					level = level + 1

					if tag_aliases[tag] then
						for _, alias in ipairs(tag_aliases[tag]) do
							table.insert(tag_queue, alias)
						end
					end
				end
			end
		end

		for _, tag in ipairs(data.tags or { data.tag }) do
			table.insert(tag_queue, tag)
		end

		drain()

		data.tags = tags
		self.spells[id] = data
	end
end

function Cooldowns:IterateSpells()
	return pairs(self.spells)
end

-------------------------------------------------------------------------------
-- Unit
-------------------------------------------------------------------------------

function Cooldowns:GetUnit(guid)
	local unit = self.units[guid]
	if not unit and UnitExists(guid) then
		unit = self.units[UnitGUID(guid)]
	end
	return unit
end

function Cooldowns:IterateUnits()
	return pairs(self.units)
end

do
	-- Unit prototype
	local Unit = {}
	Unit.__index = Unit

	function Unit:New(guid, info)
		return setmetatable({
			guid = guid,
			info = info,
			cooldowns = {}
		}, Unit)
	end

	function Unit:HasGlyph(gid)
		return self.infos.glyphs[gid] ~= nil
	end

	function Unit:HasTalent(tid)
		return self.infos.talents[tid] ~= nil
	end

	function Unit:UnitID()
		return self.infos.lku
	end

	function Unit:GetCooldown(spell)
		if type(spell) == "number" then
			return self.cooldowns[spell], 1
		elseif type(spell) == "string" then
			local cooldown, score, ready
			for _, cd in self:IterateCooldowns() do
				local cd_score = cd.spell.tags[spell]
				if cd_score and (not cooldown or cd_score < score or not ready) then
					local cd_ready = cd:IsReady()
					if not cooldown or (cd_ready and not ready) or (cd_score < score and cd_ready == ready) then
						cooldown = cd
						score = cd_score
						ready = cd_ready
					end
				end
			end
			return cooldown, score, ready
		end
	end

	function Unit:IsCooldownReady(spell)
		local cd, score, ready = self:GetCooldown(spell)
		if not cd then return false, 0 end
		if ready == nil then ready = cd:IsReady() end
		return ready, score
	end

	function Unit:IterateCooldowns()
		return pairs(self.cooldowns)
	end

	function Unit:Reset()
		for id, cd in self:IterateCooldowns() do
			cd:Reset()
		end
	end

	function Unit:Dispose()
		for _, cd in self.cooldown do
			cd:Dispose()
		end
	end

	-- Spell proxy
	local function UnitSpellProxy(unit, spell)
		local cache_keys = {}

		local function ClearCache(self)
			wipe(cache_keys)
			wipe(self)
			self.ClearCache = ClearCache
		end

		return setmetatable({
			ClearCache = ClearCache
		}, {
			__index = function(self, key)
				if cache_keys[key] then
					return nil
				else
					local dyn = false
					local value = spell[key]
					if type(value) == "function" and key ~= "ready" and key:sub(1, 2) ~= "on" then
						value, dyn = value(unit)
					end
					if not dyn then
						cache_keys[key] = true
						self[key] = value
					end
					return value
				end
			end
		})
	end

	-- Cooldown
	local Cooldown = {}
	Cooldown.__index = Cooldown

	function Cooldown:New(unit, spell)
		return setmetatable({
			unit = unit,
			spell = UnitSpellProxy(unit, spell),
			used = 0,
			cast = 0,
			expire = 0,
			cooldown = 0
		}, Cooldown)
	end

	function Cooldown:Timings(deadline)
		local now = GetTime()
		if now < deadline then
			local time_left = deadline - GetTime()
			local total_time = deadline - self.cast
			local time_elapsed = total_time - time_left
			return time_elapsed, time_left, total_time
		else
			return 0, 0, 0
		end
	end

	function Cooldown:Invoke(handler, ...)
		local handler = self.spell[handler]
		if type(handler) == "function" then
			return handler(self.unit, self, self.spell, ...)
		end
	end

	function Cooldown:Emit(event, ...)
		Cooldowns:SendMessage(event, self.unit.guid, self.spell.id, ...)
	end

	function Cooldown:IsActive()
		return GetTime() < self.expire
	end

	function Cooldown:Duration()
		return self:Timings(self.expire)
	end

	function Cooldown:MaxCharges()
		return self.spell.charges or 1
	end

	function Cooldown:IsReady(target)
		return self.used < self:MaxCharges() and self:Invoke("ready", target) ~= false
	end

	function Cooldown:Cooldown()
		return self:Timings(self.cooldown)
	end

	function Cooldown:Update()
		self.spell:ClearCache()

		local max_charges = self:MaxCharges()
		if self.used > max_charges then
			self.used = max_charges
		end

		self:Invoke("onupdate")
	end

	function Cooldown:CancelTimer()
		if self.timer then
			self.timer:Cancel()
		end
	end

	function Cooldown:BeginCooldown(cooldown)
		if not cooldown then cooldown = self.spell.cooldown end
		self.cooldown = GetTime() + cooldown

		self:CancelTimer()
		self.timer = C_Timer.NewTimer(cooldown, function()
			self:CooldownFinished()
		end)

		self:Invoke("onbegin", cooldown)
		self:Emit("FS_COOLDOWNS_START", cooldown)
	end

	function Cooldown:CooldownFinished()
		self.timer = nil

		local used = self.used - 1
		if used < 0 then used = 0 end
		self.used = used

		self:Invoke("onfinish")
		self:Emit("FS_COOLDOWNS_READY")

		if used > 0 then
			self:BeginCooldown()
		end
	end

	function Cooldown:Trigger(target, cooldown)
		if self:Invoke("ontrigger", target, cooldown) ~= false then
			local now = GetTime()

			local used = self.used + 1
			local charges = self.spell.charges or 1
			if used > charges then used = charges end
			self.used = used

			local duration = self.spell.duration or 0
			self.cast = now
			self.expire = now + duration
			self:Emit("FS_COOLDOWNS_USED", duration)

			if self.used == 1 then
				self:BeginCooldown(cooldown)
			end
		end
	end

	function Cooldown:Reset()
		local should_reset = self.spell.reset
		if should_reset == nil then
			should_reset = self.spell.cooldown >= 180
		end
		if should_reset and self:Invoke("onreset") ~= false then
			self:CancelTimer()
			self.used = 0
			self.cast = 0
			self.expire = 0
			self.cooldown = 0
			self:Emit("FS_COOLDOWNS_RESET")
		end
	end

	function Cooldown:Dispose()
		self:CancelTimer()
		self:Emit("FS_COOLDOWNS_LOST", duration)
		self:Invoke("ondispose")
	end

	-- Updater
	function Cooldowns:UpdateUnit(guid, info)
		local unit = self.units[guid]

		-- Create or update unit
		if not unit then
			unit = Unit:New(guid, info)
			self.units[guid] = unit
		else
			unit.info = info
		end

		-- Matches spell definition criteria with current unit
		local function match(criterion, value, op)
			if criterion == nil then
				-- No criterion in the spell definition
				return true
			elseif type(criterion) == "boolean" then
				-- A function returned a definitive result, bypass all remaining checks
				return criterion
			elseif type(criterion) == "table" then
				-- One item in the table must match
				for _, sub_criterion in ipairs(criterion) do
					if match(sub_criterion, value) then
						return true
					end
				end
				return false
			elseif type(criterion) == "function" then
				-- Evaluate the function with the info table and then match
				return match(criterion(info), value)
			elseif value == nil then
				-- No value to match against
				return false
			elseif type(value) == "table" then
				-- Must match one key of the table
				return value[criterion] ~= nil
			else
				if not (criterion == value) then
					print(criterion, value)
				end
				return criterion == value
			end
		end

		for id, spell in self:IterateSpells() do
			local cd = unit.cooldowns[id]

			if  match(spell.class,  info.class)
			and match(spell.race,   info.race)
			and match(spell.spec,   info.global_spec_id)
			and match(spell.glyph,  info.glyphs)
			and match(spell.talent, info.talents)
			and match(spell.available) then
				if not cd then
					cd = Cooldown:New(unit, spell)
					cd:Emit("FS_COOLDOWNS_GAINED")
					unit.cooldowns[id] = cd
				end
				cd:Update()
			elseif cd then
				unit.cooldowns[id]:Dispose()
				unit.cooldowns[id] = nil
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Query
-------------------------------------------------------------------------------

function Cooldowns:GetCooldown(guid, spell)
	local unit = self:GetUnit(guid)
	if unit then return unit:GetCooldown(spell) end
end

function Cooldowns:IsCooldownReady(guid, spell)
	local unit = self:GetUnit(guid)
	if unit then return unit:IsCooldownReady(spell) end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

function Cooldowns:FS_ROSTER_UPDATE(_, guid, _, info)
	self:UpdateUnit(guid, info)
end

function Cooldowns:FS_ROSTER_LEFT(_, guid)
	local unit = self.units[guid]
	if unit then
		unit:Dispose()
		self.units[guid] = nil
	end
end

function Cooldowns:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, _, source, _, _, _, target, _, _, _, spell, spellname)
	if event == "SPELL_CAST_SUCCESS" then
		local unit = self.units[source]
		if not unit then return end

		local cd = unit.cooldowns[spell]
		if not cd then return end

		cd:Trigger(target)
	end
end

function Cooldowns:ENCOUNTER_END()
	for guid, unit in Cooldowns:IterateUnits() do
		unit:Reset()
	end
end
