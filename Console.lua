local _, FS = ...
local Console = FS:RegisterModule("Console")

Console.commands = {}

function Console:OnEnable()
	self:RegisterChatCommand("fs", "OnSlashCmd")
end

function Console:PrintAvailableCommands()
	local cmds = {}
	for cmd, handler in pairs(self.commands) do
		cmds[#cmds + 1] = cmd
	end
	self:Printf("Available sub-commands: %s", table.concat(cmds, ", "))
end

function Console:OnSlashCmd(cmd)
	local subcmd, n = self:GetArgs(cmd)
	if not subcmd then
		self:Print("Usage: /fs <subcmd> <args>")
		self:PrintAvailableCommands()
		return
	end
	
	local handler = self.commands[subcmd:lower()]
	if not handler then
		self:Printf("Undefined sub-command '%s'.")
		self:PrintAvailableCommands()
		return
	end
	
	handler:OnSlashCmd(self:GetArgs(cmd, 10, n))
end

function Console:RegisterCommand(cmd, handler)
	if self.commands[cmd] then
		self:Printf("Unable to register chat sub-command '%s'. This name is already taken.", cmd)
		return
	end
	
	if not handler or not handler.OnSlashCmd then
		self:Printf("Unable to register chat sub-command '%s'. The given command handler doesn't define the :OnSlashCmd() method.", cmd)
		return
	end
	
	self.commands[cmd] = handler
end

function Console:UnregisterCommand(cmd)
	self.commands[cmd] = nil
end
