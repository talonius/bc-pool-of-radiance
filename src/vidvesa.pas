{ The VESA video driver (#1231): VBE mode 100h, 640x400 at a byte a pixel, reached through a 64 KB window onto the
  card's 250 KB, one bank at a time. The game's pictures and its 320 x 200 layout are VGA's (VidVga's picture layout
  and palette), drawn 2 x 2, so they look as they do in mode 13h; the fine entries (TVideoDriver.fine) draw text and the
  combat minimap at the screen's own pixels. There is no room in conventional memory for a copy of the screen, so
  everything is drawn straight to the card, each scanline's run cut where it crosses a bank. Resident, as VidVga is;
  GameBoot installs it when POOL.CFG names it (C_OPT.VIDEO_VESA), and VGA in its place when the card has no VBE or no
  mode 100h. }
{$F+}
{$I COMPILER.INC}
unit VidVesa;

interface

{ Make this the video driver when the card offers VBE mode 100h, and say True; otherwise leave GameVars.video as it is
  and say False. Called before any mode is set, from the text screen. }
function Install: Boolean;

implementation

uses Dos, Types, GameVars, VidVga;

const
  { the mode: 640 x 400 at a byte a pixel }
  VESA_MODE = $100;
  SCREEN_WIDTH = 640;
  SCREEN_HEIGHT = 400;
  { the VBE functions, in AX with INT 10h: controller information, mode information, set mode, window position; and
    what AX holds after each that worked }
  VBE_INFO = $4F00;
  VBE_MODE_INFO = $4F01;
  VBE_SET_MODE = $4F02;
  VBE_WINDOW = $4F05;
  VBE_OK = $004F;
  { a window attribute: the CPU can write through it }
  WINDOW_WRITABLE = 4;
  { the view buffer's place on the 320 x 200 screen: its corner at (8, 8), inside the view window's border }
  VIEW_LEFT = 8;
  VIEW_TOP = 8;

type
  { VBE function 4F00h's answer, as much of it as is read: the signature and the far pointer to the mode list }
  TVbeInfo = record
    signature: array[0..3] of Char;
    version: Word;
    oemName: Pointer;
    capabilities: LongInt;
    modes: Pointer;
    rest: array[0..493] of Byte;
  end;
  { VBE function 4F01h's answer, as much of it as is read }
  TVbeModeInfo = record
    attributes: Word;
    winAAttributes: Byte;
    winBAttributes: Byte;
    granularity: Word;
    winSize: Word;
    winASegment: Word;
    winBSegment: Word;
    winFunction: Pointer;
    pitch: Word;
    rest: array[0..237] of Byte;
  end;
  PWordList = ^TWordList;
  TWordList = array[0..255] of Word;
  { one scanline's pixels }
  TScanline = array[0..SCREEN_WIDTH - 1] of Byte;

var
  { the window the game writes through (0 A, 1 B), its segment, and the bytes a step of its position moves it }
  window: Byte;
  windowSeg: Word;
  granuleBytes: LongInt;
  { the bytes a scanline takes on the card }
  pitch: LongInt;
  { where the window now starts on the card, -1 before the first move }
  windowStart: LongInt;

{ Point the window at the 64 KB of the card from start (a multiple of granuleBytes). }
procedure MoveWindow(start: LongInt);
var
  regs: Registers;
begin
  if start = windowStart then Exit;
  regs.ax := VBE_WINDOW;
  regs.bx := window;
  regs.dx := start div granuleBytes;
  Intr($10, regs);
  windowStart := start;
end;

{ Copy count bytes from src to the card from byte at, moving the window as the run needs: a run of a scanline crosses
  at most one 64 KB boundary. }
procedure PutRun(at: LongInt; var src; count: Word);
var
  bytes: Types.PByteArr;
  inWindow: Word;
  first: Word;
begin
  bytes := @src;
  while count > 0 do begin
    if (at < windowStart) or (at >= windowStart + 65536) or (windowStart < 0) then
      VidVesa.MoveWindow(at - at mod granuleBytes);
    inWindow := at - windowStart;
    if LongInt(inWindow) + count > 65536 then
      first := 65536 - LongInt(inWindow)
    else
      first := count;
    Move(bytes^, Mem[windowSeg:inWindow], first);
    Inc(at, first);
    Dec(count, first);
    bytes := @bytes^[first];
  end;
end;

{ Fill count bytes of the card from byte at with color, moving the window as PutRun does. }
procedure FillRun(at: LongInt; count: Word; color: Byte);
var
  inWindow: Word;
  first: Word;
begin
  while count > 0 do begin
    if (at < windowStart) or (at >= windowStart + 65536) or (windowStart < 0) then
      VidVesa.MoveWindow(at - at mod granuleBytes);
    inWindow := at - windowStart;
    if LongInt(inWindow) + count > 65536 then
      first := 65536 - LongInt(inWindow)
    else
      first := count;
    FillChar(Mem[windowSeg:inWindow], first, color);
    Inc(at, first);
    Dec(count, first);
  end;
end;

{ The card's byte for pixel (x, y). }
function PixelAt(x, y: Word): LongInt;
begin
  PixelAt := y * pitch + x;
end;

{ count pixels from src, each widened to two, onto scanlines y and y + 1 from pixel x: one 320 x 200 scanline's run,
  drawn 2 x 2 }
procedure PutDoubled(x, y: Word; var src; count: Word);
var
  bytes: Types.PByteArr;
  line: TScanline;
  i: Word;
begin
  if count = 0 then Exit;
  bytes := @src;
  for i := 0 to count - 1 do begin
    line[i * 2] := Byte(bytes^[i]);
    line[i * 2 + 1] := Byte(bytes^[i]);
  end;
  VidVesa.PutRun(VidVesa.PixelAt(x, y), line, count * 2);
  VidVesa.PutRun(VidVesa.PixelAt(x, y + 1), line, count * 2);
end;

{ the view buffer's dirty spans, each a run of a 320 x 200 scanline, drawn 2 x 2 }
procedure FlushSpans;
var
  row: Word;
begin
  for row := 0 to SizeOf(GameVars.spanActive) - 1 do
    if GameVars.spanActive[row] <> 0 then
      VidVesa.PutDoubled((GameVars.spanScreenOfs[row] + VIEW_LEFT) * 2, (row + VIEW_TOP) * 2,
                         GameVars.viewBuffer^.data[GameVars.spanFirstOfs[row]],
                         GameVars.spanLastOfs[row] - GameVars.spanFirstOfs[row] + 1);
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  row: Word;
  rowBytes: Word;
  srcOff: Word;
begin
  with pic^ do begin
    rowBytes := width * 8;
    srcOff := 0;
    for row := screenY * 8 to screenY * 8 + height - 1 do begin
      VidVesa.PutDoubled(screenX * 16, row * 2, data[srcOff], rowBytes);
      Inc(srcOff, rowBytes);
    end;
  end;
end;

{ A glyph's 8 x 8 bits from pixel (x, y), each bit size x size pixels: fg where it is set, bg where it is clear. }
procedure PutGlyph(x, y: Word; size, fg, bg, glyph: Byte);
var
  line: array[0..15] of Byte;
  r: Byte;
  k: Byte;
  i: Byte;
  bits: Byte;
  color: Byte;
begin
  for r := 0 to 7 do begin
    bits := GameVars.gameFont^[glyph][r];
    for k := 0 to 7 do begin
      if (bits and ($80 shr k)) <> 0 then
        color := fg
      else
        color := bg;
      for i := 0 to size - 1 do
        line[k * size + i] := color;
    end;
    for i := 0 to size - 1 do
      VidVesa.PutRun(VidVesa.PixelAt(x, y + r * size + i), line, 8 * size);
  end;
end;

{ a cell of the 40 x 25 grid: the glyph 2 x 2 }
procedure DrawGlyph(col, row, fg, bg, glyph: Byte);
begin
  VidVesa.PutGlyph(col * 16, row * 16, 2, fg, bg, glyph);
end;

procedure DrawFineGlyph(col, row, fg, bg, glyph: Byte);
begin
  VidVesa.PutGlyph(col * 8, row * 8, 1, fg, bg, glyph);
end;

{ Clear the rectangle of cells size pixels square, from cell (ulCol, ulRow) to (lrCol, lrRow), to black. }
procedure ClearCells(ulCol, ulRow, lrCol, lrRow, size: Byte);
var
  y: Word;
begin
  for y := ulRow * size to lrRow * size + size - 1 do
    VidVesa.FillRun(VidVesa.PixelAt(ulCol * size, y), (lrCol - ulCol + 1) * size, 0);
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
begin
  VidVesa.ClearCells(ulCol, ulRow, lrCol, lrRow, 16);
end;

procedure ClearFineRect(ulCol, ulRow, lrCol, lrRow: Byte);
begin
  VidVesa.ClearCells(ulCol, ulRow, lrCol, lrRow, 8);
end;

procedure ClearScreen;
var
  y: Word;
begin
  for y := 0 to SCREEN_HEIGHT - 1 do
    VidVesa.FillRun(VidVesa.PixelAt(0, y), SCREEN_WIDTH, 0);
end;

procedure PutPixels(x, y: Word; var src; count: Word);
begin
  VidVesa.PutRun(VidVesa.PixelAt(x, y), src, count);
end;

{ Set mode 100h once the BIOS has set mode 13h (GameBoot): VBE function 4F02h, then the window back to its unknown
  state, since the mode set moves it. }
procedure Start;
var
  regs: Registers;
begin
  regs.ax := VBE_SET_MODE;
  regs.bx := VESA_MODE;
  Intr($10, regs);
  windowStart := -1;
end;

{ True when the card's VBE lists mode 100h and describes a window the game can write through; window, windowSeg,
  granuleBytes and pitch are then set from the mode's information. }
function FindMode: Boolean;
var
  regs: Registers;
  info: TVbeInfo;
  modeInfo: TVbeModeInfo;
  modes: PWordList;
  i: Byte;
  listed: Boolean;
begin
  FindMode := False;
  regs.ax := VBE_INFO;
  regs.es := Seg(info);
  regs.di := Ofs(info);
  Intr($10, regs);
  if (regs.ax <> VBE_OK) or (info.signature[0] <> 'V') or (info.signature[1] <> 'E') or (info.signature[2] <> 'S') or
     (info.signature[3] <> 'A') then Exit;
  modes := info.modes;
  listed := False;
  i := 0;
  while (modes^[i] <> $FFFF) and (i < 255) do begin
    if modes^[i] = VESA_MODE then
      listed := True;
    Inc(i);
  end;
  if not listed then Exit;
  regs.ax := VBE_MODE_INFO;
  regs.cx := VESA_MODE;
  regs.es := Seg(modeInfo);
  regs.di := Ofs(modeInfo);
  Intr($10, regs);
  if regs.ax <> VBE_OK then Exit;
  if (modeInfo.winAAttributes and WINDOW_WRITABLE) <> 0 then begin
    window := 0;
    windowSeg := modeInfo.winASegment;
  end else if (modeInfo.winBAttributes and WINDOW_WRITABLE) <> 0 then begin
    window := 1;
    windowSeg := modeInfo.winBSegment;
  end else
    Exit;
  if (modeInfo.granularity = 0) or (modeInfo.winSize < 64) then Exit;
  granuleBytes := LongInt(modeInfo.granularity) * 1024;
  pitch := modeInfo.pitch;
  if pitch < SCREEN_WIDTH then
    pitch := SCREEN_WIDTH;
  FindMode := True;
end;

function Install: Boolean;
begin
  Install := False;
  if not VidVesa.FindMode then Exit;
  { VGA's pictures and palette; the screen's own routines replace mode 13h's }
  VidVga.Install;
  with GameVars.video do begin
    name := 'VGA 640x400';
    Start := VidVesa.Start;
    FlushSpans := VidVesa.FlushSpans;
    ShowPic := VidVesa.ShowPic;
    DrawGlyph := VidVesa.DrawGlyph;
    ClearRect := VidVesa.ClearRect;
    ClearScreen := VidVesa.ClearScreen;
    fine := True;
    DrawFineGlyph := VidVesa.DrawFineGlyph;
    ClearFineRect := VidVesa.ClearFineRect;
    PutPixels := VidVesa.PutPixels;
  end;
  windowStart := -1;
  Install := True;
end;

end.
