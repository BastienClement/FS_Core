local _, FS = ...
local Token = FS:RegisterModule("Token", "AceTimer-3.0")
local Network, Console

-- Player's GUID
local PLAYER_GUID
local PLAYER_NAME

-- Defined tokens
local tokens = {}
local enabled = {}
local enabled_count = 0

-- Broadcast messages buffer
local broadcast_buffer = {}

-- Whisper messages buffer
local whisper_buffers = {}
local whisper_buffers_empty = true

-- Player's node ID
local id = {
	time = 0,
	dev  = FS.version == "dev",
	guid = "Player-?"
}

-- States
local STATE_DISABLED    = 1 -- Token is disabled and completely ignored
local STATE_UNAVAILABLE = 2 -- Same as disabled, but because we don't have promote, automatically transition to INIT if we are promoted
local STATE_INIT        = 3 -- Init phase, sending search message and attempting to prevent causing a new election
local STATE_CLAIMING    = 4 -- Claiming the token, starting an election
local STATE_CLAIMED     = 5 -- Someone higher priority claimed the token
local STATE_ACQUIRED    = 6 -- Election is done, someone broadcasted acquire message
local STATE_DISPOSED    = 7 -- Token is disposed and should never be used again

local state_name = {
	[STATE_DISABLED]    = "|cffc41f3bDISABLED|r",
	[STATE_UNAVAILABLE] = "|cffff7d0aUNAVAILABLE|r",
	[STATE_INIT]        = "|cfffff569INIT|r",
	[STATE_CLAIMING]    = "|cff69ccf0CLAIMING|r",
	[STATE_CLAIMED]     = "|cff69ccf0CLAIMED|r",
	[STATE_ACQUIRED]    = "|cffabd473ACQUIRED|r",
	[STATE_DISPOSED]    = "|cffc41f3bDISPOSED|r"
}

--------------------------------------------------------------------------------

-- Compare tokens level and owners GUID to chose the most rightful one
local function compare(tid_a, oid_a, tid_b, oid_b)
	if tid_a.level ~= tid_b.level then
		-- Highest level wins
		-- This is the basis of token versioning
		return (tid_a.level > tid_b.level) and 1 or -1
	elseif oid_a.dev ~= oid_b.dev then
		-- Dev wins
		-- The intent here is that error should be thrown on dev players
		return oid_a.dev and 1 or -1
	elseif oid_a.time ~= oid_b.time then
		-- Lowest time wins
		-- Highest game uptime is probably a good sign that network is not an issue
		return (oid_a.time < oid_b.time) and 1 or -1
	else
		-- Highest GUID wins
		-- Nothing else to compare...
		return (oid_b.guid > oid_b.guid) and -1 or 1
	end
end

--------------------------------------------------------------------------------

function Token:OnInitialize()
	Network = FS.Network
	Console = FS.Console
	Console:RegisterCommand("token", self)
end

function Token:OnEnable()
	-- Fetch player's GUID
	PLAYER_GUID = UnitGUID("player")
	PLAYER_NAME = GetUnitName("player", true)

	-- Update ID table
	id.guid = PLAYER_GUID
	id.time = GetServerTime()

	-- Bind token network messages
	self:RegisterMessage("FS_MSG_TOKEN")

	-- Check group composition change
	self:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function Token:EnableToken(token)
	enabled[token.name] = token
	enabled_count = enabled_count + 1

	if enabled_count == 1 then
		-- Periodically flush buffers
		self:ScheduleRepeatingTimer("FlushBuffers", 1)
		-- Check token owner liveness
		self:ScheduleRepeatingTimer("CheckLiveness", 15)
	end
end

function Token:DisableToken(token)
	enabled[token.name] = token
	enabled_count = enabled_count - 1
	if enabled_count == 0 then
		self:CancelAllTimers()
		self:FlushBuffers()
	end
end

--------------------------------------------------------------------------------

-- Broadcast a message to every players in the group
function Token:Broadcast(msg, callback)
	if type(callback) == "function" then
		msg._callback = callback
	end
	table.insert(broadcast_buffer, msg)
	return msg
end

-- Cancel a message sent by Token:Broadcast if this is still possible
-- Must be called before Token:FlushBuffers is called.
function Token:CancelBroadcast(msg)
	if #broadcast_buffer < 1 then return end
	for i, m in ipairs(broadcast_buffer) do
		if m == msg then
			table.remove(broadcast_buffer, i)
			return
		end
	end
end

-- Send a message to a specific player
function Token:Whisper(msg, target, callback)
	local target_buffer = whisper_buffers[target]
	if not target_buffer then
		target_buffer = {}
		whisper_buffers[target] = target_buffer
		whisper_buffers_empty = false
	end
	if type(callback) == "function" then
		msg._callback = callback
	end
	table.insert(target_buffer, msg)
	return msg
end

do
	-- Execute every registered callbacks
	local function execute_callback(msgs)
		for _, msg in ipairs(msgs) do
			if msg._callback then
				msg._callback()
				msg._callback = nil
			end
		end
	end

	-- Flush output messages buffers
	-- Buffers are used to group messages related to independant tokens in the same common message
	function Token:FlushBuffers()
		if #broadcast_buffer > 0 then
			execute_callback(broadcast_buffer)
			if IsInGroup() then
				Network:Send("TOKEN", { packed = broadcast_buffer, id = id }, "RAID")
			end
			wipe(broadcast_buffer)
		end

		if not whisper_buffers_empty then
			for target, buffer in pairs(whisper_buffers) do
				execute_callback(buffer)
				Network:Send("TOKEN", { packed = buffer, id = id }, target)
			end
			wipe(whisper_buffers)
			whisper_buffers_empty = true
		end
	end
end

-- Check token owner liveness
function Token:CheckLiveness()
	local now = GetTime()
	for name, token in pairs(enabled) do
		if token.state == STATE_ACQUIRED then
			if token:IsMine() then
				self:Broadcast({ heartbeat = token.id })
			elseif now - token.ping > 20 then
				token:Claim()
			end
		end
	end
end

function Token:GROUP_ROSTER_UPDATE()
	for name, token in pairs(tokens) do
		local acquirable = token:IsAcquirable()
		if token:IsEnabled() and not acquirable then
			token:Disable(true)
		elseif token.state == STATE_UNAVAILABLE and acquirable then
			token:Enable()
		end
	end
end

--------------------------------------------------------------------------------

-- Received a token-related network message
function Token:FS_MSG_TOKEN(_, data, channel, sender)
	-- Packed messages
	if data.packed then
		-- Ignore our own messages
		if data.id.guid == PLAYER_GUID then return end

		-- Iterate for each message
		for _, item in ipairs(data.packed) do
			item.id = data.id
			self:FS_MSG_TOKEN(nil, item, channel, sender)
		end

	-- Search request on token init
	elseif data.search then
		local token = enabled[data.search.name]
		if token and token:IsMine() and compare(token.id, id, data.search, data.id) > 0 then
			-- We should not respond to a search query if the requested token is higher level than ours
			-- If we do not respond, the requester will trigger a claim and win the election
			self:Whisper({ own = token.id }, sender)
		end

	-- Current token owner response
	elseif data.own then
		local token = enabled[data.own.name]
		if token and token.state == STATE_INIT then
			token:SetOwner(data.id.guid, sender)
		end

	-- Token claim
	elseif data.claim then
		local token = enabled[data.claim.name]
		if token then
			-- Claimer ID is lower priority than me, bully
			if compare(token.id, id, data.claim, data.id) > 0 then
				token:Claim()
			else
				if token.state == STATE_CLAIMING then
					token:CancelClaim()
				end
				token.state = STATE_CLAIMED
				token.owner = data.id.guid
				token.owner_name = sender
			end
		end

	-- Token acquire announce
	elseif data.acquire then
		local token = enabled[data.acquire.name]
		if token then
			-- Not the rightful owner
			if compare(token.id, id, data.acquire, data.id) > 0 then
				token:Claim()
			else
				token:SetOwner(data.id.guid, sender)
			end
		end

	-- Token released
	elseif data.release then
		local token = enabled[data.release.name]
		if token then
			token:Claim()
		end

	-- Token renew heartbeat
	elseif data.heartbeat then
		local token = enabled[data.heartbeat.name]
		if token and data.id.guid == token.owner then
			token.ping = GetTime()
		end
	end
end

--------------------------------------------------------------------------------

local TokenObj = {}
TokenObj.__index = TokenObj

-- Creates a new Token object
function TokenObj:New(name, level, promote)
	return setmetatable({
		name = name,
		level = level,
		id = { name = name, level = level },
		promote = promote,
		state = STATE_DISABLED,
		owner = nil,
		owner_name = nil,
		ping = 0
	}, TokenObj)
end

-- Enable the token, attempting to claim it
function TokenObj:Enable()
	if self.state > STATE_UNAVAILABLE then
		-- Token is already enabled
	elseif not self:IsAcquirable() then
		-- Token is not acquireable, wait
		self.state = STATE_UNAVAILABLE
	else
		-- Enable the token
		self.state = STATE_INIT
		Token:EnableToken(self)

		-- Search the current owner
		Token:Broadcast({ search = self.id }, function()
			-- If no answers after 3 sec, claim it
			C_Timer.After(3, function()
				if self.state == STATE_INIT then
					self:Claim()
				end
			end)
		end)
	end
end

-- Disable the token, releasing it if we own it
function TokenObj:Disable(unavailable, no_release)
	if self.state ~= STATE_DISABLED and self.state ~= STATE_DISPOSED then
		-- Release the token if we own it
		if self:IsMine() and not no_release then
			Token:Broadcast({ release = self.id })
		end

		-- Disable the token if previously enabled
		if self.state > STATE_UNAVAILABLE then
			Token:DisableToken(self)
		end

		-- Update state
		self.state = unavailable and STATE_UNAVAILABLE or STATE_DISABLED

		-- Erase owner information
		self.owner = nil
		self.owner_name = nil
	end
end

function TokenObj:IsEnabled()
	return self.state > STATE_UNAVAILABLE and self.state ~= STATE_DISPOSED
end

-- Check if the token is acquirable (require raid promote and we have it)
function TokenObj:IsAcquirable()
	if self.promote and IsInGroup() then
		return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	else
		return true
	end
end

-- Attempts to claim and acquire the token
function TokenObj:Claim()
	-- Token is not claimable
	if self.state < STATE_INIT or self.state > STATE_ACQUIRED then
		return
	end

	-- Claiming the token
	self.state = STATE_CLAIMING
	self.owner = PLAYER_GUID
	self.owner_name = PLAYER_NAME

	self.claim_msg = Token:Broadcast({ claim = self.id }, function()
		self.claim_msg = nil
		if self.state == STATE_CLAIMING then
			-- If we get no answers after 3 sec, consider we have acquired the token
			C_Timer.After(3, function()
				if self.state == STATE_CLAIMING then
					self:SetOwner(PLAYER_GUID, PLAYER_NAME)
					Token:Broadcast({ acquire = self.id })
				end
			end)
		end
	end)
end

-- Cancels the claim if we received another better one before effectively sending our claim
function TokenObj:CancelClaim()
	local claim = self.claim_msg
	if claim then
		Token:CancelBroadcast(claim)
	end
end

-- Sets the token owner and state to ACQUIRED
function TokenObj:SetOwner(guid, name)
	-- Checks if we previsouly were the token owner
	local was_mine = self.last_owner == PLAYER_GUID
	local is_mine = guid == PLAYER_GUID

	-- Update state
	self.state = STATE_ACQUIRED
	self.owner = guid
	self.owner_name = name
	self.last_owner = guid

	if was_mine then Token:SendMessage("FS_TOKEN_LOST", self.name, self) end
	Token:SendMessage("FS_TOKEN_ACQUIRED", self.name, self)
	if is_mine then Token:SendMessage("FS_TOKEN_WON", self.name, self) end
end

-- Returns the token owner GUID and name
function TokenObj:Owner()
	if self.state == STATE_ACQUIRED then
		return self.owner, self.owner_name
	else
		return nil, nil
	end
end

-- Checks if we are the current owner of the token
function TokenObj:IsMine()
	return self.state == STATE_ACQUIRED and self.owner == PLAYER_GUID
end

-- Dispose of the token, never doing anything with it again
function TokenObj:Dispose(upgrade)
	self:Disable(false, upgrade)
	self.state = STATE_DISPOSED
end

--------------------------------------------------------------------------------

-- Create a new token object
function Token:Create(name, level, default, promote)
	local old = tokens[name]
	if old then old:Dispose(false, true) end

	local token = TokenObj:New(name, level, promote)
	tokens[name] = token

	if default ~= false then
		token:Enable()
	end

	return token
end

--------------------------------------------------------------------------------

function Token:OnSlash()
	self:Printf("Listing %s enabled token", enabled_count)
	if enabled_count == 0 then return end

	local lines = {}
	for _, token in pairs(enabled) do
		local owner_name = token.state >= STATE_CLAIMING and token.owner_name or ""
		local line = ("  |cffc79c6e%s  |cff999999%s  %s  %s"):format(token.name, token.level, state_name[token.state], owner_name)
		table.insert(lines, line)
	end

	table.sort(lines)
	for _, line in ipairs(lines) do
		print(line)
	end
end
