"""Load/Save Game (docs/screen-mocks/load-save-game.txt, scrollbar.txt): the title in the top edge, seven of eleven
slots, the scroll bar over the right edge between the corners.

  python3 -I loadsave.py out.png                       the mock's colors
  python3 -I loadsave.py out.png --title-color yellow  try another title color
  python3 -I loadsave.py out.png --showcase            each slot line in another EGA color (scrollbar.png)
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mockrender as m  # noqa: E402

SLOTS = [('A', 'SAVE GAME A', '8:57 PM', 'NEW PHLAN', '2026/10/21'),
         ('B', 'BIG FIGHT', '8:39 PM', 'VALHINGEN GRAVES', '2026/10/21'),
         ('C', 'SPELLED UP', '8:03 PM', "YARASH'S PYRAMID", '2026/10/21'),
         ('D', 'SAVE GAME D', '12:04 PM', 'TRAINING HALL', '2026/10/17'),
         ('E', 'SAVE GAME', '8:47 PM', 'VALHINGEN GRAVES', '2026/10/21'),
         ('I', 'SAVE GAME I', '9:01 PM', 'PODOL PLAZA', '2026/09/08'),
         ('J', 'SAVE GAME J', '7:00 PM', 'NEW PHLAN', '2026/11/12')]
SLOT_COUNT = 11
# --showcase: two lines a slot, each another color (not black, not white)
SHOWCASE = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 13]


def extra(p):
    p.add_argument('--title-color', default='white')
    p.add_argument('--showcase', action='store_true')
    p.add_argument('--top', type=int, default=0, help='first slot shown (0-based), for the knob')


a = m.main_args(__doc__, extra)
s = m.screen(a)
s.frame()
s.title('LOAD/SAVE GAME', m.color(a.title_color))
for k, (letter, desc, clock, area, date) in enumerate(SLOTS):
    row = 2 + 3 * k
    if a.showcase:
        c1, c2 = SHOWCASE[2 * k], SHOWCASE[2 * k + 1]
    else:
        c1 = c2 = m.WHITE if k == 0 else m.LIGHT_GREEN
    if k == 0:
        s.text(2, row, letter + ':', m.BLACK, m.WHITE)
    else:
        s.text(2, row, letter, m.WHITE)
        s.text(3, row, ':', c1)
    s.text(5, row, desc, c1)
    s.right(36, row, clock, c1)
    s.text(5, row + 1, area, c2)
    s.right(36, row + 1, date, c2)
s.scrollbar(39, 1, 22, SLOT_COUNT, len(SLOTS), a.top)
s.menu('GAME: ', ['Load', 'Next', 'Prev', 'Quit to dos', 'eXit'])
s.save(a.out, edge=(35, 6))
