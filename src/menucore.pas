{ Menu input, animated menu pictures and linked lists of display strings. }
{$O+,F+}
{$I COMPILER.INC}
unit MenuCore;

interface

uses Types;

type
  { Bottom-line options by number, from 1 }
  TOptionSet = set of 1..20;

var
  { Set just before a MenuVertical call that only shows its list: when the list fits on one page it is drawn and #0
    returned without waiting for a key; a longer list runs the menu as usual so it can be paged. Every return clears
    it. }
  listOnly: Boolean;
  { Set just before a MenuHorizontal call whose caller reads the Left and Right arrows itself (turning, moving, aiming,
    adjusting a value); every return clears it. }
  arrowsToCaller: Boolean;
  { Set just before a MenuHorizontal call whose caller takes Enter itself (to change the highlighted line of a list):
    Enter then returns C_KEYS.ENTER in place of the current option's hotkey. Every return clears it. }
  enterToCaller: Boolean;
  { Set just before a MenuHorizontal call whose caller takes keys the menu line does not show (a letter drawn on the
    screen above it, say): a letter or digit in it ends the menu and is returned upper-cased, as a hotkey is, without
    changing the current option. Every return clears it. }
  extraKeys: string[16];
  { Set just before a MenuHorizontal call whose menu shows options without a hotkey, by number: such an option's
    capital letter is drawn in the menu colour and does not choose it, so another option may have that letter for its
    hotkey (the Journal's Entries and Exit, #874). It is reached with the arrows (Enter on it returns its letter, or
    C_KEYS.ENTER under enterToCaller). The key goes to the caller only when extraKeys holds it, or another option has
    it. Every return clears it. }
  unmarked: TOptionSet;
  { Set just before a MenuHorizontal call whose caller takes F5 and F8 (quick save and load) itself, as the map menu
    does; every return clears it. Without it those keys end no menu: outside combat they say quick save and load are
    unavailable here, and in combat they are ignored. }
  quickKeysToCaller: Boolean;
  { Set just before a MenuHorizontal call whose caller shows the Command Keys window on F1 (KeyHelp.ShowKeys), as the
    map and camp menus do: F1 then ends the menu with ext set, with or without reinterpret. Every return clears it.
    Without it F1 ends no menu: outside combat it says where the window is, and in combat it is ignored (#855). }
  helpToCaller: Boolean;
  { Set just before a MenuHorizontal or MenuVertical call whose caller opens a party member's items on Alt-1 to Alt-8
    (ViewChar.AltItems, #1195). MenuHorizontal then ends on them with ext set, with or without reinterpret; MenuVertical
    returns the key's scan code (C_KEYS.ALT_1 to ALT_8, which no other key returns: menu keys come back upper-cased)
    with sel set to the highlighted entry. Every return clears it. }
  memberKeysToCaller: Boolean;
  { Set just before a MenuVertical call whose caller shows something for the highlighted entry: a key that moves the
    highlight then returns that key at once, with sel set to the entry now highlighted, so the caller can redraw and
    call again. The call clears it. }
  movesToCaller: Boolean;
  { Set by every MenuVertical return: True when it returned because the highlight moved (movesToCaller), so the key it
    returns is a movement key, which may share its code with a letter (Page Up's scan code is 'I'), and not a choice. }
  moved: Boolean;
  { Set just before a MenuVertical call for a list paged as the spell lists are (#900): when the list is longer than
    its box, the bottom line offers Next and Prev on every page, and the box's last row is kept for '(more)' (DrawMore)
    while a page has lines below it. The call clears it. }
  fullPaging: Boolean;
  { Set just before a MenuVertical call for a list that scrolls a line at a time, as the shop's Buy screen does
    (mocks/new-shop.txt): Up and Down past the first or last row of the box move the list a line instead of wrapping
    within the page, and stop at the ends of the list; the bottom line offers no Next or Prev (Page Up and Page Down
    still turn a page). The box's last column is kept for a scroll bar (DrawScrollBar) while the list is longer than
    the box, with a blank column before it, and a page left short by a shorter list is brought up to fill the box. The
    call clears it. }
  lineScroll: Boolean;
  { Called on every pass of MenuHorizontal's key wait while set; combat sets it to animate the spell-aim preview. }
  idleHook: Types.TIdleProc;
  { Set just before a MenuHorizontal call that is to give up waiting: after menuTimeout hundredths of a second with no
    key pressed, it returns menuDefaultKey, as Curse's title menu does to start its demo. 0 waits for ever. Every
    return clears both. }
  menuTimeout: Word;
  menuDefaultKey: Char;

{ Returns zero-based member n, or nil when the list is shorter. }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Returns member's zero-based position, or -1 when it is not in list. }
function ListIndex(list, member: Types.PItemRec): Integer;

{ Returns the number of members in list. }
function ListCount(list: Types.PItemRec): Integer;

{ The lines of list a MenuVertical box from ulRow to lrRow shows at once: every row of it, or, under fullPaging (paged)
  with the list longer than the box, one fewer, the last row being kept for '(more)'. }
function PageRows(list: Types.PItemRec; ulRow, lrRow: ShortInt; paged: Boolean): Integer;

{ Draw '(more)' in white, centred between columns leftCol and rightCol on row: a list that goes on past what is shown. }
procedure DrawMore(leftCol, rightCol, row: Byte);

{ Where a scroll bar's thumb goes for a list of count lines in a box of rows lines whose first line shown is top
  (zero-based): first, the thumb's first row from 0, and size, its length in rows. The thumb's share of the bar is the
  share of the list shown, at least a row, and it runs from the bar's top, at the list's start, to its bottom, at the
  list's end. A list that fits the box fills the bar. }
procedure ScrollThumb(count, rows, top: Integer; var first, size: Integer);

{ Draw a scroll bar for ScrollThumb's thumb in column col, from row topRow down rows rows: the thumb '*' in white, the
  rest of the bar '-' in dark gray (mocks/new-shop.txt). }
procedure DrawScrollBar(col, topRow: Byte; count, rows, top: Integer);

{ Bottom-line menu: query in qCol, then menu with its digits and capital letters (the hotkeys) in hlCol, the current
  option (GameVars.horizChoice, reset to 1 when out of range) in inverse video (black on hlCol, #1160) and the rest in
  mCol. ',' and '.' move the current option, and so do the Left and Right arrows unless arrowsToCaller is set. A
  hotkey (returned upper-cased, and made the current option), a key in extraKeys (returned upper-cased) or space ends
  the menu; Enter, when mCol or hlCol is nonzero, returns the current option's hotkey (#13 for a menu without options,
  or while enterToCaller is set); Escape returns #0. With reinterpret, any other extended key returns its scan code
  and digits 1-9 that are no hotkey and not in extraKeys, and backslash, map to keypad scan codes, all with ext set;
  F1 returns its scan code, with ext set, only under helpToCaller, and Alt-1 to Alt-8 return theirs with or without
  reinterpret under memberKeysToCaller. The picture animates when animate is set or the GBVM menuAnimation flag is
  nonzero (that flag also advances a frame every pass and is cleared on exit). In the demo (GameVars.demoMode) it
  waits for nothing: it returns #0 at once, as for Escape, and ends the demo (GameIo.ReadGameKey). }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Vertical list menu in the box ulCol,ulRow..lrCol,lrRow with menu (plus Next/Prev/Exit as they apply) on the bottom
  line. The highlighted entry is drawn in inverse video, black on hlCol (#1160). The Up arrow or Home moves the
  highlight up a line and the Down arrow or End moves it down, wrapping within the page; Page Up and Page Down turn the
  page. idx is zero-based, held to the list, and the page opens on it; redraw requests repainting. Label rows have inUse
  set; they are drawn in qCol and skipped by the cursor. An empty list, Exit or Escape returns #0 with sel=nil (an empty
  list also sets idx=0). Any other menu key returns that key with sel set to the highlighted entry. With listOnly set, a
  list that fits on one page is drawn and #0 returned with sel=nil at once. With movesToCaller set, a key that moves the
  highlight returns too. A key in extraKeys returns as any other menu key does, on every key the list waits for; so do
  Alt-1 to Alt-8 under memberKeysToCaller, as their scan codes. Under fullPaging a list longer than the box offers
  Next and Prev on every page and marks a page with more below it. Under lineScroll the list scrolls a line at a time
  past the box's edges, stopping at its ends, with a scroll bar in the box's last column and no Next or Prev. }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;

{ Prompts for Yes or No and returns 'Y' or 'N'; in the demo (GameVars.demoMode), 'N' without waiting. }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Appends a display line and updates head/tail. inUse marks title rows. }
procedure AppendMenuLine(var head, tail: Types.PItemRec; name: Types.TStr40; title: Boolean);

{ Allocates n empty list nodes. Historical behavior allocates the head even
  when n is less than 1. }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Free every member. The caller's list pointer is left dangling, not set to nil. }
procedure FreeStringList(var list: Types.PItemRec);

implementation

uses GameVars, Crt, GameIo, Blit, Border, Portrait, C_KEYS, C_IFC, TextRend, StrUtil;

function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

function ListIndex(list, member: Types.PItemRec): Integer;
var
  n: Integer;
begin
  n := 0;
  while (list <> nil) and (list <> member) do begin
    list := list^.next;
    Inc(n);
  end;
  if list = nil then
    ListIndex := -1
  else
    ListIndex := n;
end;

function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function PageRows(list: Types.PItemRec; ulRow, lrRow: ShortInt; paged: Boolean): Integer;
var
  rows: Integer;
begin
  rows := lrRow - ulRow + 1;
  if paged and (MenuCore.ListCount(list) > rows) then
    Dec(rows);
  PageRows := rows;
end;

procedure DrawMore(leftCol, rightCol, row: Byte);
begin
  TextRend.DisplayCentered(leftCol, rightCol, row, White, '(more)');
end;

procedure ScrollThumb(count, rows, top: Integer; var first, size: Integer);
begin
  if (rows < 1) or (count <= rows) then begin
    first := 0;
    size := rows;
  end else begin
    size := Integer(LongInt(rows) * rows div count);
    if size < 1 then
      size := 1;
    if top < 0 then
      top := 0;
    if top > count - rows then
      top := count - rows;
    { rounded to the nearest row, but at the top only at the list's start and at the bottom only at its end }
    first := Integer((LongInt(top) * (rows - size) + (count - rows) div 2) div (count - rows));
    if (first = 0) and (top > 0) and (rows - size > 1) then
      first := 1;
    if (first = rows - size) and (top < count - rows) and (first > 1) then
      Dec(first);
  end;
end;

procedure DrawScrollBar(col, topRow: Byte; count, rows, top: Integer);
var
  first: Integer;
  size: Integer;
  r: Integer;
begin
  MenuCore.ScrollThumb(count, rows, top, first, size);
  for r := 0 to rows - 1 do
    if (r >= first) and (r < first + size) then
      TextRend.DisplayString(col, topRow + r, White, '*')
    else
      TextRend.DisplayString(col, topRow + r, DarkGray, '-');
end;

{ Highlight the menu's choice characters and select an item by keypress. With takeOption, Enter returns the current
  option's hotkey, as Curse does; without it, or when the menu has no options, Enter returns #13. }
function HorizontalMenu(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate, takeOption: Boolean;
                        var ext: Boolean): Char;
const
  { keypad digits 1..9 to scan codes, indexed by Ord(ch) - Ord('1') }
  keypadScanCodes: array[0..8] of Byte = (
    79, 80, 81, 75, 32, 77, 71, 72, 73);
var
  frameTick: LongInt;
  ch: Char;
  i: Byte;
  done: Boolean;
  mLen: Byte;
  qLen: Byte;
  opt: array[1..20] of Types.TOptRange;
  optCnt: Byte;
  enterOk: Boolean;
  { when the wait for a key began, for menuTimeout }
  waitStart: LongInt;

  { Split the menu into options: each starts at a digit or capital letter and ends two characters before the next one,
    the last at the end of the menu. There are at most 20 options (opt's size); the 20th runs to the end of the menu. }
  procedure ParseMenu(m: Types.TStr40);
  var
    idx: Byte;
    i: Byte;
    len: Byte;
  begin
    FillChar(opt, SizeOf(opt), 0);
    idx := 1;
    len := Length(m);
    for i := 1 to len do
      if m[i] in ['0'..'9', 'A'..'Z'] then
        if opt[idx].first = 0 then
          opt[idx].first := i
        else if idx < 20 then begin
          opt[idx].last := i - 2;
          Inc(idx);
          opt[idx].first := i;
        end;
    opt[idx].last := len;
    optCnt := idx;
  end;

  { The option that starts at menu position i: a hotkey past the 20th belongs to the 20th option. }
  function OptionAt(i: Byte): Byte;
  var
    j: Byte;
  begin
    j := 1;
    while (j < optCnt) and (opt[j].first <> i) do
      Inc(j);
    OptionAt := j;
  end;

  { Draw the menu after the query with option cur in inverse video (black on hlCol), the other hotkeys in hlCol (but
    not an unmarked option's) and the rest in mCol, then blank the rest of the line. The inverse covers the whole
    option, from the start of the word holding cur's hotkey to the end of its last word (StrUtil.OptionSpan): a hotkey
    inside its word (coMbat, sYstem) lights that word and nothing past it, and a script's ADVANCE CAUTIOUSLY or PRESS
    <ENTER>/<RETURN> TO CONTINUE lights whole (#1216). A menu without hotkeys lights all of it. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
    hlFirst: Byte;
    hlLast: Byte;
    nextFirst: Byte;
  begin
    if mLen > 0 then begin
      hlFirst := opt[cur].first;
      hlLast := opt[cur].last;
      if hlFirst > 0 then begin
        nextFirst := 0;
        if cur < optCnt then
          nextFirst := opt[cur + 1].first;
        StrUtil.OptionSpan(menu, opt[cur].first, nextFirst, hlFirst, hlLast);
      end;
      for i := 1 to mLen do
        if (hlFirst <= i) and (hlLast >= i)
           and (hlCol <> 0) then
          TextRend.RenderChar(qLen + i - 1, 24, Black, hlCol, 1, Ord(menu[i]), 1)
        else if (menu[i] in ['0'..'9', 'A'..'Z']) and not (OptionAt(i) in unmarked) then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, Black, 1, Ord(menu[i]), 1)
        else
          TextRend.RenderChar(qLen + i - 1, 24, mCol, Black, 1, Ord(menu[i]), 1);
      { columns qLen + mLen..39 are blanked, so a 39-column line still clears column 39 }
      if qLen + mLen <= 39 then
        TextRend.RenderChar(qLen + mLen, 24, Black, Black, 39 - mLen - qLen + 1, 32, 1);
    end;
  end;

  { Draw the query and the menu again, after a message over them. }
  procedure RedrawLine;
  begin
    if Length(query) <> 0 then
      TextRend.DisplayString(0, 24, qCol, query);
    DisplayOption(GameVars.horizChoice);
  end;

  { Outside combat, show msg on the bottom line until a key, then the menu again; in combat, nothing. }
  procedure Unavailable(msg: Types.TStr40);
  begin
    if GameVars.ifcState <> C_IFC.IN_COMBAT then begin
      TextRend.DisplayAndPause(Yellow, msg);
      TextRend.ClearBottomLine;
      RedrawLine;
    end;
  end;

  { Make the next option current, or the previous one when toNext is clear, wrapping at the ends, and redraw. }
  procedure StepOption(toNext: Boolean);
  begin
    if toNext then begin
      if GameVars.horizChoice = optCnt then
        GameVars.horizChoice := 1
      else
        Inc(GameVars.horizChoice);
    end else if GameVars.horizChoice = 1 then
      GameVars.horizChoice := optCnt
    else
      Dec(GameVars.horizChoice);
    DisplayOption(GameVars.horizChoice);
  end;

begin
  enterOk := (mCol <> 0) or (hlCol <> 0);
  ParseMenu(menu);
  if (GameVars.horizChoice < 1) or (GameVars.horizChoice > optCnt) then
    GameVars.horizChoice := 1;
  mLen := Length(menu);
  ch := #0;
  ext := False;
  done := False;
  frameTick := TextRend.GetTicks;
  waitStart := frameTick;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, 24, qCol, query);
  qLen := Length(query);
  DisplayOption(GameVars.horizChoice);
  repeat
    if @idleHook <> nil then
      idleHook;
    { the tick count restarts at midnight: restart the frame timer with it }
    if TextRend.GetTicks < frameTick then
      frameTick := TextRend.GetTicks;
    if TextRend.GetTicks < waitStart then
      waitStart := TextRend.GetTicks;
    if (menuTimeout > 0) and (TextRend.GetTicks - waitStart >= menuTimeout) and not KeyPressed then begin
      ch := menuDefaultKey;
      done := True;
    end;
    if ((GameVars.zone0^.savedWalls.menuAnimation <> 0) or animate) and (GameVars.animData.current > 0) then begin
      Portrait.DisplayImageBuf(3, 3, animate, GameVars.animData.frames[GameVars.animData.current].pic);
      if (TextRend.GetTicks - frameTick >= GameVars.animData.frames[GameVars.animData.current].time * 10)
         or (GameVars.zone0^.savedWalls.menuAnimation <> 0) then begin
        Inc(GameVars.animData.current);
        if GameVars.animData.current > GameVars.animData.count then
          GameVars.animData.current := 1;
        frameTick := TextRend.GetTicks;
      end;
    end;
    { in the demo, ReadGameKey returns Escape at once }
    if not done and (KeyPressed or GameVars.demoMode) then begin
      ch := GameIo.ReadGameKey;
      { any key, one the menu ignores too, starts menuTimeout's wait again }
      waitStart := TextRend.GetTicks;
      { a STING pop-up (Ctrl-Y) wrote over the menu line }
      if GameVars.bottomLineTaken then begin
        GameVars.bottomLineTaken := False;
        RedrawLine;
      end;
      if ch = #0 then
      { #0 prefixes an extended key: the second ReadGameKey reads its scan code. Left and Right move the current option
        unless the caller takes them; any other extended key ends the menu (with ext set) only with reinterpret, or for
        Alt-1 to Alt-8 under memberKeysToCaller, and is otherwise ignored. }
      begin
        ch := GameIo.ReadGameKey;
        if ((ch = C_KEYS.LEFT) or (ch = C_KEYS.RIGHT)) and not arrowsToCaller then
          StepOption(ch = C_KEYS.RIGHT)
        else if ((ch = C_KEYS.F5) or (ch = C_KEYS.F8)) and not quickKeysToCaller then
          Unavailable('Quick save and load unavailable.')
        else if ch = C_KEYS.F1 then begin
          if helpToCaller then begin
            ext := True;
            done := True;
          end else
            Unavailable('Help is on the map and camp menus.');
        end else if reinterpret or (memberKeysToCaller and (ch >= C_KEYS.ALT_1) and (ch <= C_KEYS.ALT_8)) then begin
          ext := True;
          done := True;
        end;
      end else
        case ch of
          { Escape returns #0. }
          C_KEYS.ESCAPE: begin
                 done := True;
                 ch := C_KEYS.NONE;
               end;
          C_KEYS.ENTER: if enterOk then begin
                 if takeOption and not enterToCaller and (opt[GameVars.horizChoice].first <> 0) then
                   ch := menu[opt[GameVars.horizChoice].first]
                 else
                   ch := C_KEYS.ENTER;
                 done := True;
               end;
          ',': StepOption(False);
          '.': StepOption(True);
        else begin
            ch := UpCase(ch);
            if ch in [' ', '0'..'9', 'A'..'Z'] then
              if ch = ' ' then
                done := True
              else
                for i := 1 to mLen do
                  if (menu[i] = ch) and not (OptionAt(i) in unmarked) then begin
                    done := True;
                    GameVars.horizChoice := OptionAt(i);
                    DisplayOption(GameVars.horizChoice);
                  end;
            if (ch <> ' ') and (Pos(ch, extraKeys) > 0) then
              done := True;
            { a digit that is an option's hotkey or in extraKeys is returned as itself: only the others are the
              keypad's (the combat menu's 1 and 2, #1209) }
            if reinterpret and not done then
              if ch in ['1'..'9', '\'] then
              begin
                if ch = '\' then
                  { keypad-'*' scan code, not ASCII '7' }
                  ch := #55
                else
                  ch := Char(keypadScanCodes[Ord(ch) - Ord('1')]);
                ext := True;
                done := True;
              end;
          end;
        end;
    end;
  until done;
  arrowsToCaller := False;
  enterToCaller := False;
  extraKeys := '';
  unmarked := [];
  quickKeysToCaller := False;
  helpToCaller := False;
  menuTimeout := 0;
  menuDefaultKey := C_KEYS.NONE;
  memberKeysToCaller := False;
  GameVars.zone0^.savedWalls.menuAnimation := 0;
  HorizontalMenu := ch;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
begin
  MenuHorizontal := MenuCore.HorizontalMenu(query, menu, qCol, mCol, hlCol, reinterpret, animate, True, ext);
end;

function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;
var
  width: Byte;
  count: Integer;
  ext: Boolean;
  rows: Integer;
  ch: Char;
  hMenu: Types.TStr40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItemRec;
  headerCnt: Integer;
  toCaller: Boolean;
  { memberKeysToCaller, taken at entry as extraKeys is }
  memberKeys: Boolean;
  oldIdx: Integer;
  oldTop: Integer;
  { the caller's extraKeys, given to every HorizontalMenu call }
  keep: string[16];
  { fullPaging with the list longer than the box: Next and Prev on every page, and '(more)' on the box's last row }
  paged: Boolean;
  { lineScroll, taken at entry }
  scrolls: Boolean;

  { Clear the box and draw the list from member top, labels in qCol and entries in mCol, each padded to the box width,
    and, when paged, '(more)' on the box's last row while lines follow the page. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    row: ShortInt;
  begin
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    pp := MenuCore.FindListMember(top, list);
    row := ulRow;
    while (pp <> nil) and (row < ulRow + rows) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, qCol, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, mCol, pp^.name);
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, Black, width - Length(pp^.name), 32, 1);
      pp := pp^.next;
      Inc(row);
    end;
    if paged and (top + rows < count) then
      MenuCore.DrawMore(ulCol, lrCol, lrRow);
    if scrolls and (count > rows) then
      MenuCore.DrawScrollBar(lrCol, ulRow, count, rows, top);
  end;

  { Position of the first non-blank character of s (the last position when s is all blanks). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Position of the last non-blank character of s (1 when s is all blanks). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraw the text of member n, without its surrounding blanks, in inverse video: black on hlCol. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayStringOn(ulCol + a - 1, ulRow + (n - GameVars.verticalMenuTop), Black, hlCol,
                             Copy(pp^.name, a, b));
  end;

  { Redraw the text of member n, without its surrounding blanks, in its normal color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GameVars.verticalMenuTop), qCol, Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GameVars.verticalMenuTop), mCol, Copy(pp^.name, a, b));
  end;

  { Move idx off label rows in the given direction, wrapping within the visible page; gives up after a page of rows. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GameVars.verticalMenuTop + rows - 1 < idx then
          idx := GameVars.verticalMenuTop;
        if count - 1 < idx then
          idx := GameVars.verticalMenuTop;
      end;
    end else
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GameVars.verticalMenuTop then
          idx := GameVars.verticalMenuTop + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
      end;
  end;

  { Scroll a page down or up, clamped to the list, keep the cursor's row on the page and redraw it. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GameVars.verticalMenuTop;
    if down then begin
      Inc(GameVars.verticalMenuTop, rows);
      if count - rows < GameVars.verticalMenuTop then
        GameVars.verticalMenuTop := count - rows;
    end else begin
      Dec(GameVars.verticalMenuTop, rows);
      if GameVars.verticalMenuTop < 0 then
        GameVars.verticalMenuTop := 0;
    end;
    idx := GameVars.verticalMenuTop + rel;
    SkipLabels(down);
    DrawPage(GameVars.verticalMenuTop);
  end;

  { lineScroll's MoveLine: move the cursor to the next entry that is no label, down or up, staying put when there is
    none before the list's end; a cursor off the page brings the page to it, a line at a time, and redraws it. }
  procedure ScrollLine(down: Boolean);
  var
    k: Integer;
  begin
    k := idx;
    repeat
      if down then
        Inc(k)
      else
        Dec(k);
    until (k < 0) or (k > count - 1) or (MenuCore.FindListMember(k, list)^.inUse = 0);
    if (k >= 0) and (k <= count - 1) then
      idx := k;
    if idx > count - 1 then
      idx := count - 1;
    if idx < GameVars.verticalMenuTop then begin
      GameVars.verticalMenuTop := idx;
      DrawPage(GameVars.verticalMenuTop);
    end else if idx > GameVars.verticalMenuTop + rows - 1 then begin
      GameVars.verticalMenuTop := idx - rows + 1;
      DrawPage(GameVars.verticalMenuTop);
    end;
  end;

  { Move the cursor one line, wrapping within the visible page and clamped to the list, then skip label rows. }
  procedure MoveLine(down: Boolean);
  begin
    if scrolls then begin
      ScrollLine(down);
      Exit;
    end;
    if down then begin
      Inc(idx);
      if GameVars.verticalMenuTop + rows - 1 < idx then
        idx := GameVars.verticalMenuTop;
      if count - 1 < idx then
        idx := GameVars.verticalMenuTop;
    end else begin
      Dec(idx);
      if idx < GameVars.verticalMenuTop then
        idx := GameVars.verticalMenuTop + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  keep := extraKeys;
  extraKeys := '';
  toCaller := movesToCaller;
  movesToCaller := False;
  memberKeys := memberKeysToCaller;
  memberKeysToCaller := False;
  moved := False;
  paged := fullPaging;
  fullPaging := False;
  scrolls := lineScroll;
  lineScroll := False;
  if list = nil then begin
    listOnly := False;
    idx := 0;
    sel := nil;
    MenuVertical := C_KEYS.NONE;
  end else begin
    GameVars.horizChoice := 1;
    if scrolls then
      { a blank column, then the scroll bar's }
      width := lrCol - ulCol - 1
    else
      width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := MenuCore.PageRows(list, ulRow, lrRow, paged);
    paged := paged and (rows < lrRow - ulRow + 1);
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    if GameVars.verticalMenuTop > idx then begin
      GameVars.verticalMenuTop := idx;
      redraw := True;
    end;
    if GameVars.verticalMenuTop > count then begin
      GameVars.verticalMenuTop := 0;
      redraw := True;
    end;
    { verticalMenuTop is every list's: an idx past the list, or below the page, brings the page down to it (#975) }
    if idx > count - 1 then
      idx := count - 1;
    if idx > GameVars.verticalMenuTop + rows - 1 then begin
      GameVars.verticalMenuTop := idx - rows + 1;
      redraw := True;
    end;
    { a scrolling list fills the box: a page left short by a shorter list comes up }
    if scrolls and (GameVars.verticalMenuTop > 0) and (GameVars.verticalMenuTop > count - rows) then begin
      GameVars.verticalMenuTop := count - rows;
      if GameVars.verticalMenuTop < 0 then
        GameVars.verticalMenuTop := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GameVars.verticalMenuTop);
    redraw := False;
    if listOnly then begin
      listOnly := False;
      if count <= rows then begin
        sel := nil;
        MenuVertical := C_KEYS.NONE;
        Exit;
      end;
    end;
    repeat
      HighlightLine(idx);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      if paged or (count - rows > GameVars.verticalMenuTop) then begin
        if not scrolls then
          hMenu := hMenu + ' Next';
        hasNext := True;
      end;
      if paged or (GameVars.verticalMenuTop > headerCnt) then begin
        if not scrolls then
          hMenu := hMenu + ' Prev';
        hasPrev := True;
      end;
      if addExit then
        hMenu := hMenu + ' Exit';
      { Enter stays #13 here: it takes the highlighted list entry, not a bottom-line option. }
      extraKeys := keep;
      ch := MenuCore.HorizontalMenu(query, hMenu, qCol, mCol, hlCol, True, False, False, ext);
      UnhighlightLine(idx);
      oldIdx := idx;
      oldTop := GameVars.verticalMenuTop;
      if ext then
        case ch of
          { line up }
          C_KEYS.HOME, C_KEYS.UP: MoveLine(False);
          { line down }
          C_KEYS.END_KEY, C_KEYS.DOWN: MoveLine(True);
          { Page Up = previous page, when Prev is offered }
          C_KEYS.PAGE_UP: if hasPrev then MovePage(False);
          { Page Down = next page, when Next is offered }
          C_KEYS.PAGE_DOWN: if hasNext then MovePage(True);
          { a party member's items, for the caller to open }
          C_KEYS.ALT_1..C_KEYS.ALT_8:
            if memberKeys then begin
              sel := MenuCore.FindListMember(idx, list);
              MenuVertical := ch;
              Exit;
            end;
        end else
        case ch of
          { as for Page Up and Page Down, only when the bottom line offers Prev or Next }
          'P': if hasPrev and not scrolls then MovePage(False);
          'N': if hasNext and not scrolls then MovePage(True);
          C_KEYS.ESCAPE, 'E', C_KEYS.NONE:
            begin
              sel := nil;
              MenuVertical := C_KEYS.NONE;
              Exit;
            end;
        else begin
            sel := MenuCore.FindListMember(idx, list);
            MenuVertical := ch;
            Exit;
          end;
        end;
      if toCaller and ((idx <> oldIdx) or (GameVars.verticalMenuTop <> oldTop)) then begin
        sel := MenuCore.FindListMember(idx, list);
        moved := True;
        MenuVertical := ch;
        Exit;
      end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  { default the highlight to "No" }
  GameVars.horizChoice := 2;
  repeat
    ch := MenuCore.MenuHorizontal(query, 'Yes No', qCol, mCol, hlCol, False, False, ext);
    { in the demo the menu waits for nothing, and the answer is No }
    if GameVars.demoMode then
      ch := 'N';
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

{ Members are allocated with only the TItemRec prefix (name, inUse, next); the fields past next do not exist. }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TMenuNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure AppendMenuLine(var head, tail: Types.PItemRec; name: Types.TStr40; title: Boolean);
var
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TMenuNode));
  n^.next := nil;
  n^.name := name;
  n^.inUse := Ord(title);
  if head = nil then
    head := n
  else
    tail^.next := n;
  tail := n;
end;

procedure FreeStringList(var list: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TMenuNode));
  end;
end;

begin
  listOnly := False;
  arrowsToCaller := False;
  enterToCaller := False;
  movesToCaller := False;
  moved := False;
  fullPaging := False;
  lineScroll := False;
  extraKeys := '';
  unmarked := [];
  quickKeysToCaller := False;
  helpToCaller := False;
  menuTimeout := 0;
  menuDefaultKey := #0;
  memberKeysToCaller := False;
  @idleHook := nil;
end.
