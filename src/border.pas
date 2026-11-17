{ Text-window borders, rectangle clearing and centered titles, and frames (docs/ui-design.md, The screen): a border
  split into sections by dividers, a title in its top edge, and a scroll bar over a section's right edge
  (docs/screen-mocks/scrollbar.txt). Borders use the 8x8 symbol set. }
{$O+,F+}
{$I COMPILER.INC}
unit Border;

interface

uses Types;

const
  { the most dividers a frame takes, so the most sections are one more }
  MAX_DIVIDERS = 4;

type
  { what a section's scroll bar last drew, so that the next draw changes only the cells that differ }
  TFrameBar = record
    drawn: Boolean;
    first: Integer;
    size: Integer;
  end;
  { A frame: a border whose corners are the cells (left, top) and (right, bottom), split across by dividers on the rows
    in divRow (ascending), each with a corner box at both its ends (a joint); a title in its top edge; and a scroll bar
    over the right edge of any section. Section 0 is the rows under the top edge, down to the first divider; section n
    is under divider n. InitFrame sets it up, AddDivider divides it, DrawFrame draws it and FrameBar puts a bar on a
    section. }
  TFrame = record
    left: ShortInt;
    top: ShortInt;
    right: ShortInt;
    bottom: ShortInt;
    { the border set, as DrawBorder's corner }
    corner: Byte;
    dividers: Byte;
    divRow: array[1..MAX_DIVIDERS] of ShortInt;
    title: Types.TStr40;
    bar: array[0..MAX_DIVIDERS] of TFrameBar;
  end;
  PFrame = ^TFrame;

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

{ A frame with its corners on (left, top) and (right, bottom), border set corner, title in its top edge ('' for none),
  no dividers and no bars. Nothing is drawn. }
procedure InitFrame(var f: TFrame; left, top, right, bottom: ShortInt; corner: Byte; title: Types.TStr40);

{ Divide f across on row: a divider with a joint at each end. Dividers are added top to bottom; one that is not below
  the last (or the top edge), not above the bottom edge, or past MAX_DIVIDERS is ignored. }
procedure AddDivider(var f: TFrame; row: ShortInt);

{ Draw f's border: each edge, corner, divider and joint once, and the title in the top edge (TitleStart) in
  UiColor.titleColor. Nothing inside is cleared. The bars are forgotten, as the edges under them are drawn plain:
  whatever draws the frame draws its bars after it (FrameBar). }
procedure DrawFrame(var f: TFrame);

{ The rows inside section n of f: from firstRow to lastRow. A section past f's dividers gives firstRow > lastRow. }
procedure SectionRows(var f: TFrame; n: Byte; var firstRow, lastRow: ShortInt);

{ Show where a list stands on the right edge of section n of f, between its corners or joints: a scroll bar while the
  list (count entries, shown at once, the first shown being top) is longer than the section, the plain edge while it
  fits. Only the cells that differ from the last draw are drawn. The arrows take the bar's first and last rows and the
  knob (ScrollThumb) the rows between, so a section under 3 rows has no bar. Without the scroll bar's cells
  (Sym8x8.HasScrollBar: the merged 8X8D archive could not be built) the bar is drawn in text. }
procedure FrameBar(var f: TFrame; n: Byte; count, shown, top: Integer);

{ The column of a title's left corner box, centred between left and right: a title of len characters takes len + 4
  cells, a corner box, a space, the title, a space and a corner box (docs/screen-mocks/load-save-game.txt). }
function TitleStart(left, right: ShortInt; len: Byte): ShortInt;

{ Where a scroll bar's knob goes on a track of track rows, for a list of count entries of which shown are shown at once,
  the first shown being top (zero-based): first, the knob's first track row from 0, and size, its length in rows. The
  knob's share of the track is the share of the list shown, rounded to the nearest row, at least one and, while the list
  is longer than its box, at least one short of the track; it touches the track's top only at the list's start and its
  bottom only at its end (docs/screen-mocks/scrollbar.txt). The track is apart from the list because the edge bar's
  arrows take two of its rows and an entry may be several rows. A list that fits fills the track. }
procedure ScrollThumb(count, shown, track, top: Integer; var first, size: Integer);

{ The scroll bar piece (BarArt.BAR_TRACK, BAR_KNOB_TOP and so on) on track row r of a knob from row first, size rows
  long: the track off the knob; on it the one-cell knob, or the top, the bottom, the grip on the middle cell (size div
  2, of a knob of 3 cells or more) or a middle cell. }
function BarPiece(first, size, r: Integer): Byte;

implementation

uses Crt, TextRend, Sym8x8, C_MSG, BarArt, UiColor;
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

procedure InitFrame(var f: TFrame; left, top, right, bottom: ShortInt; corner: Byte; title: Types.TStr40);
begin
  FillChar(f, SizeOf(f), 0);
  f.left := left;
  f.top := top;
  f.right := right;
  f.bottom := bottom;
  f.corner := corner;
  f.title := title;
end;

procedure AddDivider(var f: TFrame; row: ShortInt);
var
  above: ShortInt;
begin
  if f.dividers = 0 then
    above := f.top
  else
    above := f.divRow[f.dividers];
  if (f.dividers < MAX_DIVIDERS) and (row > above) and (row < f.bottom) then begin
    Inc(f.dividers);
    f.divRow[f.dividers] := row;
  end;
end;

function TitleStart(left, right: ShortInt; len: Byte): ShortInt;
begin
  TitleStart := left + (right - left + 1 - (len + 4)) div 2;
end;

procedure SectionRows(var f: TFrame; n: Byte; var firstRow, lastRow: ShortInt);
begin
  if n > f.dividers then begin
    firstRow := 1;
    lastRow := 0;
  end else begin
    if n = 0 then
      firstRow := f.top + 1
    else
      firstRow := f.divRow[n] + 1;
    if n = f.dividers then
      lastRow := f.bottom - 1
    else
      lastRow := f.divRow[n + 1] - 1;
  end;
end;

procedure DrawFrame(var f: TFrame);
var
  symBase: Word;
  i: ShortInt;
  d: Byte;
  edge: Boolean;
  t: Types.TStr40;
  tStart: ShortInt;
  tEnd: ShortInt;
begin
  symBase := f.corner * 3 + BORDER_SYM_BASE;
  { the title: no longer than leaves an edge cell between each of its corner boxes and the frame's corner (the frame's
    width less its two corners, two edge cells, two corner boxes and two spaces) }
  t := f.title;
  if Length(t) > f.right - f.left - 7 then
    t[0] := Chr(f.right - f.left - 7);
  tStart := 0;
  tEnd := -1;
  if Length(t) > 0 then begin
    tStart := Border.TitleStart(f.left, f.right, Length(t));
    tEnd := tStart + Length(t) + 3;
    Border.PutCorner(tStart, f.top, f.corner);
    TextRend.DisplayString(tStart + 1, f.top, titleColor, ' ' + t + ' ');
    Border.PutCorner(tEnd, f.top, f.corner);
  end;
  { the top and bottom edges and the dividers, their corners and joints }
  for i := f.left + 1 to f.right - 1 do begin
    if (i < tStart) or (i > tEnd) then
      Sym8x8.Put8x8Sym(i, f.top, symBase + 2, False, False);
    Sym8x8.Put8x8Sym(i, f.bottom, symBase + 2, False, False);
    for d := 1 to f.dividers do
      Sym8x8.Put8x8Sym(i, f.divRow[d], symBase + 2, False, False);
  end;
  Border.PutCorner(f.left, f.top, f.corner);
  Border.PutCorner(f.right, f.top, f.corner);
  Border.PutCorner(f.left, f.bottom, f.corner);
  Border.PutCorner(f.right, f.bottom, f.corner);
  for d := 1 to f.dividers do begin
    Border.PutCorner(f.left, f.divRow[d], f.corner);
    Border.PutCorner(f.right, f.divRow[d], f.corner);
  end;
  { the sides, between the corners and joints }
  for i := f.top + 1 to f.bottom - 1 do begin
    edge := True;
    for d := 1 to f.dividers do
      if f.divRow[d] = i then
        edge := False;
    if edge then begin
      Sym8x8.Put8x8Sym(f.left, i, symBase + 1, False, False);
      Sym8x8.Put8x8Sym(f.right, i, symBase + 1, False, False);
    end;
  end;
  for d := 0 to MAX_DIVIDERS do
    f.bar[d].drawn := False;
end;

procedure ScrollThumb(count, shown, track, top: Integer; var first, size: Integer);
var
  room: Integer;
begin
  if (track < 1) or (count <= shown) then begin
    first := 0;
    size := track;
  end else begin
    size := Integer((2 * LongInt(track) * shown + count) div (2 * LongInt(count)));
    if (size >= track) and (track > 1) then
      size := track - 1;
    if size < 1 then
      size := 1;
    if top < 0 then
      top := 0;
    if top > count - shown then
      top := count - shown;
    room := track - size;
    { rounded to the nearest row, but at the top only at the list's start and at the bottom only at its end }
    first := Integer((LongInt(top) * room + (count - shown) div 2) div (count - shown));
    if (first = 0) and (top > 0) and (room > 1) then
      first := 1;
    if (first = room) and (top < count - shown) and (first > 1) then
      Dec(first);
  end;
end;

function BarPiece(first, size, r: Integer): Byte;
begin
  if (r < first) or (r >= first + size) then
    BarPiece := BarArt.BAR_TRACK
  else if size = 1 then
    BarPiece := BarArt.BAR_KNOB_ONE
  else if (size > 2) and (r - first = size div 2) then
    BarPiece := BarArt.BAR_GRIP
  else if r = first then
    BarPiece := BarArt.BAR_KNOB_TOP
  else if r = first + size - 1 then
    BarPiece := BarArt.BAR_KNOB_BOTTOM
  else
    BarPiece := BarArt.BAR_KNOB_MIDDLE;
end;

{ Draw scroll bar piece (BarArt.BAR_UP and so on) at (col, row): its cell, or, without the cells, a character: the
  arrows as ^ and V in white, the knob as * in white, the track as - in dark gray. }
procedure PutPiece(col, row: ShortInt; piece: Byte);
begin
  if Sym8x8.HasScrollBar then
    Sym8x8.Put8x8Sym(col, row, Sym8x8.BAR_FIRST + piece, False, False)
  else
    case piece of
      BarArt.BAR_UP: TextRend.DisplayString(col, row, White, '^');
      BarArt.BAR_DOWN: TextRend.DisplayString(col, row, White, 'V');
      BarArt.BAR_TRACK: TextRend.DisplayString(col, row, DarkGray, '-');
    else
      TextRend.DisplayString(col, row, White, '*');
    end;
end;

procedure FrameBar(var f: TFrame; n: Byte; count, shown, top: Integer);
var
  r0: ShortInt;
  r1: ShortInt;
  r: ShortInt;
  track: Integer;
  first: Integer;
  size: Integer;
  piece: Byte;
begin
  Border.SectionRows(f, n, r0, r1);
  track := r1 - r0 - 1;
  if track < 1 then
    Exit;
  if count <= shown then begin
    { the list fits: the plain edge back where the bar was }
    if f.bar[n].drawn then
      for r := r0 to r1 do
        Sym8x8.Put8x8Sym(f.right, r, f.corner * 3 + BORDER_SYM_BASE + 1, False, False);
    f.bar[n].drawn := False;
  end else begin
    Border.ScrollThumb(count, shown, track, top, first, size);
    if not f.bar[n].drawn then begin
      PutPiece(f.right, r0, BarArt.BAR_UP);
      PutPiece(f.right, r1, BarArt.BAR_DOWN);
    end;
    for r := 0 to track - 1 do begin
      piece := Border.BarPiece(first, size, r);
      if not f.bar[n].drawn or (piece <> Border.BarPiece(f.bar[n].first, f.bar[n].size, r)) then
        PutPiece(f.right, r0 + 1 + r, piece);
    end;
    f.bar[n].drawn := True;
    f.bar[n].first := first;
    f.bar[n].size := size;
  end;
end;

end.
