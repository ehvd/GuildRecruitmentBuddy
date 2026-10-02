local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Whisper = GRB:NewModule("Whisper")
GRB.Whisper = Whisper

local CTL_PREFIX = "GRB"
local WINDOW = 60

local sentTimes = {}   -- GetTime() of whispers sent this session within the rate limit window

-- Returns true, or false and the reason the session rate limit blocks sending.
function Whisper:CheckRateLimit()
    local now = GetTime()
    while sentTimes[1] and now - sentTimes[1] >= WINDOW do
        tremove(sentTimes, 1)
    end
    local limit = GRB.db.profile.maxWhispersPerMinute
    if #sentTimes >= limit then
        local wait = ceil(WINDOW - (now - sentTimes[1]))
        return false, format(L["Rate limit reached (%d whispers per minute). Try again in %d s."], limit, wait)
    end
    return true
end

-- Sends already rendered text as a whisper through ChatThrottleLib, honouring the session rate limit.
-- Does not touch the contact database or its cooldown. Returns true, or false and a reason.
function Whisper:SendText(name, text)
    local key = GRB.Contacts:Key(name)
    if not key then return false, L["Enter a player name."] end
    local ok, reason = self:CheckRateLimit()
    if not ok then return false, reason end

    ChatThrottleLib:SendChatMessage("NORMAL", CTL_PREFIX, text, "WHISPER", nil, GRB.Contacts:GetWhisperTarget(key))
    tinsert(sentTimes, GetTime())
    return true
end

local function BuildContext(name, info)
    local ctx = GRB.Messages:GetBaseContext()
    ctx.name = (GRB.Contacts:SplitKey(GRB.Contacts:Key(name)))
    ctx.class = info and info.class or L["adventurer"]
    ctx.level = info and info.level
    return ctx
end

-- Returns true, or false and the reason why the template cannot be whispered to the player right now.
function Whisper:CanSend(name, templateId, info)
    local ok, reason = GRB.Contacts:CanContact(name)
    if not ok then return false, reason end

    local template = GRB.Messages:Get(templateId)
    if not template then
        return false, L["Select a message template."]
    end
    if template.target ~= "whisper" then
        return false, L["The selected template is not a whisper template."]
    end

    local result = GRB.Messages:Validate(template.text, BuildContext(name, info))
    if #result.unknown > 0 then
        return false, format(L["Unknown placeholders: %s"], table.concat(result.unknown, " "))
    end
    for _, placeholder in ipairs(result.unresolved) do
        if placeholder == "{level}" then
            return false, L["The player's level is unknown, but the template uses {level}."]
        end
    end
    if #result.unresolved > 0 then
        return false, format(L["Not set (see Settings): %s"], table.concat(result.unresolved, " "))
    end
    if not result.ok then
        return false, format(L["Message must be 1-%d characters (now %d)."], GRB.Messages.MAX_LENGTH, result.length)
    end

    return self:CheckRateLimit()
end

-- Sends the template as a whisper through ChatThrottleLib and records the contact.
-- info is optional: { class = "Warrior", level = 60 }. Returns true, or false and a reason.
function Whisper:Send(name, templateId, info)
    local ok, reason = self:CanSend(name, templateId, info)
    if not ok then return false, reason end

    local template = GRB.Messages:Get(templateId)
    local text = GRB.Messages:Validate(template.text, BuildContext(name, info)).rendered
    local key = GRB.Contacts:Key(name)

    self:SendText(key, text)

    GRB.Contacts:Record(key, {
        class = info and info.class,
        level = info and info.level,
        timestamp = GetServerTime(),
        templateId = template.id,
        templateName = template.name,
        status = "contacted",
    })
    return true
end
