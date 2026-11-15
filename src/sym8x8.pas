{ Load and draw 8x8 symbol sets. }
{$O+,F+}
{$I COMPILER.INC}
unit Sym8x8;

interface

const
  { the scroll bar's cells (BarArt, docs/screen-mocks/scrollbar.txt): symbol BAR_FIRST + BarArt.BAR_UP and so on, in
    set 5 }
  BAR_FIRST = 287;
  BAR_LAST = 294;

{ Loads one 8x8 symbol set and builds a transparency mask for hot pink. Ignore
  invalid destination slots. A missing required set reports the DAX record and
  exits the game. }
procedure Load8x8Set(fileID, setId: Byte);

{ Draws a global symbol ID from the loaded 8x8 sets. Combat composites it into
  the view buffer; other screens draw it directly. Missing or malformed sets
  draw nothing. An invalid symbol ID reports an error and exits. }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);

{ Load the scroll bar's cells (the 8X8D archive's C_DATA.SCROLL_BAR_BLOCK, which DataBld adds) into set 5, freeing any
  loaded before. A missing block is no error: the per-disk archives, read when the merged one could not be built, have
  none, and the set stays nil (HasScrollBar). Run after DataBld.BuildDataFiles, which makes the block. }
procedure LoadScrollBar;

{ True when the scroll bar's cells are loaded, so BAR_FIRST to BAR_LAST draw. }
function HasScrollBar: Boolean;

implementation

uses Crt, GameDefs, GameVars, Blit, GameIo, StrUtil, C_DATA;

const
  BAR_SET = 5;

procedure Load8x8Set(fileID, setId: Byte);
var
  s1: String[1];
begin
  if setId in [0..4] then begin
    Str(GameVars.diskIndex, s1);
    Blit.LoadPic('8x8d' + s1, fileID, True, LightMagenta, GameVars.symbolSetPtrs[setId]);
    if GameVars.symbolSetPtrs[setId] = nil then begin
      GameIo.FatalError('Unable to load 8x8D' + s1 + '-' + StrUtil.NumStr(fileID));
    end;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);
var
  setIdx: Byte;
begin
  case symbol of
    1..45: setIdx := 0;
    46..115: setIdx := 1;
    116..185: setIdx := 2;
    186..255: setIdx := 3;
    256..286: setIdx := 4;
    BAR_FIRST..BAR_LAST: setIdx := BAR_SET;
    0, BAR_LAST + 1..65535: begin
      GameIo.FatalError('Bad symbol number in Put8x8Symbol.');
    end;
  end;
  if GameVars.symbolSetPtrs[setIdx] <> nil then begin
    Dec(symbol, GameDefs.symSetFirst[setIdx]);
    with GameVars.symbolSetPtrs[setIdx]^ do
      if (height <> 8) or (width <> 1) or (symbol >= count) then Exit;
    if inCombat then
      Blit.BlitTileCell(col, row, symbol, Ord(other), GameVars.symbolSetPtrs[setIdx], GameVars.viewBuffer)
    else begin
      with GameVars.symbolSetPtrs[setIdx]^ do
        Move(data[symbol * imgSize], GameVars.sym8x8Buf^.data, imgSize);
      Blit.ShowPic(col, row, GameVars.sym8x8Buf);
    end;
  end;
end;

procedure LoadScrollBar;
var
  s1: String[1];
begin
  if GameVars.symbolSetPtrs[BAR_SET] <> nil then
    Blit.FreePic(GameVars.symbolSetPtrs[BAR_SET]);
  Str(GameVars.diskIndex, s1);
  Blit.LoadPic('8x8d' + s1, C_DATA.SCROLL_BAR_BLOCK, True, LightMagenta, GameVars.symbolSetPtrs[BAR_SET]);
  { a set of another shape draws nothing (Put8x8Sym); it is not kept }
  if GameVars.symbolSetPtrs[BAR_SET] <> nil then
    with GameVars.symbolSetPtrs[BAR_SET]^ do
      if (height <> 8) or (width <> 1) or (count < BAR_LAST - BAR_FIRST + 1) then
        Blit.FreePic(GameVars.symbolSetPtrs[BAR_SET]);
end;

function HasScrollBar: Boolean;
begin
  HasScrollBar := GameVars.symbolSetPtrs[BAR_SET] <> nil;
end;

end.
