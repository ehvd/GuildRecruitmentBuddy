local L = LibStub("AceLocale-3.0"):NewLocale("GuildRecruitmentBuddy", "enUS", true)
if not L then return end

L["ADDON_NAME"] = "Guild Recruitment Buddy"
L["Open window"] = true
L["Settings"] = true
L["Auto invite (ginv)"] = true
L["Auto invite is now %s."] = true
L["on"] = true
L["off"] = true
L["Left-click: open window"] = true
L["Right-click: menu"] = true
L["The main window is not available yet."] = true
L["Scanner is not available yet."] = true
L["Show minimap button"] = true
L["General"] = true
L["Usage:"] = true
L["/grb - open the main window"] = true
L["/grb invite on|off - toggle keyword auto invite"] = true
L["/grb scan - open the scanner"] = true
L["/grb config - open settings"] = true

-- Settings
L["Discord link ({discord})"] = true
L["Guild name override ({guild})"] = true
L["Leave empty to use the name of your current guild."] = true

-- Messages
L["Messages"] = true
L["Message"] = true
L["New"] = true
L["Delete"] = true
L["Up"] = true
L["Down"] = true
L["Edit"] = true
L["Name"] = true
L["Send as"] = true
L["Whisper"] = true
L["Channel"] = true
L["Channel message"] = true
L["Message text"] = true
L["Placeholders: {name} {class} {level} {guild} {discord}"] = true
L["Preview"] = true
L["New message"] = true
L["Guild invite (whisper)"] = true
L["Hi {name}! {guild} is looking for more {class}s. Want to join us? Discord: {discord}"] = true
L["Delete message \"%s\"?"] = true
L["Too long by %d characters."] = true
L["Unknown placeholders: %s"] = true
L["Not set (see Settings): %s"] = true
