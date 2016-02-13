local _, FS = ...
local Pacman = FS:RegisterModule("Pacman")

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")

LibStub("AceSerializer-3.0"):Embed(Pacman)

local Store

-------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------

function Pacman.printf(str, ...)
	print(("|cffffd200" .. str):format(...))
end

-------------------------------------------------------------------------------
-- Pacman config DB
-------------------------------------------------------------------------------

local pacman_default = {
	profile = {
		pkg = {
			["*"] = {
				db = {},
				enabled = false
			}
		}
	},
	global = {
		pkg = {
			["*"] = {
				db = {},
				push = false,
				trusted = {}
			}
		}
	}
}

local pacman_config = {
	title = {
		type = "description",
		name = "|cff64b4ffPacman",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "User-script package manager.\n",
		fontSize = "medium",
		order = 1
	},
	enable = {
		type = "toggle",
		name = "Enable",
		width = "full",
		get = function()
			return Pacman.settings.enable
		end,
		set = function(_, value)
			Pacman.settings.enable = value
			if value then
				Pacman:Enable()
			else
				Pacman:Disable()
			end
		end,
		order = 5
	},
}

-------------------------------------------------------------------------------
-- Sub-modules
-------------------------------------------------------------------------------

-- Construct the Store object
function Pacman:ConstructStore()
	if Store then return end
	Store = {}
	return Store
end

-- Create a new submodule
function Pacman:SubModule(name, ...)
	local submod = self:NewModule(name, ...)
	self[name] = submod
	return submod, Store
end

-------------------------------------------------------------------------------
-- Pacman Main GUI
-------------------------------------------------------------------------------

local pacman_installed_base = {
	title = {
		type = "description",
		name = "|cff64b4ffInstalled package",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "This tab displays the list of installed package.",
		fontSize = "medium",
		order = 1
	}
}

local pacman_installed = {
	name = "Installed",
	desc = "Installed Packages",
	order = 1,
	type = "group"
}

local pacman_updates = {
	name = "Updates",
	order = 2,
	type = "group",
	args = {
		title = {
			type = "description",
			name = "|cff64b4ffAvailable updates",
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = "Manage and update your imported packages.",
			fontSize = "medium",
			order = 1
		}
	}
}

local pacman_new = {
	name = "Create package",
	desc = "Create a newp package",
	order = 3,
	type = "group",
	args = {
		title = {
			type = "description",
			name = "|cff64b4ffCreate a new package",
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = "\n",
			order = 1
		},
		identifier = {
			order = 2,
			name = "Package identifier",
			type = "input",
			width = "full",
			validate = function(_, id)
				if not Store:Get(id) then return true end
				return "A package with this ID already exists."
			end,
			set = function(_, id) Store:CreatePackage(id) end
		},
		identifier_d = {
			order = 3,
			name = "Example: |cffffd200Blash.T18.Archimonde.WroughtChaos",
			type = "description"
		},
	}
}

local pacman_options = {
	name = "Options",
	order = 10,
	type = "group",
	args = {
		
	}
}

local pacman_gui = {
	title = {
			type = "description",
			name = " |cff64b4ffPacman",
			fontSize = "large",
			order = 0
	},
	desc = {
		type = "description",
		name = " Lua package manager\n",
		fontSize = "medium",
		order = 1
	},
	packages = pacman_installed,
	--updates = pacman_updates,
	new = pacman_new,
	--options = pacman_options
}

local pacman_fs_opts = {
	title = {
		type = "description",
		name = "|cff64b4ffPacman",
		fontSize = "large",
		order = 0
	},
	desc = {
		type = "description",
		name = "Lua package manager\n",
		fontSize = "medium",
		order = 1
	},
	notice = {
		type = "description",
		name = "|cff999999This module is exceptionally complex and has a dedicated configuration interface.\n",
		order = 6
	},
	--packages = pacman_installed,
	--updates = pacman_updates,
	--new = pacman_new,
	--options = pacman_options,
	ref = {
		type = "header",
		name = "Module reference",
		order = 1000
	},
	docs = FS.Config:MakeDoc("Available chat commands", 2000, {
		{"", "Open Pacman standalone interface.\nAlso available as /pm."},
		{"list", "List installed package status."},
		{"update", "Open the package updater window."},
		{"enable|disable <package-id>", "Enable or disable the given package."},
		{"view|edit <package-id>", "Open the package editor to view or edit the given package."},
	}, "/pacman ")
}

-------------------------------------------------------------------------------
-- Life-cycle events
-------------------------------------------------------------------------------

function Pacman:OnInitialize()
	-- Settings
	self.db = FS.db:RegisterNamespace("Pacman", pacman_default)
	self.settings = self.db.profile
	
	-- Initialize Store
	Store:OnInitialize()
	
	-- Profile switch
	pacman_gui.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(FS.db)
	
	-- Register options table
	AceConfig:RegisterOptionsTable("Pacman", { type = "group", args = pacman_gui })
	FS.Config:Register("Pacman", pacman_fs_opts)
end

function Pacman:OnEnable()
	self:RegisterMessage("PACMAN_STORE_UPDATED", "UpdatePackageList")
	Store:OnEnable()
	
	-- TODO: Remove
	Pacman.Store = Store
end

-------------------------------------------------------------------------------
-- Package list
-------------------------------------------------------------------------------

local function create_package_gui(pkg, valid)
	local own = pkg.author_key == FS:PlayerKey()
	
	if not valid then
		return {
			title = {
				type = "description",
				name = "|cffff0000" .. pkg.id,
				fontSize = "large",
				order = 0
			},
			desc = {
				type = "description",
				name = "\nThis package is corrupted and cannot be loaded.\n",
				fontSize = "medium",
				order = 1
			},
			delete = {
				type = "execute",
				name = "Delete",
				desc = "Remove this package from your game.",
				order = 10,
				width = "half",
				confirm = true,
				confirmText = "The package '|cff64b4ff" .. pkg.id .. "|r' will be removed",
				func = function() Store:RemovePackage(pkg) end
			}
		}
	end
	
	local status = Store:Status(pkg)
	local o
	o = {
		title = {
			type = "description",
			name = "|cff64b4ff" .. pkg.id,
			fontSize = "large",
			order = 0
		},
		desc = {
			type = "description",
			name = pkg.desc .. "\n",
			fontSize = "medium",
			order = 1
		},
		enabled = {
			type = "toggle",
			name = "Enable package",
			desc = "This package will be loaded when you enter the world.",
			order = 2,
			get = function() return Store:IsEnabled(pkg) end,
			set = function(_, s)
				if s then
					Store:EnablePackage(pkg)
				else
					Store:DisablePackage(pkg)
				end
			end
		},
		auto_update = {
			type = "toggle",
			name = "Enable push-updates",
			desc = "Push-updates will be enabled for this package.",
			order = 3,
			get = function() return status.global.push end,
			set = function(_, s) status.global.push = s end
		},
		--[[enabled_desc = {
			type = "description",
			name = "|cff999999This package will be automatically loaded when you launch the game.\n" ..
					"Note that it may use lazy loading to defer actual loading until needed.\n",
			order = 4
		},]]
		meta = {
			type = "group",
			inline = true,
			name = "Metadata",
			order = 20,
			args = {
				author = {
					type = "description",
					name = "|cffffd200Author|r\n" .. pkg.author,
					order = 10
				},
				revision = {
					type = "description",
					name = "\n|cffffd200Revision|r\n" .. pkg.revision .. "  @  " .. pkg.revision_date,
					order = 15
				},
				flags = {
					type = "description",
					name = function()
						local flags = ""
						for flag in pairs(pkg.flags) do
							if flags == "" then
								flags = flag
							else
								flags = flags .. ", " .. flag
							end
						end
						if flags == "" then
							flags = "None"
						end
						return "\n|cffffd200Flags|r\n" .. flags
					end,
					order = 18
				},
				--[[editable = {
					type = "description",
					name = "\n|cffffd200Editable|r\n" .. (own and "Yes" or "No"),
					order = 20
				},]]
				spacing = {
					type = "description",
					name = "",
					fontSize = "small",
					order = 25
				}
			}
		},
		operations = {
			type = "group",
			inline = true,
			name = "Operations",
			order = 11,
			args = {
				edit = {
					type = "execute",
					name = "Edit",
					desc = "Open the package editor to view and edit its content.",
					order = 0,
					width = "half",
					func = function() Pacman.Editor:Open(pkg, not own, pkg.id) end
				},
				share = {
					type = "execute",
					name = "Share",
					desc = "Link this package to other players.",
					order = 2,
					width = "half",
					hidden = not pkg.flags.Shareable and not own,
					func = function() Pacman.Updater:SharePackage(pkg) end
				},
				update = {
					type = "execute",
					name = "Update",
					desc = "Open the update manager to update, push or view other players' package version.",
					order = 3,
					width = "half",
					func = function() Pacman.Updater:Queue("updater", pkg.id) end
				},
				remove = {
					type = "execute",
					name = "Remove",
					desc = "Remove this package from your game.",
					order = 10,
					width = "half",
					confirm = true,
					confirmText = "The package '|cff64b4ff" .. pkg.id .. "|r' will be removed",
					func = function() Store:RemovePackage(pkg) end
				},
			}
		},
		trusted = {
			type = "group",
			inline = true,
			name = "Trusted players",
			order = 25,
			args = {
				list = {
					type = "description",
					name = function()
						local trusteds = ""
						for trusted in pairs(status.global.trusted) do
							if trusteds == "" then
								trusteds = trusted
							else
								trusteds = trusteds .. ", " .. trusted
							end
						end
						if trusteds == "" then
							trusteds = "None"
						end
						return trusteds .. "\n"
					end,
					order = 19
				},
				clear_trusted = {
					type = "execute",
					name = "Clear",
					desc = "Clear the list of trusted players.",
					order = 20,
					width = "half",
					func = function() wipe(status.global.trusted) end
				},
			}
		},
		clone = {
			type = "group",
			inline = true,
			name = "Clone this package",
			order = 30,
			hidden = not own and pkg.flags.Unclonable,
			args = {
				desc = {
					type = "description",
					name =
						"You can clone this package into a new one, allowing you to edit the package even if you are not the original author. " ..
						"However, you will no longer be able to receive updates for this package.\n",
					order = 1
				},
				revision = {
					type = "input",
					name = "New package id",
					width = "full",
					set = function(_, id) Store:ClonePackage(pkg, id) end,
					order = 15
				},
				spacing = {
					type = "description",
					name = "",
					fontSize = "small",
					order = 25
				}
			}
		},
		uuid = {
			type = "group",
			inline = true,
			name = "Package UUID",
			order = 100,
			args = {
				id = {
					type = "input",
					name = "",
					get = function() return pkg.uuid end,
					width = "full",
					order = 20
				}
			}
		}
	}
	
	if pkg.flags.Configurable and status.loaded then
		local env = Pacman.Sandbox:GetEnvironment(pkg)
		local conf_table = env.locals._config
		if conf_table then
			o.pkg_conf = {
				type = "group",
				inline = true,
				name = "Package configuration",
				order = 9,
				args = conf_table
			}
			--[[o.pkg_conf_spacing = {
				type = "description",
				name = " ",
				order = 10
			}]]
		end
	end
	
	return o
end

function Pacman:UpdatePackageList()
	local pkgs = {}
	for k, v in pairs(pacman_installed_base) do pkgs[k] = v end
	
	local suffix = 0
	local function push(node, key, pkg, prefix)
		local head, tail = key:match("([^.]+)%.(.+)")
		if head then
			local sub_node = node[head]
			if not sub_node then
				sub_node = {
					type = "group",
					name = head,
					desc = (prefix .. head):lower(),
					args = {}
				}
				node[head] = sub_node
			end
			push(sub_node.args, tail, pkg, prefix .. head .. ".")
		else
			suffix = suffix + 1
			
			local valid = Store:IsValid(pkg)
			local color = "|cff999999"
			if not valid then
				color = "|cffff0000"
			elseif Store:IsEnabled(pkg) then
				color = "|cff64b4ff"
			end
			
			node[key .. suffix] = {
				type = "group",
				name = color .. key,
				desc = (prefix .. key):lower(),
				args = create_package_gui(pkg, valid)
			}
		end
	end
	
	for uuid, pkg in Store:Packages() do
		push(pkgs, pkg.id, pkg, "")
	end
	
	pacman_installed.args = pkgs
end

function Pacman:OpenGUI()
	self:UpdatePackageList()
	AceConfigDialog:Open("Pacman")
end
