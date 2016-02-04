local _, FS = ...
local Pacman = FS:GetModule("Pacman")
local Console, Store = Pacman:SubModule("Console", "AceConsole-3.0")

local printf = Pacman.printf

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Console:OnInitialize()
	self:RegisterChatCommand("pacman", "OnSlashPacman")
	self:RegisterChatCommand("pm", "OnSlashPacman")
	FS:GetModule("Console"):RegisterCommand("pacman", self)
end

-------------------------------------------------------------------------------
-- Console API
-------------------------------------------------------------------------------

-- Package manipulation verbs
local verbs = {
	edit = function(pkg) Pacman.Editor:Open(pkg, false) end,
	view = function(pkg) Pacman.Editor:Open(pkg, true) end,
	enable = function(pkg) Store:EnablePackage(pkg) end,
	disable = function(pkg) Store:DisablePackage(pkg) end,
}

-- Print the list of installed packages and their status
local function PrintPackagesList()
	print("|cffff7d0aInstalled packages:")
	
	local out = {}
	for uuid, pkg in Store:Packages() do
		local status = Store:Status(pkg)
		out[#out + 1] = ("  |cff64b4ff%s|r %s |cffffd200%s |r[|cff%s|cff%s|r]"):format(
			pkg.id,
			pkg.revision,
			pkg.author,
			status.profile.enabled and "00ff00E" or "ff7d0aD",
			status.loaded and "00ff00L" or "ff7d0aU"
		)
	end
	
	-- Sort packages list
	table.sort(out)
	
	-- Output
	for _, row in ipairs(out) do print(row) end
end

-------------------------------------------------------------------------------
-- Event handlers
-------------------------------------------------------------------------------

-- Parsed input
function Console:OnSlash(cmd, arg1, arg2)
	if not cmd or cmd == "" then
		Pacman:OpenGUI()
	elseif cmd == "list" then
		PrintPackagesList()
	elseif verbs[cmd] then
		local pkg = Store:Get(arg1)
		if pkg then
			verbs[cmd](pkg)
		else
			printf("Unknown package '%s'.", arg1 or "")
		end
	else
		printf("Undefined Pacman command '%s'.", cmd or "")
	end
end

-- Unparsed input
function Console:OnSlashPacman(cmd)
	self:OnSlash(self:GetArgs(cmd, 10))
end
