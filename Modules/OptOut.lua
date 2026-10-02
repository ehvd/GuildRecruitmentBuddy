local GRB = GuildRecruitmentBuddy
local L = GRB.L

local OptOut = GRB:NewModule("OptOut", "AceEvent-3.0")
GRB.OptOut = OptOut

-- A reply opts a player out only when
--   * the addon itself whispered that player recently (Contacts:IsKeywordEligible); anyone else is ignored
--     completely, so a stranger typing "stop" changes nothing and gets no reply, and
--   * the whole reply, trimmed and without punctuation, is one of the phrases (a single word such as "stop"
--     must be the entire reply: "stop" and "STOP!" match, "stop by later" and "don't stop" do not), or it
--     contains one of the multi-word phrases ("please stop spamming me").
-- The player goes on the opt-out list (do-not-contact), gets one confirmation whisper and, being no longer
-- contacted, gets no answer to a repeated "stop".
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

    for _, phrase in ipairs(ParsePhrases(settings.phrases)) do
        if WordCount(phrase) > 1 then
            if Contains(message, phrase) then return phrase end
        elseif message == phrase then
            return phrase
        end
    end
    return nil
end

function OptOut:OnWhisper(_, text, sender, ...)
    if not Settings().enabled then return end

    local contacts = GRB.Contacts
    local key = contacts:Key(sender)
    -- Only players this addon whispered recently are handled; everyone else is ignored completely
    if not key or not contacts:IsKeywordEligible(key) then return end

    local phrase = self:Match(text)
    if not phrase then return end

    contacts:OptOut(key, (select(10, ...)))
    if Settings().notify then
        GRB:Printf(L["%s replied \"%s\": marked do-not-contact."], (contacts:SplitKey(key)), text)
    end
    if Settings().ack then
        GRB.Whisper:SendText(key, L["Got it, you won't hear from me again. Good luck out there!"], { ack = true })
    end
end

-- /grb optout list | add <name> | remove <name>
function OptOut:HandleCommand(sub, name)
    local contacts = GRB.Contacts
    if sub == "list" then
        local list = contacts:GetOptedOut()
        GRB:Printf(L["Opted-out players: %d"], #list)
        local names = {}
        for _, entry in ipairs(list) do
            tinsert(names, (contacts:SplitKey(entry.key)))
            if #names == 10 then
                GRB:Print(table.concat(names, ", "))
                wipe(names)
            end
        end
        if #names > 0 then GRB:Print(table.concat(names, ", ")) end
    elseif (sub == "add" or sub == "remove") and name and name ~= "" then
        local key = contacts:Key(name)
        if not key then return end
        if sub == "add" then
            contacts:OptOut(key)
            GRB:Printf(L["%s is now on the opt-out list."], key)
        elseif contacts:RemoveOptOut(key) then
            GRB:Printf(L["%s was taken off the opt-out list."], key)
        else
            GRB:Printf(L["%s is not on the opt-out list."], key)
        end
    else
        GRB:Print(L["/grb optout list - show the players who opted out"])
        GRB:Print(L["/grb optout add <name> - put a player on the opt-out list"])
        GRB:Print(L["/grb optout remove <name> - take a player off the opt-out list"])
    end
end

function OptOut:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
end
