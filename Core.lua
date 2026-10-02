local ADDON_NAME = ...

local GRB = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
GuildRecruitmentBuddy = GRB

local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
GRB.L = L

-- Classic Era class tokens
GRB.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local version = getMetadata(ADDON_NAME, "Version")
-- "@project-version@" is only substituted by the packager / `make install`; a linked dev checkout keeps it
GRB.version = (version and not version:find("@", 1, true)) and version or "dev"

-- profile: settings (shared by all characters), global: contacts keyed by "Name-Realm"
-- Key binding labels (Bindings.xml)
BINDING_HEADER_GUILDRECRUITMENTBUDDY = L["ADDON_NAME"]
BINDING_NAME_GUILDRECRUITMENTBUDDY_SEND = L["Send the ready channel broadcast"]

local defaults = {
    profile = {
        minimap = { hide = false },
        autoInvite = {
            enabled = false,
            keywords = "ginv",        -- comma separated, exact word, case-insensitive
            minLevel = 0,               -- 0 = off; only applied when the player's level is known
            classes = {},               -- [CLASS_TOKEN] = true; empty = every class
            cooldownMinutes = 10,       -- ignore repeated keywords from the same player for this long
            replyEnabled = false,
            replyText = L["Invited you to {guild}! Accept the invite to join."],
        },
        scanner = {
            classes = {},     -- [CLASS_TOKEN] = false when unchecked; missing = checked
            minLevel = 1,
            maxLevel = 60,
            zone = "",
        },
        quiet = {                   -- see Modules/Quiet.lua
            enabled = true,
            combat = true,
            dungeons = true,
            raids = true,
            battlegrounds = true,
        },
        quietMigrated = false,
        welcome = {
            enabled = false,        -- whisper new guild members (off by default)
            onlyRecruited = false,  -- only players that are in the contact database
            text = L["Welcome to {guild}, {name}! Our Discord: {discord}"],
        },
        optOut = {
            enabled = true,         -- reply such as "not interested" marks a contacted player do-not-contact
            notify = true,          -- print a chat notice when that happens
            -- comma separated; a single word only counts at the start of a short reply
            phrases = "no, no thanks, no thx, not interested, stop, stop spamming, stop whispering, stop messaging, " ..
                "leave me alone, dont whisper me, dont message me, remove me, unsubscribe",
            exceptions = "no problem, no worries",   -- replies starting with these are never an opt-out
        },
        broadcastEntries = {},      -- see Modules/Broadcast.lua: { id, messageId, channel, interval, active }
        nextBroadcastId = 1,
        broadcastMigrated = false,
        broadcast = {
            active = false,         -- master switch, off by default (/grb broadcast on|off)
            sound = true,           -- sound when a broadcast becomes ready
            pauseWhenAfk = true,
        },
        window = {},      -- main window position and size (managed by AceGUI)
        guildName = "",   -- overrides the detected guild name for {guild}
        discord = "",     -- value of {discord}
        messages = {},    -- { id, name, target = "whisper"|"channel", text }
        nextMessageId = 1,
        messagesSeeded = false,
        cooldownDays = 14,          -- days before the same player may be whispered again (0 = off)
        maxWhispersPerMinute = 8,   -- session rate limit for whispers sent through the addon
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
    if self.AutoInvite then self.AutoInvite:OnToggled(enabled) end
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

-- The tabbed main window lives in UI/MainFrame.lua; tabs register themselves with it.
function GRB:ToggleMainWindow(tab)
    self.MainFrame:Toggle(tab)
end

function GRB:OpenScanner()
    self.MainFrame:Open("Scanner")
end
function GRB:PrintUsage()
    self:Print(L["Usage:"])
    self:Print(L["/grb - open the main window"])
    self:Print(L["/grb invite on|off - toggle keyword auto invite"])
    self:Print(L["/grb scan - open the scanner"])
    self:Print(L["/grb broadcast on|off - toggle interval broadcasting"])
    self:Print(L["/grb send - send the ready channel broadcast"])
    self:Print(L["/grb quiet on|off - switch quiet mode on or off by hand"])
    self:Print(L["/grb config - open settings"])
    self:Print(L["/grb options - open the Blizzard options panel"])
end

function GRB:HandleSlashCommand(input)
    local cmd, arg = self:GetArgs(input or "", 2)
    cmd = cmd and cmd:lower() or ""
    arg = arg and arg:lower() or nil

    if cmd == "" then
        self:ToggleMainWindow()
    elseif cmd == "invite" and (arg == "on" or arg == "off") then
        self:SetInviteEnabled(arg == "on")
    elseif cmd == "broadcast" and (arg == "on" or arg == "off") then
        self.Broadcast:SetActive(arg == "on")
    elseif cmd == "quiet" and (arg == "on" or arg == "off") then
        self.Quiet:SetManual(arg == "on")
    elseif cmd == "send" then
        self.Broadcast:SendNext()
    elseif cmd == "scan" then
        self:OpenScanner()
    elseif cmd == "config" or cmd == "settings" then
        self:OpenConfig()
    elseif cmd == "options" then
        self:OpenBlizzardOptions()
    else
        self:PrintUsage()
    end
end
