local GRB = GuildRecruitmentBuddy
local L = GRB.L

-- Adds a "GRB" section with a "Recruit" submenu to the right-click menu of players. The submenu lists the whisper
-- templates; choosing one sends it to that player through the normal whisper path (cooldown, opt-out list and
-- rate limit all apply). Uses the Blizzard Menu system: Menu.ModifyMenu(tag, callback) runs the callback every
-- time a menu with that tag is opened.
local ContextMenu = {}
GRB.ContextMenu = ContextMenu

-- Menus of players that can be recruited: chat names, target / focus, party and raid members, friends, ...
-- (a tag no menu ever uses is harmless)
local TAGS = {
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_WORLD_STATE_SCORE", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
}

-- Works out who the menu is for. Returns "Name-Realm", { class, level } (both may be unknown) and the unit token
-- when there is one, or nil when the menu is not for another player of our faction.
local function Resolve(contextData)
    local unit = contextData.unit
    local name, realm, class, level
    if unit and UnitExists(unit) then
        if not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") or UnitIsEnemy("player", unit) then return nil end
        name, realm = UnitFullName(unit)
        class = (UnitClass(unit))
        level = UnitLevel(unit)
    else
        name, realm = contextData.name, contextData.server
        local guid = contextData.guid
        if guid then class = (GetPlayerInfoByGUID(guid)) end
    end
    if not name or name == "" then return nil end
    if realm and realm ~= "" and not name:find("-", 1, true) then
        name = name .. "-" .. realm
    end
    return name, { class = class, level = (level and level > 0) and level or nil }, unit
end

local function SendTemplate(name, templateId, info)
    local sent, why = GRB.Whisper:Send(name, templateId, info)
    if sent then
        GRB:Printf(L["Whisper sent to %s."], (GRB.Contacts:SplitKey(GRB.Contacts:Key(name))))
    elseif why then
        GRB:Print(why)
    end
end

-- Whispers the template only to a guildless player. When the guild is not known yet (a name from chat or the
-- friends list) the player is looked up with /who first; the click on the menu entry is the hardware event that
-- needs. Every /who answer is remembered, so the next menu already knows.
local function Recruit(name, templateId, info, unit)
    local key = GRB.Contacts:Key(name)
    local short = (GRB.Contacts:SplitKey(key))
    local guild = GRB.Scanner:GetKnownGuild(key, unit)
    if guild then
        GRB:Printf(L["%s is already in a guild; not whispering."], short)
        return
    elseif guild == false then
        SendTemplate(name, templateId, info)
        return
    end

    local ok, reason = GRB.Scanner:LookupPlayer(key, function(result)
        if result == nil then
            GRB:Printf(L["Could not find %s (offline?); not whispering."], short)
        elseif result then
            GRB:Printf(L["%s is in the guild <%s>; not whispering."], short, result)
        else
            SendTemplate(name, templateId, info)
        end
    end)
    if ok then
        GRB:Printf(L["Checking whether %s is in a guild..."], short)
    else
        GRB:Print(reason)
    end
end

local function Modify(_, rootDescription, contextData)
    if not GRB.db.profile.contextMenu then return end

    local name, info, unit = Resolve(contextData or {})
    if not name then return end
    local contacts = GRB.Contacts
    -- Only guildless players are recruited: hide the entry for anyone known to be in a guild
    if GRB.Scanner:GetKnownGuild(contacts:Key(name), unit) then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["GRB"])

    -- When the player cannot be whispered right now say why instead of offering the templates
    local ok, reason = contacts:CanContact(name)
    if not ok then
        rootDescription:CreateTitle("|cff999999" .. reason .. "|r")
        return
    end

    local recruit = rootDescription:CreateButton(L["Recruit"])
    local any = false
    for _, msg in ipairs(GRB.Messages:GetAll()) do
        if msg.target == "whisper" then
            any = true
            recruit:CreateButton(msg.name, function()
                Recruit(name, msg.id, info, unit)
            end)
        end
    end
    if not any then
        recruit:CreateTitle(L["No whisper templates yet."])
    end
end

if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(TAGS) do
        Menu.ModifyMenu(tag, function(...)
            -- A bug here must never break the game's own menu
            local ok, err = pcall(Modify, ...)
            if not ok then geterrorhandler()(err) end
        end)
    end
end
