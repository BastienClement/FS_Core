local _, FS = ...
local Pacman = FS:GetModule("Pacman")
local Editor, Store = Pacman:SubModule("Editor")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register("font", "Fira Mono Medium", "Interface\\Addons\\FS_Core\\media\\FiraMono-Medium.ttf")

local IndentationLib = IndentationLib

-------------------------------------------------------------------------------
-- Confirm dialog
-------------------------------------------------------------------------------

local function ConfirmPopup(message, func, func_else)
	if not StaticPopupDialogs["PACMAN_CONFIRM_DIALOG"] then
		StaticPopupDialogs["PACMAN_CONFIRM_DIALOG"] = {}
	end
	local t = StaticPopupDialogs["PACMAN_CONFIRM_DIALOG"]
	for k in pairs(t) do
		t[k] = nil
	end
	t.text = message
	t.button1 = "Yes"
	t.button2 = CANCEL
	t.preferredIndex = STATICPOPUP_NUMDIALOGS
	local dialog, oldstrata
	t.OnAccept = function()
		func()
		if dialog and oldstrata then
			dialog:SetFrameStrata(oldstrata)
		end
	end
	t.OnCancel = function()
		func_else()
		if dialog and oldstrata then
			dialog:SetFrameStrata(oldstrata)
		end
	end
	t.timeout = 0
	t.whileDead = 1
	t.hideOnEscape = 1

	dialog = StaticPopup_Show("PACMAN_CONFIRM_DIALOG")
	if dialog then
		oldstrata = dialog:GetFrameStrata()
		dialog:SetFrameStrata("TOOLTIP")
	end
end

-------------------------------------------------------------------------------
-- Editor
-------------------------------------------------------------------------------

local frame, tree
local dirty
local changed = {}
local pkg, orig_pkg, own
local reopen
local tree_backdrop, tree_backdrop_color, tree_backdrop_border_color
local tree_backdrop_altered = false
local in_package = false
local set_focus = false

local make_flag_toggle
do
	local order = 0
	function make_flag_toggle(flag, desc)
		local toggle = {
			type = "toggle",
			name = flag,
			desc = desc,
			order = order,
			--width = "full",
			disabled = function() return not own end,
			get = function() return pkg.flags[flag] ~= nil end,
			set = function(_, state)
				pkg.flags[flag] = state and true or nil
				dirty = true
			end
		}
		order = order + 1
		return toggle
	end
end

local package_properties = {
	type = "group",
	args = {
		title = {
			type = "description",
			name = function() return "Package: |cff64b4ff" .. pkg.id .. "\n" end,
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "group",
			inline = true,
			name = "Name and description",
			order = 1,
			args = {
				id = {
					type = "input",
					name = "Identifier",
					width = "full",
					order = 1,
					get = function() return pkg.id end,
					set = function(_, id)
						pkg.id = id
						orig_pkg.id = id
						Store:StoreUpdated()
					end
				},
				desc = {
					type = "input",
					name = "Description",
					width = "full",
					order = 2,
					multiline = true,
					disabled = function() return not own end,
					get = function() return pkg.desc end,
					set = function(_, desc)
						pkg.desc = desc
						dirty = true
					end
				},
				author = {
					type = "input",
					name = "Author",
					width = "full",
					order = 3,
					disabled = function() return not own end,
					get = function() return pkg.author end,
					set = function(_, author)
						pkg.author = author
						dirty = true
					end
				}
			}
		},
		flags = {
			type = "group",
			inline = true,
			name = "Flags",
			order = 2,
			args = {
				library = make_flag_toggle("Library", "This package is a function library for another package. It will not be loaded unless explicitly imported."),
				reloadable = make_flag_toggle("Reloadable", "This package can be reloaded without requiring an full UI reload."),
				pullable = make_flag_toggle("Pullable", "This package can be found and pulled from the package-search feature."),
				unclonable = make_flag_toggle("Unclonable", "This package cannot be cloned."),
				shareable = make_flag_toggle("Shareable", "Other players will be able to share this package."),
				opaque = make_flag_toggle("Opaque", "This package content will not be visible."),
				configurable = make_flag_toggle("Configurable", "This package offers configuration options."),
			}
		}
	}
}

AceConfig:RegisterOptionsTable("Pacman-Package", package_properties)

local function UpdatePackageTree()
	local t
	if own then
		t = {
			{
				value = "package",
				text = "Package",
				children = {}
			},
			{ value = "", text = "", disabled = true },
			{
				value = "new_file",
				text = "Create new file",
			},
			{ value = "", text = "", disabled = true },
			{
				value = "save_close",
				text = "Save & Close",
			},
			{
				value = "close",
				text = "Discard changes",
			},
		}
	else
		t = {
			{
				value = "package",
				text = "Package",
				children = {}
			},
			{ value = "", text = "", disabled = true },
			{
				value = "close_fast",
				text = "Close",
			},
		}
	end
	
	if own or not pkg.flags.Opaque then
		local files = t[1].children
		
		for key in pairs(pkg.files) do
			files[#files + 1] = {
				value = key,
				text = key
			}
		end
	
		table.sort(files, function(a, b)
			a, b = a.value, b.value
			if a == "main.lua" then
				return true
			elseif b == "main.lua" then
				return false
			else
				return a < b
			end
		end)
	else
		t[1].children = nil
	end
	
	tree:SetTree(t)
end

local function CreateTextEditor(file)
	local is_lua = file:match("%.lua$")
	local is_main = file == "main.lua"
	
	local editor = AceGUI:Create("MultiLineEditBox")
	editor.width = "fill"
	editor.height = "fill"
	editor:SetLabel("")
	editor:SetDisabled(not own)
	editor.editBox:SetTextColor(1, 1, 1)
	
	local old_font, old_font_size
	local fontPath = LSM:Fetch("font", "Fira Mono Medium")
	if fontPath then
		old_font, old_font_size = editor.editBox:GetFont()
		editor.editBox:SetFont(fontPath, 12)
	end
	
	local source = pkg.files[file]:trim():gsub("|", "||")
	editor:SetText(source .. "\n")
	
	if is_lua then
		IndentationLib.enable(editor.editBox, nil, 2)
	end
	
	local rename_file, delete_file, revert_file
	if not own then
		editor:DisableButton(true)
	else
		editor.button:Hide()
		
		-- Rename
		rename_file = AceGUI:Create("EditBox")
		rename_file.frame:SetParent(editor.frame)
		rename_file:SetPoint("BOTTOMLEFT", 0, 3)
		rename_file.frame:Show()
		rename_file:SetText(file)
		rename_file:SetDisabled(is_main or not own)
		rename_file:SetWidth(200)
		
		local should_set_focus = set_focus
		set_focus = false
		editor:SetUserData("setfocus", function()
			if should_set_focus then
				C_Timer.After(0.1, function()
					rename_file:SetFocus()
				end)
			end
		end)
		
		
		rename_file:SetCallback("OnEnterPressed", function(_, _, name)
			pkg.files[name] = pkg.files[file]
			pkg.files[file] = nil
			dirty = true
			UpdatePackageTree()
			tree:SelectByPath("package", name)
		end)
		
		-- Delete
		delete_file = AceGUI:Create("Button")
		delete_file.frame:SetParent(editor.frame)
		delete_file:SetPoint("BOTTOMRIGHT", -17, 3)
		delete_file.frame:Show()
		delete_file:SetText("Delete")
		delete_file:SetWidth(120)
		delete_file:SetDisabled(is_main)
		
		delete_file:SetCallback("OnClick", function()
			ConfirmPopup("Are you sure you want to delete this file?", function(...)
				pkg.files[file] = nil
				dirty = true
				UpdatePackageTree()
				tree:SelectByPath("package")
			end)
		end)
		
		-- Revert
		revert_file = AceGUI:Create("Button")
		revert_file.frame:SetParent(editor.frame)
		revert_file:SetPoint("RIGHT", delete_file.frame, "LEFT", -5, 0)
		revert_file:SetText("Revert")
		revert_file:SetWidth(120)
		revert_file:SetDisabled(not changed[file])
		
		if orig_pkg.files[file] then
			revert_file.frame:Show()
		end
		
		revert_file:SetCallback("OnClick", function()
			ConfirmPopup("Are you sure you want to revert this file to the previous revision?", function(...)
				if pkg.flags.Opaque then
					pkg.files[file] = Store:Decode(orig_pkg.files[file])
				else
					pkg.files[file] = orig_pkg.files[file]
				end
				changed[file] = nil
				tree:SelectByPath("package", file)
			end, function() end)
		end)
		
		
		editor:SetCallback("OnTextChanged", function(_, _, text)
			text = text:trim()
			if source ~= text:gsub("|", "||") then
				pkg.files[file] = text
				source = text
				dirty = true
				changed[file] = true
				revert_file:SetDisabled(false)
			end
		end)
	end
	
	editor:SetCallback("OnRelease", function()
		if is_lua then IndentationLib.disable(editor.editBox) end
		if old_font then editor.editBox:SetFont(old_font, old_font_size) end
		if own then
			editor.button:Show()
			rename_file:Release()
			delete_file:Release()
			revert_file:Release()
		end
	end)
	
	return editor
end

local function RestoreContentBackdrop()
	if not tree_backdrop_altered then return end
	tree.border:SetBackdrop(tree_backdrop)
	tree.border:SetBackdropColor(unpack(tree_backdrop_color))
	tree.border:SetBackdropBorderColor(unpack(tree_backdrop_border_color))
	tree_backdrop_altered = false
end

-- Click handler for item in the left tree
local function FileSelected(container, _, file)
	-- Clear the main view
	container:ReleaseChildren()
	if file ~= "package" then in_package = false end
	
	-- Take appropriate action
	if file == "new_file" then -- Creating a new file
		if not pkg.files[""] then
			pkg.files[""] = ""
			UpdatePackageTree()
		end
		set_focus = true
		tree:SelectByPath("package", "")
	elseif file == "save_close" then -- Close & Save editor content
		Editor:Close()
	elseif file == "close" then -- Close editor and discard changes made to the package
		RestoreContentBackdrop()
		-- Only ask for confirmation is the package was actually modified
		if dirty then
			ConfirmPopup("Changes made to the package will be lost forever! Are you sure?", function()
				Editor:Close(true)
			end, function()
				tree:SelectByPath("package")
			end)
		else
			Editor:Close(true)
		end
	elseif file == "close_fast" then -- Close without saving, used in read-only mode
		Editor:Close(true)
	elseif file == "package" then -- Package properties editor
		if not in_package then
			RestoreContentBackdrop()
			container:ResumeLayout()
			AceConfigDialog:Open("Pacman-Package", container)
			in_package = true
			tree:SelectByPath("package")
		else
			AceConfigDialog:Open("Pacman-Package", container)
		end
	else -- Edit a file
		local _, file = ("\001"):split(file)
		if file then
			local editor = CreateTextEditor(file)
			container:AddChild(editor)
			container:PauseLayout()
			
			editor:ClearAllPoints()
			editor:SetPoint("TOPLEFT", container.border, 0, 3.5)
			editor:SetPoint("BOTTOMRIGHT", container.border, -3, -3.5)
			
			if not tree_backdrop_altered then
				container.border:SetBackdrop(nil)
				tree_backdrop_altered = true
			end
			
			local setfocus = editor:GetUserData("setfocus")
			if setfocus then setfocus() end
		end
	end
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

-- Editor open
function Editor:Open(p, read_only, reopen_package)
	if not Store:IsValid(p) then
		print("|cffff7d0aPackage '" .. p.id .. "' is corrupted and cannot be edited.")
		return
	end

	-- Close old editor before opening this one
	if frame then frame:Release() end
	
	-- Close main Pacman frame
	AceConfigDialog:Close("Pacman")
	GameTooltip:Hide()
	
	-- Store package data
	orig_pkg = p
	pkg = FS:Clone(p)
	reopen = reopen_package
	in_package = false
	
	-- Init ownership and dirty flag
	own = not read_only and pkg.author_key == FS:PlayerKey() 
	dirty = false
	changed = {}
	
	-- Decode opaque package
	if pkg.flags.Opaque and own then
		for file, content in pairs(pkg.files) do
			pkg.files[file] = Store:Decode(content)
		end
	end
	
	-- Main window
	frame = AceGUI:Create("Window")
	frame:SetTitle("Package Editor")
	frame:SetWidth(1200)
	frame:SetHeight(675)
	frame:SetLayout("fill")
	
	-- Left tree
	tree = AceGUI:Create("TreeGroup")
	tree:EnableButtonTooltips(false)
	tree:SetLayout("fill")
	tree_backdrop = tree.border:GetBackdrop()
	tree_backdrop_color = { tree.border:GetBackdropColor() }
	tree_backdrop_border_color = { tree.border:GetBackdropBorderColor() }
	frame:AddChild(tree)
	
	-- Populate tree and open the main.lua file
	UpdatePackageTree()
	tree:SetCallback("OnGroupSelected", FileSelected)
	tree:SelectByPath("package")
	tree:SetCallback("OnRelease", function()
		RestoreContentBackdrop()
	end)
	
	-- Cleanup when editor window is closed
	frame:SetCallback("OnClose", function(widget)
		Editor:Close(true)
	end)
end

-- Editor cleanup
function Editor:Close(discard)
	-- No editor open
	if not frame then return end
	
	-- We need to save a new revision
	if dirty and not discard then
		pkg.revision = pkg.revision + 1
		pkg.revision_date = date()
		
		-- Encode Opaque package
		if pkg.flags.Opaque then
			for file, content in pairs(pkg.files) do
				pkg.files[file] = Store:Encode(content)
			end
		end
		
		Store:UpdatePackage(pkg)
	end
	
	-- Close window
	frame:Release()
	frame = nil
	
	-- We need to open the main GUI again
	if reopen then
		AceConfigDialog:Open("Pacman")
	end
end
