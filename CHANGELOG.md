# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2026-10-02

### Added
- Opt-out flow: when a player the addon whispered replies with an opt-out phrase such as "stop", a popup shows the message and asks whether to add the player to the do-not-contact list or skip. Adding sends one confirmation whisper ("Got it, you won't hear from me again...") and the addon never whispers the player again; a repeated "stop" gets no reply. The popup waits during quiet mode and can be switched off in Settings > Opt-out detection to add players automatically. The opt-out list is the account-wide do-not-contact list (keyed `Name-Realm`, with the GUID when known and the opt-out time), shared by the officer sync. `/grb optout list`, `add <name>` and `remove <name>` manage it by hand.
- Every whisper the addon sends now goes through one gate that silently skips opted-out players and players with an open opt-out request (only the confirmation to a player who has just opted out passes it).
- Scanner race filter: pick races of your own faction (none selected = all races); each selected race becomes its own `/who` query and combinations that cannot exist are skipped, with the usual splitting when a query returns a full page. The results show each player's race and can be filtered by it.

### Changed
- The reminder issue to update the CurseForge description now contains the Markdown in a code block with a copy button, and older open reminder issues are closed automatically when a newer one is opened.
- Opt-out phrases are only handled for players the addon itself whispered within the last 30 days; anyone else is ignored completely. New setting "Only invite players I have whispered" (off by default) in Settings > Auto invite does the same for "ginv".
- Contacts that were last touched more than 30 days ago (or longer than the whisper cooldown) are pruned on load; opted-out players and guild members are always kept.
- The default recruitment template asks "Looking for a guild?" and tells the player how to opt out; an unmodified copy of the old default is replaced once.

## [0.3.0] - 2026-10-02

### Added
- Officer sync: guild members who can invite and use the addon share the contact list automatically so two recruiters never whisper the same player. Each client announces itself on the guild addon channel only when it has invite permission and only accepts data from clients that did the same; the contacts travel as direct addon whispers. The newest change wins (do-not-contact wins a tie), catching up after login is incremental, and `/grb sync` or Settings > Officer sync forces a full resync. Deleting or purging contacts stays local.
- Quiet mode: recruiting stays out of the way in combat, dungeons, raids and battlegrounds (each switchable in Settings > Quiet mode) or when switched on by hand with `/grb quiet on|off` or the minimap menu. Broadcasts are not marked ready and their popup is hidden, "ginv" requests are queued silently and the invite popup waits, welcome whispers are held back until it ends. The window status bar and the minimap button (greyed out) show when it is active. The combat/instance pause of broadcasting moved here from the broadcast settings.
- Welcome flow: when someone joins the guild (detected from the client's own join message, so it works in every language) their contact is marked as joined and, if enabled, they get a welcome whisper (default: "Welcome to {guild}, {name}! Our Discord: {discord}") a few seconds later. Off by default; optionally only for players you contacted or invited; do-not-contact players are never welcomed or re-labelled.

### Changed
- The CurseForge description now lives in `docs/curseforge.md`; releases attach it to the GitHub release and `make description` copies it to the clipboard (CurseForge has no API to update it). When it changed since the previous release, the release workflow opens an issue assigned to the repository owner as the reminder to paste it.
- The project icon is now used for the minimap button and in the addon list (a round 128x128 texture in `Media/`).

## [0.2.0] - 2026-10-02

### Added
- Interval channel broadcasting, managed in the new Broadcast tab. Each broadcast sends one channel message to one channel (dropdown of the channels you have joined) at its own interval; add several broadcasts to send the same message to multiple channels. A timer marks a broadcast as ready and a popup, sound and key binding (`/grb send`) let you send it with the click Blizzard requires for channel messages. Each broadcast has an active checkbox, a live state and cooldown, Send now (sends immediately and restarts the timer) and Remove. Pauses in instances, combat and while AFK. Off by default; master switch in the tab, `/grb broadcast on|off`, the minimap menu or settings.
- The "Broadcast ready" popup has buttons to disable the shown broadcast or all broadcasting, and a cogwheel that opens the Broadcast tab.
- Opt-out detection: when a player you contacted replies with a configurable phrase (default: no thanks, not interested, stop, ...), they are marked do-not-contact automatically, with an optional chat notice. Single words only count at the start of a short reply and an exceptions list (default: no problem, no worries) avoids false positives.

### Changed
- The Messages tab is now only about writing message templates; channel, interval and on/off live in the Broadcast tab.
- Development tasks moved to a `Makefile` (`make libs`, `lint`, `install`, `link`, `uninstall`, `clean`), replacing `scripts/fetch-libs.ps1`.

### Fixed
- Right-click menu of the minimap button raised a Lua error because `EasyMenu` no longer exists in the client.
- Overlapping text in the Messages tab preview (counter and warning labels) and the same label layout problem in the Contacts and Scanner tabs.

## [0.1.0] - 2026-10-02

First release (MVP) for WoW Classic Era.

### Added
- Message templates: create, edit, delete and reorder named whisper/channel messages with `{name}` `{class}` `{level}` `{guild}` `{discord}` placeholders, 255-character validation and live preview.
- Contacted-player database shared across characters (keyed `Name-Realm`) with statuses (contacted, replied, invited, joined, declined, do-not-contact), configurable whisper cooldown (default 14 days), automatic skipping of guild members and an automatic `replied` status.
- Throttled whisper sending (ChatThrottleLib) with a per-session rate limit; the Contacts tab has a sortable, filterable list, status changes, delete, purge and a manual whisper box that shows why sending is disabled.
- Auto guild invite: whispers containing a keyword (default `ginv`) queue an invite request shown in a click-to-invite popup (Blizzard requires a click for guild invites). Rules for minimum level, allowed classes, do-not-contact and a per-player cooldown, plus an optional auto-reply whisper. Off by default; toggle with `/grb invite on|off`, the minimap menu or settings.
- Guildless player scanner: `/who` queries sliced by class and level (split further when a query returns a full page), one query per click with a throttle countdown, results with contact/cooldown status, per-row Whisper / Invite / Block and a throttled "Whisper all eligible". The default Who window is suppressed while a query runs.
- Tabbed main window (Messages | Scanner | Contacts | Settings) with remembered position and size, minimap button, and settings in the window (`/grb config`) and in Blizzard Interface Options (`/grb options`).
- Slash commands `/grb` and `/guildrecruitmentbuddy`.

### Development
- Git flow repository, luacheck CI and tag-triggered CurseForge/GitHub releases (BigWigs packager).
- Documentation of Blizzard platform constraints (`docs/CONSTRAINTS.md`).

[Unreleased]: https://github.com/ehvd/GuildRecruitmentBuddy/compare/v0.4.0...develop
[0.4.0]: https://github.com/ehvd/GuildRecruitmentBuddy/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ehvd/GuildRecruitmentBuddy/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ehvd/GuildRecruitmentBuddy/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ehvd/GuildRecruitmentBuddy/releases/tag/v0.1.0
