local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Broadcast = GRB:NewModule("Broadcast", "AceTimer-3.0")
GRB.Broadcast = Broadcast

-- A broadcast ENTRY sends one channel message (template) to one channel every N minutes, so the same message can be
-- broadcast to several channels by adding several entries. Entries live in profile.broadcastEntries:
--   { id, messageId, channel (base name, e.g. "Trade"), interval (minutes), active }
--
-- SendChatMessage to a CHANNEL needs a hardware event (see docs/CONSTRAINTS.md), so a timer can only mark an entry
-- as "ready". The user then presses the keybind (Bindings.xml), `/grb send` or the button of the ready popup
-- (UI/BroadcastFrame.lua); SendEntry() runs inside that click/keypress and calls SendChatMessage directly
-- (ChatThrottleLib would defer the call to OnUpdate and lose the hardware event).
Broadcast.DEFAULT_INTERVAL = 10   -- minutes
Broadcast.MAX_INTERVAL = 60

local TICK = 1
local MAX_CHANNELS = 10

local nextDue = {}   -- entry id -> GetTime() when it becomes ready again (nil = ready as soon as possible)
local ready = {}     -- ids of entries that are ready to be sent, oldest first

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

local function Reschedule(entry)
    nextDue[entry.id] = GetTime() + entry.interval * 60
end

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------

function Broadcast:GetEntries()
    return GRB.db.profile.broadcastEntries
end

function Broadcast:GetEntry(id)
    for _, entry in ipairs(GRB.db.profile.broadcastEntries) do
        if entry.id == id then return entry end
    end
end

-- The channel message an entry sends, or nil when it was deleted or is no longer a channel message
function Broadcast:GetMessage(entry)
    local msg = GRB.Messages:Get(entry.messageId)
    if msg and msg.target == "channel" then
        return msg
    end
end

function Broadcast:AddEntry(messageId)
    local profile = GRB.db.profile
    local entry = {
        id = profile.nextBroadcastId,
        messageId = messageId,
        channel = "",
        interval = self.DEFAULT_INTERVAL,
        active = false,
    }
    profile.nextBroadcastId = profile.nextBroadcastId + 1
    tinsert(profile.broadcastEntries, entry)
    self:Notify()
    return entry
end

-- fields may contain messageId, channel, interval and active. Enabling, retargeting or changing the channel
-- restarts the timer; a shorter interval applies to the running countdown at once, a longer one from the next send.
function Broadcast:UpdateEntry(id, fields)
    local entry = self:GetEntry(id)
    if not entry then return nil end
    if fields.messageId ~= nil then entry.messageId = fields.messageId end
    if fields.channel ~= nil then entry.channel = strtrim(fields.channel) end
    if fields.interval ~= nil then
        entry.interval = min(max(floor(fields.interval), 1), self.MAX_INTERVAL)
    end
    if fields.active ~= nil then entry.active = fields.active and true or false end

    if fields.active ~= nil or fields.messageId ~= nil or fields.channel ~= nil then
        nextDue[id] = nil
    elseif fields.interval ~= nil and nextDue[id] then
        nextDue[id] = min(nextDue[id], GetTime() + entry.interval * 60)
    end
    if not entry.active then RemoveReady(id) end
    self:Notify()
    return entry
end

function Broadcast:DeleteEntry(id)
    local entries = GRB.db.profile.broadcastEntries
    for i, entry in ipairs(entries) do
        if entry.id == id then
            tremove(entries, i)
            nextDue[id] = nil
            RemoveReady(id)
            self:Notify()
            return true
        end
    end
    return false
end

-- Called when a message template is deleted
function Broadcast:OnMessageDeleted(messageId)
    local entries = GRB.db.profile.broadcastEntries
    for i = #entries, 1, -1 do
        if entries[i].messageId == messageId then
            self:DeleteEntry(entries[i].id)
        end
    end
end

-- Moves the per-message broadcast settings of earlier development builds (channel, interval, broadcast on the
-- message itself) into entries.
function Broadcast:OnInitialize()
    local profile = GRB.db.profile
    if profile.broadcastMigrated then return end
    profile.broadcastMigrated = true
    for _, msg in ipairs(profile.messages) do
        if msg.target == "channel" and (msg.broadcast or (msg.channel and msg.channel ~= "")) then
            local entry = self:AddEntry(msg.id)
            entry.channel = msg.channel or ""
            entry.interval = msg.interval or self.DEFAULT_INTERVAL
            entry.active = msg.broadcast == true
        end
        msg.channel, msg.interval, msg.broadcast = nil, nil, nil
    end
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

-- Returns the reason broadcasting is paused right now, or nil: quiet mode (combat, dungeon, raid, battleground)
-- or AFK.
function Broadcast:GetPauseReason()
    local quiet = GRB.Quiet:GetReason()
    if quiet then
        return quiet
    end
    if Settings().pauseWhenAfk and UnitIsAFK("player") then
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

-- State of an entry. Returns one of
--   "invalid"   its message was deleted or is no longer a channel message
--   "inactive"  the entry is not set to broadcast
--   "off"       it is, but broadcasting is switched off
--   "paused"    broadcasting is paused (second return value: the reason)
--   "ready"     it can be sent now
--   "waiting"   cooling down (second return value: seconds until it is ready)
function Broadcast:GetState(id)
    local entry = self:GetEntry(id)
    if not entry or not self:GetMessage(entry) then
        return "invalid"
    end
    if not entry.active then
        return "inactive"
    end
    if not self:IsActive() then
        return "off"
    end
    local pause = self:GetPauseReason()
    if pause then
        return "paused", pause
    end
    local due = nextDue[id]
    if IsReady(id) or not due or GetTime() >= due then
        return "ready"
    end
    return "waiting", due - GetTime()
end

function Broadcast:Tick()
    if not self:IsActive() then return end

    if not self:GetPauseReason() then
        local now = GetTime()
        local added = false
        for _, entry in ipairs(self:GetEntries()) do
            if entry.active and self:GetMessage(entry) and not IsReady(entry.id) then
                local due = nextDue[entry.id]
                if not due or now >= due then
                    tinsert(ready, entry.id)
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

-- Must be called from a keypress or click. Sends the oldest ready entry.
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
    local entry = id and self:GetEntry(id)
    while id and not (entry and entry.active and self:GetMessage(entry)) do
        id = tremove(ready, 1)
        entry = id and self:GetEntry(id)
    end
    if not entry then
        GRB:Print(L["No broadcast is ready yet."])
        self:Notify()
        return false
    end
    return self:SendEntry(entry.id)
end

-- Must be called from a keypress or click. Sends an entry right now (even if it is not ready, inactive or
-- broadcasting is paused) and restarts its timer.
function Broadcast:SendEntry(id)
    local entry = self:GetEntry(id)
    local msg = entry and self:GetMessage(entry)
    if not msg then return false end

    RemoveReady(id)
    Reschedule(entry)
    self:Notify()

    local channelId = self:FindChannel(entry.channel)
    if not channelId then
        GRB:Printf(L["Channel \"%s\" is not joined; skipped \"%s\"."], entry.channel ~= "" and entry.channel or "?", msg.name)
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

-- Dismisses the oldest ready entry until its next interval
function Broadcast:SkipNext()
    local id = tremove(ready, 1)
    local entry = id and self:GetEntry(id)
    if entry then
        Reschedule(entry)
    end
    self:Notify()
end

function Broadcast:OnEnable()
    self:ScheduleRepeatingTimer("Tick", TICK)
    GRB.Quiet:OnChange(function() self:Notify() end)
end
