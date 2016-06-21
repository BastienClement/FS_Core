local _, FS = ...

FS.Util.Operator = {
	----------------------------------------------------------------------------
	-- Comparison operators
	----------------------------------------------------------------------------
	Lt  = function(a, b) return a < b end,
	Le  = function(a, b) return a <= b end,
	Eq  = function(a, b) return a == b end,
	Ne  = function(a, b) return a ~= b end,
	Ge  = function(a, b) return a >= b end,
	Gt  = function(a, b) return a > b end,

	----------------------------------------------------------------------------
	-- Arithmetic operators
	----------------------------------------------------------------------------
	Add = function(a, b) return a + b end,
	Div = function(a, b) return a / b end,
	FloorDiv = function(a, b) return math.floor(a/b) end,
	IntDiv = function(a, b)
		local q = a / b
		if a >= 0 then return math.floor(q) else return math.ceil(q) end
	end,
	Mod = function(a, b) return a % b end,
	Mul = function(a, b) return a * b end,
	Neg = function(a) return -a end,
	Pow = function(a, b) return a ^ b end,
	Sub = function(a, b) return a - b end,

	----------------------------------------------------------------------------
	-- String operators
	----------------------------------------------------------------------------
	Concat = function(a, b) return a..b end,
	Len = function(a) return #a end,

	----------------------------------------------------------------------------
	-- Logical operators
	----------------------------------------------------------------------------
	And = function(a, b) return a and b end,
	Or = function(a, b) return a or b end,
	Not = function(a) return not a end,
	Truth = function(a) return not not a end,

	----------------------------------------------------------------------------
	-- Control flow
	----------------------------------------------------------------------------
	Break = function() end,
}
