local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Messages = GRB:NewModule("Messages")
GRB.Messages = Messages

Messages.MAX_LENGTH = 255
Messages.TARGETS = { "whisper", "channel" }

local KNOWN_PLACEHOLDERS = { name = true, class = true, level = true, guild = true, discord = true }

local function IsValidTarget(target)
    for _, t in ipairs(Messages.TARGETS) do
        if t == target then return true end
    end
    return false
end

-- The first default template of earlier versions; an unmodified copy is replaced once by the current default.
local OLD_DEFAULT_TEXT = "Hi {name}! {guild} is looking for more {class}s. Want to join us? Discord: {discord}"

function Messages:OnInitialize()
    local profile = GRB.db.profile
    local defaultText = L["Hi {name}! Looking for a guild? {guild} is a friendly community looking for more members. "
        .. "Whisper \"ginv\" for an invite or ask me anything! "
        .. "Sorry for the cold whisper; reply \"stop\" and I won't message you again."]

    if not profile.messagesSeeded then
        profile.messagesSeeded = true
        if #profile.messages == 0 then
            self:Add(L["Guild invite (whisper)"], "whisper", defaultText)
        end
    end

    if not profile.defaultTemplateUpdated then
        profile.defaultTemplateUpdated = true
        for _, msg in ipairs(profile.messages) do
            if msg.text == OLD_DEFAULT_TEXT then
                msg.text = defaultText
            end
        end
    end
end
---------------------------------------------------------------------------
-- CRUD
---------------------------------------------------------------------------

function Messages:GetAll()
    return GRB.db.profile.messages
end

function Messages:IndexOf(id)
    for i, msg in ipairs(GRB.db.profile.messages) do
        if msg.id == id then return i end
    end
end

function Messages:Get(id)
    local index = self:IndexOf(id)
    return index and GRB.db.profile.messages[index] or nil
end

function Messages:Add(name, target, text)
    local profile = GRB.db.profile
    local msg = {
        id = profile.nextMessageId,
        name = name or L["New message"],
        target = IsValidTarget(target) and target or "whisper",
        text = text or "",
    }
    profile.nextMessageId = profile.nextMessageId + 1
    tinsert(profile.messages, msg)
    return msg
end

-- fields may contain name, target and text
function Messages:Update(id, fields)
    local msg = self:Get(id)
    if not msg then return nil end
    if fields.name ~= nil then msg.name = fields.name end
    if fields.text ~= nil then msg.text = fields.text end
    if fields.target ~= nil and IsValidTarget(fields.target) then msg.target = fields.target end
    return msg
end

function Messages:Delete(id)
    local index = self:IndexOf(id)
    if not index then return false end
    tremove(GRB.db.profile.messages, index)
    if GRB.Broadcast then GRB.Broadcast:OnMessageDeleted(id) end
    return true
end

-- delta: -1 moves the message up, +1 moves it down
function Messages:Move(id, delta)
    local messages = GRB.db.profile.messages
    local index = self:IndexOf(id)
    if not index then return false end
    local newIndex = index + delta
    if newIndex < 1 or newIndex > #messages then return false end
    messages[index], messages[newIndex] = messages[newIndex], messages[index]
    return true
end

---------------------------------------------------------------------------
-- Placeholders
---------------------------------------------------------------------------

function Messages:GetGuildName()
    local override = GRB.db.profile.guildName
    if override and override ~= "" then return override end
    return (GetGuildInfo("player"))
end

-- Values that do not depend on the recipient: {guild} and {discord}
function Messages:GetBaseContext()
    return {
        guild = self:GetGuildName(),
        discord = GRB.db.profile.discord,
    }
end

function Messages:GetSampleContext()
    local ctx = self:GetBaseContext()
    ctx.name = "Arthas"
    ctx.class = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE.WARRIOR) or "Warrior"
    ctx.level = 60
    return ctx
end

local function AddUnique(list, value)
    for _, v in ipairs(list) do
        if v == value then return end
    end
    tinsert(list, value)
end

-- Replaces {name} {class} {level} {guild} {discord} (case-insensitive) using ctx.
-- Returns the rendered text, the known placeholders that had no value and the unknown placeholders.
function Messages:Render(text, ctx)
    local unresolved, unknown = {}, {}
    local rendered = (gsub(text or "", "{(%w+)}", function(key)
        local lower = key:lower()
        if not KNOWN_PLACEHOLDERS[lower] then
            AddUnique(unknown, "{" .. key .. "}")
            return nil
        end
        local value = ctx and ctx[lower]
        if value == nil or value == "" then
            AddUnique(unresolved, "{" .. lower .. "}")
            return nil
        end
        return tostring(value)
    end))
    return rendered, unresolved, unknown
end

-- Returns a table: rendered, length, ok (fits the chat limit), unresolved, unknown
function Messages:Validate(text, ctx)
    local rendered, unresolved, unknown = self:Render(text, ctx)
    local length = #rendered
    return {
        rendered = rendered,
        length = length,
        ok = length > 0 and length <= self.MAX_LENGTH,
        unresolved = unresolved,
        unknown = unknown,
    }
end
