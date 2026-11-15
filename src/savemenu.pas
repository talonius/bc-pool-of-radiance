{ The full-screen Load/Save Game menu: one entry per saved-game slot, its description, area and the time it was saved,
  and the popup that asks for a description when saving. A slot's description and area are kept in savgam<x>.inf beside
  its savgam<x>.dat. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit SaveMenu;

interface

uses Types, FileUtil;

const
  { the saved-game slots, in the order the menu lists them: A..J, then Z, the quick save (F5 and F8), so Q is Quit's key
    (#1080) }
  SLOT_LETTERS = 'ABCDEFGHIJZ';
  { the quick save's slot before #1080, whose files MoveOldQuickSave moves to slot Z }
  OLD_QUICK_SLOT = 'Q';
  { how many slots there are: the menu's tables are this long }
  SLOT_COUNT = Length(SLOT_LETTERS);
  { the longest description and area name a slot keeps }
  DESC_LEN = 30;
  AREA_LEN = 18;
  { the longest description typed, and shown, beside the time a slot was saved }
  DESC_SHOWN = 27;
  { what ChooseSlot returns for Quit (#872): no slot's letter }
  QUIT_CHOSEN = '!';
  { the quick save's slot: F5 saves to it and F8 loads it, from the map menu }
  QUICK_SLOT = 'Z';

type
  TSlotDesc = string[DESC_LEN];
  TSlotArea = string[AREA_LEN];

{ Runs the full-screen slot browser. Save mode lists every slot; Load mode lists
  only usable saves and reports when none exist (#1069). Arrow, paging, and
  direct-letter keys select a slot. The initial selection is start when present,
  otherwise the newest save.

  Returns a slot letter, QUIT_CHOSEN for Quit, or C_KEYS.NONE for Escape/Exit.
  The caller handles Quit and redraws its own screen. }
function ChooseSlot(saving: Boolean; start: Char): Char;

{ Edits a slot description in a popup. Input is uppercase and limited to
  DESC_SHOWN characters. An empty description becomes "SAVE GAME <letter>".
  Enter accepts it; Escape returns False. }
function AskDescription(letter: Char; area: TSlotArea; var desc: TSlotDesc): Boolean;

{ The description and area kept for slot letter: True when its savgam<x>.inf is a slot-info file of this format, else
  False with both empty. }
function ReadSlotInfo(letter: Char; var desc: TSlotDesc; var area: TSlotArea): Boolean;

{ Slot letter's file of extension ext: savgam<x><ext>, its name alone / with the save directory before it. }
function SlotName(letter: Char; ext: Types.TStr8): FileUtil.TSetName;
function SlotFile(letter: Char; ext: Types.TStr8): Types.TPathStr;

{ CHRDAT<letter><n>: the base name of the n-th party member's files in saved game letter. }
function MemberName(letter: Char; n: Byte): Types.TStr8;

{ vault<x>.dat: slot letter's copy of the vault (Vault). }
function VaultName(letter: Char): FileUtil.TSetName;

{ Add to save s, to be erased, a character's files (SaveLoad writes them): <base><ext>, .itm, .spc, .mem, .sts and
  .chx. }
procedure RemoveCharFiles(var s: FileUtil.TFileSet; base: FileUtil.TSetName; ext: Types.TStr8);

{ Recovers a slot after an interrupted commit. Every reader calls this before
  inspecting the slot. Returns True when recovery is complete. }
function RecoverSlot(letter: Char): Boolean;

{ Move a quick save made before #1080, in slot Q, to slot Z, the quick save's slot now: every file of the save (its
  savgam .dat, .inf, .sts, .map, .nts and .jnl, its vault copy and its members' files), savgamQ.dat last, so a move
  the game was ended in is done again at the next start. Nothing moves while slot Z holds a save. }
procedure MoveOldQuickSave;

{ Write slot letter's savgam<x>.inf as a file of save s (FileUtil.WriteToSet): True when it was written. }
function WriteSlotInfo(var s: FileUtil.TFileSet; letter: Char; desc: TSlotDesc; area: TSlotArea): Boolean;

{ 'Put save disk in X: (Esc gives up)', for the save directory's drive. }
function SaveDiskMsg: Types.TStr40;

{ Say on the bottom line that name could not be made (problem: 'Cannot write', 'Cannot create'), with its path, then ask
  for the save disk (SaveDiskMsg), each until a key (DaxIo.AskForDisk): False when Escape answered, giving up (SSI asked
  until the disk was there, so a folder that could not be written held the player for good, #794). }
function AskSaveDisk(problem: Types.TStr40; name: Types.TPathStr): Boolean;

{ Create the save directory and any parent directory it needs (FileUtil.MakeFolder, which POOLOPT.CFG's write shares,
  #1067). Prompt for the save disk until it is there or Escape gives up (AskSaveDisk). }
procedure CheckSaveDir;

implementation

uses Crt, Dos, GameVars, TextRend, Border, GameIo, DaxIo, MenuCore, AreaName, C_KEYS, StrUtil
  {$IFDEF FPC}, NatFile{$ENDIF}, UiColor;

const
  INFO_SIG = 'SINF';
  INFO_VERSION = 1;
  { the list's frame: the title box on row 1, the list box rows 3..22, both boxes columns 1..38 }
  BOX_LEFT = 1;
  BOX_RIGHT = 38;
  TITLE_ROW = 1;
  LIST_TOP = 3;
  LIST_BOTTOM = 22;
  { the slots shown at once: each takes two rows and a blank one, below the top "(more)" row }
  VISIBLE = 6;
  { the text inside the list box, a column in from its borders: a slot's letter at LEFT_COL, its description and area
    from DESC_COL, its time and date ending at RIGHT_COL }
  LEFT_COL = 2;
  DESC_COL = 5;
  RIGHT_COL = 37;
  { the save popup's description line }
  POP_DESC_ROW = LIST_TOP + 5;
  { the bottom line's options, by GameVars.horizChoice }
  OPT_NEXT = 1;
  OPT_PREV = 2;
  OPT_TAKE = 3;
  OPT_QUIT = 4;
  OPT_EXIT = 5;
  { Exit's key, which no slot has (#910); Quit's is its Q (#1080) }
  EXIT_KEY = 'X';
  QUIT_KEY = 'Q';

type
  { A savgam<x>.inf file. }
  TSlotInfoFile = record
    sig: string[4];
    version: Byte;
    desc: TSlotDesc;
    area: TSlotArea;
  end;

var
  { the slots listed, by letter, with what is shown for each }
  listed: string[SLOT_COUNT];
  count: Byte;
  used: array[1..SLOT_COUNT] of Boolean;
  descs: array[1..SLOT_COUNT] of TSlotDesc;
  areas: array[1..SLOT_COUNT] of TSlotArea;
  { when each was saved: hh:mm and YYYY/MM/DD }
  clocks: array[1..SLOT_COUNT] of string[5];
  dates: array[1..SLOT_COUNT] of string[10];
  times: array[1..SLOT_COUNT] of LongInt;
  { the selected slot, and the first one shown, as indexes into listed }
  sel: Byte;
  top: Byte;

function SlotName(letter: Char; ext: Types.TStr8): FileUtil.TSetName;
begin
  SlotName := 'savgam' + letter + ext;
end;

function SlotFile(letter: Char; ext: Types.TStr8): Types.TPathStr;
begin
  SlotFile := GameVars.saveDirectory + SaveMenu.SlotName(letter, ext);
end;

function MemberName(letter: Char; n: Byte): Types.TStr8;
var
  numStr: String[1];
begin
  Str(n, numStr);
  MemberName := 'CHRDAT' + letter + numStr;
end;

function VaultName(letter: Char): FileUtil.TSetName;
begin
  VaultName := 'vault' + letter + '.dat';
end;

procedure RemoveCharFiles(var s: FileUtil.TFileSet; base: FileUtil.TSetName; ext: Types.TStr8);
begin
  FileUtil.AddToSet(s, base + ext, False);
  FileUtil.AddToSet(s, base + '.itm', False);
  FileUtil.AddToSet(s, base + '.spc', False);
  FileUtil.AddToSet(s, base + '.mem', False);
  FileUtil.AddToSet(s, base + '.sts', False);
  FileUtil.AddToSet(s, base + '.chx', False);
end;

{ Start s as the set of every file a save in slot letter may have, the .dat first, as SaveLoad.SaveToSlot puts it. }
procedure SlotSet(var s: FileUtil.TFileSet; letter: Char);
var
  n: Byte;
begin
  FileUtil.NewSet(s, GameVars.saveDirectory);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.dat'), False);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.inf'), False);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.sts'), False);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.map'), False);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.nts'), False);
  FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.jnl'), False);
  FileUtil.AddToSet(s, SaveMenu.VaultName(letter), False);
  for n := 1 to Types.MAX_PARTY do
    SaveMenu.RemoveCharFiles(s, SaveMenu.MemberName(letter, n), '.sav');
end;

function RecoverSlot(letter: Char): Boolean;
var
  s: FileUtil.TFileSet;
begin
  SaveMenu.SlotSet(s, letter);
  RecoverSlot := FileUtil.RecoverSet(s);
end;

procedure MoveOldQuickSave;
var
  oldSet: FileUtil.TFileSet;
  newSet: FileUtil.TFileSet;
  i: Byte;
  ok: Boolean;
begin
  if not SaveMenu.RecoverSlot(OLD_QUICK_SLOT) or not SaveMenu.RecoverSlot(QUICK_SLOT) or
      not FileUtil.Exists(SaveMenu.SlotFile(OLD_QUICK_SLOT, '.dat')) or
      FileUtil.Exists(SaveMenu.SlotFile(QUICK_SLOT, '.dat')) then
    Exit;
  SaveMenu.SlotSet(oldSet, OLD_QUICK_SLOT);
  SaveMenu.SlotSet(newSet, QUICK_SLOT);
  { each file Q has replaces Z's; a file Z has with none in Q stays, since a move the game was ended in may already
    have put it there, and a rerun that erased it would lose it (#1085) }
  ok := True;
  for i := oldSet.count downto 1 do
    if ok and FileUtil.Exists(oldSet.dir + oldSet.names[i]) then begin
      ok := FileUtil.DeleteChecked(newSet.dir + newSet.names[i]);
      if ok then
        ok := FileUtil.RenameChecked(oldSet.dir + oldSet.names[i], newSet.dir + newSet.names[i]);
    end;
end;

function ReadSlotInfo(letter: Char; var desc: TSlotDesc; var area: TSlotArea): Boolean;
var
  rec: TSlotInfoFile;
  ok: Boolean;
begin
  desc := '';
  area := '';
  ok := FileUtil.ReadRecord(SaveMenu.SlotFile(letter, '.inf'), rec, SizeOf(rec)) and (rec.sig = INFO_SIG) and
        (rec.version = INFO_VERSION) and (Length(rec.desc) <= DESC_LEN) and (Length(rec.area) <= AREA_LEN);
  if ok then begin
    desc := rec.desc;
    area := rec.area;
  end;
  ReadSlotInfo := ok;
end;

function WriteSlotInfo(var s: FileUtil.TFileSet; letter: Char; desc: TSlotDesc; area: TSlotArea): Boolean;
var
  rec: TSlotInfoFile;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := INFO_SIG;
  rec.version := INFO_VERSION;
  rec.desc := desc;
  rec.area := area;
  WriteSlotInfo := FileUtil.WriteToSet(s, SaveMenu.SlotName(letter, '.inf'), rec, SizeOf(rec));
end;

{ Fill in listed entry i for slot letter: whether its savgam<x>.dat exists, the file's time (packed, and as hh:mm and
  YYYY/MM/DD), and its description and area. A save with no slot-info file (one made before the menu kept them) has no
  description, and its area is read from the save itself: the GBVM previousScriptId and mapId in its zone 0, which
  follows the one-byte diskIndex. }
procedure ReadSlot(i: Byte; letter: Char);
var
  f: file;
  t: LongInt;
  dt: DateTime;
  y: string[4];
  ioRes: Integer;
  script: Word;
  map: Types.TGbvmWord;
  n1: Word;
  n2: Word;
  recovered: Boolean;
begin
  recovered := SaveMenu.RecoverSlot(letter);
  listed[i] := letter;
  used[i] := False;
  times[i] := 0;
  clocks[i] := '';
  dates[i] := '';
  descs[i] := '';
  areas[i] := '';
  if FileUtil.OpenReadOnly(f, SaveMenu.SlotFile(letter, '.dat')) then begin
    used[i] := True;
    GetFTime(f, t);
    if IOResult = 0 then begin
      times[i] := t;
      UnpackTime(t, dt);
      Str(dt.Year, y);
      clocks[i] := StrUtil.ZeroPad2(dt.Hour) + ':' + StrUtil.ZeroPad2(dt.Min);
      dates[i] := y + '/' + StrUtil.ZeroPad2(dt.Month) + '/' + StrUtil.ZeroPad2(dt.Day);
    end;
    if not SaveMenu.ReadSlotInfo(letter, descs[i], areas[i]) then begin
      Seek(f, SizeOf(GameVars.diskIndex) + Ofs(GameVars.zone0^.previousScriptId) - Ofs(GameVars.zone0^));
      BlockRead(f, script, SizeOf(script), n1);
      Seek(f, SizeOf(GameVars.diskIndex) + Ofs(GameVars.zone0^.mapId) - Ofs(GameVars.zone0^));
      BlockRead(f, map, SizeOf(map), n2);
      if (IOResult = 0) and (n1 = SizeOf(script)) and (n2 = SizeOf(map)) then
        areas[i] := AreaName.AreaFor(Lo(script), map.lo)
      else
        areas[i] := 'UNKNOWN AREA';
    end;
    Close(f);
    ioRes := IOResult;
  end;
end;

{ Draw the slots from top, each letter in white, the selected slot in white with its letter and colon in inverse video
  (black on white, #1160) and the rest in light green, with "(more)" above when a slot is hidden above and below when
  one is hidden below. }
procedure DrawList;
var
  k: Byte;
  i: Byte;
  row: Byte;
  color: Byte;
begin
  Border.ClearBox(BOX_LEFT, LIST_TOP, BOX_RIGHT, LIST_BOTTOM);
  if top > 1 then
    MenuCore.DrawMore(BOX_LEFT, BOX_RIGHT, LIST_TOP);
  for k := 0 to VISIBLE - 1 do begin
    i := top + k;
    if i <= count then begin
      if i = sel then
        color := White
      else
        color := LightGreen;
      row := LIST_TOP + 1 + 3 * k;
      if i = sel then
        TextRend.DisplayStringOn(LEFT_COL, row, Black, White, listed[i] + ':')
      else begin
        TextRend.DisplayString(LEFT_COL, row, White, listed[i]);
        TextRend.DisplayString(LEFT_COL + 1, row, color, ':');
      end;
      if used[i] then begin
        TextRend.DisplayString(DESC_COL, row, color, Copy(descs[i], 1, DESC_SHOWN));
        TextRend.DisplayString(RIGHT_COL + 1 - Length(clocks[i]), row, color, clocks[i]);
        TextRend.DisplayString(DESC_COL, row + 1, color, areas[i]);
        TextRend.DisplayString(RIGHT_COL + 1 - Length(dates[i]), row + 1, color, dates[i]);
      end else
        TextRend.DisplayString(DESC_COL, row, color, 'EMPTY');
    end;
  end;
  if top + VISIBLE - 1 < count then
    MenuCore.DrawMore(BOX_LEFT, BOX_RIGHT, LIST_BOTTOM);
end;

{ Select listed entry i, wrapping past either end, scroll it into view and redraw the list. }
procedure MoveTo(i: Integer);
begin
  if i < 1 then
    i := count
  else if i > count then
    i := 1;
  sel := i;
  if sel < top then
    top := sel;
  if sel > top + VISIBLE - 1 then
    top := sel - VISIBLE + 1;
  SaveMenu.DrawList;
end;

function ChooseSlot(saving: Boolean; start: Char): Char;
var
  i: Byte;
  ch: Char;
  ext: Boolean;
  action: Types.TStr8;
  newest: LongInt;
  chosen: Char;
  letters: string[SLOT_COUNT];
begin
  ChooseSlot := C_KEYS.NONE;
  { a string constant cannot be indexed }
  letters := SLOT_LETTERS;
  count := 0;
  for i := 1 to Length(letters) do begin
    SaveMenu.ReadSlot(count + 1, letters[i]);
    if saving or used[count + 1] then
      Inc(count);
  end;
  listed[0] := Chr(count);
  { only loading lists none; the caller's screen stays up behind the message (#1069) }
  if count = 0 then begin
    TextRend.FlashBottomLine(Yellow, 'No saved games found to load.');
    Exit;
  end;
  sel := 1;
  newest := 0;
  for i := 1 to count do
    if used[i] and ((newest = 0) or (times[i] > newest)) then begin
      newest := times[i];
      sel := i;
    end;
  if Pos(start, listed) > 0 then
    sel := Pos(start, listed);
  top := 1;
  TextRend.ClearScreen;
  Border.DrawBorder(BOX_LEFT, LIST_TOP, BOX_RIGHT, LIST_BOTTOM, 0);
  Border.DrawBorder(BOX_LEFT, TITLE_ROW, BOX_RIGHT, TITLE_ROW, 0);
  TextRend.DisplayCentered(BOX_LEFT, BOX_RIGHT, TITLE_ROW, White, 'Load/Save Game Menu');
  SaveMenu.MoveTo(sel);
  if saving then
    action := 'Save'
  else
    action := 'Load';
  chosen := ' ';
  GameVars.horizChoice := OPT_TAKE;
  repeat
    { the slots' letters, and X for Exit (#910) }
    MenuCore.extraKeys := listed + EXIT_KEY;
    MenuCore.unmarked := [OPT_EXIT];
    MenuCore.enterToCaller := True;
    ch := MenuCore.MenuHorizontal('Game: ', 'Next Prev ' + action + ' Quit Exit', promptColor, optionColor,
                                  commandColor, True, False, ext);
    { Enter takes the bottom line's current option }
    if (not ext) and (ch = C_KEYS.ENTER) then
      case GameVars.horizChoice of
        OPT_NEXT: ch := 'N';
        OPT_PREV: ch := 'P';
        OPT_TAKE: ch := action[1];
        OPT_QUIT: ch := QUIT_CHOSEN;
      else
        ch := C_KEYS.NONE;
      end;
    if ext then
      case ch of
        C_KEYS.UP, C_KEYS.HOME: SaveMenu.MoveTo(sel - 1);
        C_KEYS.DOWN, C_KEYS.END_KEY: SaveMenu.MoveTo(sel + 1);
        { a screenful, stopping at the first or last slot rather than wrapping }
        C_KEYS.PAGE_UP: if sel > VISIBLE then
                       SaveMenu.MoveTo(sel - VISIBLE)
                     else
                       SaveMenu.MoveTo(1);
        C_KEYS.PAGE_DOWN: if sel + VISIBLE < count then
                       SaveMenu.MoveTo(sel + VISIBLE)
                     else
                       SaveMenu.MoveTo(count);
      end
    else if (ch = C_KEYS.NONE) or (ch = QUIT_CHOSEN) then
      chosen := ch
    else if ch = EXIT_KEY then
      chosen := C_KEYS.NONE
    else if ch = QUIT_KEY then
      chosen := QUIT_CHOSEN
    { a slot's letter takes it, as Save or Load on it does (#652) }
    else if (ch <> ' ') and (Pos(ch, listed) > 0) then
      chosen := ch
    else if ch = 'N' then
      SaveMenu.MoveTo(sel + 1)
    else if ch = 'P' then
      SaveMenu.MoveTo(sel - 1)
    else if ch = action[1] then
      chosen := listed[sel];
  until chosen <> ' ';
  TextRend.ClearBottomLine;
  ChooseSlot := chosen;
end;

{ Draw the description line: shown in white, the rest of its DESC_SHOWN columns as dots (the font's underscore is not a
  line). }
procedure DrawDescLine(shown: TSlotDesc);
var
  i: Byte;
begin
  TextRend.DisplayString(LEFT_COL, POP_DESC_ROW, White, shown);
  for i := Length(shown) + 1 to DESC_SHOWN do
    TextRend.DisplayString(LEFT_COL + i - 1, POP_DESC_ROW, LightGreen, '.');
end;

function AskDescription(letter: Char; area: TSlotArea; var desc: TSlotDesc): Boolean;
var
  s: TSlotDesc;
  default: TSlotDesc;
  key: Char;
begin
  { the list is cleared behind it: the slot and area on its second and third rows, the description on its fifth and
    sixth }
  Border.ClearBox(BOX_LEFT, LIST_TOP, BOX_RIGHT, LIST_BOTTOM);
  default := 'SAVE GAME ' + letter;
  TextRend.DisplayString(LEFT_COL, LIST_TOP + 1, LightGreen, default);
  TextRend.DisplayString(LEFT_COL, LIST_TOP + 2, LightGreen, 'Location: ' + area);
  TextRend.DisplayString(LEFT_COL, LIST_TOP + 4, LightGreen, 'Description:');
  s := Copy(desc, 1, DESC_SHOWN);
  TextRend.ClearBottomLine;
  { every letter goes to the description, so Exit has no hotkey: Escape takes it, and Enter saves (#657) }
  TextRend.DisplayString(0, 24, LightMagenta, 'Save: ');
  TextRend.DisplayString(6, 24, LightGreen, 'Exit');
  repeat
    if s = '' then
      SaveMenu.DrawDescLine(default)
    else
      SaveMenu.DrawDescLine(s);
    { an extended key's scan code is read with its #0: neither is typed }
    key := GameIo.ReadAnyKey;
    case key of
      ' '..'z':
        if Length(s) < DESC_SHOWN then
          s := s + UpCase(key);
      C_KEYS.BACKSPACE:
        if Length(s) > 0 then
          s := Copy(s, 1, Length(s) - 1);
    end;
  until (key = C_KEYS.ENTER) or (key = C_KEYS.ESCAPE);
  TextRend.ClearBottomLine;
  if s = '' then
    s := default;
  if key = C_KEYS.ENTER then
    desc := s;
  AskDescription := key = C_KEYS.ENTER;
end;

function SaveDiskMsg: Types.TStr40;
begin
  SaveDiskMsg := 'Put save disk in ' + GameVars.saveDirectory[1] + ': (Esc gives up)';
end;

function AskSaveDisk(problem: Types.TStr40; name: Types.TPathStr): Boolean;
begin
  AskSaveDisk := DaxIo.AskForDisk(problem, name, SaveMenu.SaveDiskMsg) <> C_KEYS.ESCAPE;
end;

procedure CheckSaveDir;
begin
  while not FileUtil.MakeFolder(GameVars.saveDirectory) and
        SaveMenu.AskSaveDisk('Cannot create', Copy(GameVars.saveDirectory, 1, Length(GameVars.saveDirectory) - 1)) do
    ;
end;

end.
