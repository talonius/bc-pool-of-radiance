# Screen and menu design

How the game's screens look and how they are driven: layout, color, keys, scrolling, and how a screen is drawn. It is
the reference for new screens and for bringing old ones into line. Where a rule is not decided yet it says so, under
**Open**; the list of open questions is at the end.

The mocks in `docs/screen-mocks/` show screens built to these rules; `scripts/mock-render/` draws a mock with the
game's own font and border symbols.

This covers the game's screens (40x25 cells of 8x8 pixels, EGA and VGA). The setup program's text-mode screens
(`poolcfg`, `TuiKit`) are another medium; they follow the color roles where they can.


## Principles

- **One way to do a thing.** A list scrolls the same way, says there is more the same way, and colors a key the same
  way on every screen.
- **Arrow keys first.** The arrows work wherever they do not clash with something the screen already uses them for.
- **Room to breathe.** A space between the border and the text, and a blank line where it helps reading. The screen is
  only 40x25, so this gives way when a screen needs the room, but it is the default.
- **Draw only what changed.** Nothing is cleared to be drawn again the same, and no edge is drawn twice (Drawing).
- **A color means one thing.** Colors are chosen by role (Color), not picked per screen.


## The screen

The screen is a grid of 40 columns (0-39) by 25 rows (0-24). Row 24 is the **bottom line**: the menu or prompt, outside
any frame. Rows 0-23 hold the windows.

### Frames and sections

A window is a **frame**, the gold border, split into **sections** by **dividers**: a divider is a horizontal edge across
the frame, with a corner box at both of its ends where it meets the frame's sides (a **joint**). The shop's Buy screen
is one frame of three sections: the tabs, the list, and the character panel (`new-shop.txt`).

A screen is drawn as one frame with dividers, not as boxes laid over each other, so each edge is drawn once and the
frame knows where its joints are. (Today the Buy screen draws three boxes whose shared edges are drawn twice, and
`Border` keeps one joint, the map window's lower right, by a special case, #1172.)

### Titles

A frame's title goes in its **top edge**, centred: a corner box, a space, the title, a space and a corner box.

    +==========+ LOAD/SAVE GAME +==========+

The old way, a title row inside the frame with a divider under it, costs two rows; the title in the edge gives them back
to the screen (Load/Save gains a slot from it). A screen that keeps SSI's look can still put a title on its first text
row as `Border.DrawWindow` does (#977).

### Padding

Text starts one column in from the border (column 2 inside a full-screen frame) and ends one column short of it. A list
leaves a blank row under the top edge where there is room. When a screen cannot fit with the padding, the padding goes
first, before anything is abbreviated.

### Data in the border

The border can carry something besides a title, such as a page count or a status, but rarely, and never so much of the
border that redrawing it costs like redrawing the screen. The scroll bar is the one thing that takes over an edge.


## Color

The game draws in the 16 EGA colors. CGA no longer limits it, but a color is used for a reason, not because it is
available. Note the EGA names: **Yellow** (14) is the bright yellow; the dim one, 6, shows as **Brown**.

### Roles

| Role | Color | Notes |
|---|---|---|
| Key, in a key/value pair (`GOLD`, `AC`, `DMG`) | White (15) | |
| Value, in a key/value pair | Light Green (10) | |
| Command key (the hotkey letter of a menu option) | White (15) | always |
| Menu option text | Light Green (10) | the bottom line's other letters |
| Current menu option | inverse video: black on White | #1160 |
| Prompt (`GAME:`, `SHOP:`) | Light Magenta (13) | the bottom line's query |
| Header (a section's heading, a column heading) | Light Magenta (13) | |
| Title (in the frame's top edge) | **Open**: White for now | see below |
| Character name | Light Cyan (11) | |
| Character name, ready to train | Light Magenta (13) | as in Pools of Darkness |
| Character name, out of action | Light Red (12) | |
| Creature name, hostile | Yellow (14) | |
| Not normal (injured hit points, a warning) | Yellow (14) | |
| Bad, negative (a loss, a failure, a worse value) | Light Red (12) | |
| Improved (a better value, a bonus) | **On trial**: Light Blue (9) | see below |
| Unavailable (a command or entry that cannot be taken) | Dark Gray (8) | |
| Scroll bar | White, Light Gray, Dark Gray, Black | scrollbar.txt |

The names follow `CharDisp.NameColor`, which every name should be drawn through. (View Character's name,
`viewchar.pas:377`, is light cyan by hand, so it misses the other three.)

The dim colors (1-7) look washed out next to the bright ones on a black screen, so text is in a bright color. A dim
color is for something that should recede: the scroll bar's track, an unavailable entry.

### Open: titles

White is the safe choice: it means nothing else here, and the title is the one white thing in the top edge. The others
tried each carry another meaning: Yellow means "not normal", Light Magenta is a header and a name ready to train, and
Light Cyan is a character's name. A title is seldom next to those, so the clash may not matter in practice; this needs
trying on real screens. `loadsave.py --title-color <color>` renders the choices.

### On trial: statuses and "improved"

Status text (a condition, a spell in effect, a comparison) sits badly in green: green is every value, so a status in
green does not stand out from them. Yellow already means "not normal" and Light Red "bad", so what is missing is a color
for **improved** that is not green. **Light Blue** (9) is on trial: the View Character mock
(`docs/screen-mocks/view-character.png`) shows a Strength spell's score and haste's movement in it, beside injured hit
points in yellow and Poisoned in light red. It is darker than the other bright colors, which may suit a status, or may
read as dim; it needs a look on the real screen. `character.py --better <color>` renders others. The shop's comparison
(NEW AC and DMG against CURR) is the next place to try it.

### In code

Colors are **global variables, one per role**, in one unit (say `UiColor`, used qualified as the sources do:
`UiColor.headerColor`) and set to the defaults above at start-up, instead of each call passing `LightGreen` or
`White`:

    keyColor, valueColor, commandColor, optionColor, promptColor, headerColor, titleColor,
    partyColor, trainColor, downColor, hostileColor, warnColor, badColor, betterColor, unavailableColor

The name colors are `partyColor`, `trainColor`, `downColor` and `hostileColor`, not `nameColor`: Pascal ignores case,
so a `nameColor` would clash with `CharDisp.NameColor`, the function that picks among them. A variable, not a
constant, so a color can be changed while the game runs: to try title colors without rebuilding, and later from a
setting if colors become a choice. A screen that disagrees with the rest shows up in a search. Screens move to the
roles as they are touched; the bottom line's three (`MenuHorizontal`'s qCol, mCol and hlCol, passed at 33 call sites
as LightMagenta, LightGreen, White) are the first.


## Keys

### Everywhere

| Key | Does |
|---|---|
| Up, Down | move a line in a list |
| Left, Right | move the bottom line's current option |
| Page Up, Page Down | move a page in a list (or a page of text) |
| Home, End | the list's first and last entry |
| Tab, Shift-Tab | move to the next or the previous section that takes keys (see Focus) |
| Enter | take the current list entry, or the bottom line's current option where there is no list |
| Escape | back out: the same as Exit |
| A command key | its option, at once |
| F1 | the screen's keys (KeyHelp): every screen this design touches gets them |
| Alt-1 to Alt-8 | a party member's items, where the screen offers it (#1195) |

### Where the arrows are taken

The arrows work on every screen except where the screen already uses them for something else. Known:

- **The overland map**: the arrows move the party.
- **The 3D view**: the arrows move and turn.
- **Combat**: the arrows (and keypad) move and aim. (To check: the combat menus between moves may be free to use them.)
- **Text entry** (a name, a description): Left and Right move in the text.

Others may turn up; add them here.

### Lists

A list scrolls a line at a time: Down on its last row shown brings the next line into view, and Up on its first row the
line before. It **stops at its ends**; it does not wrap. Page Up and Page Down move a page, stopping at the ends. A list
longer than its section shows a **scroll bar**. There is no Next or Prev on the bottom line for a list, and no `(more)`.

Home and End go to the list's first and last entry. (Today `SaveMenu` takes them as Up and Down, as the keypad's 7 and 1
are the diagonals; on a list they are the ends, as in any modern list.)

### Stepping through records

Some screens step through things rather than scroll a list: the next monster in the bestiary (`beastmnu`), the next
portrait in character creation, the next target when aiming. These have Next and Prev today.

On those screens **Up and Down step** to the previous and the next record: they show no list, so the keys are free,
and Left and Right stay with the bottom line. Next and Prev leave their bottom lines.

### Focus: Tab and Shift-Tab

A screen with more than one section that takes keys moves between them with **Tab**, and back with **Shift-Tab**,
wrapping. The section that has the keys (the focus) is the one the arrows, Page Up/Down and Home/End act on. The first
use is the journal: Tab from the list of entries to the entry's text, and the arrows scroll the text.

The focused section must be visible as such. **Open:** how; the candidates are the scroll bar (only the focused
section's knob shows its grip, or the unfocused bar is dimmed) and the cursor (the unfocused list's cursor in Dark Gray
rather than inverse).

### Help

Every screen this design changes gets **F1** help: its keys, through `KeyHelp.ShowPage` (as the shop's Buy screen and
the Items screen have), and listed in its mock. A screen is not finished without it.


## The scroll bar

`docs/screen-mocks/scrollbar.txt` has the pieces and their pixels; `scrollbar.png` and `scrollbar-edge.png` show it.

- It is drawn **over the right edge of the section it scrolls**, between that section's corners or joints, and only
  while the list is longer than the section. When the list fits, the edge is the plain border.
- It runs the length of **its section, not the window**: on the Buy screen, rows 3 to 15 between the joints on rows 2
  and 16; the tabs and the character panel keep their border.
- The arrows take its first and last rows; the knob moves on the rows between (the track). The knob's share of the
  track is the share of the list shown, **rounded**, at least a row; it touches the top arrow only at the list's start
  and the bottom arrow only at its end. A knob of three cells or more has the grip on its middle cell.
- The pieces are finished cells the Data Builder writes to a DAX file; the game recolors nothing while it runs.

For the code: `MenuCore.ScrollThumb` sizes the knob to the list box's own height and rounds down, because the old bar
had no arrows. The edge bar's track is two rows shorter than the section and is counted in rows while a list may count
entries of several rows (a Load/Save slot is three), so ScrollThumb takes the track's length as well as the list's
(`mockrender.scroll_thumb` is the version the design asks for). `Sym8x8.Put8x8Sym` stops at symbol 286, and the gold
border set runs 276-285, so the bar's cells need symbol numbers past it.


## Drawing

Text and the border are drawn straight onto the visible screen (only the 3D view goes through a buffer), so whatever is
drawn twice is drawn twice where the player sees it, and a box cleared to be drawn again goes black for a moment. Each
glyph on EGA is 32 port writes and 32 memory writes.

- **Move the cursor: redraw two entries**, the one left and the one taken. Not the list.
- **Scroll: redraw the entries shown, in place**, each padded out to the section's width so it covers the last one.
  Do not clear the section first.
- **The scroll bar: redraw the cells that changed**, those the knob left and entered.
- **Edges once.** A frame draws each edge and joint once; a scroll bar is drawn after the edge it covers, and whatever
  redraws that edge redraws the bar after it.
- **Clear only what will not be drawn over.** The screen is cleared when a screen opens, not on every key.

Today Load/Save clears its list box (798 cells) and redraws all seven slots on every arrow key, where two slots
changed; `MenuVertical` clears its box before every page it draws, though every line it draws is already padded.


## The parts

What a screen is built from. Today's units, and where they are going:

| Part | Today | To be |
|---|---|---|
| Frame | `Border.DrawBorder` per box, `DrawWindow`, `ClearToFrame`; one joint kept by special case | a frame with dividers, joints, a title in its top edge, and a scroll bar on a section's edge |
| List | `MenuVertical` for lists of one-line strings, its behaviour set by globals (`fullPaging`, `lineScroll`, ...); about ten screens with lists of their own (Load/Save, the journal, the kill count, spell info, help pages) | one list: a section, the entry count, rows per entry, the first entry shown and the cursor, and a routine that draws an entry. It scrolls, stops at its ends, shows the bar, and redraws only what changed. `MenuVertical` becomes a list whose entries are strings |
| "There's more" | `(more)` (`MenuCore.DrawMore`), Next/Prev, the text bar `*`/`-` | the scroll bar |
| Bottom line | `MenuCore.MenuHorizontal` | unchanged |
| Colors | literal colors at every call | a global variable per role |

The order of the work and its steps are in the Forge issue for this refactor.


## Mocks

A screen's mock (`docs/screen-mocks/<screen>.txt`) is drawn in text: `=` and `|` the border, `+` a corner box or joint,
and the scroll bar's pieces as `scrollbar.txt` gives them. Under the picture: the command keys, the colors of anything
that is not as this document says, and any rule the screen adds. Where colors or pixels matter, `scripts/mock-render/`
draws it with the game's own glyphs (its README says how).


## Curse, Secret and Pools

The other Gold Box ports share the font and most of these screens, so these rules are meant for them too; a rule
decided here should be decided once.

The borders are another matter. Pool's border is a single 8x8 cell wide. The later games' are more intricate: Curse's is
a stone frame with a dotted rule inside it, its joints are stone, and its windows sit inside it with a black margin.
The rules (sections, a title in the top edge, the scroll bar over the scrolled section's right edge) hold, but each
game needs its own cells for the bar, the corners that hold a title, and the joints, drawn to its border, and its
frame code may need more than one cell's width to place them.


## Open questions

1. Title color: White, Yellow, Light Cyan or another (Color).
2. Light Blue for "improved": keep it after seeing it on the real screen? (Color)
3. Whether combat's menus can take the arrows between moves (Keys).
4. How the focused section shows (Keys, Focus).

Decided 2026-11-13: Dark Gray for unavailable commands and entries; Home and End go to a list's ends; Up and Down step
through records; Tab and Shift-Tab move the focus; F1 help on every screen this design changes.
