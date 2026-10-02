local ADDON_NAME = ...
local GRB = GuildRecruitmentBuddy
local L = GRB.L

local function GetOptions()
    local db = GRB.db.profile
    local invite = db.autoInvite
    return {
        type = "group",
        name = L["ADDON_NAME"],
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    minimap = {
                        type = "toggle",
                        name = L["Show minimap button"],
                        order = 2,
                        get = function() return not db.minimap.hide end,
                        set = function(_, value)
                            db.minimap.hide = not value
                            GRB:UpdateMinimapButton()
                        end,
                    },
                    discord = {
                        type = "input",
                        name = L["Discord link ({discord})"],
                        order = 3,
                        width = "full",
                        get = function() return db.discord end,
                        set = function(_, value) db.discord = strtrim(value or "") end,
                    },
                    cooldownDays = {
                        type = "range",
                        name = L["Whisper cooldown (days)"],
                        desc = L["How long to wait before the same player can be whispered again. 0 disables the cooldown."],
                        order = 5,
                        width = "full",
                        min = 0, max = 90, step = 1,
                        get = function() return db.cooldownDays end,
                        set = function(_, value) db.cooldownDays = value end,
                    },
                    maxWhispersPerMinute = {
                        type = "range",
                        name = L["Max whispers per minute"],
                        desc = L["Session rate limit for whispers sent through the addon."],
                        order = 6,
                        width = "full",
                        min = 1, max = 20, step = 1,
                        get = function() return db.maxWhispersPerMinute end,
                        set = function(_, value) db.maxWhispersPerMinute = value end,
                    },
                    guildName = {
                        type = "input",
                        name = L["Guild name override ({guild})"],
                        desc = L["Leave empty to use the name of your current guild."],
                        order = 4,
                        width = "full",
                        get = function() return db.guildName end,
                        set = function(_, value) db.guildName = strtrim(value or "") end,
                    },
                },
            },
            autoInvite = {
                type = "group",
                name = L["Auto invite (ginv)"],
                order = 2,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["A keyword whisper queues an invite request. Click Invite in the popup to send it."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable auto invite"],
                        order = 1,
                        width = "full",
                        get = function() return GRB:IsInviteEnabled() end,
                        set = function(_, value) GRB:SetInviteEnabled(value) end,
                    },
                    keywords = {
                        type = "input",
                        name = L["Keywords (comma separated)"],
                        desc = L["Matched as an exact word, case-insensitive."],
                        order = 2,
                        width = "full",
                        get = function() return invite.keywords end,
                        set = function(_, value) invite.keywords = strtrim(value or "") end,
                    },
                    minLevel = {
                        type = "range",
                        name = L["Minimum level (0 = off)"],
                        desc = L["Only applied when the level is known from the contacts; a whisper does not include it."],
                        order = 3,
                        width = "full",
                        min = 0, max = 60, step = 1,
                        get = function() return invite.minLevel end,
                        set = function(_, value) invite.minLevel = value end,
                    },
                    classes = {
                        type = "multiselect",
                        name = L["Allowed classes (none selected = all)"],
                        order = 4,
                        values = function()
                            local values = {}
                            for _, token in ipairs(GRB.AutoInvite.CLASSES) do
                                values[token] = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token
                            end
                            return values
                        end,
                        get = function(_, token) return invite.classes[token] or false end,
                        set = function(_, token, value) invite.classes[token] = value or nil end,
                    },
                    cooldownMinutes = {
                        type = "range",
                        name = L["Per-player cooldown (minutes)"],
                        desc = L["Repeated keywords from the same player are ignored for this long."],
                        order = 5,
                        width = "full",
                        min = 1, max = 60, step = 1,
                        get = function() return invite.cooldownMinutes end,
                        set = function(_, value) invite.cooldownMinutes = value end,
                    },
                    replyEnabled = {
                        type = "toggle",
                        name = L["Whisper the player when the invite is sent"],
                        order = 6,
                        width = "full",
                        get = function() return invite.replyEnabled end,
                        set = function(_, value) invite.replyEnabled = value end,
                    },
                    replyText = {
                        type = "input",
                        name = L["Reply text"],
                        desc = L["Placeholders: {name} {class} {level} {guild} {discord}"],
                        order = 7,
                        width = "full",
                        multiline = 3,
                        get = function() return invite.replyText end,
                        set = function(_, value) invite.replyText = value or "" end,
                    },
                },
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(GRB.db),
        },
    }
end

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local registry = LibStub("AceConfigRegistry-3.0")

local settingsContainer  -- AceGUI container holding the options while the Settings tab is shown
local SettingsTab = {}

function GRB:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions)
    self.blizOptionsFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, L["ADDON_NAME"])
end

-- /grb config: the options inside the main window
function GRB:OpenConfig()
    self.MainFrame:Open("Settings")
end

-- /grb options: the same options in Blizzard's Interface Options
function GRB:OpenBlizzardOptions()
    if InterfaceOptionsFrame_OpenToCategory then
        -- Called twice on purpose: the first call only opens the panel on the wrong category (known Blizzard bug)
        InterfaceOptionsFrame_OpenToCategory(self.blizOptionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.blizOptionsFrame)
    elseif Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(self.blizOptionsFrame.name)
    end
end

-- AceConfigDialog does not refresh options embedded in custom containers, so do it here.
function SettingsTab:ConfigTableChanged(_, appName)
    if appName ~= ADDON_NAME or not settingsContainer then return end
    C_Timer.After(0, function()
        if settingsContainer then
            AceConfigDialog:Open(ADDON_NAME, settingsContainer)
        end
    end)
end
registry.RegisterCallback(SettingsTab, "ConfigTableChange", "ConfigTableChanged")

local function BuildSettings(container)
    container:SetLayout("Fill")
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Fill")
    group:SetFullWidth(true)
    group:SetFullHeight(true)
    container:AddChild(group)
    settingsContainer = group
    AceConfigDialog:Open(ADDON_NAME, group)
end

local function CleanupSettings()
    settingsContainer = nil
end

GRB.MainFrame:RegisterTab("Settings", L["Settings"], BuildSettings, CleanupSettings)