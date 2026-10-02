local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Scanner = GRB:NewModule("Scanner", "AceEvent-3.0", "AceTimer-3.0")
GRB.Scanner = Scanner

-- C_FriendList.SendWho needs a hardware event and the server throttles and caps /who (about 49 results),
-- so the scan is a queue of small class/level queries; RunNext() runs exactly one and must be called from a click.
-- A query that returns a full page is split in half and re-queued until it fits (or is a single level).
local MAX_RESULTS = 49
local SLICE = 10             -- initial level slice width
local MIN_INTERVAL = 5       -- seconds between queries (server throttle)
local RESPONSE_TIMEOUT = 8   -- seconds to wait for WHO_LIST_UPDATE
local MAX_RETRIES = 2

-- Classic Era races per faction (client race tokens), with the race ids for C_CreatureInfo and which classes
-- each race can play, so a race selection does not queue impossible combinations such as Human Shaman.
Scanner.FACTION_RACES = {
    Alliance = { "Human", "Dwarf", "NightElf", "Gnome" },
    Horde = { "Orc", "Scourge", "Tauren", "Troll" },
}
local RACE_IDS = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5, Tauren = 6, Gnome = 7, Troll = 8 }
local RACE_NAMES = {   -- fallback when the client cannot tell the localized name
    Human = "Human", Orc = "Orc", Dwarf = "Dwarf", NightElf = "Night Elf",
    Scourge = "Undead", Tauren = "Tauren", Gnome = "Gnome", Troll = "Troll",
}
local RACE_CLASSES = {
    Human = { WARRIOR = true, PALADIN = true, ROGUE = true, PRIEST = true, MAGE = true, WARLOCK = true },
    Dwarf = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true },
    NightElf = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, DRUID = true },
    Gnome = { WARRIOR = true, ROGUE = true, MAGE = true, WARLOCK = true },
    Orc = { WARRIOR = true, HUNTER = true, ROGUE = true, SHAMAN = true, WARLOCK = true },
    Scourge = { WARRIOR = true, ROGUE = true, PRIEST = true, MAGE = true, WARLOCK = true },
    Tauren = { WARRIOR = true, HUNTER = true, SHAMAN = true, DRUID = true },
    Troll = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true },
}

local queue = {}      -- pending queries: { token, class, raceToken, race, lo, hi, zone, retries }
local results = {}    -- guildless players found: { key, name, class, token, level, zone }
local seen = {}       -- "Name-Realm" -> true
local stats = {}
local pending         -- query that was sent and awaits WHO_LIST_UPDATE
local nextAllowed = 0
local timeoutTimer

local engaged = false
local friendsFrameWasRegistered = false

local function ResetStats()
    stats.queries = 0     -- queries sent
    stats.scanned = 0     -- players returned by /who
    stats.found = 0       -- guildless players
    stats.capped = 0      -- single-level queries that still returned a full page
    stats.failed = 0      -- queries that got no response
end
ResetStats()

---------------------------------------------------------------------------
-- Who UI suppression (restored after every query)
---------------------------------------------------------------------------

-- Results are delivered as WHO_LIST_UPDATE only when SetWhoToUi(true); FriendsFrame would pop up for it,
-- so it stops listening while a scanner query is in flight. There is no getter, so the default (false) is restored.
local function Engage()
    if engaged then return end
    engaged = true
    C_FriendList.SetWhoToUi(true)
    if FriendsFrame and FriendsFrame:IsEventRegistered("WHO_LIST_UPDATE") then
        friendsFrameWasRegistered = true
        FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
    end
end

local function Disengage()
    if not engaged then return end
    engaged = false
    C_FriendList.SetWhoToUi(false)
    if friendsFrameWasRegistered then
        friendsFrameWasRegistered = false
        FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
    end
end

---------------------------------------------------------------------------
-- Known guilds
---------------------------------------------------------------------------

-- Every player a /who returns (guilded or not) is remembered for a while, so the right-click menu
-- (UI/ContextMenu.lua) can tell whether a name from chat or the friends list is guildless.
local GUILD_CACHE_TTL = 1800    -- seconds
local GUILD_CACHE_MAX = 2000
local guildCache = {}           -- "Name-Realm" -> { guild = "Name" or false (guildless), at = GetTime() }
local guildCacheSize = 0

function Scanner:RememberGuild(key, guild)
    if not key then return end
    if not guildCache[key] then
        guildCacheSize = guildCacheSize + 1
        if guildCacheSize > GUILD_CACHE_MAX then
            wipe(guildCache)
            guildCacheSize = 1
        end
    end
    guildCache[key] = { guild = guild, at = GetTime() }
end

-- Returns the guild name of a player when it is known, false when the player is known to be guildless and nil
-- when nothing is known. A visible unit (target, party member, ...) tells its guild directly.
function Scanner:GetKnownGuild(key, unit)
    if GRB.Contacts:IsInGuild(key) then
        return (GetGuildInfo("player")) or true
    end
    if unit and UnitExists(unit) and UnitIsPlayer(unit) and UnitIsVisible(unit) then
        return (GetGuildInfo(unit)) or false
    end
    local entry = guildCache[key]
    if entry and GetTime() - entry.at < GUILD_CACHE_TTL then
        return entry.guild
    end
    return nil
end

---------------------------------------------------------------------------
-- Queue
---------------------------------------------------------------------------

-- Race tokens of the player's own faction (the only ones /who can find)
function Scanner:GetRaces()
    return Scanner.FACTION_RACES[UnitFactionGroup("player")] or {}
end

-- Localized race name, as used by /who r-"..." and returned by GetWhoInfo
function Scanner:GetRaceName(token)
    local id = RACE_IDS[token]
    local info = id and C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(id)
    return (info and info.raceName) or RACE_NAMES[token] or token
end

local function BuildFilter(query)
    local filter = format("c-\"%s\"", query.class)
    if query.race then
        filter = filter .. format(" r-\"%s\"", query.race)
    end
    if query.lo == query.hi then
        filter = filter .. " " .. query.lo
    else
        filter = filter .. format(" %d-%d", query.lo, query.hi)
    end
    if query.zone and query.zone ~= "" then
        filter = filter .. format(" z-\"%s\"", query.zone)
    end
    return filter
end

function Scanner:DescribeQuery(query)
    local range = query.lo == query.hi and tostring(query.lo) or (query.lo .. "-" .. query.hi)
    return format("%s%s %s", query.race and (query.race .. " ") or "", query.class, range)
end

function Scanner:Notify()
    if self.onUpdate then self.onUpdate() end
end

function Scanner:Reset()
    wipe(queue)
    wipe(results)
    wipe(seen)
    ResetStats()
    pending = nil
    if timeoutTimer then
        self:CancelTimer(timeoutTimer)
        timeoutTimer = nil
    end
    Disengage()
    self:Notify()
end

-- opts: { classes = { [TOKEN] = true }, races = { [RACE_TOKEN] = true } (empty = every race), minLevel, maxLevel, zone }.
-- Replaces the queue and results. With a race selection each query asks for one race (r-"Race"), so a busy
-- class does not hide the wanted race behind the 49-result cap; combinations the race cannot play are skipped.
-- Returns the number of queries.
function Scanner:Start(opts)
    self:Reset()
    local zone = strtrim((gsub(opts.zone or "", "\"", "")))

    local factionRaces = self:GetRaces()
    local races = {}
    for _, raceToken in ipairs(factionRaces) do
        if opts.races and opts.races[raceToken] then
            tinsert(races, raceToken)
        end
    end
    -- Nothing selected, or every race selected: no race filter at all
    if #races == 0 or #races == #factionRaces then
        races = { false }
    end

    for _, token in ipairs(GRB.CLASSES) do
        if opts.classes[token] then
            local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
            for _, raceToken in ipairs(races) do
                if not raceToken or RACE_CLASSES[raceToken][token] then
                    for lo = opts.minLevel, opts.maxLevel, SLICE do
                        tinsert(queue, {
                            token = token,
                            class = className,
                            raceToken = raceToken or nil,
                            race = raceToken and self:GetRaceName(raceToken) or nil,
                            lo = lo,
                            hi = min(lo + SLICE - 1, opts.maxLevel),
                            zone = zone,
                            retries = 0,
                        })
                    end
                end
            end
        end
    end
    self:Notify()
    return #queue
end
function Scanner:GetQueueSize()
    return #queue
end

function Scanner:GetNextQuery()
    return queue[1]
end

function Scanner:GetResults()
    return results
end

function Scanner:GetStats()
    return stats
end

function Scanner:IsWaiting()
    return pending ~= nil
end

-- Returns true, or false and the reason why the next query cannot run now.
function Scanner:CanRun()
    if pending then
        return false, L["Waiting for the server..."]
    end
    if #queue == 0 then
        return false, L["The queue is empty. Start a new scan."]
    end
    local wait = nextAllowed - GetTime()
    if wait > 0 then
        return false, format(L["Wait %d s (server throttle)."], ceil(wait))
    end
    return true
end

-- Must be called from a click (hardware event).
function Scanner:RunNext()
    local ok, reason = self:CanRun()
    if not ok then return false, reason end

    pending = tremove(queue, 1)
    Engage()
    nextAllowed = GetTime() + MIN_INTERVAL
    stats.queries = stats.queries + 1
    C_FriendList.SendWho(BuildFilter(pending))
    timeoutTimer = self:ScheduleTimer("OnTimeout", RESPONSE_TIMEOUT)
    self:Notify()
    return true
end

-- Looks one player up with /who n-"Name" to learn their guild. Must be called from a click (hardware event).
-- callback(guild): the guild name, false when the player is guildless, nil when the player was not found
-- (offline) or the server did not answer. Returns true, or false and the reason it cannot run now.
function Scanner:LookupPlayer(name, callback)
    local key = GRB.Contacts:Key(name)
    if not key then return false, L["Enter a player name."] end
    if pending then
        return false, L["Waiting for the server..."]
    end
    local wait = nextAllowed - GetTime()
    if wait > 0 then
        return false, format(L["Wait %d s (server throttle)."], ceil(wait))
    end

    pending = { lookup = true, key = key, callback = callback }
    Engage()
    nextAllowed = GetTime() + MIN_INTERVAL
    C_FriendList.SendWho(format("n-\"%s\"", (GRB.Contacts:SplitKey(key))))
    timeoutTimer = self:ScheduleTimer("OnTimeout", RESPONSE_TIMEOUT)
    self:Notify()
    return true
end

---------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------

local function AddResult(info)
    local key = GRB.Contacts:Key(info.fullName)
    if not key or seen[key] then return end
    seen[key] = true
    stats.found = stats.found + 1
    tinsert(results, {
        key = key,
        name = (GRB.Contacts:SplitKey(key)),
        class = info.classStr,
        race = info.raceStr,
        token = info.filename,
        level = info.level,
        zone = info.area,
    })
end

-- A copy of a query for part of its level range (same class, race and zone)
local function Half(query, lo, hi)
    return {
        token = query.token, class = query.class, raceToken = query.raceToken, race = query.race,
        lo = lo, hi = hi, zone = query.zone, retries = 0,
    }
end

function Scanner:OnWhoListUpdate()
    local query = pending
    if not query then return end
    pending = nil
    if timeoutTimer then
        self:CancelTimer(timeoutTimer)
        timeoutTimer = nil
    end

    local count = C_FriendList.GetNumWhoResults()
    local found, foundGuild   -- answer of a single-player lookup
    for i = 1, count do
        local info = C_FriendList.GetWhoInfo(i)
        if info then
            local key = GRB.Contacts:Key(info.fullName)
            local guild = (info.fullGuildName and info.fullGuildName ~= "") and info.fullGuildName or false
            self:RememberGuild(key, guild)
            if query.lookup then
                if key == query.key then found, foundGuild = true, guild end
            else
                stats.scanned = stats.scanned + 1
                if not guild then
                    AddResult(info)
                end
            end
        end
    end
    Disengage()

    if query.lookup then
        -- guild name / false (guildless) when the player was found, nil when not (a plain 'and/or' would turn false into nil)
        local result
        if found then result = foundGuild end
        query.callback(result)
        self:Notify()
        return
    end
    -- A full page means players were cut off: split the level range and query both halves next.
    if count >= MAX_RESULTS then
        if query.lo < query.hi then
            local mid = floor((query.lo + query.hi) / 2)
            tinsert(queue, 1, Half(query, mid + 1, query.hi))
            tinsert(queue, 1, Half(query, query.lo, mid))
        else
            stats.capped = stats.capped + 1
        end
    end
    self:Notify()
end

function Scanner:OnTimeout()
    timeoutTimer = nil
    local query = pending
    pending = nil
    Disengage()
    if query and query.lookup then
        query.callback(nil)
    elseif query then
        stats.failed = stats.failed + 1
        if query.retries < MAX_RETRIES then
            query.retries = query.retries + 1
            tinsert(queue, 1, query)
        end
    end
    self:Notify()
end

function Scanner:OnEnable()
    self:RegisterEvent("WHO_LIST_UPDATE", "OnWhoListUpdate")
end
