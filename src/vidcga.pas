{ The CGA video driver: BIOS mode 4, 320x200 in 4 colours at 2 bits a pixel, even and odd rows in separate banks at
  $B800 and $BA00. Resident, since its routines are the hot ones; GameBoot installs it when POOL.CFG names CGA (phase 6
  of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidCga;

interface

uses Types;

{ Make this the video driver: fill GameVars.video. }
procedure Install;

{ The banked modes' copies to the screen, CGA's and Tandy's (VidTdy installs them too): each scanline at its
  GameVars.bankRowSeg segment, 1 shl cellShift bytes a cell row in a picture and 1 shl screenShift a cell column on the
  screen, which are the same in both. }
procedure FlushSpans;
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ The CGA colour, 0..3, DrawGlyph draws text colour fg in: fg mapped through attrTable, but for DarkGray. CGA's four
  colours have no grey, and attrTable draws DarkGray as white, as bright as the text it greys out (#1185), so greyed
  text is drawn in magenta. A checkerboard of white at half density was tried first and left letters such as E, L and
  S unreadable. attrTable is SSI's and stays as it is, since pictures go through it too. }
function TextColour(fg: Byte): Byte;

implementation

uses Crt, C_VIDEO, GameDefs, GameVars, DaxIo, Blit, PicCga;

const
  { CGA's magenta in palette 1 }
  CGA_MAGENTA = 2;

var
  { the two banks: even scanlines at $B800, odd at $BA00, 80 bytes a scanline and 4 scanlines of each to a text row }
  cgaB800: array[0..255] of Types.TCgaRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK0_SEG:$0000{$ENDIF};
  cgaBA00: array[0..255] of Types.TCgaRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK1_SEG:$0000{$ENDIF};

procedure Start;
begin
end;

{ the dirty spans of the view, which starts a cell row down and a cell column in }
procedure FlushSpans;
var
  row: Word;
begin
  for row := 0 to SizeOf(GameVars.spanActive) - 1 do
    if GameVars.spanActive[row] <> 0 then
      Move(GameVars.viewBuffer^.data[GameVars.spanFirstOfs[row]],
           Mem[GameVars.bankRowSeg[row + 8]:GameVars.spanScreenOfs[row] + 1 shl GameVars.video.screenShift],
           GameVars.spanLastOfs[row] - GameVars.spanFirstOfs[row] + 1);
end;

{ a scanline at a time through the row segments }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  row: Integer;
  colOff: Word;
  firstRow: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
begin
  with pic^ do begin
    rowBytes := width shl GameVars.video.cellShift;
    srcOff := 0;
    firstRow := screenY * 8;
    lastRow := firstRow + height - 1;
    colOff := screenX shl GameVars.video.screenShift;
    for row := firstRow to lastRow do begin
      Move(pic^.data[srcOff], Mem[GameVars.bankRowSeg[row]:colOff], rowBytes);
      Inc(srcOff, rowBytes);
    end;
  end;
end;

function TextColour(fg: Byte): Byte;
begin
  if fg = DarkGray then
    TextColour := CGA_MAGENTA
  else
    TextColour := GameDefs.attrTable[fg];
end;

{ fg is mapped to CGA's by TextColour and bg through attrTable (no text is drawn on DarkGray); each pixel's 2 bits come
  from cgaColorPat, fg's under a set font bit and bg's under a clear one; font rows 0, 2, 4 and 6 go to the even bank,
  1, 3, 5 and 7 to the odd }
procedure DrawGlyph(col, row, fg, bg, glyph: Byte);
const
  { CGA colors 0..3 repeated across eight 2-bit pixels }
  cgaColorPat: array[0..3] of Word = (
    $0000, $5555, $AAAA, $FFFF);
var
  bankRow: Word;
  fontRow: Byte;
  cgaWord: Word;
  inkMask: Word;
  inkPat: Word;
  paperPat: Word;
  k: Byte;
begin
  inkPat := cgaColorPat[VidCga.TextColour(fg)];
  paperPat := cgaColorPat[GameDefs.attrTable[bg]];
  for fontRow := 0 to 7 do begin
    inkMask := 0;
    for k := 0 to 7 do
      if (GameVars.gameFont^[glyph][fontRow] and ($80 shr k)) > 0 then
        inkMask := inkMask or GameDefs.cgaPixelMask[k];
    cgaWord := (inkMask and inkPat) or ((inkMask xor $FFFF) and paperPat);
    bankRow := row * 4 + fontRow shr 1;
    if Odd(fontRow) then
      cgaBA00[bankRow][col] := Swap(cgaWord)
    else
      cgaB800[bankRow][col] := Swap(cgaWord);
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  row: Word;
  byteCount: Word;
begin
  byteCount := (lrCol - ulCol + 1) * 2;
  for row := ulRow * 4 to lrRow * 4 + 3 do begin
    FillChar(cgaB800[row][ulCol], byteCount, 0);
    FillChar(cgaBA00[row][ulCol], byteCount, 0);
  end;
end;

procedure ClearScreen;
begin
  FillChar(cgaBA00, SizeOf(Types.TCgaBank), 0);
  FillChar(cgaB800, SizeOf(Types.TCgaBank), 0);
end;

{ the attribute's colour (its low four bits) mapped through attrTable, on the one page }
procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GameVars.pageMain, col, row, GameDefs.attrTable[attr and $0F], count, ch);
end;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  { the colour map picks which of the 4 colours shows color }
  FillChar(cell, SizeOf(cell), GameDefs.cgaColorFill[Blit.SrcNibble(color, colorMap)]);
end;

{ no palette registers }
procedure SetPalette(registerIndex, color: Byte);
begin
end;

procedure Install;
begin
  with GameVars.video do begin
    name := 'CGA';
    colours := 4;
    hasPalette := False;
    keyed := False;
    cellShift := 1;
    screenShift := 1;
    maskShift := 0;
    CellFill := VidCga.CellFill;
    biosMode := 4;
    ramVideoParas := 0;
    Start := VidCga.Start;
    FlushSpans := VidCga.FlushSpans;
    ShowPic := VidCga.ShowPic;
    DrawGlyph := VidCga.DrawGlyph;
    ClearRect := VidCga.ClearRect;
    ClearScreen := VidCga.ClearScreen;
    WriteChar := VidCga.WriteChar;
    ExpandChunk := PicCga.ExpandChunk;
    MirrorFrame := PicCga.MirrorFrame;
    RemapColour := PicCga.RemapColour;
    RecolorFrame := PicCga.RecolorFrame;
    PutPixelRow := PicCga.PutPixelRow;
    InitRowTables := PicCga.InitRowTables;
    SetPalette := VidCga.SetPalette;
    { the 320 x 200 screen: no fine entries (VidVesa's) }
    fine := False;
  end;
end;

end.
