{ Tests for BarArt: the scroll bar block the Data Builder adds to the 8X8D archive (docs/screen-mocks/scrollbar.txt).
  Block 202 here is made up: a header and 31 frames, the corner box (frame 20) a known pattern of yellow, brown and
  white. }
{$I COMPILER.INC}
program TBarArt;

uses Crt, BarArt, TestKit;

const
  SYM_FRAMES = 31;
  SYM_BYTES = BarArt.HEADER_BYTES + SYM_FRAMES * BarArt.CELL_BYTES;

type
  TPicture = array[0..7] of string[8];

const
  UP_ARROW: TPicture = ('--------', '---*----', '--***---', '-*****--', '--***..-', '--***.--', '---...--', '--------');
  DOWN_ARROW: TPicture = ('--------', '--***---', '--***.--', '--***.--', '-*****--', '--***..-', '---*..--',
                          '----.---');
  KNOB_ONE: TPicture = ('WWWWWWWd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd',
                        'dddddddd');
  { the made-up corner box: Y yellow, B brown, W white }
  CORNER: TPicture = ('YYYYYYYB', 'YWWWWWBB', 'YWYYYYBB', 'YWYWBYBB', 'YWYBBYBB', 'YWYYYYBB', 'YBBBBBBB', 'BBBBBBBB');
  { what the grip should be: the corner box's yellow light gray and brown dark gray, column 0 white and 7 dark gray }
  GRIP: TPicture = ('Wggggggd', 'WWWWWWdd', 'WWggggdd', 'WWgWdgdd', 'WWgddgdd', 'WWggggdd', 'Wddddddd', 'Wddddddd');

var
  sym: array[0..SYM_BYTES - 1] of Byte;
  block: BarArt.TBarBlock;
  i: Word;
  ok: Boolean;

function ColorOf(ch: Char): Byte;
begin
  case ch of
    '*', 'W': ColorOf := White;
    '-', 'g': ColorOf := LightGray;
    'd': ColorOf := DarkGray;
    'Y': ColorOf := Yellow;
    'B': ColorOf := Brown;
  else
    ColorOf := Black;
  end;
end;

{ Put picture pic into frame n of the made-up block 202. }
procedure PutSym(n: Byte; var pic: TPicture);
var
  x: Byte;
  y: Byte;
  at: Word;
begin
  for y := 0 to 7 do
    for x := 0 to 7 do begin
      at := BarArt.HEADER_BYTES + n * BarArt.CELL_BYTES + y * 4 + x div 2;
      if x mod 2 = 0 then
        sym[at] := (sym[at] and $0F) or (ColorOf(pic[y][x + 1]) shl 4)
      else
        sym[at] := (sym[at] and $F0) or ColorOf(pic[y][x + 1]);
    end;
end;

{ True when frame n of block is pic, pixel for pixel. }
function Matches(n: Byte; var pic: TPicture): Boolean;
var
  x: Byte;
  y: Byte;
  same: Boolean;
begin
  same := True;
  for y := 0 to 7 do
    for x := 0 to 7 do
      if BarArt.Pixel(block, n, x, y) <> ColorOf(pic[y][x + 1]) then
        same := False;
  Matches := same;
end;

{ True when every pixel of frame n is the checkerboard: dark gray where x + y is even, black elsewhere. }
function IsTrack(n: Byte): Boolean;
var
  x: Byte;
  y: Byte;
  same: Boolean;
begin
  same := True;
  for y := 0 to 7 do
    for x := 0 to 7 do
      if ((x + y) mod 2 = 0) <> (BarArt.Pixel(block, n, x, y) = DarkGray) then
        same := False;
  IsTrack := same;
end;

begin
  TestKit.Start('TBARART');
  FillChar(sym, SizeOf(sym), 0);
  { block 202's header: 8 high, 1 wide, origin 0,0, 31 frames, a color map }
  sym[0] := 8;
  sym[2] := 1;
  sym[8] := SYM_FRAMES;
  for i := 9 to 16 do
    sym[i] := i;
  PutSym(BarArt.CORNER_FRAME, CORNER);

  TestKit.Check(BarArt.MakeBlock(sym, SizeOf(sym), block), 'a block 202 with the corner box makes the bar block');
  ok := True;
  for i := 0 to BarArt.HEADER_BYTES - 1 do
    if (i <> BarArt.COUNT_AT) and (block[i] <> sym[i]) then
      ok := False;
  TestKit.Check(ok, 'the header is 202''s, height, width and color map');
  TestKit.CheckEqualsL(BarArt.BAR_CELLS, block[BarArt.COUNT_AT], 'with 8 frames');
  TestKit.CheckEqualsL(17 + 8 * 32, SizeOf(block), 'header and 8 frames of 32 bytes');

  TestKit.Check(Matches(BarArt.BAR_UP, UP_ARROW), 'the up arrow is scrollbar.txt''s');
  TestKit.Check(Matches(BarArt.BAR_DOWN, DOWN_ARROW), 'the down arrow is scrollbar.txt''s');
  TestKit.Check(IsTrack(BarArt.BAR_TRACK), 'the track is the checkerboard, dark gray in the top-left pixel');
  TestKit.Check(Matches(BarArt.BAR_KNOB_ONE, KNOB_ONE), 'the one-cell knob is bevelled on all four sides');
  TestKit.CheckEqualsL(White, BarArt.Pixel(block, BarArt.BAR_KNOB_TOP, 3, 0), 'the knob''s top cell has a white top');
  TestKit.CheckEqualsL(LightGray, BarArt.Pixel(block, BarArt.BAR_KNOB_MIDDLE, 3, 0), 'a middle cell has none');
  TestKit.CheckEqualsL(DarkGray, BarArt.Pixel(block, BarArt.BAR_KNOB_BOTTOM, 3, 7),
                       'the bottom cell has a dark gray bottom');
  TestKit.CheckEqualsL(White, BarArt.Pixel(block, BarArt.BAR_KNOB_MIDDLE, 0, 4), 'every knob cell''s left edge is white');
  TestKit.CheckEqualsL(DarkGray, BarArt.Pixel(block, BarArt.BAR_KNOB_MIDDLE, 7, 4),
                       'and its right edge dark gray');
  TestKit.Check(Matches(BarArt.BAR_GRIP, GRIP), 'the grip is the corner box in grays, with the knob''s edges');

  TestKit.Check(not BarArt.MakeBlock(sym, BarArt.HEADER_BYTES + BarArt.CORNER_FRAME * BarArt.CELL_BYTES, block),
                'a block 202 cut short of the corner box makes none');
  TestKit.Done;
end.
