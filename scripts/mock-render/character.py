"""View Character under docs/ui-design.md (docs/screen-mocks/view-character.txt): the name as the title in the top
edge, keys white and values green, headers light magenta, and the status colors: improved (a spell's Strength, haste's
Movement, a value's color on a blue background), not normal (injured hit points) and bad (poisoned).

  python3 -I character.py out.png [--better light-green] [--better-bg blue] [--name-color light-cyan]
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mockrender as m  # noqa: E402


def extra(p):
    p.add_argument('--better', default='light-green', help='the improved text color to try')
    p.add_argument('--better-bg', default='blue', help='its background (black for none)')
    p.add_argument('--name-color', default='light-cyan', help='light-magenta: ready to train')


a = m.main_args(__doc__, extra)
KEY, VALUE, HEAD = m.WHITE, m.LIGHT_GREEN, m.LIGHT_MAGENTA
BETTER, BETTER_BG, WARN, BAD = m.color(a.better), m.color(a.better_bg), m.YELLOW, m.LIGHT_RED
s = m.screen(a)
s.frame()
s.title('TARVIN', m.color(a.name_color))


def kv(col, row, key, value, color=VALUE, vcol=None, better=False):
    """key in white and its value after it (from vcol); better draws the value as improved."""
    s.text(col, row, key, KEY)
    vcol = vcol if vcol is not None else col + len(key) + 1
    if better:
        s.text(vcol, row, value, BETTER, BETTER_BG)
    else:
        s.text(vcol, row, value, color)


s.text(2, 2, 'MALE ELF', VALUE)
kv(11, 2, 'AGE', '130')
s.text(2, 3, 'CHAOTIC GOOD', VALUE)
s.text(2, 4, 'FIGHTER/MAGIC-USER', VALUE)
# abilities and money, each under a header
s.text(2, 6, 'ABILITIES', HEAD)
s.text(20, 6, 'MONEY', HEAD)
for i, (name, val) in enumerate([('STR', '18(50)'), ('INT', '17'), ('WIS', '10'), ('DEX', '17'), ('CON', '15'),
                                 ('CHA', '13')]):
    kv(2, 7 + i, name, val, vcol=6, better=name == 'STR')
for i, (name, val) in enumerate([('GEMS', '4'), ('PLATINUM', '120'), ('GOLD', '2210'), ('SILVER', '35')]):
    s.right(29, 7 + i, name, KEY)
    s.right(37, 7 + i, val, VALUE)
kv(2, 14, 'LEVEL', '5/5')
kv(22, 14, 'EXP', '42000', vcol=26)
# combat
s.text(2, 16, 'COMBAT', HEAD)
kv(2, 17, 'AC', '2', vcol=5)
kv(2, 18, 'HP', '19', WARN, vcol=5)
kv(9, 17, 'THAC0', '15', vcol=16)
kv(9, 18, 'DAMAGE', '1D8+4', vcol=16)
kv(9, 19, 'ATT/RD', '3/2', vcol=16)
kv(22, 17, 'ENCUMBRANCE', '1150', vcol=34)
kv(22, 18, 'MOVEMENT', '24', vcol=34, better=True)
kv(2, 21, 'WEAPON', 'LONG SWORD +1', vcol=9)
kv(2, 22, 'STATUS', 'OKAY', vcol=9)
s.text(13, 22, ',', VALUE)
s.text(15, 22, 'POISONED', BAD)
s.menu('', ['Items', 'Spells', 'Trade', 'Drop', 'Exit'], current=-1)
s.save(a.out)
