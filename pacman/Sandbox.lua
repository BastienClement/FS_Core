local _, FS = ...
local Pacman = FS:GetModule("Pacman")
local Sandbox, Store = Pacman:SubModule("Sandbox")

local printf = Pacman.printf

-------------------------------------------------------------------------------
-- Rules
-------------------------------------------------------------------------------

-- Lua functions that may allow breaking out of the environment
-- Access to these function are blocked and a warning message is printed
local blocked = {
	getfenv = true,
	setfenv = true,
	RunScript = true,
}

-- Overrides
-- Access to these function are transparently rewritten
local override = {
}

-------------------------------------------------------------------------------
-- Builder
-------------------------------------------------------------------------------

local env_cache = {}

-- Construct the sandbox environment
function Sandbox:GetEnvironment(pkg)
	local uuid = pkg.uuid
	local id = pkg.id
	
	-- Environment already created
	local env = env_cache[uuid]
	if env then return env end
	
	-- New environment
	env = {}
	env_cache[uuid] = env
	
	-- Blocked warning
	local function blocked_warn()
		printf("The package '%s' just tried to use a forbidden function but has been blocked from doing so.", id)
	end
	
	-- Create the sandbox and the package-locals container
	local sandbox = {}
	local locals = setmetatable({}, { __index = sandbox })
	
	env.sandbox = sandbox
	env.locals = locals
		
	-- Exports object
	sandbox.exports = {}
	
	-- Package database
	sandbox.db = Store:Status(pkg).db
	
	-- Module loading cache
	local modules = {}
	
	-- Reloading
	function env.Reload()
		-- Reload references
		pkg = Store:Get(uuid)
		id = pkg.id
		sandbox.db = Store:Status(pkg).db
		
		-- Call OnReload function
		local reload = locals._reload
		if type(reload) == "function" then
			local ok, exports = pcall(reload)
			if not ok then
				printf("Package '%s' reloading failed:\n|cfffff569%s", id, exports)
			elseif exports ~= nil then
				-- Value returned replace the previous exports
				Store:UpdateExports(pkg, exports)
			end
		end
	end
	
	-------------------------
	-- PACKAGE API
	-------------------------
	
	-- Read a package file content
	function sandbox.read(file)
		local data = pkg.files[file]
		if data and pkg.flags.Opaque then
			data = Store:Decode(data)
		end
		return data
	end
	
	-- Load a package Lua file
	local _loading = {}
	function sandbox.load(file, reload)
		if modules[file] and not reload then
			return modules[file]
		end
		
		if _loading[file] then
			error(("Loading loop prevented, attempted to load '%s' twice."):format(file), 2)
		else
			_loading[file] = true
		end
		
		local source = sandbox.read(file)
		if not source then
			error(("Loading of '%s' failed: file does not exist."):format(file), 2)
		end
		
		local fn, err = loadstring(source, ("{%s}/%s"):format(id, file))
		if not fn then
			error(("Loading of '%s' failed: %s."):format(file, err), 2)
		end
		
		setfenv(fn, locals)
		
		modules[file] = locals.exports
		local res = fn()
		
		if res ~= nil then
			modules[file] = res
		end
		
		_loading[file] = nil
		return modules[file]
	end
	
	-- Load another package and return its exports table
	function sandbox.require(uuid, rev, optional)
		if type(rev) == "boolean" then
			optional = rev
			rev = nil
		end
		
		pkg = Store:Get(uuid)
		if not pkg then
			local human_name = uuid
			
			-- Attempt to find a variable containing this UUID and use its name instead
			for key, val in pairs(locals) do
				if val == uuid then
					human_name = key
					break
				end
			end
			
			error(("Cannot find required package '%s'."):format(human_name), 2)
		end
		
		local ok, exports = Store:Load(pkg)
		if not ok then
			error(("Cannot load required package '%s'.\n%s"):format(pkg.id, exports), 2)
		end
		
		return exports
	end
	
	-------------------------
	-- END PACKAGE API
	-------------------------
	
	-- Actually sandbox the sandbox
	setmetatable(sandbox, {
		__index = function(_, k)
			if k == "_G" then
				return sandbox
			elseif k == "_L" then
				return locals
			elseif blocked[k] then
				return blocked_warn
			elseif override[k] then
				return override[k]
			else
				return _G[k]
			end
		end,
		__newindex = function(_, k, v)
			if k ~= "_G" and not blocked[k] and not override[k] then
				_G[k] = v
			end
		end
	})
	
	-- Return the complete environment
	return env
end
