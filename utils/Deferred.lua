local _, FS = ...

local Deferred = {}
Deferred.__index = Deferred

local function new()
	return setmetatable({
		state = nil,
		values = nil,
		waiting = {}
	}, Deferred)
end

local function resolve(state, self, ...)
	if self.state ~= nil then
		error("Deferred is already resolved")
	end

	self.state = state
	self.values = { ... }

	for _, handlers in ipairs(self.waiting) do
		local handler = handlers[state and 1 or 2]
		if handler then handler(...) end
	end

	self.waiting = nil
end

function Deferred:resolve(...)
	resolve(true, self, ...)
end

function Deferred:reject(...)
	resolve(false, self, ...)
end

function Deferred:onComplete(success, failure)
	if self.state == nil then
		table.insert(self.waiting, { success, failure })
	else
		local handler
		if self.state then
			handler = success
		else
			handler = failure
		end
		if handler then
			handler(unpack(self.values))
		end
	end
end

function Deferred:map(fn)
	local child = new()
	self:onComplete(
		function(...) child:resolve(fn(...)) end,
		function(...) child:reject(...) end
	)
	return child
end

function Deferred:flatmap(fn)
	local child = new()
	self:onComplete(
		function(...) fn(...):onComplete(
			function(...) child:resolve(...) end,
			function(...) child:reject(...) end
		) end,
		function(...) child:reject(...) end
	)
	return child
end

function FS.Util.Deferred(value)
	local deferred = new()
	if value ~= nil then
		deferred:Resolve(value)
	end
	return deferred
end
