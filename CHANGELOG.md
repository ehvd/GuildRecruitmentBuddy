# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Fixed
- Overlapping text in the Messages tab preview (counter and warning labels) and the same label layout problem in the Contacts and Scanner tabs.

### Changed
- Development tasks moved to a `Makefile` (`make libs`, `lint`, `install`, `link`, `uninstall`, `clean`), replacing `scripts/fetch-libs.ps1`.

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

[Unreleased]: https://github.com/ehvd/GuildRecruitmentBuddy/compare/v0.1.0...develop
[0.1.0]: https://github.com/ehvd/GuildRecruitmentBuddy/releases/tag/v0.1.0
