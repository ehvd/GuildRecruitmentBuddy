local GRB = GuildRecruitmentBuddy
local L = GRB.L

local OptOut = GRB:NewModule("OptOut", "AceEvent-3.0")
GRB.OptOut = OptOut

-- A reply is treated as an opt-out request when
--   * the addon itself whispered that player recently (Contacts:IsKeywordEligible); anyone else is ignored
--     completely, so a stranger typing "stop" changes nothing and gets no reply, and
--   * the reply, without punctuation, contains one of the multi-word phrases ("please stop spamming me") or
--     starts with a single-word phrase in a short reply ("stop", "no thanks i'm good"; but not
--     "no problem, I'll join", see the exceptions list).
-- By default the request goes into a queue and a popup (UI/OptOutFrame.lua) shows the message that triggered it;
-- the user adds the player to the do-not-contact list or skips it. With confirmation switched off the player
-- is added at once. Adding a player sends one confirmation whisper; being no longer contacted, a repeated
-- "stop" gets no reply.
local SHORT_REPLY_WORDS = 3

local parsedCache = {}   -- raw setting string -> { normalized phrases }
local queue = {}         -- pending requests: { key, name, text, guid }

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

---------------------------------------------------------------------------
-- Pending requests (confirmation popup)
---------------------------------------------------------------------------

function OptOut:GetQueue()
    return queue
end

-- true while the player has an opt-out request waiting for the user's decision
function OptOut:IsPending(key)
    for _, entry in ipairs(queue) do
        if entry.key == key then return true end
    end
    return false
end

function OptOut:Notify()
    if GRB.OptOutFrame then
        GRB.OptOutFrame:Update()
    end
end

local function PlayCue()
    local sound = SOUNDKIT and SOUNDKIT.TELL_MESSAGE
    if sound then PlaySound(sound) end
end

-- Puts the player on the opt-out list, tells the user and (unless switched off) sends the one confirmation whisper.
function OptOut:Apply(entry)
    local contacts = GRB.Contacts
    if contacts:IsOptedOut(entry.key) then return end   -- already handled, e.g. by another recruiter's sync

    contacts:OptOut(entry.key, entry.guid)
    if Settings().notify then
        GRB:Printf(L["%s replied \"%s\": marked do-not-contact."], entry.name, entry.text)
    end
    if Settings().ack then
        GRB.Whisper:SendText(entry.key, L["Got it, you won't hear from me again. Good luck out there!"], { ack = true })
    end
end

-- The popup's "Opt out" button
function OptOut:ConfirmNext()
    local entry = tremove(queue, 1)
    if entry then
        self:Apply(entry)
    end
    self:Notify()
end

-- The popup's "Skip" button: the player stays a normal contact
function OptOut:SkipNext()
    tremove(queue, 1)
    self:Notify()
end

function OptOut:OnWhisper(_, text, sender, ...)
    if not Settings().enabled then return end

    local contacts = GRB.Contacts
    local key = contacts:Key(sender)
    -- Only players this addon whispered recently are handled; everyone else is ignored completely
    if not key or not contacts:IsKeywordEligible(key) then return end

    if not self:Match(text) then return end

    local entry = {
        key = key,
        name = (contacts:SplitKey(key)),
        text = text,
        guid = (select(10, ...)),
    }
    if not Settings().confirm then
        self:Apply(entry)
        return
    end

    -- A player who answers again while the request is open just updates the shown message
    for _, pending in ipairs(queue) do
        if pending.key == key then
            pending.text = text
            self:Notify()
            return
        end
    end
    tinsert(queue, entry)
    -- Quiet mode: the request waits silently and the popup appears when it ends
    if not GRB.Quiet:IsQuiet() then
        PlayCue()
    end
    self:Notify()
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
    GRB.Quiet:OnChange(function(reason)
        if not reason and #queue > 0 then PlayCue() end
        self:Notify()
    end)
end
