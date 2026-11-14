# Mock renderer

Draws screen mocks with the game's own font and gold border symbols (from `drive_c/POOLRAD/8X8D1.DAX`), so a mock in
`docs/screen-mocks/` can be checked as the game would draw it. The rules the mocks follow are in `docs/ui-design.md`.

Needs Pillow and [goldbox-re-tools](~/repos/goldbox-re-tools) (set `GOLDBOX_RE_TOOLS` if it is elsewhere). Run with
`python3 -I` (the scripts find `mockrender.py` beside them):

    python3 -I scripts/mock-render/loadsave.py docs/screen-mocks/scrollbar.png    # also writes scrollbar-edge.png
    python3 -I scripts/mock-render/shop.py docs/screen-mocks/new-shop.png
    python3 -I scripts/mock-render/character.py docs/screen-mocks/view-character.png
    python3 -I scripts/mock-render/glyphs.py /tmp/glyphs.png                       # every 8x8 symbol, numbered

`loadsave.py --title-color yellow` tries a title color; `--showcase` draws each slot line in another EGA color; `--top N`
scrolls (moves the knob). `shop.py --top N` does the same.
`character.py --better <color> --better-bg <color>` tries colors for "improved"; `--name-color light-magenta` shows a name ready to train.

`mockrender.py` holds the pieces: `Screen.frame` (a border with dividers and their joints), `Screen.title` (a title in
the top edge), `Screen.scrollbar` (the edge scroll bar over one section), `Screen.menu` (the bottom line), `Screen.text`.
Every screen script takes `--dim`: its text in the dim colors (0-7), the border unchanged.

A new screen's mock is a short script on top of it.
