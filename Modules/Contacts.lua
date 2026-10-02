local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Contacts = GRB:NewModule("Contacts", "AceEvent-3.0")
GRB.Contacts = Contacts

local DAY = 86400

-- A player only counts as contacted (for "stop" / "ginv" replies) for this long after the addon whispered them, and
-- contacts older than this are pruned on load (never "do-not-contact" or "joined", and never within the whisper cooldown).
Contacts.RETENTION_DAYS = 30
local ROSTER_REQUEST_INTERVAL = 20

Contacts.STATUSES = { "contacted", "replied", "invited", "joined", "declined", "do-not-contact" }
Contacts.STATUS_LABELS = {
    ["contacted"] = L["Contacted"],
    ["replied"] = L["Replied"],
    ["invited"] = L["Invited"],
    ["joined"] = L["Joined"],
    ["declined"] = L["Declined"],
    ["do-not-contact"] = L["Do not contact"],
}

local STATUS_INDEX = {}
for index, status in ipairs(Contacts.STATUSES) do
    STATUS_INDEX[status] = index
end

local guildKeys = {}       -- "Name-Realm" -> true for every member of our guild
local guildOnline = {}     -- "Name-Realm" -> true / false (online) for every member of our guild
local lastRosterRequest = 0

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

local function GetRealm()
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = (gsub(GetRealmName() or "", "[%s%-']", ""))
    end
    return realm
end

-- Normalizes a player name to the "Name-Realm" key used by the database.
function Contacts:Key(name)
    name = strtrim(name or "")
    if name == "" then return nil end
    local short, realm = strsplit("-", name, 2)
    if not short or short == "" then return nil end
    short = short:sub(1, 1):upper() .. short:sub(2):lower()
    if not realm or realm == "" then
        realm = GetRealm()
    end
    return short .. "-" .. realm
end

function Contacts:SplitKey(key)
    return strsplit("-", key, 2)
end

-- Whispers to players on our own realm use the short name, others the full key.
function Contacts:GetWhisperTarget(key)
    local short, realm = self:SplitKey(key)
    if realm == GetRealm() then return short end
    return key
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------

function Contacts:Get(name)
    local key = self:Key(name)
    return key and GRB.db.global.contacts[key] or nil, key
end

local RECORD_FIELDS = { "class", "level", "timestamp", "templateId", "templateName", "status", "whispered" }

-- Creates or updates a contact. info may contain class, level, timestamp, templateId, templateName, status.
function Contacts:Record(name, info)
    local key = self:Key(name)
    if not key then return nil end
    local contacts = GRB.db.global.contacts
    local contact = contacts[key]
    if not contact then
        local short, realm = self:SplitKey(key)
        contact = { name = short, realm = realm, status = "contacted" }
        contacts[key] = contact
    end
    for _, field in ipairs(RECORD_FIELDS) do
        if info and info[field] ~= nil then
            contact[field] = info[field]
        end
    end
    self:Touch(key)
    return contact, key
end

-- Marks a contact as changed locally: stamps it for the officer sync and shares it with the other recruiters.
function Contacts:Touch(key)
    local contact = GRB.db.global.contacts[key]
    if not contact then return end
    contact.updated = GetServerTime()
    if GRB.Sync then GRB.Sync:OnLocalChange(key) end
end

-- When a contact was last changed (contacts from before the sync existed fall back to the last contact time)
function Contacts:UpdatedOf(contact)
    return contact.updated or contact.timestamp or 0
end

-- Applies a contact received from another recruiter. The newest change wins; on a tie the status that
-- protects the player best (higher in STATUSES, do-not-contact last) wins. Does not touch the sync again.
-- data: { status, timestamp, class, level, templateName, updated }. Returns true when it changed anything.
function Contacts:ApplyRemote(key, data)
    local contacts = GRB.db.global.contacts
    local contact = contacts[key]
    if contact then
        local localUpdated = self:UpdatedOf(contact)
        if data.updated < localUpdated then return false end
        if data.updated == localUpdated and (STATUS_INDEX[data.status] or 0) <= (STATUS_INDEX[contact.status] or 0) then
            return false
        end
    else
        local short, realm = self:SplitKey(key)
        contact = { name = short, realm = realm }
        contacts[key] = contact
    end
    contact.status = data.status
    contact.timestamp = data.timestamp
    contact.class = data.class
    contact.level = data.level
    contact.templateName = data.templateName
    contact.whispered = data.whispered
    contact.updated = data.updated
    return true
end

function Contacts:SetStatus(name, status)
    if not STATUS_INDEX[status] then return false end
    local contact, key = self:Get(name)
    if contact then
        contact.status = status
        self:Touch(key)
    else
        self:Record(name, { status = status, timestamp = GetServerTime() })
    end
    return true
end

function Contacts:Delete(name)
    local key = self:Key(name)
    if key and GRB.db.global.contacts[key] then
        GRB.db.global.contacts[key] = nil
        return true
    end
    return false
end

-- Removes contacts last contacted more than `days` days ago. "Do not contact" entries are kept
-- so a purge never makes it possible to whisper someone who asked not to be contacted.
function Contacts:Purge(days)
    local cutoff = GetServerTime() - days * DAY
    local contacts = GRB.db.global.contacts
    local removed = 0
    for key, contact in pairs(contacts) do
        if contact.status ~= "do-not-contact" and (contact.timestamp or 0) < cutoff then
            contacts[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

---------------------------------------------------------------------------
-- Opt-out list and "contacted" gate
---------------------------------------------------------------------------

-- The opt-out list is the set of contacts with the do-not-contact status: account-wide, keyed "Name-Realm",
-- shared with the other recruiters by the officer sync. The addon never whispers them.
function Contacts:IsOptedOut(key)
    local contact = key and GRB.db.global.contacts[key]
    return contact ~= nil and contact.status == "do-not-contact"
end

-- When the addon last whispered the player. Contacts from before the "whispered" field existed fall back to
-- the template name, which only Whisper:Send records.
local function WhisperedAt(contact)
    return contact.whispered or (contact.templateName and contact.timestamp) or nil
end

-- true when the addon itself whispered this player recently (see RETENTION_DAYS), they have not opted out and
-- they are not guild members yet. Only such players may trigger "stop" / "ginv" handling: anyone else sending
-- those words is ignored completely.
function Contacts:IsKeywordEligible(key)
    local contact = key and GRB.db.global.contacts[key]
    if not contact or contact.status == "do-not-contact" or contact.status == "joined" then
        return false
    end
    local whispered = WhisperedAt(contact)
    return whispered ~= nil and GetServerTime() - whispered <= self.RETENTION_DAYS * DAY
end

-- Puts a player on the opt-out list (creating the contact when needed). guid is optional.
function Contacts:OptOut(name, guid)
    local key = self:Key(name)
    if not key then return nil end
    self:SetStatus(key, "do-not-contact")
    local contact = GRB.db.global.contacts[key]
    contact.optedOutAt = GetServerTime()
    if guid and guid ~= "" then contact.guid = guid end
    return key
end

-- Takes a player off the opt-out list again. They are neutral afterwards: the whisper cooldown applies and
-- they have to be whispered again before "stop" / "ginv" are handled for them. Returns false when not listed.
function Contacts:RemoveOptOut(name)
    local contact, key = self:Get(name)
    if not contact or contact.status ~= "do-not-contact" then return false end
    contact.status = "declined"
    contact.optedOutAt = nil
    self:Touch(key)
    return true
end

-- Returns an array of { key, contact } for every opted-out player, sorted by name
function Contacts:GetOptedOut()
    local list = {}
    for key, contact in pairs(GRB.db.global.contacts) do
        if contact.status == "do-not-contact" then
            tinsert(list, { key = key, contact = contact })
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return list
end

-- Deletes contacts that have not been touched for a long time so the table does not grow forever.
-- Opted-out players and guild members are kept, and so is anything inside the whisper cooldown.
function Contacts:PruneStale()
    local days = max(self.RETENTION_DAYS, GRB.db.profile.cooldownDays)
    local cutoff = GetServerTime() - days * DAY
    local contacts = GRB.db.global.contacts
    for key, contact in pairs(contacts) do
        if contact.status ~= "do-not-contact" and contact.status ~= "joined"
            and max(contact.timestamp or 0, contact.updated or 0) < cutoff then
            contacts[key] = nil
        end
    end
end
local function SortValue(entry, sortKey)
    local contact = entry.contact
    if sortKey == "name" then
        return entry.key:lower()
    elseif sortKey == "class" then
        return (contact.class or ""):lower()
    elseif sortKey == "level" then
        return contact.level or 0
    elseif sortKey == "status" then
        return STATUS_INDEX[contact.status] or 0
    end
    return contact.timestamp or 0
end

-- Returns an array of { key = "Name-Realm", contact = {...} }, filtered by status ("all" or nil for everything).
function Contacts:GetList(filter, sortKey, ascending)
    local list = {}
    for key, contact in pairs(GRB.db.global.contacts) do
        if not filter or filter == "all" or contact.status == filter then
            tinsert(list, { key = key, contact = contact })
        end
    end
    table.sort(list, function(a, b)
        local va, vb = SortValue(a, sortKey), SortValue(b, sortKey)
        if va ~= vb then
            if ascending then return va < vb end
            return va > vb
        end
        return a.key < b.key
    end)
    return list
end

---------------------------------------------------------------------------
-- Eligibility
---------------------------------------------------------------------------

function Contacts:IsInGuild(name)
    local key = self:Key(name)
    return key ~= nil and guildKeys[key] == true
end

-- Returns true, or false and a human readable reason why the player must not be whispered.
function Contacts:CanContact(name)
    local key = self:Key(name)
    if not key then
        return false, L["Enter a player name."]
    end
    local short = self:SplitKey(key)
    if key == self:Key(UnitName("player")) then
        return false, L["That is you."]
    end
    if guildKeys[key] then
        return false, format(L["%s is already in our guild."], short)
    end
    if GRB.OptOut:IsPending(key) then
        return false, format(L["%s asked to stop; decide on the opt-out request first."], short)
    end

    local contact = GRB.db.global.contacts[key]
    if not contact then return true end

    if contact.status == "do-not-contact" then
        return false, format(L["%s is marked do-not-contact."], short)
    end
    if contact.status == "joined" then
        return false, format(L["%s has already joined."], short)
    end

    local cooldownDays = GRB.db.profile.cooldownDays
    if cooldownDays > 0 and contact.timestamp then
        local remaining = contact.timestamp + cooldownDays * DAY - GetServerTime()
        if remaining > 0 then
            return false, format(L["%s was contacted recently. Cooldown ends in %d day(s)."], short, ceil(remaining / DAY))
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Guild roster cache and events
---------------------------------------------------------------------------

function Contacts:RequestRoster()
    if not IsInGuild() then return end
    local now = GetTime()
    if now - lastRosterRequest < ROSTER_REQUEST_INTERVAL then return end
    lastRosterRequest = now
    local requestRoster = (C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
    requestRoster()
end

function Contacts:RebuildGuildCache()
    wipe(guildKeys)
    wipe(guildOnline)
    if not IsInGuild() then return end
    for i = 1, (GetNumGuildMembers()) do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        local key = name and self:Key(name)
        if key then
            guildKeys[key] = true
            guildOnline[key] = online and true or false
        end
    end
end

-- true / false when the guild roster says the member is online / offline, nil when unknown
function Contacts:IsOnline(key)
    return guildOnline[key]
end

function Contacts:OnWhisper(_, _, sender, ...)
    local contact, key = self:Get(sender)
    local guid = select(10, ...)
    if contact and guid and guid ~= "" then
        contact.guid = guid
    end
    if contact and contact.status == "contacted" then
        contact.status = "replied"
        self:Touch(key)
    end
end

function Contacts:OnEnable()
    self:PruneStale()
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "RebuildGuildCache")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "RequestRoster")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestRoster")
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RequestRoster()
end
