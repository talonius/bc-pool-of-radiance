{ The VGA video driver: BIOS mode 13h, 320x200 at a byte a pixel, linear at $A000, one page. Pictures are a byte a pixel
  too (8 bytes a cell row), with transparency by colour key (Types.PIC_KEY), as Dark Queen of Krynn keeps its own; the
  art is 16-colour, shown through DAC entries 0..15. Resident, since its routines are the hot ones; GameBoot installs it
  when POOL.CFG names VGA (phase 6 of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidVga;

interface

{ Make this the video driver: fill GameVars.video. }
procedure Install;

implementation

uses Types, C_VIDEO, GameVars, DaxIo, PicVga{$IFDEF FPC}, Host{$ENDIF};

const
  { EGA's 16 colours as VGA DAC values (6 bits a component): the BIOS's own for entries 0..15 in mode 13h }
  EGA_RGB: array[0..15, 0..2] of Byte = (
    (0, 0, 0), (0, 0, 42), (0, 42, 0), (0, 42, 42), (42, 0, 0), (42, 0, 42), (42, 21, 0), (42, 42, 42),
    (21, 21, 21), (21, 21, 63), (21, 63, 21), (21, 63, 63), (63, 21, 21), (63, 21, 63), (63, 63, 21), (63, 63, 63));
  DAC_WRITE_INDEX = $3C8;
  DAC_DATA = $3C9;

var
  { the screen: mode 13h's memory at $A000, or the native build's copy of it, which Host shows }
{$IFDEF FPC}
  vgaMem: Host.TScreen absolute Host.screen;
{$ELSE}
  vgaMem: array[0..C_VIDEO.VGA_ROW_BYTES * 200 - 1] of Byte absolute C_VIDEO.VGA_VIDEO_SEG:0;
{$ENDIF}

procedure SetPalette(registerIndex, color: Byte); forward;

{ Natively, the palette the BIOS's mode 13h starts with: entries 0..15 EGA's colours (Host's DAC starts black) }
procedure Start;
{$IFDEF FPC}
var
  i: Byte;
begin
  for i := 0 to 15 do
    SetPalette(i, i);
end;
{$ELSE}
begin
end;
{$ENDIF}

{ a byte a pixel in the view buffer and on the screen: each dirty span is one Move }
procedure FlushSpans;
var
  row: Word;
begin
  for row := 0 to SizeOf(GameVars.spanActive) - 1 do
    if GameVars.spanActive[row] <> 0 then
      Move(GameVars.viewBuffer^.data[GameVars.spanFirstOfs[row]],
           vgaMem[GameVars.fbRowOfs[row + 8] + GameVars.spanScreenOfs[row] + 8],
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
      Move(data[srcOff], vgaMem[GameVars.fbRowOfs[row] + screenX * 8], rowBytes);
      Inc(srcOff, rowBytes);
    end;
  end;
end;

{ each font bit a pixel of fg, each clear bit a pixel of bg }
procedure DrawGlyph(col, row, fg, bg, glyph: Byte);
var
  dstOff: Word;
  r: Byte;
  k: Byte;
  bits: Byte;
begin
  for r := 0 to 7 do begin
    dstOff := GameVars.fbRowOfs[row * 8 + r] + col * 8;
    bits := GameVars.gameFont^[glyph][r];
    for k := 0 to 7 do begin
      if (bits and ($80 shr k)) <> 0 then
        vgaMem[dstOff + k] := fg
      else
        vgaMem[dstOff + k] := bg;
    end;
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  y: Word;
begin
  for y := ulRow * 8 to lrRow * 8 + 7 do
    FillChar(vgaMem[GameVars.fbRowOfs[y] + ulCol * 8], (lrCol - ulCol + 1) * 8, 0);
end;

procedure ClearScreen;
begin
  FillChar(vgaMem, SizeOf(vgaMem), 0);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GameVars.pageMain, col, row, attr, count, ch);
end;

{ the 16 colours are DAC entries 0..15: registerIndex's entry takes color's RGB }
procedure SetPalette(registerIndex, color: Byte);
begin
{$IFDEF FPC}
  Move(EGA_RGB[color and $0F], Host.dac[registerIndex], 3);
{$ELSE}
  Port[DAC_WRITE_INDEX] := registerIndex;
  Port[DAC_DATA] := EGA_RGB[color and $0F, 0];
  Port[DAC_DATA] := EGA_RGB[color and $0F, 1];
  Port[DAC_DATA] := EGA_RGB[color and $0F, 2];
{$ENDIF}
end;

{ a cell row in one colour: 8 bytes of it }
procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  FillChar(cell, SizeOf(cell), color);
end;

procedure Install;
begin
  with GameVars.video do begin
    name := 'VGA';
    colours := 16;
    hasPalette := True;
    keyed := True;
    cellShift := 3;
    screenShift := 3;
    { the mask is kept a bit a pixel, a byte a cell row (EGA's form), though keyed drawing does not read it }
    maskShift := 3;
    CellFill := VidVga.CellFill;
    biosMode := $13;
    ramVideoParas := 0;
    Start := VidVga.Start;
    FlushSpans := VidVga.FlushSpans;
    ShowPic := VidVga.ShowPic;
    DrawGlyph := VidVga.DrawGlyph;
    ClearRect := VidVga.ClearRect;
    ClearScreen := VidVga.ClearScreen;
    WriteChar := VidVga.WriteChar;
    ExpandChunk := PicVga.ExpandChunk;
    MirrorFrame := PicVga.MirrorFrame;
    RemapColour := PicVga.RemapColour;
    RecolorFrame := PicVga.RecolorFrame;
    PutPixelRow := PicVga.PutPixelRow;
    InitRowTables := PicVga.InitRowTables;
    SetPalette := VidVga.SetPalette;
    { the 320 x 200 screen: no fine entries (VidVesa's) }
    fine := False;
  end;
end;

end.
