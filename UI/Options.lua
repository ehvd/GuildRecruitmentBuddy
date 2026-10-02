local ADDON_NAME = ...
local GRB = GuildRecruitmentBuddy
local L = GRB.L

local function GetOptions()
    local db = GRB.db.profile
    return {
        type = "group",
        name = L["ADDON_NAME"],
        args = {
            general = {
                type = "group",
                name = L["General"],
                order = 1,
                args = {
                    autoInvite = {
                        type = "toggle",
                        name = L["Auto invite (ginv)"],
                        order = 1,
                        get = function() return GRB:IsInviteEnabled() end,
                        set = function(_, value) GRB:SetInviteEnabled(value) end,
                    },
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
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(GRB.db),
        },
    }
end

function GRB:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, GetOptions)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, L["ADDON_NAME"])
end

function GRB:OpenConfig()
    LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
end
