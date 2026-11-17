{ Tests for ListView (docs/ui-design.md, Lists and Drawing): which entries it draws on which rows, and when; the keys,
  stopping at the ends; the bar on the section's edge. Load/Save's shape: a full-screen frame, entries of 3 rows from
  row 2, 7 shown, 11 slots. The entries are drawn by a spy that logs them; the bar and the clears through SpyVid. }
{$F+}
{$I COMPILER.INC}
program TListVw;

uses Types, C_KEYS, Border, ListView, SpyVid, TestKit;

type
  TDrawn = record
    entry: Integer;
    row: ShortInt;
    current: Boolean;
  end;

var
  log: array[1..40] of TDrawn;
  logged: Integer;
  f: Border.TFrame;
  l: ListView.TListView;
  k: Integer;
  ok: Boolean;
  r: ShortInt;

procedure SpyEntry(entry: Integer; row: ShortInt; current: Boolean);
begin
  Inc(logged);
  if logged <= 40 then begin
    log[logged].entry := entry;
    log[logged].row := row;
    log[logged].current := current;
  end;
end;

procedure Restart;
begin
  logged := 0;
  SpyVid.ResetDraws;
end;

{ True when entry n was drawn on row, with the cursor or not as current says. }
function WasDrawn(n: Integer; row: ShortInt; current: Boolean): Boolean;
var
  i: Integer;
  found: Boolean;
begin
  found := False;
  for i := 1 to logged do
    if (log[i].entry = n) and (log[i].row = row) and (log[i].current = current) then
      found := True;
  WasDrawn := found;
end;

{ A Load/Save list of count slots, the cursor on cur, drawn whole. }
procedure Open(count, cur: Integer);
begin
  SpyVid.ClearCells;
  Border.InitFrame(f, 0, 0, 39, 23, 0, 'Load/Save Game');
  Border.DrawFrame(f);
  ListView.InitList(l, f, 0, 2, 22, 3, count, cur, SpyEntry);
  Restart;
  ListView.DrawList(l);
end;

begin
  TestKit.Start('TLISTVW');
  SpyVid.Install;

  Open(11, 0);
  TestKit.CheckEqualsL(7, l.shown, '7 slots of 3 rows fit rows 2 to 22');
  TestKit.CheckEqualsL(7, logged, 'DrawList draws the 7 shown');
  TestKit.Check(WasDrawn(0, 2, True) and WasDrawn(1, 5, False) and WasDrawn(6, 20, False),
                'from row 2, 3 rows apart, the cursor''s marked');
  TestKit.Check((SpyVid.cells[1, 39].sym = SpyVid.BAR_UP) and (SpyVid.cells[2, 39].sym = SpyVid.KNOB_TOP),
                'and the bar on the right edge');

  { on the page: two entries }
  Restart;
  TestKit.Check(ListView.ListKey(l, C_KEYS.DOWN), 'Down is a list key');
  TestKit.CheckEqualsL(1, l.cur, 'Down moves the cursor a slot');
  TestKit.Check((logged = 2) and WasDrawn(0, 2, False) and WasDrawn(1, 5, True),
                'on the page: only the slot left and the slot taken');
  TestKit.CheckEqualsL(0, SpyVid.cells[2, 39].draws, 'and not the bar');

  { past the page: scroll a line, the entries in place }
  ListView.MoveTo(l, 6);
  Restart;
  ok := ListView.ListKey(l, C_KEYS.DOWN);
  TestKit.Check((l.cur = 7) and (l.top = 1), 'Down off the last row scrolls a slot');
  TestKit.Check((logged = 7) and WasDrawn(1, 2, False) and WasDrawn(7, 20, True), 'the 7 shown drawn in place');
  ok := True;
  for r := 2 to 22 do
    if SpyVid.cells[r, 20].clears <> 0 then
      ok := False;
  TestKit.Check(ok, 'nothing cleared to draw them');
  TestKit.Check(SpyVid.cells[1, 39].draws = 0, 'the arrow not redrawn');

  { the ends }
  ok := ListView.ListKey(l, C_KEYS.END_KEY);
  TestKit.Check((l.cur = 10) and (l.top = 4), 'End: the last slot, at the bottom');
  TestKit.CheckEqualsL(SpyVid.KNOB_BOTTOM, SpyVid.cells[21, 39].sym, 'the knob at the bottom of the track');
  Restart;
  TestKit.Check(ListView.ListKey(l, C_KEYS.DOWN), 'Down at the end is still a list key');
  TestKit.Check((l.cur = 10) and (logged = 0), 'but stops: nothing moves or is drawn');
  ok := ListView.ListKey(l, C_KEYS.HOME);
  TestKit.Check((l.cur = 0) and (l.top = 0), 'Home: the first slot');
  Restart;
  ok := ListView.ListKey(l, C_KEYS.UP);
  TestKit.Check((l.cur = 0) and (logged = 0), 'Up at the start stops');

  { pages }
  ok := ListView.ListKey(l, C_KEYS.PAGE_DOWN);
  TestKit.Check((l.cur = 7) and (l.top = 1), 'Page Down: 7 slots on');
  ok := ListView.ListKey(l, C_KEYS.PAGE_DOWN);
  TestKit.CheckEqualsL(10, l.cur, 'and stops at the last');
  ok := ListView.ListKey(l, C_KEYS.PAGE_UP);
  TestKit.Check((l.cur = 3) and (l.top = 3), 'Page Up: 7 back, the page following');
  TestKit.Check(not ListView.ListKey(l, 'A'), 'any other key is not the list''s');

  { opening on a slot off the first page shows it at the bottom }
  Open(11, 9);
  TestKit.Check((l.top = 3) and WasDrawn(9, 20, True), 'opened on slot 9: the page from slot 3, slot 9 last');

  { fewer slots than places: the rest cleared, no bar }
  Open(4, 0);
  TestKit.CheckEqualsL(4, logged, '4 slots: 4 drawn');
  TestKit.Check((SpyVid.cells[14, 20].clears = 1) and (SpyVid.cells[22, 20].clears = 1),
                'the places past them cleared');
  TestKit.CheckEqualsL(SpyVid.SIDE, SpyVid.cells[10, 39].sym, 'no bar: the edge plain');
  ok := ListView.ListKey(l, C_KEYS.PAGE_DOWN);
  TestKit.CheckEqualsL(3, l.cur, 'Page Down on a short list: its last slot');

  { an empty list }
  Open(0, 0);
  Restart;
  for k := 1 to 3 do
    ok := ListView.ListKey(l, C_KEYS.DOWN);
  TestKit.Check((logged = 0) and (l.cur = 0), 'an empty list draws no entry and does not move');
  TestKit.Done;
end.
