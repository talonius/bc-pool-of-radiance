{ A spy video driver for tests of what a screen draws (TFrame, TListVw): the VGA driver's layout, with ShowPic,
  DrawGlyph and ClearRect recording into cells instead of drawing. Symbol set 4 and the scroll bar's set 5 are made up,
  each frame's first byte naming its symbol, so ShowPic can tell which symbol a cell got. Each cell's draws are counted,
  for "each edge once" and "only the cells that changed". }
{$F+}
{$I COMPILER.INC}
unit SpyVid;

interface

uses Types;

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
  KNOB_ONE = 293;
  GRIP = 294;
  { no glyph drawn in a cell }
  NO_GLYPH = 255;

type
  TCell = record
    { the symbol last drawn there, 0 for none }
    sym: Word;
    { the game-font glyph last drawn there and its colours, NO_GLYPH for none }
    glyph: Byte;
    fg: Byte;
    bg: Byte;
    { draws of any kind since ResetDraws, and clears }
    draws: Byte;
    clears: Byte;
  end;

var
  cells: array[0..24, 0..39] of TCell;
  { the made-up scroll bar set, to put back after a test takes it away }
  barSet: Types.PImgBuf;

{ Install the spy: the VGA driver's layout, the spying procedures, a font, the made-up symbol sets and an empty screen. }
procedure Install;

{ An empty screen: no symbols, no glyphs, no draws. }
procedure ClearCells;

{ The draw and clear counts back to 0, the screen kept. }
procedure ResetDraws;

{ The game font's glyph for character ch, as TextRend.RenderChar picks it. }
function GlyphOf(ch: Char): Byte;

{ The text of row's glyphs from column first to last, as characters (the game font's glyph g is character g + 64 below
  32, else g); a cell with no glyph reads as '.'. }
function RowText(row, first, last: ShortInt): String;

implementation

uses GameVars, Blit, VidVga;

procedure SpyShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  m: Byte;
begin
  m := pic^.data[0];
  with cells[screenY, screenX] do begin
    if m >= 100 then
      sym := 287 + m - 100
    else
      sym := 256 + m;
    glyph := NO_GLYPH;
    Inc(draws);
  end;
end;

procedure SpyDrawGlyph(col, row, fg, bg, glyph: Byte);
begin
  cells[row, col].sym := 0;
  cells[row, col].glyph := glyph;
  cells[row, col].fg := fg;
  cells[row, col].bg := bg;
  Inc(cells[row, col].draws);
end;

procedure SpyClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  r: Byte;
  c: Byte;
begin
  for r := ulRow to lrRow do
    for c := ulCol to lrCol do begin
      cells[r, c].sym := 0;
      cells[r, c].glyph := NO_GLYPH;
      Inc(cells[r, c].clears);
    end;
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

procedure ClearCells;
var
  r: ShortInt;
  c: ShortInt;
begin
  FillChar(cells, SizeOf(cells), 0);
  for r := 0 to 24 do
    for c := 0 to 39 do
      cells[r, c].glyph := NO_GLYPH;
end;

procedure ResetDraws;
var
  r: ShortInt;
  c: ShortInt;
begin
  for r := 0 to 24 do
    for c := 0 to 39 do begin
      cells[r, c].draws := 0;
      cells[r, c].clears := 0;
    end;
end;

procedure Install;
begin
  VidVga.Install;
  GameVars.video.ShowPic := SpyShowPic;
  GameVars.video.DrawGlyph := SpyDrawGlyph;
  GameVars.video.ClearRect := SpyClearRect;
  New(GameVars.gameFont);
  GameVars.symbolSetPtrs[4] := MakeSet(31, 0);
  barSet := MakeSet(8, 100);
  GameVars.symbolSetPtrs[5] := barSet;
  Blit.AllocPic(8, 1, 1, 0, GameVars.sym8x8Buf);
  SpyVid.ClearCells;
end;

function GlyphOf(ch: Char): Byte;
begin
  GlyphOf := Ord(UpCase(ch)) mod 64;
end;

function RowText(row, first, last: ShortInt): String;
var
  s: String;
  c: ShortInt;
  g: Byte;
begin
  s := '';
  for c := first to last do begin
    g := cells[row, c].glyph;
    if g = NO_GLYPH then
      s := s + '.'
    else if g < 32 then
      s := s + Chr(g + 64)
    else
      s := s + Chr(g);
  end;
  RowText := s;
end;

end.
