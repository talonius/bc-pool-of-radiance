{ Text-window borders, rectangle clearing and centered titles. Borders use the 8x8 symbol set. }
{$O+,F+}
{$I COMPILER.INC}
unit Border;

interface

uses Types;

procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);

{ Put the corner symbol (corner, as DrawBorder's) at (col, row) of the 40x25 grid. }
procedure PutCorner(col, row: ShortInt; corner: Byte);

{ Forget the corner at the map window's lower-right corner: the whole screen was cleared (TextRend.ClearScreen), so a
  later edge across that cell must not put one back. }
procedure ForgetJoin;

{ Clear the whole screen (TextRend.ClearScreen) and draw the frame round the full text window (C_MSG.TEXT_LEFT to
  TEXT_BOTTOM): a full-screen page's start, with no corner left on the frame from the windows drawn before it. }
procedure ClearToFrame;

implementation

uses TextRend, Sym8x8, C_MSG;
const
  BORDER_SYM_BASE = 276;
  { the 40x25 text grid }
  LAST_COL = 39;
  LAST_ROW = 24;
  { where the lower-right corner of the map window (1,1,15,15) meets the message window's top edge (#1172) }
  JOIN_COL = 16;
  JOIN_ROW = 16;

  { a border's corner is at (JOIN_COL, JOIN_ROW) and nothing has cleared it since (a typed constant, so it starts
    False) }
  joinCorner: Boolean = False;

{ Put the corner symbol (corner, as DrawBorder's) at (col, row) of the 40x25 grid. }
procedure PutCorner(col, row: ShortInt; corner: Byte);
begin
  Sym8x8.Put8x8Sym(col, row, corner * 3 + BORDER_SYM_BASE, False, False);
end;

procedure ForgetJoin;
begin
  joinCorner := False;
end;

procedure ClearToFrame;
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0);
end;

{ Draw a border one cell outside the requested text rectangle. Expand the coordinates to the border ring, then draw
  symbol BORDER_SYM_BASE + corner*3 at the four corners, +2 along the top and bottom edges and +1 down both sides.
  An edge across the map window's lower-right corner, (JOIN_COL, JOIN_ROW), leaves the corner there: the message
  window's top edge, drawn after the map window (the wilderness's windows, a message window opened alone), wiped it
  (#1172). }
procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);
var
  i: ShortInt;
  symBase: Word;
begin
  Dec(ulCol);
  Dec(ulRow);
  Inc(lrCol);
  Inc(lrRow);
  symBase := corner * 3 + BORDER_SYM_BASE;
  Sym8x8.Put8x8Sym(ulCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(ulCol, lrRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, lrRow, symBase + 0, False, False);
  for i := ulCol + 1 to lrCol - 1 do begin
    Sym8x8.Put8x8Sym(i, ulRow, symBase + 2, False, False);
    Sym8x8.Put8x8Sym(i, lrRow, symBase + 2, False, False);
  end;
  for i := ulRow + 1 to lrRow - 1 do begin
    Sym8x8.Put8x8Sym(ulCol, i, symBase + 1, False, False);
    Sym8x8.Put8x8Sym(lrCol, i, symBase + 1, False, False);
  end;
  if ((ulCol = JOIN_COL) or (lrCol = JOIN_COL)) and ((ulRow = JOIN_ROW) or (lrRow = JOIN_ROW)) then
    joinCorner := True
  else if joinCorner and
    ((((ulRow = JOIN_ROW) or (lrRow = JOIN_ROW)) and (ulCol < JOIN_COL) and (lrCol > JOIN_COL)) or
     (((ulCol = JOIN_COL) or (lrCol = JOIN_COL)) and (ulRow < JOIN_ROW) and (lrRow > JOIN_ROW))) then
    Border.PutCorner(JOIN_COL, JOIN_ROW, corner);
end;

{ Clear a character-cell rectangle to black: cut to the 40x25 grid first, so a rectangle partly off the screen clears
  what is on it, then TextRend.ClearRect (an empty one clears nothing). }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  if ulCol < 0 then ulCol := 0;
  if ulRow < 0 then ulRow := 0;
  if lrCol > LAST_COL then lrCol := LAST_COL;
  if lrRow > LAST_ROW then lrRow := LAST_ROW;
  if (ulCol <= JOIN_COL) and (lrCol >= JOIN_COL) and (ulRow <= JOIN_ROW) and (lrRow >= JOIN_ROW) then
    joinCorner := False;
  TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
end;

{ Clear the window, draw its border and center a nonempty title on the window's first text row (ulRow). The title is
  centred between ulCol and lrCol - 1, not lrCol: that is SSI's (ulCol + lrCol - Length(title)) div 2, so the titles
  sit where SSI put them (#977). }
procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);
begin
  Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
  Border.DrawBorder(ulCol, ulRow, lrCol, lrRow, corner);
  if Length(title) <> 0 then
    TextRend.DisplayCentered(ulCol, lrCol - 1, ulRow, color, title);
end;

end.
