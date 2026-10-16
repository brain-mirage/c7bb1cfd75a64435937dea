# Macros: a player's guide

A macro is a short list of commands that runs when you press one button. It can cast a spell, use an item, pick a
target, attack, say something or do several of these at once. Macros work much like World of Warcraft's, with a few
differences for this game, which this guide points out.

Contents:

1. Making a macro
2. How a macro is written
3. The commands
4. Options: conditions and targets
5. Sequences and steps
6. The rules you will meet
7. Example macros
8. The original client's text hotkeys

This guide writes our commands with `//`, the command prefix this client uses unless you change it (see section 2).
If you change the prefix, use yours wherever this guide shows `//`.

---

## 1. Making a macro

### Opening the macro window

- Press **F11**, or
- open the game menu (**Esc**, or the **Menu** button) and choose **Macros**.

The window opens only while you are in the world.

### Two sets of macros

The window has two tabs:

- **General**: your account's macros. Every character you play, on every server, sees them. Up to 120.
- **<your character>'s**: this character's own macros, on this server only. Up to 18.

The count under the list shows how many you have of how many there can be.

### A new macro

1. Pick the tab it belongs to, then press **New**.
2. Type a **name** (16 characters at most) and **choose an icon**. The icons are the question mark, a set of
   pictures, the icons of the spells you know, and the game's item icons (with the game's art installed); scroll with
   the mouse wheel or the ^ and v buttons. **OK** needs a name.
3. Type the macro's text under **Enter macro commands:**, one command a line.
4. Press **Save**. Clicking another macro in the list, or closing the window, also saves what you typed.

The counter under the text shows how long it is: **255 characters at most**, where the command prefix of each line
counts as one character, however long your prefix is. A longer text is not saved: the counter says "too long to save",
and Save says "The macro is N characters, 255 at most: it was not saved." Nothing is ever cut off.

If you write a line that starts with a single `/`, such as `/cast` (a WoW habit), the window warns you under the text:
"Said to the server as written: /cast". Such a line goes to the server as chat (section 2 explains why).

**Change Name/Icon** changes the selected macro's name and icon. **Delete** asks first; deleting a macro also takes it
off every action bar button it is on (for this character).

The **?** button in the window shows a short summary of the commands.

### Putting a macro on a button

Drag the macro from the list (or the big icon of the selected macro) onto an **action bar button** or a segment of the
**action wheel**. If the button already holds something, that goes onto your cursor, to drop somewhere else.

Now that button's **key** runs the macro, and so does **clicking** the button. The macro window does not bind keys of
its own: a macro's key is its button's key. Out of the box:

| Bar | Keys |
|---|---|
| Bar 1 (along the bottom) | 1 2 3 4 5 6 7 8 9 0 - = |
| Bar 2 | Ctrl+1 ... Ctrl+= |
| Bar 3 | Alt+1 ... Alt+= |

Only bar 1 is shown at first; turn the others on in the Settings to drop macros on them. You can change any button's key
in **Settings, Key Bindings**. Its **Macros** group has the macro window's own key; the **Macros** settings page has a
button that opens the list there. Keys bound to a macro in older builds still work, and are listed in that group by the
macro's name.

A button holds the macro itself, so editing the macro's text changes what the button does.

### What the button shows

A macro's button shows the macro's icon and name, and its tooltip shows the macro's name and first lines. Two things
make it show what the macro would do right now instead:

- **`#showtooltip`** as a line of the macro: the button shows the icon of the spell or item the macro would use now
  (with an item's count and the aether, the game's cooldown), and its tooltip is that spell's or item's.
- **The question-mark icon**: a macro whose icon is the question mark also shows the spell's or item's icon, but keeps
  its own tooltip.

`#show` is like `#showtooltip`, but changes only the icon. Section 4 explains how the button decides.

### Where macros are kept

In the game's folder: the General tab's in `config\macrobook.json`, and each character's in
`servers\<server>\<character>\macrobook.json`. Copy these files to keep a backup.

---

## 2. How a macro is written

**One command a line.** The lines run from top to bottom. Empty lines are skipped, and spaces at the start and end of
a line do not matter. Command names may be written in any case (`//CAST` is `//cast`), and so may the names of spells,
items and the characters you target.

**The command prefix.** Our commands start with this client's command prefix, **`//`** unless you change it. You can
change it in **Settings, Macros, "Client command prefix"**: up to four characters, with no letters, digits or spaces,
not a single `/`, and not starting with `#` (for example `@`). When you change it, the client rewrites the
command lines of your saved macros to the new prefix, so they keep working.

**A line without the prefix is chat.** A line that does not start with the prefix is said aloud in normal chat, exactly
as written. That includes lines starting with a single `/`: those belong to the server, as in the original client, so a
server's own commands (such as a GM's `/` commands) work from a macro too. A plain line of text works as well:

```
Hello everyone!
```

**Lines starting with `#`** are not run:

- `#showtooltip` and `#show` (optionally followed by a spell or item, options allowed) say what the button shows
  (section 4). Only the first such line counts.
- `#reset=` sets when a stepped macro starts again (section 5).
- **Any other `#` line is a comment**: write what you like after the `#`. There are no comments at the end of a line.

**No variables.** Text is sent as written. WoW's `%t` (the target's name) and similar are not replaced.

**Typing commands in the chat line.** Every command in section 3 except `//next` can also be typed in the chat line,
with the prefix: `//cast Heal`, `//dance`. (`//next` only separates a macro's steps; typed, it shows "Unknown command:
//next".) A typed line is one command; if you paste several lines, only the first runs. A line with the
prefix is never sent to the server: a name that is no command shows "Unknown command: //x". Plugins can add commands of
their own, which also take the prefix and also work in macros.

---

## 3. The commands

Each command below is written with the default prefix. Where a command takes options (section 4), they go right after
the command's name: `//cast [mod:shift] Heal; Zap`. The chat and social commands take no options: their text is sent
as you wrote it.

"As the key does" means the command does exactly what that key or button of the game does, with the same limits
(for example a key that works at most once a second), and the server receives the same thing.

### Spells and items

**`//cast <name>`**, **`//use <name>`** (the two are one command, as in WoW)
Casts a spell or uses an item, as pressing its key on the action bar does. The name is looked up in this order:

1. a **number** from 1 to 52: the item in that inventory slot (1 to 26 are slots a to z, 27 to 52 are slots A to Z);
2. an **item** you carry with that name;
3. a **spell** you know with that name.

So `//use 3` uses the item in slot c, and `//cast Heal` casts Heal (if you also carried an item called Heal, the item
would win). An unknown name says `No spell or item called "Heal".` A `!` before the name is ignored (`//cast !Heal`).

A spell that needs a target goes where its key would send it: to your selected target if you have one, otherwise its
target line opens for you to pick one (your **Settings, Targeting** choices, such as Hover casting and the sweep, apply
as they do to the key; like the key, they act only while you have no target selected). A spell that asks for a word, a number or an item opens that line, as its key does. With a target named in
the options (`//cast [@player] Heal`), see section 4, "Targets".

**`//castrandom <name>, <name>, ...`**, **`//userandom ...`**
Picks one of the listed spells or items at random and casts or uses it as `//cast` does.

**`//castsequence reset=<rules> <name>, <name>, ...`** (`reset=` may be left out)
Casts the first spell of the list, then the next one on the next press, and so on, starting over after the last. See
section 5.

### Targeting

These change your selected target (the one the target frame shows). Selecting sends nothing to the server.

**`//target <name or unit>`**, **`//tar`**
Selects a unit: a unit word such as `player` (yourself), `focus` or `party1` (section 4), or a name. A name picks the
character or NPC in view with exactly that name, or else the nearest whose name begins with it (`//target Bo` finds
Bob). Monsters have no names the client can see: use `//targetenemy` for them. `//target [@mouseover]` selects what is
under the mouse.

**`//targetexact <name>`**
Selects the nearest unit with exactly that name, never one whose name merely begins with it.

**`//targetenemy`**
Selects the nearest creature on screen; each further press selects the next one out, and after the farthest it starts
again with the nearest. `//targetenemy 1` goes the other way round. Creatures are everything
drawn as a monster, NPCs drawn as creatures included; dying ones are skipped.

**`//targetfriend`**, **`//targetfriendplayer`**
The same among the characters on screen, not yourself (NPCs drawn as people included). The game has no sides, so every
character counts as a friend.

**`//targetparty`**, **`//targetraid`**
The same among the members of your group who are on screen. (The game has no raids; both do this.)

**`//targetenemyplayer`**
Does nothing: no character is an enemy in this game.

**`//targetlasttarget`**
Selects the unit you had selected before the current one.

**`//targetlastenemy`**, **`//targetlastfriend`**
Selects the last creature, or the last character, you had selected.

**`//cleartarget`**
Clears your selected target, as Esc does. Unlike Esc, it leaves a selection of many creatures (below) as it is.

**`//focus <name or unit>`**
Remembers a unit as your **focus**, for `[@focus]` (section 4): `//focus Bob`, `//focus [@mouseover]`. With nothing
after it, your current target becomes the focus. The focus is the macros' own: nothing on the screen shows it, and it
is forgotten when you log in again.

**`//clearfocus`**
Forgets the focus.

### Selecting many creatures (for the sweep)

The client can select several creatures at once, as dragging a box over the map's empty ground does. A targeted spell's
key then works over them (**Settings, Targeting, "Sweep"**: Hold casts on each in turn while you hold the key, Strict
casts on the next one at each press, Off ignores them). Selecting sends nothing to the server.

**The sweep needs no target selected.** While you have a target selected (the one the target frame shows), a targeted
spell's key casts at that target alone, as the original client's does, and the many-creature selection waits. So clear
the target first: `//cleartarget` does that and keeps the many-creature selection. `//select kind` and `//select add`
read your target, so put `//cleartarget` after them:

```
//select kind
//cleartarget
//cast Zap
```

The sweep's casts keep the pace the key's own would (Settings, Targeting, "Sweep Interval"); pressing the macro faster
does not cast faster.

**`//select`** or **`//select enemies`**
Selects every monster on screen: living creatures without a name. Players, NPCs and items are never selected.

**`//select kind`**
Selects every monster on screen that looks like your target (the same picture and colour). Your target must be a
creature.

**`//select add`**, **`//select remove`**
Adds your target to the selection, or takes it out. `//select [@mouseover] add` uses what is under the mouse instead.

**`//clearselection`**
Clears the selection, as Esc does.

### Fighting

**`//startattack`**, **`//attack`**
Attacks, as the attack key (Space) does. With a bow, letting go of the macro's key counts as letting go of Space.

**`//stopattack`**
Lowers a drawn bow, as Esc does, and drops a `//startattack` waiting for its key to be let go. While a bow is drawn,
macro keys do nothing (as in the original client), so this is mostly useful typed in the chat line.

**`//stopcasting`**
Stops a running sweep, and closes the target, word, number or item line that a spell opened, as Esc on that line does.
An item's line and the chat line are left alone.

### Your character

**`//look`**: does what the Look key does (`;`).
**`//open`**: does what the Open key does (O), for example opening a door.
**`//ride`**: does what the Ride key does (R).
**`//pickup`**: picks up, as the Pick Up key (`,`) does. **`//pickup all`** picks up all, as Shift+`,` does.

**`//eat <item>`**, **`//wield <item>`**, **`//wear <item>`**
Eats, wields or wears an item, as the bag menu's Eat, Wield and Wear do. The item is a name or an inventory slot number,
as for `//use`: `//eat Acorn`, `//wield 2`.

**`//equip <item>`**, **`//eq <item>`**
The same as `//wear` (on the server, wearing and wielding both put on any item that can be put on).

### Emotes

**`//emote <emote>`** plays an emote, as the emote menu does (Shift+;). The emote is its name or its letter:

| Letter | Emote | Letter | Emote |
|---|---|---|---|
| a | laughter | i | sarcasm |
| b | grief | j | shrug |
| c | shame | k | annoyed |
| d | affection | l | dance |
| e | boredom | m | respect |
| f | sleepiness | n | triumph |
| g | surprise | o | strange |
| h | rage | p | kiss |

Each emote is also a command of its own: **`//laughter`**, **`//grief`**, **`//shame`**, **`//affection`**,
**`//boredom`**, **`//sleepiness`**, **`//surprise`**, **`//rage`**, **`//sarcasm`**, **`//shrug`**, **`//annoyed`**,
**`//dance`**, **`//respect`**, **`//triumph`**, **`//strange`**, **`//kiss`**.

`//emote` also takes an emote's code, the number the game sends for it: 0 to 11 for laughter to dance (in the table's
order), 254 for respect, 255 for triumph, 12 for strange and 13 for kiss. Any other number or word is refused with a
short message (`No emote "200": ...`), and nothing is sent.

### Chat

These send the rest of the line as their text; options in brackets are not read here.

| Command | Says the text |
|---|---|
| **`//say <text>`**, **`//s`** | in normal chat |
| **`//yell <text>`**, **`//y`**, **`//shout`**, **`//sh`** | as a shout |
| **`//whisper <name> <text>`**, **`//w`**, **`//tell`**, **`//t`** | to that character only |
| **`//party <text>`**, **`//p`**, **`//group`** | to your group |
| **`//clan <text>`**, **`//guild`**, **`//g`** | to your clan |

In a macro, `//say` sends its text as the original client's text hotkeys did; typed in the chat line, it is said as the
chat line says what you type. A text that itself starts with the prefix is never sent (`Not sent: "..." starts with this
client's command prefix.`), so `//say //dance` says nothing.

### Group and ignore list

**`//invite <name>`**: invites that character to your group.
**`//ignore <name>`**, **`//unignore <name>`**: adds the name to your ignore list, or takes it off.

### Controlling the macro

**`//stopmacro`**
Stops the macro here: the lines after it do not run. With options it stops only when they hold:
`//stopmacro [noexists]` stops when you have no target.

**`//next`**
Splits the macro into steps, one step a press (section 5). It is a separator inside a macro, not a command to type: in
the chat line it shows "Unknown command: //next".

### Commands that do nothing in this game

**`//assist`**, **`//a`**, **`//cancelaura`**, **`//cancelform`**, **`//click`** are accepted, so WoW macros do not break,
but do nothing: the game never says what another unit targets, has no auras the client can remove, no forms, and no
named buttons to click. (`//targetenemyplayer`, above, also does nothing.)

---

## 4. Options: conditions and targets

Most commands take **options**, as WoW's do: conditions in square brackets that choose what the command does.

```
//cast [@mouseover,help][help] Heal; [harm] Zap; Rest
```

- **Clauses** are separated by `;`. The first clause whose conditions hold is used, and its text (here a spell's name)
  is what the command acts on. If no clause holds, the line does nothing.
- **Brackets** before a clause are alternatives: one of them must hold. `[a][b] Heal` means "a or b".
- **Commas** inside a bracket: all must hold. `[help,nodead]` means "help and not dead".
- **`[]`** always holds, and so does a clause with no brackets (`Rest` above).
- **`no`** before a condition turns it round: `[nodead]`, `[nomod]`, `[noexists]`.

### Conditions

| Condition | Holds when |
|---|---|
| `exists` | the unit is there (in view) |
| `help` | the unit is a character: a player, or an NPC drawn as a person |
| `harm` | the unit is a creature: a monster, or an NPC drawn as a creature |
| `dead` | the unit is a creature playing its death |
| `combat` | you are fighting (see below) |
| `mod`, `modifier` | any of Shift, Ctrl or Alt is held |
| `mod:shift`, `mod:ctrl`, `mod:alt` | that key is held; `mod:shift/ctrl` means either (`lshift`, `rctrl` and so on count as the same key) |
| `btn:1` to `btn:5`, `button` | the macro's button was clicked with that mouse button (1 left, 2 right, 3 middle, 4 and 5 the side buttons; `LeftButton`, `RightButton`, `MiddleButton`, `Button4`, `Button5` also work); a key press counts as button 1 |
| `known:<spell>` | you know that spell; `known:Heal/Zap` means either |

`help`, `harm`, `dead` and `exists` test the bracket's unit (below), or your target when the bracket names none. The
game has no sides, so `help` and `harm` say what a unit is, not whether it is friendly.

**Fighting (`combat`).** The game does not tell the client whether you are in a fight, so the client keeps its own
estimate: a fight starts when you attack, cast a spell at a creature or are hit, and ends 6 seconds after the last of
these.

**Conditions this game has no data for are false, and so are their `no` forms.** `[mounted]`, `[stance]`,
`[channeling]`, `[group]`, `[flying]` and any other condition not in the table never hold, and neither do
`[nomounted]` and the like. The same goes for a unit the client cannot know (below).

### Targets

`@unit` (or `target=unit`) inside a bracket names the unit that the bracket's conditions test, and that the command acts
on: `[@mouseover,harm]`, `[target=focus]`.

| Unit | Means |
|---|---|
| `player` | yourself |
| `target` | your selected target (`playertarget` is the same) |
| `mouseover` | the creature or character under the mouse pointer when the macro runs |
| `focus` | the unit `//focus` remembered |
| `party1` to `party4` | the members of your group, in the group list's order (you left out); one not in view is not there |
| `none` | no unit: `//cast [@none] Heal` opens the target line even when you have a target selected |
| a name | the character or NPC in view with that name, or else the nearest whose name begins with it |
| `pet`, `vehicle`, `raid1`... `raid40`, `partypet1`... `partypet4`, `raidpet1`... `raidpet40`, `arena1`... `arena5`, `boss1`... `boss4` | never there: this game has none of them (`[@pet,noexists]` holds) |
| `targettarget`, `focustarget`, `party1target` and other "...target" units, and `npc` | unknown: the game never says what another unit targets, and the client does not keep whom you talk to; every condition on them is false |

**What a unit does to `//cast` and `//use`.** For a spell or an item that needs a target, the unit is where it goes: the
client opens its target line and picks that unit for you, as if you had clicked it. If the unit named is not there
(`[@focus]` with no focus), nothing happens. For a spell or item that needs no target, the unit only matters to the
conditions. Mouse-over macros are best run from their key: when you click the button, the pointer is on the button.

### What `#showtooltip` shows

With no name after it, `#showtooltip` (and `#show`, and the question-mark icon) shows the first `//cast`, `//use` or
`//castsequence` line whose options hold right now (for a sequence, the spell its next press casts; for a stepped macro,
the current step's). With a name, it shows that: `#showtooltip Heal`, or with options,
`#showtooltip [mod:shift] Heal; Zap`.

The button follows the keys you hold and your target as they change. It cannot know your fight or your focus, so
for what the button shows `[combat]` and `[nocombat]` never hold, and neither does any condition on `@focus` (they do
work when the macro runs).

---

## 5. Sequences and steps

### `//castsequence`

```
//castsequence [options] reset=<rules> Spell1, Spell2, Spell3
```

The options and `reset=` may both be left out: `//castsequence Zap, Zap, Flame`.

Each press casts the next entry of the list (spells, items, or slot numbers, as for `//cast`); after the last comes the
first. **A step moves on only when its cast or use really goes out**: if its name matches nothing, its options do not
hold, or you cancel the target line it opened, the same step comes again on the next press. (If the server refuses the cast,
for example for lack of mana, the client cannot see that, and the step has moved on.)

`reset=` (optional, right after the options) says when to start again from the first entry. Join rules with `/`:

| Rule | Starts again |
|---|---|
| a number, `reset=8` | after that many seconds without a press of this sequence |
| `target` | when your target changed since its last press |
| `combat` | when a fight ended since its last press |
| `shift`, `ctrl`, `alt` | when you press it with that key held (that press casts the first entry) |

Two buttons with the same sequence text share one sequence. A button with `#showtooltip` shows the entry the next press
casts. Sequences start from the first entry again each time you log in.

### Stepped macros: `//next`

Our own addition (WoW players get it from add-ons): `//next` lines split a macro into steps. Each press runs the next
step, all of its lines; after the last step, the next press runs the first again.

```
#showtooltip
//cast Zap
//next
//cast Flame
//next
//cast Zap
//targetenemy
```

Three presses cast Zap, Flame and Zap (the third also selects the next enemy); the fourth casts Zap again.

A step moves on like a `//castsequence` step: when its action really went out, or as soon as it has run if it has no
action (section 6 says which commands are actions). A step whose spell opened its target line moves on when you answer
that line, and stays if you cancel it.

A **`#reset=`** line, anywhere in the macro, gives the steps the same reset rules as `//castsequence`:
`#reset=target/8` starts again from the first step after 8 seconds without a press, or when your target changed.
Holding a `#reset=` key (`#reset=shift`) makes that press run the first step, and the button shows the first step's
spell while you hold it.

---

## 6. The rules you will meet

**Each line is another press of the macro's key.** Every action goes the way that action's own key or button goes, in
the order of the lines, with that key's limits. So if a line opens a line of its own (a spell's target line, for
example), that open line takes the presses of the lines after it, as it would take your next key presses: they do
nothing. Put such a spell last, or give it a target first.

**One press, every line.** In this build a press runs every line, and every action in it goes out: a macro can cast,
use an item and attack in one press. The client also has a rule like WoW's limit of one spell per press, "one real
action per press", but it is switched off. If a later build switches it on, only the first action of a press that
reaches the game goes through, and later actions of that press are skipped; everything free still runs. The same split
decides when a stepped macro's step moves on (section 5):

| Actions | Free |
|---|---|
| `//cast`, `//use`, `//castsequence`, `//castrandom`, `//userandom` | the targeting commands, `//focus`, `//clearfocus`, `//select`, `//clearselection` |
| `//startattack`, `//attack` | `//stopattack`, `//stopcasting`, `//cancelaura`, `//cancelform` |
| `//eat`, `//wield`, `//wear`, `//equip`, `//eq` | `//stopmacro`, `//next`, `//click`, the `#` lines |
| `//pickup`, `//ride`, `//look`, `//open` | chat: `//say`, `//yell`, `//whisper`, `//party`, `//clan` and their short forms, and every line said |
| `//emote` and the emotes by name | `//invite`, `//ignore`, `//unignore` |

**When a press does nothing.** As with the game's own keys, a macro's press does nothing:

- before your character is in the world: after you log in, and after every map change, until your character appears
  on the map;
- while your bow is drawn.

While a server transfer is showing, none of its actions go out either. Such a press is not kept for later: press again
once you can act.

**Holding the key does not repeat the macro.** A held key runs it once. (A sweep over a selection goes on while you hold
the key, as the spell's own key does.)

**Limits.**

| What | Limit |
|---|---|
| A macro's name | 16 characters |
| A macro's text | 255 characters, each line's command prefix counting as one |
| General macros | 120 |
| A character's macros | 18 per character, per server |
| The command prefix | 1 to 4 characters: no letters, digits or spaces, not a single `/`, not starting with `#` |

---

## 7. Example macros

Put your own spell and item names in place of the ones below (Heal, Zap, Flame, Acorn).

**Heal what is under the mouse, else your target if it is a character, else yourself.**

```
#showtooltip
//cast [@mouseover,help][help][@player] Heal
```

**Pick the nearest monster unless you have one selected, and zap it.**

```
#showtooltip Zap
//targetenemy [noharm]
//cast Zap
```

**One button, two spells: Shift for the heal.**

```
#showtooltip
//cast [mod:shift] Heal; Zap
```

**A sequence that starts over after 10 seconds or on a new target.**

```
#showtooltip
//castsequence reset=10/target Zap, Zap, Flame
```

**Zap every monster on screen** (with Settings, Targeting, Sweep on Hold: hold the macro's key). `//cleartarget` lets
the sweep run even when you have a target selected (section 3, "Selecting many creatures").

```
//select enemies
//cleartarget
//cast Zap
```

**Only with a target.**

```
//stopmacro [noexists]
//cast Zap
//say Zap!
```

**Heal your focus.** Select a friend and type `//focus` in the chat line once; then:

```
#showtooltip
//cast [@focus,exists][] Heal
```

**Eat, and dance.**

```
//eat Acorn
//dance
```

---

## 8. The original client's text hotkeys

The original client had thirty text hotkeys of its own (keys 1 to 0, Ctrl+1 to Ctrl+0 and Alt+1 to Alt+0), set up in
its Macro Setup dialog. Each one says a line of text. If your character had some, they are on its bars and still say
their lines. To edit them, turn on **Settings, Macros, "Show the original's hotkey setup (Macro Setup)"**: the macro
window then has a **Hotkeys** tab, the original's Menu opens its dialog from its Hotkey entry (with the setting off,
that entry opens the macro window), and the command Original Macro Setup can be given a key. Their lines are kept to
64 characters, as the original kept them, and are said as written; our commands do not run from them, and a line that
starts with the command prefix is not sent at all.
