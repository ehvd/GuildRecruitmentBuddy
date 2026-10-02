# Platform constraints

Blizzard restricts what addons may automate. GuildRecruitmentBuddy is designed around these
limits and never tries to bypass them. Verified against warcraft.wiki.gg (Classic Era 1.15.x,
Interface `11509`) on 2026-10-02.

## 1. Public channel messages need a hardware event

`SendChatMessage` to `CHANNEL` (LookingForGroup, General, Trade, World) is "HW event restricted
for both outdoors and indoors". `SAY`/`YELL` are restricted outdoors. Whispers are not restricted.
Messages are truncated at 255 characters.

**Design:** a timer may only mark a broadcast as *ready* (button highlight / sound); the user
presses a keybind or button to actually send it. Never send channel messages from timers/events.

Implementation notes:

- The broadcast is sent with a direct `SendChatMessage` call inside the key binding / button handler. It must not go through ChatThrottleLib, which would defer the call to a later frame and lose the hardware event.
- Channel messages are addressed by channel index. The addon stores the channel's base name (`Trade` for `Trade - Stormwind City`) and looks the index up with `GetChannelName` at send time, so it survives zone changes and relogs.
- Pausing: instances (`IsInInstance`), combat and AFK stop new broadcasts from being marked ready.

Source: <https://warcraft.wiki.gg/wiki/API_SendChatMessage>

## 2. `/who` needs a hardware event and is throttled

`C_FriendList.SendWho` requires a hardware event ("as a measure against gold spam channel invites
and other unintended uses"). The server applies a cooldown and does not guarantee a response;
results arrive via `WHO_LIST_UPDATE` and are capped at 50 per query.

**Design:** the scanner builds a queue of small class/level-slice queries; each click on
"Next query" runs exactly one. Use `C_FriendList.SetWhoToUi` to keep the default `/who` UI quiet
while scanning and restore it afterwards.

Notes:

- /who has no "guildless" filter, so guildless players are filtered client-side (GetWhoInfo(i).fullGuildName empty).
- A query that returns a full page (49+ results) is split in half by level and re-queued; if a single level is still full, the scan reports that some players may be missing.
- With SetWhoToUi(false) results of 3 or fewer players arrive as chat lines instead of WHO_LIST_UPDATE, so the scanner enables SetWhoToUi(true) and stops FriendsFrame from listening to WHO_LIST_UPDATE only while a query is in flight, then restores both (the default is alse; there is no getter).

Sources: <https://warcraft.wiki.gg/wiki/API_C_FriendList.SendWho>, <https://warcraft.wiki.gg/wiki/API_C_FriendList.GetWhoInfo>, <https://warcraft.wiki.gg/wiki/API_C_FriendList.SetWhoToUi>

## 3. Guild invites need a hardware event

`C_GuildInfo.Invite` (alias `GuildInvite`) is marked `#hwevent` and exists in the Classic Era client.
It cannot be called from an event handler such as `CHAT_MSG_WHISPER`.

**Design:** a "ginv" whisper (or scanner row) enqueues an invite request; a popup/button
("Invite Foo (Warrior 60)?") performs the invite on click. Always check `CanGuildInvite()` first.

Source: <https://warcraft.wiki.gg/wiki/API_C_GuildInfo.Invite>

## 4. Chat throttling

All outgoing whispers go through ChatThrottleLib (bundled with Ace3) plus our own per-session
rate limit. Spamming whispers can get a player silenced or reported.

Source: <https://warcraft.wiki.gg/wiki/ChatThrottleLib>
