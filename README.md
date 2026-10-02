<p align="center"><img src="icon.png" alt="GuildRecruitmentBuddy" width="160"></p>

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
| `/grb config` | Open the Settings tab |
| `/grb options` | Open the settings in Blizzard's Interface Options |

`/guildrecruitmentbuddy` is an alias for `/grb`.

## Local development

Needs GNU make and a POSIX `sh` with `git`, `cp`, `sed` and `awk` (Git for Windows provides them), plus
[luacheck](https://github.com/lunarmodules/luacheck) for `make lint`. Run `make` to list the targets:

| Target | Action |
|---|---|
| `make install` | Fetch the libraries if needed and copy the addon into the Classic Era AddOns folder |
| `make link` | Junction the repo into AddOns instead, so `/reload` in game picks up edits (live development) |
| `make uninstall` | Remove the installed copy or the link (never touches the repo) |
| `make libs` | Fetch the embedded libraries into `Libs/` (gitignored) |
| `make lint` | Run `luacheck` |
| `make clean` | Remove the fetched libraries |

`install` and `link` exclude each other: run `make uninstall` to switch.

The default AddOns folder is `C:/Program Files (x86)/Blizzard/World of Warcraft/_classic_era_/Interface/AddOns`.
Put personal settings in an untracked `local.mk`, or pass them on the command line:

```make
WOW_DIR  = D:/Games/World of Warcraft
LUACHECK = C:/Users/me/bin/luacheck.exe
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Releases are published to CurseForge from tags by CI.

## License

[MIT](LICENSE)
