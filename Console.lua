local _, FS = ...
local Console = FS:RegisterModule("Console")

local AceConfigDialog = LibStub("AceConfigDialog-3.0")

Console.commands = {}

function Console:OnEnable()
	self:RegisterChatCommand("fs", "OnSlash")
end

function Console:PrintAvailableCommands()
	local cmds = {}
	for cmd, handler in pairs(self.commands) do
		cmds[#cmds + 1] = cmd
	end
	self:Printf("Available commands: %s", table.concat(cmds, ", "))
end

function Console:OnSlash(cmd)
	-- Extract subcmd from cmd line
	local subcmd, n = self:GetArgs(cmd)
	if not subcmd then
		AceConfigDialog:Open("FS Core")
		--self:Print("Usage: /fs <cmd> <args>")
		--self:PrintAvailableCommands()
		return
	end
	
	-- Change subcmd to lowercase and fetch handler function
	subcmd = subcmd:lower()
	local handler = self.commands[subcmd]
	
	-- Check that the command is defined
	if not handler then
		self:Printf("Undefined command '%s'.", subcmd)
		self:PrintAvailableCommands()
		return
	end
	
	-- Invoke the handler
	handler(self:GetArgs(cmd, 10, n))
end

function Console:RegisterCommand(cmd, handler, method)
	-- Default handler method
	if not method then method = "OnSlash" end
	
	-- Check if the command is not already registered
	if self.commands[cmd] then
		self:Printf("Unable to register chat command '%s'. This name is already taken.", cmd)
		return
	end
	
	-- Check that the receiver object has the requested handler
	if not handler or not handler[method] then
		self:Printf("Unable to register chat command '%s'. The given command handler doesn't define the :%s() method.", cmd, method)
		return
	end
	
	-- Wrapper function
	self.commands[cmd] = function(...)
		handler[method](handler, ...)
	end
end

function Console:UnregisterCommand(cmd)
	self.commands[cmd] = nil
end
