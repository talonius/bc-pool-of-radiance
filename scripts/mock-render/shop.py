"""The shop's Buy screen (docs/screen-mocks/new-shop.txt): three sections, the scroll bar over the list section's
right edge only, between its joints on rows 2 and 16.

  python3 -I shop.py out.png [--top N]
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mockrender as m  # noqa: E402

# prices and items only show the layout
ITEMS = [(250000, 'FINE ELVEN COMPOSITE BOW'), (75, 'LONG BOW'), (35, 'SHORT BOW'), (30, 'TWO-HANDED SWORD'),
         (15, 'LONG SWORD'), (10, 'BROAD SWORD'), (8, 'SHORT SWORD'), (8, 'MACE'), (5, 'BATTLE AXE'),
         (5, 'MORNING STAR'), (3, 'FLAIL'), (2, 'DAGGER'), (1, 'HAND AXE'), (1, 'SPEAR'), (1, 'CLUB'),
         (20, 'HALBERD'), (10, 'GLAIVE'), (7, 'MILITARY PICK'), (6, 'SLING'), (20, 'LIGHT CROSSBOW')]
LIST_TOP, LIST_ROWS = 3, 13
TABS = [('ALL', 1), ('MELEE', 0), ('RANGED', 0), ('ARMOR', 0), ('AMMO', 1), ('MISC', 1)]


def extra(p):
    p.add_argument('--top', type=int, default=0, help='first item shown (0-based)')


a = m.main_args(__doc__, extra)
s = m.screen(a)
s.frame(dividers=(2, 16))
# tabs: the current one all white, the rest green with their command keys white
x = 1
for i, (word, key) in enumerate(TABS):
    if i == 0:
        s.text(x, 1, word, m.WHITE)
    else:
        for j, ch in enumerate(word):
            s.text(x + j, 1, ch, m.WHITE if j == key else m.LIGHT_GREEN)
    x += len(word) + 1
for k in range(LIST_ROWS):
    i = a.top + k
    if i >= len(ITEMS):
        break
    line = '%6d %s' % ITEMS[i]
    if k == 0:
        s.text(1, LIST_TOP + k, line.ljust(37), m.BLACK, m.WHITE)
    else:
        s.text(1, LIST_TOP + k, line, m.LIGHT_GREEN)
s.scrollbar(39, LIST_TOP, LIST_TOP + LIST_ROWS - 1, len(ITEMS), LIST_ROWS, a.top)
# the character panel
s.text(1, 17, '1:', m.WHITE)
s.text(4, 17, 'BRIANNA', m.LIGHT_CYAN)
s.text(17, 17, 'GOLD', m.WHITE)
s.right(28, 17, '128072', m.LIGHT_GREEN)
s.right(37, 17, '15102', m.LIGHT_GREEN)
for row, label, ac, dmg in ((18, 'CURR', '3', '1D8+1'), (19, 'NEW', '3', '1D6')):
    s.text(5, row, label, m.WHITE)
    s.text(10, row, 'AC', m.WHITE)
    s.right(14, row, ac, m.LIGHT_GREEN)
    s.text(19, row, 'DMG', m.WHITE)
    s.text(23, row, dmg, m.LIGHT_GREEN)
s.text(1, 20, 'PLATE ARMOR', m.LIGHT_GREEN)
s.right(37, 20, 'SHIELD', m.LIGHT_GREEN)
s.text(1, 21, 'FINE ELVEN COMPOSITE BOW', m.LIGHT_GREEN)
s.text(1, 22, '25 ARROWS +1', m.LIGHT_GREEN)
s.menu('SHOP: ', ['SHOWING ALL', 'Buy', 'Exit'])
s.save(a.out)
