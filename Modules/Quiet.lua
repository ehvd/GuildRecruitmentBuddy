local GRB = GuildRecruitmentBuddy
local L = GRB.L

local Quiet = GRB:NewModule("Quiet", "AceEvent-3.0")
GRB.Quiet = Quiet

-- Quiet mode keeps recruiting out of the way while the player is busy: in combat, in dungeons, raids and
-- battlegrounds (each switchable), or when switched on manually with `/grb quiet on`. While it is active
--   * broadcasts are not marked ready and their popup is hidden,
--   * "ginv" requests are still queued, silently, and the invite popup waits,
--   * welcome whispers are held back until it ends.
-- Things the user does with a click (scanner, whispering from the Contacts tab, Send now) are never blocked.
local current              -- reason that was last announced to the listeners, nil = not quiet
local manual = false       -- switched on by the user for this session
local listeners = {}

local function Settings()
    return GRB.db.profile.quiet
end

-- Returns the reason quiet mode is active right now, or nil.
function Quiet:GetReason()
    if manual then
        return L["switched on manually"]
    end
    local settings = Settings()
    if not settings.enabled then return nil end

    if settings.combat and (InCombatLockdown() or UnitAffectingCombat("player")) then
        return L["in combat"]
    end

    local inInstance, kind = IsInInstance()
    if inInstance then
        if kind == "raid" then
            if settings.raids then return L["in a raid"] end
        elseif kind == "pvp" or kind == "arena" then
            if settings.battlegrounds then return L["in a battleground"] end
        elseif settings.dungeons then
            return L["in a dungeon"]
        end
    end
    return nil
end

function Quiet:IsQuiet()
    return self:GetReason() ~= nil
end

function Quiet:IsManual()
    return manual
end

function Quiet:SetManual(enabled)
    manual = enabled and true or false
    GRB:Printf(L["Manual quiet mode is now %s."], manual and L["on"] or L["off"])
    self:Refresh()
end

-- fn(reason) is called whenever quiet mode starts, changes reason or ends (reason == nil).
function Quiet:OnChange(fn)
    tinsert(listeners, fn)
end

function Quiet:Refresh()
    local reason = self:GetReason()
    if reason == current then return end
    current = reason
    for _, fn in ipairs(listeners) do
        fn(reason)
    end
end

-- Earlier development builds kept the combat / instance pause on the broadcast settings.
function Quiet:OnInitialize()
    local profile = GRB.db.profile
    if profile.quietMigrated then return end
    profile.quietMigrated = true

    local broadcast = profile.broadcast
    if broadcast.pauseInCombat == false then
        profile.quiet.combat = false
    end
    if broadcast.pauseInInstance == false then
        profile.quiet.dungeons, profile.quiet.raids, profile.quiet.battlegrounds = false, false, false
    end
    broadcast.pauseInCombat, broadcast.pauseInInstance = nil, nil
end

function Quiet:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Refresh")
    self:Refresh()
end
