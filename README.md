# Moolitism Helper 3.7

Taurens moo. Now you do too. With a cow, a farm, a herd, 14 party games, a raid boss, a Moo Pass, a Moo Meter, Moo Bingo, a stock market and 640+ moo-chievements.
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
| Moo-chievements | All 640+ achievements: categories, search, progress bars |
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

## What's new in 3.7

- **The Lua error after a few fights is fixed** (issue #19, fixed by steckums): on clients where Moo-litism
  reads the game's single "current fight" view, the 3.6.1 fix for #14 broke after about six fights and then
  errored after every fight. Plus steckums' fixes for #20: wipe mourning posting twice, guild questions
  dropped when you leave a group, a Moo-lette reminder going to the wrong chat, and more.
- **No more Lua error floods.** Every per-frame script and timer in the addon now runs protected: an error
  is recorded once (with where it came from), and a part that keeps failing switches itself off until
  `/reload` instead of erroring every frame. MooScape pauses with a message instead of freezing, and a
  broken achievement check is skipped instead of stopping all the others.
- **`/moo errors`** shows the errors the addon hit; the last 30 are kept in your saved data, so a bug
  report can include exactly what happened (`/moo errors clear` empties the list).
- **MooScape plays like a proper skilling RPG:**
  - right-click anything for its options (Chop down / Mine / Fish at / Attack / Talk-to / Trade-with /
    Use / Walk here / Examine / Cancel); left-click does the first one, shown in the corner as you point
  - right-click pack items to Wield, Wear, Eat, Drop or Examine them
  - examine lines for every tile, monster, person and item
  - "You swing your hoof-axe at the pine tree." / "You get some pine logs." messages, "+15 Woodcutting xp"
    over your cow, and "Congratulations, you've just advanced a Woodcutting level."
  - the skills tab shows what each level unlocks, and clicking a skill tells you the next unlock

## What's new in 3.6.2

Fixes for GitHub issue #17:
- Group members the game shows as "Unknown" (not loaded yet) are never interviewed, mourned, AFK-stalked or
  counted as present.
- Deaths are tracked per player, not per name, and nobody is mourned twice within a minute, so two
  "Unknown"s or two players with the same name can't set off mourning over and over.
- With several copies of the addon in a party, a death (or a wipe) is mourned once, even when each copy
  saw a different list of the dead.
- The Moo Clock chimes once per chat, not once per addon user.

## What's new in 3.6.1

Fixes for GitHub issues #12-#16:
- The Moo Market rejects "nan", "inf" and other non-numbers (`/moo invest MILK nan` used to turn your milk
  into NaN, after which everything was free), and repairs saved data that was already broken (#12).
- Hear Moo leaves Moo Cipher lines alone, so they can be decoded, and doesn't translate your own lines (#13).
- Moo-litism no longer shames wrong amounts when the game resets its "current fight" view (#14).
- "BONG" and "Around the Clock" can be earned (the Moo Clock now counts its chimes), and "The Sound of
  Silence" needs a mute you set yourself (#15).
- The "moo in 3 channels" daily can't be finished by reloading; BINGO announces the line you just finished;
  clicking a rank-up toast no longer opens the achievements tab; `/moo longmoo` with a mistyped channel
  posts nothing; Moo Meter posting reports the real reason when it fails (#16).

## What's new in 3.6

- **MooScape** (`/mooscape`, `/moo quest`): Moo Quest grew into a full point-and-click RPG: five zones,
  eight skills with crafting, gear, a bank, seven quests ending with the Bone Matriarch, party members on
  your map, and much fancier graphics.
- **Yo Moo-ma jokes**: friends saying "your mom" in chat get a cow-themed roast; `/moo mom [name]` sends one.

## What's new in 3.5.1

- HARD MUTE can't be bypassed for numbered channels any more (issue #10). The game names a zone channel
  "Trade" in one place and "Trade - Orgrimmar" in another, so a Trade mute set in the Barn didn't stop
  `/moo 2`, `/moo launch 2` or `/moo longmoo 2`, and `/moo mute 2` didn't stop the Moo button. Every path now
  uses the same key, and mutes saved under the long name are carried over.
- Surprise Moo Checks always happen in your group, never in guild chat, even with "Play in: Guild chat"
  (issue #11).

## What's new in 3.5

- **Moo Quest: The Pasture Lands** (`/pasture` or `/mooquest`): a small point-and-click RPG in its own
  window. Click a tile to walk there; click trees, rocks, ponds and bushes to gather; fight monsters;
  eat food; and sell your haul to Trader Moo-rgan for real MooHelper milk. Six skills level from 1 to 50.
  It's all on your screen: Moo Quest never posts to chat.
- Five new Moo Quest achievements.

## What's new in 3.4.3

- Friends without the addon are heard more reliably. When a friend's copy of the addon posted a line,
  anyone typing the same words (say, "moo moo") in the next 30 seconds was ignored; now only that
  friend's own copy's line is skipped.
- `/moo heard`: the last lines other people typed and what the addon did with each, with the reason when
  it ignored one (hidden by the game during combat or encounters, cooldown, reply limit, no trigger
  words, switched off...). If it doesn't react to someone, run this and you'll see why.

## What's new in 3.4.2

- Quick Draw: a moo right after DRAW wins again. Playing Quick Draw twice within two minutes used to end
  the second game as "Nobody drew" the moment DRAW went out (issue #9).
- Offline party members are no longer interviewed, picked for games or shamed for "ignoring the herd",
  and a question waiting on someone who logs off is dropped quietly (issue #8).
- A friend typing the same words the addon just said (say, "moo") is no longer mistaken for the addon's
  own line.

## What's new in 3.4.1

- Games in different chats no longer block each other (issue #7): a guild game and a party game can run
  at the same time, each answering only in its own chat.

## What's new in 3.4

- **Moo-litism actually works now.** It used to give up 9 seconds after a fight and skipped any fight
  whose damage-meter session it had already read, so if the game kept adding to one session it only ever
  shamed the first fight. Now it counts only the avoidable damage that's new since the last read (works
  either way), keeps checking for up to 2 minutes while the game hides the numbers, and checks again on
  boss kills and zone changes. `/moo moolitism` shows exactly what the damage meter returned on your
  client (please include it in bug reports); `/moo moolitism check` reads it right now.
- **Moo GTFO** (`/moo gtfo`): a "get out of the fire" alarm. Forever blocks the combat log, so it watches
  your health: a big hit (15% in a second, adjustable), a meltdown (40% in 3 seconds) or low health
  plays the raid-warning sound, flashes MOO-VE! and (at most every 20 s) tells the party. If the GTFO
  addon is installed, its alarms set off the moo too. `/moo gtfo test` to hear it.
- **Mournful moo-poetry** when a friend dies (issue #6), and a wipe is now one mourning line, not one
  per death.
- **`/moo longmoo`**: the longest moo chat allows (issue #4).
- Safety fixes from the code review in issue #5: whispers can't read the Hall of Moo-Shame or stats,
  queued lines and games never carry over to a new group, `/moo off` stops games and queued lines at once,
  the send queue and error log are capped, a line that keeps failing is dropped, and losing Moo-lette only
  makes you yell if your Yell channel is checked.

## Thanks

Bug reports and reviews: jnick422, seantomecko, djgoins1 - and Llama, who we're told basically made the
game usable. Every moo in this addon is a little longer because of you.

## What's new in 3.3

- **Moo Raid Boss** (`/moo boss`, or a friend says "raid boss" in party chat): a co-op boss fight in
  party (or guild) chat. Friends don't need the addon: every moo they type hits it. It fights back:
  STAMPEDE (moo within 10 seconds or get trampled), SILENCE (don't moo: moos heal it), BULL'S-EYE (the
  named player must moo). Enrages at half health (ALL-CAPS moos crit), wipes the party after 3 minutes.
  Six bosses, a damage chart, loot, and a live Raid Boss tab in the Barn.
- **Moo Pass** (`/moo pass`): a 50-tier season track, a new season every month. Everything you do earns
  XP; every tier pays milk; every 5th tier unlocks a title (`/moo title`).
- **Moo Wrapped** (`/moo wrapped`, `/moo wrapped post`): your whole moo history on one card.
- With two copies in a party, moo-backs pause during moo-counting games (raid boss, MOO-OFF, Moo Check,
  Quick Draw) on every copy, so a fight doesn't drown in moo-backs.
- Party death checks are much cheaper: each health event checks only that unit (pets are skipped), and the
  full-group scan runs on roster changes and every 5 seconds instead of every second.
- 14 new achievements, a "Slay a Moo Raid Boss" Bingo square, and three new Barn tabs.

## What's new in 3.2

- **Moo Meter** (`/moo meter`): a damage meter in moos. 1 moo = 1,000 damage, so 12,300 DPS is 12.3 MooPS.
  Modes: damage, healing, damage taken, avoidable damage, interrupts, deaths, and moos (who mooed most in
  party). Forever hides the numbers from addons during combat, so it fills in the moment each fight ends.
  `/moo meter post [mode] [overall]` posts the top 5 to your group. Optional auto-post after boss kills.
- **Moo Bingo** (`/moo bingo`): a 5x5 card that marks itself as things happen (a wipe, someone rolls a 1,
  someone says sorry, a Golden Moo...). A line is BINGO (+1,000 milk, announced), the whole card is a BLACKOUT.
- **Moo Market** (`/moo market`, `/moo invest <MILK|HAY|KODO> <qty|max>`, `/moo sell <stock> <qty|all>`):
  trade milk for stocks whose prices move every minute and react to Moo-nsoons, stampedes and Golden Moos.
- **Herd Keepers and Cow Duels** (`/moo keepers`, `/moo duel <name>`): copies of the addon find each other
  through hidden addon messages. Challenge a friend's cow; both copies compute the same fight.
- **Two copies in one party behave.** Copies never answer each other's lines (no moo-back loops), and a game,
  roast, roll comment, welcome or forecast happens once per chat, not once per copy. Begging for mercy
  quiets every copy. Backstop: at most 8 automatic replies a minute to any one person.
- 19 new achievements in a "Barnyard Fun" category, and four new Barn tabs.

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
