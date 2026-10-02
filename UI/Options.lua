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
