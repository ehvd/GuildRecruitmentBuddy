# Guild Recruitment Buddy

**Recruit for your guild without the spreadsheet, the sticky notes or the accidental double-whispers.**

Guild Recruitment Buddy helps guild officers find guildless players, reach out with saved messages, and invite people who ask to join. It remembers everyone you've contacted, so you never spam the same player twice, even across your alts and your fellow recruiters.

Built for **WoW Classic Era** by an officer of an active raiding guild, for the recruitment work officers actually do every week.

---

## Features

### 🔍 Guildless Player Scanner
Find players who aren't in a guild, filtered by **class**, **race**, **level range** and **zone**.

- Splits your search into small `/who` queries, and splits busy ones again, so results aren't cut off at the 50-player limit
- Shows only players without a guild
- Marks players you've already contacted
- Whisper, invite or mark "do not contact" right from the results list, or whisper everyone eligible in batches

### 💬 Saved Recruitment Messages
Write your recruitment pitches once and reuse them everywhere.

- Separate templates for **whispers** and **channel posts** (LookingForGroup, World, Trade, General)
- Placeholders that fill in automatically: `{name}`, `{class}`, `{level}`, `{guild}`, `{discord}`
- Live preview and a warning when a message goes over the chat length limit

### 📣 Channel Broadcasting
Post your recruitment message to your chosen channels every few minutes, without having to remember.

- Send the **same message to several channels**, each on its own interval
- A timer tells you when a post is ready: a popup, a sound and a **key binding** (`/grb send`) let you send it with one press
- **Send now** whenever you like, which restarts that broadcast's timer
- Pauses automatically while you're busy (see Quiet Mode) or AFK

### 📒 Contact Memory
Every whisper sent through the addon is remembered.

- Tracks each player's status: contacted, replied, lead, invited, joined, declined or do-not-contact
- Configurable cooldown (14 days by default) before the same player can be whispered again
- Shared across all your characters
- Sortable contact list with filters, status changes and cleanup tools

### 🤝 Officer Sync
Everyone in your guild who can invite and runs the addon shares the same contact list, so **two recruiters never whisper the same player**.

- Only members with invite permission take part, and contacts are sent to them directly, never on the open guild channel
- The newest change wins; do-not-contact always wins a tie
- Catches up automatically when you log in, and you can force a full sync with `/grb sync`

### ✉️ Keyword Auto-Invite
When a player you've whispered replies **`ginv`** (or any keyword you choose), Guild Recruitment Buddy queues the guild invite for one click.

- Works for players who answer your channel posts too; optionally only for players the addon has whispered
- Optional rules: minimum level, allowed classes, ignore players marked do-not-contact
- Optional automatic reply when the invite goes out
- Built-in cooldown, so repeated whispers don't trigger repeated invites
- Off by default; toggle it with one command

### 👆 Right-click Recruiting
See someone in chat, in your group or on your friends list who might fit? **Right-click their name**, open **GRB > Recruit** and pick a whisper template. It goes out through the normal safety checks: cooldown, do-not-contact list and rate limit all apply, and the menu tells you why when a player can't be whispered right now.

### 🌟 Leads
A player answers *"not yet, maybe later :)"* and the reply is gone in the chat log a minute later. Guild Recruitment Buddy keeps what contacts write back, and replies that sound interested but not ready ("maybe", "later", "tell me more", ... your list) turn the player into a **lead**.

- The **Leads** tab lists every lead with their saved reply and the date, with one-click follow-up whisper, invite or removal
- Leads are never pruned or purged, so you can come back to them weeks later
- Save one by hand with `/grb lead <name> [message]` or set the Lead status in the Contacts tab

### 👋 Welcome Messages
When someone joins the guild, they're marked as joined and can get a welcome whisper with your Discord or website link. Off by default.

### 🙅 Opt-out Detection
If a player you whispered replies **`stop`** (or `not interested`, `no thanks` and the like), a popup shows their message and asks whether to add them to the opt-out list. If you do, they get one polite confirmation whisper and are never whispered by the addon again. Replies from players the addon hasn't contacted are ignored. The phrase list is yours to edit, and `/grb optout list` / `add` / `remove` manage the list by hand. The opt-out list is account-wide and shared with your fellow recruiters through Officer Sync.

### 🤫 Quiet Mode
In combat, dungeons, raids and battlegrounds the addon keeps out of your way: no popups, silent invite requests, welcome whispers held back until you're free. Each context can be switched off, or switch quiet mode on by hand.

---

## Commands

| Command | Action |
|---|---|
| `/grb` | Open the main window |
| `/grb scan` | Open the scanner |
| `/grb invite on` / `off` | Toggle keyword auto-invite |
| `/grb broadcast on` / `off` | Toggle channel broadcasting |
| `/grb send` | Send the ready channel broadcast (also a key binding) |
| `/grb quiet on` / `off` | Switch quiet mode on or off by hand |
| `/grb leads` | Open the leads |
| `/grb lead <name> [message]` | Save a player as a lead |
| `/grb optout list` / `add <name>` / `remove <name>` | Manage the opt-out list |
| `/grb sync` | Force a full contact sync with other recruiters |
| `/grb config` | Open settings |

There's also a minimap button for quick access.

---

## Playing Fair

Guild Recruitment Buddy works within Blizzard's addon rules:

- **Some actions need a click.** WoW only allows `/who` searches, guild invites and public channel messages from a real button press or keypress. The addon prepares everything; you press the button.
- **Whispers are rate-limited** to keep you from getting silenced or reported for spam.
- **Players who aren't interested stay left alone.** Mark them do-not-contact (or let opt-out detection do it) and the addon won't let you whisper them again.

Recruiting works best when it doesn't feel like spam, and the addon is built to help with that.

---

## Requirements

- WoW Classic Era
- A guild rank with **invite permission** for the invite features and officer sync

---

## Roadmap

Planned for future versions:

- **Recruitment needs**: set which classes and roles you're looking for, and the scanner filters for them
- **Recruitment statistics**: see which of your messages actually get replies
- **Guild capacity warning** when you're close to the member cap
- **Finnish localization**

---

## Feedback & Bugs

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/ehvd/GuildRecruitmentBuddy/issues).
