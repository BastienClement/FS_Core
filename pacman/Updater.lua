local _, FS = ...
local Pacman = FS:GetModule("Pacman")
local Updater, Store = Pacman:SubModule("Updater", "AceEvent-3.0")

local AceGUI = LibStub("AceGUI-3.0")

local printf = Pacman.printf

-------------------------------------------------------------------------------
-- Life-cycle
-------------------------------------------------------------------------------

function Updater:OnEnable()
	self:RegisterMessage("FS_MSG_PACMAN", "OnNetMessage")
end

-------------------------------------------------------------------------------
-- Sharing
-------------------------------------------------------------------------------

do
	local share_keys = {}
	local share_keys_expire = {}
	
	-- Add a share link for a package in the current textarea
	function Updater:SharePackage(pkg)
		local editbox = GetCurrentKeyBoardFocus()
		if editbox then
			local uuid = pkg.uuid
			if not share_keys[uuid] then
				-- Generate a new share key
				share_keys[uuid] = FS:UUID(8)
			else
				-- Cancel and reset previous timeout
				share_keys_expire[uuid]:Cancel()
			end
			
			-- Share keys expire after 15 min
			share_keys_expire[uuid] = C_Timer.NewTimer(60 * 15, function()
				share_keys[uuid] = nil
				share_keys_expire[uuid] = nil
			end)
			
			-- Insert in edit box
			editbox:Insert("[Pacman: " .. pkg.id .. " - " .. share_keys[uuid] .. "]")
		end
	end
	
	-- Check a share key validity
	function Updater:CheckShareKey(pkg, key)
		return share_keys[pkg.uuid] == key
	end
end


-------------------------------------------------------------------------------
-- Chat messages
-------------------------------------------------------------------------------

do
	local function pacman_chat_filter(_, event, msg, player, l, cs, t, flag, channelId, ...)
		if flag == "GM" or flag == "DEV" or (event == "CHAT_MSG_CHANNEL" and type(channelId) == "number" and channelId > 0) then
			return
		end

		local new_msg = ""
		local remaining = msg
		local done = false

		repeat
			local start, finish, package_id, share_key = remaining:find("%[Pacman: ([^%]%|]+) %- ([^%]%|]+)%]")
			if package_id and share_key then
				package_id = package_id:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
				share_key = share_key:gsub("|c[Ff][Ff]......", ""):gsub("|r", "")
				new_msg = new_msg .. remaining:sub(1, start - 1)
				new_msg = new_msg .. ("|cff64b4ff|Hpacman:%s:%s:%s|h[Pacman: %s]|h|r"):format(share_key, player, package_id, package_id)
				remaining = remaining:sub(finish + 1);
			else
				done = true
			end
		until done
		
		new_msg = new_msg .. remaining

		if new_msg ~= "" then
			return false, new_msg, player, l, cs, t, flag, channelId, ...
		end
	end

	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_CONVERSATION", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", pacman_chat_filter)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", pacman_chat_filter)

	local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
	function ItemRefTooltip:SetHyperlink(link, ...)
		if link and link:sub(1, 6) == "pacman" then
			return
		end
		return OriginalSetHyperlink(self, link, ...)
	end

	local OriginalHandleModifiedItemClick = HandleModifiedItemClick
	function HandleModifiedItemClick(link, ...)
		if link and link:find("|Hpacman") then
			return
		end
		return OriginalHandleModifiedItemClick(link, ...)
	end
	
	hooksecurefunc("ChatFrame_OnHyperlinkShow", function(self, link, text, button)
		if link:sub(1, 6) == "pacman" then
			local _, share_key, player, id = strsplit(":", link, 4)
			if share_key and player and id then
				Updater:RequestPackage(id, player, share_key)
			else
				printf("This link does not seem to be a valid Pacman link.")
			end
		end
	end)
end

-------------------------------------------------------------------------------
-- Intra-Messaging
-------------------------------------------------------------------------------

do
	local listeners = {}
	
	function Updater:Listen(event, fn)
		listeners[event] = fn
	end
	
	function Updater:ClearListeners()
		wipe(listeners)
	end
	
	function Updater:Notify(event, ...)
		if listeners[event] then
			listeners[event](...)
		end
	end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

do
	local window
	local container
	local status = {}
	
	-- Dialog queue
	local queue = {}
	
	-- Create a text label
	local function CreateLabel(text)
		local label = AceGUI:Create("Label")
		label:SetText(text)
		label:SetFullWidth(true)
		
		local old_ww = label.label:CanWordWrap()
		local old_nsw = label.label:CanNonSpaceWrap()
		
		label.label:SetWordWrap(true)
		label.label:SetNonSpaceWrap(true)
		
		label:SetCallback("OnRelease", function()
			label.label:SetWordWrap(old_ww)
			label.label:SetNonSpaceWrap(old_nsw)
		end)
		
		return label
	end
	
	local function ContainerHeight(container)
		local height = 0
		for _, child in ipairs(container.obj.children) do
			local frame = child.frame
			local fheight = frame.height or frame:GetHeight()
			height = height + fheight
		end
		return height
	end
	
	-- Resize the dialog window
	function Updater:Layout()
		container:DoLayout()
		local height = ContainerHeight(container.frame)
		window:SetHeight(height + 57 - 10)
	end
	
	-- Open the dialog window
	function Updater:Open(display, ...)
		-- Create window if necessary
		if not window then
			window = AceGUI:Create("Window")
			window:SetStatusTable(status)
			window:EnableResize(false)
			window:SetWidth(350)
			
			window:SetCallback("OnClose", function()
				window:Release()
				window = nil
				ObjectiveTrackerFrame:Show()
				self:Flush()
			end)
			
			container = AceGUI:Create("SimpleGroup")
			container:SetAutoAdjustHeight(true)
			container:SetFullWidth(true)
			container:SetLayout("list")
			window:AddChild(container)
		
			window:ClearAllPoints()
			window:SetPoint("TOPRIGHT", ObjectiveTrackerFrame)
			ObjectiveTrackerFrame:Hide()
		else
			container:ReleaseChildren()
		end
		
		-- Construct title
		local function add_title(id, sender)
			local id_label = CreateLabel(id)
			id_label:SetFontObject(GameFontHighlightLarge)
			id_label:SetColor(0.39, 0.70, 1)
			container:AddChild(id_label)
			
			local sender_label = CreateLabel(("|cffffd200From: |r%s\n"):format(sender))
			sender_label:SetFontObject(GameFontHighlight)
			container:AddChild(sender_label)
		end
		
		local function add_text(text, font, cont)
			if not cont then cont = container end
			if not font then font = GameFontHighlight end
			
			local text_label = CreateLabel(text)
			text_label:SetFontObject(font)
			cont:AddChild(text_label)	
			
			return text_label
		end
		
		local function add_buttons(buttons)
			local actions = AceGUI:Create("SimpleGroup")
			actions:SetLayout("flow")
			actions:SetFullWidth(true)
			container:AddChild(actions)
			
			for _, button in ipairs(buttons) do
				local btn = AceGUI:Create("Button")
				btn:SetText(button[1])
				btn:SetWidth(100)
				actions:AddChild(btn)
				
				if button[2] then
					btn:SetCallback("OnClick", button[2])
				else
					btn:SetDisabled(true)
				end
			end
		end
		
		-----------------------------------------------------------------------
		-- Request Package data, then import 
		-----------------------------------------------------------------------
		if display == "request" then
			local id, sender, do_request = ...
			window:SetTitle("Loading package...")
			
			add_title(id, sender)
			add_text("|cffabd473Loading package informations...\n")
			add_buttons({
				{ "Cancel", function()
					self:Flush()
				end	}
			})
			
			do_request()
		
		-----------------------------------------------------------------------
		-- Package import or upgrade
		-----------------------------------------------------------------------
		elseif display == "import" or display == "import_pkg" then
			local meta, sender, do_import = ...
			
			local is_push = display == "import_pkg"
			local upgrade = Store:Get(meta.uuid)
			local useless = upgrade and meta.revision <= upgrade.revision
			
			if upgrade then
				window:SetTitle("Upgrade package")
			else
				window:SetTitle("Import package")
			end
			
			add_title(meta.id, sender)
			
			if not is_push then
				add_text(meta.desc:trim() .. "\n")
			end
			
			if upgrade and not useless then
				add_text("|cffabd473An update for this package is available.\n")
			end
			
			add_text(("|cffffd200Author: |r%s"):format(meta.author))
			add_text(("|cffffd200Revision: |r%s |cffcccccc(%s)"):format(meta.revision, meta.revision_date))
			if not is_push then
				add_text(("|cffffd200Size: |r%s\n"):format(FS:FormatNumber(meta.size, 1) .. "B"))
			else
				add_text(" ")
			end
			
			local enable, push
			if not upgrade then
				enable = AceGUI:Create("CheckBox")
				enable:SetLabel("Enable package")
				enable:SetFullWidth(true)
				enable:SetValue(true)
				container:AddChild(enable)
				add_text("|cffccccccThis package will be enabled once downloaded.\n", GameFontHighlightSmall)
			
				push = AceGUI:Create("CheckBox")
				push:SetLabel("Allow push-updates")
				push:SetFullWidth(true)
				push:SetValue(true)
				container:AddChild(push)
				add_text("|cffccccccYou will be able to receive push-updates for this package.\n", GameFontHighlightSmall)
			end
			
			local trust
			if not useless then
				trust = AceGUI:Create("CheckBox")
				trust:SetLabel("Trust this player")
				trust:SetFullWidth(true)
				container:AddChild(trust)
				add_text("|cffccccccYou will not be prompted again for updates to this package.\n", GameFontHighlightSmall)
				
				if Updater:IsTrusted(meta.uuid, sender) then
					trust:SetValue(true)
				end
			end
			
			local buttons = {}
			
			if useless then
				add_text("|cffabd473You already have latest version of this package.\n")
			elseif upgrade then
				table.insert(buttons, { "Upgrade", function() do_import(nil, nil, trust:GetValue()) end })
			else
				table.insert(buttons, { "Import", function() do_import(enable:GetValue(), push:GetValue(), trust:GetValue()) end })
			end

			table.insert(buttons, { (useless and "Close" or "Cancel"), function()
				self:Flush()
			end })
			
			add_buttons(buttons)
			
		-----------------------------------------------------------------------
		-- Package import or upgrade
		-----------------------------------------------------------------------
		elseif display == "download" then
			local id, sender, total = ...
			window:SetTitle("Downloading package")
			
			add_title(id, sender)
			
			local progress = CreateLabel("|cffabd473Downloading...\n")
			progress:SetFontObject(font)
			container:AddChild(progress)	
			
			self:Listen("DOWNLOAD_PROGRESS", function(bytes, total)
				progress:SetText(("%s |cffabd473/ %s\n"):format(bytes, total))
			end)
			
			add_buttons({ 
				{ "Cancel", function()
					self:Flush()
				end }
			})
			
		-----------------------------------------------------------------------
		-- Updater window
		-----------------------------------------------------------------------
		elseif display == "updater" then
			local arg = ...
			window:SetTitle("Pacman Updater")
			
			local pkg = Store:Get(arg)
			local shareable = pkg and (pkg.flags.Shareable or pkg.author_key == FS:PlayerKey())
			local select_tab
			
			-- Package selector
			do
				local list = {}
				local order = {}
				
				for uuid, pkg in Store:Packages() do
					list[uuid] = pkg.id
					order[#order + 1] = uuid
				end
				
				table.sort(order, function(a, b)
					return list[a] < list[b]
				end)
				
				pkg_select = AceGUI:Create("Dropdown")
				pkg_select:SetLabel("Package")
				pkg_select:SetFullWidth(true)
				pkg_select:SetList(list, order)
				container:AddChild(pkg_select)
				
				if pkg then
					pkg_select:SetValue(pkg.uuid)
				end
				
				pkg_select:SetCallback("OnValueChanged", function(_, _, uuid)
					pkg = Store:Get(uuid)
					select_tab("search")
				end)
			end
			
			-- Tabs selector
			do
				local tabs = AceGUI:Create("TabGroup")
				tabs:SetFullWidth(true)
				tabs:SetLayout("List")
				container:AddChild(tabs)
				
				function select_tab(tab)
					tabs:SetTabs({
						{ value = "search", text = "Search update" },
						{ value = "push", text = "Push update", disabled = not pkg or not IsInGroup() }
					})
					tabs:SelectTab(tab)
				end
				
				tabs:SetCallback("OnGroupSelected", function(_, _, action)
					tabs:ReleaseChildren()
					
					local function layout()
						tabs:DoLayout()
						self:Layout()
					end
					
					local listc, list, placeholder
					local function init_list(loading)
						tabs:ReleaseChildren()
						
						listc = AceGUI:Create("SimpleGroup")
						listc:SetFullWidth(true)
						listc:SetLayout("Fill")
						listc:SetHeight(300)
						tabs:AddChild(listc)
						
						list = AceGUI:Create("ScrollFrame")
						list:SetLayout("List")
						listc:AddChild(list)
						
						add_text("\n|cffabd473".. loading .. "\n", nil, list)
						placeholder = true
					end
					
					local function push_result(name, rev, action, enabled, cb)
						if placeholder then
							list:ReleaseChildren()
							add_text(" ", nil, list)
							placeholder = false
						end
						
						local row = AceGUI:Create("SimpleGroup")
						row:SetFullWidth(true)
						row:SetAutoAdjustHeight(true)
						
						add_text(name, nil, row)
						add_text(("|cffffd200Revision: |r%s\n"):format(rev), nil, row)
						
						row:DoLayout()
						row:PauseLayout()
						
						local btn = AceGUI:Create("Button")
						btn:SetText(action)
						btn:SetDisabled(not enabled)
						btn:SetWidth(100)
						
						row:AddChild(btn)
						btn:SetPoint("TOPRIGHT", row.frame, "TOPRIGHT", 0, -2)
						
						btn:SetCallback("OnClick", function()
							btn:SetDisabled(true)
							cb()
						end)
						
						list:AddChild(row)
						return btn
					end
					
					local function replace_placeholder(text)
						if placeholder then
							list:ReleaseChildren()
							add_text("\n|cffff7d0a".. text .. "\n", nil, list)
						end
					end
					
					local function add_button(text, cb)
						local btn = AceGUI:Create("Button")
						btn:SetText(text)
						btn:SetFullWidth(true)
						btn:SetCallback("OnClick", function()
							btn:SetDisabled(true)
							cb()
						end)
						tabs:AddChild(btn)
						return btn
					end
					
					if action == "search" then
						local function search_btn()
							return add_button("Search", function()
								init_list("Searching...")
								
								local btn = search_btn()
								btn:SetDisabled(true)
								
								local timer = C_Timer.NewTimer(5, function()
									replace_placeholder("No updates found...")
									btn:SetDisabled(false)
								end)
								
								local senders = {}
								self:Listen("SEARCH_RESULT", function(uuid, sender, rev, pullable)
									if pkg.uuid == uuid and not senders[sender] then
										senders[sender] = true
										push_result(sender, rev, "Pull", pullable, function()
											Updater:RequestPackage(pkg.uuid, sender)
											Updater:Flush()
										end)
									end
								end)
								
								local search_obj = {
									search = pkg.uuid,
									revision = pkg.revision
								}
								
								if IsInGuild() then Updater:Send(search_obj, "GUILD") end
								if IsInGroup() then Updater:Send(search_obj, "RAID") end
								
								btn:SetCallback("OnRelease", function()
									timer:Cancel()
								end)
								
								layout()
							end)
						end
						
						add_text("\n\n\n\nSearch an update to this package.\n", nil, tabs)
						local btn = search_btn()
						add_text("\n\n", nil, tabs)
						
						if not pkg then btn:SetDisabled(true) end
					elseif action == "push" then
						local function push_btn()
							return add_button("Scan", function()
								pkg = Store:Get(pkg.uuid)
								init_list("Scanning...")
								
								local btns = {}
								local push_all
								push_all = add_button("Push to all", function()
									for _, btn in ipairs(btns) do
										btn:SetDisabled(true)
									end
									push_all:SetDisabled(true)
									Updater:Send({ push = Store:Export(pkg) }, "RAID")
								end)
								push_all:SetDisabled(true)
								
								local btn = push_btn()
								btn:SetDisabled(true)
								
								local timer = C_Timer.NewTimer(5, function()
									replace_placeholder("No results...")
									btn:SetDisabled(false)
								end)
								
								local senders = {}
								self:Listen("PROBE_RESULT", function(uuid, sender, rev, enabled, pushable)
									if pkg.uuid == uuid and not senders[sender] then
										senders[sender] = true
										
										if rev >= pkg.revision or not shareable then pushable = false end
										
										if not enabled then
											rev = rev .. " |cff999999(Disabled)"
										end
										
										local btn = push_result(sender, rev, "Push", pushable, function()
											Updater:Send({ push = Store:Export(pkg) }, sender)
										end)
										
										if pushable then
											table.insert(btns, btn)
											push_all:SetDisabled(false)
										end
									end
								end)
								
								--local probe_obj = { probe = pkg.uuid }
								--if IsInGuild() then Updater:Send(probe_obj, "GUILD") end
								if IsInGroup() then Updater:Send({ probe = pkg.uuid }, "RAID") end
								
								btn:SetCallback("OnRelease", function()
									timer:Cancel()
								end)
								
								layout()
							end)
						end
						
						add_text("\n\n\n\nPush an update for this package.\n", nil, tabs)
						local btn = push_btn()
						add_text("\n\n", nil, tabs)
						
						if not pkg then btn:SetDisabled(true) end
					end
					
					layout()
				end)
				
				select_tab("search")
			end
			
			add_buttons({ 
				{ "Close", function()
					self:Flush()
				end }
			})
		end
		
		self:Layout()
	end
	
	function Updater:Flush()
		self:ClearListeners()
		if #queue > 0 then
			local args = table.remove(queue, 1)
			self:Open(unpack(args))
		elseif window then
			window:Release()
			window = nil
			ObjectiveTrackerFrame:Show()
		end
	end
	
	function Updater:Queue(...)
		table.insert(queue, {...})
		if not window then
			self:Flush()
		end
	end
end

-------------------------------------------------------------------------------
-- Actions
-------------------------------------------------------------------------------

function Updater:RequestPackage(id, from, key)
	local pkg = Store:Get(id)
	local display_id = pkg and pkg.id or id
	Updater:Queue("request", display_id, from, function()
		-- Request metadata informations
		self:Send({ request = id, key = key }, from)
		
		-- Listen for response
		self:Listen("RECEIVED_METADATA", function(metadata, sender)
			if (metadata.id:lower() == id:lower() or metadata.uuid == id)
			and Ambiguate(sender, "none") == Ambiguate(from , "none") then
				Updater:Open("import", metadata, sender, function(enable, push, trust)
					self:Send({ download = metadata.uuid, key = key }, from)
					Updater:Open("download", metadata.id, sender, metadata.size)
					self:Listen("PACKAGE_DOWNLOADED", function(pkg)
						if pkg.uuid == metadata.uuid then
							if Updater:Upgrade(pkg) then
								local status = Store:Status(pkg)
								if enable then
									Store:EnablePackage(pkg)
								end
								status.global.push = push or false
								status.global.trusted[sender] = trust or nil
							end
							Updater:Flush()
						end
					end)
				end)
			end
		end)
	end)
end

-- Upgrade or Install a package
function Updater:Upgrade(pkg, old)
	if Store:IsValid(pkg) then
		-- Fetch old if not given
		if not old then
			old = Store:Get(pkg.uuid)
		end
		
		-- Keep customized ID
		if old then
			pkg.id = old.id
		end
		
		-- Perform Store update
		Store:UpdatePackage(pkg)
		
		if old then
			printf("The package '%s' was upgraded to revision %s.", pkg.id, pkg.revision)
			if not old.flags.Reloadable then
				printf("You need to reload your interface to apply the upgrade.")
			end
		else
			printf("The package '%s' was successfully installed.", pkg.id)
		end
		
		return true
	end
	return false
end

function Updater:IsShareable(pkg, key)
	if not pkg then return false end
	
	local status = Store:Status(pkg)
	if not status then return false end
	
	return pkg.flags.Pullable or (
		(pkg.flags.Shareable or pkg.author_key == FS:PlayerKey())
		and Updater:CheckShareKey(pkg, key)
	)
end

function Updater:IsTrusted(pkg, player)
	if not pkg then return false end
	if type(pkg) == "string" then pkg = { uuid = pkg } end
	
	local status = Store:Status(pkg)
	if not status then return false end
	
	return status.global.trusted[player]
end

-------------------------------------------------------------------------------
-- Network messages
-------------------------------------------------------------------------------

-- Send Pacman message
function Updater:Send(...)
	return FS:Send("PACMAN", ...)
end

-- Receive Pacman message
function Updater:OnNetMessage(_, data, channel, sender)
	if type(data) ~= "table" then return end
	
	---------------------------------------------------------------------------
	-- Metadata response
	---------------------------------------------------------------------------
	if data.metadata then
		-- Received Package metadata from a request
		self:Notify("RECEIVED_METADATA", data.metadata, sender)
		
	---------------------------------------------------------------------------
	-- Metadata request
	---------------------------------------------------------------------------
	elseif data.request then
		-- Received a metadata request
		local pkg = Store:Get(data.request)
		if self:IsShareable(pkg, data.key) then
			self:Send({ metadata = Store:Metadata(pkg) }, sender)
		end
		
	---------------------------------------------------------------------------
	-- Download request
	---------------------------------------------------------------------------
	elseif data.download then
		-- Received a download request
		local pkg = Store:Get(data.download)
		if self:IsShareable(pkg, data.key) then
			self:Send({ pkg = Store:Export(pkg) }, sender, "BULK", function(_, bytes, total)
				self:Send({ progress = bytes, total = total }, sender)
			end)
		end
		
	---------------------------------------------------------------------------
	-- Download received
	---------------------------------------------------------------------------
	elseif data.pkg then
		if Store:IsValid(data.pkg) then
			self:Notify("PACKAGE_DOWNLOADED", data.pkg)
		end
	
	---------------------------------------------------------------------------
	-- Download progress
	---------------------------------------------------------------------------
	elseif data.progress then
		self:Notify("DOWNLOAD_PROGRESS", data.progress, data.total)
		
	---------------------------------------------------------------------------
	-- Package probing request
	---------------------------------------------------------------------------
	elseif data.probe then
		local pkg = Store:Get(data.probe)
		if pkg then
			local status = Store:Status(pkg)
			if not status then return end
			
			self:Send({
				probe_result = pkg.uuid,
				revision = pkg.revision,
				enabled = status.profile.enabled,
				push = status.global.push
			}, sender)
		end
		
	---------------------------------------------------------------------------
	-- Package probing response
	---------------------------------------------------------------------------
	elseif data.probe_result then
		self:Notify("PROBE_RESULT", data.probe_result, sender, data.revision, data.enabled, data.push)
		
	---------------------------------------------------------------------------
	-- Package search request
	---------------------------------------------------------------------------
	elseif data.search and data.revision then
		local pkg = Store:Get(data.search)
		if pkg
		and pkg.revision > data.revision
		and (
			pkg.flags.Pullable
			or pkg.flags.Shareable
			or pkg.author_key == FS:PlayerKey()
		) then
			self:Send({
				search_result = pkg.uuid,
				revision = pkg.revision,
				pullable = pkg.flags.Pullable
			}, sender)
		end
		
	---------------------------------------------------------------------------
	-- Package search response
	---------------------------------------------------------------------------
	elseif data.search_result then
		self:Notify("SEARCH_RESULT", data.search_result, sender, data.revision, data.pullable)
	
	---------------------------------------------------------------------------
	-- Push-update offer
	---------------------------------------------------------------------------
	elseif data.push then
		if not Store:IsValid(data.push) then return end
		
		-- Fetch current package and status table
		local pkg = Store:Get(data.push.uuid)
		if not pkg then return end
		
		local status = Store:Status(pkg)
		
		-- Check upgrade and allowed
		if pkg.revision >= data.push.revision 
		or not status.global.push then
			return
		end
		
		if Updater:IsTrusted(pkg, sender) then
			Updater:Upgrade(data.push, pkg)
			return
		else
			Updater:Open("import_pkg", data.push, sender, function(enable, push, trust)
				Updater:Upgrade(data.push, pkg)
				if trust then
					status.global.trusted[sender] = true
				end
				Updater:Flush()
			end)
		end
	end
end
