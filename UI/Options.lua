local ADDON_NAME = ...
local GRB = GuildRecruitmentBuddy
local L = GRB.L

local function GetOptions()
    local db = GRB.db.profile
    local invite = db.autoInvite
    local broadcast = db.broadcast
    local optOut = db.optOut
    local leads = db.leads
    local welcome = db.welcome
    local quiet = db.quiet
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
                    contextMenu = {
                        type = "toggle",
                        name = L["Add a Recruit entry to the right-click menu of players"],
                        desc = L["Right-click a name (chat, target, party, friends) to whisper a template to that player."],
                        order = 2.5,
                        width = "full",
                        get = function() return db.contextMenu end,
                        set = function(_, value) db.contextMenu = value end,
                    },                    discord = {
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
                    onlyContacted = {
                        type = "toggle",
                        name = L["Only invite players I have whispered"],
                        desc = L["When on, ginv from players you have not whispered (e.g. who answer channel posts) is ignored."],
                        order = 1.5,
                        width = "full",
                        get = function() return invite.onlyContacted end,
                        set = function(_, value) invite.onlyContacted = value end,
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
            broadcast = {
                type = "group",
                name = L["Interval broadcasting"],
                order = 3,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["A timer marks channel messages as ready; send them with a keybind or click (Blizzard requires one)."],
                    },
                    active = {
                        type = "toggle",
                        name = L["Enable interval broadcasting"],
                        order = 1,
                        width = "full",
                        get = function() return GRB.Broadcast:IsActive() end,
                        set = function(_, value) GRB.Broadcast:SetActive(value) end,
                    },
                    keybind = {
                        type = "description",
                        order = 2,
                        name = L["Keybind: Esc > Key Bindings > AddOns > Guild Recruitment Buddy. You can also use /grb send."],
                    },
                    sound = {
                        type = "toggle",
                        name = L["Play a sound when a broadcast is ready"],
                        order = 3,
                        width = "full",
                        get = function() return broadcast.sound end,
                        set = function(_, value) broadcast.sound = value end,
                    },
                    pauseWhenAfk = {
                        type = "toggle",
                        name = L["Pause while AFK"],
                        order = 4,
                        width = "full",
                        get = function() return broadcast.pauseWhenAfk end,
                        set = function(_, value) broadcast.pauseWhenAfk = value end,
                    },
                },
            },
            optOut = {
                type = "group",
                name = L["Opt-out detection"],
                order = 4,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["When a player you contacted replies with one of these phrases, they are marked do-not-contact."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable opt-out detection"],
                        order = 1,
                        width = "full",
                        get = function() return optOut.enabled end,
                        set = function(_, value) optOut.enabled = value end,
                    },
                    notify = {
                        type = "toggle",
                        name = L["Print a chat notice when a player opts out"],
                        order = 2,
                        width = "full",
                        get = function() return optOut.notify end,
                        set = function(_, value) optOut.notify = value end,
                    },
                    confirm = {
                        type = "toggle",
                        name = L["Ask before adding a player to the do-not-contact list"],
                        desc = L["A popup shows the message that triggered the request, with buttons to add the player or skip."],
                        order = 2.2,
                        width = "full",
                        get = function() return optOut.confirm end,
                        set = function(_, value) optOut.confirm = value end,
                    },
                    ack = {
                        type = "toggle",
                        name = L["Send a confirmation whisper when a player opts out"],
                        order = 2.5,
                        width = "full",
                        get = function() return optOut.ack end,
                        set = function(_, value) optOut.ack = value end,
                    },
                    phrases = {
                        type = "input",
                        name = L["Opt-out phrases (comma separated)"],
                        desc = L["A single word only counts at the start of a short reply."],
                        order = 3,
                        width = "full",
                        multiline = 4,
                        get = function() return optOut.phrases end,
                        set = function(_, value) optOut.phrases = value or "" end,
                    },
                    exceptions = {
                        type = "input",
                        name = L["Exceptions (comma separated)"],
                        desc = L["Replies starting with one of these are never treated as an opt-out."],
                        order = 4,
                        width = "full",
                        get = function() return optOut.exceptions end,
                        set = function(_, value) optOut.exceptions = value or "" end,
                    },
                },
            },            welcome = {
                type = "group",
                name = L["Welcome flow"],
                order = 5,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["When someone joins the guild they are marked as joined and can get a welcome whisper."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Whisper new guild members"],
                        order = 1,
                        width = "full",
                        get = function() return welcome.enabled end,
                        set = function(_, value) welcome.enabled = value end,
                    },
                    onlyRecruited = {
                        type = "toggle",
                        name = L["Only players I contacted or invited"],
                        desc = L["Only welcome players that are in the contact database."],
                        order = 2,
                        width = "full",
                        get = function() return welcome.onlyRecruited end,
                        set = function(_, value) welcome.onlyRecruited = value end,
                    },
                    text = {
                        type = "input",
                        name = L["Welcome message"],
                        desc = L["Placeholders: {name} {class} {level} {guild} {discord}"],
                        order = 3,
                        width = "full",
                        multiline = 3,
                        get = function() return welcome.text end,
                        set = function(_, value) welcome.text = value or "" end,
                    },
                    placeholders = {
                        type = "description",
                        order = 3.1,
                        fontSize = "medium",
                        name = L["Placeholders: {name} {class} {level} {guild} {discord}"] .. "\n" ..
                            L["{class} and {level} are only known for players in your contact database. "
                                .. "An unknown {class} becomes \"adventurer\", and the welcome is skipped "
                                .. "when it uses {level} and the level is unknown."],
                    },
                    previewHeader = {
                        type = "header",
                        order = 4,
                        name = L["Preview"],
                    },
                    previewCounter = {
                        type = "description",
                        order = 4.1,
                        name = function()
                            local result = GRB.Messages:Validate(welcome.text, GRB.Messages:GetSampleContext())
                            local color = result.ok and "|cff40ff40" or "|cffff4040"
                            return format("%s%d / %d|r", color, result.length, GRB.Messages.MAX_LENGTH)
                        end,
                    },
                    previewWarning = {
                        type = "description",
                        order = 4.2,
                        hidden = function()
                            local result = GRB.Messages:Validate(welcome.text, GRB.Messages:GetSampleContext())
                            return result.length <= GRB.Messages.MAX_LENGTH and #result.unknown == 0 and #result.unresolved == 0
                        end,
                        name = function()
                            local result = GRB.Messages:Validate(welcome.text, GRB.Messages:GetSampleContext())
                            local notes = {}
                            if result.length > GRB.Messages.MAX_LENGTH then
                                tinsert(notes, format(L["Too long by %d characters."], result.length - GRB.Messages.MAX_LENGTH))
                            end
                            if #result.unknown > 0 then
                                tinsert(notes, format(L["Unknown placeholders: %s"], table.concat(result.unknown, " ")))
                            end
                            if #result.unresolved > 0 then
                                tinsert(notes, format(L["Not set (see Settings): %s"], table.concat(result.unresolved, " ")))
                            end
                            return "|cffffd100" .. table.concat(notes, "  ") .. "|r"
                        end,
                    },
                    previewText = {
                        type = "description",
                        order = 4.3,
                        fontSize = "medium",
                        name = function()
                            return (GRB.Messages:Validate(welcome.text, GRB.Messages:GetSampleContext()).rendered)
                        end,
                    },
                },
            },            quiet = {
                type = "group",
                name = L["Quiet mode"],
                order = 6,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["Keeps recruiting out of the way: no broadcast popups, silent invite requests, held-back welcomes."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable automatic quiet mode"],
                        order = 1,
                        width = "full",
                        get = function() return quiet.enabled end,
                        set = function(_, value)
                            quiet.enabled = value
                            GRB.Quiet:Refresh()
                        end,
                    },
                    combat = {
                        type = "toggle",
                        name = L["In combat"],
                        order = 2,
                        width = "full",
                        get = function() return quiet.combat end,
                        set = function(_, value) quiet.combat = value; GRB.Quiet:Refresh() end,
                    },
                    dungeons = {
                        type = "toggle",
                        name = L["In dungeons"],
                        order = 3,
                        width = "full",
                        get = function() return quiet.dungeons end,
                        set = function(_, value) quiet.dungeons = value; GRB.Quiet:Refresh() end,
                    },
                    raids = {
                        type = "toggle",
                        name = L["In raids"],
                        order = 4,
                        width = "full",
                        get = function() return quiet.raids end,
                        set = function(_, value) quiet.raids = value; GRB.Quiet:Refresh() end,
                    },
                    battlegrounds = {
                        type = "toggle",
                        name = L["In battlegrounds and arenas"],
                        order = 5,
                        width = "full",
                        get = function() return quiet.battlegrounds end,
                        set = function(_, value) quiet.battlegrounds = value; GRB.Quiet:Refresh() end,
                    },
                    manual = {
                        type = "description",
                        order = 6,
                        name = L["Switch quiet mode on by hand with /grb quiet on and off with /grb quiet off."],
                    },
                },
            },            sync = {
                type = "group",
                name = L["Officer sync"],
                order = 7,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["Shares contacts with guild members who can invite, so recruiters never whisper the same player."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Enable officer sync"],
                        order = 1,
                        width = "full",
                        get = function() return db.sync.enabled end,
                        set = function(_, value)
                            db.sync.enabled = value
                            if value then GRB.Sync:TryAnnounce() end
                        end,
                    },
                    status = {
                        type = "description",
                        order = 2,
                        name = function() return GRB.Sync:GetSummary() end,
                    },
                    force = {
                        type = "execute",
                        name = L["Force full sync"],
                        desc = L["Forget what was received before and exchange all contacts with every online recruiter."],
                        order = 3,
                        disabled = function() return not GRB.Sync:CanSync() end,
                        func = function() GRB.Sync:ForceSync() end,
                    },
                },
            },            leads = {
                type = "group",
                name = L["Leads"],
                order = 8,
                args = {
                    description = {
                        type = "description",
                        order = 0,
                        name = L["Replies from players you contacted that sound interested but not ready are kept as leads."],
                    },
                    enabled = {
                        type = "toggle",
                        name = L["Save interested replies as leads"],
                        order = 1,
                        width = "full",
                        get = function() return leads.enabled end,
                        set = function(_, value) leads.enabled = value end,
                    },
                    phrases = {
                        type = "input",
                        name = L["Lead phrases (comma separated)"],
                        desc = L["A reply containing one of these words or phrases becomes a lead (opt-outs never do)."],
                        order = 2,
                        width = "full",
                        multiline = 3,
                        get = function() return leads.phrases end,
                        set = function(_, value) leads.phrases = value or "" end,
                    },
                },
            },            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(GRB.db),
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