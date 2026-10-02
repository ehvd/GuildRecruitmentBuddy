local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Broadcast = GRB:NewModule("Broadcast", "AceTimer-3.0")
GRB.Broadcast = Broadcast

-- SendChatMessage to a CHANNEL needs a hardware event (see docs/CONSTRAINTS.md), so a timer can only mark a
-- message as "ready". The user then presses the keybind (Bindings.xml), `/grb send` or the button of the
-- ready popup (UI/BroadcastFrame.lua); Broadcast:SendNext() runs inside that click/keypress and calls
-- SendChatMessage directly (ChatThrottleLib would defer the call to OnUpdate and lose the hardware event).
local TICK = 1
local MAX_CHANNELS = 10

local nextDue = {}   -- message id -> GetTime() when it becomes ready again (nil = ready as soon as possible)
local ready = {}     -- ids of messages that are ready to be sent, oldest first

local function Settings()
    return GRB.db.profile.broadcast
end

local function IsReady(id)
    for _, readyId in ipairs(ready) do
        if readyId == id then return true end
    end
    return false
end

local function RemoveReady(id)
    for i, readyId in ipairs(ready) do
        if readyId == id then
            tremove(ready, i)
            return
        end
    end
end

-- "Trade - Stormwind City" -> "trade", so a stored channel name survives zone changes and new sessions
local function BaseName(name)
    return ((name:match("^(.-)%s+%-%s+") or name):lower())
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------

-- Returns the channel index for a stored channel name, or nil when the channel is not joined.
function Broadcast:FindChannel(channel)
    if not channel or channel == "" then return nil end
    local wanted = BaseName(channel)
    for i = 1, MAX_CHANNELS do
        local id, name = GetChannelName(i)
        if id and id > 0 and name and BaseName(name) == wanted then
            return id
        end
    end
end

function Broadcast:GetJoinedChannels()
    local names = {}
    for i = 1, MAX_CHANNELS do
        local id, name = GetChannelName(i)
        if id and id > 0 and name then
            tinsert(names, (name:match("^(.-)%s+%-%s+") or name))
        end
    end
    return names
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

function Broadcast:IsActive()
    return Settings().active
end

function Broadcast:SetActive(active)
    active = active and true or false
    Settings().active = active
    if not active then
        wipe(ready)
    end
    GRB:Printf(L["Broadcasting is now %s."], active and L["on"] or L["off"])
    self:Notify()
end

-- Returns the reason broadcasting is paused right now, or nil.
function Broadcast:GetPauseReason()
    local settings = Settings()
    if settings.pauseInInstance and IsInInstance() then
        return L["in an instance"]
    end
    if settings.pauseInCombat and (InCombatLockdown() or UnitAffectingCombat("player")) then
        return L["in combat"]
    end
    if settings.pauseWhenAfk and UnitIsAFK("player") then
        return L["AFK"]
    end
end

function Broadcast:GetReady()
    return ready
end

function Broadcast:Notify()
    if GRB.BroadcastFrame then
        GRB.BroadcastFrame:Update()
    end
end

-- Called when a message is edited or deleted. Enabling, retargeting or changing the channel restarts its timer;
-- a new interval only applies from the next send.
function Broadcast:OnMessageChanged(id, fields)
    if not fields or fields.broadcast ~= nil or fields.target ~= nil or fields.channel ~= nil then
        nextDue[id] = nil
    end
    local msg = GRB.Messages:Get(id)
    if not msg or msg.target ~= "channel" or not msg.broadcast then
        RemoveReady(id)
    end
    self:Notify()
end

-- Text for the status line of a message in the Messages tab
function Broadcast:GetStatusText(id)
    local msg = GRB.Messages:Get(id)
    if not msg or msg.target ~= "channel" or not msg.broadcast then
        return ""
    end
    if not self:IsActive() then
        return L["Broadcasting is off (/grb broadcast on)."]
    end
    local pause = self:GetPauseReason()
    if pause then
        return format(L["Paused: %s."], pause)
    end
    if IsReady(id) then
        return L["Ready to send."]
    end
    local due = nextDue[id]
    if not due then
        return L["Ready to send."]
    end
    return format(L["Next one is ready in %d min."], max(1, ceil((due - GetTime()) / 60)))
end

function Broadcast:Tick()
    if not self:IsActive() then return end

    if not self:GetPauseReason() then
        local now = GetTime()
        local added = false
        for _, msg in ipairs(GRB.Messages:GetAll()) do
            if msg.target == "channel" and msg.broadcast and not IsReady(msg.id) then
                local due = nextDue[msg.id]
                if not due or now >= due then
                    tinsert(ready, msg.id)
                    added = true
                end
            end
        end
        if added then
            if Settings().sound then
                local sound = SOUNDKIT and (SOUNDKIT.READY_CHECK or SOUNDKIT.TELL_MESSAGE)
                if sound then PlaySound(sound) end
            end
            if FlashClientIcon then FlashClientIcon() end
        end
    end
    self:Notify()
end

---------------------------------------------------------------------------
-- Sending (hardware event)
---------------------------------------------------------------------------

local function Reschedule(msg)
    nextDue[msg.id] = GetTime() + (msg.interval or GRB.Messages.DEFAULT_INTERVAL) * 60
end

-- Must be called from a keypress or click. Sends the oldest ready message.
function Broadcast:SendNext()
    if not self:IsActive() then
        GRB:Print(L["Broadcasting is off (/grb broadcast on)."])
        return false
    end
    local pause = self:GetPauseReason()
    if pause then
        GRB:Printf(L["Paused: %s."], pause)
        return false
    end

    local id = tremove(ready, 1)
    local msg = id and GRB.Messages:Get(id)
    while id and (not msg or msg.target ~= "channel" or not msg.broadcast) do
        id = tremove(ready, 1)
        msg = id and GRB.Messages:Get(id)
    end
    if not msg then
        GRB:Print(L["No broadcast is ready yet."])
        self:Notify()
        return false
    end

    Reschedule(msg)
    self:Notify()

    local channelId = self:FindChannel(msg.channel)
    if not channelId then
        GRB:Printf(L["Channel \"%s\" is not joined; skipped \"%s\"."], msg.channel ~= "" and msg.channel or "?", msg.name)
        return false
    end

    local result = GRB.Messages:Validate(msg.text, GRB.Messages:GetBaseContext())
    if not result.ok or #result.unresolved > 0 or #result.unknown > 0 then
        GRB:Printf(L["\"%s\" was not sent: the text is empty, too long or has unset placeholders."], msg.name)
        return false
    end

    SendChatMessage(result.rendered, "CHANNEL", nil, channelId)
    return true
end

-- Dismisses the oldest ready message until its next interval
function Broadcast:SkipNext()
    local id = tremove(ready, 1)
    local msg = id and GRB.Messages:Get(id)
    if msg then
        Reschedule(msg)
    end
    self:Notify()
end

function Broadcast:OnEnable()
    self:ScheduleRepeatingTimer("Tick", TICK)
end
