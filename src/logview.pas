{ Displays the combat log one page at a time (#841), preserving each message's
  colors while wrapping it to the page width. This overlaid unit is loaded only
  when the page opens. The caller supplies the title and redraws its own screen
  afterward. }
{$O+,F+}
{$I COMPILER.INC}
unit LogView;

interface

uses Types;

{ Shows the log under title until Exit or Escape, initially positioned at the
  newest entry. Arrow keys scroll by line, Page Up/Down by page, and Home/End
  jump to the beginning or end. }
procedure ShowLog(title: Types.TStr40);

implementation

uses Crt, C_KEYS, GameVars, TextRend, Border, MenuCore, CbtLog, LogWrap, UiColor;

const
  { one framed box from TOP_ROW to BOTTOM_ROW, as the Settings screen's: the title on TOP_ROW, a blank row, then the
    lines from FIRST_ROW, each from LEFT_COL to RIGHT_COL }
  FRAME_LEFT = 1;
  FRAME_RIGHT = 38;
  TOP_ROW = 1;
  BOTTOM_ROW = 22;
  FIRST_ROW = TOP_ROW + 2;
  LEFT_COL = 2;
  RIGHT_COL = FRAME_RIGHT;
  WIDTH = RIGHT_COL - LEFT_COL + 1;
  PAGE_ROWS = BOTTOM_ROW - FIRST_ROW + 1;
  TITLE_COLOR = White;

var
  { the lines each entry wraps to, by entry (CbtLog.Count's, the ring's MAX_ENTRIES and the entry still being built);
    the lines in all; and the line on the page's first row }
  lineCounts: array[1..CbtLog.MAX_ENTRIES + 1] of Byte;
  total: Integer;
  top: Integer;

{ Draw a wrapped line at row, each run in its colour. }
procedure DrawLine(row: Byte; line: LogWrap.TWrapLine);
var
  i: Byte;
  col: Byte;
  color: Byte;
  run: Types.TStr40;
begin
  col := LEFT_COL;
  color := LightGreen;
  run := '';
  i := 1;
  while i <= Length(line) do begin
    if line[i] = CbtLog.COLOR_MARK then begin
      if run <> '' then begin
        TextRend.DisplayString(col, row, color, run);
        Inc(col, Length(run));
        run := '';
      end;
      if i < Length(line) then
        color := Ord(line[i + 1]);
      Inc(i, 2);
    end else begin
      run := run + line[i];
      Inc(i);
    end;
  end;
  if run <> '' then
    TextRend.DisplayString(col, row, color, run);
end;

{ Clear the page's rows and draw the lines from top. }
procedure DrawPage;
var
  n: Byte;
  first: Integer;
  i: Byte;
  count: Byte;
  entry: string;
  lines: LogWrap.TWrapLines;
begin
  Border.ClearBox(LEFT_COL, FIRST_ROW, RIGHT_COL, BOTTOM_ROW);
  { first: the line number of entry n's first line }
  first := 1;
  for n := 1 to CbtLog.Count do begin
    if (first + lineCounts[n] > top) and (first < top + PAGE_ROWS) then begin
      CbtLog.Entry(n, entry);
      count := LogWrap.WrapEntry(entry, WIDTH, lines);
      for i := 1 to count do
        if (first + i - 1 >= top) and (first + i - 1 < top + PAGE_ROWS) then
          LogView.DrawLine(FIRST_ROW + first + i - 1 - top, lines[i]);
    end;
    Inc(first, lineCounts[n]);
  end;
end;

{ Scroll so line t is on the page's first row, kept within the log, and redraw when that moves it. }
procedure ScrollTo(t: Integer);
begin
  if t > total - PAGE_ROWS + 1 then
    t := total - PAGE_ROWS + 1;
  if t < 1 then
    t := 1;
  if t <> top then begin
    top := t;
    LogView.DrawPage;
  end;
end;

procedure ShowLog(title: Types.TStr40);
var
  n: Byte;
  entry: string;
  lines: LogWrap.TWrapLines;
  ch: Char;
  ext: Boolean;
  savedChoice: Byte;
begin
  savedChoice := GameVars.horizChoice;
  total := 0;
  for n := 1 to CbtLog.Count do begin
    CbtLog.Entry(n, entry);
    lineCounts[n] := LogWrap.WrapEntry(entry, WIDTH, lines);
    Inc(total, lineCounts[n]);
  end;
  Border.ClearBox(0, 0, 39, 24);
  Border.DrawBorder(FRAME_LEFT, TOP_ROW, FRAME_RIGHT, BOTTOM_ROW, 0);
  TextRend.DisplayCentered(FRAME_LEFT, FRAME_RIGHT, TOP_ROW, TITLE_COLOR, title);
  top := total - PAGE_ROWS + 1;
  if top < 1 then
    top := 1;
  LogView.DrawPage;
  GameVars.horizChoice := 1;
  repeat
    ch := MenuCore.MenuHorizontal('Messages: ', 'Up Down Top eNd Exit', promptColor, optionColor, commandColor, True,
                                  False, ext);
    if ext then
      case ch of
        C_KEYS.UP: LogView.ScrollTo(top - 1);
        C_KEYS.DOWN: LogView.ScrollTo(top + 1);
        C_KEYS.PAGE_UP: LogView.ScrollTo(top - PAGE_ROWS);
        C_KEYS.PAGE_DOWN: LogView.ScrollTo(top + PAGE_ROWS);
        C_KEYS.HOME: LogView.ScrollTo(1);
        C_KEYS.END_KEY: LogView.ScrollTo(total);
      end
    else
      case ch of
        'U': LogView.ScrollTo(top - 1);
        'D': LogView.ScrollTo(top + 1);
        'T': LogView.ScrollTo(1);
        'N': LogView.ScrollTo(total);
      end;
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  GameVars.horizChoice := savedChoice;
end;

end.
