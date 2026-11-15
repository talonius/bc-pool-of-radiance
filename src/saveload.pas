{ Character files, saved games and party assembly. CHARLIST.TXT lists available characters; .cha/.itm/.spc files hold
  their records, inventory and effects, and a .mem file their usual spells. SAVGAMx.DAT stores the world and party
  state, with party members in CHRDATxN.sav files. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit SaveLoad;

interface

uses Types;

{ Loads CHARLIST.TXT into a newly allocated menu list. Party members are marked
  with a leading '* '. A missing or unreadable file produces an empty list. }
procedure LoadCharlist(var list: Types.PItemRec);

{ Rewrites CHARLIST.TXT, omitting the requested name when nonempty. Party marks
  are removed before writing, but party members remain on the roster (#754).
  Write through a temporary file so an error or full disk leaves the old roster
  intact. The player may retry with another save disk or press Escape. }
procedure SaveCharlist(list: Types.PItemRec; omit: String);

{ Load curChar's CHEAD into icon-anim slot 11 and CBODY into slot orderNumber, OR-merge head onto body; when loading,
  remap the default icon colours to the character's iconColors1 nibbles. Icons live on virtual disk 3. }
procedure LoadCharIconAnim(loading: Boolean);

{ Saves one character and its inventory, effects, usual spells, statistics, and
  extension data. An empty fname creates a standalone .cha character and adds
  it to CHARLIST.TXT; otherwise fname names a saved-game member's .sav file.

  All related files are committed together through temporary copies. A failed
  write leaves both the previous files and CHARLIST.TXT unchanged. }
function SaveChar(creature: Types.PCharRecord; fname: Types.TStr8): Boolean;

{ Erase a character's single-character files (.cha, .itm, .spc, .mem, .sts, .chx, those there are) and take its name off
  CHARLIST.TXT: a character dropped forever, whose files loading or saving a game no longer erases (#754). }
procedure EraseChar(name: String);

{ Loads a standalone character or a saved-game member. Rebuilds heap-based item
  and effect lists, then reads optional usual-spell, statistics, and extension
  files. Missing optional files are treated as empty.

  Returns False for a missing, unreadable, or short character record. The caller
  must then free the unused record. With Quick Ends With Fight enabled, loaded
  party members return to manual control; NPC and animation settings are kept. }
function LoadChar(name: String; creature: Types.PCharRecord; savedGame: Boolean): Boolean;

{ True when the character's single-character record, <saveDir><name>.cha (as SaveChar names it), is there. }
function HasCharFile(name: String): Boolean;

{ Opens the Load menu and restores the selected game. Rejects a short save before
  changing memory, skips missing or damaged party-member files, and reloads the
  map, wall sets, icons, and slot vault. Standalone character files and the
  current application settings are left alone. Escape cancels the load. }
procedure LoadGame;

{ Opens the Save menu, asks for a description, and writes the complete slot:
  world state, party members, slot information, statistics, explored map,
  notes, and vault. Every file is prepared first and committed as one set, so a
  failed write leaves the previous slot intact. Returns True only after a
  successful commit. The caller redraws the screen. }
function SaveGame: Boolean;

{ Confirms Exit to DOS. When askSave is set and the party has changed, offer to
  save first; cancelling that save also cancels the exit (#660). The caller
  redraws its screen if this routine returns. }
procedure QuitToDos(askSave: Boolean);

{ Quick save: save into SaveMenu.QUICK_SLOT, described as QUICK SAVE, with no menu, and say on the bottom line whether
  it was saved. }
procedure QuickSave;

{ True when SaveMenu.QUICK_SLOT holds a save file big enough to load, once a save into it that the game was ended in is
  undone (SaveMenu.RecoverSlot). }
function QuickLoadable: Boolean;

{ Quick load, between two runs of EclVm.GameLoop: free the party (records, items, effects, usual spells and icon
  animations), load SaveMenu.QUICK_SLOT as LoadGame loads a slot, and set loadedSave so the next GameLoop resumes it.
  With no loadable quick save it says so and frees nothing, and the next GameLoop resumes the game in memory. }
procedure QuickLoad;

{ Append to creatureList, make it current, give it the lowest free orderNumber (its icon-anim slot, 0..7), bump the GBVM
  party size and RecalcBaseSkills. }
procedure AddCharToParty(creature: Types.PCharRecord);

{ If name does not exist, offer 'Save and exit Insert disk #N'; on 'S' step the party back one square (0..15 wrap),
  restore the previous virtual disk, SaveGame and exit to DOS (GameIo.ExitGame). A save cancelled or not written puts
  the party and the disk back and offers the choice again. }
procedure CheckFileElseQuit(name: Types.TPathStr);

procedure FreeCreature(creature: Types.PCharRecord);

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Free every creature in the list, with its icon animation; the party size drops to 0 and curChar becomes nil. }
procedure FreeParty;

implementation

uses Dos, DiskRec, Crt, C_AREA, GameDefs, GameVars, Blit, TextRend, GameIo, MenuCore, Ending, ClassCal, View3D,
  MapTiles, C_KEYS, C_GBVM, SaveMenu, AreaName, Vault, Stats, DaxIo, CharHlp, FileUtil, Party, StrUtil,
  UsualSpl, VidOps, Explored, MapNotes, JrnlSeen, C_EFFECT, C_LEVEL, CharDisp, CharExt,
  BeastFil{$IFDEF FPC}, NatFile{$ENDIF}, UiColor;

type
  { the party's names in a savgam file: the CHRDATxN files they are kept in }
  TSaveNames = array[1..Types.MAX_PARTY] of Types.TStr40;

{ Create file name's temporary copy (FileUtil.RewriteTemp) for writing, asking for the save disk until it can be: False
  when Escape gave up (SaveMenu.AskSaveDisk), with nothing open. }
function RewriteSaveFile(var f: file; name: Types.TPathStr): Boolean;
var
  opened: Boolean;
begin
  repeat
    opened := FileUtil.RewriteTemp(f, name);
  until opened or not SaveMenu.AskSaveDisk('Cannot write', name);
  RewriteSaveFile := opened;
end;

{ A character's single-character files' base name, from its name, sanitized for DOS / with the save directory before
  it. }
function CharFileName(name: String): FileUtil.TSetName;
begin
  CharFileName := DaxIo.SanitizeFileName(name);
end;

function CharFileBase(name: String): Types.TPathStr;
begin
  CharFileBase := GameVars.saveDirectory + SaveLoad.CharFileName(name);
end;

function HasCharFile(name: String): Boolean;
begin
  HasCharFile := FileUtil.Exists(SaveLoad.CharFileBase(name) + '.cha');
end;

{ Nodes are TMenuNode-sized: the TItemRec prefix (name, inUse, next), not the full record. '* ' marks party members. }
procedure LoadCharlist(var list: Types.PItemRec);
var
  tail: Types.PItemRec;
  p: Types.PCharRecord;
  f: Text;
  ioRes: Integer;
  name: Types.TStr40;
begin
  list := nil;
  SaveMenu.CheckSaveDir;
  { a write the game was ended in is undone first }
  if not FileUtil.RecoverFile(GameVars.saveDirectory + 'charlist.txt') then Exit;
  if not FileUtil.Exists(GameVars.saveDirectory + 'charlist.txt') then Exit;
  { an error still pending would make the Reset do nothing }
  ioRes := IOResult;
  Assign(f, GameVars.saveDirectory + 'charlist.txt');
  Reset(f);
  if IOResult <> 0 then Exit;
  { a line that does not read ends the list, and leaves no error pending for the next file (SaveCharlist's) }
  ioRes := 0;
  while (ioRes = 0) and not Eof(f) do begin
    ReadLn(f, name);
    ioRes := IOResult;
    if ioRes = 0 then begin
      p := GameVars.creatureList;
      while (p <> nil) and (p^.name <> name) do
        p := p^.nextCharAddr;
      if p <> nil then
        name := '* ' + name;
      MenuCore.AppendMenuLine(list, tail, name, False);
    end;
  end;
  Close(f);
  ioRes := IOResult;
end;

procedure SaveCharlist(list: Types.PItemRec; omit: String);
var
  p: Types.PItemRec;
  f: Text;
  ioRes: Integer;
  name: String;
  fn: Types.TPathStr;
  ok: Boolean;
begin
  SaveMenu.CheckSaveDir;
  fn := GameVars.saveDirectory + 'charlist.txt';
  repeat
    { an error still pending would make the Rewrite do nothing }
    ioRes := IOResult;
    if FileUtil.MakeTempFolder(fn) then begin
      Assign(f, FileUtil.TempName(fn));
      Rewrite(f);
      ioRes := IOResult;
    end else
      ioRes := 3;
  until (ioRes = 0) or not SaveMenu.AskSaveDisk('Cannot write', fn);
  { Escape gave up: the roster stays as it was }
  if ioRes <> 0 then Exit;
  p := list;
  ok := True;
  while ok and (p <> nil) do begin
    name := p^.name;
    if Copy(name, 1, 2) = '* ' then
      Delete(name, 1, 2);
    if (Length(omit) = 0) or (name <> omit) then
      WriteLn(f, name);
    ok := IOResult = 0;
    p := p^.next;
  end;
  { the Close writes the last of it }
  Close(f);
  ok := (IOResult = 0) and ok;
  { a roster not written whole (a full disk) leaves the old one }
  if ok then
    ok := FileUtil.PutInPlace(fn)
  else
    FileUtil.DeleteFile(FileUtil.TempName(fn));
end;

procedure LoadCharIconAnim(loading: Boolean);
const
  { CHEAD/CBODY filename suffix indexed by iconSize: S for 1 (dwarf, gnome, halfling), T for 2 (tall races) }
  iconHeightSuffix: array[1..2] of Char = (
    'S',
    'T');
var
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  i: Byte;
  height: Byte;
begin
  DaxIo.PushState(3);
  with GameVars.curChar^ do begin
    { iconHeightSuffix is [1..2]; a monster's iconSize is 0 (LoadCreatureData sets it only for PC races), which v1.3
      read past the table and took as the small set }
    if iconSize = 2 then
      height := 2
    else
      height := 1;
    MapTiles.LoadIconAnim('CHEAD' + iconHeightSuffix[height], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + iconHeightSuffix[height], iconBody, orderNumber);
    VidOps.MergePic(GameVars.iconAnimation[11, 0], GameVars.iconAnimation[orderNumber, 0]);
    VidOps.MergePic(GameVars.iconAnimation[11, 1], GameVars.iconAnimation[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        fromMap[i] := i;
        toMap[i] := i;
      end;
      for i := 1 to 6 do begin
        toMap[GameDefs.defaultIconColors[i]] := iconColors1[i] and $F;
        toMap[GameDefs.defaultIconColors[i] + 8] := (iconColors1[i] and $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, GameVars.iconAnimation[orderNumber, 0]);
      Blit.RemapPic(fromMap, toMap, 0, False, GameVars.iconAnimation[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
end;

{ Write creature's record, items and effects to the temporary copies (FileUtil.TempName) of <base><ext>, <base>.itm and
  <base>.spc, and its usual spells, statistics and port fields to <base>.mem, .sts and .chx, adding each to save s (an
  empty list's file, and a .mem, .sts or .chx with nothing to hold, as one to erase): True when every one is whole. Else
  the copy that failed is not left, and the caller drops s. The records go out with their pointers cleared: loading
  rebuilds the lists from the .itm and .spc files, and the equipment slots from the items, so their values meant
  nothing, and a heap address made two saves of the same game differ. }
function WriteCharFiles(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName;
                        ext: Types.TStr8): Boolean;
var
  f: file;
  ok: Boolean;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  { the record as written: a copy with its pointers cleared, as below for each item and effect }
  rec: Types.TCharRecord;
  itemRec: Types.TItemRec;
  effectRec: Types.TEffectRec;
  { each as the file has it (DiskRec) }
  recDisk: DiskRec.TCharDisk;
  itemDisk: DiskRec.TItemDisk;
  effectDisk: DiskRec.TEffectDisk;
begin
  ok := SaveLoad.RewriteSaveFile(f, s.dir + base + ext);
  rec := creature^;
  rec.effectsAddr := nil;
  rec.itemsAddr := nil;
  rec.nextCharAddr := nil;
  rec.combatAddr := nil;
  FillChar(rec.equipped, SizeOf(rec.equipped), 0);
  DiskRec.CharToDisk(rec, recDisk);
  if ok then begin
    FileUtil.WriteChecked(f, recDisk, DiskRec.CHAR_DISK_BYTES, ok);
    ok := FileUtil.CloseTemp(f, s.dir + base + ext, ok);
    if ok then
      FileUtil.AddToSet(s, base + ext, True);
  end;
  if ok then
    if creature^.itemsAddr = nil then
      FileUtil.AddToSet(s, base + '.itm', False)
    else begin
      ok := FileUtil.RewriteTemp(f, s.dir + base + '.itm');
      if ok then begin
        item := creature^.itemsAddr;
        while ok and (item <> nil) do begin
          itemRec := item^;
          itemRec.next := nil;
          DiskRec.ItemToDisk(itemRec, itemDisk);
          FileUtil.WriteChecked(f, itemDisk, DiskRec.ITEM_DISK_BYTES, ok);
          item := item^.next;
        end;
        ok := FileUtil.CloseTemp(f, s.dir + base + '.itm', ok);
        if ok then
          FileUtil.AddToSet(s, base + '.itm', True);
      end;
    end;
  if ok then
    if creature^.effectsAddr = nil then
      FileUtil.AddToSet(s, base + '.spc', False)
    else begin
      ok := FileUtil.RewriteTemp(f, s.dir + base + '.spc');
      if ok then begin
        effect := creature^.effectsAddr;
        while ok and (effect <> nil) do begin
          effectRec := effect^;
          effectRec.next := nil;
          DiskRec.EffectToDisk(effectRec, effectDisk);
          FileUtil.WriteChecked(f, effectDisk, DiskRec.EFFECT_DISK_BYTES, ok);
          effect := effect^.next;
        end;
        ok := FileUtil.CloseTemp(f, s.dir + base + '.spc', ok);
        if ok then
          FileUtil.AddToSet(s, base + '.spc', True);
      end;
    end;
  WriteCharFiles := ok and UsualSpl.WriteUsualSpells(s, creature, base) and Stats.WriteChar(s, creature, base) and
                    CharExt.WriteExt(s, creature, base);
end;

{ Undo a single-character save of the character called name that the game was ended in before it was done
  (FileUtil.RecoverSet): True when nothing was left to undo. }
function RecoverChar(name: String): Boolean;
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, GameVars.saveDirectory);
  SaveMenu.RemoveCharFiles(s, SaveLoad.CharFileName(name), '.cha');
  RecoverChar := FileUtil.RecoverSet(s);
end;

{ Put save s in place (FileUtil.CommitSet) when ok, its files all written whole; else give it up (FileUtil.DropSet),
  leaving the old files as they were. True when s is in place. }
function CommitWhole(var s: FileUtil.TFileSet; ok: Boolean): Boolean;
begin
  if ok then
    ok := FileUtil.CommitSet(s)
  else
    FileUtil.DropSet(s);
  CommitWhole := ok;
end;

function SaveChar(creature: Types.PCharRecord; fname: Types.TStr8): Boolean;
var
  s: FileUtil.TFileSet;
  base: FileUtil.TSetName;
  ext: String[4];
  list: Types.PItemRec;
  p: Types.PItemRec;
  tail: Types.PItemRec;
  ok: Boolean;
  found: Boolean;
begin
  SaveMenu.CheckSaveDir;
  if Length(fname) = 0 then begin
    ext := '.cha';
    base := SaveLoad.CharFileName(creature^.name);
  end else begin
    ext := '.sav';
    base := fname;
  end;
  { a write that fails (a full disk) leaves the old files as they were }
  FileUtil.NewSet(s, GameVars.saveDirectory);
  ok := SaveLoad.CommitWhole(s, SaveLoad.WriteCharFiles(s, creature, base, ext));
  if not ok then
    TextRend.DisplayAndPause(Yellow, 'Could not save ' + Copy(creature^.name, 1, Types.NAME_LEN) + '.');
  if ok and (Length(fname) = 0) then begin
    { the name is added once: a party member's line, which LoadCharlist marks with '* ', is its own }
    SaveLoad.LoadCharlist(list);
    p := list;
    tail := nil;
    found := False;
    while p <> nil do begin
      if (p^.name = creature^.name) or (p^.name = '* ' + creature^.name) then
        found := True;
      tail := p;
      p := p^.next;
    end;
    if not found then begin
      MenuCore.AppendMenuLine(list, tail, creature^.name, False);
      SaveLoad.SaveCharlist(list, '');
    end;
    MenuCore.FreeStringList(list);
  end;
  SaveChar := ok;
end;

procedure EraseChar(name: String);
var
  s: FileUtil.TFileSet;
  list: Types.PItemRec;
  erased: Boolean;
begin
  FileUtil.NewSet(s, GameVars.saveDirectory);
  SaveMenu.RemoveCharFiles(s, SaveLoad.CharFileName(name), '.cha');
  erased := FileUtil.CommitSet(s);
  SaveLoad.LoadCharlist(list);
  if list <> nil then begin
    SaveLoad.SaveCharlist(list, name);
    MenuCore.FreeStringList(list);
  end;
end;

function LoadChar(name: String; creature: Types.PCharRecord; savedGame: Boolean): Boolean;
var
  f: file;
  res: Word;
  ext: String[4];
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  newItem: Types.PItemRec;
  newEffect: Types.PEffectRec;
  whole: Boolean;
  msg: Types.TStr40;
  found: Boolean;
  { each as the file has it (DiskRec) }
  recDisk: DiskRec.TCharDisk;
  itemDisk: DiskRec.TItemDisk;
  effectDisk: DiskRec.TEffectDisk;
begin
  { a single-character save the game was ended in gives the character back its old files }
  if not savedGame then
    found := SaveLoad.RecoverChar(name);
  { as SaveChar names it (CharFileBase) }
  name := SaveLoad.CharFileBase(name);
  msg := SaveMenu.SaveDiskMsg;
  if savedGame then
    ext := '.sav'
  else
    ext := '.cha';
  { Escape at the save disk prompt gives up on a character whose file is gone (#794) }
  found := DaxIo.OpenWithRetry(name + ext, msg, False, False, f);
  LoadChar := False;
  if not found then Exit;
  res := 0;
  { a short file overwrites only the record's start, as a read straight into it did }
  DiskRec.CharToDisk(creature^, recDisk);
  BlockRead(f, recDisk, DiskRec.CHAR_DISK_BYTES, res);
  whole := (IOResult = 0) and (res = DiskRec.CHAR_DISK_BYTES);
  DiskRec.CharFromDisk(recDisk, creature^);
  Close(f);
  creature^.nextCharAddr := nil;
  creature^.itemsAddr := nil;
  creature^.effectsAddr := nil;
  creature^.combatAddr := nil;
  LoadChar := whole;
  if not whole then Exit;
  if (GameVars.quickEnds <> 0) and CharHlp.ComesUnderPlayer(creature) then
    creature^.quickfight := 0;
  if FileUtil.Exists(name + '.itm') then begin
    found := DaxIo.OpenWithRetry(name + '.itm', msg, False, False, f);
    item := nil;
    whole := found;
    while whole and not Eof(f) do begin
      GetMem(newItem, SizeOf(Types.TItemRec));
      res := 0;
      BlockRead(f, itemDisk, DiskRec.ITEM_DISK_BYTES, res);
      whole := (IOResult = 0) and (res = DiskRec.ITEM_DISK_BYTES);
      if whole then begin
        DiskRec.ItemFromDisk(itemDisk, newItem^);
        newItem^.next := nil;
        if item = nil then
          creature^.itemsAddr := newItem
        else
          item^.next := newItem;
        item := newItem;
      end else
        FreeMem(newItem, SizeOf(Types.TItemRec));
    end;
    if found then
      Close(f);
  end;
  if FileUtil.Exists(name + '.spc') then begin
    found := DaxIo.OpenWithRetry(name + '.spc', msg, False, False, f);
    effect := nil;
    whole := found;
    while whole and not Eof(f) do begin
      GetMem(newEffect, SizeOf(Types.TEffectRec));
      res := 0;
      BlockRead(f, effectDisk, DiskRec.EFFECT_DISK_BYTES, res);
      whole := (IOResult = 0) and (res = DiskRec.EFFECT_DISK_BYTES);
      if whole then begin
        DiskRec.EffectFromDisk(effectDisk, newEffect^);
        newEffect^.next := nil;
        if effect = nil then
          creature^.effectsAddr := newEffect
        else
          effect^.next := newEffect;
        effect := newEffect;
      end else
        FreeMem(newEffect, SizeOf(Types.TEffectRec));
    end;
    if found then
      Close(f);
  end;
  { a paladin created by SSI's game, or before #742, has eff 8 as his own Protection from Evil (permanent, strength
    255): it becomes the 10' radius one character creation gives now }
  if creature^.classLevels[C_LEVEL.PALADIN] > 0 then begin
    effect := creature^.effectsAddr;
    while effect <> nil do begin
      if (effect^.id = C_EFFECT.PROTECTION_FROM_EVIL) and (effect^.duration = 0) and (effect^.strength = 255) then
        effect^.id := C_EFFECT.PROT_EVIL_10FT;
      effect := effect^.next;
    end;
  end;
  { the slots pointed into the heap of the game that saved them }
  CharHlp.LinkEquipped(creature);
  UsualSpl.ReadUsualSpells(creature, name);
  Stats.ReadChar(creature, name);
  CharExt.ReadExt(creature, name);
end;

procedure AddCharToParty(creature: Types.PCharRecord);
var
  p: Types.PCharRecord;
  used: array[0..Types.MAX_PARTY - 1] of Byte;
begin
  creature^.orderNumber := 255;
  if GameVars.creatureList = nil then
    GameVars.creatureList := creature
  else
    Party.LastCreature^.nextCharAddr := creature;
  FillChar(used, SizeOf(used), 0);
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..Types.MAX_PARTY - 1] then
      used[p^.orderNumber] := 1;
    p := p^.nextCharAddr;
  end;
  GameVars.curChar := creature;
  with GameVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < Types.MAX_PARTY) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GameVars.zone1^[C_GBVM.PARTY_SIZE]);
  ClassCal.RecalcBaseSkills(creature);
end;

{ The least a savgam file holds: everything LoadSlot reads from it. }
function SaveMinSize: LongInt;
begin
  SaveMinSize := LongInt(SizeOf(GameVars.diskIndex)) + SizeOf(GameVars.zone0^) + SizeOf(GameVars.zone1^) +
                 SizeOf(GameVars.zone2^) + C_GBVM.SAVED_SCRIPT_BYTES + SizeOf(GameVars.gMapX) +
                 SizeOf(GameVars.gMapY) + SizeOf(GameVars.gFacing) + SizeOf(GameVars.wallAhead) +
                 SizeOf(GameVars.eventAtCell) + SizeOf(GameVars.gLocType) + SizeOf(GameVars.ifcState) +
                 SizeOf(Byte) + SizeOf(TSaveNames);
end;

{ Load saved game letter: the save file (one too short to hold it all is refused, with a message, before anything is
  read), then each listed character, and the rest LoadGame describes. The party must be empty. }
procedure LoadSlot(letter: Char);
var
  names: TSaveNames;
  f: file;
  i: Byte;
  creature: Types.PCharRecord;
  fn: Types.TPathStr;
  res: Word;
  nChars: Byte;
  found: Boolean;
begin
  { a save the game was ended in gives the slot back its old one }
  found := SaveMenu.RecoverSlot(letter);
  found := DaxIo.OpenWithRetry(SaveMenu.SlotFile(letter, '.dat'), SaveMenu.SaveDiskMsg, True, False, f);
  TextRend.ClearBottomLine;
  { a save shorter than everything read below is refused before any of it replaces the game in memory }
  if found then begin
    found := (IOResult = 0) and (FileSize(f) >= SaveLoad.SaveMinSize) and (IOResult = 0);
    if not found then
      Close(f);
    res := IOResult;
  end;
  if not found then begin
    TextRend.DisplayAndPause(Yellow, 'Save game ' + letter + ' is damaged.');
    TextRend.ClearBottomLine;
    Exit;
  end;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  BlockRead(f, GameVars.diskIndex, SizeOf(GameVars.diskIndex), res);
  { disks 1..8 only }
  if not (GameVars.diskIndex in [1..Types.LAST_DISK]) then
    GameVars.diskIndex := 1;
  BlockRead(f, GameVars.zone0^, SizeOf(GameVars.zone0^), res);
  BlockRead(f, GameVars.zone1^, SizeOf(GameVars.zone1^), res);
  BlockRead(f, GameVars.zone2^, SizeOf(GameVars.zone2^), res);
  { the script the save holds is passed over: GameLoop loads the area's script from the data (#609) }
  Seek(f, FilePos(f) + C_GBVM.SAVED_SCRIPT_BYTES);
  { the party's map position: SSI's five bytes }
  BlockRead(f, GameVars.gMapX, SizeOf(GameVars.gMapX), res);
  BlockRead(f, GameVars.gMapY, SizeOf(GameVars.gMapY), res);
  BlockRead(f, GameVars.gFacing, SizeOf(GameVars.gFacing), res);
  BlockRead(f, GameVars.wallAhead, SizeOf(GameVars.wallAhead), res);
  BlockRead(f, GameVars.eventAtCell, SizeOf(GameVars.eventAtCell), res);
  { a cardinal facing only }
  GameVars.gFacing := GameVars.gFacing and 6;
  BlockRead(f, GameVars.gLocType, SizeOf(GameVars.gLocType), res);
  BlockRead(f, GameVars.ifcState, SizeOf(GameVars.ifcState), res);
  BlockRead(f, nChars, SizeOf(nChars), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  res := IOResult;
  { the vault left with this game is the session's vault now }
  Vault.RestoreFromSlot(letter);
  { the game's statistics (#611); a save made before them starts from none }
  Stats.ReadGame(SaveMenu.SlotFile(letter, '.sts'));
  Explored.ReadSlot(SaveMenu.SlotFile(letter, '.map'));
  MapNotes.ReadSlot(SaveMenu.SlotFile(letter, '.nts'));
  { what the party has found of the Journal (#1090); a save made before it keeps the whole Journal }
  JrnlSeen.ReadSlot(SaveMenu.SlotFile(letter, '.jnl'));
  { names holds MAX_PARTY, the most a party has }
  if nChars > Types.MAX_PARTY then
    nChars := Types.MAX_PARTY;
  { a name whose length byte is past its field is cut to it before it names a file (#917) }
  for i := 1 to nChars do
    found := StrUtil.FitLength(names[i], SizeOf(names[i]) - 1);
  { the save's speed and settings word are SSI's copies: the game keeps its own settings (POOLOPT.CFG) }
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := 0;
  for i := 1 to nChars do begin
    fn := SaveLoad.CharFileName(names[i]);
    if FileUtil.Exists(GameVars.saveDirectory + fn + '.sav') then begin
      GetMem(creature, SizeOf(Types.TCharRecord));
      { a short or unreadable .sav is left out, as a missing one is }
      if SaveLoad.LoadChar(fn, creature, True) then
        SaveLoad.AddCharToParty(creature)
      else
        FreeMem(creature, SizeOf(Types.TCharRecord));
      SaveMenu.CheckSaveDir;
    end;
  end;
  GameVars.curChar := GameVars.creatureList;
  while GameVars.curChar <> nil do begin
    SaveLoad.LoadCharIconAnim(True);
    GameVars.curChar := GameVars.curChar^.nextCharAddr;
  end;
  GameVars.curChar := GameVars.creatureList;
  { the disk number SaveGame stored at C_GBVM.DISK_NUM }
  GameVars.diskIndex := Lo(GameVars.zone1^[C_GBVM.DISK_NUM]);
  if not (GameVars.diskIndex in [1..Types.LAST_DISK]) then
    GameVars.diskIndex := 1;
  if GameVars.gLocType < C_AREA.LOC_WILD_WEST then
    View3D.Load3DMap(GameVars.zone0^.mapId.lo);
  if GameVars.gLocType > C_AREA.LOC_3D_MAP then
    MapTiles.LoadIconAnim('ICON', 0, 11)
  else
    for i := 1 to 3 do begin
      GameVars.wallSetCache[i].wallDefId := GameVars.zone0^.words[C_GBVM.WALLSLOT_ID + i];
      GameVars.wallSetCache[i].symbolSlot := GameVars.zone0^.words[C_GBVM.WALLSLOT_SLOT + i];
      if GameVars.wallSetCache[i].wallDefId >= 0 then
        View3D.LoadWallSet(GameVars.wallSetCache[i].wallDefId, GameVars.wallSetCache[i].symbolSlot);
    end;
  { the file's last wall slot shares the menu animation flag (#651), which no menu was showing when it was saved }
  GameVars.zone0^.savedWalls.menuAnimation := 0;
  if GameVars.zone0^.yarashPyramidLeft <> 0 then
    Ending.YarashComplete(False);
  TextRend.ClearBottomLine;
end;

procedure LoadGame;
var
  letter: Char;
begin
  SaveMenu.CheckSaveDir;
  repeat
    letter := SaveMenu.ChooseSlot(False, C_KEYS.NONE);
    if letter = SaveMenu.QUIT_CHOSEN then
      SaveLoad.QuitToDos(False);
  until letter <> SaveMenu.QUIT_CHOSEN;
  if letter <> C_KEYS.NONE then
    SaveLoad.LoadSlot(letter);
end;

procedure QuitToDos(askSave: Boolean);
begin
  if MenuCore.YesNoMenu('Exit to DOS? ', warnColor, optionColor, commandColor) = 'Y' then
    if not askSave or (GameVars.recentlySaved <> 0) or (GameVars.creatureList = nil) then
      GameIo.ExitGame
    else if MenuCore.YesNoMenu('Save first? ', warnColor, optionColor, commandColor) = 'N' then
      GameIo.ExitGame
    else if SaveLoad.SaveGame then
      GameIo.ExitGame;
  TextRend.ClearBottomLine;
end;

function QuickLoadable: Boolean;
var
  f: file;
  ioRes: Integer;
  recovered: Boolean;
begin
  QuickLoadable := False;
  recovered := SaveMenu.RecoverSlot(SaveMenu.QUICK_SLOT);
  if FileUtil.OpenReadOnly(f, SaveMenu.SlotFile(SaveMenu.QUICK_SLOT, '.dat')) then begin
    QuickLoadable := (FileSize(f) >= SaveLoad.SaveMinSize) and (IOResult = 0);
    Close(f);
  end;
  ioRes := IOResult;
end;

procedure QuickLoad;
begin
  { the party goes only when there is a game to replace it }
  if not SaveLoad.QuickLoadable then begin
    TextRend.DisplayAndPause(Yellow, 'There is no quick save.');
    TextRend.ClearBottomLine;
    { GameLoop resumes the game in memory, as after a load }
    GameVars.loadedSave := 1;
    Exit;
  end;
  SaveLoad.FreeParty;
  SaveLoad.LoadSlot(SaveMenu.QUICK_SLOT);
  { as CharGen.MainMenu does after a load: GameLoop keeps the loaded script }
  GameVars.loadedSave := 1;
  GameVars.locTypePrev := C_AREA.LOC_3D_MAP;
end;

{ Write saved game letter, with desc and area for its slot-info file: the rest SaveGame describes after the menu. Every
  file of the save is written to a temporary copy first, and only when every one is whole are they put in place of the
  old ones, all or none (FileUtil.CommitSet); else the old save is left as it was and the bottom line says the game was
  not saved. True when it was. What the Bestiary has learned is written then too, to its own file, which is no part of
  the save (#842). The demo's game is never saved (#1109): no menu there offers a save, and this writes nothing in it. }
function SaveToSlot(letter: Char; desc: SaveMenu.TSlotDesc; area: SaveMenu.TSlotArea): Boolean;
var
  names: TSaveNames;
  s: FileUtil.TFileSet;
  f: file;
  n: Byte;
  count: Byte;
  p: Types.PCharRecord;
  walls: Types.TGbvmSavedWalls;
  fn: Types.TPathStr;
  ok: Boolean;
  { the save file's copy was created: it is closed after the writes }
  opened: Boolean;
  { the date, which is not used: asking for it is what counts }
  year, month, day, weekDay: Word;
begin
  SaveToSlot := False;
  if GameVars.demoMode then Exit;
  { DOS stamps the save's files with its own date, which DOSBox-X moves past midnight only when a program asks for the
    date or time. The game reads the BIOS ticks instead (#469), so without this a game left running overnight saved
    with the day it started on (#1126). Natively the host's clock stamps them, and the call is harmless. }
  Dos.GetDate(year, month, day, weekDay);
  { the script a load reopens (#609): GameLoop records the running one only once the map menu returns, and NEWECL leaves
    the old area's there until then }
  GameVars.zone0^.previousScriptId := GameVars.eclScriptId;
  { the names' unused characters too, so a save holds nothing left over in memory }
  FillChar(names, SizeOf(names), 0);
  SaveMenu.CheckSaveDir;
  FileUtil.NewSet(s, GameVars.saveDirectory);
  fn := SaveMenu.SlotFile(letter, '.dat');
  { a save folder that cannot be written fails the save once Escape gives up (#794): nothing is written below }
  opened := SaveLoad.RewriteSaveFile(f, fn);
  ok := opened;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Saving...Please Wait');
  { the wall slots go in the file only (#651): in memory their words are the script's, the last of them the menu
    animation flag, which would set the next menu animating the last picture loaded over the view }
  walls := GameVars.zone0^.savedWalls;
  for n := 1 to 3 do begin
    GameVars.zone0^.words[C_GBVM.WALLSLOT_ID + n] := GameVars.wallSetCache[n].wallDefId;
    GameVars.zone0^.words[C_GBVM.WALLSLOT_SLOT + n] := GameVars.wallSetCache[n].symbolSlot;
  end;
  GameVars.zone0^.gameSpeed.value := GameVars.gameDelay;
  GameVars.zone0^.settings := (1 - GameVars.musicOn) * 4 + GameVars.portraitsAll * GameVars.monsterPics * 2 +
                               GameVars.portraitsAll * GameVars.portraitsOn;
  GameVars.zone1^[C_GBVM.DISK_NUM] := GameVars.diskIndex;
  FileUtil.WriteChecked(f, GameVars.diskIndex, SizeOf(GameVars.diskIndex), ok);
  FileUtil.WriteChecked(f, GameVars.zone0^, SizeOf(GameVars.zone0^), ok);
  GameVars.zone0^.savedWalls := walls;
  FileUtil.WriteChecked(f, GameVars.zone1^, SizeOf(GameVars.zone1^), ok);
  FileUtil.WriteChecked(f, GameVars.zone2^, SizeOf(GameVars.zone2^), ok);
  { SSI's part of the script buffer, so the file stays SSI's size }
  FileUtil.WriteChecked(f, GameVars.zone3^, C_GBVM.SAVED_SCRIPT_BYTES, ok);
  { the party's map position: SSI's five bytes }
  FileUtil.WriteChecked(f, GameVars.gMapX, SizeOf(GameVars.gMapX), ok);
  FileUtil.WriteChecked(f, GameVars.gMapY, SizeOf(GameVars.gMapY), ok);
  FileUtil.WriteChecked(f, GameVars.gFacing, SizeOf(GameVars.gFacing), ok);
  FileUtil.WriteChecked(f, GameVars.wallAhead, SizeOf(GameVars.wallAhead), ok);
  FileUtil.WriteChecked(f, GameVars.eventAtCell, SizeOf(GameVars.eventAtCell), ok);
  FileUtil.WriteChecked(f, GameVars.gLocType, SizeOf(GameVars.gLocType), ok);
  FileUtil.WriteChecked(f, GameVars.ifcState, SizeOf(GameVars.ifcState), ok);
  { names holds MAX_PARTY, the most a party has }
  count := 0;
  p := GameVars.creatureList;
  while (p <> nil) and (count < Types.MAX_PARTY) do begin
    Inc(count);
    names[count] := SaveMenu.MemberName(letter, count);
    p := p^.nextCharAddr;
  end;
  FileUtil.WriteChecked(f, count, SizeOf(count), ok);
  FileUtil.WriteChecked(f, names, SizeOf(names), ok);
  if opened then
    ok := FileUtil.CloseTemp(f, fn, ok);
  { the save file first: CommitSet puts it in place last, so a slot whose commit was ended part way has none }
  if ok then
    FileUtil.AddToSet(s, SaveMenu.SlotName(letter, '.dat'), True);
  { every member's files, while all are whole; the old files of a member the party no longer has go }
  p := GameVars.creatureList;
  for n := 1 to Types.MAX_PARTY do
    if n <= count then begin
      ok := ok and SaveLoad.WriteCharFiles(s, p, SaveMenu.MemberName(letter, n), '.sav');
      p := p^.nextCharAddr;
    end else
      SaveMenu.RemoveCharFiles(s, SaveMenu.MemberName(letter, n), '.sav');
  ok := ok and SaveMenu.WriteSlotInfo(s, letter, desc, area) and
        Stats.WriteGame(s, SaveMenu.SlotName(letter, '.sts')) and
        Explored.WriteSlot(s, SaveMenu.SlotName(letter, '.map')) and
        MapNotes.WriteSlot(s, SaveMenu.SlotName(letter, '.nts')) and
        JrnlSeen.WriteSlot(s, SaveMenu.SlotName(letter, '.jnl')) and Vault.AddToSave(s, letter);
  ok := SaveLoad.CommitWhole(s, ok);
  BeastFil.Flush;
  TextRend.ClearBottomLine;
  if ok then
    GameVars.recentlySaved := 1
  else begin
    TextRend.DisplayAndPause(Yellow, 'The game was not saved.');
    TextRend.ClearBottomLine;
  end;
  SaveToSlot := ok;
end;

function SaveGame: Boolean;
var
  letter: Char;
  desc: SaveMenu.TSlotDesc;
  area: SaveMenu.TSlotArea;
  oldArea: SaveMenu.TSlotArea;
  ok: Boolean;
begin
  SaveGame := False;
  SaveMenu.CheckSaveDir;
  area := AreaName.CurrentArea;
  letter := C_KEYS.NONE;
  repeat
    { back from the popup, the menu opens on the slot it was for }
    letter := SaveMenu.ChooseSlot(True, letter);
    if letter = C_KEYS.NONE then Exit;
    if letter = SaveMenu.QUIT_CHOSEN then begin
      SaveLoad.QuitToDos(False);
      letter := C_KEYS.NONE;
      ok := False;
    end else begin
      { an overwritten save's description is offered to edit; ReadSlotInfo leaves it empty for a slot with none, so
        whether it found one does not matter here }
      ok := SaveMenu.ReadSlotInfo(letter, desc, oldArea);
      ok := SaveMenu.AskDescription(letter, area, desc);
    end;
  until ok;
  SaveGame := SaveLoad.SaveToSlot(letter, desc, area);
end;

procedure QuickSave;
begin
  { a save that failed has said so }
  if SaveLoad.SaveToSlot(SaveMenu.QUICK_SLOT, 'QUICK SAVE', AreaName.CurrentArea) then begin
    TextRend.DisplayAndPause(LightGreen, 'Quick save done.');
    TextRend.ClearBottomLine;
  end;
end;

procedure CheckFileElseQuit(name: Types.TPathStr);
var
  msg: Types.TStr40;
  ch: Char;
  ext: Boolean;
  saving: Boolean;
  x: ShortInt;
  y: ShortInt;
  disk: Byte;
begin
  if FileUtil.Exists(name) then Exit;
  msg := 'Save and exit  Insert disk #' + StrUtil.NumStr(GameVars.diskIndex);
  repeat
    ch := MenuCore.MenuHorizontal('', msg, promptColor, optionColor, commandColor, False, False, ext);
    saving := (not ext) and (ch = 'S');
    if saving then begin
      x := GameVars.gMapX;
      y := GameVars.gMapY;
      disk := GameVars.diskIndex;
      Dec(GameVars.gMapX, GameDefs.dirDX[GameVars.gFacing]);
      Dec(GameVars.gMapY, GameDefs.dirDY[GameVars.gFacing]);
      View3D.WrapCoords(GameVars.gMapX, GameVars.gMapY);
      DaxIo.PopState;
      if SaveLoad.SaveGame then
        GameIo.ExitGame;
      { not saved: the party stands where it was, on the new disk, and chooses again over the redrawn view }
      GameVars.gMapX := x;
      GameVars.gMapY := y;
      GameVars.diskIndex := disk;
      CharDisp.DisplayNoncombatInterface;
    end;
  until not saving;
end;

{ Free the combat record, every item, every effect node, then the record itself, forgetting its usual spells and
  statistics. The caller's pointer is left as it was. }
procedure FreeCreature(creature: Types.PCharRecord);
var
  holdE: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  with creature^ do begin
    if (combatAddr <> nil) then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    CharHlp.FreeItemList(itemsAddr);
    effect := effectsAddr;
    while effect <> nil do begin
      holdE := effect;
      effect := effect^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  UsualSpl.ForgetUsualSpells(creature);
  Stats.Forget(creature);
  FreeMem(creature, SizeOf(Types.TCharRecord));
end;

{ Unlink curChar from the creature list and free it (and its icon animation if freeAnim); curChar becomes the next
  creature (head case) or the previous one (mid case), and the party size drops unless suppressSizeDec. A curChar not
  found in the list is left alone. When the creature removed was savedChar, savedChar follows the new curChar. }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PCharRecord;
  removed: Types.PCharRecord;
begin
  if GameVars.creatureList = nil then Exit;
  removed := GameVars.curChar;
  prev := GameVars.creatureList;
  if prev <> GameVars.curChar then begin
    while (prev^.nextCharAddr <> GameVars.curChar) and (prev^.nextCharAddr <> nil) do
      prev := prev^.nextCharAddr;
    if prev^.nextCharAddr <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GameVars.curChar^.orderNumber);
      prev^.nextCharAddr := GameVars.curChar^.nextCharAddr;
      SaveLoad.FreeCreature(GameVars.curChar);
      GameVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GameVars.zone1^[C_GBVM.PARTY_SIZE]);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GameVars.curChar^.orderNumber);
    GameVars.creatureList := GameVars.curChar^.nextCharAddr;
    prev := GameVars.curChar^.nextCharAddr;
    SaveLoad.FreeCreature(GameVars.curChar);
    GameVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GameVars.zone1^[C_GBVM.PARTY_SIZE]);
  end;
  { the script engine makes savedChar current again: never the freed record (SSI left it there, as Curse's #609) }
  if (GameVars.curChar <> removed) and (GameVars.savedChar = removed) then
    GameVars.savedChar := GameVars.curChar;
end;

procedure FreeParty;
begin
  { RemoveCreature frees the head of the list while it is curChar }
  while GameVars.creatureList <> nil do begin
    GameVars.curChar := GameVars.creatureList;
    SaveLoad.RemoveCreature(False, True);
  end;
  GameVars.curChar := nil;
end;

end.
