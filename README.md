# GuildRecruitmentBuddy

A World of Warcraft **Classic Era** addon that helps guild officers recruit: message templates,
a memory of who was already contacted, "ginv" auto-invite and a guildless-player scanner.

> Blizzard restricts automation of chat, `/who` and guild invites. This addon works **with**
> those limits (one click per action), never around them. See [docs/CONSTRAINTS.md](docs/CONSTRAINTS.md).

## Slash commands

| Command | Action |
|---|---|
| `/grb` | Open the main window |
| `/grb invite on\|off` | Toggle the keyword auto-invite |
| `/grb scan` | Open the scanner tab |
| `/grb config` | Open the settings panel |

`/guildrecruitmentbuddy` is an alias for `/grb`.

## Local development

1. Install `luacheck` (e.g. `luarocks install luacheck`).
2. Fetch the libraries into `GuildRecruitmentBuddy/Libs/` (gitignored):

   ```powershell
   ./scripts/fetch-libs.ps1
   ```

3. Junction the addon into your WoW AddOns folder:

   ```powershell
   cmd /c mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\GuildRecruitmentBuddy" "D:\Projects\WoW\GuildRecruitmentBuddy\GuildRecruitmentBuddy"
   ```

4. Run `/reload` in game after editing Lua.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Releases are published to CurseForge from tags by CI.

## License

[MIT](LICENSE)
