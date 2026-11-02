{ The Tandy video driver: BIOS mode 9, 320x200 in 16 colours at 4 bits a pixel, four banks from $B800. Resident, since
  its routines are the hot ones; GameBoot installs it when POOL.CFG names Tandy (phase 6 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidTdy;

interface

{ Make this the video driver: fill GameVars.video. }
procedure Install;

implementation

uses Types, C_VIDEO, GameVars, DaxIo, PicTdy, VidCga;

var
  { the four banks from $B800: scanline n in bank n mod 4, 160 bytes a scanline }
  tdyB800: array[0..255] of Types.TTdyRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK0_SEG:$0000{$ENDIF};
  tdyBA00: array[0..255] of Types.TTdyRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK1_SEG:$0000{$ENDIF};
  tdyBC00: array[0..255] of Types.TTdyRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK2_SEG:$0000{$ENDIF};
  tdyBE00: array[0..255] of Types.TTdyRow {$IFNDEF FPC}absolute C_VIDEO.GFX_BANK3_SEG:$0000{$ENDIF};

procedure Start;
begin
end;

{ two pixels a byte, a set font bit in fg and a clear one in bg, each font row a scanline through the row segments }
procedure DrawGlyph(col, row, fg, bg, glyph: Byte);
var
  fontRow: Byte;
  bits: Byte;
  k: Byte;
  tandyPx: Byte;
  seg: Word;
begin
  for fontRow := 0 to 7 do begin
    bits := GameVars.gameFont^[glyph][fontRow];
    seg := GameVars.bankRowSeg[row * 8 + fontRow];
    for k := 0 to 3 do begin
      if (bits and ($80 shr (2 * k))) <> 0 then
        tandyPx := fg shl 4
      else
        tandyPx := bg shl 4;
      if (bits and ($40 shr (2 * k))) <> 0 then
        tandyPx := tandyPx or fg
      else
        tandyPx := tandyPx or bg;
      Mem[seg:col * 4 + k] := tandyPx;
    end;
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  row: Word;
  firstByteColumn: Word;
  byteCount: Word;
begin
  firstByteColumn := ulCol * 4;
  byteCount := (lrCol - ulCol + 1) * 4;
  for row := ulRow * 2 to lrRow * 2 + 1 do begin
    FillChar(tdyB800[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBA00[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBC00[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBE00[row][firstByteColumn], byteCount, 0);
  end;
end;

procedure ClearScreen;
begin
  FillChar(tdyB800, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBA00, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBC00, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBE00, SizeOf(Types.TTandyBank), 0);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GameVars.pageMain, col, row, attr, count, ch);
end;

{ two pixels of color in every byte }
procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  FillChar(cell, SizeOf(cell), (color and $0F) * $11);
end;

{ no palette registers }
procedure SetPalette(registerIndex, color: Byte);
begin
end;

procedure Install;
begin
  with GameVars.video do begin
    name := 'Tandy';
    colours := 16;
    hasPalette := False;
    keyed := False;
    cellShift := 2;
    screenShift := 2;
    maskShift := 0;
    CellFill := VidTdy.CellFill;
    biosMode := 9;
    ramVideoParas := 1024;
    Start := VidTdy.Start;
    FlushSpans := VidCga.FlushSpans;
    ShowPic := VidCga.ShowPic;
    DrawGlyph := VidTdy.DrawGlyph;
    ClearRect := VidTdy.ClearRect;
    ClearScreen := VidTdy.ClearScreen;
    WriteChar := VidTdy.WriteChar;
    ExpandChunk := PicTdy.ExpandChunk;
    MirrorFrame := PicTdy.MirrorFrame;
    RemapColour := PicTdy.RemapColour;
    RecolorFrame := PicTdy.RecolorFrame;
    PutPixelRow := PicTdy.PutPixelRow;
    InitRowTables := PicTdy.InitRowTables;
    SetPalette := VidTdy.SetPalette;
    { the 320 x 200 screen: no fine entries (VidVesa's) }
    fine := False;
  end;
end;

end.
