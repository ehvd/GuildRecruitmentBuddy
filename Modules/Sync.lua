local ADDON_NAME = ...
local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Sync = GRB:NewModule("Sync", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0")
GRB.Sync = Sync

-- Shares the contact database between every guild member who can invite, so two recruiters never whisper
-- the same player. Only members with invite permission take part:
--   * a client announces itself on the guild addon channel ("hello") only when CanGuildInvite() is true and
--     only accepts data from clients that announced the same;
--   * the contacts themselves travel as direct addon whispers to those announced peers, never on the open
--     guild channel.
-- Each contact carries an `updated` time. The newest change wins (see Contacts:ApplyRemote). Catching up is
-- incremental: a client tells its peers up to which `updated` time it already has their data (`want`).
-- Deleting or purging contacts is local only.
local Serializer = LibStub("AceSerializer-3.0")

local PREFIX = "GRBSync"
local VERSION = 1
local CHUNK_SIZE = 60        -- contacts per message
local ANNOUNCE_DELAY = 10    -- seconds after login

local peers = {}             -- "Name-Realm" -> { lastSeen } recruiters that announced invite permission
local announced = false
local stats = { sent = 0, received = 0, lastReceived = nil }   -- this session

local function Settings()
    return GRB.db.profile.sync
end

local function State()
    return GRB.db.global.sync
end

local function MyKey()
    return GRB.Contacts:Key(UnitName("player"))
end

-- Peers the roster does not list as offline (unknown counts as online)
local function IsReachable(key)
    return GRB.Contacts:IsOnline(key) ~= false
end

function Sync:CanSync()
    if not Settings().enabled then
        return false, L["Officer sync is switched off."]
    end
    if not IsInGuild() then
        return false, L["You are not in a guild."]
    end
    if not CanGuildInvite() then
        return false, L["Officer sync needs guild invite permission."]
    end
    return true
end

function Sync:Changed()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(ADDON_NAME)
end

---------------------------------------------------------------------------
-- Wire format
---------------------------------------------------------------------------

local function Pack(contact)
    return {
        s = contact.status,
        t = contact.timestamp,
        c = contact.class,
        l = contact.level,
        n = contact.templateName,
        w = contact.whispered,
        u = GRB.Contacts:UpdatedOf(contact),
    }
end

-- Validates a received contact; returns the data for Contacts:ApplyRemote or nil.
local function Unpack(key, e)
    if type(key) ~= "string" or #key > 64 or not key:match("^[^%-]+%-[^%-]+$") then return nil end
    if type(e) ~= "table" then return nil end
    if type(e.s) ~= "string" or not GRB.Contacts.STATUS_LABELS[e.s] then return nil end
    if type(e.u) ~= "number" then return nil end
    return {
        status = e.s,
        timestamp = type(e.t) == "number" and e.t or nil,
        class = type(e.c) == "string" and strsub(e.c, 1, 24) or nil,
        level = type(e.l) == "number" and e.l >= 1 and e.l <= 80 and e.l or nil,
        templateName = type(e.n) == "string" and strsub(e.n, 1, 60) or nil,
        whispered = type(e.w) == "number" and e.w or nil,
        updated = e.u,
    }
end

-- target == nil sends on the guild addon channel, otherwise as an addon whisper
function Sync:Transmit(target, msg, priority)
    local text = Serializer:Serialize(msg)
    if target then
        self:SendCommMessage(PREFIX, text, "WHISPER", target, priority or "NORMAL")
    else
        self:SendCommMessage(PREFIX, text, "GUILD", nil, priority or "NORMAL")
    end
    stats.sent = stats.sent + 1
end

-- Sends every contact changed after `since` to a peer, in chunks
function Sync:SendContacts(peerKey, since)
    local contacts = GRB.Contacts
    local target = contacts:GetWhisperTarget(peerKey)
    local entries, count = {}, 0
    local function Flush()
        if count > 0 then
            self:Transmit(target, { t = "data", e = entries }, "BULK")
            entries, count = {}, 0
        end
    end
    for key, contact in pairs(GRB.db.global.contacts) do
        if contacts:UpdatedOf(contact) > since then
            entries[key] = Pack(contact)
            count = count + 1
            if count >= CHUNK_SIZE then Flush() end
        end
    end
    Flush()
end

---------------------------------------------------------------------------
-- Announcing and receiving
---------------------------------------------------------------------------

function Sync:Announce()
    self:Transmit(nil, { t = "hello", v = VERSION, inv = true, want = State().last })
end

function Sync:TryAnnounce()
    if announced or not self:CanSync() then return end
    announced = true
    self:Announce()
end

function Sync:OnHello(senderKey, msg)
    if msg.inv ~= true then return end
    peers[senderKey] = { lastSeen = GetTime() }

    -- Answer a broadcast hello so the newcomer learns about us (a reply is not answered again)
    if not msg.reply then
        self:Transmit(GRB.Contacts:GetWhisperTarget(senderKey), {
            t = "hello", v = VERSION, inv = true, reply = true, want = State().last,
        })
    end

    -- Send what the peer is missing: everything we changed since the time it last received from us
    local since = (type(msg.want) == "table" and tonumber(msg.want[MyKey()])) or 0
    self:SendContacts(senderKey, since)
    self:Changed()
end

function Sync:OnData(senderKey, msg)
    if not peers[senderKey] or type(msg.e) ~= "table" then return end

    local state = State()
    local applied, newest = 0, state.last[senderKey] or 0
    for key, e in pairs(msg.e) do
        local data = Unpack(key, e)
        if data then
            if GRB.Contacts:ApplyRemote(key, data) then
                applied = applied + 1
            end
            newest = max(newest, data.updated)
        end
    end
    state.last[senderKey] = newest

    if applied > 0 then
        stats.received = stats.received + applied
        stats.lastReceived = GetServerTime()
    end
    self:Changed()
end

function Sync:OnComm(prefix, message, _, sender)
    if prefix ~= PREFIX or not self:CanSync() then return end
    local senderKey = GRB.Contacts:Key(sender)
    if not senderKey or senderKey == MyKey() then return end

    local ok, msg = Serializer:Deserialize(message)
    if not ok or type(msg) ~= "table" then return end

    if msg.t == "hello" then
        self:OnHello(senderKey, msg)
    elseif msg.t == "data" or msg.t == "upd" then
        self:OnData(senderKey, msg)
    end
end

-- Called by Contacts:Touch when a contact changed on this client: tell the online peers right away
function Sync:OnLocalChange(key)
    if not next(peers) or not self:CanSync() then return end
    local contact = GRB.db.global.contacts[key]
    if not contact then return end

    local msg = { t = "upd", e = { [key] = Pack(contact) } }
    for peerKey in pairs(peers) do
        if IsReachable(peerKey) then
            self:Transmit(GRB.Contacts:GetWhisperTarget(peerKey), msg)
        end
    end
end

-- Forgets what was received before and exchanges everything with every online recruiter in both directions.
function Sync:ForceSync()
    local ok, reason = self:CanSync()
    if not ok then
        GRB:Print(reason)
        return false
    end

    wipe(State().last)
    self:Announce()   -- peers answer with all their contacts because `want` is empty
    for peerKey in pairs(peers) do
        if IsReachable(peerKey) then
            self:SendContacts(peerKey, 0)
        end
    end
    GRB:Print(L["Full sync started. Contacts are exchanged with every online recruiter."])
    self:Changed()
    return true
end

---------------------------------------------------------------------------
-- Status
---------------------------------------------------------------------------

function Sync:GetPeerNames()
    local names = {}
    for key in pairs(peers) do
        if IsReachable(key) then
            tinsert(names, (GRB.Contacts:SplitKey(key)))
        end
    end
    table.sort(names)
    return names
end

function Sync:GetSummary()
    local ok, reason = self:CanSync()
    if not ok then return reason end

    local names = self:GetPeerNames()
    local lines = {
        format(L["Online recruiters with the addon: %s"], #names > 0 and table.concat(names, ", ") or L["none"]),
        format(L["This session: %d contact change(s) received, %d message(s) sent."], stats.received, stats.sent),
    }
    if stats.lastReceived then
        tinsert(lines, format(L["Last change received at %s."], date("%H:%M:%S", stats.lastReceived)))
    end
    return table.concat(lines, "\n")
end

function Sync:OnEnable()
    self:RegisterComm(PREFIX, "OnComm")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "TryAnnounce")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", function()
        announced = false
        wipe(peers)
        self:TryAnnounce()
    end)
    self:ScheduleTimer("TryAnnounce", ANNOUNCE_DELAY)
end
