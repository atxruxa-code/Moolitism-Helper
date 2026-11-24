# Moolitism Helper 3.1

Taurens moo. Now you do too. With a cow, a farm, a herd, 13 party games and 615 moo-chievements.
For **World of Warcraft: Forever** (interface 16001). Only you need it installed.
In game it calls itself MooHelper, and every command starts with `/moo`.

## Install

**With WoWUp:** Get Addons → Install from URL → paste `https://github.com/atxruxa-code/Moolitism-Helper`.
WoWUp then offers updates whenever a new version is released.

**By hand:** download `Moolitism-Helper-<version>-forever.zip` from the
[Releases page](https://github.com/atxruxa-code/Moolitism-Helper/releases) and unzip it into your Forever
client's `Interface\AddOns\` folder, so you get `Interface\AddOns\Moolitism-Helper\Moolitism-Helper.toc`.
Then restart the game. If you had the older `MooHelper` folder, delete it so the two don't both load.

## Releasing a new version

Bump `## Version` in `Moolitism-Helper.toc`, commit, then push a tag: `git tag v3.2.0` and
`git push origin v3.2.0`. GitHub builds the zip and `release.json` and publishes the release.

- **The Barn** is the main window: `/moo barn`, right-click the kodo button, or the addon menu.
- **The kodo button** moos. Drag it anywhere.

## The Barn

| Tab | What's there |
|---|---|
| Moo HQ | The big MOO button, your stats, a **launch pad** (one button per channel, x1–x20), and a translator with 7 dialects and the Moo Cipher |
| Channels | Where the Moo button sends, and **HARD MUTE** for every channel |
| Triggers | Every automatic thing, grouped, each showing which channel it uses; how-often settings; the panic button |
| Party Games | 13 games with Start buttons and what friends can say to start them |
| The Herd | Your friends' herd ranks and points |
| Bessie | Your cow: feed, pet, brush, show off, rename |
| The Farm | Milk, 10 generators, 8 upgrades, daily Moo Quests |
| Moo-chievements | All 615 achievements: categories, search, progress bars |
| Settings | Effects, Hear Moo dialect, moo style, button size and position |

## HARD MUTE

A hard-muted channel **cannot** be posted to by MooHelper. Not by the button, launches, games, interviews,
the clock, welcomes, whisper replies, Bessie or achievement announcements. Every message goes through one
gate that checks the mute list, and there's no other way out. Officer chat is muted from the start.

- Channels tab: click **open** / **HARD MUTED** next to any channel.
- Or type `/moo mute guild`, `/moo unmute guild`, `/moo mutes`.

If MooHelper was talking somewhere you didn't expect, it was one of these, all of which you can now mute
or switch off in Triggers: Moo Clock (guild), daily forecast (guild), login welcomes (guild/whisper),
rank-ups and level-ups (group + guild), whisper conversations.

## Launching moos

`/moo launch <channel> [count] [text]`, for example `/moo launch guild 5` or `/moo launch trade 2 WTS hay`.
Channels: say, yell, e, party, raid, instance, guild, officer, trade, general, or a channel number.
The rest of a barrage follows one a second. Say, Yell and public channels take up to 3 per key press
(WoW only lets addons post there when you press something). Or use the launch pad in Moo HQ.

## What's new in 3.0

**Moo-chievements.** The whole Forever Achievements system is built in: 445 achievements for levels,
quests, zones, dungeons, raids, professions, reputation and PvP, with barnyard names ("Growing Up",
"Caves & Cellars", "Stampedes"…). On top of that are about 170 new moo achievements in six new categories:
Moo Mastery, Party Animal, The Farm, Bessie, The Herd and Strange Moos. Earned ones pop up as a toast and
(optionally) announce in group chat.

**Bessie.** Your own cow. She gets hungry and bored, grows from Calf to Legendary Moo Beast as you moo,
is happiest after boss kills, and speaks up in group chat now and then. Friends can ask about her.

**The Farm.** Milk comes from mooing, hosting games and earning achievements. Spend it on generators
(Hire a Calf → Moo-n Base) that make milk every second, even offline at half rate, and on upgrades
(Louder Moos, Industrial Udders, the Golden Moo Button…). Three **daily Moo Quests** a day, with streaks.

**The Herd.** Friends earn Herd Points by mooing, answering interviews and winning games, and get promoted
in party chat from Stray to Moo Legend. They can ask "what's my rank in the herd?".

**7 new party games:**
- **Quick Draw Moo:** the first MOO after DRAW wins; typing early gets you disqualified.
- **Moo-gman:** hangman with cow words.
- **Cow Scramble** and **Moo Math.**
- **Moo Tales:** each friend adds a line to a story, and the herd performs it at the end.
- **Moo Theater:** a short play starring your party.
- **Cow Tipping.**

**Dialects and the Moo Cipher.** `/moo t ancient hello` speaks Ancient Bovine. There are also Calf Speak,
Moo Opera, Whispered Moo, Pirate Moo and Olde Bovine. `/moo cipher party meet at the barn` hides a secret
in a line of moos; MooHelper shows you (and any friend with MooHelper) the decoded message.

**Moo world events:**
- **Moo-nsoon:** double milk for 5 minutes.
- **Stampede Hour.**
- **Golden Moo:** a golden kodo floats across your screen; click it for a pile of milk.
- **Moo FM:** a radio DJ segment in group chat.
- **Moo-roscopes:** a daily horoscope from the Moo-diac.

## Games in guild chat

Every game works in guild chat too. Guildmates start one by saying it in guild chat ("trivia",
"moo off", "hangman"...), and it runs and listens there. To start one yourself, add `guild` to the
command (`/moo trivia guild`), or set **Play in: Guild chat** on the Barn's Games tab. One game runs at a
time across party and guild. If Guild is hard muted, guild games can't start. Switch it all off with
"Games and chat in guild" in the Triggers tab. Interviews and the AFK stalker stay in party.

## Everything friends can say in party or guild chat

moo off, moo check, trivia, vote <question>, sing, roulette, quick draw / duel, hangman, scramble, moo math,
story time, theater, cow tip <name>, fortune, roast me, compliment me, horoscope, my rank / the herd,
how is your cow, how much milk, achievements, moo fm, hall of shame, my stats, how many moos,
translate <text>, your name, a question to you, and begging ("please stop mooing").

## Commands

`/moo help` lists everything. The main ones:

| Command | What it does |
|---|---|
| `/moo` | Moo in every channel ticked for the button |
| `/moo launch <channel> [count] [text]` | Barrage one channel |
| `/moo mute <channel>` / `unmute` / `mutes` | Hard mutes |
| `/moo t [dialect] <text>`, `/moo dialects`, `/moo cipher [channel] <secret>`, `/moo decode <line>` | Speaking moo |
| `/moo battle`, `trivia`, `vote`, `sing`, `roulette`, `check`, `draw`, `hangman`, `scramble`, `math`, `story`, `theater`, `tip` | Party games |
| `/moo bessie [feed\|pet\|brush\|show\|name <name>]` | Your cow |
| `/moo farm`, `/moo buy <thing>`, `/moo quests`, `/moo golden` | The farm |
| `/moo herd`, `/moo ach [post]`, `/moo fm`, `/moo horoscope [name]` | The rest of the barnyard |
| `/moo off` / `/moo on` | Panic button for everything automatic (your own commands still work) |

## Limits that stay on

- Say, Yell and public channels need a click or key press. This is WoW's rule; breaking it gets the addon blocked.
- Automatic lines wait while the game locks addon chat during boss fights.
- At most one automatic line a second (faster and the server can disconnect you).
- Never auto-replies to a Game Master.

## What hasn't been tested in the real game

Everything was tested against a simulated Forever client (a 3-person party, guild, whispers, fights,
1,600+ clicks through the Barn), not the real game. Most likely to need a tweak:

- Moo-litism needs Forever's damage meter API.
- Hear Moo and the cipher decoder use chat filters.
- Friend deaths and the AFK stalker need Forever to show party members' state to addons.
- Some chat may be hidden from addons inside dungeons, so games mid-dungeon can miss answers.
- The ported achievement tracking has the same caveats as Forever Achievements (boss names, English zone names).
