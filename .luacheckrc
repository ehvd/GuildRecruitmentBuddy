std = "lua51"
max_line_length = 140
codes = true
self = false

exclude_files = {
    "**/Libs/**",
    ".release/**",
}

-- Globals written by the addon (SavedVariables, binding/XML-referenced names)
globals = {
    "GuildRecruitmentBuddyDB",
    "GuildRecruitmentBuddy",
    "SLASH_GRB1",
    "SLASH_GRB2",
    "SlashCmdList",
    "StaticPopupDialogs",
    "BINDING_HEADER_GUILDRECRUITMENTBUDDY",
    "BINDING_NAME_GUILDRECRUITMENTBUDDY_SEND",
    "GuildRecruitmentBuddyMainFrame",
    "UISpecialFrames",
}

-- Globals only read by the addon (WoW API, Ace3 and shared libraries)
read_globals = {
    -- Lua / WoW extensions to the stdlib
    "strsplit", "strjoin", "strtrim", "strlower", "strupper", "strfind", "strmatch", "strsub",
    "strlen", "strrep", "gsub", "format", "tinsert", "tremove", "wipe", "tContains", "date", "time",
    "min", "max", "floor", "ceil", "mod", "abs", "random", "sort", "getn",

    -- Libraries
    "LibStub", "CreateFrame", "ChatThrottleLib",

    -- Frames / UI
    "UIParent", "GameTooltip", "StaticPopup_Show", "PlaySound", "PlaySoundFile", "SOUNDKIT",
    "InterfaceOptionsFrame_OpenToCategory", "Settings", "UIDropDownMenu_Initialize",
    "UIDropDownMenu_AddButton", "UIDropDownMenu_SetText", "UIDropDownMenu_SetWidth",
    "UIDropDownMenu_CreateInfo", "ToggleDropDownMenu", "CloseDropDownMenus", "EasyMenu",
    "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset", "FauxScrollFrame_OnVerticalScroll",
    "BackdropTemplateMixin", "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall",
    "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize",
    "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "DEFAULT_CHAT_FRAME",

    -- Game API
    "C_Timer", "C_FriendList", "C_GuildInfo", "C_ChatInfo",
    "SendChatMessage", "GetGuildInfo", "GetNumGuildMembers", "GetGuildRosterInfo",
    "GuildRoster", "IsInGuild", "CanGuildInvite", "GuildInvite", "GetRealmName", "GetBindingKey", "UnitAffectingCombat", "InterfaceOptionsFrame_OpenToCategory", "FriendsFrame", "GetPlayerInfoByGUID", "GetNormalizedRealmName", "UnitName",
    "UnitLevel", "UnitClass", "UnitFactionGroup", "GetServerTime", "GetTime", "GetLocale",
    "IsInInstance", "InCombatLockdown", "UnitIsAFK", "GetNumGroupMembers", "IsInRaid",
    "GetChannelList", "GetChannelName", "Ambiguate", "FlashClientIcon", "RAID_CLASS_COLORS",
    "LOCALIZED_CLASS_NAMES_MALE", "LOCALIZED_CLASS_NAMES_FEMALE", "CLASS_SORT_ORDER",
    "GetNumClasses", "GetClassInfo", "GetAddOnMetadata", "C_AddOns",
    "ACCEPT", "CANCEL", "GetCursorPosition", "Minimap", "MinimapCluster",
    "CHAT_MSG_WHISPER", "WHO_LIST_UPDATE",
}
