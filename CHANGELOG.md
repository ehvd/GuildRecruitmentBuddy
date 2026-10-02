# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Project setup: repository, git flow, templates.
- Documentation of Blizzard platform constraints (docs/CONSTRAINTS.md).
- Lint workflow (luacheck) and `.luacheckrc`.
- Release workflow (BigWigs packager -> CurseForge/GitHub) and `.pkgmeta`.
- Addon skeleton: `.toc` (Interface 11509), embeds, AceAddon core, AceDB, `/grb` + `/guildrecruitmentbuddy` slash commands, minimap button, options panel and `scripts/fetch-libs.ps1`.
- Project icon (`icon.png`).
- CurseForge project ID in the `.toc`.
- Message templates: create, edit, delete and reorder named whisper/channel messages with `{name}` `{class}` `{level}` `{guild}` `{discord}` placeholders, 255-character validation and live preview.
- Tabbed main window (`/grb`) with the Messages tab; settings for the Discord link and guild name override.
