"""Render screen mocks with the game's own font and border symbols (docs/ui-design.md, docs/screen-mocks/).

A Screen is the 320x200 EGA picture as a 40x25 grid of 8x8 cells. Text is drawn in the game font (8X8D1.DAX block 201)
and borders in symbols 256..286 (block 202), so a mock shows what the game would draw. The scroll bar pieces follow
docs/screen-mocks/scrollbar.txt.

Needs Pillow and goldbox-re-tools (its src on the path: GOLDBOX_RE_TOOLS, default ~/repos/goldbox-re-tools).
"""
import os
import sys

TOOLS = os.environ.get('GOLDBOX_RE_TOOLS', os.path.expanduser('~/repos/goldbox-re-tools'))
sys.path.insert(0, os.path.join(TOOLS, 'src'))
from goldbox.dax_tool import parse_header, extract_block  # noqa: E402
from PIL import Image  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DEFAULT_DAX = os.path.join(REPO, 'drive_c', 'POOLRAD', '8X8D1.DAX')

# EGA colors by number, and their names as the Pascal sources use them
EGA = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), (170, 0, 0), (170, 0, 170), (170, 85, 0), (170, 170, 170),
       (85, 85, 85), (85, 85, 255), (85, 255, 85), (85, 255, 255), (255, 85, 85), (255, 85, 255), (255, 255, 85),
       (255, 255, 255)]
(BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, BROWN, LIGHT_GRAY, DARK_GRAY, LIGHT_BLUE, LIGHT_GREEN, LIGHT_CYAN,
 LIGHT_RED, LIGHT_MAGENTA, YELLOW, WHITE) = range(16)
COLOR_NAMES = {n.lower().replace('_', ''): i for i, n in enumerate(
    ['BLACK', 'BLUE', 'GREEN', 'CYAN', 'RED', 'MAGENTA', 'BROWN', 'LIGHT_GRAY', 'DARK_GRAY', 'LIGHT_BLUE',
     'LIGHT_GREEN', 'LIGHT_CYAN', 'LIGHT_RED', 'LIGHT_MAGENTA', 'YELLOW', 'WHITE'])}

# the gold border set (Border.BORDER_SYM_BASE): corner box, vertical edge, horizontal edge
CORNER_SYM, VERT_SYM, HORZ_SYM = 276, 277, 278


def color(name):
    """An EGA color from a number or a name such as 'yellow' or 'light-cyan'."""
    if isinstance(name, int) or name.isdigit():
        return int(name)
    return COLOR_NAMES[name.lower().replace('-', '').replace('_', '')]


def art(rows, cmap):
    """An 8x8 cell from 8 strings of picture characters, each mapped to a color by cmap."""
    return [[cmap[ch] for ch in r] for r in rows]


# scroll bar pieces (scrollbar.txt): '-' grey, '*' white, '.' black on the arrows; W g d . on the knob
_ARROW = {'-': LIGHT_GRAY, '*': WHITE, '.': BLACK}
UP_ARROW = art(['--------', '---*----', '--***---', '-*****--', '--***..-', '--***.--', '---...--', '--------'], _ARROW)
DOWN_ARROW = art(['--------', '--***---', '--***.--', '--***.--', '-*****--', '--***..-', '---*..--', '----.---'],
                 _ARROW)
TRACK = [[DARK_GRAY if (r + c) % 2 == 0 else BLACK for c in range(8)] for r in range(8)]


def knob_cell(first, last):
    """A knob cell: white left edge, dark grey right edge, white top on the first cell, dark grey bottom on the last."""
    return [[DARK_GRAY if c == 7 or (last and r == 7) else (WHITE if c == 0 or (first and r == 0) else LIGHT_GRAY)
             for c in range(8)] for r in range(8)]


def scroll_thumb(count, shown, track, top):
    """The knob's first track row (from 0) and length for a list of count entries, shown at once, on track rows, whose
    first entry shown is top. The knob's share of the track is the share of the list shown, rounded, at least a row;
    it touches the track's top only at the list's start and its bottom only at its end (scrollbar.txt).

    MenuCore.ScrollThumb has no track argument (its bar is as long as the list box) and rounds the length down; the
    edge bar's arrows make the track shorter than the box, so this is the version the design asks for."""
    if track < 1 or count <= shown:
        return 0, track
    size = max(1, (2 * track * shown + count) // (2 * count))
    top = max(0, min(top, count - shown))
    room = track - size
    first = (top * room + (count - shown) // 2) // (count - shown)
    if first == 0 and top > 0 and room > 1:
        first = 1
    if first == room and top < count - shown and first > 1:
        first -= 1
    return first, size


class Screen:
    def __init__(self, dax=DEFAULT_DAX):
        data = open(dax, 'rb').read()
        off, ents = parse_header(data)
        blocks = {e.block_id: extract_block(data, off, e) for e in ents}
        self.font = blocks[201]
        self.syms = blocks[202]
        self.px = [[BLACK] * 320 for _ in range(200)]

    def symbol(self, n, remap=None):
        """Symbol n (256..286) as an 8x8 cell, its colors remapped through remap."""
        p = 17 + (n - 256) * 32
        cell = []
        for _ in range(8):
            row = []
            for _ in range(4):
                v = self.syms[p]
                p += 1
                row += [v >> 4, v & 15]
            cell.append([remap.get(v, v) for v in row] if remap else row)
        return cell

    def put(self, col, row, cell):
        for r in range(8):
            self.px[row * 8 + r][col * 8:col * 8 + 8] = cell[r]

    def text(self, col, row, s, fg, bg=BLACK):
        """s in the game font from (col, row), as TextRend.DisplayStringOn draws it (upper-cased, mod 64)."""
        for i, ch in enumerate(s):
            g = ord(ch.upper()) % 64
            for r in range(8):
                bits = self.font[g * 8 + r]
                self.px[row * 8 + r][(col + i) * 8:(col + i) * 8 + 8] = [
                    fg if bits & (0x80 >> c) else bg for c in range(8)]

    def right(self, endcol, row, s, fg, bg=BLACK):
        """s ending in column endcol."""
        self.text(endcol - len(s) + 1, row, s, fg, bg)

    def frame(self, left=0, top=0, right=39, bottom=23, dividers=()):
        """A border with its corners on (left, top) and (right, bottom), and a divider across it on each row in
        dividers, a corner box at both its ends (the joints)."""
        horz, vert, corner = self.symbol(HORZ_SYM), self.symbol(VERT_SYM), self.symbol(CORNER_SYM)
        for r in range(top, bottom + 1):
            self.put(left, r, vert)
            self.put(right, r, vert)
        for r in (top, bottom, *dividers):
            for c in range(left, right + 1):
                self.put(c, r, horz)
            self.put(left, r, corner)
            self.put(right, r, corner)

    def title(self, s, fg=WHITE, left=0, right=39, row=0):
        """s centred in a top edge: a corner box, a space, s, a space and a corner box (load-save-game.txt)."""
        corner = self.symbol(CORNER_SYM)
        start = left + (right - left + 1 - (len(s) + 4)) // 2
        self.put(start, row, corner)
        self.text(start + 1, row, ' ' + s + ' ', fg)
        self.put(start + len(s) + 3, row, corner)

    def scrollbar(self, col, top, bottom, count, shown, first_shown):
        """The scroll bar over the edge from row top to row bottom (the rows between a section's corners or joints):
        arrows on its ends, the knob and track between. Nothing is drawn when the list fits."""
        if count <= shown:
            return
        track = bottom - top - 1
        first, size = scroll_thumb(count, shown, track, first_shown)
        self.put(col, top, UP_ARROW)
        self.put(col, bottom, DOWN_ARROW)
        for r in range(track):
            self.put(col, top + 1 + r, TRACK)
        if size == 1:
            self.put(col, top + 1 + first, knob_cell(True, True))
            return
        for i in range(size):
            self.put(col, top + 1 + first + i, knob_cell(i == 0, i == size - 1))
        if size > 2:
            # the grip: the corner box recolored grey (yellow to grey, brown to dark grey), the knob's edges kept
            box = self.symbol(CORNER_SYM, {YELLOW: LIGHT_GRAY, BROWN: DARK_GRAY})
            grip = [[DARK_GRAY if c == 7 else (WHITE if c == 0 else box[r][c]) for c in range(8)] for r in range(8)]
            self.put(col, top + 1 + first + size // 2, grip)

    def menu(self, query, options, current=0, row=24, query_color=LIGHT_MAGENTA, menu_color=LIGHT_GREEN,
             key_color=WHITE):
        """A bottom-line menu as MenuCore.MenuHorizontal draws it: the query, then each option with its capitals (the
        hotkeys) in key_color and the rest in menu_color, the current one in inverse video (black on key_color).
        Write an option's hotkey as its only capital ('eXit'), or all capitals for a whole-word key."""
        self.text(0, row, query, query_color)
        x = len(query)
        for i, opt in enumerate(options):
            if i == current:
                self.text(x, row, opt, BLACK, key_color)
            else:
                for j, ch in enumerate(opt):
                    self.text(x + j, row, ch, key_color if ch.isupper() or ch.isdigit() else menu_color)
            x += len(opt) + 1

    def save(self, path, edge=None, scale=3):
        """The picture at scale, and with edge=(col, zoom) also its last columns from col, zoomed (the -edge.png)."""
        img = Image.new('RGB', (320, 200))
        img.putdata([EGA[v] for row in self.px for v in row])
        big = img.resize((320 * scale, 200 * scale), Image.NEAREST)
        big.save(path)
        if edge:
            col, zoom = edge
            x = col * 8 * scale
            crop = big.crop((x, 0, 320 * scale, 200 * scale))
            crop.resize((crop.width * zoom // scale, crop.height * zoom // scale), Image.NEAREST).save(
                path.replace('.png', '-edge.png'))


def main_args(description, extra=None):
    """Common arguments: the output png and the DAX; extra(parser) adds a screen's own."""
    import argparse
    p = argparse.ArgumentParser(description=description)
    p.add_argument('out', help='png to write')
    p.add_argument('--dax', default=DEFAULT_DAX, help='8X8D1.DAX (default: drive_c/POOLRAD)')
    if extra:
        extra(p)
    return p.parse_args()
