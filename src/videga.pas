{ The EGA video driver: BIOS mode 0Dh, 320x200 in 16 colours on four planes at $A000; page 0 is shown, page 1 is
  FlushSpans' staging area. Resident, since its routines are the hot ones; GameBoot installs it when POOL.CFG names EGA
  (phase 6 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidEga;

interface

{ Make this the video driver: fill GameVars.video. }
procedure Install;

implementation

uses Types, C_VIDEO, C_EGA, GameDefs, GameVars, DaxIo, Crt, Dos, PicEga;

const
  { write-mode 1: CPU write stores the 4 latched planes (a 4-plane block copy through the latches) }
  GC_WRITE_MODE_1 = 1;
  { write-mode 2: the CPU byte's low four bits are a colour written to every pixel of the byte }
  GC_WRITE_MODE_2 = 2;
  { off-screen planar staging area (0x200 para = 8 KB up) }
  EGA_STAGE_SEG = $A200;

var
  { the video segment of the displayed page, page 0 (Start); page 1, at EGA_STAGE_SEG, is FlushSpans' staging area }
  egaCurPage: Word;

{ Reset EGA graphics-controller registers, enable all color planes and set the full bit mask. }
procedure ResetEgaGc;
begin
  Port[C_EGA.GC_ADDR_PORT] := 0;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 1;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 2;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 3;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 4;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 5;
  Port[C_EGA.GC_DATA_PORT] := 0;
  Port[C_EGA.GC_ADDR_PORT] := 7;
  Port[C_EGA.GC_DATA_PORT] := $0F;
  Port[C_EGA.GC_ADDR_PORT] := 8;
  Port[C_EGA.GC_DATA_PORT] := $FF;
  Port[C_EGA.SEQ_ADDR_PORT] := C_EGA.SEQ_MAP_MASK_REG;
  Port[C_EGA.SEQ_DATA_PORT] := C_EGA.MAP_MASK_ALL_PLANES;
end;

{ Make page the active display page (INT10 AH=5) and store its segment base, with a 512-paragraph stride, in
  egaCurPage. }
procedure SetupEgaCurrentPage(page: Byte);
begin
  GameVars.interruptRegisters.ah := 5;
  GameVars.interruptRegisters.al := page;
  Intr($10, GameVars.interruptRegisters);
  egaCurPage := C_VIDEO.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

{ Fill a character-cell rectangle of the displayed page with color using write mode 2, then restore write mode 0. }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: Byte; color: Byte);
var
  dstOff: Word;
  rowCount: Word;
  i: Word;
begin
  dstOff := Word(ulRow) * 40 * 8 + ulCol;
  rowCount := (lrRow - ulRow + 1) * 8 - 1;
  VidEga.ResetEgaGc;
  Port[C_EGA.GC_ADDR_PORT] := C_EGA.GC_MODE_REG;
  Port[C_EGA.GC_DATA_PORT] := GC_WRITE_MODE_2;
  for i := 0 to rowCount do begin
    FillChar(Mem[egaCurPage: dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40);
  end;
  Port[C_EGA.GC_ADDR_PORT] := C_EGA.GC_MODE_REG;
  Port[C_EGA.GC_DATA_PORT] := C_EGA.GC_WRITE_MODE_0;
end;

{ page 0 shown and drawn on (SSI's second page is gone: its memory is FlushSpans' staging area) }
procedure Start;
begin
  GameVars.pageMain := 0;
  VidEga.SetupEgaCurrentPage(GameVars.pageMain);
end;

{ Each span is staged plane by plane in off-screen video memory and then copied to the visible page in one latch-copy
  pass, so the visible memory is never left with only some planes updated. An EGA last offset of $FFFF would keep the
  plane loop from ending. }
procedure FlushSpans;
var
  row: Word;
  srcOff: Word;
  dstOff: Word;
  dstBase: Word;
  plane: Byte;
begin
  Port[C_EGA.SEQ_ADDR_PORT] := C_EGA.SEQ_MAP_MASK_REG;
  for row := 0 to SizeOf(GameVars.spanActive) - 1 do
    if GameVars.spanActive[row] <> 0 then begin
      dstBase := GameVars.fbRowOfs[row + 8] + GameVars.spanScreenOfs[row] + 1;
      { each plane's bytes, every fourth from its own in the view buffer }
      for plane := 0 to 3 do begin
        Port[C_EGA.SEQ_DATA_PORT] := GameDefs.egaPlaneBit[plane];
        srcOff := GameVars.spanFirstOfs[row] + plane;
        dstOff := dstBase;
        repeat
          Mem[EGA_STAGE_SEG:dstOff] := GameVars.viewBuffer^.data[srcOff];
          Inc(srcOff, 4);
          Inc(dstOff);
        until srcOff > GameVars.spanLastOfs[row];
      end;
    end;
  Port[C_EGA.SEQ_DATA_PORT] := C_EGA.MAP_MASK_ALL_PLANES;
  dstOff := GameVars.fbRowOfs[8] + 1;
  Port[C_EGA.GC_ADDR_PORT] := C_EGA.GC_MODE_REG;
  Port[C_EGA.GC_DATA_PORT] := GC_WRITE_MODE_1;
  for row := 0 to SizeOf(GameVars.spanActive) - 1 do begin
    if GameVars.spanActive[row] <> 0 then
      Move(Mem[EGA_STAGE_SEG:dstOff + GameVars.spanScreenOfs[row]],
           Mem[C_VIDEO.EGA_VIDEO_SEG:dstOff + GameVars.spanScreenOfs[row]],
           (GameVars.spanLastOfs[row] - GameVars.spanFirstOfs[row]) div 4 + 1);
    Inc(dstOff, 40);
  end;
  Port[C_EGA.GC_DATA_PORT] := C_EGA.GC_WRITE_MODE_0;
end;

{ 4 plane bytes per cell through the sequencer's map mask }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  srcOff: Word;
  plane: Byte;
begin
  with pic^ do begin
    srcOff := 0;
    firstRow := screenY * 8;
    lastRow := firstRow + height - 1;
    colOff := screenX;
    colEnd := colOff + width - 1;
    Port[C_EGA.SEQ_ADDR_PORT] := C_EGA.SEQ_MAP_MASK_REG;
    for row := firstRow to lastRow do
      for col := colOff to colEnd do
        for plane := 0 to 3 do begin
          Port[C_EGA.SEQ_DATA_PORT] := GameDefs.egaPlaneBit[plane];
          Mem[C_VIDEO.EGA_VIDEO_SEG:GameVars.fbRowOfs[row] + col] := pic^.data[srcOff];
          Inc(srcOff);
        end;
    Port[C_EGA.SEQ_DATA_PORT] := C_EGA.MAP_MASK_ALL_PLANES;
  end;
end;

{ all four planes: in each plane, the font row's set bits take fg's bit and its clear bits bg's }
procedure DrawGlyph(col, row, fg, bg, glyph: Byte);
var
  dstOff: Word;
  plane: Byte;
  fontRow: Byte;
  bits: Byte;
  planeByte: Byte;
begin
  dstOff := (row * 8) * 40 + col;
  Port[C_EGA.SEQ_ADDR_PORT] := C_EGA.SEQ_MAP_MASK_REG;
  for fontRow := 0 to 7 do begin
    bits := GameVars.gameFont^[glyph][fontRow];
    for plane := 0 to 3 do begin
      Port[C_EGA.SEQ_DATA_PORT] := GameDefs.egaPlaneBit[plane];
      planeByte := 0;
      if (GameDefs.egaPlaneBit[plane] and fg) > 0 then
        planeByte := bits;
      if (GameDefs.egaPlaneBit[plane] and bg) > 0 then
        planeByte := planeByte or (bits xor $FF);
      Mem[egaCurPage: dstOff] := planeByte;
    end;
    Inc(dstOff, 40);
  end;
  Port[C_EGA.SEQ_DATA_PORT] := C_EGA.MAP_MASK_ALL_PLANES;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
begin
  VidEga.FillRectEga(ulCol, ulRow, lrCol, lrRow, Black);
end;

procedure ClearScreen;
begin
  VidEga.FillRectEga(0, 0, 39, 24, Black);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GameVars.pageMain, col, row, attr, count, ch);
end;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
var
  plane: Byte;
begin
  { a byte a plane: all set where the colour has that plane's bit }
  for plane := 0 to 3 do
    if (GameDefs.egaPlaneBit[plane] and color) > 0 then
      cell[plane] := $FF
    else
      cell[plane] := 0;
end;

{ one palette register through BIOS INT 10h AX=1000h; bright colours (8..15) are offset by a further 8 to reach their
  palette values }
procedure SetPalette(registerIndex, color: Byte);
begin
  GameVars.interruptRegisters.ah := $10;
  GameVars.interruptRegisters.al := 0;
  if color < 8 then
    GameVars.interruptRegisters.bh := color
  else
    GameVars.interruptRegisters.bh := color + 8;
  GameVars.interruptRegisters.bl := registerIndex;
  Intr($10, GameVars.interruptRegisters);
end;

procedure Install;
begin
  with GameVars.video do begin
    name := 'EGA';
    colours := 16;
    hasPalette := True;
    keyed := False;
    cellShift := 2;
    screenShift := 0;
    maskShift := 2;
    CellFill := VidEga.CellFill;
    biosMode := 13;
    ramVideoParas := 0;
    Start := VidEga.Start;
    FlushSpans := VidEga.FlushSpans;
    ShowPic := VidEga.ShowPic;
    DrawGlyph := VidEga.DrawGlyph;
    ClearRect := VidEga.ClearRect;
    ClearScreen := VidEga.ClearScreen;
    WriteChar := VidEga.WriteChar;
    ExpandChunk := PicEga.ExpandChunk;
    MirrorFrame := PicEga.MirrorFrame;
    RemapColour := PicEga.RemapColour;
    RecolorFrame := PicEga.RecolorFrame;
    PutPixelRow := PicEga.PutPixelRow;
    InitRowTables := PicEga.InitRowTables;
    SetPalette := VidEga.SetPalette;
    { the 320 x 200 screen: no fine entries (VidVesa's) }
    fine := False;
  end;
end;

end.
