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

-- Contacts
L["Contacts"] = true
L["Contacted"] = true
L["Replied"] = true
L["Invited"] = true
L["Joined"] = true
L["Declined"] = true
L["Do not contact"] = true
L["All"] = true
L["Class"] = true
L["Level"] = true
L["Status"] = true
L["Last contacted"] = true
L["Filter by status"] = true
L["Purge older than (days)"] = true
L["Purge"] = true
L["Purged %d contact(s)."] = true
L["Delete all contacts last contacted more than %d days ago? (\"Do not contact\" entries are kept.)"] = true
L["Delete contact \"%s\"?"] = true
L["Page %d / %d (%d contacts)"] = true
L["Whisper a player"] = true
L["Player name"] = true
L["Send"] = true
L["Whisper sent to %s."] = true
L["adventurer"] = true

-- Whisper eligibility
L["Enter a player name."] = true
L["That is you."] = true
L["%s is already in our guild."] = true
L["%s is marked do-not-contact."] = true
L["%s has already joined."] = true
L["%s was contacted recently. Cooldown ends in %d day(s)."] = true
L["Select a message template."] = true
L["The selected template is not a whisper template."] = true
L["The player's level is unknown, but the template uses {level}."] = true
L["Message must be 1-%d characters (now %d)."] = true
L["Rate limit reached (%d whispers per minute). Try again in %d s."] = true

-- Settings
L["Whisper cooldown (days)"] = true
L["How long to wait before the same player can be whispered again. 0 disables the cooldown."] = true
L["Max whispers per minute"] = true
L["Session rate limit for whispers sent through the addon."] = true
