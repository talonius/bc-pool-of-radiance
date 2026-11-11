{ Game-font text rendering, the message window, bottom-line input, BIOS-tick and centisecond timing, and screen and
  rectangle clearing through the video driver. }
{$O+,F+}
{$I COMPILER.INC}
unit TextRend;

interface

uses Types;

var
  { DisplayMessageWindow's text that runs past its window's last row waits on the text delay (PauseOnly) before the rest
    is shown, not for a key: the full-width combat view's two message lines (CbtMap.SetLayout, #1211) }
  pageByDelay: Boolean;
  { how many times the game has waited over its text, by PauseOnly or DisplayAndPause: CharDisp waits before writing
    over the full-width combat view's two message lines only when no wait came since they were written (#1211) }
  pauseCount: Word;

procedure LoadGameFont;

{ Draws count copies of a game-font glyph from a cell, one column apart.
  @param(col The first copy's column.)
  @param(row The row.)
  @param(fg The ink color, for the glyph's set pixels.)
  @param(bg The paper color, for its clear pixels: Black, or the highlight color with fg Black for inverse video.)
  @param(count The number of copies.)
  @param(ch The character, or the glyph index when isAscii is 0.)
  @param(isAscii Nonzero to map ch to a glyph (UpCase, mod 64).) }
procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);

procedure PrintSpaces(col, row, color, count: Byte);

{ Blank the bottom text line, row 24, where menus and prompts go. Resident, so combat clearing it loads no overlay. }
procedure ClearBottomLine;

procedure DisplayString(col, row, color: Byte; source: string);

{ Writes a string from a cell in ink on paper, one character per cell; characters off the screen are not drawn.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The ink color.)
  @param(bg The paper color: Black, or the highlight color with fg Black for inverse video.)
  @param(source The text.) }
procedure DisplayStringOn(col, row, fg, bg: Byte; source: string);

{ Draw s centred between columns left and right (both included) on row, cut to that width first. }
procedure DisplayCentered(left, right, row, color: Byte; s: string);

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);

{ DisplayMessageWindow in the message window, the screen's lower right (C_MSG.TEXT_LEFT, MESSAGE_TOP to TEXT_RIGHT,
  TEXT_BOTTOM). }
procedure ShowMessage(color: Byte; clearFirst: Boolean; s: string);

function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;

function ReadNumber(query: Types.TStr40; color: Byte): Word;

{ Show msg on the bottom line and wait for a key; an extended key is read whole (GameIo.ReadAnyKey). }
procedure DisplayAndPause(color: Byte; msg: Types.TStr40);

{ The BIOS tick count (18.2 a second since midnight), read until two reads agree, so a timer tick between the two words
  of a read is not taken. Natively it first waits a millisecond through Crt.Delay, which runs Host.Service: a loop that
  waits by watching the clock (the ending's animations, #1095) presents its frames and keeps the window answering, as
  one that waits through Delay or ReadKey does, and gives the processor back. }
function TickCount: LongInt;

function GetTicks: LongInt;

procedure ClearScreen;

procedure PrintAndPause(msg: Types.TStr40; color: Byte);

{ Crt.Delay for the text delay: GameVars.gameDelay * 225 ms. In the demo (#1109) a key cuts it short (PauseTicks). }
procedure PauseOnly;

{ Wait hundredths hundredths of a second. In the demo (#1109) a key ends the wait at once, and ends the demo
  (GameIo.DemoEnding); the key is left unread. }
procedure PauseTicks(hundredths: LongInt);

{ Wait for seconds or a keypress, whichever comes first. The key is left unread. }
procedure DelayOrKey(seconds: Word);

{ Show msg in color on the bottom line for two seconds or until a key, which is read, then clear the line: a refusal
  that needs no answer, such as the party menu's for Dual Class (#879). }
procedure FlashBottomLine(color: Byte; msg: Types.TStr40);

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);

implementation

uses GameVars, DaxIo, Crt, Dos, GameIo, C_KEYS, C_MSG, Border{$IFDEF FPC}, Host{$ENDIF};

{$IFDEF FPC}
{ the native build's count of the same ticks }
function biosTicks: LongInt;
begin
  biosTicks := Host.BiosTicks;
end;
{$ELSE}
var
  { BIOS timer ticks since midnight }
  biosTicks: LongInt absolute $0040:$006C;
{$ENDIF}

{ Load font block 201 from 8X8D1.DAX, copy it into gameFont (no more than gameFont holds) and free the loader's buffer.
  Nothing is copied if the block cannot be loaded. }
procedure LoadGameFont;
var
  { the unpacked block's size, which is also the buffer's }
  size: Word;
  dataPtr: Types.PByteArr;
  n: Word;
begin
  DaxIo.LoadDax('8X8d1', '.dax', 201, size, dataPtr);
  if size = 0 then Exit;
  n := size;
  if n > SizeOf(Types.TFontArr) then
    n := SizeOf(Types.TFontArr);
  Move(dataPtr^, GameVars.gameFont^, n);
  FreeMem(dataPtr, size);
end;

{ Draw count copies of a game-font glyph at character coordinates, advancing one column per copy, its set pixels in fg
  and its clear pixels in bg. isAscii <> 0 maps ch through UpCase mod 64; otherwise ch is the glyph index. Ignore an
  out-of-range starting position or an unloaded font; later copies are not range-checked. A glyph index past the font
  draws nothing. The video driver draws each copy (GameVars.video.DrawGlyph). }
procedure RenderChar(col, row, fg, bg, count, ch, isAscii: Byte);
var
  i: Byte;
  charIdx: Byte;
begin
  if (col > 39) or (row > 24) or (GameVars.gameFont = nil) then Exit;
  if isAscii <> 0 then
    charIdx := Ord(UpCase(Chr(ch))) mod 64
  else begin
    if ch >= SizeOf(Types.TFontArr) div SizeOf(GameVars.gameFont^[0]) then Exit;
    charIdx := ch;
  end;
  for i := 1 to count do begin
    GameVars.video.DrawGlyph(col, row, fg, bg, charIdx);
    Inc(col);
  end;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

procedure ShowMessage(color: Byte; clearFirst: Boolean; s: string);
begin
  TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, color,
                                clearFirst, s);
end;

procedure DisplayCentered(left, right, row, color: Byte; s: string);
var
  width: Byte;
begin
  width := right - left + 1;
  if Length(s) > width then
    s[0] := Chr(width);
  TextRend.DisplayString(left + (width - Length(s)) div 2, row, color, s);
end;

{ Draw count spaces from (col, row); an off-screen start is ignored. }
procedure PrintSpaces(col, row, color, count: Byte);
begin
  if (col > 39) or (row > 24) then Exit;
  TextRend.RenderChar(col, row, color, Black, count, 32, 1);
end;

{ Draw a string in the game font at the requested column, row and color, on black; nothing is drawn off the screen. }
procedure DisplayString(col, row, color: Byte; source: string);
begin
  TextRend.DisplayStringOn(col, row, color, Black, source);
end;

procedure DisplayStringOn(col, row, fg, bg: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  if (col > 39) or (row > 24) then Exit;
  n := Length(source);
  for i := 1 to n do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1);
    Inc(col);
  end;
end;

{ Print text with word wrapping and paging inside the requested window: text past its last row waits for a key, or on
  the text delay while pageByDelay is set, and goes on from its top row. Skip leading break characters, scan each word
  and include trailing punctuation before deciding where to wrap. }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, color: Byte; clearFirst: Boolean; source: string);
const
  { Word-wrap punctuation; space is tested separately }
  breakChars: Types.TBrkSet = ['!', ',', '-', '.', ':', ';', '?'];
var
  { Integers, so idx can step past a 255-character source (a Byte wrapped to 0 and reprinted forever, #729) }
  len: Integer;
  width: Byte;
  idx: Integer;
  lineEnd: Integer;

  { Flush source[idx..lineEnd] at the cursor, advancing idx/curCol, stopping at lrCol; per-char Delay when slow text is
    on. }
  procedure PrintCharInWindow;
  begin
    while (idx <= lineEnd) and (GameVars.curCol <= lrCol) do begin
      TextRend.RenderChar(GameVars.curCol, GameVars.curRow, color, Black, 1, Ord(source[idx]), 1);
      if GameVars.msgDelayFlag <> 0 then Delay(GameVars.gameDelay * 10);
      Inc(idx);
      Inc(GameVars.curCol);
    end;
  end;

  { Skip the spaces a line break consumed. }
  procedure FindNewIndex;
  begin
    while (idx < len) and (source[idx] = ' ') do Inc(idx);
  end;

begin
  if (ulCol > lrCol) or (ulRow > lrRow) or (lrCol > 39) or (lrRow > 24) then Exit;
  if (GameVars.curCol < ulCol) or (GameVars.curCol > lrCol) or (GameVars.curRow < ulRow) or
      (GameVars.curRow > lrRow) then begin
    GameVars.curCol := ulCol;
    GameVars.curRow := ulRow;
  end;
  if clearFirst then begin
    TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
    GameVars.curCol := ulCol;
    GameVars.curRow := ulRow;
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    lineEnd := idx;
    while (lineEnd < len) and (source[lineEnd] in breakChars) do
      Inc(lineEnd);
    while (lineEnd < len) and not (source[lineEnd] in breakChars) and (source[lineEnd] <> ' ') do
      Inc(lineEnd);
    if source[lineEnd] <> ' ' then
      while (lineEnd + 1 < len) and (source[lineEnd + 1] in breakChars) do
        Inc(lineEnd);
    { a word wider than the window is split: what fits on this row now, the rest carried on to the next }
    if (GameVars.curCol <= lrCol) and (lineEnd - idx + Ord(source[lineEnd] <> ' ') > width) then
      lineEnd := idx + lrCol - GameVars.curCol;
    if lineEnd - idx + GameVars.curCol > lrCol then begin
      { the word fits and only its trailing space hangs over the edge: print the word, then wrap }
      if (lineEnd - idx + GameVars.curCol = lrCol + 1) and (source[lineEnd] = ' ') then begin
        Dec(lineEnd);
        PrintCharInWindow;
      end;
      GameVars.curCol := ulCol;
      Inc(GameVars.curRow);
      FindNewIndex;
      { FindNewIndex stops at len, so text is still waiting when idx < len or source[len] is not a space; a last
        one-character word waits too }
      if (GameVars.curRow > lrRow) and ((idx < len) or (source[idx] <> ' ')) then begin
        GameVars.curCol := ulCol;
        GameVars.curRow := ulRow;
        if pageByDelay then
          TextRend.PauseOnly
        else
          TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
        TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
        PrintCharInWindow;
      end else if GameVars.curRow > lrRow then
        { only a trailing space is left: nothing to print below the window }
        Exit;
    end else
      PrintCharInWindow;
  until idx > len;
  if GameVars.curCol > lrCol then begin
    GameVars.curCol := ulCol;
    Inc(GameVars.curRow);
  end;
end;

{ Prompt with query on the bottom row, then edit a line of up to maxLen chars: printable keys ' '..'z' append + echo in
  white (game font), backspace trims, Return/Escape ends (Escape does not discard the input); the result is uppercased.
  The first character goes right after the query: SSI moved the column before drawing, leaving a gap and drawing a 40th
  character past the screen (#735). }
function ReadString(query: Types.TStr40; color, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  reply: string;
  key: Char;
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, color, query);
  col := Length(query);
  reply := '';
  repeat
    { an extended key (an arrow, Delete) types nothing }
    key := GameIo.ReadAnyKey;
    case key of
      ' '..'z':
        if Length(reply) < maxLen then begin
          reply := reply + key;
          TextRend.DisplayString(col, 24, White, key);
          Inc(col);
        end;
      C_KEYS.BACKSPACE:
        if Length(reply) > 0 then begin
          reply := Copy(reply, 1, Length(reply) - 1);
          Dec(col);
          TextRend.PrintSpaces(col, 24, Black, 1);
        end;
    end;
  until (key = C_KEYS.ENTER) or (key = C_KEYS.ESCAPE);
  TextRend.ClearBottomLine;
  for col := 1 to Length(reply) do
    reply[col] := UpCase(reply[col]);
  ReadString := reply;
end;

{ Prompt for up to six characters until they parse as an integer in 0..65535, the range of the Word result. }
function ReadNumber(query: Types.TStr40; color: Byte): Word;
var
  num: LongInt;
  reply: Types.TStr40;
  code: Integer;
begin
  repeat
    reply := TextRend.ReadString(query, color, 6);
    Val(reply, num, code);
    if code = 0 then
      if (num > 65535) or (num < 0) then code := 1;
  until code = 0;
  ReadNumber := num;
end;

{ Clear the bottom row, print a message in the requested color and wait for a key. }
procedure DisplayAndPause(color: Byte; msg: Types.TStr40);
var
  key: Char;
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, color, msg);
  key := GameIo.ReadAnyKey;
  Inc(pauseCount);
end;

function TickCount: LongInt;
var
  now: LongInt;
  again: LongInt;
begin
{$IFDEF FPC}
  Delay(1);
{$ENDIF}
  again := biosTicks;
  repeat
    now := again;
    again := biosTicks;
  until now = again;
  TickCount := now;
end;

{ Return the time since midnight in centiseconds, from TickCount (5.4925 centiseconds a tick), which restarts at 0 at
  midnight. No DOS call is made: the menus call this on every pass while they wait for a key. }
function GetTicks: LongInt;
var
  now: LongInt;
begin
  now := TextRend.TickCount;
  { split so the product stays in a LongInt for a whole day's count }
  GetTicks := (now div 10000) * 54925 + (now mod 10000) * 54925 div 10000;
end;

{ Clear the whole screen to black (the video driver's ClearScreen: both EGA pages, every CGA or Tandy bank). }
procedure ClearScreen;
begin
  GameVars.video.ClearScreen;
  { a corner Border kept at the map window's lower-right is gone with the rest (the shop's Buy screen drew one there) }
  Border.ForgetJoin;
end;

{ Clear the bottom row, print msg in color, pause on the text delay (not a keywait), clear again. The parameters are
  (msg, color), the reverse of DisplayAndPause's. }
procedure PrintAndPause(msg: Types.TStr40; color: Byte);
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, color, msg);
  TextRend.PauseOnly;
  TextRend.ClearBottomLine;
end;

procedure PauseOnly;
begin
  if GameVars.demoMode then
    TextRend.PauseTicks(LongInt(GameVars.gameDelay) * 45 div 2)
  else
    Delay(GameVars.gameDelay * 225);
  Inc(pauseCount);
end;

procedure PauseTicks(hundredths: LongInt);
var
  start: LongInt;
  now: LongInt;
begin
  start := TextRend.GetTicks;
  repeat
    now := TextRend.GetTicks;
    { a reading below the start means the tick count restarted at midnight }
  until (now - start >= hundredths) or (now < start) or GameIo.DemoEnding;
end;

procedure DelayOrKey(seconds: Word);
var
  start: LongInt;
  deadline: LongInt;
  now: LongInt;
begin
  start := TextRend.GetTicks;
  deadline := start + 100 * seconds;
  repeat
    now := TextRend.GetTicks;
    { a reading below the start means the tick count restarted at midnight }
  until (now >= deadline) or (now < start) or KeyPressed;
end;

procedure FlashBottomLine(color: Byte; msg: Types.TStr40);
var
  key: Char;
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, color, msg);
  TextRend.DelayOrKey(2);
  if KeyPressed then
    key := GameIo.ReadAnyKey;
  TextRend.ClearBottomLine;
end;

{ Clear a character-cell rectangle to black (on both EGA pages). }
procedure ClearRect(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  { the rectangle must lie on the 40 x 25 screen, corners in order }
  if (ulCol < 0) or (ulRow < 0) or (ulCol > lrCol) or (ulRow > lrRow) or (lrCol > 39) or (lrRow > 24) then Exit;
  GameVars.video.ClearRect(ulCol, ulRow, lrCol, lrRow);
end;

begin
  { Turbo Pascal clears no variable }
  pageByDelay := False;
  pauseCount := 0;
end.
