{ A list in a frame's section (docs/ui-design.md, Lists and Drawing): it scrolls a line at a time and stops at its ends,
  shows the scroll bar on the section's edge while it is longer than the section (Border.FrameBar), and draws only what
  changed. The screen draws each entry, through its draw routine; the list says which entry goes on which row and when.
  The keys come from the screen's own key loop (ListKey). }
{$O+,F+}
{$I COMPILER.INC}
unit ListView;

interface

uses Types, Border;

type
  { Draw entry number entry (from 0) of the list, its first row being row, as the cursor's entry when current is set. It must
    draw every cell of the entry that may differ from another entry's, padding its text out to the entry's width, since
    entries are drawn in place over others without clearing. }
  TDrawEntry = procedure(entry: Integer; row: ShortInt; current: Boolean);
  TListView = record
    { the frame and its section the list is in: the bar goes on the section's right edge }
    frame: Border.PFrame;
    section: Byte;
    { the first entry's first row; rows each entry takes; entries that fit }
    firstRow: ShortInt;
    entryRows: Byte;
    shown: Integer;
    { the entries; the first shown; the cursor's }
    count: Integer;
    top: Integer;
    cur: Integer;
    draw: TDrawEntry;
  end;

{ A list in section of frame f, its entries from firstRow down to lastRow, entryRows rows each, count of them, the cursor
  on cur (held to the list) and the page scrolled to show it; draw draws an entry. Nothing is drawn. }
procedure InitList(var l: TListView; var f: Border.TFrame; section: Byte; firstRow, lastRow: ShortInt;
                   entryRows: Byte; count, cur: Integer; draw: TDrawEntry);

{ Draw the list whole: every entry shown, the rows of places past the last entry cleared, and the scroll bar (or the
  plain edge). After the frame is drawn, and when the screen comes back. }
procedure DrawList(var l: TListView);

{ Put the cursor on entry n, held to the list, scrolling the fewest lines that show it. On the page: the entry left and
  the entry taken are redrawn. Scrolled: the entries shown are redrawn in place, and the bar's cells that changed. }
procedure MoveTo(var l: TListView; n: Integer);

{ Move the cursor for an extended key: Up and Down a line, Page Up and Page Down a page, Home and End to the first and
  last entry, stopping at the ends. True when key is one of them, moved or not, so the screen takes no other action. }
function ListKey(var l: TListView; key: Char): Boolean;

implementation

uses C_KEYS;

{ Draw the entries shown, and the places past the last entry blank. }
procedure DrawShown(var l: TListView);
var
  k: Integer;
  i: Integer;
  row: ShortInt;
begin
  for k := 0 to l.shown - 1 do begin
    i := l.top + k;
    row := l.firstRow + k * l.entryRows;
    if i < l.count then
      l.draw(i, row, i = l.cur)
    else
      Border.ClearBox(l.frame^.left + 1, row, l.frame^.right - 1, row + l.entryRows - 1);
  end;
end;

procedure InitList(var l: TListView; var f: Border.TFrame; section: Byte; firstRow, lastRow: ShortInt;
                   entryRows: Byte; count, cur: Integer; draw: TDrawEntry);
begin
  l.frame := @f;
  l.section := section;
  l.firstRow := firstRow;
  if entryRows < 1 then
    entryRows := 1;
  l.entryRows := entryRows;
  l.shown := (lastRow - firstRow + 1) div entryRows;
  if l.shown < 1 then
    l.shown := 1;
  l.count := count;
  if cur > count - 1 then
    cur := count - 1;
  if cur < 0 then
    cur := 0;
  l.cur := cur;
  l.top := 0;
  if l.cur > l.shown - 1 then
    l.top := l.cur - l.shown + 1;
  l.draw := draw;
end;

procedure DrawList(var l: TListView);
begin
  DrawShown(l);
  Border.FrameBar(l.frame^, l.section, l.count, l.shown, l.top);
end;

procedure MoveTo(var l: TListView; n: Integer);
var
  old: Integer;
  oldTop: Integer;
begin
  if l.count = 0 then
    Exit;
  if n > l.count - 1 then
    n := l.count - 1;
  if n < 0 then
    n := 0;
  if n = l.cur then
    Exit;
  old := l.cur;
  oldTop := l.top;
  l.cur := n;
  if l.cur < l.top then
    l.top := l.cur
  else if l.cur > l.top + l.shown - 1 then
    l.top := l.cur - l.shown + 1;
  if l.top = oldTop then begin
    l.draw(old, l.firstRow + (old - l.top) * l.entryRows, False);
    l.draw(l.cur, l.firstRow + (l.cur - l.top) * l.entryRows, True);
  end else begin
    DrawShown(l);
    Border.FrameBar(l.frame^, l.section, l.count, l.shown, l.top);
  end;
end;

function ListKey(var l: TListView; key: Char): Boolean;
begin
  ListKey := True;
  case key of
    C_KEYS.UP: ListView.MoveTo(l, l.cur - 1);
    C_KEYS.DOWN: ListView.MoveTo(l, l.cur + 1);
    C_KEYS.PAGE_UP: ListView.MoveTo(l, l.cur - l.shown);
    C_KEYS.PAGE_DOWN: ListView.MoveTo(l, l.cur + l.shown);
    C_KEYS.HOME: ListView.MoveTo(l, 0);
    C_KEYS.END_KEY: ListView.MoveTo(l, l.count - 1);
  else
    ListKey := False;
  end;
end;

end.
