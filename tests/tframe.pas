{ Tests for Border's frames (docs/ui-design.md, The screen): what DrawFrame and FrameBar draw, cell by cell, through a
  spy video driver. Symbol set 4 and the scroll bar's set 5 are made up, each frame's first byte naming its symbol, so
  the spy's ShowPic can tell which symbol each cell got; its DrawGlyph records the game-font glyphs. Each cell's draws
  are counted, for "each edge once" and "only the cells that changed". }
{$F+}
{$I COMPILER.INC}
program TFrame;

uses {$IFNDEF FPC}Crt, {$ENDIF}Types, GameVars, Blit, VidVga, Sym8x8, Border, UiColor, TestKit;

const
  CORNER = 276;
  SIDE = 277;
  EDGE = 278;
  BAR_UP = 287;
  BAR_DOWN = 288;
  BAR_TRACK = 289;
  KNOB_TOP = 290;
  KNOB_MID = 291;
  KNOB_BOTTOM = 292;
  GRIP = 294;
  { colours, as Crt has them (natively the test does not use Crt) }
  WHITE_ = 15;
  DARK_GRAY_ = 8;

type
  TCell = record
    { the symbol last drawn there, 0 for none }
    sym: Word;
    { the game-font glyph last drawn there and its colour, 255 for none }
    glyph: Byte;
    fg: Byte;
    draws: Byte;
  end;

var
  cells: array[0..24, 0..39] of TCell;
  f: Border.TFrame;
  barSet: Types.PImgBuf;
  r: ShortInt;
  c: ShortInt;
  ok: Boolean;
  a: ShortInt;
  b: ShortInt;

procedure SpyShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  m: Byte;
begin
  m := pic^.data[0];
  with cells[screenY, screenX] do begin
    if m >= 100 then
      sym := Sym8x8.BAR_FIRST + m - 100
    else
      sym := 256 + m;
    glyph := 255;
    Inc(draws);
  end;
end;

procedure SpyDrawGlyph(col, row, fg, bg, glyph: Byte);
begin
  cells[row, col].sym := 0;
  cells[row, col].glyph := glyph;
  cells[row, col].fg := fg;
  Inc(cells[row, col].draws);
end;

procedure ClearCells;
begin
  FillChar(cells, SizeOf(cells), 0);
  for r := 0 to 24 do
    for c := 0 to 39 do
      cells[r, c].glyph := 255;
end;

procedure ResetDraws;
begin
  for r := 0 to 24 do
    for c := 0 to 39 do
      cells[r, c].draws := 0;
end;

{ A made-up symbol set of count 8x8 frames, frame k's first byte being base + k. }
function MakeSet(count, base: Byte): Types.PImgBuf;
var
  pic: Types.PImgBuf;
  k: Byte;
begin
  Blit.AllocPic(8, 1, count, 0, pic);
  for k := 0 to count - 1 do
    pic^.data[k * pic^.imgSize] := base + k;
  MakeSet := pic;
end;

{ The game font's glyph for character ch, as TextRend.RenderChar picks it. }
function GlyphOf(ch: Char): Byte;
begin
  GlyphOf := Ord(UpCase(ch)) mod 64;
end;

{ What the frame f's border should have at (col, row): a corner box at its corners and joints, the edge along its top,
  bottom and dividers, the side down its sides, and 0 off the border. }
function Expected(col, row: ShortInt): Word;
var
  d: Byte;
  across: Boolean;
begin
  across := (row = f.top) or (row = f.bottom);
  for d := 1 to f.dividers do
    if row = f.divRow[d] then
      across := True;
  if (col < f.left) or (col > f.right) or (row < f.top) or (row > f.bottom) then
    Expected := 0
  else if across and ((col = f.left) or (col = f.right)) then
    Expected := CORNER
  else if across then
    Expected := EDGE
  else if (col = f.left) or (col = f.right) then
    Expected := SIDE
  else
    Expected := 0;
end;

begin
  TestKit.Start('TFRAME');
  VidVga.Install;
  GameVars.video.ShowPic := SpyShowPic;
  GameVars.video.DrawGlyph := SpyDrawGlyph;
  New(GameVars.gameFont);
  GameVars.symbolSetPtrs[4] := MakeSet(31, 0);
  barSet := MakeSet(8, 100);
  GameVars.symbolSetPtrs[5] := barSet;
  Blit.AllocPic(8, 1, 1, 0, GameVars.sym8x8Buf);

  { the pure parts }
  TestKit.CheckEqualsL(11, Border.TitleStart(0, 39, 14), 'LOAD/SAVE GAME''s left corner box in column 11');
  Border.InitFrame(f, 0, 0, 39, 23, 0, '');
  Border.AddDivider(f, 2);
  Border.AddDivider(f, 16);
  Border.AddDivider(f, 10);
  Border.AddDivider(f, 23);
  TestKit.CheckEqualsL(2, f.dividers, 'a divider above the last, or on the bottom edge, is ignored');
  Border.SectionRows(f, 0, a, b);
  TestKit.Check((a = 1) and (b = 1), 'the shop''s section 0: the tab row');
  Border.SectionRows(f, 1, a, b);
  TestKit.Check((a = 3) and (b = 15), 'section 1: the list, rows 3 to 15');
  Border.SectionRows(f, 2, a, b);
  TestKit.Check((a = 17) and (b = 22), 'section 2: the panel, rows 17 to 22');
  Border.SectionRows(f, 3, a, b);
  TestKit.Check(a > b, 'no section 3');

  { the shop's frame: every border cell drawn once, with the right symbol, and nothing inside }
  ClearCells;
  Border.DrawFrame(f);
  ok := True;
  for r := 0 to 24 do
    for c := 0 to 39 do
      if (cells[r, c].sym <> Expected(c, r)) or (cells[r, c].draws <> Ord(Expected(c, r) <> 0)) then
        ok := False;
  TestKit.Check(ok, 'the shop''s frame: corners and joints, edges, sides, each drawn once, nothing inside');

  { its list's scroll bar: 20 items, 13 shown from the first, over column 39 between the joints on rows 2 and 16 }
  ResetDraws;
  Border.FrameBar(f, 1, 20, 13, 0);
  TestKit.Check((cells[3, 39].sym = BAR_UP) and (cells[15, 39].sym = BAR_DOWN), 'the arrows on rows 3 and 15');
  TestKit.Check((cells[4, 39].sym = KNOB_TOP) and (cells[5, 39].sym = KNOB_MID) and (cells[7, 39].sym = GRIP) and
                (cells[10, 39].sym = KNOB_BOTTOM), 'a knob of 7 rows from row 4, the grip on its middle cell');
  TestKit.Check((cells[11, 39].sym = BAR_TRACK) and (cells[14, 39].sym = BAR_TRACK), 'the track under it');
  TestKit.Check((cells[2, 39].sym = CORNER) and (cells[16, 39].sym = CORNER) and (cells[1, 39].sym = SIDE) and
                (cells[17, 39].sym = SIDE), 'the joints, the tabs'' and the panel''s edges as they were');
  ok := True;
  for r := 0 to 24 do
    for c := 0 to 38 do
      if cells[r, c].draws <> 0 then
        ok := False;
  TestKit.Check(ok, 'nothing drawn off the bar''s column');

  { a line down: only the cells whose piece changed }
  ResetDraws;
  Border.FrameBar(f, 1, 20, 13, 1);
  TestKit.Check((cells[3, 39].draws = 0) and (cells[15, 39].draws = 0), 'a line down: the arrows are not redrawn');
  TestKit.Check((cells[4, 39].sym = BAR_TRACK) and (cells[5, 39].sym = KNOB_TOP) and (cells[8, 39].sym = GRIP) and
                (cells[11, 39].sym = KNOB_BOTTOM), 'the knob a row down');
  TestKit.Check((cells[6, 39].draws = 0) and (cells[9, 39].draws = 0) and (cells[12, 39].draws = 0),
                'a middle cell still a middle cell, and the track still track, are not redrawn');
  TestKit.Check((cells[4, 39].draws = 1) and (cells[7, 39].draws = 1) and (cells[11, 39].draws = 1),
                'the cells that changed are, once');
  ResetDraws;
  Border.FrameBar(f, 1, 20, 13, 1);
  ok := True;
  for r := 0 to 24 do
    if cells[r, 39].draws <> 0 then
      ok := False;
  TestKit.Check(ok, 'the same place again: nothing drawn');

  { the list comes to fit: the plain edge back }
  Border.FrameBar(f, 1, 10, 13, 0);
  ok := True;
  for r := 3 to 15 do
    if cells[r, 39].sym <> SIDE then
      ok := False;
  TestKit.Check(ok, 'a list that fits: the side back on rows 3 to 15');
  ResetDraws;
  Border.FrameBar(f, 1, 10, 13, 0);
  TestKit.CheckEqualsL(0, cells[3, 39].draws, 'and drawn once, not again');

  { a frame drawn again forgets its bars: the next bar is drawn whole }
  Border.FrameBar(f, 1, 20, 13, 0);
  Border.DrawFrame(f);
  ResetDraws;
  Border.FrameBar(f, 1, 20, 13, 0);
  TestKit.Check((cells[3, 39].draws = 1) and (cells[6, 39].draws = 1) and (cells[14, 39].draws = 1),
                'after DrawFrame the bar is drawn whole');

  { a title in the top edge: Load/Save's }
  ClearCells;
  Border.InitFrame(f, 0, 0, 39, 23, 0, 'Load/Save Game');
  titleColor := 14;
  Border.DrawFrame(f);
  TestKit.Check((cells[0, 11].sym = CORNER) and (cells[0, 28].sym = CORNER), 'corner boxes in columns 11 and 28');
  TestKit.Check((cells[0, 12].glyph = GlyphOf(' ')) and (cells[0, 13].glyph = GlyphOf('L')) and
                (cells[0, 26].glyph = GlyphOf('E')) and (cells[0, 27].glyph = GlyphOf(' ')),
                'a space, the title, a space between them');
  TestKit.CheckEqualsL(14, cells[0, 13].fg, 'in titleColor');
  TestKit.Check((cells[0, 10].sym = EDGE) and (cells[0, 29].sym = EDGE) and (cells[0, 0].sym = CORNER),
                'the edge either side');
  ok := True;
  for c := 0 to 39 do
    if cells[0, c].draws <> 1 then
      ok := False;
  TestKit.Check(ok, 'every top-edge cell drawn once');
  UiColor.SetDefaults;

  { Load/Save's bar, between the corners: 7 of 11 slots on rows 1 to 22 }
  Border.FrameBar(f, 0, 11, 7, 0);
  TestKit.Check((cells[1, 39].sym = BAR_UP) and (cells[22, 39].sym = BAR_DOWN) and (cells[2, 39].sym = KNOB_TOP) and
                (cells[14, 39].sym = KNOB_BOTTOM) and (cells[15, 39].sym = BAR_TRACK),
                'Load/Save: arrows on rows 1 and 22, a knob of 13 rows from row 2');

  { a long title is cut to leave an edge cell beyond each of its corner boxes }
  ClearCells;
  Border.InitFrame(f, 0, 0, 19, 5, 0, 'A TITLE FAR TOO LONG');
  Border.DrawFrame(f);
  TestKit.Check((cells[0, 1].sym = EDGE) and (cells[0, 2].sym = CORNER) and (cells[0, 17].sym = CORNER) and
                (cells[0, 18].sym = EDGE), 'a long title is cut short, an edge cell each side');

  { without the scroll bar's cells, a bar in text }
  ClearCells;
  GameVars.symbolSetPtrs[5] := nil;
  Border.InitFrame(f, 0, 0, 39, 23, 0, '');
  Border.FrameBar(f, 0, 11, 7, 0);
  TestKit.Check((cells[1, 39].glyph = GlyphOf('^')) and (cells[22, 39].glyph = GlyphOf('V')) and
                (cells[2, 39].glyph = GlyphOf('*')) and (cells[20, 39].glyph = GlyphOf('-')),
                'no cells: ^, V, * and - in the edge');
  TestKit.Check((cells[2, 39].fg = WHITE_) and (cells[20, 39].fg = DARK_GRAY_), 'the knob white, the track dark gray');
  GameVars.symbolSetPtrs[5] := barSet;

  { the pieces of a knob }
  TestKit.Check((Border.BarPiece(2, 1, 2) = 6) and (Border.BarPiece(2, 2, 2) = 3) and (Border.BarPiece(2, 2, 3) = 5),
                'one cell: the one-cell knob; two: top and bottom, no grip');
  TestKit.Check((Border.BarPiece(0, 4, 2) = 7) and (Border.BarPiece(0, 4, 1) = 4) and (Border.BarPiece(0, 4, 4) = 2),
                'four: the grip on the lower middle cell; past it, the track');
  TestKit.Done;
end.
