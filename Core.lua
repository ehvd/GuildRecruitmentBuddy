local ADDON_NAME = ...

local GRB = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
GuildRecruitmentBuddy = GRB

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
GRB.L = L

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
GRB.version = getMetadata(ADDON_NAME, "Version") or "dev"

-- profile: settings (shared by all characters), global: contacts keyed by "Name-Realm"
local defaults = {
    profile = {
        minimap = { hide = false },
        autoInvite = {
            enabled = false,
        },
        guildName = "",   -- overrides the detected guild name for {guild}
        discord = "",     -- value of {discord}
        messages = {},    -- { id, name, target = "whisper"|"channel", text }
        nextMessageId = 1,
        messagesSeeded = false,
    },
    global = {
        contacts = {},
    },
}

function GRB:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("GuildRecruitmentBuddyDB", defaults, true)

    self:RegisterChatCommand("grb", "HandleSlashCommand")
    self:RegisterChatCommand("guildrecruitmentbuddy", "HandleSlashCommand")

    self:SetupOptions()
    self:SetupMinimapButton()
end

function GRB:IsInviteEnabled()
    return self.db.profile.autoInvite.enabled
end

function GRB:SetInviteEnabled(enabled)
    enabled = enabled and true or false
    self.db.profile.autoInvite.enabled = enabled
    self:Printf(L["Auto invite is now %s."], enabled and L["on"] or L["off"])
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

-- The tabbed main window is provided by UI/MainFrame.lua once it exists.
function GRB:ToggleMainWindow(tab)
    if self.MainFrame and self.MainFrame.Toggle then
        self.MainFrame:Toggle(tab)
    else
        self:Print(L["The main window is not available yet."])
    end
end

function GRB:OpenScanner()
    if self.MainFrame and self.MainFrame.Toggle then
        self.MainFrame:Toggle("Scanner")
    else
        self:Print(L["Scanner is not available yet."])
    end
end

function GRB:PrintUsage()
    self:Print(L["Usage:"])
    self:Print(L["/grb - open the main window"])
    self:Print(L["/grb invite on|off - toggle keyword auto invite"])
    self:Print(L["/grb scan - open the scanner"])
    self:Print(L["/grb config - open settings"])
end

function GRB:HandleSlashCommand(input)
    local cmd, arg = self:GetArgs(input or "", 2)
    cmd = cmd and cmd:lower() or ""
    arg = arg and arg:lower() or nil

    if cmd == "" then
        self:ToggleMainWindow()
    elseif cmd == "invite" and (arg == "on" or arg == "off") then
        self:SetInviteEnabled(arg == "on")
    elseif cmd == "scan" then
        self:OpenScanner()
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        self:OpenConfig()
    else
        self:PrintUsage()
    end
end
