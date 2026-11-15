{ The scroll bar's cells (docs/screen-mocks/scrollbar.txt), made by the Data Builder into a block of the merged 8X8D
  archive (C_DATA.SCROLL_BAR_BLOCK) so that the game draws finished cells, recolors nothing while it runs, and the cells
  can be looked at and changed in the archive. The block is a picture as symbol block 202 is: 202's 17-byte header
  with BAR_CELLS frames, then each frame's 8 rows of 4 bytes, two pixels a byte, high nibble first. }
{$O+,F+}
{$I COMPILER.INC}
unit BarArt;

interface

const
  { the frames, in order: symbols Sym8x8.BAR_FIRST + n }
  BAR_UP = 0;
  BAR_DOWN = 1;
  BAR_TRACK = 2;
  BAR_KNOB_TOP = 3;
  BAR_KNOB_MIDDLE = 4;
  BAR_KNOB_BOTTOM = 5;
  BAR_KNOB_ONE = 6;
  BAR_GRIP = 7;
  BAR_CELLS = 8;
  { a picture block's header: height, width (in 8-pixel units), two offsets, the frame count, the color map }
  HEADER_BYTES = 17;
  { the frame count's place in the header }
  COUNT_AT = 8;
  { bytes in one 8x8 frame }
  CELL_BYTES = 32;
  BLOCK_BYTES = HEADER_BYTES + BAR_CELLS * CELL_BYTES;
  { the gold corner box, the grip's source: symbol 276, frame 20 of block 202 (symbols 256 on) }
  CORNER_FRAME = 20;

type
  TBarBlock = array[0..BLOCK_BYTES - 1] of Byte;

{ Make the scroll bar block from sym, block 202's raw bytes (symLen of them): its header with BAR_CELLS frames, the
  pictures of scrollbar.txt, and the grip from 202's corner box. False, block untouched, when sym is too short to hold
  the corner box. }
function MakeBlock(var sym; symLen: Word; var block: TBarBlock): Boolean;

{ The color of pixel (x, y), both 0 to 7, of frame n of block: for tests and for checking a block read back. }
function Pixel(var block: TBarBlock; n, x, y: Byte): Byte;

implementation

uses Crt;

type
  TBytes = array[0..65519] of Byte;
  TPicture = array[0..7] of string[8];

const
  { scrollbar.txt's pictures: '-' light gray, '*' white, '.' black on the arrows; 'd' dark gray and '.' black on the
    track; 'W' white, 'g' light gray, 'd' dark gray on the knob }
  UP_ARROW: TPicture = ('--------', '---*----', '--***---', '-*****--', '--***..-', '--***.--', '---...--', '--------');
  DOWN_ARROW: TPicture = ('--------', '--***---', '--***.--', '--***.--', '-*****--', '--***..-', '---*..--',
                          '----.---');
  TRACK: TPicture = ('d.d.d.d.', '.d.d.d.d', 'd.d.d.d.', '.d.d.d.d', 'd.d.d.d.', '.d.d.d.d', 'd.d.d.d.', '.d.d.d.d');
  KNOB_TOP: TPicture = ('WWWWWWWd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd',
                        'Wggggggd');
  KNOB_MIDDLE: TPicture = ('Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd',
                           'Wggggggd');
  KNOB_BOTTOM: TPicture = ('Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd',
                           'dddddddd');
  KNOB_ONE: TPicture = ('WWWWWWWd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd', 'Wggggggd',
                        'dddddddd');

function ColorOf(ch: Char): Byte;
begin
  case ch of
    '*', 'W': ColorOf := White;
    '-', 'g': ColorOf := LightGray;
    'd': ColorOf := DarkGray;
  else
    ColorOf := Black;
  end;
end;

procedure SetPixel(var block: TBarBlock; n, x, y, color: Byte);
var
  at: Word;
begin
  at := HEADER_BYTES + n * CELL_BYTES + y * 4 + x div 2;
  if x mod 2 = 0 then
    block[at] := (block[at] and $0F) or (color shl 4)
  else
    block[at] := (block[at] and $F0) or color;
end;

function Pixel(var block: TBarBlock; n, x, y: Byte): Byte;
var
  b: Byte;
begin
  b := block[HEADER_BYTES + n * CELL_BYTES + y * 4 + x div 2];
  if x mod 2 = 0 then
    Pixel := b shr 4
  else
    Pixel := b and $0F;
end;

procedure Draw(var block: TBarBlock; n: Byte; var pic: TPicture);
var
  x: Byte;
  y: Byte;
begin
  for y := 0 to 7 do
    for x := 0 to 7 do
      SetPixel(block, n, x, y, ColorOf(pic[y][x + 1]));
end;

function MakeBlock(var sym; symLen: Word; var block: TBarBlock): Boolean;
var
  s: TBytes absolute sym;
  x: Byte;
  y: Byte;
  b: Byte;
  c: Byte;
begin
  MakeBlock := False;
  if symLen < HEADER_BYTES + (CORNER_FRAME + 1) * CELL_BYTES then
    Exit;
  FillChar(block, SizeOf(block), 0);
  Move(s[0], block[0], HEADER_BYTES);
  block[COUNT_AT] := BAR_CELLS;
  Draw(block, BAR_UP, UP_ARROW);
  Draw(block, BAR_DOWN, DOWN_ARROW);
  Draw(block, BAR_TRACK, TRACK);
  Draw(block, BAR_KNOB_TOP, KNOB_TOP);
  Draw(block, BAR_KNOB_MIDDLE, KNOB_MIDDLE);
  Draw(block, BAR_KNOB_BOTTOM, KNOB_BOTTOM);
  Draw(block, BAR_KNOB_ONE, KNOB_ONE);
  { the grip: the corner box recolored as a middle cell, yellow to light gray, brown to dark gray, its white kept; the
    knob's white left edge and dark gray right edge kept }
  for y := 0 to 7 do
    for x := 0 to 7 do begin
      b := s[HEADER_BYTES + CORNER_FRAME * CELL_BYTES + y * 4 + x div 2];
      if x mod 2 = 0 then
        c := b shr 4
      else
        c := b and $0F;
      case c of
        Yellow: c := LightGray;
        Brown: c := DarkGray;
      end;
      if x = 0 then
        c := White
      else if x = 7 then
        c := DarkGray;
      SetPixel(block, BAR_GRIP, x, y, c);
    end;
  MakeBlock := True;
end;

end.
