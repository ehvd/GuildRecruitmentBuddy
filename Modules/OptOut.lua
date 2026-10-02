local GRB = GuildRecruitmentBuddy
local L = GRB.L

local OptOut = GRB:NewModule("OptOut", "AceEvent-3.0")
GRB.OptOut = OptOut

-- A single word such as "no" only counts at the start of a short reply: "no thanks" opts out,
-- "no problem, I'll join" does not.
local SHORT_REPLY_WORDS = 3

local parsedCache = {}   -- raw setting string -> { normalized phrases }

local function Settings()
    return GRB.db.profile.optOut
end

-- Lower case, strip ASCII punctuation (so "don't" and "dont" match) and collapse white space.
local function Normalize(text)
    text = gsub(text:lower(), "%p", "")
    text = gsub(text, "%s+", " ")
    return strtrim(text)
end

local function WordCount(text)
    local count = 0
    for _ in text:gmatch("%S+") do count = count + 1 end
    return count
end

-- Splits a comma/newline separated setting into normalized phrases (cached).
local function ParsePhrases(raw)
    local cached = parsedCache[raw]
    if cached then return cached end
    local phrases = {}
    for item in (raw or ""):gmatch("[^,\n]+") do
        local phrase = Normalize(item)
        if phrase ~= "" then
            tinsert(phrases, phrase)
        end
    end
    parsedCache[raw] = phrases
    return phrases
end

local function StartsWith(message, phrase)
    return message == phrase or message:sub(1, #phrase + 1) == phrase .. " "
end

local function Contains(message, phrase)
    return (" " .. message .. " "):find(" " .. phrase .. " ", 1, true) ~= nil
end

-- Returns the phrase that matched, or nil when the text is not an opt-out.
function OptOut:Match(text)
    local message = Normalize(text or "")
    if message == "" then return nil end
    local settings = Settings()

    for _, exception in ipairs(ParsePhrases(settings.exceptions)) do
        if StartsWith(message, exception) then return nil end
    end

    local words = WordCount(message)
    for _, phrase in ipairs(ParsePhrases(settings.phrases)) do
        if WordCount(phrase) > 1 then
            if Contains(message, phrase) then return phrase end
        elseif StartsWith(message, phrase) and words <= SHORT_REPLY_WORDS then
            return phrase
        end
    end
    return nil
end

function OptOut:OnWhisper(_, text, sender)
    if not Settings().enabled then return end

    local contact, key = GRB.Contacts:Get(sender)
    -- Only players we contacted and who have not been invited or joined yet
    if not contact or (contact.status ~= "contacted" and contact.status ~= "replied") then return end

    local phrase = self:Match(text)
    if not phrase then return end

    GRB.Contacts:SetStatus(key, "do-not-contact")
    if Settings().notify then
        GRB:Printf(L["%s replied \"%s\": marked do-not-contact."], contact.name or key, text)
    end
end

function OptOut:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end
