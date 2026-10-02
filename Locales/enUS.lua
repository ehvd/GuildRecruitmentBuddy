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
L["Show minimap button"] = true
L["General"] = true
L["Usage:"] = true
L["/grb - open the main window"] = true
L["/grb invite on|off - toggle keyword auto invite"] = true
L["/grb scan - open the scanner"] = true
L["/grb config - open settings"] = true
L["/grb options - open the Blizzard options panel"] = true

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

-- Auto invite
L["Guild invite request"] = true
L["Invite"] = true
L["Skip"] = true
L["Invite %s (%s, level %s)?"] = true
L["%d more waiting"] = true
L["Invited %s to the guild."] = true
L["You do not have permission to invite players to the guild."] = true
L["Invited you to {guild}! Accept the invite to join."] = true
L["Auto-reply skipped: the reply text is empty, too long or has unset placeholders."] = true
L["Auto-reply skipped: %s"] = true
L["A keyword whisper queues an invite request. Click Invite in the popup to send it."] = true
L["Enable auto invite"] = true
L["Keywords (comma separated)"] = true
L["Matched as an exact word, case-insensitive."] = true
L["Minimum level (0 = off)"] = true
L["Only applied when the level is known from the contacts; a whisper does not include it."] = true
L["Allowed classes (none selected = all)"] = true
L["Per-player cooldown (minutes)"] = true
L["Repeated keywords from the same player are ignored for this long."] = true
L["Whisper the player when the invite is sent"] = true
L["Reply text"] = true

-- Scanner
L["Scanner"] = true
L["Finds players without a guild with /who. Blizzard allows one query per click: press Next query repeatedly."] = true
L["Minimum level"] = true
L["Maximum level"] = true
L["Zone (optional)"] = true
L["Whisper template"] = true
L["Start new scan"] = true
L["Reset"] = true
L["Players without a guild"] = true
L["Whisper all eligible"] = true
L["Block"] = true
L["New"] = true
L["Contacted %s (cooldown over)"] = true
L["Page %d / %d (%d players)"] = true
L["Next query (%d left)"] = true
L["Next: %s"] = true
L["Scan complete."] = true
L["Queries: %d. Players seen: %d. Without a guild: %d."] = true
L["%d single-level queries hit the result cap; some players may be missing."] = true
L["%d queries got no response from the server."] = true
L["Select at least one class."] = true
L["Scan prepared: %d queries. Press Next query to run them one by one."] = true
L["Whispered %d player(s)."] = true
L["Waiting for the server..."] = true
L["The queue is empty. Start a new scan."] = true
L["Wait %d s (server throttle)."] = true
