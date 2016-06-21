local _, FS = ...

local Operator = FS.Util.Operator

-- Stream methods
local Stream = {}

-- Stream metatable
local stream_mt = {
	__call = function(self, param, state)
		return self.gen(param or self.param, state or self.state)
	end,
	__tostring = function(self)
		return "<stream>"
	end,
	__index = Stream,
	__len = function(self)
		return self:length()
	end
}

-- Constucts a stream from a triplet
local function stream(gen, param, state)
	return setmetatable({
		gen = gen,
		param = param,
		state = state
	}, stream_mt), param, state
end

-------------------------------------------------------------------------------
-- Generators
-------------------------------------------------------------------------------

function FS.Util.Stream(gen, param, state)
	local tpe = type(gen)
	if tpe == "function" then
		return stream(gen, param, state)
	elseif tpe == "table" then
		return (#gen > 0) and stream(ipairs(gen)) : map (function(a, b) return b end) or stream(pairs(gen))
	else
		error("Stream: unsupported generator type: " .. tpe)
	end
end

function FS.Util.Generate(generator, state, ...)
	if state == nil then
		if select("#", ...) > 0 then
			local values = { state, ... }
			return stream(function() return unpack(values) end)
		else
			return stream(function() return state end)
		end
	else
		local first = true
		return stream(function()
			if first then
				first = false
			else
				state = generator(state)
			end
			return state
		end)
	end
end

function FS.Util.Range(start, stop, step)
	if stop == nil then
		stop = start
		start = (stop >= 0) and 1 or -1
	end
	if step == nil then
		step = (start <= stop) and 1 or -1
	end
	if start == 0 and stop == 0 then
		return stream(function() return nil end)
	else
		return stream(function(param, current)
			current = current + step
			if (start <= stop and current > stop) or (start > stop and current < stop) then
				return nil
			else
				return current
			end
		end, nil, start - step)
	end
end

-------------------------------------------------------------------------------
-- Consumers
-------------------------------------------------------------------------------

-- Foreach
do
	local function trampoline(fn, state, ...)
		if state == nil then return nil end
		if fn(state, ...) == Operator.Break then return nil end
		return state
	end

	function Stream:foreach(fn)
		local gen, param, state = self.gen, self.param, self.state
		repeat
			state = trampoline(fn, gen(param, state))
		until state == nil
	end
end

-- Peek
do
	local function peek(fn, state, ...)
		if state == nil then return nil end
		fn(state, ...)
		return state, ...
	end

	function Stream:peek(fn)
		local gen = self.gen
		return stream(function(...)
			return peek(fn, gen(...))
		end, self.param, self.state)
	end
end

-------------------------------------------------------------------------------
-- Slicing
-------------------------------------------------------------------------------

-- Take
do
	local function take(pred, state, ...)
		if state == nil or not pred(state, ...) then return nil end
		return state, ...
	end

	function Stream:take(pred)
		if type(pred) == "number" then
			if pred <= 0 then return self end
			local left = pred
			pred = function()
				left = left - 1
				return left >= 0
			end
		end

		local gen = self.gen
		return stream(function(param, state)
			return take(pred, gen(param, state))
		end, self.param, self.state)
	end
end

-- Drop
function Stream:drop(pred)
	if type(pred) == "number" then
		if pred <= 0 then return self end
		local left = pred - 1
		pred = function()
			left = left - 1
			return left >= 0
		end
	end

	local gen, param, state = self.gen, self.param, self.state

	repeat
		state = gen(param, state)
	until state == nil or not pred(state)

	return stream(gen, param, state)
end

-- Span
function Stream:span(pred)
	return self:take(pred), self:drop(pred)
end

-------------------------------------------------------------------------------
-- Filtering
-------------------------------------------------------------------------------

-- Filter
function Stream:filter(pred)
	return self:collect(function(...)
		if pred(...) then
			return ...
		else
			return nil
		end
	end)
end

-------------------------------------------------------------------------------
-- Transformations
-------------------------------------------------------------------------------

-- Map
function Stream:map(fn, continue)
	local gen, param, state = self.gen, self.param, self.state
	local map, collect, next

	map = function(new_state, ...)
		state = new_state
		if state == nil then return nil end
		if continue == true then
			return collect(fn(state, ...))
		else
			return fn(state, ...)
		end
	end

	collect = function(state, ...)
		if state == nil then
			return next()
		else
			return state, ...
		end
	end

	next = function()
		return map(gen(param, state))
	end

	return stream(next)
end

-- Collect
function Stream:collect(fn)
	return self:map(fn, true)
end

-- Enumerate
function Stream:enumerate()
	local i = 0
	return self:map(function(...)
		i = i + 1
		return i, ...
	end)
end

-------------------------------------------------------------------------------
-- Composition
-------------------------------------------------------------------------------

do
	local stream = FS.Util.Stream

	local function toIterators(stream)
		return stream:iterator()
	end

	local function iteratorHasNext(iterator)
		return iterator:HasNext()
	end

	local function iteratorNext(iterator)
		return iterator:Next()
	end

	local function zip_gen(sources)
		if not stream(sources) : all(iteratorHasNext) then
			return nil
		else
			return unpack(stream(sources) : map(iteratorNext) : toList())
		end
	end

	function Stream:zip(...)
		return stream(zip_gen, stream { self, ... } : map (toIterators) : toList())
	end
end

-------------------------------------------------------------------------------
-- Reducing
-------------------------------------------------------------------------------

-- Fold
function Stream:fold(seed, fn)
	local acc = seed
	self:foreach(function(...)
		acc = fn(acc, ...)
	end)
	return acc
end

-- Len
function Stream:len()
	return self:fold(0, function(a) return a + 1 end)
end

-- Count
function Stream:count(pred)
	return self:fold(0, function(a, ...)
		if pred(...) then
			return a + 1
		else
			return a
		end
	end)
end

-- Sum
function Stream:sum()
	return self:fold(0, Operator.Add)
end

-- Product
function Stream:product()
	return self:fold(0, Operator.Mul)
end

-- Min
function Stream:min(comp)
	comp = comp or Operator.Lt
	return self:fold(nil, function(min, a)
		if min == nil or comp(a, min) then return a else return min end
	end)
end

-- Max
function Stream:max(comp)
	comp = comp or Operator.Gt
	return self:fold(nil, function(max, a)
		if max == nil or comp(a, max) then return a else return max end
	end)
end

-- All
function Stream:all(pred)
	local all = true
	self:foreach(function(...)
		if not pred(...) then
			all = false
			return Operator.Break
		end
	end)
	return all
end

-- Any
function Stream:any(pred)
	local any = false
	self:foreach(function(...)
		if pred(...) then
			any = true
			return Operator.Break
		end
	end)
	return any
end

-- ToList
function Stream:toList()
	return self:fold({}, function(l, v)
		table.insert(l, v)
		return l
	end)
end

-- ToMap
function Stream:toMap()
	return self:fold({}, function(m, k, v)
		m[k] = v
		return m
	end)
end

-- Iterator
function Stream:iterator()
	local gen, param, state = self.gen, self.param, self.state

	local it = {
		generated = false
	}

	function it:Generate()
		self.generated = true
		state = gen(param, state)
	end

	function it:HasNext()
		if not self.generated then self:Generate() end
		return state ~= nil
	end

	function it:Next()
		if not self.generated then self:Generate() end
		self.generated = false
		return state
	end

	return it
end
