# Behaviour scenarios

Each `.txt` file here is a scenario that `tests/regress.sh` replays, through goldbox-player's emulator harness,
against a golden build and the build under test, comparing the screen text (read exactly from the game's font) and the
save files at its checkpoints. Every scenario boots with `NORAND`, so the dice fall the same way every run, and starts
from the default saved games the harness copies in (`goldbox-player/saves/`). The harness boots the game as `START
STING`, and STING skips the startup advisory (#1173), so a scenario starts at the main menu even though those saves
have no POOLOPT.CFG; `advisory` shows the advisory by typing a start with `ADVISE` at the DOS prompt.

The format, one step a line (`#` starts a comment):

| step | does |
| --- | --- |
| `boot WORDS` | start with WORDS after `START STING` (first line) |
| `press KEY...` | press each key: `l`, `ret`, `esc`, `up`, `alt-q`, `ctrl-y`, ... |
| `wait REGEX [SECS]` | until the menu line matches (30 s by default) |
| `checkpoint NAME` | record the screen |
| `saves NAME` | record every file in `SAVE\` (size and sha256) |
| `ignore REGEX` | leave matching text lines out of the comparison (the version string, file times) |
| `saves NAME GLOB...` | record only the files in `SAVE\` matching a glob |
| `mask GLOB [every N] OFF:LEN...` | zero those bytes (in each N-byte record) before files are compared |
| `golden: STEP`, `candidate: STEP` | a step for that build only, where the two need different keys |
| `screens off` | record screen checkpoints without comparing them |
| `#video MODE` | run this scenario only in that video mode (see below) |

`POOL.CFG` points the game at `C:\POOLRAD\` and `C:\POOLRAD\SAVE\`, where the harness installs it.

`POOL.CFG` runs the game in EGA. `VIDEO=cga tests/regress.sh ...` uses `POOL-CGA.CFG`, and `VIDEO=tandy` uses
`POOL-TANDY.CFG`. Each mode keeps its own golden record, `record-cga.json` or `record-tandy.json`. Tandy runs on
goldbox-player's `por-v13-tandy` title, a Tandy machine, because an EGA machine cannot set mode 9.

A scenario with a `#video vga` line (a comment to the harness, read by `regress.sh`) tests something only that mode
shows. With `VIDEO` unset, `regress.sh` runs it apart from the rest, as `VIDEO=vga` would, its report in
`obj/regress-vga.json`; under another `VIDEO` it is left out.

`combat`, `vault` and `areachange` end with an `overlay-loads` checkpoint (STING Ctrl-Y), recorded but not compared;
`tests/ovlloads.py` prints both builds' counts from the last run's `obj/regress.json`, the measure of the overlay
working sets.

The golden build is this game's own, of a recent commit: the scenarios follow today's menus, and `golden:` steps are
left for a golden build that needs other keys (SSI's, in `ssiformat`). After an interface change that moves a
scenario's keys or waits, fix the scenario, then record fresh goldens from the merge commit, one record a mode:

```
sha=$(git rev-parse --short HEAD); g=.golden/$sha
scripts/build.sh && mkdir -p $g && cp obj/START.EXE obj/GAME.OVR drive_c/POOLRAD/SBSFX.DAT $g/
tests/regress.sh $g $g          # EGA, then each mode the same way:
VIDEO=cga tests/regress.sh $g $g; VIDEO=tandy tests/regress.sh $g $g; VIDEO=vga tests/regress.sh $g $g
SOUND=adlib tests/regress.sh $g $g; SOUND=sb tests/regress.sh $g $g; MEMSIZE=16 tests/regress.sh $g $g
```

With no scenario named, `regress.sh` leaves out `ssiformat`, whose golden is SSI's v1.3; it runs on its own, as its
row below says.

A new scenario should first be run against the golden build twice (`tests/regress.sh GOLDEN GOLDEN scenario.txt`): it
must pass, or it depends on something other than the build (timing, a key arriving early). A frame that differs while
the text matches (an animated picture) is only a warning.

| scenario | covers |
| --- | --- |
| `boot` | the main menu, the settings screen and its Camp and Sound pages; with `SOUND=none` (no sound device, #1156) the Sound page reads Music and Sound OFF, every line grey |
| `chargen` | creating a paladin with fixed dice, the portrait picker (Escape doing nothing there) and the icon picker, the `.CHA` file written, adding him |
| `loadsave` | the Load/Save menu, loading A, View and More Info (its saves, statistics and a thief's skills), the save popup, the files a save writes (the `.MAP` with them) |
| `combat` | resting in Podal Plaza until orcs come, a Quick fight, the loot, Take, the statistics |
| `vault` | walking New Phlan to the vault, a deposit, leaving and returning |
| `journal` | the journal list with its first item previewed, and the second selected |
| `journalfound` | the Journal listing what the party has found (#1090), from save A in New Phlan's tavern at (10,8) with an empty `savgamA.jnl` (`saves/journal`): the empty Journal, a tavern tale overheard after declining to gamble, and the Journal listing that tale alone; the golden build lists every item, so its two journal checkpoints differ by design |
| `camp` | Fix and Rest in Valhingen Graveyard, Scribe's message for a character without magic-user levels, and Escape leaving Alter's portrait picker with the portrait unchanged |
| `fixreport` | Fix's report (#1170, #1171): Use Potions and Use Paladin's Heal turned on on the Camp page, then Fix in camp from save J: "FIX: TALONIA USED POTION OF HEALING ON ANNA.", the item named once without its stack's count; the golden build words the lines "... during Fix." |
| `companion` | the Companion Tools (phase 8) turned on in Settings: the map, the character editor (levels, Modify, gear with a plus and bracers' AC, money, spells, health) and a note written on the map |
| `shop` | walking to the arms shop, Pool, buying a hand axe, the pack, selling it back |
| `areachange` | New Phlan's script handing over to the training hall's (NEWECL), named in the save popup |
| `wilderness` | the central wilderness from save G (`saves/wild`, put into `SAVE\` by the scenario): the map and its second tile set, three steps, and the overlay loads, heap and picture memory (Ctrl-Y; ours only) |
| `wildfight` | save G again: a 32-step walk that meets a random encounter under NORAND, the fight's start, and the memory there |
| `wildafter` | VGA only (`#video vga`, #1218): save G, wildfight's walk, a Quick fight, No to Continue Battle and Exit from the loot, then the wilderness menu back (not "Out of memory", which the second tile set's reload in a 65K block gave on a 1 MB machine) and Ctrl-Y's overlay loads, heap and picture memory |
| `wildmoveafter` | VGA only (#1218, #1186): wildafter in Move mode, the wide view back beside the second tile set after the fight, its status line and Exit, and Ctrl-Y's figures; a golden build without Move fails at its first wait |
| `cloudkill` | Cloudkill in combat (#1193), from save I's party in Podal Plaza with Andrea made a 9th-level magic-user with Cloudkill memorized (`saves/cloudkill`, slot D; the spell was put into her `.chx` memorized slots): three rests draw orcs, Andrea casts Cloudkill, the aim preview counts the orcs its 3x3 cloud catches, and the cloud kills them and stays on the map in its yellow art; the golden build has no Cloudkill, so it fails until the goldens are recorded from a build with it |
| `leadership` | paladin leadership (#1124) and the end of a fight (#1194), from cloudkill's fixture with TALONIA an 8th-level paladin and ANDREA an NPC under the computer (`saves/leadership`, slot D): three rests draw orcs, the fight opens with "Using leadership ability" and "TALONIA LEADS ANDREA.", Andrea's turn comes with the combat menu, a Quick fight ends in Continue Battle, Yes plays one more round and asks again, No ends it; the golden build has neither, so it fails until the goldens are recorded from a build with them |
| `minimap` | the combat minimap (#1210): Minimap (F3) turned on on the Settings screen's Combat page, then save I's party rests in Podal Plaza until orcs come: the first turn's menu with the arena under the creature's details, F3 taking it away and bringing it back, Aim marking the target on it, and a Quick fight to the end; the golden build has no minimap, so it fails until the goldens are recorded from a build with one |
| `widecombat` | the full-width combat view (#1211), from cloudkill's fixture (`saves/cloudkill`, slot D): Wide View turned off, on, off and on on the Settings screen's Combat page; three rests draw orcs; the fight 13 squares by 6 with the creature's line under it; Ctrl-Y's memory; F3 saying there is no minimap; Andrea's spell list, Cloudkill's aim with its preview and the orc on the info line, the cloud on the map, Ctrl-Y again (the memory lines are ignored in the comparison: read them in `obj/regress.json`) |
| `weaponsets` | weapon sets (#1209), from cloudkill's fixture with a long bow added to TALONIA's items after her shield (`saves/weaponsets`, slot D): on her Items screen 2 tags the arrows and bow and 1 the sword and shield (the Set column), a quick save and load keeps them (her `.chx`), three rests draw orcs, and on her turn the combat menu ends in `1 2`, 2 readies the bow and arrows and 1 the sword and shield (the info panel's weapon); the golden build has no weapon sets, so it fails until the goldens are recorded from a build with them |
| `wildmove` | the wilderness's Move mode (#1159) and its wide view (#1186), from save G (`saves/wild`): Move turns the top of the screen to one map 13 tiles across and the line to the status and Exit; a step west to Phlan's eastern edge narrows the view for the city's picture and menu, the party list back, and LEAVE widens it again; Page Up steps north-east and Home north-west (18 hours each), Right east (12), F1's keys and Alt-2's items come back to the wide view, Escape gives the menu and the 5x5 view back, and Home there picks the previous character; the golden build has no Move, so it fails until the goldens are recorded from a build with it (and `wilderness` and `outpost` differ by their menu line) |
| `altitems` | Alt-1 to Alt-8 (#1175), from save G (`saves/wild`): Alt-2 opens the second member's items, Alt-3 there switches to the third's in place (#1195), and Escape puts the wilderness back, Alt-7 with six members does nothing, F1 lists the Alt keys, and Alt-1 in camp opens the first member's items; the golden build has no Alt keys, so it fails until the goldens are recorded from a build with them |
| `trainanywhere` | Train Anywhere (#1212, #1215), from save G with Morrigan given 24,500 experience and 1,001 gp (`saves/trainanywhere`): F4 with the setting off does nothing and F1 leaves it out; the setting turned on in camp's Alter, Settings (its label TRAIN ANYWHERE (F4)); F1 lists F4; F4 on the wilderness map opens the hall's menu with Train, View, Dual Class and Exit; Morrigan trains to 5th level for 1,000 gp and then lacks the experience; Gins, drained, refused Dual Class; Morgan's Dual Class screen; Escape gives the map back, View shows Morrigan's level and purse; F4 in camp, Exit back to camp. The golden build has no F4, so it fails until the goldens are recorded from a build with it |
| `altshop` | Alt-1 to Alt-8 at the New Phlan arms shop (#1195), from save A: Alt-2 at the counter opens Anna's items with Sell and Id, Alt-3 there switches to Gins's in place, Gins sells a scroll (her purse before and after), Escape gives the counter back with Gins current; Alt-1 in the Buy list opens Talonia's items and Escape gives the list back; Alt-4 on the View page opens Spawn's items and Escape shows Spawn's sheet |
| `helppages` | F1 on the shop's Buy screen and the Items screen, from save A at the New Phlan arms shop: its keys over the stock and Exit back, then View, Items, its keys (the weapon-set keys, Alt-n) and Exit back; the golden build has neither page, so it fails until the goldens are recorded from a build with them |
| `stojanow` | Stojanow Gate once taken (#683), from save A moved there (`saves/stojanow`): the cheer before the gatehouse and behind it, once a visit, and the guard room become barracks |
| `bane` | the Temple of Bane freed with Dirten in the party (#682), from save A moved beside its altar with a member made Dirten (`saves/bane`): the fight won with Alt-X, the farewell, the day kept in the save, the rebuilding |
| `banetemple` | Dirten's temple 14 days on (#682, `saves/banetemple`): his welcome, the temple, the twelve-line Heal list (#1125), Cure Light Wounds at 90 gold pieces, Repair's quote (this build only), the view restored |
| `banestuck` | a party stuck with Dirten (#1139), from bane's fixture with the temple freed without him and him in the party after (`saves/banestuck`): his farewell at the altar, then the rebuilding |
| `banealtar` | the Temple of Bane's altar destroyed on an earlier visit (#1139, `saves/banealtar`): its remains, not the offer to destroy it again |
| `bishop` | the bishop's study once the temple is freed without Dirten (#1139), save A on its square, (10,5) (`saves/bishop`): the bishop's thanks, Dirten not joining, `[$4A9C]` and `[$4A79]` in the save |
| `madman` | the Temple of Tyr with the Mad Man in the party (#1138), save A on its square, (8,4) (`saves/madman`): the priest's question, No (the greeting and the offer of healing), then Yes (he leaves the party) |
| `odran` | the Valhingen mage who joins (#1113, #1117), save A on his square, (8,9) (`saves/odran`): his offer, then Let Him Join: he joins as ODRAN and the view comes back at once |
| `coffin` | the vampire's coffin sanctified (#1096), save A on its square, (12,4), Anna carrying two vials of holy water and a holy symbol (`saves/coffin`): one vial used up, the symbol kept, then the crypt's remains |
| `coffinbare` | the vampire's coffin with nothing holy (#1096, `saves/coffinbare`): SANCTIFY refused, and the coffin as it was |
| `outpost` | the Zhentil Keep Outpost before the mission (#1116), save A in the western wilderness at (3,33) (`saves/outpost`): a step north, the riders' warning, LEAVE, the map back |
| `skullcrusher` | Skullcrusher leaving outside City Hall (#1168), save A on the square east of it, (5,4), event 26, the fifth and sixth members made Skullcrusher, the sixth unconscious (`saves/skullcrusher`): the standing one's farewell, then Cadorna's guard carting the fallen one away, and both gone |
| `skulldead` | a dead Skullcrusher outside City Hall (#1168, `saves/skulldead`): carted away and gone |
| `magicshop` | New Phlan's magic shop (#1091, #1158), save A on its square, (11,12) (`saves/magicshop`): the greeting, the counter, the stock (the wares, then the twelve scrolls), Buy on the first scroll listing its spells and asking, No; the golden build has the arms shop there, so its greeting and stock differ by design |
| `drained` | the View page's drained levels and secondary status (#1161, #1174), from repair's fixture with two members drained (`saves/drained`): MORRIGAN, a paladin drained twice with no drain log (an old save), shows `7 (-2)`; GINS, undrained, the old line; BLAIR, a fighter/magic-user/thief with a version 3 `.chx` logging a drain in each class, `8 (-1)/8 (-1)/8 (-1)` with Exp moved right; both drained read `Okay, Drained`. The golden build shows neither, so those two checkpoints differ by design |
| `advisory` | the startup advisory (#1173): Exit to DOS, then `START STING NORAND ADVISE` typed at the prompt on a fresh install (no POOLOPT.CFG): the support part (not the speed part, at the harness's 30000 cycles), a key to the main menu, and the next typed start straight to the main menu, then the System page with the same lines (the address's at sign drawn from `Advisory.AT_BITMAP`); the golden build has no advisory, so it fails until the goldens are recorded from a build with one |
| `repair` | Repair for a healthy party (#1155), from the save on the issue, its slot A put in slot H (`saves/repair`) on the Temple of Tyr's square in New Phlan, (8,4): the temple, "The party needs nothing the temple can give." held until a key (this build only), the view restored |
| `demo` | the demo (#1109) played to its end, started with `DEMO` (three seconds at the main menu): the C64's title portrait and six captions, Podol Plaza, the ogre in the view and up close, the last caption, then the main menu with no party and `SAVE\` untouched; `regress.sh` stages `DEMO.DAX` for it (from `src/binaries` into the candidate) and runs it apart from the scenarios without the demo, its report in `obj/regress-demo.json` (#1233), and a golden build without the demo fails at its first wait |
| `demoabort` | the demo (#1109) ended by a key: thirty seconds on the main menu start it, Space mid-walk ends it, another thirty seconds start it again and Space mid-battle ends that; each time the main menu with no party, `SAVE\` untouched, the System page's free memory and measured speed (ignored in the comparison: read them in `obj/regress.json`), then a new character rolling what `chargen`'s does and save A loading; `DEMO.DAX` staged as for `demo` |
| `nodemo` | no `DEMO.DAX` (#1109; `regress.sh` stages it only for `demo*`, which it runs apart from the rest, #1233): started with `DEMO` and left alone for 40 seconds, the main menu stays up with no error or disk prompt, and Create opens the race screen |
| `ssiformat` | against SSI's own v1.3 (`tests/regress.sh drive_c/POOLRAD/SSI obj tests/scenarios/ssiformat.txt`): the `.CHA` file Remove writes and the files saving A into D writes are SSI's (`CHARLIST.TXT` is left out: a party member stays on the roster, #754), with SSI's heap pointers, the unused name bytes and the saved script masked |
