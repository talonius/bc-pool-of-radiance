{ Implements the Command Keys window opened with F1 from the map and camp
  menus (#855), and the help pages F1 opens on the shop's Buy screen and the
  Items screen (ShowPage). Key descriptions live in tables here so new commands
  only need to be added in one place. }
{$O+,F+}
{$I COMPILER.INC}
unit KeyHelp;

interface

uses Types;

const
  { Conditions that control whether a help line is visible. }
  SHOW_ALWAYS = 0;
  SHOW_QUICK = 1;
  SHOW_COMPANION = 2;
  SHOW_STING = 3;
  SHOW_SOUND = 4;
  SHOW_LOG = 5;
  SHOW_TRAIN = 6;
  { Number of entries in KEYS. }
  KEY_LINES = 12;
  { Number of entries in SHOP_KEYS and ITEM_KEYS. }
  SHOP_LINES = 15;
  ITEM_LINES = 14;

type
  { One row in the help window. A ShowPage row with neither key nor what is a blank row; one with what only goes on
    from the row above. }
  TKeyLine = record
    key: string[9];
    what: string[28];
    show: Byte;
  end;
  { A table of lines for ShowPage, of any length up to this }
  TKeyLines = array[1..KEY_LINES] of TKeyLine;
  PKeyLines = ^TKeyLines;

const
  { The lines, in the window's order. }
  KEYS: array[1..KEY_LINES] of TKeyLine = (
    (key: 'F1  '; what: 'This Screen'; show: SHOW_ALWAYS),
    (key: 'F2  '; what: 'Bestiary'; show: SHOW_ALWAYS),
    (key: 'F3  '; what: 'Minimap (Combat Only)'; show: SHOW_ALWAYS),
    (key: 'F4  '; what: 'Train Anywhere'; show: SHOW_TRAIN),
    (key: 'F5  '; what: 'Quick Save'; show: SHOW_QUICK),
    (key: 'F6  '; what: 'Companion Tools'; show: SHOW_COMPANION),
    (key: 'F7  '; what: 'Action Log (Combat Only)'; show: SHOW_LOG),
    (key: 'F8  '; what: 'Quick Load'; show: SHOW_QUICK),
    (key: '1, 2   '; what: 'Ready Set (Combat Only)'; show: SHOW_ALWAYS),
    (key: 'ALT-n  '; what: 'View PC n''s items (1 to 8)'; show: SHOW_ALWAYS),
    (key: 'CTRL-S '; what: 'Sound On/Off'; show: SHOW_SOUND),
    (key: 'CTRL-Y '; what: 'Memory Stats'; show: SHOW_STING));

  { The shop's Buy screen (ShopBuy.BuyScreen) }
  SHOP_KEYS: array[1..SHOP_LINES] of TKeyLine = (
    (key: 'F1       '; what: 'This Screen'; show: SHOW_ALWAYS),
    (key: 'UP, DN   '; what: 'Move a line'; show: SHOW_ALWAYS),
    (key: 'PGUP/DN  '; what: 'Move a page'; show: SHOW_ALWAYS),
    (key: 'B, ENTER '; what: 'Buy the highlighted item'; show: SHOW_ALWAYS),
    (key: 'S        '; what: 'Showing All / Usable'; show: SHOW_ALWAYS),
    (key: ''; what: ''; show: SHOW_ALWAYS),
    (key: 'L        '; what: 'All tab'; show: SHOW_ALWAYS),
    (key: 'M        '; what: 'Melee tab'; show: SHOW_ALWAYS),
    (key: 'R        '; what: 'Ranged tab'; show: SHOW_ALWAYS),
    (key: 'A        '; what: 'Armor tab'; show: SHOW_ALWAYS),
    (key: 'O        '; what: 'Ammo tab'; show: SHOW_ALWAYS),
    (key: 'I        '; what: 'Misc tab'; show: SHOW_ALWAYS),
    (key: ''; what: ''; show: SHOW_ALWAYS),
    (key: 'ALT-n    '; what: 'Switch to PC n (1 to 8)'; show: SHOW_ALWAYS),
    (key: 'E, ESC   '; what: 'Exit'; show: SHOW_ALWAYS));

  { The Items screen (ViewChar.UseItemMenu) }
  ITEM_KEYS: array[1..ITEM_LINES] of TKeyLine = (
    (key: 'F1       '; what: 'This Screen'; show: SHOW_ALWAYS),
    (key: 'UP, DN   '; what: 'Move a line'; show: SHOW_ALWAYS),
    (key: 'PGUP/DN  '; what: 'Next / Prev page'; show: SHOW_ALWAYS),
    (key: 'R        '; what: 'Ready / Unready'; show: SHOW_ALWAYS),
    (key: 'U        '; what: 'Use'; show: SHOW_ALWAYS),
    (key: 'T        '; what: 'Trade'; show: SHOW_ALWAYS),
    (key: 'D        '; what: 'Drop / Deposit'; show: SHOW_ALWAYS),
    (key: 'H, J     '; what: 'Halve, Join a stack'; show: SHOW_ALWAYS),
    (key: 'S, I     '; what: 'Sell, Id (at a shop)'; show: SHOW_ALWAYS),
    (key: ''; what: ''; show: SHOW_ALWAYS),
    (key: '1, 2     '; what: 'Set / Unset weapon set'; show: SHOW_ALWAYS),
    (key: ''; what: ''; show: SHOW_ALWAYS),
    (key: 'ALT-n    '; what: 'Switch to PC n (1 to 8)'; show: SHOW_ALWAYS),
    (key: 'E, ESC   '; what: 'Exit'; show: SHOW_ALWAYS));

{ Returns whether help line n applies to the current settings and menu. }
function LineShown(n: Byte; quickKeys: Boolean): Boolean;

{ Whether the window has room for a blank row between its groups of lines (the function keys, the Alt keys and the Ctrl
  keys) with the lines shown for quickKeys; when it has not, as with every line shown under STING, the groups follow
  each other without one. }
function GroupGaps(quickKeys: Boolean): Boolean;

{ Line n's group in the window: A for an Alt key, C for a Ctrl key, F for a function key or a plain one (the weapon
  sets' 1 and 2, #1209, which take no group of their own, to spare a blank row). }
function KeyGroup(n: Byte): Char;

{ Shows the full-screen Command Keys window until Exit or Escape. quickKeys is
  True when the calling menu supports F5/F8 quick save and load. The caller is
  responsible for redrawing its screen afterward. }
procedure ShowKeys(quickKeys: Boolean);

{ Shows a full-screen help window, one box with no title, holding the count lines of lines in order (see TKeyLine),
  until Exit or Escape. The caller redraws its screen afterward. }
procedure ShowPage(lines: PKeyLines; count: Byte);

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, C_KEYS, C_SOUND, GameVars, TextRend, Border, MenuCore;

const
  { The window's frame and rows, as the Quests page's (#855): the title box on TITLE_ROW, the lines' box from LIST_TOP
    to BOTTOM_ROW, and the lines from a blank row into it. Keys start at KEY_COL. BOTTOM_ROW is a row below the Quests
    page's, the row above the menu line, so that LIST_ROWS is 19; every line fits with the groups' blank rows now that
    Alt-1 to Alt-8 share a line, and GroupGaps drops those rows should the lines outgrow it (#1209, #1212). }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  TITLE_ROW = 1;
  LIST_TOP = 3;
  BOTTOM_ROW = 23;
  FIRST_ROW = LIST_TOP + 1;
  { the rows the lines have, from FIRST_ROW to the row above the box's bottom edge }
  LIST_ROWS = BOTTOM_ROW - FIRST_ROW;
  KEY_COL = 2;
  TITLE_COLOR = White;
  KEY_COLOR = White;
  LINE_COLOR = LightGreen;
  { ShowPage's box: rows PAGE_TOP to PAGE_BOTTOM, its edges on the rows around them, above the menu line; the lines
    from a blank row into it, PAGE_ROWS of them at most, with a blank row under the last }
  PAGE_TOP = 1;
  PAGE_BOTTOM = 22;
  PAGE_FIRST = PAGE_TOP + 1;
  PAGE_ROWS = PAGE_BOTTOM - PAGE_FIRST;
  { the columns a ShowPage table's keys take, blanks after them included }
  PAGE_KEY_WIDTH = 9;

function LineShown(n: Byte; quickKeys: Boolean): Boolean;
begin
  case KEYS[n].show of
    SHOW_QUICK: LineShown := quickKeys;
    SHOW_COMPANION: LineShown := GameVars.companionOn <> 0;
    SHOW_STING: LineShown := GameVars.stingArg;
    SHOW_SOUND: LineShown := GameVars.sound.mode <> C_SOUND.MODE_DISABLED;
    SHOW_LOG: LineShown := GameVars.combatLogOn <> 0;
    SHOW_TRAIN: LineShown := GameVars.trainAnywhereOn <> 0;
  else
    LineShown := True;
  end;
end;

{ Line n's group in the window: A for an Alt key, C for a Ctrl key, F for a function key or a plain one (the weapon
  sets' 1 and 2, #1209, which take no group of their own, to spare a blank row). }
function KeyGroup(n: Byte): Char;
begin
  if KEYS[n].key[1] in ['A', 'C'] then
    KeyGroup := KEYS[n].key[1]
  else
    KeyGroup := 'F';
end;

function GroupGaps(quickKeys: Boolean): Boolean;
var
  n: Byte;
  rows: Byte;
  group: Char;
begin
  rows := 0;
  group := ' ';
  for n := 1 to KEY_LINES do
    if KeyHelp.LineShown(n, quickKeys) then begin
      if (group <> ' ') and (KeyHelp.KeyGroup(n) <> group) then
        Inc(rows);
      group := KeyHelp.KeyGroup(n);
      Inc(rows);
    end;
  GroupGaps := rows <= LIST_ROWS;
end;

{ The Command Keys window's frame with title centred in its title box. }
procedure DrawFrame(title: Types.TStr40);
begin
  { the whole screen, as a window over the map's would run into its frames; the lines' box first, then the title's, so
    the corners stay where the borders meet }
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, LIST_TOP, RIGHT_COL, BOTTOM_ROW, 0);
  Border.DrawBorder(LEFT_COL, TITLE_ROW, RIGHT_COL, TITLE_ROW, 0);
  TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TITLE_ROW, TITLE_COLOR, title);
end;

{ Line kl at row: its key in KEY_COLOR, then what in LINE_COLOR. }
procedure DrawLine(var kl: TKeyLine; row: Byte);
begin
  TextRend.DisplayString(KEY_COL, row, KEY_COLOR, kl.key);
  TextRend.DisplayString(KEY_COL + Length(kl.key), row, LINE_COLOR, kl.what);
end;

{ Wait on the window's Exit, then clear the bottom line and put back the caller's menu choice, savedChoice. }
procedure WaitExit(savedChoice: Byte);
var
  ch: Char;
  ext: Boolean;
begin
  repeat
    { F1 here is this window already }
    MenuCore.helpToCaller := True;
    ch := MenuCore.MenuHorizontal('Help: ', 'Exit', LightMagenta, LightGreen, White, False, False, ext);
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  TextRend.ClearBottomLine;
  GameVars.horizChoice := savedChoice;
end;

procedure ShowKeys(quickKeys: Boolean);
var
  n: Byte;
  row: Byte;
  { the group of the last line shown (KeyGroup) }
  group: Char;
  savedChoice: Byte;
  gaps: Boolean;
begin
  savedChoice := GameVars.horizChoice;
  gaps := KeyHelp.GroupGaps(quickKeys);
  KeyHelp.DrawFrame('Command Keys');
  row := FIRST_ROW;
  group := ' ';
  for n := 1 to KEY_LINES do
    if KeyHelp.LineShown(n, quickKeys) then begin
      { a blank row between groups, when they fit with it: the function keys, the Alt keys (#1175) and the Ctrl keys }
      if gaps and (group <> ' ') and (KeyHelp.KeyGroup(n) <> group) then
        Inc(row);
      group := KeyHelp.KeyGroup(n);
      KeyHelp.DrawLine(KEYS[n], row);
      Inc(row);
    end;
  KeyHelp.WaitExit(savedChoice);
end;

procedure ShowPage(lines: PKeyLines; count: Byte);
var
  n: Byte;
  savedChoice: Byte;
begin
  savedChoice := GameVars.horizChoice;
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, PAGE_TOP, RIGHT_COL, PAGE_BOTTOM, 0);
  { the rows the box has; a longer table is cut }
  if count > PAGE_ROWS then
    count := PAGE_ROWS;
  for n := 1 to count do
    if lines^[n].key = '' then
      { a continued line lines up with the text above it }
      TextRend.DisplayString(KEY_COL + PAGE_KEY_WIDTH, PAGE_FIRST + n - 1, LINE_COLOR, lines^[n].what)
    else
      KeyHelp.DrawLine(lines^[n], PAGE_FIRST + n - 1);
  KeyHelp.WaitExit(savedChoice);
end;

end.
