local GRB = GuildRecruitmentBuddy
local L = GRB.L

local AutoInvite = GRB:NewModule("AutoInvite", "AceEvent-3.0")
GRB.AutoInvite = AutoInvite

-- C_GuildInfo.Invite needs a hardware event, so a whisper only queues a request.
-- The invite itself happens when the user clicks the button of the invite popup (UI/InviteFrame.lua).
local queue = {}          -- pending requests: { key, target, class, token, level }
local lastRequest = {}    -- "Name-Realm" -> GetTime() of the last request, for the per-player cooldown
local warnedNoPermission = false

AutoInvite.CLASSES = GRB.CLASSES

local function Settings()
    return GRB.db.profile.autoInvite
end

local function EscapePattern(text)
    return (gsub(text, "%p", "%%%0"))
end

-- Exact word match, case-insensitive: "ginv" matches "GINV pls" and "ginv!" but not "ginvite".
local function MatchesKeyword(text)
    local lower = text:lower()
    for keyword in Settings().keywords:gmatch("[^,]+") do
        keyword = strtrim(keyword):lower()
        if keyword ~= "" and lower:find("%f[%w]" .. EscapePattern(keyword) .. "%f[%W]") then
            return true
        end
    end
    return false
end

local function Invite(target)
    local invite = (C_GuildInfo and C_GuildInfo.Invite) or GuildInvite
    invite(target)
end

local function PlayCue()
    local sound = SOUNDKIT and SOUNDKIT.TELL_MESSAGE
    if sound then PlaySound(sound) end
end

function AutoInvite:GetQueue()
    return queue
end

function AutoInvite:Notify()
    if GRB.InviteFrame then
        GRB.InviteFrame:Update()
    end
end

function AutoInvite:OnToggled(enabled)
    if not enabled then
        wipe(queue)
        self:Notify()
    elseif not CanGuildInvite() then
        GRB:Print(L["You do not have permission to invite players to the guild."])
    end
end

-- Returns true, or false and a reason when the whisper must not produce an invite request.
function AutoInvite:Evaluate(key, class, level)
    local settings = Settings()
    if GRB.Contacts:IsInGuild(key) then
        return false, "in guild"
    end
    local contact = GRB.Contacts:Get(key)
    if contact and contact.status == "do-not-contact" then
        return false, "do-not-contact"
    end

    -- Allowed classes (none selected = every class). Unknown class cannot satisfy a restriction.
    if next(settings.classes) and not settings.classes[class] then
        return false, "class"
    end

    -- Minimum level. A whisper does not carry the level, so only known levels (from the contact
    -- database) can be checked; unknown levels pass.
    level = level or (contact and contact.level)
    if settings.minLevel > 0 and level and level < settings.minLevel then
        return false, "level"
    end
    return true
end

function AutoInvite:OnWhisper(_, text, sender, ...)
    if not GRB:IsInviteEnabled() or not MatchesKeyword(text) then return end

    local key = GRB.Contacts:Key(sender)
    if not key then return end

    -- Only players this addon whispered are handled: anyone else gets no invite and no reply and changes nothing.
    -- (Players who answer a channel post were never whispered; switch the setting off to invite them too.)
    if Settings().onlyContacted and not GRB.Contacts:IsKeywordEligible(key) then return end

    -- Per-player cooldown so repeated "ginv" does not spam requests
    local now = GetTime()
    local last = lastRequest[key]
    if last and now - last < Settings().cooldownMinutes * 60 then return end

    for _, entry in ipairs(queue) do
        if entry.key == key then return end
    end

    local guid = select(10, ...)
    local localizedClass, token
    if guid then
        localizedClass, token = GetPlayerInfoByGUID(guid)
    end

    if not self:Evaluate(key, token) then return end

    if not CanGuildInvite() then
        if not warnedNoPermission then
            warnedNoPermission = true
            GRB:Print(L["You do not have permission to invite players to the guild."])
        end
        return
    end

    lastRequest[key] = now
    local contact = GRB.Contacts:Get(key)
    tinsert(queue, {
        key = key,
        target = GRB.Contacts:GetWhisperTarget(key),
        class = localizedClass,
        token = token,
        level = contact and contact.level,
    })

    -- Quiet mode: the request waits silently and the popup appears when it ends
    if not GRB.Quiet:IsQuiet() then
        PlayCue()
    end
    self:Notify()
end

-- Optional whisper sent right after the invite
function AutoInvite:SendReply(entry)
    local settings = Settings()
    if not settings.replyEnabled then return end

    local ok, reason = GRB.Whisper:SendFreeText(entry.key, settings.replyText, { class = entry.class, level = entry.level })
    if not ok and reason then
        GRB:Print(format(L["Auto-reply skipped: %s"], reason))
    end
end

-- Must be called from a click (hardware event).
-- entry: { key, target, class, level }. Returns true when the invite was sent.
function AutoInvite:InviteNow(entry, withReply)
    if not CanGuildInvite() then
        GRB:Print(L["You do not have permission to invite players to the guild."])
        return false
    end
    if GRB.Contacts:IsInGuild(entry.key) then
        GRB:Printf(L["%s is already in our guild."], entry.target)
        return false
    end

    Invite(entry.target)
    GRB.Contacts:Record(entry.key, {
        class = entry.class,
        level = entry.level,
        timestamp = GetServerTime(),
        status = "invited",
    })
    GRB:Printf(L["Invited %s to the guild."], entry.target)
    if withReply then
        self:SendReply(entry)
    end
    return true
end

-- Must be called from a click (hardware event). Invites the first queued player.
function AutoInvite:AcceptNext()
    local entry = tremove(queue, 1)
    -- A request that was queued before the player opted out is dropped
    if entry and not GRB.Contacts:IsOptedOut(entry.key) then
        self:InviteNow(entry, true)
    end
    self:Notify()
end

function AutoInvite:SkipNext()
    tremove(queue, 1)
    self:Notify()
end

function AutoInvite:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    GRB.Quiet:OnChange(function(reason)
        if not reason and #queue > 0 then PlayCue() end
        self:Notify()
    end)
end
