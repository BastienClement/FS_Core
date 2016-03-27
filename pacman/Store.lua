local _, FS = ...
local Pacman = FS:GetModule("Pacman")

-- Keep private. Do not initialize as SubModule.
-- Other modules will need to grab a reference to this during their init.
local Store = Pacman:ConstructStore()

local AceEvent = LibStub("AceEvent-3.0")
local Compress = LibStub:GetLibrary("LibCompress")

local printf = Pacman.printf

-------------------------------------------------------------------------------
-- Pacman DB
-------------------------------------------------------------------------------

local db
local index = {}

local status
status = setmetatable({}, {
	__index = function(t, uuid)
		local profile_db = Pacman.db.profile.pkg[uuid].db
		local global_db = Pacman.db.global.pkg[uuid].db
		local s = {
			loaded = false,
			profile = Pacman.db.profile.pkg[uuid],
			global = Pacman.db.global.pkg[uuid],
			db = setmetatable({
				profile = profile_db,
				global = global_db
			}, {
				__index = global_db,
				__newindex = function(t, k, v)
					global_db[k] = v
				end
			})
		}
		status[uuid] = s
		return s
	end
})

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Store:OnInitialize()
	-- Initialize database object
	if type(PACMAN_DB) ~= "table" then PACMAN_DB = {} end
	
	-- Move the database to a local variable
	db = PACMAN_DB
	--PACMAN_DB = nil
	
	-- MESSING WITH SAVED VARIABLES IS DANGEROUS
	-- Restore global just before writing SavedVariables
	--AceEvent:RegisterEvent("PLAYER_LOGOUT", function()
		--PACMAN_DB = Compress:Encode7bit(Compress:CompressHuffman(self:Serialize(db)))
		--PACMAN_DB = db
	--end)
	
	-- Cleanup
	for uuid in pairs(Pacman.db.profile.pkg) do
		if not db[uuid] then Pacman.db.profile.pkg[uuid] = nil end
	end
	for uuid in pairs(Pacman.db.global.pkg) do
		if not db[uuid] then Pacman.db.global.pkg[uuid] = nil end
	end
end

function Store:OnEnable()
	-- Force Store update
	self:StoreUpdated()
end

-------------------------------------------------------------------------------
-- Store update
-------------------------------------------------------------------------------

do
	-- Rebuild the package index
	local function RebuildIndex()
		index = {}
		for uuid, pkg in Store:Packages() do
			index[pkg.id:lower()] = pkg
		end
	end
	
	-- Load enabled packages
	local function CheckEnabled()
		for uuid, pkg in Store:Packages() do
			if not pkg.flags.Library or status[uuid].loaded then
				local uuid = pkg.uuid
				if status[uuid].profile.enabled then
					if not Store:HasLoadingFailed(pkg) then
						local loaded_rev = Store:LoadedRevision(pkg)
						if not loaded_rev then
							Store:Load(pkg)
						elseif loaded_rev ~= pkg.revision and pkg.flags.Reloadable then
							Store:Reload(pkg)
						end
					end
				end
			end
		end
	end
	
	-- Notify store updates
	function Store:StoreUpdated()
		RebuildIndex()
		CheckEnabled()
		AceEvent:SendMessage("PACMAN_STORE_UPDATED")
	end
end

-------------------------------------------------------------------------------
-- Template for main.lua
-------------------------------------------------------------------------------

local MAIN_TPL = [===[
-- This file is the initialization file for this package.
-- It is automatically executed by Pacman during the package loading.

-- The content of this file is provided for reference only, skip execution.
do return end

-- You can use 'require(uuid)' to import another package exported values.
-- You must use the package's UUID as a reference.
local lib = require("...")

-- You can use 'load(file)' to execute another file from your package.
load("locales.lua")

-- The 'db' table content is saved between reloads.
if db.enabled == nil then
  db.enabled = false
end

-- If your package has the Configurable flag, the content of the 'config'
-- variable will be treated as an Ace3 options table.
config = {
  enable = {
    type = "toggle",
    name = "Enable",
    width = "full",
    get = function() return db.enabled end,
    set = function(_, v) db.enabled = v end
  }
}

-- Use the 'exports' table to export functions and values to other packages.
export.version = 1
function exports.HelloWorld()
  print("Hello, world")
end

-- If your package has the Reloadable flag, this function will be called
-- when the package is updated.
function reload()
  load("main.lua", true) -- Use true here to force re-evaluation
end]===]

-------------------------------------------------------------------------------
-- Opaque package encoding
-------------------------------------------------------------------------------

function Store:Encode(s)
	return Compress:Encode7bit(s)
end

function Store:Decode(s)
	return Compress:Decode7bit(s)
end

-------------------------------------------------------------------------------
-- Hashing
-------------------------------------------------------------------------------

-- Compute the hash value for a package
function Store:HashPackage(pkg)
	-- Fingerprint components
	local fp = {
		"uuid:" .. pkg.uuid,
		"author:" .. pkg.author,
		"author_key:" .. pkg.author_key,
		"revision:" .. pkg.revision,
		"desc:" .. pkg.desc
	}
	
	-- Use files content
	for name, content in pairs(pkg.files) do fp[#fp + 1] = "file:" .. name .. ":" .. content end
	
	-- Use flags
	for flag in pairs(pkg.flags) do fp[#fp + 1] = "flag:" .. flag end
	
	-- Ensure items are always used in the same order
	table.sort(fp)
	
	-- Compute checksum
	local code = Compress:fcs32init()
	for _, item in ipairs(fp) do
		code = Compress:fcs32update(code, item)
	end
	return Compress:fcs32final(code)
end

-- Update the hash value of a package
function Store:RehashPackage(pkg)
	pkg.hash = self:HashPackage(pkg)
	return pkg
end

-- Check if a package checksum is valid
function Store:IsValid(pkg)
	return pkg.hash == self:HashPackage(pkg)
end

-------------------------------------------------------------------------------
-- Store manipulation
-------------------------------------------------------------------------------

-- Iterator over Store packages
function Store:Packages()
	return pairs(db)
end

-- Get package by UUID
function Store:Get(id)
	if not id then return end
	local pkg = db[id]
	if not pkg then
		pkg = index[id:lower()]
	end
	return pkg
end

-- Get package config
function Store:Status(pkg)
	return status[pkg.uuid]
end

-- Create a new package with given identifier
function Store:CreatePackage(id)
	if index[id:lower()] then return end
	local uuid = FS:UUID()
	
	local pkg = {
		uuid = uuid,
		id = id,
		author = UnitName("player") .. "-" .. GetRealmName(),
		author_key = FS:PlayerKey(),
		revision = 1,
		revision_date = date(),
		files = {
			["main.lua"] = MAIN_TPL
		},
		flags = {},
		desc = ""
	}
	
	db[uuid] = self:RehashPackage(pkg)
	self:StoreUpdated()
end

-- Clone a package
function Store:ClonePackage(pkg, to)
	if index[to:lower()] then return end
	
	local uuid = FS:UUID()
	local clone = FS:Clone(pkg)
	
	clone.id = to
	clone.uuid = uuid
	clone.author = UnitName("player") .. "-" .. GetRealmName()
	clone.author_key = FS:PlayerKey()
	clone.revision = 1
	clone.revision_date = date()
	
	db[uuid] = self:RehashPackage(clone)
	self:StoreUpdated()
end

-- Remove a package
function Store:RemovePackage(pkg)
	db[pkg.uuid] = nil
	Pacman.db.profile.pkg[pkg.uuid] = nil
	Pacman.db.global.pkg[pkg.uuid] = nil
	status[pkg.uuid] = nil
	self:StoreUpdated()
end

-- Enable a package
function Store:EnablePackage(pkg)
	status[pkg.uuid].profile.enabled = true
	self:StoreUpdated()
end

-- Disable a package
function Store:DisablePackage(pkg)
	status[pkg.uuid].profile.enabled = false
	printf("The package '%s' will be disabled during your next UI loading.", pkg.id)
	self:StoreUpdated()
end

-- Return enable state
function Store:IsEnabled(pkg)
	return status[pkg.uuid].profile.enabled
end

-- Update a package object
function Store:UpdatePackage(pkg)
	db[pkg.uuid] = self:RehashPackage(pkg)
	self:StoreUpdated()
end

-------------------------------------------------------------------------------
-- Formatter
-------------------------------------------------------------------------------

-- Export a package
function Store:Export(pkg)
	pkg = FS:Clone(pkg)
	return pkg
end

-- Extract package metadata
function Store:Metadata(pkg)
	-- Compute package size
	-- TODO: be accurate
	local size = #pkg.desc
	for file, content in pairs(pkg.files) do
		size = size + #content
	end
	
	return {
		id = pkg.id,
		uuid = pkg.uuid,
		revision = pkg.revision,
		revision_date = pkg.revision_date,
		author = pkg.author,
		desc = pkg.desc,
		size = size
	}
end

-------------------------------------------------------------------------------
-- Loader
-------------------------------------------------------------------------------

do
	local loaded_revision = {}
	local exports_cache = {}
	local loading_failed = {}
	
	local mute_corrupted_notice = {}

	-- Access the currently loaded revision
	function Store:LoadedRevision(pkg)
		return loaded_revision[pkg.uuid]
	end
	
	-- Check if a package loading has failed
	function Store:HasLoadingFailed(pkg)
		return loading_failed[pkg.uuid]
	end

	-- Load a package
	function Store:Load(pkg)
		local uuid = pkg.uuid
		
		if loaded_revision[uuid] then
			return true, exports_cache[uuid]
		elseif loading_failed[uuid] then
			return false, loading_failed[uuid]
		elseif not status[uuid].profile.enabled then
			return false, "Package is not enabled"
		end
		
		if not self:IsValid(pkg) then
			if not mute_corrupted_notice[uuid] then
				mute_corrupted_notice[uuid] = true
				loading_failed[uuid] = "Hash failure"
				printf("Package '%s' is corrupted and cannot be loaded.", pkg.id)
			end
			return false, "Hash failure"
		end
		
		local env = Pacman.Sandbox:GetEnvironment(pkg)
		local ok, exports = pcall(env.sandbox.load, "main.lua")
		
		if not ok then
			printf("Package '%s' loading failed:\n|cfffff569%s", pkg.id, exports)
			loading_failed[uuid] = exports
		else
			loaded_revision[uuid] = pkg.revision
			exports_cache[uuid] = exports
			status[uuid].loaded = true
			Pacman:NotifyLoaded("Pacman:" .. pkg.id)
		end
		
		return ok, exports
	end

	-- Reload a package
	function Store:Reload(pkg)
		if not pkg.flags.Reloadable then return end
		loaded_revision[pkg.uuid] = pkg.revision
		
		local env = Pacman.Sandbox:GetEnvironment(pkg)
		env.Reload()
	end
	
	-- Change the cached exported values
	function Store:UpdateExports(pkg, exports)
		exports_cache[pkg.uuid] = exports
	end
end
