{ The Journal screen: the list of the Adventurer's Journal's proclamations, entries and tavern tales in a column on the
  left, and the highlighted item's title and text a page at a time in the pane beside it.

  The pane follows the highlight, but only once the highlight has rested for PREVIEW_DELAY: reading an item can load an
  overlay, so the preview is drawn from MenuCore's idle hook while the bottom line waits for a key, and a held arrow key
  scrolls the list without stopping to draw each item on the way.

  The bottom line is the Journal's menu, after a JOURNAL: prompt; its Quests option turns the screen to the Quests page
  (#852), which lists the quests the party has been given, done or not (JrnlQst, #851), and whose Entries turns it back
  (#874).

  The list holds the items the party has found, or with the Journal setting All every item (JrnlSeen.Listed, #1090);
  the highlight and the list's first row are places in that list, not Journal items. }
{$O+,F+}
{$I COMPILER.INC}
unit JrnlView;

interface

{ Show the Journal until Exit or Escape, then redraw the exploration screen. An empty list says so, and the bottom line
  offers only Quests and Exit. Up and Down (also Home and End) move the
  highlight through the list, scrolling it at either end of the column and wrapping at either end of the list; Page Up
  and Page Down scroll it a column at a time. The highlighted item's title and first page show in the pane once the
  highlight rests. Select shows the highlighted item at once and turns to its text: Next and Prev, offered while the
  selected item has a later or an earlier page, turn its pages until the highlight moves again. Quests turns to the
  Quests page (ShowQuests), whose Entries turns back to the list as it was, and whose Exit or Escape leaves the Journal
  (#852, #874). }
procedure JournalMenu;

implementation

uses Crt, Types, C_JRNL, C_KEYS, GameVars, TextRend, Border, MenuCore, CharHlp, JrnlList, JrnlQst, CharDisp,
  C_MSG, JrnlSeen, UiColor;

const
  { The pane holds the item: its title on TITLE_ROW and its text from TEXT_TOP down, each as wide as the text is
    wrapped. The list column fills the rest of the frame on its left, one label a row, with the border column between
    them. }
  PANE_RIGHT = 38;
  PANE_LEFT = PANE_RIGHT - C_JRNL.JOURNAL_WIDTH + 1;
  LIST_LEFT = 1;
  LIST_RIGHT = PANE_LEFT - 2;
  TOP_ROW = 1;
  BOTTOM_ROW = 22;
  TITLE_ROW = 1;
  TEXT_TOP = 3;
  { the pane's text rows; an item longer than that gives up a row to "(more)" above a page with one before it and below
    a page with one after it }
  TEXT_ROWS = BOTTOM_ROW - TEXT_TOP + 1;
  { how long the highlight rests before the pane shows its item, in TextRend.GetTicks centiseconds }
  PREVIEW_DELAY = 25;
  { the bottom line's prompt, on the Journal and on its Quests page }
  PROMPT = 'Journal: ';
  { the Quests page: its heading on TITLE_ROW and its list from QUESTS_TOP down to BOTTOM_ROW, across the frame }
  QUESTS_LEFT = LIST_LEFT;
  QUESTS_RIGHT = PANE_RIGHT;
  QUESTS_TOP = TEXT_TOP;

var
  { the Journal items the list holds, in the Journal's order, and how many }
  items: array[1..C_JRNL.JOURNAL_COUNT] of Byte;
  count: Integer;
  { the highlighted place in the list, and the place on the list's first row }
  sel: Integer;
  top: Integer;
  { the place whose item is in the pane (0 while the pane is empty), its line count, and its page out of pages }
  shown: Integer;
  lines: Integer;
  page: Integer;
  pages: Integer;
  { set when the highlight has moved and the pane has yet to follow it, with the time it moved }
  previewDue: Boolean;
  movedAt: LongInt;

{ Fill the list with the Journal items it holds (JrnlSeen.Listed). }
procedure CollectItems;
var
  i: Integer;
begin
  count := 0;
  for i := 1 to C_JRNL.JOURNAL_COUNT do
    if JrnlSeen.Listed(i) then begin
      Inc(count);
      items[count] := i;
    end;
end;

{ Draws the label of a visible place n on its list row: in inverse video (black on white, #1160) when highlighted, else
  in light green. }
procedure DrawLabel(n: Integer; highlighted: Boolean);
var
  s: Types.TStr40;
begin
  s := Copy(JrnlList.EntryLabel(items[n]), 1, LIST_RIGHT - LIST_LEFT + 1);
  if highlighted then
    TextRend.DisplayStringOn(LIST_LEFT, TOP_ROW + n - top, Black, White, s)
  else
    TextRend.DisplayString(LIST_LEFT, TOP_ROW + n - top, LightGreen, s);
end;

{ Clear the list column and draw the labels from place top, the highlighted one in inverse video. }
procedure DrawList;
var
  n: Integer;
begin
  Border.ClearBox(LIST_LEFT, TOP_ROW, LIST_RIGHT, BOTTOM_ROW);
  n := top;
  while (n <= count) and (n - top <= BOTTOM_ROW - TOP_ROW) do begin
    JrnlView.DrawLabel(n, n = sel);
    Inc(n);
  end;
end;

{ Returns the first line on a 1-based page. The first and last pages lose one
  row to a "(more)" marker; middle pages lose two. }
function PageStart(p: Integer): Integer;
begin
  if p <= 1 then
    PageStart := 1
  else
    PageStart := TEXT_ROWS + (p - 2) * (TEXT_ROWS - 2);
end;

{ Clear the pane and draw the shown item's title, centered, and the lines of its current page, with "(more)" on the
  pane's top row when there is a page before it and on its bottom row when there is one after it. }
procedure DrawPage;
var
  title: string;
  line: Integer;
  row: Integer;
  lastRow: Integer;
begin
  Border.ClearBox(PANE_LEFT, TITLE_ROW, PANE_RIGHT, TITLE_ROW);
  Border.ClearBox(PANE_LEFT, TEXT_TOP, PANE_RIGHT, BOTTOM_ROW);
  title := Copy(JrnlList.EntryTitle(items[shown]), 1, PANE_RIGHT - PANE_LEFT + 1);
  TextRend.DisplayCentered(PANE_LEFT, PANE_RIGHT, TITLE_ROW, White, title);
  row := TEXT_TOP;
  lastRow := BOTTOM_ROW;
  if page > 1 then begin
    MenuCore.DrawMore(PANE_LEFT, PANE_RIGHT, TEXT_TOP);
    Inc(row);
  end;
  if page < pages then begin
    MenuCore.DrawMore(PANE_LEFT, PANE_RIGHT, BOTTOM_ROW);
    Dec(lastRow);
  end;
  line := JrnlView.PageStart(page);
  while (row <= lastRow) and (line <= lines) do begin
    TextRend.DisplayString(PANE_LEFT, row, LightGreen,
                           Copy(JrnlList.TextLine(items[shown], line), 1, PANE_RIGHT - PANE_LEFT + 1));
    Inc(line);
    Inc(row);
  end;
end;

{ Show the highlighted item's first page in the pane, unless the pane shows it already or the list is empty. }
procedure ShowSelected;
begin
  previewDue := False;
  if count = 0 then
    Exit;
  if shown <> sel then begin
    shown := sel;
    lines := JrnlList.LineCount(items[shown]);
    { a page holds TEXT_ROWS lines alone, TEXT_ROWS - 1 first or last, and TEXT_ROWS - 2 between }
    if lines <= TEXT_ROWS then
      pages := 1
    else begin
      pages := 2;
      while lines > JrnlView.PageStart(pages) + TEXT_ROWS - 2 do
        Inc(pages);
    end;
    page := 1;
    JrnlView.DrawPage;
  end else if page <> 1 then begin
    page := 1;
    JrnlView.DrawPage;
  end;
end;

{ Starts the preview delay if the highlighted item has changed. }
procedure Moved(old: Integer);
begin
  if sel <> old then begin
    previewDue := True;
    movedAt := TextRend.GetTicks;
  end;
end;

{ MenuCore's idle hook while the Journal waits for a key: once the highlight has rested for PREVIEW_DELAY with no key
  waiting, show its item. }
procedure TickPreview;
var
  now: LongInt;
begin
  if previewDue and not KeyPressed then begin
    now := TextRend.GetTicks;
    { the tick count restarts at midnight }
    if (now < movedAt) or (now - movedAt >= PREVIEW_DELAY) then
      JrnlView.ShowSelected;
  end;
end;

{ Draw the Journal: the list's box, then the text box and the title box, so the gold corners stay where the borders
  meet, the list from place top and the pane's page when it shows an item, or in the pane that the list is empty. }
procedure DrawJournal;
begin
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  Border.DrawBorder(LIST_LEFT, TOP_ROW, LIST_RIGHT, BOTTOM_ROW, 0);
  Border.DrawBorder(PANE_LEFT, TEXT_TOP, PANE_RIGHT, BOTTOM_ROW, 0);
  Border.DrawBorder(PANE_LEFT, TITLE_ROW, PANE_RIGHT, TITLE_ROW, 0);
  JrnlView.DrawList;
  if count = 0 then
    TextRend.DisplayString(PANE_LEFT, TEXT_TOP, LightGreen, 'Your journal is empty.')
  else if shown <> 0 then
    JrnlView.DrawPage;
end;

{ The Quests page's line for quest n: a blank, its label padded to C_JRNL.QUEST_WIDTH, a blank and DONE or ----. }
function QuestLine(n: Integer): Types.TStr40;
var
  line: Types.TStr40;
begin
  line := ' ' + Copy(JrnlQst.QuestLabel(n), 1, C_JRNL.QUEST_WIDTH);
  while Length(line) < C_JRNL.QUEST_WIDTH + 2 do
    line := line + ' ';
  if JrnlQst.IsDone(n) then
    QuestLine := line + 'DONE'
  else
    QuestLine := line + '----';
end;

{ Shows the Quests page until the player chooses Entries or Exit. Its heading
  is above the quests the party has been given (JrnlQst.IsGiven), each DONE or
  not yet (----), a page at a time, with the Journal's menu below (#874). Entries (E)
  turns back to the Journal's list, Quests (Q) stays on the page, and Exit, which has no key since E is Entries', or
  Escape leaves the Journal. Next and Prev, offered while the list has a page after or before this one, and Page Down
  and Page Up turn its pages. The list is only read: Enter takes the bottom line's current option, as it does on every
  menu, and nothing on the list is selected. The list is never empty: LIX is posted from the start. Returns True for
  Exit or Escape, and False when Entries returns to the Journal. }
function ShowQuests: Boolean;
const
  ROWS = BOTTOM_ROW - QUESTS_TOP + 1;
var
  ch: Char;
  ext: Boolean;
  n: Integer;
  count: Integer;
  { the list's first quest on the page, from 0 }
  top: Integer;
  menu: Types.TStr40;
  { the hotkey of each option on the bottom line, X for Exit, which has none }
  keys: string[5];
  { the option chosen last, by its key }
  lastKey: Char;
  { the quest on each line of the list }
  quest: array[0..C_JRNL.QUEST_COUNT - 1] of Byte;

  { Clear the list's box and draw its page from quest top. }
  procedure DrawQuestPage;
  var
    k: Integer;
  begin
    Border.ClearBox(QUESTS_LEFT, QUESTS_TOP, QUESTS_RIGHT, BOTTOM_ROW);
    k := top;
    while (k < count) and (k - top < ROWS) do begin
      TextRend.DisplayString(QUESTS_LEFT, QUESTS_TOP + k - top, LightGreen, JrnlView.QuestLine(quest[k]));
      Inc(k);
    end;
  end;

begin
  count := 0;
  for n := 1 to C_JRNL.QUEST_COUNT do
    if JrnlQst.IsGiven(n) then begin
      quest[count] := n;
      Inc(count);
    end;
  { the list's box first, then the heading's, as on the Journal }
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  Border.DrawBorder(QUESTS_LEFT, QUESTS_TOP, QUESTS_RIGHT, BOTTOM_ROW, 0);
  Border.DrawBorder(QUESTS_LEFT, TITLE_ROW, QUESTS_RIGHT, TITLE_ROW, 0);
  TextRend.DisplayCentered(QUESTS_LEFT, QUESTS_RIGHT, TITLE_ROW, White, 'QUESTS');
  top := 0;
  DrawQuestPage;
  lastKey := 'Q';
  repeat
    menu := 'Entries Quests';
    keys := 'EQ';
    if top + ROWS < count then begin
      menu := menu + ' Next';
      keys := keys + 'N';
    end;
    if top > 0 then begin
      menu := menu + ' Prev';
      keys := keys + 'P';
    end;
    menu := menu + ' Exit';
    keys := keys + 'X';
    if Pos(lastKey, keys) > 0 then
      GameVars.horizChoice := Pos(lastKey, keys)
    else
      GameVars.horizChoice := 2;
    MenuCore.unmarked := [Length(keys)];
    MenuCore.enterToCaller := True;
    ch := MenuCore.MenuHorizontal(PROMPT, menu, promptColor, optionColor, commandColor, True, False, ext);
    if ext then begin
      case ch of
        C_KEYS.PAGE_DOWN: ch := 'N';
        C_KEYS.PAGE_UP: ch := 'P';
      else
        ch := ' ';
      end;
      { only when the bottom line offers it }
      if Pos(ch, keys) = 0 then
        ch := ' ';
    end else if ch = C_KEYS.ENTER then
      ch := keys[GameVars.horizChoice];
    case ch of
      'N': begin
             Inc(top, ROWS);
             DrawQuestPage;
           end;
      'P': begin
             Dec(top, ROWS);
             if top < 0 then
               top := 0;
             DrawQuestPage;
           end;
    end;
    if ch in ['E', 'Q', 'N', 'P', 'X'] then
      lastKey := ch;
  until ch in [C_KEYS.NONE, 'E', 'X'];
  ShowQuests := ch <> 'E';
end;

{ Moves the highlight to a place in the list, scrolls it into view, and starts the
  preview delay. }
procedure MoveTo(n: Integer);
var
  old: Integer;
begin
  old := sel;
  if n > count then
    n := count;
  if n < 1 then
    n := 1;
  if (n < top) or (n > top + BOTTOM_ROW - TOP_ROW) then begin
    if n < top then
      top := n
    else
      top := n - (BOTTOM_ROW - TOP_ROW);
    sel := n;
    JrnlView.DrawList;
  end else begin
    JrnlView.DrawLabel(sel, False);
    sel := n;
    JrnlView.DrawLabel(sel, True);
  end;
  JrnlView.Moved(old);
end;

{ Scrolls the list one column while keeping the highlight on the same row. }
procedure ScrollColumn(down: Boolean);
var
  row: Integer;
  old: Integer;
begin
  old := sel;
  row := sel - top;
  if down then
    top := top + BOTTOM_ROW - TOP_ROW + 1
  else
    top := top - (BOTTOM_ROW - TOP_ROW + 1);
  if top > count - (BOTTOM_ROW - TOP_ROW) then
    top := count - (BOTTOM_ROW - TOP_ROW);
  if top < 1 then
    top := 1;
  sel := top + row;
  if sel > count then
    sel := count;
  JrnlView.DrawList;
  JrnlView.Moved(old);
end;

procedure JournalMenu;
var
  menu: Types.TStr40;
  ch: Char;
  { the bottom-line option chosen last, kept current while it is offered }
  lastKey: Char;
  ext: Boolean;
  { set by Select: Next and Prev page the item until the highlight moves }
  reading: Boolean;
  savedChoice: Byte;

  { The option number of hotkey key on the bottom line, or 1 (Select) when it is not offered. }
  function OptionOf(key: Char): Byte;
  var
    i: Byte;
    n: Byte;
  begin
    OptionOf := 1;
    n := 0;
    for i := 1 to Length(menu) do
      if menu[i] in ['A'..'Z'] then begin
        Inc(n);
        if menu[i] = key then
          OptionOf := n;
      end;
  end;

begin
  savedChoice := GameVars.horizChoice;
  JrnlView.CollectItems;
  sel := 1;
  top := 1;
  shown := 0;
  lines := 0;
  page := 1;
  pages := 1;
  reading := False;
  lastKey := 'S';
  JrnlView.DrawJournal;
  previewDue := count > 0;
  movedAt := TextRend.GetTicks;
  MenuCore.idleHook := JrnlView.TickPreview;
  repeat
    if count = 0 then
      menu := 'Quests Exit'
    else begin
      menu := 'Select';
      if reading and (page < pages) then
        menu := menu + ' Next';
      if reading and (page > 1) then
        menu := menu + ' Prev';
      menu := menu + ' Quests Exit';
    end;
    GameVars.horizChoice := OptionOf(lastKey);
    ch := MenuCore.MenuHorizontal(PROMPT, menu, promptColor, optionColor, commandColor, True, False, ext);
    if ext then begin
      { an empty list has nothing to move through }
      if count > 0 then
        case ch of
          C_KEYS.UP, C_KEYS.HOME: if sel > 1 then
                                    JrnlView.MoveTo(sel - 1)
                                  else
                                    JrnlView.MoveTo(count);
          C_KEYS.DOWN, C_KEYS.END_KEY: if sel < count then
                                         JrnlView.MoveTo(sel + 1)
                                       else
                                         JrnlView.MoveTo(1);
          C_KEYS.PAGE_UP: JrnlView.ScrollColumn(False);
          C_KEYS.PAGE_DOWN: JrnlView.ScrollColumn(True);
        end;
      if previewDue then begin
        reading := False;
        { after a move, Enter takes the highlighted item }
        lastKey := 'S';
      end;
    end else begin
      lastKey := ch;
      case ch of
        'S': begin
               JrnlView.ShowSelected;
               reading := True;
             end;
        'N': if page < pages then begin
               Inc(page);
               JrnlView.DrawPage;
             end;
        'P': if page > 1 then begin
               Dec(page);
               JrnlView.DrawPage;
             end;
        'Q': begin
               { the pane's preview waits while the Quests page is up }
               @MenuCore.idleHook := nil;
               if JrnlView.ShowQuests then
                 ch := 'E'
               else begin
                 JrnlView.DrawJournal;
                 MenuCore.idleHook := JrnlView.TickPreview;
               end;
             end;
      end;
    end;
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  @MenuCore.idleHook := nil;
  GameVars.horizChoice := savedChoice;
  CharDisp.DisplayNoncombatInterface;
end;

end.
