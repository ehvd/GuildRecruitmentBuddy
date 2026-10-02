local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Welcome = GRB:NewModule("Welcome", "AceEvent-3.0", "AceTimer-3.0")
GRB.Welcome = Welcome

local WELCOME_DELAY = 3             -- seconds after the join message (the player may still be loading)
local WELCOME_COOLDOWN = 24 * 3600  -- do not welcome the same player again within a day (leave / rejoin)

-- Turns a client format string such as "%s has joined the guild." into a Lua pattern with one capture.
local function FormatToPattern(format_)
    local pattern = gsub(format_, "([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
    pattern = gsub(pattern, "%%%%s", "(.+)")
    return "^" .. pattern .. "$"
end

-- The client's own (localized) join message, so detection works in every locale
local JOIN_PATTERN = FormatToPattern(ERR_GUILD_JOIN_S or "%s has joined the guild.")

local function Settings()
    return GRB.db.profile.welcome
end

function Welcome:OnSystemMessage(_, text)
    local name = text and text:match(JOIN_PATTERN)
    if name then
        self:OnJoined(name)
    end
end

-- A player joined the guild: mark the contact as joined and (optionally) welcome them.
function Welcome:OnJoined(name)
    local contacts = GRB.Contacts
    local key = contacts:Key(name)
    if not key or key == contacts:Key(UnitName("player")) then return end

    local contact = contacts:Get(key)
    -- Someone who asked not to be contacted is neither welcomed nor re-labelled
    if contact and contact.status == "do-not-contact" then return end

    contacts:Record(key, {
        status = "joined",
        timestamp = not (contact and contact.timestamp) and GetServerTime() or nil,
    })
    contacts:RequestRoster()

    local settings = Settings()
    if not settings.enabled then return end
    if settings.onlyRecruited and not contact then return end
    if contact and contact.welcomed and GetServerTime() - contact.welcomed < WELCOME_COOLDOWN then return end

    self:ScheduleTimer("SendWelcome", WELCOME_DELAY, key)
end

local held = {}   -- players waiting for a welcome until quiet mode ends

function Welcome:SendWelcome(key)
    if GRB.Quiet:IsQuiet() then
        held[key] = true
        return
    end
    local contact = GRB.Contacts:Get(key)
    local ok, reason = GRB.Whisper:SendFreeText(key, Settings().text, {
        class = contact and contact.class,
        level = contact and contact.level,
    })
    local short = GRB.Contacts:SplitKey(key)
    if ok then
        if contact then contact.welcomed = GetServerTime() end
        GRB:Printf(L["Welcomed %s."], short)
    else
        GRB:Printf(L["Welcome message to %s skipped: %s"], short, reason)
    end
end

function Welcome:OnEnable()
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")
    GRB.Quiet:OnChange(function(reason)
        if reason then return end
        -- Quiet mode ended: send the held-back welcomes a couple of seconds apart
        local delay = WELCOME_DELAY
        for key in pairs(held) do
            held[key] = nil
            self:ScheduleTimer("SendWelcome", delay, key)
            delay = delay + 2
        end
    end)
end
