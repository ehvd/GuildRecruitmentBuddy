local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Contacts = GRB:NewModule("Contacts", "AceEvent-3.0")
GRB.Contacts = Contacts

local DAY = 86400
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

local RECORD_FIELDS = { "class", "level", "timestamp", "templateId", "templateName", "status" }

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
    return contact, key
end

function Contacts:SetStatus(name, status)
    if not STATUS_INDEX[status] then return false end
    local contact = self:Get(name)
    if contact then
        contact.status = status
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
    if not IsInGuild() then return end
    for i = 1, (GetNumGuildMembers()) do
        local name = GetGuildRosterInfo(i)
        local key = name and self:Key(name)
        if key then
            guildKeys[key] = true
        end
    end
end

function Contacts:OnWhisper(_, _, sender)
    local contact = self:Get(sender)
    if contact and contact.status == "contacted" then
        contact.status = "replied"
    end
end

function Contacts:OnEnable()
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "RebuildGuildCache")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "RequestRoster")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestRoster")
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RequestRoster()
end
