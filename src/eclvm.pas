{ Main game loop and ECL script interpreter. }
{$O+,F+}
{$I COMPILER.INC}
unit EclVm;

interface

{ Main game loop: set the interface state from the previous script id and view3dFlag, load (a saved game's too) and
  initialize the ECL script and run its on-load entry, then repeat the map menu, camp, search and movement until the
  party is defeated, a quick load is asked for (Explore.quickLoadAsked) or a game was loaded from the training hall's
  party menu (GameVars.loadedSave set); the program then runs it again on the loaded game. }
procedure GameLoop;

{ Clear the script engine's search-mode backup and its CLEAR BOX and PROTECTION flags, for a new game
  (GameInit.ResetGameState). }
procedure ResetGame;

{ Demo.Run's script (#1109): as GameLoop starts an area, load the demo's script (EclMenu.LoadEclScript, in demo mode)
  and run its on-load entry, which plays the whole demo; return when it ends or a key ends it (Reloading), without the
  map menu, and with the GOSUB return stack freed. }
procedure RunDemo;

implementation

uses Types, C_AREA, C_NPC, C_MSG, GameDefs, GameVars, Crt, Temple, PostCbt, Combat, Explore, CharGen, Ending, CharHlp,
  DaxIo, GameIo, C_ECL, C_LEVEL, C_IFC, C_GBVM, C_SOUND, C_MONEY, C_STATUS, C_TIME, VaultMnu, EclTrace, Border,
  Camp, EclMenu, FxEngine, MapTiles, MapView, MenuCore, RandItem, Portrait, SaveLoad, Shop, SoundDrv, TextRend, View3D,
  StrUtil, EclVars, CharDisp, Party, Dice, DiskRec, MoneyCal, Bestiary, Sage, MagicShp, EffHndlr,
  JrnlSeen, C_DEMO, Wilds{$IFDEF FPC}, TpRand{$ENDIF}, UiColor;

var
  { stop the VM and return control to the player }
  eclStop: Byte;
  { NEWECL ran; the game loop then calls NewEclDone }
  newEclFlag: Byte;
  { LOAD CHARACTER ran; restore curChar from savedChar }
  restoreChar: Byte;
  { LOADFILES or LOADPIECES ran (not that loading succeeded) }
  filesLoaded: Byte;
  { first LOADFILES/LOADPIECES pair still to draw the interface }
  enteringLoop: Byte;
  { LOADPIECES ran (not that loading succeeded) }
  piecesLoaded: Byte;
  { LOADFILES ran (not that loading succeeded) }
  mapLoaded: Byte;
  { monsters added by LOAD MONSTER since CLEAR MONSTERS (max 63) }
  creatureCnt: Byte;
  { Current monster ID }
  monId: Byte;
  { Current monster picture ID }
  monPicId: Byte;
  { Creature list contains hostile monsters flag }
  monstersOn: Byte;

const
  { LOAD MONSTER adds no monsters beyond this count }
  MAX_LOADED_MONSTERS = 63;

  { The WHO prompts that choose who duels, by script and the WHO's address, and where Escape on them sends the script:
    back to the PRINTCLEAR that asks the duel's question again (#661). SSI's WHO has no way out. }
  DUEL_WHOS = 3;
  DUEL_WHO: array[1..DUEL_WHOS] of record
    script: Byte;
    at: Word;
    back: Word;
  end = (
    { the New Phlan training hall's arena: "Do you duel?" }
    (script: 11; at: $9C72; back: $9C05),
    { the Pitt's tavern buccaneer: the Challenge Attack Flee Bribe menu }
    (script: 18; at: $A985; back: $A90D),
    { the Lizardman Keep champion: "Will you champion me?" }
    (script: 16; at: $A300; back: $A287));

  { training hall (class bitmask in C_GBVM.TRAIN_CLASS_MASK) }
  PROG_TRAINING = 0;
  PROG_WIN_GAME = 8;
  PROG_CAMP = 9;
  { the sage in New Phlan's east tavern (#868), whom a DataPat fix to New Phlan's script calls: no SSI script uses 10 }
  PROG_SAGE = 10;
  { the magic shop in New Phlan (#1091, #1158), whose stock a DataPat fix to New Phlan's script fills with it before
    entering the shop: no SSI script uses 11 }
  PROG_MAGIC_SHOP = 11;
  { the Commodore 64's end of the demo (#1109), which no PC script uses: in the demo it ends the script as EXIT does }
  PROG_DEMO_END = 3;
  { The ids of the three wilderness scripts; each selects a gLocType (C_AREA's LOC_WILD_WEST, LOC_WILD_CENTRAL or
    LOC_WILD_EAST). Their values equal C_ECL.IF_GT, C_ECL.IF_LE and C_ECL.IF_GE, but they are script ids, not opcodes. }
  { location type 2, Western Wilderness }
  WILD_WEST_SCRIPT = 25;
  { location type 3, Central Wilderness }
  WILD_CENTRAL_SCRIPT = 26;
  { location type 4, Eastern Wilderness }
  WILD_EAST_SCRIPT = 27;

var
  { Backup of the search-mode bit (C_GBVM.SEARCH_FLAGS bit 0) }
  searchModeFlag: Byte;
  { ECL 3D CLEAR BOX executed flag }
  ecl3dClearFlag: Byte;
  protNewLine: Byte;

procedure CallEclScript(address: Word); forward;

{ True when GameLoop is to return so the program starts it again on another game: a quick load was asked for, or a
  game was loaded from a script's party menu (GameVars.loadedSave, which GameLoop's EclInit clears); and in the demo,
  when a key ends it (GameIo.DemoEnding), which stops its script at the next command (#1109). }
function Reloading: Boolean;
begin
  Reloading := Explore.quickLoadAsked or (GameVars.loadedSave <> 0) or GameIo.DemoEnding;
end;

{ No monster loaded or set up: SETUP MONSTER sets the ids and CLEAR MONSTERS the count, but a script may APPROACH, LOAD
  MONSTER or fight before either has run. At startup, since Turbo Pascal clears no variable (#826), and at the start of
  every game, new or loaded, which would otherwise keep the last area's monsters (#829). The Bestiary starts a new
  encounter (#842). }
procedure ForgetMonsters;
begin
  Bestiary.NewEncounter;
  creatureCnt := 0;
  monId := 0;
  monPicId := 0;
  monstersOn := 0;
end;

{ Free the whole GOSUB return stack. }
procedure FreeEclStack;
begin
  while GameVars.scriptReturnStack <> nil do begin
    GameVars.prevScriptReturnStack := GameVars.scriptReturnStack^.next;
    FreeMem(GameVars.scriptReturnStack, SizeOf(Types.TEclRet));
    GameVars.scriptReturnStack := GameVars.prevScriptReturnStack;
  end;
end;

{ After a LOAD CHARACTER (restoreChar), make the character current before it (savedChar) current again; EXIT and
  PROGRAM do. }
procedure RestoreLoadedChar;
begin
  if restoreChar <> 0 then begin
    GameVars.curChar := GameVars.savedChar;
    restoreChar := 0;
  end;
end;

{ EXIT: redraw the borders if PROTECTION text was shown, restore the backed-up current character, clear the graphic
  flags, stop the VM, step past the opcode, free the whole GOSUB return stack and park the message cursor }
procedure EclExit;
begin
  if EclMenu.protTextShown <> 0 then begin
    Border.DrawWindow(1, 1, 15, 15, 0, White, '');
    if GameVars.zone0^.view3dFlag <> 0 then
      Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  end;
  EclVm.RestoreLoadedChar;
  FillChar(EclMenu.monsterFlags, SizeOf(EclMenu.monsterFlags), 0);
  GameVars.eclGraphics := False;
  EclMenu.protTextShown := 0;
  eclStop := 1;
  Inc(GameVars.eclIp);
  FreeEclStack;
  GameVars.curRow := C_MSG.MESSAGE_TOP;
  GameVars.curCol := C_MSG.TEXT_LEFT;
  ecl3dClearFlag := 0;
end;

{ GOTO: jump to var 1's address }
procedure EclGoto;
begin
  EclVars.LoadEclVars(1);
  GameVars.eclIp := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
end;

{ GOSUB: push the return address and jump to var 1's address }
procedure EclGosubCmd;
begin
  EclVars.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE: set the comparison flags from vars 1 and 2, as strings when either is a string (type bit 7 set) }
procedure EclCompare;
begin
  EclVars.LoadEclVars(2);
  if (GameVars.varTypes[1] >= $80) or (GameVars.varTypes[2] >= $80) then
    EclMenu.EclCompareStr(GameVars.gbStrings^[1], GameVars.gbStrings^[2])
  else
    EclMenu.EclCompareInt(EclVars.GetEclVar(1), EclVars.GetEclVar(2));
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: combine vars 1 and 2 and store the result at var 3's address. SUBTRACT computes
  var 2 - var 1. DIVIDE by zero stores 0; v1.3 divided anyway and halted with runtime error 200. }
procedure EclArith;
var
  address: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclVars.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclVars.GetEclVar(i);
  address := EclVars.CombineBytesToWord(GameVars.varLo[3], GameVars.varHi[3]);
  case GameVars.curOpcode of
    C_ECL.ADD: r := v[1] + v[2];
    C_ECL.SUBTRACT: r := v[2] - v[1];
    C_ECL.DIVIDE:
      if v[2] = 0 then
        r := 0
      else
        r := v[1] div v[2];
    C_ECL.MULTIPLY: r := v[1] * v[2];
  end;
  EclVars.WriteGbvm(address, r);
end;

{ RANDOM: store a random number from 0 to var 1 (0 to 254 when var 1 is 255) at var 2's address }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  n := EclVars.GetEclVar(1);
  if n < 255 then Inc(n);
  address := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  roll := Random(n);
  EclVars.WriteGbvm(address, roll);
end;

{ SAVE: store var 1, a number or a string (type bit 7 set), at var 2's address. A name given the current character
  (C_GBVM.CHAR_NAME, as #1113's data fix names the Valhingen mage) shows in the party list at once. }
procedure EclSave;
var
  v: Word;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  address := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  if GameVars.varTypes[1] < $80 then begin
    v := EclVars.GetEclVar(1);
    EclVars.WriteGbvm(address, v);
  end else begin
    EclVars.WriteGbvmString(address, GameVars.gbStrings^[1]);
    if address = C_GBVM.CHAR_NAME then
      CharDisp.DisplayParty(GameVars.curChar);
  end;
end;

{ LOAD CHARACTER: make creature number var 1 (low seven bits, 0 = the first) current; EXIT and PROGRAM restore the
  previous one. With bit 7 set, and dumpCr6C00 and dumpCr6B00 both set, the creature is removed from the party; an index
  that finds no one removes no one. }
procedure EclLoadChar;
var
  p: Types.PCharRecord;
  idx: Byte;
  i: Byte;
  flag80: Byte;
  { the member removed was savedChar }
  wasSaved: Boolean;
begin
  restoreChar := 1;
  EclVars.LoadEclVars(1);
  i := 0;
  idx := EclVars.GetEclVar(1);
  p := GameVars.creatureList;
  flag80 := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.nextCharAddr;
      Inc(i);
    end;
  if p <> nil then
    GameVars.curChar := p;
  if (flag80 <> 0) and GameVars.dumpCr6C00 and GameVars.dumpCr6B00 then begin
    { SSI removed the character current before when the index found no one (#759) }
    if p <> nil then begin
      wasSaved := GameVars.savedChar = GameVars.curChar;
      if wasSaved then
        restoreChar := 0;
      { the record is freed: RemoveCreature moves savedChar to the new current character, which EXIT, PROGRAM and
        NewEclDone then restore (SSI kept savedChar on the freed record, #759) }
      SaveLoad.RemoveCreature(False, True);
      CharDisp.DisplayParty(GameVars.curChar);
    end;
    GameVars.dumpCr6C00 := False;
    GameVars.dumpCr6B00 := False;
  end;
end;

{ SETUP MONSTER: set the monster id and picture, store the requested monster distance and the actual one (capped by
  MaxMonsterDist), then draw the monster }
procedure EclSetupMon;
begin
  EclVars.LoadEclVars(3);
  monId := EclVars.GetEclVar(1);
  GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ] := EclVars.GetEclVar(2);
  monPicId := EclVars.GetEclVar(3);
  GameVars.zone1^[C_GBVM.MONSTER_DIST] := EclMenu.MaxMonsterDist(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
  if GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ] < GameVars.zone1^[C_GBVM.MONSTER_DIST] then
    GameVars.zone1^[C_GBVM.MONSTER_DIST] := GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(monId, monPicId, Byte(GameVars.zone1^[C_GBVM.MONSTER_DIST]),
                         EclMenu.monsterFlags);
end;

{ LOAD MONSTER: load monster var 1 with EclMenu.InitCreature and append it to the creature list, then append var 2 - 1
  copies, each with its own copy of the item and effect lists (prepended, so in reverse order). All use the combat icon
  var 3, loaded into the next icon slot. Stops at 63 monsters, and loads none when the monster icon slots (8..12) are
  used up. The party has met the kind, fight or not (Bestiary.Met, #842). }
procedure EclLoadMon;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  tmpl: Types.TCharRecord;
  nm: String[12];
  item: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := GameVars.curChar;
  i := 1;
  EclVars.LoadEclVars(3);
  { at most 63 monsters, and an icon slot for them }
  if creatureCnt >= MAX_LOADED_MONSTERS then Exit;
  { SSI went on to slot 25, loading a sixth kind over the combat sprites (#724) }
  if EclMenu.iconAnimId > MapTiles.LAST_MONSTER_ICON then Exit;
  p := nil;
  q := nil;
  id := EclVars.GetEclVar(1);
  EclMenu.InitCreature(id, creature, item, ef);
  Bestiary.Met(creature);
  tmpl := creature^;
  invHead := item;
  effHead := ef;
  count := EclVars.GetEclVar(2);
  if count = 0 then count := 1;
  picId := EclVars.GetEclVar(3);
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, EclMenu.iconAnimId);
  p := Party.LastCreature;
  p^.nextCharAddr := creature;
  p := p^.nextCharAddr;
  p^.orderNumber := EclMenu.iconAnimId;
  p^.nextCharAddr := nil;
  Inc(creatureCnt);
  Inc(i);
  while (i <= count) and (creatureCnt < MAX_LOADED_MONSTERS) do begin
    GetMem(q, SizeOf(Types.TCharRecord));
    p^.nextCharAddr := q;
    p := p^.nextCharAddr;
    p^ := tmpl;
    p^.orderNumber := EclMenu.iconAnimId;
    p^.nextCharAddr := nil;
    p^.effectsAddr := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(creatureCnt);
    while item <> nil do begin
      CharHlp.PrependItemCopy(p^.itemsAddr, item);
      item := item^.next;
    end;
    item := invHead;
    while ef <> nil do begin
      CharHlp.PrependEffectCopy(p^.effectsAddr, ef);
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(EclMenu.iconAnimId);
  monstersOn := 1;
  GameVars.curChar := savedCur;
end;

{ APPROACH: bring the monster one step closer and redraw it }
procedure EclApproach;
begin
  if GameVars.zone1^[C_GBVM.MONSTER_DIST] > 0 then begin
    Dec(GameVars.zone1^[C_GBVM.MONSTER_DIST]);
    EclMenu.DisplayMonster(monId, monPicId, Byte(GameVars.zone1^[C_GBVM.MONSTER_DIST]),
                           EclMenu.monsterFlags);
  end;
  Inc(GameVars.eclIp);
end;

{ PICTURE: show picture var 1 in the view window, as an animation or a portrait depending on C_GBVM.PIC_LOADING. 255
  removes the picture, redrawing the map view when ECL graphics or a sprite were showing. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclVars.LoadEclVars(1);
  picId := EclVars.GetEclVar(1);
  { a picture goes in the 5x5 view's window, not over Move mode's wide view (#1186) }
  if picId <> 255 then
    CharDisp.SetWildView(False);
  if (GameVars.zone0^.view3dFlag = 0) and (picId <> 255) then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  if picId <> 255 then begin
    EclMenu.monsterFlags[1] := True;
    GameVars.eclGraphics := True;
    if GameVars.zone1^[C_GBVM.PIC_LOADING] = 255 then begin
      Portrait.LoadAnimation('PIC', picId, 0, GameVars.animData);
      Portrait.DisplayImageBuf(3, 3, True, GameVars.animData.frames[1].pic);
    end else
      EclMenu.DisplayPortrait(Byte(GameVars.zone1^[C_GBVM.PIC_LOADING]), picId);
  end else begin
    if ((GameVars.locTypePrev > C_AREA.LOC_3D_MAP) or (GameVars.gLocType = C_AREA.LOC_3D_MAP)) and
        (GameVars.eclGraphics or GameVars.sprShown) then begin
      MapView.DisplayMapView;
      GameVars.eclGraphics := False;
      GameVars.sprShown := False;
      EclMenu.picDrawn := True;
    end;
    EclMenu.monsterFlags[0] := False;
    EclMenu.monsterFlags[1] := False;
  end;
end;

{ INPUT NUMBER: read a number from the player into var 2's address }
procedure EclInputNum;
var
  q: String[1];
  v: Word;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  q := '';
  address := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  v := TextRend.ReadNumber(q, LightGreen);
  EclVars.WriteGbvm(address, v);
end;

{ INPUT STRING: read up to 40 characters into var 2's address; an empty answer is stored as one space }
procedure EclInputStr;
var
  q: String[1];
  address: Word;
  s: String;
begin
  EclVars.LoadEclVars(2);
  q := '';
  address := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  s := TextRend.ReadString(q, LightGreen, 40);
  if s = '' then s := ' ';
  EclVars.WriteGbvmString(address, s);
end;

{ PRINT / PRINTCLEAR: show var 1 (a number is converted to text) in the message window. PRINTCLEAR clears the window and
  starts at its top. The Journal notes the entries, tales and proclamations the text names (JrnlSeen.Scan, #1090). }
procedure EclPrint;
begin
  EclVars.LoadEclVars(1);
  Explore.bottomMessageCleared := 0;
  GameVars.msgDelayFlag := 1;
  if GameVars.varTypes[1] < $80 then
    GameVars.gbStrings^[1] := StrUtil.NumStr(EclVars.GetEclVar(1));
  JrnlSeen.Scan(GameVars.gbStrings^[1]);
  if GameVars.curOpcode = C_ECL.PRINT then
    TextRend.ShowMessage(LightGreen, False, GameVars.gbStrings^[1])
  else begin
    GameVars.curRow := C_MSG.MESSAGE_TOP;
    GameVars.curCol := C_MSG.TEXT_LEFT;
    TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM,
                                  LightGreen, True,
                                  GameVars.gbStrings^[1]);
  end;
  GameVars.msgDelayFlag := 0;
end;

{ RETURN: pop the GOSUB return stack into the IP. With an empty stack it only steps past the opcode. }
procedure EclReturn;
begin
  Inc(GameVars.eclIp);
  if GameVars.scriptReturnStack <> nil then begin
    GameVars.eclIp := GameVars.scriptReturnStack^.addr;
    GameVars.prevScriptReturnStack := GameVars.scriptReturnStack^.next;
    FreeMem(GameVars.scriptReturnStack, SizeOf(Types.TEclRet));
    GameVars.scriptReturnStack := GameVars.prevScriptReturnStack;
  end;
end;

{ COMPARE AND: set the eq flag when var 1 = var 2 and var 3 = var 4, else the ne flag }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(EclMenu.cmpFlags, SizeOf(EclMenu.cmpFlags), 0);
  EclVars.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclVars.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    EclMenu.cmpFlags[0] := True
  else
    EclMenu.cmpFlags[1] := True;
end;

{ IF: skip the next command unless the comparison flag for this opcode is set }
procedure EclIf;
begin
  Inc(GameVars.eclIp);
  case GameVars.curOpcode of
    C_ECL.IF_EQ: if not EclMenu.cmpFlags[0] then EclVars.SkipEclCmd;
    C_ECL.IF_NE: if not EclMenu.cmpFlags[1] then EclVars.SkipEclCmd;
    C_ECL.IF_LT: if not EclMenu.cmpFlags[2] then EclVars.SkipEclCmd;
    C_ECL.IF_GT: if not EclMenu.cmpFlags[3] then EclVars.SkipEclCmd;
    C_ECL.IF_LE: if not EclMenu.cmpFlags[4] then EclVars.SkipEclCmd;
    C_ECL.IF_GE: if not EclMenu.cmpFlags[5] then EclVars.SkipEclCmd;
  end;
end;

{ NEWECL: remember the current script id, check that the script archive is available (the merged ECL.DAX when it is in
  use), load and initialize script var 1, then stop the VM and set newEclFlag so the game loop runs its on-load entry
  (NewEclDone) }
procedure EclNewEcl;
var
  id: Byte;
{$IFDEF FPC}
  archive: Types.TStr20;
{$ENDIF}
begin
  EclVars.LoadEclVars(1);
  GameVars.zone0^.previousScriptId := GameVars.eclScriptId;
  id := EclVars.GetEclVar(1);
  GameVars.eclScriptId := id;
{$IFDEF FPC}
  { natively a merged archive is in the writable folder (#1064) }
  archive := DaxIo.ArchiveName('ECL' + StrUtil.NumStr(GameVars.diskIndex));
  SaveLoad.CheckFileElseQuit(DaxIo.FolderOf(archive) + archive + '.dax');
{$ELSE}
  SaveLoad.CheckFileElseQuit(GameVars.gameDir + DaxIo.ArchiveName('ECL' + StrUtil.NumStr(GameVars.diskIndex)) +
                             '.dax');
{$ENDIF}
  EclMenu.LoadEclScript(id);
  { a NEWECL inside a subroutine leaves return addresses on the stack, and EclInit only clears the pointer }
  FreeEclStack;
  EclMenu.EclInit;
  eclStop := 1;
  newEclFlag := 1;
  filesLoaded := 0;
end;

{ LOADFILES: load GEO map var 1 when view3dFlag <> 0, or the BACPAC tile set when view3dFlag = 0. LOADPIECES: load the
  wall sets in vars 1..3 (127 loads set 0; with both mapGraphics flags set only vars 1 and 3 are used); otherwise a 255
  slot clears its wall-def cache entry. Once both have run on entering the main loop, draw the noncombat interface and
  the party. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclVars.LoadEclVars(3);
  filesLoaded := 1;
  for i := 1 to 3 do
    f[i] := EclVars.GetEclVar(i);
  if GameVars.curOpcode = C_ECL.LOAD_FILES then begin
    mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) and (GameVars.zone0^.view3dFlag <> 0) then begin
      GameVars.zone0^.mapId.value := f[1];
      View3D.Load3DMap(f[1]);
      GameVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
    end;
    if (f[3] <> 255) and (GameVars.zone0^.view3dFlag = 0) then
      MapTiles.Load24x24Set('BACPAC', 0);
  end else begin
    piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GameVars.zone0^.mapGraphics1 <> 0) and (GameVars.zone0^.mapGraphics2 <> 0) then begin
      View3D.LoadWallSet(f[1], 1);
      View3D.LoadWallSet(f[3], 3);
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i)
        else begin
          GameVars.wallSetCache[i].wallDefId := -1;
          GameVars.wallSetCache[i].symbolSlot := -1;
        end;
  end;
  if (enteringLoop <> 0) and (piecesLoaded <> 0) and (mapLoaded <> 0) then begin
    CharDisp.DisplayNoncombatInterface;
    CharDisp.DisplayParty(GameVars.curChar);
    enteringLoop := 0;
  end;
end;

{ AND / OR: combine vars 1 and 2, truncate the result to a byte, set the comparison flags as for COMPARE 0 with the
  result, and store it at var 3's address }
procedure EclAndOr;
var
  address: Word;
  v2: Word;
  v1: Word;
  r: Byte;
begin
  EclVars.LoadEclVars(3);
  v1 := EclVars.GetEclVar(1);
  v2 := EclVars.GetEclVar(2);
  address := EclVars.CombineBytesToWord(GameVars.varLo[3], GameVars.varHi[3]);
  if GameVars.curOpcode = C_ECL.OP_AND then
    r := v1 and v2
  else
    r := v1 or v2;
  EclMenu.EclCompareInt(0, r);
  EclVars.WriteGbvm(address, r);
end;

{ GETTABLE: read the value at var 1's address + var 2 into var 3's address }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclVars.LoadEclVars(3);
  addr1 := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  idx := EclVars.GetEclVar(2);
  addr2 := EclVars.CombineBytesToWord(GameVars.varLo[3], GameVars.varHi[3]);
  sum := addr1 + idx;
  v := EclVars.ReadGbvm(sum);
  EclVars.WriteGbvm(addr2, v);
end;

{ SAVETABLE: store var 1 at var 2's address + var 3 }
procedure EclSaveTable;
var
  idx: Word;
  address: Word;
  v: Word;
  sum: Word;
begin
  EclVars.LoadEclVars(3);
  v := EclVars.GetEclVar(1);
  address := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  idx := EclVars.GetEclVar(3);
  sum := address + idx;
  EclVars.WriteGbvm(sum, v);
end;

{ VMENU: show the prompt, then a vertical menu of the var 3 strings that follow (at most 20), and store the chosen
  index at var 1's address once one is chosen }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  address: Word;
  { the key MenuVertical returns; the choice is idx and list }
  key: Char;
begin
  Explore.bottomMessageCleared := 0;
  redraw := True;
  q := '';
  i := 1;
  EclVars.LoadEclVars(3);
  address := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  msg := GameVars.gbStrings^[1];
  count := EclVars.GetEclVar(3);
  EclVars.LoadEclList(count);
  if count > Types.GB_STRING_LAST then
    count := Types.GB_STRING_LAST;
  MenuCore.AllocStringList(count, list);
  head := list;
  GameVars.curCol := C_MSG.TEXT_LEFT;
  GameVars.curRow := C_MSG.MESSAGE_TOP;
  TextRend.ShowMessage(LightGreen, True, msg);
  while list <> nil do begin
    list^.name := GameVars.gbStrings^[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  idx := 0;
  { the script needs a choice: Escape leaves list nil and idx on the highlighted line, which was stored as if chosen
    (#757), so the menu is shown again }
  repeat
    list := head;
    redraw := True;
    key := MenuCore.MenuVertical(q, q, promptColor, optionColor, commandColor, C_MSG.TEXT_LEFT, GameVars.curRow + 1,
                          C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, list, False, redraw, idx, list);
  until (list <> nil) or (head = nil);
  EclVars.WriteGbvm(address, idx);
  { the menu leaves list on the chosen line (nil on Escape), so free from the head }
  MenuCore.FreeStringList(head);
  TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
end;

{ HMENU: build a '~A ~B ~C' horizontal menu from the var 2 strings that follow (1 to 20) and store the chosen index at
  var 1's address. An option's hotkey is its first letter, or a later one no earlier option took when that one is taken
  (StrUtil.MarkHotkey), so every option can be chosen. A single choice also accepts Enter, and the joystick wording of
  the continue prompt becomes the keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  address: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
  { the hotkeys the options before this one took }
  taken: String;
begin
  q := '';
  menu := '';
  EclVars.LoadEclVars(2);
  address := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  count := EclVars.GetEclVar(2);
  EclVars.LoadEclList(count);
  { a count of 0 shows gbStrings^[1] alone }
  if count > Types.GB_STRING_LAST then
    count := Types.GB_STRING_LAST
  else if count = 0 then
    count := 1;
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := White;
    mCol := White;
    if GameVars.gbStrings^[1] = 'PRESS <RETURN> OR BUTTON TO CONTINUE' then
      GameVars.gbStrings^[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := White;
    mCol := LightGreen;
  end;
  anim := GameVars.eclGraphics and EclMenu.picDrawn;
  taken := '';
  for i := 1 to count - 1 do
    menu := menu + StrUtil.MarkHotkey(GameVars.gbStrings^[i], taken) + ' ';
  menu := menu + StrUtil.MarkHotkey(GameVars.gbStrings^[count], taken);
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclVars.WriteGbvm(address, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEAR MONSTERS: forget the loaded monsters, reset the monster icon slot, and clear the treasure money and items; the
  Bestiary's next meeting is a new encounter (#842) }
procedure EclClearMon;
begin
  Inc(GameVars.eclIp);
  Bestiary.NewEncounter;
  creatureCnt := 0;
  monstersOn := 0;
  EclMenu.iconAnimId := MapTiles.FIRST_MONSTER_ICON;
  CharHlp.ClearTreasure;
end;

{ PARTY STRENGTH: store the party's rating at var 1's address: (4*cleric + (hp + 5*(AC below 0) + 5*(THAC0 below 21)
  + 8*mage)) div 10 per member, from the stored 60-biased AC and THAC0. The sum is capped at 255; v1.3 kept it in a
  Byte, which wrapped. }
procedure EclPartyStr;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Word;
  address: Word;
  p: Types.PCharRecord;
begin
  EclVars.LoadEclVars(1);
  strength := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur;
    th := p^.thac0Cur;
    mage := p^.classLevels[C_LEVEL.MAGE];
    cleric := p^.classLevels[C_LEVEL.CLERIC];
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    Inc(strength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.nextCharAddr;
  end;
  address := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  if strength > 255 then
    strength := 255;
  EclVars.WriteGbvm(address, strength);
end;

{ CHECK PARTY: with var 1 = 0, report whether any member has effect var 2; with var 1 = C_GBVM.CHAR_FIND_TRAPS or
  C_GBVM.CHAR_MOVEMENT, report the party's lowest, highest and average value (all 0 for an empty list). The results go
  to the addresses of vars 3..6 (lowest, highest, average, found). }
procedure EclCheckParty;
var
  attr: Word;
  sum: Word;
  effId: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  effect: Types.PEffectRec;
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;
  value: Integer;

  { Store the three results and the found flag at the addresses of vars 3..6 }
  procedure Write4Gbvm;
  begin
    EclVars.WriteGbvm(addr1, outv[1]);
    EclVars.WriteGbvm(addr2, outv[2]);
    EclVars.WriteGbvm(addr3, outv[3]);
    EclVars.WriteGbvm(addr4, Ord(found));
  end;

begin
  EclVars.LoadEclVars(6);
  p := GameVars.creatureList;
  found := False;
  if GameVars.varTypes[1] = 1 then
    attr := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1])
  else
    attr := EclVars.GetEclVar(1);
  effId := EclVars.GetEclVar(2);
  addr1 := EclVars.CombineBytesToWord(GameVars.varLo[3], GameVars.varHi[3]);
  addr2 := EclVars.CombineBytesToWord(GameVars.varLo[4], GameVars.varHi[4]);
  addr3 := EclVars.CombineBytesToWord(GameVars.varLo[5], GameVars.varHi[5]);
  addr4 := EclVars.CombineBytesToWord(GameVars.varLo[6], GameVars.varHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  outv[3] := 0;
  case attr of
    0: begin
      while (p <> nil) and (not found) do begin
        found := CharHlp.HasEffect(p, effId, effect);
        p := p^.nextCharAddr;
      end;
      outv[1] := 0;
      Write4Gbvm;
    end;
    C_GBVM.CHAR_FIND_TRAPS, C_GBVM.CHAR_MOVEMENT: begin
      while p <> nil do begin
        Inc(count);
        if attr = C_GBVM.CHAR_FIND_TRAPS then
          value := p^.thiefSkills[C_GBVM.CHAR_FIND_TRAPS - C_GBVM.CHAR_THIEF_SKILLS + 1]
        else
          value := p^.movementCur;
        if value < outv[1] then
          outv[1] := value;
        if value > outv[2] then
          outv[2] := value;
        Inc(sum, value);
        p := p^.nextCharAddr;
      end;
      { SSI divided by the count unguarded, which an empty list would make a division by zero (#809) }
      if count = 0 then
        outv[1] := 0
      else
        outv[3] := sum div count;
      Write4Gbvm;
    end;
  end;
end;

{ PARTY SURPRISE: store 1 at var 1's address when the party has a ranger, else 0, and 0 at var 2's address }
procedure EclPartySurprise;
var
  p: Types.PCharRecord;
  mod1: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclVars.LoadEclVars(2);
  p := GameVars.creatureList;
  mod1 := 0;
  while p <> nil do begin
    if p^.classLevels[C_LEVEL.RANGER] > 0 then
      mod1 := 1;
    p := p^.nextCharAddr;
  end;
  addr1 := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  addr2 := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  EclVars.WriteGbvm(addr1, mod1);
  EclVars.WriteGbvm(addr2, 0);
end;

{ SURPRISE: roll 1d6 for each side against targets built from vars 1..4 and store the result at C_GBVM.SURPRISE, a
  bitmask combat reads (CbtActs): 1 when the first roll succeeds, 2 when the second does, 3 when both do (both sides
  surprised; SSI overwrote that 3 with 2, POR-0159), 0 when neither does. }
procedure EclSurprise;
var
  r1: Byte;
  r2: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  t1: ShortInt;
  t2: ShortInt;
begin
  EclVars.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do
    v[i] := EclVars.GetEclVar(i);
  t1 := v[4] + 2 - v[1];
  t2 := v[2] + 2 - v[3];
  r1 := Dice.RollDice(1, 6);
  r2 := Dice.RollDice(1, 6);
  if r1 <= t1 then
    result := 1;
  if r2 <= t2 then
    result := result or 2;
  EclVars.WriteGbvm(C_GBVM.SURPRISE, result);
end;

{ COMBAT: with no monsters and no duel, enter the shop when C_GBVM.ENTER_SHOP is 1, the vault when it is 2, or the
  temple when C_GBVM.ENTER_TEMPLE is 1 (MoneyCal.TEMPLE_FULL_PRICE) or 2 (TEMPLE_TENTH_OFF), else run
  PostCbt.PostCombat. Otherwise fight, then run PostCbt.PostCombat. Afterwards restore the interface state. }
procedure EclCombat;
var
  dist: Word;
  mode: Byte;
begin
  Inc(GameVars.eclIp);
  if (monstersOn = 0) and (not GameVars.duelFlag) then begin
    if GameVars.zone1^[C_GBVM.ENTER_SHOP] = 1 then begin
      GameVars.zone1^[C_GBVM.ENTER_SHOP] := 0;
      Shop.ShopMainMenu;
    end else if GameVars.zone1^[C_GBVM.ENTER_SHOP] = 2 then begin
      { New Phlan's vault, The Hoarder's Respite: the data patch for #606 stores 2 }
      GameVars.zone1^[C_GBVM.ENTER_SHOP] := 0;
      VaultMnu.VaultMenu;
    end else if (GameVars.zone1^[C_GBVM.ENTER_TEMPLE] = MoneyCal.TEMPLE_FULL_PRICE) or
        (GameVars.zone1^[C_GBVM.ENTER_TEMPLE] = MoneyCal.TEMPLE_TENTH_OFF) then begin
      { the Temple of Bane that Dirten rebuilds, a tenth off: the data patch for #682 stores 2 }
      mode := GameVars.zone1^[C_GBVM.ENTER_TEMPLE];
      GameVars.zone1^[C_GBVM.ENTER_TEMPLE] := 0;
      Temple.TempleMainMenu(mode);
    end else
      PostCbt.PostCombat;
  end else begin
    dist := EclMenu.MaxMonsterDist(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
    if dist < GameVars.zone1^[C_GBVM.MONSTER_DIST] then
      GameVars.zone1^[C_GBVM.MONSTER_DIST] := dist;
    Combat.CombatMain;
    PostCbt.PostCombat;
    if GameVars.zone0^.view3dFlag = 0 then begin
      MapTiles.Load24x24Set('BACPAC', 0);
      MapTiles.LoadWildIcons;
    end;
    GameVars.duelFlag := False;
  end;
  if GameVars.gLocType = C_AREA.LOC_3D_MAP then
    GameVars.ifcState := C_IFC.INDOORS
  else
    GameVars.ifcState := C_IFC.OVERLAND;
  GameVars.zone1^[C_GBVM.SEARCH_FLAGS] := GameVars.zone1^[C_GBVM.SEARCH_FLAGS] and 1;
  FillChar(EclMenu.monsterFlags, SizeOf(EclMenu.monsterFlags), 0);
  GameVars.eclGraphics := False;
  CharDisp.DisplayNoncombatInterface;
end;

{ ONGOTO / ONGOSUB: jump to or call address number var 1 of the var 2 addresses that follow (at most 64); a selector of
  var 2 or more, or 64 or more, falls through past the list }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  i: Byte;
  done: Boolean;
begin
  done := False;
  EclVars.LoadEclVars(2);
  sel := EclVars.GetEclVar(1);
  count := EclVars.GetEclVar(2);
  EclVars.LoadEclList(count);
  { 64 =High(varLo), the most addresses LoadEclVars keeps; a selector past them falls through }
  if count > 64 then
    count := 64;
  i := 0;
  while (i < count) and (not done) do begin
    if sel = i then begin
      if GameVars.curOpcode = C_ECL.ON_GOTO then
        GameVars.eclIp := EclVars.CombineBytesToWord(GameVars.varLo[i + 1], GameVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      done := True;
    end else
      Inc(i);
  end;
end;

{ TREASURE: set the treasure money from vars 1..7 and add items by var 8: below $80 it selects an ITEM archive list,
  $80+n generates n random items and 255 none. Item nodes are prepended, and a trailing part record in the list is
  ignored. A second roll of 48 or 49 (empty entries in ITEMS, not items) is rolled again; v1.3 picked no item id for
  it, so the item reused the previous item's id, or for the first item an uninitialised one. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  it: Types.TItemRec;
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  itemId: Byte;
  offset: Word;
  sizeRead: Word;
  data: Types.PByteArr;
begin
  EclVars.LoadEclVars(8);
  for i := C_MONEY.COPPER to C_MONEY.JEWELRY do
    GameVars.treasureMoney[i] := EclVars.GetEclVar(Byte(i) + 1);
  tId := EclVars.GetEclVar(8);
  if tId < $80 then begin
    DaxIo.LoadDax('ITEM' + StrUtil.NumStr(GameVars.diskIndex), '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    offset := 0;
    while sizeRead - offset >= DiskRec.ITEM_DISK_BYTES do begin
      DiskRec.ItemFromDisk(data^[offset], it);
      Inc(offset, DiskRec.ITEM_DISK_BYTES);
      CharHlp.PrependItemCopy(GameVars.treasureItems, @it);
    end;
    FreeMem(data, sizeRead);
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := Dice.RollDice(1, 100);
      case roll of
        1..60: begin
          repeat
            roll2 := Dice.RollDice(1, 100);
          until (roll2 <> 48) and (roll2 <> 49);
          case roll2 of
            1..47, 50..59:
              if roll2 = 45 then
                itemId := 59
              else
                itemId := roll2;
            60..90: begin
              roll2 := Dice.RollDice(1, 10);
              case roll2 of
                1..4: itemId := 36;
                5..7: itemId := 35;
                8: itemId := 34;
                9: itemId := 37;
                10: itemId := 38;
              end;
            end;
            91..94: itemId := 73;
            95..97: itemId := 93;
            98..100: itemId := 77;
          end;
        end;
        61..85: itemId := 61;
        86..92: itemId := 62;
        { SSI's arm read 91..98; 91 and 92 are matched above, and Free Pascal rejects a label used twice }
        93..98: begin
          roll3 := Dice.RollDice(1, 16);
          case roll3 of
            1..7: itemId := 71;
            8..9: itemId := 70;
            10: itemId := 84;
            11, 12: itemId := 78;
            13, 14: itemId := 79;
            15: itemId := 92;
            16: itemId := 67;
          end;
        end;
        99, 100: itemId := 69;
      end;
      RandItem.GenerateRandomItem(itemId, @it);
      CharHlp.PrependItemCopy(GameVars.treasureItems, @it);
    end;
    CharHlp.LabelItems(GameVars.treasureItems);
  end;
end;

{ ROB: take var 2 percent of the money (at most 100) and steal each item with a var 3 percent chance, from the current
  character or, when var 1 is nonzero, from every member; each robbed character's stats are recalculated. v1.3 used
  var 2 for the item chance as well, so a toll that only took coins (var 3 = 0) also stole items; Curse reads var 3. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  fraction: Real;
begin
  EclVars.LoadEclVars(3);
  whole := EclVars.GetEclVar(1);
  pct := EclVars.GetEclVar(2);
  if pct > 100 then
    pct := 100;
  fraction := (100 - pct) / 100;
  chance := EclVars.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GameVars.curChar);
    EclMenu.RobItems(chance, GameVars.curChar);
    CharHlp.RecalcStats(GameVars.curChar);
  end else begin
    p := GameVars.creatureList;
    while p <> nil do begin
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      CharHlp.RecalcStats(p);
      p := p^.nextCharAddr;
    end;
  end;
  { the party list shows the new armor class at once }
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ Run the encounter menu until combat, flight, parley or monster retreat ends it. WAIT and ADVANCE update the encounter
  and repeat; write the outcome to var 4's address: 0 = monsters flee, 1 = combat, 2 = party flees, 3 = parley }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  tried: Byte;
  address: Word;

  { The party closes in, or with the monsters at hand both sides wait; the menu comes round again. }
  procedure ApproachOrWait;
  begin
    if GameVars.zone1^[C_GBVM.MONSTER_DIST] <> 0 then begin
      Dec(GameVars.zone1^[C_GBVM.MONSTER_DIST]);
      EclMenu.DisplayMonster(monId, monPicId, Byte(GameVars.zone1^[C_GBVM.MONSTER_DIST]),
                             EclMenu.monsterFlags);
    end else
      TextRend.ShowMessage(LightGreen, True, 'Both sides wait.');
    waited := True;
  end;

  { The party closes in and the menu comes round again, or with the monsters at hand it is a parley (3). }
  procedure ApproachOrParley;
  begin
    if GameVars.zone1^[C_GBVM.MONSTER_DIST] <= 0 then
      EclVars.WriteGbvm(address, 3)
    else begin
      Dec(GameVars.zone1^[C_GBVM.MONSTER_DIST]);
      EclMenu.DisplayMonster(monId, monPicId, Byte(GameVars.zone1^[C_GBVM.MONSTER_DIST]),
                             EclMenu.monsterFlags);
      waited := True;
    end;
  end;

  { The monsters run (0). }
  procedure MonstersFlee;
  begin
    EclVars.WriteGbvm(address, 0);
    GameVars.curCol := C_MSG.TEXT_LEFT;
    GameVars.curRow := C_MSG.MESSAGE_TOP;
    TextRend.ShowMessage(LightGreen, True, 'The monsters flee.');
  end;

begin
  GameVars.inEncMenu := 1;
  Explore.bottomMessageCleared := 0;
  GameVars.msgDelayFlag := 1;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclVars.LoadEclVars(14);
  monId := EclVars.GetEclVar(1);
  GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ] := EclVars.GetEclVar(2);
  monPicId := EclVars.GetEclVar(3);
  address := EclVars.CombineBytesToWord(GameVars.varLo[4], GameVars.varHi[4]);
  for i := 0 to 4 do
    resp[i] := EclVars.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GameVars.gbStrings^[i];
  fleePar := EclVars.GetEclVar(13);
  fleeMon := EclVars.GetEclVar(14);
  GameVars.zone1^[C_GBVM.MONSTER_DIST] := EclMenu.MaxMonsterDist(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
  if GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ] < GameVars.zone1^[C_GBVM.MONSTER_DIST] then
    GameVars.zone1^[C_GBVM.MONSTER_DIST] := GameVars.zone1^[C_GBVM.MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(monId, monPicId, Byte(GameVars.zone1^[C_GBVM.MONSTER_DIST]),
                         EclMenu.monsterFlags);
  repeat
    anim := GameVars.eclGraphics and EclMenu.picDrawn;
    clearW := True;
    waited := False;
    GameVars.curCol := C_MSG.TEXT_LEFT;
    GameVars.curRow := C_MSG.MESSAGE_TOP;
    { the message for the distance, else the next one after it that is set, wrapping round the three }
    if GameVars.zone1^[C_GBVM.MONSTER_DIST] <= 2 then begin
      k := GameVars.zone1^[C_GBVM.MONSTER_DIST] + 1;
      tried := 0;
      repeat
        msg := msgs[k];
        Inc(k);
        if k > 3 then k := 1;
        Inc(tried);
      until (msg <> '') or (tried = 3);
    end;
    if msg = '' then
      clearW := False;
    TextRend.ShowMessage(LightGreen, clearW, msg);
    if (GameVars.zone1^[C_GBVM.MONSTER_DIST] = 0) or (GameVars.zone0^.view3dFlag = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, promptColor, optionColor, commandColor, False, anim);
    if ((GameVars.zone1^[C_GBVM.MONSTER_DIST] = 0) or (GameVars.zone0^.view3dFlag = 0)) and (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclVars.WriteGbvm(address, 1)
        else begin
          if loMove >= fleePar then
            EclVars.WriteGbvm(address, 2)
          else
            EclVars.WriteGbvm(address, 1);
        end;
      1:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1: begin
            waited := True;
            TextRend.ShowMessage(LightGreen, True, 'Both sides wait.');
          end;
          2: EclVars.WriteGbvm(address, 2);
          3: ApproachOrWait;
          4: ApproachOrParley;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then
              MonstersFlee
            else
              EclVars.WriteGbvm(address, 1);
          1..4: MonstersFlee;
        end;
      3:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1, 3: ApproachOrWait;
          2: EclVars.WriteGbvm(address, 2);
          4: ApproachOrParley;
        end;
      4:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1, 3, 4: ApproachOrParley;
          2: EclVars.WriteGbvm(address, 2);
        end;
    end;
  until not waited;
  TextRend.ClearRect(0, 24, 39, 24);
  GameVars.msgDelayFlag := 0;
  GameVars.inEncMenu := 0;
end;

{ PARLAY: offer the five attitudes, with a single space as the prompt, and store var (choice + 1) at var 6's address }
procedure EclParlay;
var
  sel: Byte;
  v5: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  address: Word;
  space: Char;
begin
  EclVars.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclVars.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', promptColor, optionColor,
                                  commandColor, False, False);
  address := EclVars.CombineBytesToWord(GameVars.varLo[6], GameVars.varHi[6]);
  v5 := v[sel];
  EclVars.WriteGbvm(address, v5);
end;

{ Set the eq comparison flag when found, else ne, and clear the others, as FIND ITEM and USE UP ITEM leave them. }
procedure SetFoundFlags(found: Boolean);
begin
  FillChar(EclMenu.cmpFlags, SizeOf(EclMenu.cmpFlags), 0);
  EclMenu.cmpFlags[0] := found;
  EclMenu.cmpFlags[1] := not found;
end;

{ FIND ITEM: set the eq comparison flag (else ne) if any party member carries an item var 1 selects
  (CharHlp.ItemSelected: a base item type, or C_ITEM.FIND_HOLY_SYMBOL) }
procedure EclFindItem;
var
  owner: Types.PCharRecord;
begin
  EclVars.LoadEclVars(1);
  EclVm.SetFoundFlags(CharHlp.FindPartyItem(EclVars.GetEclVar(1), owner) <> nil);
end;

{ USE UP ITEM (C_ECL.USE_UP_ITEM, not SSI's): use up one of the first item in party order that var 1 selects, as FIND
  ITEM selects it (CharHlp.UseUpItem: a stack loses one, anything else is gone, put away first when readied), and set
  the eq comparison flag; with none, the ne flag. The owner's stats and the party list follow at once. }
procedure EclUseUpItem;
var
  owner: Types.PCharRecord;
  item: Types.PItemRec;
begin
  EclVars.LoadEclVars(1);
  item := CharHlp.FindPartyItem(EclVars.GetEclVar(1), owner);
  EclVm.SetFoundFlags(item <> nil);
  if item <> nil then begin
    if (item^.quantity <= 1) and (item^.equipped <> 0) then
      FxEngine.UnreadyItem(owner, item);
    { a stack's weight is per piece, so it weighs less too }
    CharHlp.UseUpItem(owner, item);
    CharHlp.RecalcStats(owner);
    CharDisp.DisplayParty(GameVars.curChar);
  end;
end;

{ DELAY: pause for the text delay }
procedure EclDelay;
begin
  Inc(GameVars.eclIp);
  TextRend.PauseOnly;
end;

{ DAMAGE: apply scripted damage, then check for total party defeat. Without attack bit 7, attack counts attack rolls
  against random members (value is passed to FxEngine.AttackRollNoAttacker) and damage is rerolled after each roll. With
  bit 7, bit 6 selects the whole party, bit 5 skips whole-party saves, and the low five bits modify the save. value bit
  7 selects the current character instead of a random one; its low three bits select the save type. The
  current-character path subtracts one from that type, and type 0 there means no save. }
procedure EclDamage;
var
  attack: Byte;
  dieCount: Byte;
  sides: Byte;
  i: Byte;
  saveMod: Byte;
  value: Byte;
  bonus: Byte;
  count: Byte;
  saveType: Byte;
  k: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  allParty: Byte;
begin
  savedCur := GameVars.curChar;
  allParty := 0;
  p := GameVars.creatureList;
  EclVars.LoadEclVars(5);
  attack := EclVars.GetEclVar(1);
  dieCount := EclVars.GetEclVar(2);
  sides := EclVars.GetEclVar(3);
  bonus := EclVars.GetEclVar(4);
  value := EclVars.GetEclVar(5);
  dmg := bonus + Dice.RollDice(dieCount, sides);
  if attack and $40 <> 0 then
    allParty := 1
  else
    count := Dice.RollDice(1, Byte(GameVars.zone1^[C_GBVM.PARTY_SIZE]));
  if attack and $80 <> 0 then begin
    saveMod := attack and $1F;
    saveType := value and 7;
    if allParty <> 0 then begin
      while p <> nil do begin
        if attack and $20 <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else begin
          if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
            EclMenu.EclInflictDamage(dmg, p);
        end;
        p := p^.nextCharAddr;
      end;
    end else if value and $80 <> 0 then begin
      if (saveType = 0) or (not FxEngine.RollSavingThrow(GameVars.curChar, saveType - 1, saveMod)) then
        EclMenu.EclInflictDamage(dmg, GameVars.curChar);
    end else begin
      for i := 2 to count do
        p := p^.nextCharAddr;
      if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end else begin
    { a scripted volley is an encounter of its own: its first attack on a Cloak of Displacement's wearer misses,
      however the last combat left the cloak (#1183) }
    q := GameVars.creatureList;
    while q <> nil do begin
      EffHndlr.ResetDisplacement(q);
      q := q^.nextCharAddr;
    end;
    for i := 1 to attack do begin
      p := GameVars.creatureList;
      count := Dice.RollDice(1, Byte(GameVars.zone1^[C_GBVM.PARTY_SIZE]));
      k := 1;
      while k < count do begin
        p := p^.nextCharAddr;
        Inc(k);
      end;
      if FxEngine.AttackRollNoAttacker(p, value) then
        EclMenu.EclInflictDamage(dmg, p);
      dmg := bonus + Dice.RollDice(dieCount, sides);
    end;
  end;
  q := GameVars.creatureList;
  GameVars.partyDefeated := True;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GameVars.partyDefeated := False;
    q := q^.nextCharAddr;
  end;
  if GameVars.partyDefeated then begin
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'The END!');
    GameVars.curCol := 2;
    GameVars.curRow := 2;
    TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM,
                                  LightGreen, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GameVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, C_MSG.CONTINUE_PROMPT);
end;

{ SPRITE OFF: if a sprite is showing, redraw the map view over it }
procedure EclSpriteOff;
begin
  Inc(GameVars.eclIp);
  if GameVars.sprShown then begin
    MapView.DisplayMapView;
    GameVars.sprShown := False;
    GameVars.eclGraphics := False;
  end;
end;

{ CLOCK: advance the clock by var 1, in minutes, in steps of at most 255 (AdvanceTime takes a Byte). }
procedure EclClock;
var
  n: Word;
begin
  EclVars.LoadEclVars(1);
  n := EclVars.GetEclVar(1);
  while n > 255 do begin
    FxEngine.AdvanceTime(255, C_TIME.MINUTES);
    Dec(n, 255);
  end;
  FxEngine.AdvanceTime(n, C_TIME.MINUTES);
end;

{ PRINTRETURN: move the message cursor to the start of the next line and clear protNewLine }
procedure EclPrintRet;
begin
  Inc(GameVars.eclIp);
  GameVars.curCol := C_MSG.TEXT_LEFT;
  Inc(GameVars.curRow);
  protNewLine := 0;
end;

{ CLEAR BOX: clear the 3D view box and note it for PROTECTION }
procedure EclClearBox;
begin
  Inc(GameVars.eclIp);
  TextRend.ClearRect(1, 1, 15, 15);
  ecl3dClearFlag := 1;
end;

{ WHO: let the player pick a party member, prompting with var 1; the choice becomes the current character. A WHO that
  chooses who duels (DUEL_WHO) adds Exit: Exit or Escape picks no one and sends the script back to the duel's
  question. }
procedure EclWho;
var
  msg: String;
  at: Word;
  i: Byte;
  back: Word;
  picked: Types.PCharRecord;
begin
  at := GameVars.eclIp;
  back := 0;
  for i := 1 to DUEL_WHOS do
    if (DUEL_WHO[i].script = GameVars.eclScriptId) and (DUEL_WHO[i].at = at) then
      back := DUEL_WHO[i].back;
  EclVars.LoadEclVars(1);
  TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  msg := GameVars.gbStrings^[1];
  picked := GameVars.curChar;
  CharDisp.SelectChar(msg, back <> 0, picked);
  if picked = nil then
    GameVars.eclIp := back
  else
    GameVars.curChar := picked;
end;

{ ADD NPC: add creature var 1 to the party as an NPC whose npc byte is half the morale var 2 with bit 7 set. Monster id
  24 joins as hostile, every other id as friendly. A full party (8 members) takes nobody, and the current character is
  left as it was. In the demo (#1109) the NPC fights under Quick, as the whole party does there. }
procedure EclAddNpc;
var
  id: Byte;
  morale: Byte;
  partySize: Byte;
begin
  EclVars.LoadEclVars(2);
  id := EclVars.GetEclVar(1);
  partySize := GameVars.zone1^[C_GBVM.PARTY_SIZE];
  EclMenu.AddCreatureToParty(id);
  if GameVars.zone1^[C_GBVM.PARTY_SIZE] = partySize then Exit;
  morale := EclVars.GetEclVar(2);
  morale := morale div 2;
  morale := morale or C_NPC.FLAG;
  GameVars.curChar^.npc := morale;
  if id <> 24 then
    GameVars.curChar^.hostile := 0
  else
    GameVars.curChar^.hostile := 1;
  if GameVars.demoMode then
    GameVars.curChar^.quickfight := 1;
  CharHlp.RecalcStats(GameVars.curChar);
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ SPELL: find the first party member, in party order, who is okay and has spell var 1 memorized (not pending) in
  memorizedSpells[1..20]. Write the slot to var 2's address as its index - 1, which is how scripts reach it through the
  character window at C_GBVM.CHAR_MEMORIZED_FIRST (SpecialWriteZ1 maps it to memorizedSpells[1]), and the member's
  party position (0 = the first, as LOAD CHARACTER counts) to var 3's. With nobody found, the slot is 255.
  memorizedSpells[0] cannot be reached through the window, so it is not searched. Kovel Mansion's locked chest uses it
  for "Cast Knock". }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  k: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  addr1: Word;
  addr2: Word;
begin
  EclVars.LoadEclVars(3);
  spellId := EclVars.GetEclVar(1);
  addr1 := EclVars.CombineBytesToWord(GameVars.varLo[2], GameVars.varHi[2]);
  addr2 := EclVars.CombineBytesToWord(GameVars.varLo[3], GameVars.varHi[3]);
  slot := 255;
  idx := 0;
  found := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not found) do begin
    if p^.status = C_STATUS.OKAY then
      for k := 1 to SizeOf(p^.memorizedSpells) - 1 do
        if (not found) and (p^.memorizedSpells[k] = spellId) then begin
          found := True;
          slot := k - 1;
        end;
    if not found then begin
      p := p^.nextCharAddr;
      Inc(idx);
    end;
  end;
  EclVars.WriteGbvm(addr1, slot);
  EclVars.WriteGbvm(addr2, idx);
end;

{ CALL: dispatch ECL service calls by address (C_GBVM.CALL_*): refresh the view, start a duel or solo fight, play a
  sound, step forward, update the wall state, or, for the demo's C64 script (#1109), draw the picture's frame or show
  the picture's next frame. v1.3 cased on the address less $7FFF. }
procedure EclCall;
const
  { CALL_ANIMATE's shortest hold of a frame, in hundredths of a second }
  FRAME_LEAST = 25;
var
  address: Word;
  { how long CALL_ANIMATE holds its frame, in hundredths of a second }
  hold: LongInt;
begin
  EclVars.LoadEclVars(1);
  address := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  case address of
    C_GBVM.CALL_REFRESH_VIEW: begin
      GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
      if filesLoaded <> 0 then
        if GameVars.eclGraphics or GameVars.sprShown or GameVars.picRegionW or EclVars.movedParty or
            EclVars.redrawSky then begin
          MapView.DisplayMapView;
          CharDisp.PrintMiscInfo;
          EclVars.redrawSky := False;
          GameVars.picRegionW := False;
          EclVars.movedParty := False;
          GameVars.eclGraphics := False;
          GameVars.sprShown := False;
        end;
    end;
    { a fight gets the usual screen, not Move mode's wide view (#1186) }
    C_GBVM.CALL_MIRROR_DUEL: begin
      CharDisp.SetWildView(False);
      EclMenu.CharFightsAlone(1);
    end;
    C_GBVM.CALL_FIGHT_ALONE: begin
      CharDisp.SetWildView(False);
      EclMenu.CharFightsAlone(0);
    end;
    C_GBVM.CALL_SOUND: begin
      case EclVars.sndEffect of
        8: SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
        10: SoundDrv.SoundCommand(GameDefs.soundIds.combat[C_SOUND.ECL_CUE]);
      end;
    end;
    C_GBVM.CALL_MOVE_FORWARD:
      EclMenu.EclMoveForward;
    C_GBVM.CALL_WALL_AHEAD:
      if GameVars.gLocType = C_AREA.LOC_3D_MAP then
        GameVars.wallAhead := View3D.GetWallType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
    { the demo's script draws the picture's frame over the view CLEAR BOX emptied, as the C64 did; SSI's PC scripts
      call it too, where it does nothing, as in v1.3 }
    C_GBVM.CALL_VIEW_FRAME:
      if GameVars.demoMode then
        Border.DrawWindow(3, 3, 13, 13, 0, White, '');
    { the next frame of the picture in the view, held for the frame's time, as a menu animates it
      (MenuCore.HorizontalMenu), but at least FRAME_LEAST: the ogre's later frames have a time of 0, which a menu shows
      for one pass of its loop; a picture of one frame stays as it is }
    C_GBVM.CALL_ANIMATE:
      with GameVars.animData do
        if count > 1 then begin
          Inc(current);
          if (current < 1) or (current > count) then
            current := 1;
          Portrait.DisplayImageBuf(3, 3, True, frames[current].pic);
          hold := LongInt(frames[current].time) * 10;
          if hold < FRAME_LEAST then
            hold := FRAME_LEAST;
          TextRend.PauseTicks(hold);
        end;
  end;
end;

{ Run the pre-camp script entry (C_ECL.ENTRY_PRE_CAMP) and the camp menu, then the camp-interruption entry
  (C_ECL.ENTRY_CAMP_INTERRUPT) if camp was interrupted. Redraw the map view and clear recentlySaved. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_PRE_CAMP]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharDisp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_CAMP_INTERRUPT]);
  end;
  MapView.DisplayMapView;
  GameVars.recentlySaved := 0;
end;

{ PROGRAM: restore the backed-up current character, then run program var 1: PROG_TRAINING (the training hall menu),
  PROG_WIN_GAME, PROG_CAMP (camp with the IP preserved, then EXIT), PROG_SAGE (the sage's counsel, Sage.SageMenu,
  then the script goes on), PROG_MAGIC_SHOP (the magic shop's stock, MagicShp.StockShop, which the script then
  enters) or, in the demo, PROG_DEMO_END (EXIT). Other values do nothing. }
procedure EclProgram;
var
  v: Byte;
  savedIp: Word;
begin
  EclVm.RestoreLoadedChar;
  EclVars.LoadEclVars(1);
  v := EclVars.GetEclVar(1);
  case v of
    PROG_TRAINING: begin
      CharGen.MainMenu(True, False);
      { a game loaded from the menu (Load, once the party is empty) leaves this script, which v1.3 ran on over the
        loaded game: GameLoop returns and the program starts it again in the loaded area }
      if GameVars.loadedSave <> 0 then
        eclStop := 1
      else
        CharDisp.DisplayNoncombatInterface;
    end;
    PROG_WIN_GAME:
      Ending.WinGame;
    PROG_CAMP: begin
      savedIp := GameVars.eclIp;
      EclVm.EnterCamp;
      GameVars.eclIp := savedIp;
      EclVm.EclExit;
    end;
    PROG_SAGE:
      Sage.SageMenu;
    PROG_MAGIC_SHOP:
      MagicShp.StockShop;
    PROG_DEMO_END:
      if GameVars.demoMode then
        EclVm.EclExit;
  end;
end;

{ PROTECTION: draw the text at var 1's address at the message cursor; each byte is one less than its game-font glyph,
  and a $00 or $FF byte ends it, as does the right edge of the text area. After CLEAR BOX, text below row 13 moves into
  the 3D box and EXIT redraws its border. }
procedure EclProtection;
var
  address: Word;
  a: Word;
  i: Word;
  c: Byte;
  done: Boolean;
begin
  FillChar(EclMenu.monsterFlags, SizeOf(EclMenu.monsterFlags), 0);
  GameVars.eclGraphics := False;
  EclVars.LoadEclVars(1);
  address := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  i := 0;
  done := False;
  if (ecl3dClearFlag <> 0) and (GameVars.curRow > 13) then begin
    GameVars.curRow := 5;
    GameVars.curCol := 2;
    EclMenu.protTextShown := 1;
  end;
  protNewLine := 1;
  repeat
    a := address + i;
    c := EclVars.ReadGbvm(a) + 1;
    if c > 1 then begin
      TextRend.RenderChar(GameVars.curCol, GameVars.curRow, White, Black, 1, c, 0);
      Inc(GameVars.curCol);
      Inc(i);
    end else
      done := True;
  { v1.3 stopped only at the end byte, with a Byte offset that wrapped, so text with none looped forever }
  until done or (GameVars.curCol > C_MSG.TEXT_RIGHT);
  Inc(GameVars.curRow);
end;

{ Run the command at the IP (curOpcode). An opcode with no handler, such as C_ECL.UNUSED_1F, is stepped over as
  SkipEclCmd steps over it (its operands where SkipEclCmd knows them, otherwise the opcode byte alone); v1.3 left the
  IP on it, so CallEclScript ran it forever. }
procedure ExecNextEclCmd;
begin
  case GameVars.curOpcode of
    C_ECL.OP_EXIT: EclVm.EclExit;
    C_ECL.OP_GOTO: EclVm.EclGoto;
    C_ECL.GOSUB: EclVm.EclGosubCmd;
    C_ECL.COMPARE: EclVm.EclCompare;
    C_ECL.ADD, C_ECL.SUBTRACT, C_ECL.DIVIDE, C_ECL.MULTIPLY: EclVm.EclArith;
    C_ECL.OP_RANDOM: EclVm.EclRandom;
    C_ECL.SAVE: EclVm.EclSave;
    C_ECL.LOAD_CHARACTER: EclVm.EclLoadChar;
    C_ECL.LOAD_MONSTER: EclVm.EclLoadMon;
    C_ECL.SETUP_MONSTER: EclVm.EclSetupMon;
    C_ECL.APPROACH: EclVm.EclApproach;
    C_ECL.PICTURE: EclVm.EclPicture;
    C_ECL.INPUT_NUMBER: EclVm.EclInputNum;
    C_ECL.INPUT_STRING: EclVm.EclInputStr;
    C_ECL.PRINT, C_ECL.PRINT_CLEAR: EclVm.EclPrint;
    C_ECL.RETURN: EclVm.EclReturn;
    C_ECL.COMPARE_AND: EclVm.EclCompareAnd;
    C_ECL.VERTICAL_MENU: EclVm.EclVMenu;
    C_ECL.IF_EQ, C_ECL.IF_NE, C_ECL.IF_LT, C_ECL.IF_GT, C_ECL.IF_LE, C_ECL.IF_GE: EclVm.EclIf;
    C_ECL.CLEAR_MONSTERS: EclVm.EclClearMon;
    C_ECL.PARTY_STRENGTH: EclVm.EclPartyStr;
    C_ECL.CHECK_PARTY: EclVm.EclCheckParty;
    C_ECL.NEW_ECL: EclVm.EclNewEcl;
    C_ECL.LOAD_FILES, C_ECL.LOAD_PIECES: EclVm.EclLoadFiles;
    C_ECL.PARTY_SURPRISE: EclVm.EclPartySurprise;
    C_ECL.SURPRISE: EclVm.EclSurprise;
    C_ECL.OP_COMBAT: EclVm.EclCombat;
    C_ECL.ON_GOTO, C_ECL.ON_GOSUB: EclVm.EclOnGoto;
    C_ECL.TREASURE: EclVm.EclTreasure;
    C_ECL.ROB: EclVm.EclRob;
    C_ECL.ENCOUNTER_MENU: EclVm.EclEncounter;
    C_ECL.GET_TABLE: EclVm.EclGetTable;
    C_ECL.HORIZONTAL_MENU: EclVm.EclHMenu;
    C_ECL.PARLAY: EclVm.EclParlay;
    C_ECL.CALL: EclVm.EclCall;
    C_ECL.DAMAGE: EclVm.EclDamage;
    C_ECL.OP_AND, C_ECL.OP_OR: EclVm.EclAndOr;
    C_ECL.SPRITE_OFF: EclVm.EclSpriteOff;
    C_ECL.FIND_ITEM: EclVm.EclFindItem;
    C_ECL.PRINT_RETURN: EclVm.EclPrintRet;
    C_ECL.CLOCK: EclVm.EclClock;
    C_ECL.SAVE_TABLE: EclVm.EclSaveTable;
    C_ECL.ADD_NPC: EclVm.EclAddNpc;
    C_ECL.OP_PROGRAM: EclVm.EclProgram;
    C_ECL.WHO: EclVm.EclWho;
    C_ECL.OP_DELAY: EclVm.EclDelay;
    C_ECL.SPELL: EclVm.EclSpell;
    C_ECL.PROTECTION: EclVm.EclProtection;
    C_ECL.CLEAR_BOX: EclVm.EclClearBox;
    C_ECL.USE_UP_ITEM: EclVm.EclUseUpItem;
  else
    EclVars.SkipEclCmd;
  end;
end;

{ Runs commands at address until EXIT/NEWECL stops the VM or the party is defeated; nothing while GameLoop is to return
  for another game (Reloading) }
procedure CallEclScript(address: Word);
begin
  GameVars.eclIp := address;
  eclStop := 0;
  while (eclStop = 0) and (not GameVars.partyDefeated) and not EclVm.Reloading do begin
    GameVars.curOpcode := GameVars.zone3^[GameVars.eclIp];
    { STING Ctrl-L's trace log (#612), as Curse writes it }
    if GameVars.debugTraceEnabled then
      WriteLn(GameIo.debugFile, EclTrace.OpName(GameVars.curOpcode));
    { Move mode's wide view (#1186) stays for a command that draws no more than the message window, and goes for any
      other: a menu, a monster, combat or a new area gets the usual screen, with the party list }
    if Wilds.wideShown and not Wilds.KeepsWide(GameVars.curOpcode) then
      CharDisp.SetWildView(False);
    EclVm.ExecNextEclCmd;
  end;
  eclStop := 0;
end;

{ Refresh the event byte, run the new script's on-load entry (C_ECL.ENTRY_LOAD), and when view3dFlag = 0 set the
  location type for the three wilderness scripts (on the central one, call Ending.YarashComplete once the Yarash pyramid
  is done). Redraw, then run the C_ECL.ENTRY_MOVE entry and the search entry, and make the character current at the
  start (savedChar) current again. newEclFlag is cleared before the ENTRY_MOVE entry runs, so this repeats while that
  entry itself runs NEWECL. }
procedure NewEclDone;
begin
  repeat
    GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
    GameVars.zone1^[C_GBVM.LEAVE_MAP] := 0;
    { in GameVars, as in Curse, so removing it from the party moves it on (SSI kept its own copy, #759, #776) }
    GameVars.savedChar := GameVars.curChar;
    GameVars.locTypePrev := GameVars.gLocType;
    GameVars.gLocType := C_AREA.LOC_3D_MAP;
    EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_LOAD]);
    GameVars.ifcState := C_IFC.INDOORS;
    if GameVars.zone0^.view3dFlag = 0 then
      case GameVars.eclScriptId of
        WILD_WEST_SCRIPT: begin
          GameVars.gLocType := C_AREA.LOC_WILD_WEST;
          GameVars.ifcState := C_IFC.OVERLAND;
        end;
        WILD_CENTRAL_SCRIPT: begin
          GameVars.gLocType := C_AREA.LOC_WILD_CENTRAL;
          GameVars.ifcState := C_IFC.OVERLAND;
          if (GameVars.zone0^.yarashMissionDone = 254) and (GameVars.zone0^.yarashPyramidLeft = 0) then
            Ending.YarashComplete(True);
        end;
        WILD_EAST_SCRIPT: begin
          GameVars.gLocType := C_AREA.LOC_WILD_EAST;
          GameVars.ifcState := C_IFC.OVERLAND;
        end;
      end;
    if (GameVars.locTypePrev > C_AREA.LOC_3D_MAP) and (GameVars.gLocType = C_AREA.LOC_3D_MAP) then
      Border.DrawWindow(3, 3, 13, 13, 0, LightGreen, '');
    if (((GameVars.locTypePrev > C_AREA.LOC_3D_MAP) or (GameVars.gLocType = C_AREA.LOC_3D_MAP)) and
        (filesLoaded <> 0)) or
        ((GameVars.locTypePrev = C_AREA.LOC_3D_MAP) and (GameVars.gLocType = C_AREA.LOC_3D_MAP)) then
      MapView.DisplayMapView;
    newEclFlag := 0;
    EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_MOVE]);
    if newEclFlag = 0 then begin
      EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH]);
      GameVars.curChar := GameVars.savedChar;
      CharDisp.DisplayParty(GameVars.curChar);
    end;
  until newEclFlag = 0;
end;

{ Run the initial script, then process map, camp, search and movement actions until the party is defeated or GameLoop
  is to return for another game (Reloading). }
procedure GameLoop;
var
  cmd: Char;
begin
  piecesLoaded := 0;
  mapLoaded := 0;
  restoreChar := 0;
  filesLoaded := 0;
  enteringLoop := 1;
  ForgetMonsters;
  GameVars.ifcState := C_IFC.INDOORS;
  newEclFlag := 0;
  GameVars.eclScriptId := Byte(GameVars.zone0^.previousScriptId);
  case GameVars.eclScriptId of
    WILD_WEST_SCRIPT, WILD_CENTRAL_SCRIPT, WILD_EAST_SCRIPT:
      if GameVars.zone0^.view3dFlag = 0 then
        GameVars.ifcState := C_IFC.OVERLAND;
  end;
  { the area's script is loaded from the data even for a saved game (#609), as Secret of the Silver Blades does: the
    copy a save holds would keep a script from before a data fix (DataPat), and is SSI's size only }
  EclMenu.LoadEclScript(GameVars.eclScriptId);
  EclMenu.EclInit;
  EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_LOAD]);
  if GameVars.ifcState <> C_IFC.OVERLAND then begin
    if enteringLoop = 1 then begin
      CharDisp.DisplayNoncombatInterface;
      enteringLoop := 0;
    end;
    MapView.DisplayMapView;
  end;
  GameVars.zone0^.previousScriptId := GameVars.eclScriptId;
  while not GameVars.partyDefeated and not EclVm.Reloading do begin
    cmd := Explore.MapMainMenu;
    GameVars.savedChar := GameVars.curChar;
    GameVars.zone0^.previousScriptId := GameVars.eclScriptId;
    while ((GameVars.zone1^[C_GBVM.SEARCH_FLAGS] > 1) or (UpCase(cmd) = 'E')) and
        (not GameVars.partyDefeated) and not EclVm.Reloading do begin
      if UpCase(cmd) = 'E' then
        EclVm.EnterCamp
      else begin
        searchModeFlag := GameVars.zone1^[C_GBVM.SEARCH_FLAGS] and 1;
        GameVars.zone1^[C_GBVM.SEARCH_FLAGS] := 1;
        MapView.DisplayMapView;
        EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH]);
        if newEclFlag <> 0 then
          EclVm.NewEclDone;
        GameVars.zone1^[C_GBVM.SEARCH_FLAGS] := searchModeFlag;
      end;
      if not GameVars.partyDefeated and not EclVm.Reloading then begin
        cmd := Explore.MapMainMenu;
        GameVars.savedChar := GameVars.curChar;
      end;
    end;
    { a quick load asked for on the map menu, or a game loaded from a script's party menu, ends the loop at once: the
      program runs it again on that game }
    if not EclVm.Reloading then begin
      if not GameVars.partyDefeated then
        EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_MOVE]);
      if newEclFlag <> 0 then
        EclVm.NewEclDone
      else if not GameVars.partyDefeated and not EclVm.Reloading then begin
        GameVars.zone0^.previousX := GameVars.gMapX;
        GameVars.zone0^.previousY := GameVars.gMapY;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        { the step sound, which Explore.MovePartyForward3D has played too, but for a singleStep driver (POR-0170) }
        if (GameVars.gMapX <> GameVars.zone0^.previousX) or (GameVars.gMapY <> GameVars.zone0^.previousY) then
          SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
        GameVars.eclGraphics := False;
        EclMenu.picDrawn := True;
        EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH]);
        if newEclFlag <> 0 then
          EclVm.NewEclDone;
      end;
    end;
  end;
  GameVars.partyDefeated := False;
end;

procedure RunDemo;
begin
  piecesLoaded := 0;
  mapLoaded := 0;
  restoreChar := 0;
  filesLoaded := 0;
  enteringLoop := 1;
  newEclFlag := 0;
  ForgetMonsters;
  EclMenu.LoadEclScript(C_DEMO.SCRIPT_BLOCK);
  EclMenu.EclInit;
  EclVm.CallEclScript(GameVars.scriptEntryAddrs[C_ECL.ENTRY_LOAD]);
  { a key stops the script inside a GOSUB, whose return it never takes }
  FreeEclStack;
end;

procedure ResetGame;
begin
  searchModeFlag := 0;
  ecl3dClearFlag := 0;
  protNewLine := 0;
end;

begin
  ForgetMonsters;
end.
