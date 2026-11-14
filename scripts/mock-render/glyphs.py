"""A sheet of the 8x8 symbols in 8X8D1.DAX: block 203 (symbols 1..) and block 202 (256..), magnified and numbered,
transparent (light magenta) shown as magenta. For finding a symbol to draw or recolor.

  python3 -I glyphs.py out.png
"""
import os
import struct
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mockrender as m  # noqa: E402
from goldbox.dax_tool import parse_header, extract_block  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

a = m.main_args(__doc__)
data = open(a.dax, 'rb').read()
off, ents = parse_header(data)
blocks = {e.block_id: extract_block(data, off, e) for e in ents}
S, COLS = 6, 16
CELL = 8 * S + 14
sets = []
for rec, first in ((203, 1), (202, 256)):
    b = blocks[rec]
    h, w, _, _, cnt = struct.unpack_from('<HHHHB', b, 0)
    p, frames = 17, []
    for _ in range(cnt):
        px = []
        for _ in range(h):
            row = []
            for _ in range(w * 4):
                row += [b[p] >> 4, b[p] & 15]
                p += 1
            px.append(row)
        frames.append(px)
    sets.append((rec, first, frames))
rows = sum((len(f) + COLS - 1) // COLS for _, _, f in sets) + 2
img = Image.new('RGB', (COLS * CELL + 10, rows * (CELL + 12) + 20), (40, 40, 40))
d = ImageDraw.Draw(img)
y = 5
for rec, first, frames in sets:
    d.text((5, y), 'record %d: symbols %d..%d' % (rec, first, first + len(frames) - 1), fill=(255, 255, 255))
    y += 14
    for i, fr in enumerate(frames):
        cx, cy = 5 + (i % COLS) * CELL, y + (i // COLS) * (CELL + 12)
        for r, row in enumerate(fr):
            for c, v in enumerate(row):
                d.rectangle([cx + c * S, cy + r * S, cx + c * S + S - 1, cy + r * S + S - 1],
                            fill=(255, 0, 255) if v == m.LIGHT_MAGENTA else m.EGA[v])
        d.text((cx, cy + 8 * S + 1), str(first + i), fill=(200, 200, 200))
    y += ((len(frames) + COLS - 1) // COLS) * (CELL + 12) + 6
img.save(a.out)
