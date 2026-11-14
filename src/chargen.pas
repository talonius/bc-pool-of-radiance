{ Character creation, modification and training, plus party management and the main menu. }
{$O+,F+}
{$I COMPILER.INC}
unit CharGen;

interface

{ The party menu: SSI's at start-up and after the party is destroyed, the two-column one at a training hall in a game in
  play (inGame), #885, and that one cut down to Train, View, Dual Class and Exit for Train Anywhere (anywhere, with
  inGame, #1212). }
procedure MainMenu(inGame, anywhere: Boolean);

{ F4 outside combat with the Train Anywhere setting on (#1212): the training hall's menu where the party stands
  (MainMenu, anywhere), training every class (CharHlp.HallMask) with every other rule of the hall: the fee, the
  experience, a level at a time, the Game Level Cap and the Non-Human Level Cap. No time passes. The portrait archive
  (GameVars.diskIndex), the interface state and the bottom line's option are put back after it; the caller draws its
  screen again. }
procedure TrainAnywhere;

{ The combat-icon editor for curChar: head, weapon, size and colours, each picked from a grid of the icon with every
  option; Keep keeps the icon, Exit puts it back as it was. }
procedure CustomizeIcon;

{ The portrait picker for curChar; canCancel lets Escape leave it with the portrait unchanged (camp's Alter). }
procedure CustomizePortrait(canCancel: Boolean);

{ True when curChar can be modified at all: a player race (Dwarf..Human, whose limits minimumMaximumStatistics holds;
  the hired Acolyte is race 0) and a class C_CLASS.CLERIC..MAGE_THIEF (0..16). }
function Modifiable: Boolean;

{ Arrow-key editor for curChar's six attributes and hit points (ModifyCharacterMenu's, which calls it for a character
  with no experience; the Companion Tools' character editor calls it for any Modifiable one). levelled: a Constitution
  change moves hpMax by the hit points it gives over every hit die (ClassCal.ConHpTotal), the hit-point row runs
  between ClassCal.HpMinimum and HpMaximum for the character's levels, and damage taken stays taken; Keep leaves
  npcTreasureShare as it is. }
procedure ModifyCharacter(levelled: Boolean);

{ Set curChar's hpMax to hp, but not below ClassCal.HpMinimum or 1, keeping the damage it has taken (hpCur not below
  0): ModifyCharacter's hit-point row, levelled, and the Companion Tools' lowered level. }
procedure SetHpMax(hp: Integer);

{ curChar gains a level in each class of trainable (GameDefs.classBits), with its hit points, as a training hall gives
  it; restoreDrain restores a drained level for each. The Companion Tools' editor raises levels with it too. }
procedure GainLevels(trainable: Byte; restoreDrain: Boolean);

implementation

uses Types, Crt, C_AREA, GameDefs, GameVars, SaveLoad, ViewChar, Border, C_CLASS, C_LEVEL, C_RACE, C_SPELL,
  C_KEYS, C_EFFECT, C_STATUS, C_IFC, C_GBVM, C_STAT, C_MONEY, Money, C_ALIGN, Options, Blit, CbtMap, CharHlp, ClassCal,
  DaxIo, FxEngine, MapTiles, MenuCore, Portrait, TextRend, StrUtil, CharDisp, MoneyCal, Party, Magic, C_MSG, Dice,
  VidOps, ChgClass, PartyMnu, CharExt, C_DEMO, Demo{$IFDEF FPC}, TpRand{$ENDIF};

const
  { Racial ability adjustments, by race and ability, added to each 3d6 roll before the racial limits apply. }
  raceAbilityAdj: array[C_RACE.DWARF..C_RACE.HUMAN] of Types.TRuleAbilities = (
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 1; charisma: -1), { dwarf }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 1; constitution: -1; charisma: 0), { elf }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0), { gnome }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0), { half-elf }
    (strength: -1; intelligence: 0; wisdom: 0; dexterity: 1; constitution: 0; charisma: 0), { halfling }
    (strength: 1; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 1; charisma: -2), { half-orc }
    (strength: 0; intelligence: 0; wisdom: 0; dexterity: 0; constitution: 0; charisma: 0)); { human }

var
  { STING training override. }
  stingMode: Byte;

const
  { The race screen's frames: the race list and the ability adjustments share rows 1..RACE_TOP_BOTTOM, on either side
    of the border column RACE_SPLIT_COL; the classes and their maximum levels fill the box below. }
  RACE_SPLIT_COL = 17;
  RACE_TOP_BOTTOM = 8;
  { the row of the first race, and of the first ability beside it }
  RACE_LIST_ROW = 2;

procedure CreateCharacterMenu; forward;
const
  { The oldest age in each age category, in years, by race }
  ageThresholds: array[1..7] of Types.TRuleAgeCategories = (
    (youngAdult: 50; mature: 150; middleAged: 250; old: 350; venerable: 450), { dwarf }
    (youngAdult: 175; mature: 550; middleAged: 875; old: 1200; venerable: 1600), { elf }
    (youngAdult: 90; mature: 300; middleAged: 450; old: 600; venerable: 750), { gnome }
    (youngAdult: 40; mature: 100; middleAged: 175; old: 250; venerable: 325), { half-elf }
    (youngAdult: 33; mature: 68; middleAged: 101; old: 144; venerable: 199), { halfling }
    (youngAdult: 15; mature: 30; middleAged: 45; old: 60; venerable: 80), { half-orc }
    (youngAdult: 20; mature: 40; middleAged: 60; old: 90; venerable: 120)); { human }
  startingGoldClass: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of Types.TRuleGold = (
    (num: 3; sides: 6), (num: 3; sides: 6), (num: 5; sides: 4), (num: 5; sides: 4),
    (num: 5; sides: 4), (num: 2; sides: 4), (num: 2; sides: 6), (num: 5; sides: 4));

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

procedure TrainingMenu; forward;

procedure AddCharacterMenu; forward;

{ MainMenu: The party menu, in one of its two forms (PartyMnu, #885). With inGame clear, the start-up menu (fixmain's,
  after the title screen and after the party is destroyed) is SSI's: the roster as SSI drew it, then the commands
  offered in one column (PartyMnu.DrawList, ChooseListed), and Home, End, Up and Down step through the party. With
  inGame set, a training hall's in a game in play (EclVm.EclProgram's PROG_TRAINING), it is the two-column menu of
  mocks/training-hall.txt (#879): the roster the mock's way (CharDisp.hallMenu), then the commands in two columns, the
  highlight on one and a command not offered in dark gray; PartyMnu.ChooseCmd reads a command's key, or Enter on the
  highlighted one, and Home and End step through the party (Party.SelectPrevNextChar). The commands offered are
  PartyMnu.OfferedCmds's: with no party Create, Add, Load, Settings and Exit to DOS; with one all but Load; Train only
  at a training hall or with free training on (#765), as SSI offered it; Dual Class on the two-column menu alone (#885),
  and there only with a character selected, dark gray without one. ChgClass.Refusal's reason, if any, shows on the
  bottom line for two seconds or until a key (TextRend.FlashBottomLine), and otherwise ChgClass.ChangeClassMenu opens
  for the character selected then. Returns once a loaded saved game leaves the main-menu
  state (setting loadedSave) or Begin Adventuring sets ifcState to 4 (C_IFC.INDOORS). Exit to DOS asks through
  SaveLoad.QuitToDos: with a party not saved since it changed, it asks to save first: Yes opens the save menu, and
  leaving it without saving stays in the menu; No quits unsaved (#660). Settings opens the Settings screen
  (Options.OptionsMenu). J sets stingMode when the first command-line parameter is STING. The start-up menu left alone
  with no party returns with GameVars.demoMode set, for FixMain to play the demo (#1109). Train Anywhere's menu
  (anywhere, #1212; PartyMnu.OfferedCmds) has Train, View and Dual Class, and its Exit, or Escape, returns. }
procedure MainMenu(inGame, anywhere: Boolean);
var
  ch: Char;
  ext: Boolean;
  ext2: Boolean;
  redraw: Boolean;
  { SaveGame's result: the menu goes on either way }
  saved: Boolean;
  { a training hall here, or free training on }
  atHall: Boolean;
  offered: PartyMnu.TCmdSet;
  { the highlighted command, and the row of the commands' headings, of the two-column menu }
  cur: Byte;
  top: Byte;
  refusal: Types.TStr40;
begin
  GameVars.diskIndex := 3;
  redraw := True;
  stingMode := 0;
  cur := PartyMnu.CMD_ADD;
  if anywhere then
    cur := PartyMnu.CMD_TRAIN;
  CharDisp.hallMenu := inGame;
  GameVars.ifcState := C_IFC.MAIN_MENU;
  while True do begin
    if redraw then begin
      Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, Black, '');
      atHall := (CharHlp.HallMask > 0) or (stingMode <> 0);
      PartyMnu.OfferedCmds(GameVars.curChar <> nil, atHall, inGame, anywhere, offered);
      top := PartyMnu.MENU_TOP;
      if GameVars.curChar <> nil then begin
        CharDisp.DisplayParty(Types.PCharRecord(GameVars.curChar));
        top := PartyMnu.MenuTop(GameVars.zone1^[C_GBVM.PARTY_SIZE]);
      end;
      if inGame then begin
        if not (cur in offered) then
          cur := PartyMnu.StepCmd(offered, cur, 1);
        PartyMnu.Draw(offered, top, cur);
      end else
        PartyMnu.DrawList(offered);
      redraw := False;
    end;

    if inGame then
      ch := PartyMnu.ChooseCmd(offered, top, cur, ext)
    else
      ch := PartyMnu.ChooseListed(offered, (GameVars.creatureList = nil) and Demo.Available, ext);
    TextRend.ClearBottomLine;
    if ext then begin
      { Home and End step through the party (Party.SelectPrevNextChar), and on SSI's menu Up and Down too }
      if (ch in [C_KEYS.HOME, C_KEYS.END_KEY]) or (not inGame and (ch in [C_KEYS.UP, C_KEYS.DOWN])) then begin
        Party.SelectPrevNextChar(ch);
        CharDisp.DisplayParty(Types.PCharRecord(GameVars.curChar));
      end else if ViewChar.AltItems(ch) then begin
        { Alt-n opened member n's items (#1195): the screen is drawn again, as after View }
        CharDisp.DisplayNoncombatInterface;
        redraw := True;
      end;
    end else if ch = C_DEMO.START_KEY then begin
      { the start-up menu left alone with no party (PartyMnu.ChooseListed): FixMain plays the demo (#1109) }
      GameVars.demoMode := True;
      Exit;
    end else begin
      { a command that may change the party marks it unsaved; Exit, Save, Settings and free training do not }
      if not (ch in ['E', 'S', 'G', 'J']) then
        GameVars.recentlySaved := 0;
      case ch of
        'C': CharGen.CreateCharacterMenu;
        'D': CharGen.DropCharacterMenu;
        'M': CharGen.ModifyCharacterMenu;
        'T': CharGen.TrainingMenu;
        'U': begin
               refusal := ChgClass.Refusal(GameVars.curChar, atHall);
               if refusal <> '' then
                 TextRend.FlashBottomLine(Yellow, refusal)
               else
                 ChgClass.ChangeClassMenu(stingMode <> 0);
             end;
        'V': ViewChar.ViewCharMenu(ext2);
        'A': CharGen.AddCharacterMenu;
        'R': if GameVars.curChar <> nil then
             begin
               { a character whose save failed stays in the party }
               if SaveLoad.SaveChar(Types.PCharRecord(GameVars.curChar), '') then
                 SaveLoad.RemoveCreature(False, True);
             end;
        'L': begin
               SaveLoad.LoadGame;
               if GameVars.ifcState <> C_IFC.MAIN_MENU then begin
                 GameVars.loadedSave := 1;
                 Exit;
               end;
             end;
        'S': if GameVars.creatureList <> nil then
               saved := SaveLoad.SaveGame;
        'B': if GameVars.creatureList <> nil then
             begin
               GameVars.ifcState := C_IFC.INDOORS;
               TextRend.ClearBottomLine;
               Exit;
             end;
        'G': Options.OptionsMenu;
        'E': if anywhere then
               Exit
             else
               SaveLoad.QuitToDos(True);
        { free training, turned on and off as in Curse }
        'J': if GameVars.stingArg then
             begin
               stingMode := Ord(stingMode = 0);
               if stingMode <> 0 then
                 CharDisp.PrintBottomLine('Free training on')
               else
                 CharDisp.PrintBottomLine('Free training off');
             end;
      end;
      redraw := True;
    end;
  end;
end;

procedure TrainAnywhere;
var
  savedDisk: Byte;
  savedIfc: Byte;
  savedChoice: Byte;
  savedHall: Boolean;
begin
  savedDisk := GameVars.diskIndex;
  savedIfc := GameVars.ifcState;
  savedChoice := GameVars.horizChoice;
  savedHall := CharDisp.hallMenu;
  GameVars.trainingAnywhere := True;
  CharGen.MainMenu(True, True);
  GameVars.trainingAnywhere := False;
  GameVars.diskIndex := savedDisk;
  GameVars.ifcState := savedIfc;
  GameVars.horizChoice := savedChoice;
  CharDisp.hallMenu := savedHall;
  TextRend.ClearBottomLine;
end;

{ ShowRaceInfo: Fill the race screen's panes for race: its ability adjustments (raceAbilityAdj) beside the race
  list, and below, the single classes the race may take with the rule book's maximum level in each
  (raceMaxLevel; U for no maximum), and beside them the race's multiclasses, abbreviated. A single class is one
  ClassCal.classesByRace offers alone or as part of a multiclass. A multiclass trains each part to the same maximum,
  which the note at the foot of the box says; a race without multiclasses shows neither the note nor the multiclass
  heading. The note sits under the single classes, so the multiclasses may run on beside it to the foot of the box. A
  race outside Dwarf..Human leaves the panes blank. }
procedure ShowRaceInfo(race: ShortInt);
const
  { by classLevels index }
  PART_ABBREVS: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of String[2] = (
    'CL', 'DR', 'FI', 'PA', 'RA', 'MU', 'TH', 'MO');
  ABIL_COL = 19;
  ADJ_COL = 23;
  HEADING_ROW = 11;
  { the data starts a row below the headings; the single classes end above the note's two rows, and the multiclasses,
    right of the note, at the foot of the box }
  FIRST_ROW = 13;
  LAST_ROW = 19;
  NOTE_ROW = 20;
  LAST_MULTI_ROW = 21;
  MAX_COL = 2;
  MAX_VALUE_COL = 3;
  CLASS_COL = 7;
  MULTI_COL = 21;
  LAST_COL = 38;
  { The rule book's racial level maximums (Character Race Limits), by race and classLevels index: 0 is no maximum (U)
    and -1 a class the race cannot take. A fighter's or ranger's is the best case, with Strength 18. Half-orcs are not
    offered at creation, so their row is empty. With the Non-Human Level Cap setting off every class a race can take
    shows U. }
  raceMaxLevel: array[C_RACE.DWARF..C_RACE.HUMAN] of Types.TRuleClassLevels = (
    { dwarf }
    (cleric: -1; druid: -1; fighter: 9; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { elf }
    (cleric: -1; druid: -1; fighter: 7; paladin: -1; ranger: -1; mage: 11; thief: 0; monk: -1),
    { gnome }
    (cleric: -1; druid: -1; fighter: 6; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { half-elf }
    (cleric: 5; druid: -1; fighter: 8; paladin: -1; ranger: 8; mage: 8; thief: 0; monk: -1),
    { halfling }
    (cleric: -1; druid: -1; fighter: 6; paladin: -1; ranger: -1; mage: -1; thief: 0; monk: -1),
    { half-orc }
    (cleric: -1; druid: -1; fighter: -1; paladin: -1; ranger: -1; mage: -1; thief: -1; monk: -1),
    { human }
    (cleric: 0; druid: -1; fighter: 0; paladin: 0; ranger: 0; mage: 0; thief: 0; monk: -1));
var
  i: ShortInt;
  slot: Byte;
  cnt: Byte;
  cls: ShortInt;
  row: Byte;
  adj: ShortInt;
  s: String;
  p: Byte;
  part: ShortInt;
  lvl: ShortInt;
  hasMulti: Boolean;
  isSingle: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of Boolean;
begin
  Border.ClearBox(ADJ_COL, RACE_LIST_ROW, LAST_COL, RACE_LIST_ROW + C_STAT.CHARISMA);
  Border.ClearBox(1, HEADING_ROW, LAST_COL, NOTE_ROW + 1);
  if (race < C_RACE.DWARF) or (race > C_RACE.HUMAN) then
    Exit;
  for i := C_STAT.STRENGTH to C_STAT.CHARISMA do begin
    TextRend.DisplayString(ABIL_COL, RACE_LIST_ROW + i, LightGreen, GameDefs.abilityNames[i]);
    adj := raceAbilityAdj[race].values[i];
    if adj > 0 then
      s := '+' + StrUtil.NumStr(adj)
    else if adj < 0 then
      s := '-' + StrUtil.NumStr(-adj)
    else
      s := ' 0';
    TextRend.DisplayString(ADJ_COL, RACE_LIST_ROW + i, LightGreen, s);
  end;
  { the multiclasses on the right, noting every part as a single class }
  FillChar(isSingle, SizeOf(isSingle), 0);
  hasMulti := False;
  cnt := ClassCal.classesByRace[race].count;
  if cnt > Types.RACE_CLASSES_LAST then
    cnt := Types.RACE_CLASSES_LAST;
  row := FIRST_ROW;
  for slot := 1 to cnt do begin
    cls := ClassCal.classesByRace[race].classes[slot];
    if (cls >= C_CLASS.CLERIC) and (cls <= C_CLASS.MAGE_THIEF) then begin
      s := '';
      for p := 1 to 3 do begin
        part := GameDefs.classParts[cls].values[p];
        if (part >= C_LEVEL.CLERIC) and (part <= C_LEVEL.MONK) then begin
          isSingle[part] := True;
          if s <> '' then
            s := s + '/';
          s := s + PART_ABBREVS[part];
        end;
      end;
      if (cls > C_CLASS.MONK) and (row <= LAST_MULTI_ROW) then begin
        hasMulti := True;
        TextRend.DisplayString(MULTI_COL, row, LightGreen, Copy(s, 1, LAST_COL - MULTI_COL + 1));
        Inc(row);
      end;
    end;
  end;
  TextRend.DisplayString(MAX_COL, HEADING_ROW, LightMagenta, 'Max');
  TextRend.DisplayString(CLASS_COL, HEADING_ROW, LightMagenta, 'Class');
  if hasMulti then
    TextRend.DisplayString(MULTI_COL, HEADING_ROW, LightMagenta, 'Multiclasses');
  { the single classes on the left; a single class's id is its classLevels index }
  row := FIRST_ROW;
  for part := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if isSingle[part] and (row <= LAST_ROW) then begin
      lvl := raceMaxLevel[race].values[part];
      { with the Non-Human Level Cap setting off no race has a maximum (#1176) }
      if (lvl > 0) and (GameVars.nonHumanCapOn = 0) then
        lvl := 0;
      if lvl = 0 then
        s := 'U'
      else if lvl > 0 then
        s := StrUtil.NumStr(lvl)
      else
        s := '-';
      TextRend.DisplayString(MAX_VALUE_COL, row, LightGreen, s);
      TextRend.DisplayString(CLASS_COL, row, LightGreen, Copy(GameDefs.classNames[part], 1, MULTI_COL - CLASS_COL - 1));
      Inc(row);
    end;
  if hasMulti then begin
    TextRend.DisplayString(MAX_COL, NOTE_ROW, LightGreen, 'Multiclass levels');
    TextRend.DisplayString(MAX_COL + 2, NOTE_ROW + 1, LightGreen, 'are as above.');
  end;
end;

{ CreateCharacterMenu: Choose race, gender, class and alignment, set the starting age, then roll attributes, hit points
  and gold until the player keeps the result; name the character, customize portrait and icon, save it with
  SaveLoad.SaveChar (a save that fails is offered again, until No) and free it. Aborting a pick menu frees the string
  list and the character before it exits; at the end SaveLoad.FreeCreature frees the record with its racial effects. }
procedure CreateCharacterMenu;
var
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  list: Types.PItemRec;
  m: Types.PItemRec;
  sel: Integer;
  slot: Byte;
  j: ShortInt;
  roll: Byte;
  ch: Char;
  k: ShortInt;
  g: ShortInt;
  cls: ShortInt;
  i: ShortInt;
  cnt: Byte;
  clsCount: Byte;
  goldDice: Byte;
  addExit: Boolean;
  redraw: Boolean;

  { Bring the new character's rolled ability i within its race's limits (ClassCal.RaceAbilityMin and Max), then up to
    its class's minimum. }
  procedure ClampToLimits(i: ShortInt);
  begin
    with creature^ do begin
      if stats[i] < ClassCal.RaceAbilityMin(race, genderSp, i) then
        stats[i] := ClassCal.RaceAbilityMin(race, genderSp, i);
      if stats[i] > ClassCal.RaceAbilityMax(race, genderSp, i) then
        stats[i] := ClassCal.RaceAbilityMax(race, genderSp, i);
      if stats[i] < ClassCal.ClassAbilityMin(race, charClass, i) then
        stats[i] := ClassCal.ClassAbilityMin(race, charClass, i);
    end;
  end;

  { Run the gender, class or alignment list until Enter, leaving the pick in sel (1 for the first line). Exit or Escape
    frees the list and the character and returns False, for the caller to leave. }
  function PickFromList: Boolean;
  var
    picked: Types.PItemRec;
    key: Char;
    withExit: Boolean;
    repaint: Boolean;
  begin
    PickFromList := True;
    picked := list;
    sel := 1;
    withExit := True;
    repaint := True;
    repeat
      key := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, withExit, repaint, sel,
                                   picked);
      if key = C_KEYS.NONE then begin
        MenuCore.FreeStringList(list);
        SaveLoad.FreeCreature(creature);
        PickFromList := False;
        Exit;
      end;
    until key = C_KEYS.ENTER;
  end;

begin
  GetMem(creature, SizeOf(Types.TCharRecord));
  FillChar(creature^, SizeOf(Types.TCharRecord), 0);
  with creature^ do begin
    for slot := 1 to 6 do
      iconColors1[slot] := GameDefs.defaultIconColors[slot] + (GameDefs.defaultIconColors[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_STATUS.OKAY;
    enabled := 1;
    portraitHead := 1;
    portraitBody := 1;
    iconDimensions := 1;
    randByte := Random(256);
  end;
  { race }
  MenuCore.AllocStringList(7, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 1 to 7 do
    case k of
      C_RACE.DWARF..C_RACE.HALFLING: begin
              m := MenuCore.FindListMember(k, list);
              m^.name := '  ' + GameDefs.raceNames[k];
            end;
      { half-orc (6) row skipped }
      C_RACE.HUMAN: begin
              m := MenuCore.FindListMember(k - 1, list);
              m^.name := '  ' + GameDefs.raceNames[k];
            end;
    end;
  { the race screen: the bottom box goes first, so the top boxes' gold corners stay on the row they share with it }
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  Border.DrawBorder(1, RACE_TOP_BOTTOM + 2, 38, 22, 0);
  Border.DrawBorder(1, 1, RACE_SPLIT_COL - 1, RACE_TOP_BOTTOM, 0);
  Border.DrawBorder(RACE_SPLIT_COL + 1, 1, 38, RACE_TOP_BOTTOM, 0);
  CharGen.ShowRaceInfo(C_RACE.DWARF);
  m := list;
  sel := 1;
  { the list starts at Dwarf, with the label row above the box }
  GameVars.verticalMenuTop := 1;
  redraw := True;
  addExit := True;
  repeat
    MenuCore.movesToCaller := True;
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, RACE_LIST_ROW, RACE_SPLIT_COL - 1,
                                RACE_LIST_ROW + 5, list, addExit, redraw, sel, m);
    if ch = C_KEYS.NONE then begin
      MenuCore.FreeStringList(list);
      SaveLoad.FreeCreature(creature);
      Exit;
    end;
    if ch <> C_KEYS.ENTER then
      { 6 -> Human (7) }
      if sel = 6 then
        CharGen.ShowRaceInfo(C_RACE.HUMAN)
      else
        CharGen.ShowRaceInfo(sel);
  until ch = C_KEYS.ENTER;
  { back to the one frame the following lists use }
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, Black, '');
  if sel = 6 then
    { 6 -> Human (7) }
    Inc(sel);
  with creature^ do begin
    race := sel;
    { Racial innate effects. }
    case race of
      C_RACE.HALFLING: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.CON_PSN_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.CONSTITUTION_SAVE_BONUS, 0, 255, False);
         end;
      C_RACE.DWARF: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.CON_PSN_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.DWARF_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.DWARF_GIANT_DEFENSE, 0, 255, False);
         end;
      C_RACE.GNOME: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.CONSTITUTION_SAVE_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.GNOME_ATTACK_BONUS, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.DWARF_GIANT_DEFENSE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.GNOME_BUGBEAR_DEFENSE, 0, 255, False);
         end;
      C_RACE.ELF: begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.ELF_RESISTANCE, 0, 255, False);
         end;
      C_RACE.HALF_ELF: begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_EFFECT.HALF_ELF_RESISTANCE, 0, 255, False);
         end;
      else
        { human }
        iconSize := 2;
    end;
  end;
  { gender }
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GameDefs.genderNames[g];
  end;
  if not PickFromList then Exit;
  creature^.genderSp := sel - 1;
  { class }
  MenuCore.FreeStringList(list);
  cnt := ClassCal.classesByRace[creature^.race].count;
  { the table's width }
  if cnt > Types.RACE_CLASSES_LAST then
    cnt := Types.RACE_CLASSES_LAST;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GameDefs.classNames[ClassCal.classesByRace[creature^.race].classes[slot]];
  end;
  if not PickFromList then Exit;
  if (sel < 1) or (sel > cnt) then
    sel := 1;
  with creature^ do begin
    charClass := ClassCal.classesByRace[race].classes[sel];
    levelHighest := 1;
    { first level in each part of the class }
    if (charClass >= C_CLASS.CLERIC) and (charClass <= C_CLASS.MAGE_THIEF) then
      for slot := 1 to 3 do
        if (GameDefs.classParts[charClass].values[slot] >= C_LEVEL.CLERIC)
           and (GameDefs.classParts[charClass].values[slot] <= C_LEVEL.MONK) then
          classLevels[GameDefs.classParts[charClass].values[slot]] := 1;
    { a paladin's own Protection from Evil: permanent, and at strength 255 so Dispel Magic leaves it. It is the 10'
      radius one, as the paladin's has a 1" radius: SSI gave eff 8, which covered the paladin alone (#742). }
    if charClass = C_CLASS.PALADIN then
      FxEngine.AddEffect(creature, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
    itemLimits := 0;
    thac0Base := 0;
    for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
      if classLevels[cls] > 0 then begin
        if GameDefs.classThac0[cls, classLevels[cls]] > thac0Base then
          thac0Base := GameDefs.classThac0[cls, classLevels[cls]];
        itemLimits := itemLimits or ClassCal.usabilityBit[cls];
      end;
  end;
  ClassCal.RecalcSaves(Types.PCharRecord(creature));
  { alignment }
  MenuCore.FreeStringList(list);
  cnt := ClassCal.alignByClass[creature^.charClass].count;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GameDefs.alignNames[ClassCal.alignByClass[creature^.charClass].alignments[slot]];
  end;
  if not PickFromList then Exit;
  creature^.alignment := ClassCal.alignByClass[creature^.charClass].alignments[sel];
  MenuCore.FreeStringList(list);
  creature^.age := ClassCal.StartingAge(creature^.race, creature^.charClass);
  { stat roll / derived / keep loop }
  savedCur := GameVars.curChar;
  GameVars.curChar := creature;
  ViewChar.DisplayChar(GameVars.curChar);
  repeat
    creature^.strExc := 0;
    for i := 0 to 5 do begin
      creature^.stats[i] := 0;
      for j := 1 to 6 do begin
        roll := Dice.RollDice(3, 6);
        { racial adjustment; the racial limits below still apply }
        if (creature^.race >= C_RACE.DWARF) and (creature^.race <= C_RACE.HUMAN) then
          roll := roll + raceAbilityAdj[creature^.race].values[i];
        if creature^.stats[i] < roll then
          creature^.stats[i] := roll;
      end;
      with creature^ do
        case i of
          { Strength }
          C_STAT.STRENGTH: begin
               if (stats[i] > 0) and (ageThresholds[race].youngAdult < age) then
                 Inc(stats[i]);
               if (stats[i] > 0) and (ageThresholds[race].mature < age) then
                 Dec(stats[i]);
               if (stats[i] > 0) and (ageThresholds[race].middleAged < age) then
                 Dec(stats[i], 2);
               if (stats[i] > 0) and (ageThresholds[race].old < age) then
                 Dec(stats[i]);
               ClampToLimits(i);
               if (stats[C_STAT.STRENGTH] = 18) and (CharHlp.WarriorLevel(creature) > 0) then begin
                 strExc := Random(100) + 1;
                 if GameDefs.minimumMaximumStatistics[race].excMax[genderSp] < strExc then
                   strExc := GameDefs.minimumMaximumStatistics[race].excMax[genderSp];
               end;
             end;
          { Intelligence }
          C_STAT.INTELLIGENCE: begin
               if ageThresholds[race].mature < age then
                 Inc(stats[i]);
               if ageThresholds[race].old < age then
                 Inc(stats[i]);
               ClampToLimits(i);
             end;
          { Wisdom }
          C_STAT.WISDOM: begin
               if ageThresholds[race].youngAdult >= age then
                 Dec(stats[i]);
               if ageThresholds[race].mature < age then
                 Inc(stats[i]);
               if ageThresholds[race].middleAged < age then
                 Inc(stats[i]);
               if ageThresholds[race].old < age then
                 Inc(stats[i]);
               ClampToLimits(i);
             end;
          { Dexterity }
          C_STAT.DEXTERITY: begin
               if ageThresholds[race].middleAged < age then
                 Dec(stats[i], 2);
               if ageThresholds[race].old < age then
                 Dec(stats[i]);
               ClampToLimits(i);
             end;
          { Constitution }
          C_STAT.CONSTITUTION: begin
               { the DMG's young adult +1, kept when mature; middle age, old and venerable each take 1 off. SSI left
                 out the +1, so every age came out one lower (#704). }
               Inc(stats[i]);
               if ageThresholds[race].mature < age then
                 Dec(stats[i]);
               if ageThresholds[race].middleAged < age then
                 Dec(stats[i]);
               if ageThresholds[race].old < age then
                 Dec(stats[i]);
               ClampToLimits(i);
             end;
          { Charisma }
          C_STAT.CHARISMA: begin
               ClampToLimits(i);
             end;
        end;
      ViewChar.PrintStat(i, False);
    end;
    { thief skills use the Dexterity just rolled }
    if creature^.classLevels[C_LEVEL.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(Types.PCharRecord(creature));
    with creature^ do begin
      attacks := 2;
      unarmedRollsA[1] := 1;
      unarmedDiceA[1] := 2;
      useStrength := 1;
      movementBase := 12;
      { goldDice sums each class's starting-gold dice (startingGoldClass); gold = sum * 10 div class count }
      goldDice := 0;
      clsCount := 0;
      for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
        if classLevels[cls] > 0 then begin
          Inc(goldDice,
              Dice.RollDice(startingGoldClass[cls].num, startingGoldClass[cls].sides));
          Inc(clsCount);
          ClassCal.StartCasterClass(Types.PCharRecord(creature), cls);
        end;
      coins[C_MONEY.GOLD] := goldDice * 10 div clsCount;
      { Hit points: roll every class, add the Con bonus and divide by the class count (1 if a negative bonus would leave
        too little) }
      hpRolled := ClassCal.RollFirstLevelHp(creature, $FF);
      hpMax := ClassCal.DivideAmongClasses(hpRolled, ClassCal.ConHpBonus(creature, $FF), clsCount);
      hpCur := hpMax;
      hpRolled := hpRolled div clsCount;
    end;
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenu('Keep this character? ', LightMagenta, LightGreen, White);
  until ch = 'Y';
  ViewChar.DisplayChar(GameVars.curChar);
  GameVars.curChar := savedCur;
  repeat
    creature^.name := TextRend.ReadString('Character name: ', LightMagenta, Types.NAME_LEN);
  until creature^.name <> '';
  savedCur := GameVars.curChar;
  GameVars.curChar := creature;
  CharGen.CustomizePortrait(False);
  { the icon editor draws over the sheet the picker cleared }
  ViewChar.DisplayChar(GameVars.curChar);
  CharGen.CustomizeIcon;
  while not SaveLoad.SaveChar(Types.PCharRecord(creature), '') and
        (MenuCore.YesNoMenu('Try again? ', Yellow, LightGreen, White) = 'Y') do
    ;
  GameVars.curChar := savedCur;
  { with its racial effects }
  SaveLoad.FreeCreature(creature);
end;

{ DropCharacterMenu: Ask twice, then drop curChar from the party with RemoveCreature (freeing it and its icon) and erase
  its own files and roster line (SaveLoad.EraseChar), so it does not come back on the Add list; the farewell message
  depends on whether the character is enabled. Declining shows the relief line, shortened for a name too long for SSI's
  wording to fit the 40-column bottom row. }
procedure DropCharacterMenu;
begin
  if GameVars.curChar = nil then Exit;
  with GameVars.curChar^ do begin
    if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y') and
        (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
    begin
      if enabled = 0 then
        CharDisp.PrintBottomLine('You dump ' + name + ' out back.')
      else
        CharDisp.PrintBottomLine(name + ' bids you farewell.');
      SaveLoad.EraseChar(name);
      SaveLoad.RemoveCreature(False, True);
    end else if Length(name) + Length(' breathes a sigh of relief.') <= 40 then
      CharDisp.PrintBottomLine(name + ' breathes a sigh of relief.')
    else
      { a name of 14 or 15 letters takes the shorter line, which fits the bottom row (#766) }
      CharDisp.PrintBottomLine(name + ' sighs with relief.');
  end;
end;

function Modifiable: Boolean;
begin
  Modifiable := (GameVars.curChar^.race >= C_RACE.DWARF) and (GameVars.curChar^.race <= C_RACE.HUMAN) and
                (GameVars.curChar^.charClass >= C_CLASS.CLERIC) and (GameVars.curChar^.charClass <= C_CLASS.MAGE_THIEF);
end;

{ ModifyCharacterMenu: Modify Character on the main menu: ModifyCharacter for a Modifiable character with no
  experience. A dual-classed human, whose experience starts again at 0, is not one, as Curse refuses it (#838). }
procedure ModifyCharacterMenu;
begin
  if (GameVars.curChar^.experience > 0) or not CharGen.Modifiable or CharHlp.IsDualClass(GameVars.curChar) then
    TextRend.PrintAndPause(GameVars.curChar^.name + ' can''t be modified.', Yellow)
  else
    CharGen.ModifyCharacter(False);
end;

procedure SetHpMax(hp: Integer);
var
  dmg: Integer;
begin
  with GameVars.curChar^ do begin
    dmg := hpMax - hpCur;
    if hp < ClassCal.HpMinimum(GameVars.curChar) then
      hp := ClassCal.HpMinimum(GameVars.curChar);
    if hp < 1 then
      hp := 1;
    hpMax := hp;
    if hp - dmg < 0 then
      hpCur := 0
    else
      hpCur := hp - dmg;
  end;
end;

{ ModifyCharacter: Up and Down pick a row (6 = hit points); Left and Right lower or raise it within racial, class and
  hit-point limits. Keep recalculates a thief's skills for the new Dexterity and, unless levelled, sets npcTreasureShare
  to 1; Exit restores the saved attributes, strExc, hpMax (and, levelled, hpCur) and cleric spell slots. A lowered
  attribute stops at the higher of the racial and class minimums; one already at 0 is not lowered further, so it rises
  to that minimum. }
procedure ModifyCharacter(levelled: Boolean);
var
  savedStats: array[0..5] of Byte;
  savedExc: Byte;
  savedHp: Byte;
  savedHpCur: Byte;
  savedClericSpells: array[1..Types.CASTER_LEVEL_LAST] of Byte;
  lvlSp: ShortInt;
  hold: ShortInt;
  key: Char;
  ext: Boolean;
  statIdx: Byte;
  oldCon: Byte;
  hpShift: Integer;

  { RedrawStat: Repaint the selected row: an attribute via ViewChar.PrintStat, or the hit-point line (row 6) via
    CharDisp.PrintHitPoints; hotPink highlights it }
  procedure RedrawStat(hotPink: Boolean);
  begin
    if statIdx < 6 then
      ViewChar.PrintStat(statIdx, hotPink)
    else
      CharDisp.PrintHitPoints(Types.PCharRecord(GameVars.curChar), 4, 18, hotPink);
  end;

  { StatMinimum: The lowest value the selected attribute may be lowered to: racialMin, or the class minimum when that
    is higher }
  function StatMinimum(racialMin: Byte): Byte;
  begin
    with GameVars.curChar^ do
      if ClassCal.ClassAbilityMin(race, charClass, statIdx) > racialMin then
        StatMinimum := ClassCal.ClassAbilityMin(race, charClass, statIdx)
      else
        StatMinimum := racialMin;
  end;

  { Left on ability a: up to the larger of its racial and class minimums. }
  procedure RaiseToMinimum(a: ShortInt);
  begin
    with GameVars.curChar^ do
      if stats[a] < StatMinimum(ClassCal.RaceAbilityMin(race, genderSp, a)) then
        stats[a] := StatMinimum(ClassCal.RaceAbilityMin(race, genderSp, a));
  end;

  { Right on ability a: down to its racial maximum. }
  procedure LowerToMaximum(a: ShortInt);
  begin
    with GameVars.curChar^ do
      if stats[a] > ClassCal.RaceAbilityMax(race, genderSp, a) then
        stats[a] := ClassCal.RaceAbilityMax(race, genderSp, a);
  end;

  { Levelled, the hit points a Constitution change from oldCon gives or takes over every hit die, damage kept. }
  procedure ShiftHp;
  begin
    with GameVars.curChar^ do begin
      hpShift := ClassCal.ConHpTotal(Types.PCharRecord(GameVars.curChar), stats[C_STAT.CONSTITUTION]) -
                 ClassCal.ConHpTotal(Types.PCharRecord(GameVars.curChar), oldCon);
      if hpMax + hpShift < 1 then
        hpShift := 1 - hpMax;
      hpMax := hpMax + hpShift;
      if hpCur + hpShift < 0 then
        hpCur := 0
      else
        hpCur := hpCur + hpShift;
    end;
  end;

  { Levelled, hpMax moved by k within the levels' limits, damage kept. }
  procedure StepHp(k: Integer);
  var
    hp: Integer;
  begin
    hp := GameVars.curChar^.hpMax + k;
    if hp > ClassCal.HpMaximum(GameVars.curChar) then
      hp := ClassCal.HpMaximum(GameVars.curChar);
    CharGen.SetHpMax(hp);
  end;

begin
  if not CharGen.Modifiable then begin
    TextRend.PrintAndPause(GameVars.curChar^.name + ' can''t be modified.', Yellow);
    Exit;
  end;
  ViewChar.DisplayChar(GameVars.curChar);
  Move(GameVars.curChar^.stats, savedStats, SizeOf(GameVars.curChar^.stats));
  savedExc := GameVars.curChar^.strExc;
  savedHp := GameVars.curChar^.hpMax;
  savedHpCur := GameVars.curChar^.hpCur;
  { a Wisdom change recalculates the cleric spell slots }
  for lvlSp := 1 to Types.CASTER_LEVEL_LAST do
    savedClericSpells[lvlSp] := CharHlp.SpellSlots(GameVars.curChar, C_SPELL.CLASS_CLERIC, lvlSp);
  statIdx := 6;
  RedrawStat(False);
  statIdx := 0;
  RedrawStat(True);
  with GameVars.curChar^ do begin
    repeat
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('Modify character: ', 'Keep Exit', LightMagenta, LightGreen,
                                     White, True, False, ext);
      RedrawStat(False);
      oldCon := stats[C_STAT.CONSTITUTION];
      if ext then
        case key of
          C_KEYS.DOWN, C_KEYS.ENTER:
            begin
              Inc(statIdx);
              if statIdx > 6 then
                statIdx := 0;
            end;
          C_KEYS.UP:
            begin
              Dec(statIdx);
              if statIdx = 255 then
                statIdx := 6;
            end;
          { Left = decrease }
          C_KEYS.LEFT:
            if statIdx < 6 then begin
              hold := statIdx;
              if stats[hold] > 0 then
                Dec(stats[hold]);
              case hold of
                C_STAT.STRENGTH: if strExc > 0 then begin
                     Dec(strExc);
                     Inc(stats[hold]);
                   end else
                     RaiseToMinimum(hold);
                C_STAT.WISDOM: begin
                     RaiseToMinimum(hold);
                     { the cleric slots again for the new Wisdom, at any level: setting the first-level count to 1
                       and adding the bonus again was right only at level 1 }
                     ClassCal.ResetClericSlots(Types.PCharRecord(GameVars.curChar));
                   end;
                C_STAT.CONSTITUTION: begin
                     RaiseToMinimum(hold);
                     if levelled then
                       ShiftHp
                     else begin
                       if ClassCal.HpMaximum(GameVars.curChar) < hpMax then
                         hpMax := ClassCal.HpMaximum(GameVars.curChar);
                       hpCur := hpMax;
                     end;
                     statIdx := 6;
                     RedrawStat(False);
                     statIdx := C_STAT.CONSTITUTION;
                   end;
              else
                { Intelligence, Dexterity, Charisma }
                RaiseToMinimum(hold);
              end;
            end else
            { HP row }
            if levelled then
              StepHp(-1)
            else begin
              Dec(hpMax);
              if ClassCal.HpMinimum(GameVars.curChar) > hpMax then
                hpMax := ClassCal.HpMinimum(GameVars.curChar);
              hpCur := hpMax;
            end;
          { Right = increase }
          C_KEYS.RIGHT:
            if statIdx < 6 then begin
              hold := statIdx;
              Inc(stats[hold]);
              case hold of
                C_STAT.STRENGTH: if stats[hold] > ClassCal.RaceAbilityMax(race, genderSp, hold) then begin
                     if (stats[hold] > 18) and (CharHlp.WarriorLevel(GameVars.curChar) > 0) and
                         (GameDefs.minimumMaximumStatistics[race].excMax[genderSp] > strExc) then
                       Inc(strExc);
                     stats[hold] := ClassCal.RaceAbilityMax(race, genderSp, hold);
                   end;
                C_STAT.WISDOM: begin
                     LowerToMaximum(hold);
                     ClassCal.ResetClericSlots(Types.PCharRecord(GameVars.curChar));
                   end;
                C_STAT.CONSTITUTION: begin
                     LowerToMaximum(hold);
                     if levelled then
                       ShiftHp
                     else begin
                       if ClassCal.HpMinimum(GameVars.curChar) > hpMax then
                         hpMax := ClassCal.HpMinimum(GameVars.curChar);
                       hpCur := hpMax;
                     end;
                     statIdx := 6;
                     RedrawStat(False);
                     statIdx := C_STAT.CONSTITUTION;
                   end;
              else
                { Intelligence, Dexterity, Charisma }
                LowerToMaximum(hold);
              end;
            end else
            { HP row }
            if levelled then
              StepHp(1)
            else begin
              Inc(hpMax);
              if ClassCal.HpMaximum(GameVars.curChar) < hpMax then
                hpMax := ClassCal.HpMaximum(GameVars.curChar);
              hpCur := hpMax;
            end;
        end else
        case key of
          'E', C_KEYS.NONE:
            begin
              for hold := 0 to 5 do
                GameVars.curChar^.stats[hold] := savedStats[hold];
              GameVars.curChar^.strExc := savedExc;
              GameVars.curChar^.hpMax := savedHp;
              GameVars.curChar^.hpCur := hpMax;
              if levelled then
                GameVars.curChar^.hpCur := savedHpCur;
              for lvlSp := 1 to Types.CASTER_LEVEL_LAST do
                CharHlp.SetSpellSlots(GameVars.curChar, C_SPELL.CLASS_CLERIC, lvlSp, savedClericSpells[lvlSp]);
              { a Wisdom change above cleric level 1 ran RecalcBaseSkills, whose thief skills read the Dexterity
                then }
              if classLevels[C_LEVEL.THIEF] > 0 then
                ClassCal.RecalcThiefSkills(Types.PCharRecord(GameVars.curChar));
              CharHlp.RecalcStats(Types.PCharRecord(GameVars.curChar));
              Exit;
            end;
        end;
      CharHlp.RecalcStats(Types.PCharRecord(GameVars.curChar));
      ViewChar.PrintCombatStats;
      RedrawStat(True);
    until (not ext) and (key = 'K');
    if classLevels[C_LEVEL.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(Types.PCharRecord(GameVars.curChar));
    if not levelled then
      GameVars.curChar^.npcTreasureShare := 1;
  end;
end;

{ GainLevels: curChar gains a level in each of its classes in mask (GameDefs.classBits), as training gives it: with
  restoreDrain, one drained level is restored for each, its entry on the drain log dropped and the experience the
  drain took forfeit (CharExt.TrainDrain, #1174); base skills are recalculated; a new magic-user level picks one
  spell; hit points grow by the rolled dice (and, for hpMax, the classes' Con bonus) divided by the class count, at
  least 1, damage kept. A dual-classed human (#838) gains no level in a class it has left, and no hit points until the
  class it follows passes the class it left (ClassCal.HitDice): then its own die alone, undivided. A class that
  wakes with the level is announced (ChgClass.AnnounceWoken). }
procedure GainLevels(trainable: Byte; restoreDrain: Boolean);
var
  clsCount: Byte;
  rolled: Integer;
  gain: Integer;
  dmg: Byte;
  cls: ShortInt;
  conB: Integer;
  oldMage: ShortInt;
  sel: Byte;
  idx: Integer;
  notEmpty: Boolean;
  resting: Byte;
  entry: Types.TDrainRec;
begin
  resting := ChgClass.RestingMask(GameVars.curChar);
  with GameVars.curChar^ do begin
    clsCount := ClassCal.HpClassCount(GameVars.curChar);
    oldMage := classLevels[C_LEVEL.MAGE];
    for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
      if classLevels[cls] > 0 then begin
        if (GameDefs.classBits[cls] and trainable > 0) and (portExt.formerClasses and (1 shl cls) = 0) then begin
          Inc(classLevels[cls]);
          if restoreDrain and (drainedLevels > 0) then begin
            { the drain's entry goes with its experience (#1174), its hit points by the new roll below }
            if CharExt.TrainDrain(GameVars.curChar, cls, entry) then begin
              if entry.hp > drainedHps then
                drainedHps := 0
              else
                Dec(drainedHps, entry.hp);
            end else
              Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;
    ClassCal.RecalcBaseSkills(Types.PCharRecord(GameVars.curChar));
    if classLevels[C_LEVEL.MAGE] > oldMage then begin
      idx := -1;
      repeat
        sel := Magic.SpellMenu(4, 4, idx, notEmpty);
      until (sel > 0) or (not notEmpty);
      { SpellMenu returns 0 when there is no spell left to learn }
      if sel > 0 then
        CharHlp.SetSpellKnown(GameVars.curChar, sel, True);
    end;
    if not CharHlp.IsDualClass(GameVars.curChar) or (ClassCal.HitDice(GameVars.curChar, charClass) > 0) then begin
      rolled := ClassCal.RollFirstLevelHp(GameVars.curChar, trainable);
      gain := rolled div clsCount;
      if gain = 0 then
        gain := 1;
      Inc(hpRolled, gain);
      conB := ClassCal.ConHpBonus(GameVars.curChar, trainable);
      gain := (rolled + conB) div clsCount;
      if gain < 1 then
        gain := 1;
      dmg := hpMax - hpCur;
      Inc(hpMax, gain);
      hpCur := hpMax - dmg;
    end;
  end;
  if resting <> 0 then
    ChgClass.AnnounceWoken(GameVars.curChar, resting);
end;

{ TrainingMenu: Train curChar for 1000 gp. Refuses characters that are not C_STATUS.OKAY, have under 1000 gp, have no
  class this hall trains (CharHlp.HallMask: every class under Train Anywhere) or lack the experience; stingMode skips
  these checks and the fee, but not the class and level limits, so a character with no class left to train is still
  sent away. Applies the racial level caps (CharHlp.AtLevelCap) and the experience table's end (ClassCal.LevelOpen). A
  character who trains has experience clamped to one below the highest level + 2 threshold it has reached. A class a
  dual-classed human has left neither trains nor counts for the hall (#838). Each trained class gains a level and
  restores one drained level; a new magic-user level picks one spell; hit points grow by the rolled dice (and, for
  hpMax, the trained classes' Con bonus) divided by the class count, at least 1, as GainLevels gives them. }
procedure TrainingMenu;
var
  xpClamp: LongInt;
  nextXp: LongInt;
  trainMask: Byte;
  classMask: Byte;
  trainable: Byte;
  { the classes that can train, C_LEVEL bits (CharHlp.TrainClasses) }
  trains: Byte;
  cls: ShortInt;
  row: ShortInt;
  lvl: ShortInt;
begin
  if (GameVars.curChar^.status <> C_STATUS.OKAY) and (stingMode = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow);
    Exit;
  end;
  if (MoneyCal.CreatureGold(Types.PCharRecord(GameVars.curChar)) < 1000) and (stingMode = 0) then begin
    TextRend.PrintAndPause('Training costs 1000 gp.', Yellow);
    Exit;
  end;
  trainMask := 0;
  classMask := 0;
  with GameVars.curChar^ do begin
    xpClamp := 0;
    trains := CharHlp.TrainClasses(Types.PCharRecord(GameVars.curChar), stingMode <> 0);
    for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
      { a class a dual-classed human has left never trains (#838) }
      if (classLevels[cls] > 0) and (portExt.formerClasses and (1 shl cls) = 0) then begin
        Inc(classMask, GameDefs.classBits[cls]);
        lvl := classLevels[cls];
        if trains and (1 shl cls) <> 0 then begin
          Inc(trainMask, GameDefs.classBits[cls]);
          { a level past the class's end (ClassCal.LevelOpen, the Game Level Cap) clamps nothing }
          if ClassCal.LevelOpen(cls, lvl + 2) then
            nextXp := ClassCal.LevelXp(cls, lvl + 2)
          else
            nextXp := 0;
          if nextXp > 0 then
            if experience >= nextXp then
              if nextXp > xpClamp then
                xpClamp := nextXp - 1;
        end;
      end;
    if stingMode = 0 then begin
      if Byte(classMask and CharHlp.HallMask) = 0 then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow);
        Exit;
      end else if Byte(trainMask and CharHlp.HallMask) = 0 then begin
        TextRend.PrintAndPause('Not Enough Experience', Yellow);
        Exit;
      end;
    end;
    if stingMode = 0 then
      trainable := trainMask and CharHlp.HallMask
    else
      trainable := trainMask;
    { free training passes the hall's checks with every class at its limit: GainLevels would then gain no level and
      still add a hit point (#703) }
    if trainable = 0 then begin
      TextRend.PrintAndPause('No class can train further', Yellow);
      Exit;
    end;
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    row := 4;
    CharDisp.DisplayCreatureName(Types.PCharRecord(GameVars.curChar), 4, row, False);
    TextRend.DisplayString(Length(name) + 4, row, LightGreen, ' will become:');
    for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
      if (classLevels[cls] > 0) and (portExt.formerClasses and (1 shl cls) = 0) then
        if GameDefs.classBits[cls] and trainable > 0 then begin
          Inc(row);
          if row = 5 then
            TextRend.DisplayString(6, row, LightGreen,
                                   '    a level ' + StrUtil.NumStr(classLevels[cls] + 1) + ' ' +
                                     GameDefs.classNames[cls])
          else
            TextRend.DisplayString(6, row, LightGreen,
                                   'and a level ' + StrUtil.NumStr(classLevels[cls] + 1) + ' ' +
                                     GameDefs.classNames[cls]);
        end;
    if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then
      Exit;
    CharDisp.PrintBottomLine('Congratulations...');
    if stingMode = 0 then
      Money.PayFromCreature(Types.PCharRecord(GameVars.curChar), 1000);
    { only a character who trains loses the experience past the level + 2 threshold: SSI cut it before the hall's
      checks and the question, so a refusal or a No kept the cut (#701) }
    if xpClamp > 0 then
      experience := xpClamp;
    CharGen.GainLevels(trainable, True);
  end;
end;

{ AddCharacterMenu: Pick characters from the CHARLIST.TXT roster (SaveLoad.LoadCharlist), load each with
  SaveLoad.LoadChar and add it to the party unless already there (same name and randByte) or its record is short or
  unreadable, which the bottom line reports as a damaged file until a key: at most 6 non-NPCs and 8 members in all.
  Curse's party rules also apply: a paladin does not join a party with an evil member, nor an evil character a party
  with a paladin, and a party has at most 3 rangers. A character they refuse gets Curse's message on the bottom line
  until a key, keeps its unmarked name and is freed. The first character into an empty party joins unchecked, as do NPCs
  a script adds. A character with no file, once Escape gives up at the save disk prompt, is taken off the roster. Added
  entries get a leading '* ' and the roster is saved back, the added ones still on it (SaveLoad.SaveCharlist). With no
  roster, or an empty one, the bottom line says there are no characters to add, for two seconds or until a key
  (TextRend.FlashBottomLine), over the menu it was chosen from (#1069). }
procedure AddCharacterMenu;
const
  { the most player characters, not NPCs, a party takes }
  MAX_PCS = 6;
var
  list: Types.PItemRec;
  m: Types.PItemRec;
  creature: Types.PCharRecord;
  p: Types.PCharRecord;
  idx: Integer;
  key: Char;
  redraw: Boolean;
  nonNpc: Byte;
  rangers: Byte;
  hasEvil: Boolean;
  paladin: Types.PCharRecord;
  newEvil: Boolean;
  newPaladin: Boolean;
  newRanger: Boolean;
begin
  SaveLoad.LoadCharlist(list);
  if list = nil then begin
    { the menu stays up behind it (#1069) }
    TextRend.FlashBottomLine(Yellow, 'No characters found to add.');
    Exit;
  end;
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  idx := 0;
  m := list;
  redraw := True;
  { the until clause reads nonNpc after every key, including Space and a party member's entry, which add nothing }
  nonNpc := 0;
  repeat
    { the menu string already holds Exit, so MenuVertical adds none }
    key := MenuCore.MenuVertical('Add a character: ', 'Add Exit', LightMagenta, LightGreen, White,
                                 1, 2, 38, 22, list, False, redraw, idx, m);
    if (key = C_KEYS.ENTER) or (key = 'A') then
      if m^.name[1] <> '*' then
      begin
        GetMem(creature, SizeOf(Types.TCharRecord));
        nonNpc := 0;
        { a short or unreadable .cha is not added and keeps its unmarked name; the bottom line says so until a key,
          as the put-save-disk prompt does, with the name cut to fit the line }
        if not SaveLoad.LoadChar(m^.name, Types.PCharRecord(creature), False) then begin
          FreeMem(creature, SizeOf(Types.TCharRecord));
          if not SaveLoad.HasCharFile(m^.name) then begin
            { Escape gave up on a character with no file: it leaves the roster (SSI asked for the disk forever, #794) }
            SaveLoad.SaveCharlist(list, m^.name);
            MenuCore.FreeStringList(list);
            SaveLoad.LoadCharlist(list);
            if list = nil then Exit;
            idx := 0;
            m := list;
            redraw := True;
          end else begin
            TextRend.DisplayAndPause(Yellow, Copy(m^.name, 1, 21) + '''s file is damaged.');
            Border.ClearBox(0, 24, 39, 24);
          end;
        end else begin
          m^.name := '* ' + m^.name;
          if GameVars.creatureList = nil then begin
            GameVars.zone1^[C_GBVM.PARTY_SIZE] := 0;
            SaveLoad.AddCharToParty(Types.PCharRecord(creature));
            SaveLoad.LoadCharIconAnim(True);
          end else begin
            rangers := 0;
            hasEvil := False;
            paladin := nil;
            p := GameVars.creatureList;
            while (p <> nil) and ((p^.name <> creature^.name) or (p^.randByte <> creature^.randByte)) do begin
              { C_NPC.FLAG clear }
              if not CharHlp.IsNpc(p) then
                Inc(nonNpc);
              if CharHlp.GetClassLevel(p, C_LEVEL.RANGER_BIT) > 0 then
                Inc(rangers);
              if p^.alignment in C_ALIGN.EVIL_ALIGNMENTS then
                hasEvil := True;
              if CharHlp.GetClassLevel(p, C_LEVEL.PALADIN_BIT) > 0 then
                paladin := p;
              p := p^.nextCharAddr;
            end;
            newPaladin := CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT) > 0;
            newRanger := CharHlp.GetClassLevel(creature, C_LEVEL.RANGER_BIT) > 0;
            newEvil := creature^.alignment in C_ALIGN.EVIL_ALIGNMENTS;
            if (p = nil) and
                ((newPaladin and hasEvil) or (newRanger and (rangers >= 3)) or
                 (newEvil and (paladin <> nil))) then begin
              { refused by the party rules: unmarked, so it stays on the roster; the reason stays up until a key }
              Delete(m^.name, 1, 2);
              if newPaladin and hasEvil then
                TextRend.DisplayAndPause(Yellow, 'paladins do not join with evil scum')
              else if newRanger and (rangers >= 3) then
                TextRend.DisplayAndPause(Yellow, 'too many rangers in party')
              else
                TextRend.DisplayAndPause(Yellow, paladin^.name + ' will tolerate no evil!');
              Border.ClearBox(0, 24, 39, 24);
              SaveLoad.FreeCreature(Types.PCharRecord(creature));
            end
            { Add if not already in the party and the party is under 8: a non-NPC (C_NPC.FLAG clear) while under 6
              non-NPCs, or an NPC (C_NPC.FLAG set). v1.3 took a non-NPC into a full party with 3 or more NPCs as a
              ninth member. }
            else if (p = nil) and (GameVars.zone1^[C_GBVM.PARTY_SIZE] < Types.MAX_PARTY) and
                (CharHlp.IsNpc(creature) or (nonNpc < MAX_PCS)) then begin
              SaveLoad.AddCharToParty(Types.PCharRecord(creature));
              SaveLoad.LoadCharIconAnim(True);
              { C_NPC.FLAG clear }
              if not CharHlp.IsNpc(creature) then
                Inc(nonNpc);
            end else begin
              { one the party has no room for is unmarked, to be picked again }
              if p = nil then
                m^.name := Copy(m^.name, 3, Length(m^.name) - 2);
              { with the items and effects LoadChar read }
              SaveLoad.FreeCreature(Types.PCharRecord(creature));
            end;
          end;
        end;
      end;
  until (key = 'E') or (key = C_KEYS.NONE) or (nonNpc >= MAX_PCS) or
        (GameVars.zone1^[C_GBVM.PARTY_SIZE] >= Types.MAX_PARTY);
  SaveLoad.SaveCharlist(list, '');
  MenuCore.FreeStringList(list);
end;

{ CustomizePortrait: The portrait picker, on its own bordered page. Three heads sit over three bodies; the middle
  column, framed, is the current pick and the others are the previous and next in GameDefs.headTbl/bodyTbl, wrapping
  at the ends of the entries offered (Portrait.PlayerPortraitCount: all of them once the merged archives are read).
  Head and Body (or Up and Down) choose the row; Next and Prev (or Left and Right) step through it. Keep (or Space, or
  Enter while Keep is the current option) shows the pick alone and asks whether it is ok: Yes keeps it, No goes back to
  choosing. With canCancel (camp's Alter), Escape leaves the picker and restores the head and body the character
  had; without it (character creation) there is no way out but choosing a portrait. A head or body number past the
  ones offered starts at 1. The caller redraws its screen afterwards. (SSI's picker cycled the head or body with H
  and B under the sheet's portrait, forward only.) }
procedure CustomizePortrait(canCancel: Boolean);
const
  PIC_COL: array[0..2] of Byte = (2, 14, 26);
  PIC_ROW = 4;
  { the hint under the counts }
  HINT_ROW = 20;
var
  key: Char;
  ext: Boolean;
  onBody: Boolean;
  done: Boolean;
  heads: array[0..2] of Types.PImgBuf;
  bodies: array[0..2] of Types.PImgBuf;
  diskCh: String[1];
  i: Byte;
  step: Integer;
  { how many heads and bodies are offered (Portrait.PlayerPortraitCount) }
  nHeads: Byte;
  nBodies: Byte;
  { the portrait on entry, which Escape restores }
  savedHead: Byte;
  savedBody: Byte;

  { Wrap: The table position k steps from cur in a table of n, wrapping at the ends }
  function Wrap(cur: Byte; k: Integer; n: Byte): Byte;
  begin
    Wrap := ((Integer(cur) - 1 + k + n) mod n) + 1;
  end;

  { ShowRow: Load and draw the heads (or bodies) around the current pick }
  procedure ShowRow(body: Boolean);
  var
    k: Integer;
  begin
    with GameVars.curChar^ do
      for k := -1 to 1 do
        if body then begin
          Blit.LoadPic('BODY' + diskCh, GameDefs.bodyTbl[Wrap(portraitBody, k, nBodies)], False, 0, bodies[k + 1]);
          Portrait.DisplayImageBuf(PIC_COL[k + 1], PIC_ROW + Portrait.BODY_ROW_OFFSET, False, bodies[k + 1]);
        end else begin
          Blit.LoadPic('HEAD' + diskCh, GameDefs.headTbl[Wrap(portraitHead, k, nHeads)], False, 0, heads[k + 1]);
          Portrait.DisplayImageBuf(PIC_COL[k + 1], PIC_ROW, False, heads[k + 1]);
        end;
  end;

  { Centered: Print s centred between the margins (columns 2..37) on row, clearing the row first }
  procedure Centered(row, color: Byte; s: Types.TStr40);
  begin
    Border.ClearBox(2, row, 37, row);
    TextRend.DisplayCentered(2, 37, row, color, s);
  end;

  { ShowCounts: The "Head  7 of 41" and "Body  3 of 21" lines, the row being changed in white and the other in green }
  procedure ShowCounts;
  var
    col: Byte;
  begin
    with GameVars.curChar^ do begin
      if onBody then col := LightGreen else col := White;
      Centered(17, col, 'Head ' + StrUtil.PadLeft(StrUtil.NumStr(portraitHead), 2) + ' of ' + StrUtil.NumStr(nHeads));
      if onBody then col := White else col := LightGreen;
      Centered(18, col, 'Body ' + StrUtil.PadLeft(StrUtil.NumStr(portraitBody), 2) + ' of ' + StrUtil.NumStr(nBodies));
    end;
  end;

begin
  Str(LongInt(GameVars.diskIndex), diskCh);
  nHeads := Portrait.PlayerPortraitCount(False);
  nBodies := Portrait.PlayerPortraitCount(True);
  for i := 0 to 2 do begin
    heads[i] := nil;
    bodies[i] := nil;
  end;
  with GameVars.curChar^ do begin
    savedHead := portraitHead;
    savedBody := portraitBody;
    if (portraitHead = 0) or (portraitHead > nHeads) then
      portraitHead := 1;
    if (portraitBody = 0) or (portraitBody > nBodies) then
      portraitBody := 1;
    Border.ClearToFrame;
    Centered(2, White, name);
    Border.DrawBorder(PIC_COL[1], PIC_ROW, PIC_COL[1] + 10, PIC_ROW + 10, 0);
    Centered(HINT_ROW, LightGreen, 'Arrow keys for selection');
    ShowRow(False);
    ShowRow(True);
    onBody := False;
    done := False;
    { Keep, the fifth option }
    GameVars.horizChoice := 5;
    repeat
      ShowCounts;
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('Portrait: ', 'Head Body Next Prev Keep', LightMagenta, LightGreen, White,
                                     True, False, ext);
      { an extended key's scan code can equal a letter (Down is 80, 'P'), so the two are told apart by ext }
      step := 0;
      if ext then
        case key of
          C_KEYS.UP, C_KEYS.DOWN: onBody := not onBody;
          C_KEYS.LEFT: step := -1;
          C_KEYS.RIGHT: step := 1;
        end
      else
        case key of
          'N': step := 1;
          'P': step := -1;
          'H': onBody := False;
          'B': onBody := True;
          { Escape }
          C_KEYS.NONE: if canCancel then begin
              portraitHead := savedHead;
              portraitBody := savedBody;
              done := True;
            end;
          'K', ' ', C_KEYS.ENTER: begin
              { the pick alone: no neighbours, no counts }
              Border.ClearBox(PIC_COL[0], PIC_ROW, PIC_COL[0] + 10, PIC_ROW + 10);
              Border.ClearBox(PIC_COL[2], PIC_ROW, PIC_COL[2] + 10, PIC_ROW + 10);
              Border.ClearBox(2, 17, 37, HINT_ROW);
              if MenuCore.YesNoMenu('Is this portrait ok? ', LightMagenta, LightGreen, White) = 'Y' then
                done := True
              else begin
                ShowRow(False);
                ShowRow(True);
                Centered(HINT_ROW, LightGreen, 'Arrow keys for selection');
                GameVars.horizChoice := 5;
              end;
            end;
        end;
      if step <> 0 then begin
        if onBody then
          portraitBody := Wrap(portraitBody, step, nBodies)
        else
          portraitHead := Wrap(portraitHead, step, nHeads);
        ShowRow(onBody);
      end;
    until done;
  end;
  for i := 0 to 2 do begin
    Blit.FreePic(heads[i]);
    Blit.FreePic(bodies[i]);
  end;
  TextRend.ClearBottomLine;
end;

{ CustomizeIcon: The combat-icon editor for curChar, on its own two-pane page. The left pane shows the name, the icon's
  ready and action frames, Head and Weapon (each with its place among the shapes there are), Size, the seven coloured
  parts ("1 2" beside the five with two colours) and, on the bottom line, the menu: Keep and Exit. Up and Down choose an
  item, the menu being the last; on the menu Left and Right choose Keep or Exit and Enter takes it, as K and E do. Enter
  on Size toggles small and large; on any other item it fills the right pane with a 4x4 grid of the icon with each
  option of that item: every head, every weapon, or the part in each of the 16 colours. The arrows move the game's
  cursor box (COMSPR 25, the square behind the active icon in combat) through the grid, turning the page past its last
  or first row, and the ready and action frames on the left show the boxed option. Enter keeps it, Escape goes back to
  the left with the icon as it was, and Space switches a two-colour part between colour 1 and colour 2. The menu is not
  offered while the grid is up. Keep asks whether the icon is ok: Yes ends the editor with the icon as it is and No goes
  back to it. Exit, or Escape on the left, ends the editor with the icon as it was when the editor opened. Only the
  field chosen is stored (iconHead, iconBody, iconSize or iconColors1), and a party member's icon in its slot
  (orderNumber) is rebuilt at the end. A page's icons are kept, so moving the box loads at most one frame from CHEAD or
  CBODY. (SSI's editor stepped through each choice with Next and Prev under an old and a new copy of the icon.) }
procedure CustomizeIcon;
const
  { CHEAD and CBODY each hold 14 heads and 32 weapons per size }
  NUM_HEADS = 14;
  NUM_WEAPONS = 32;
  NUM_COLORS = 16;
  { the left pane's items, in Up and Down order }
  ITEM_HEAD = 0;
  ITEM_WEAPON = 1;
  ITEM_SIZE = 2;
  FIRST_PART = 3;
  LAST_PART = 9;
  { the bottom line's menu, which MenuHorizontal draws }
  ITEM_MENU = 10;
  ITEM_NAME: array[ITEM_HEAD..LAST_PART] of String[6] = (
    'Head', 'Weapon', 'Size', 'Weapon', 'Body', 'Hair', 'Face', 'Shield', 'Arm', 'Leg');
  ITEM_COL: array[ITEM_HEAD..LAST_PART] of Byte = (2, 2, 2, 3, 3, 3, 3, 3, 3, 3);
  ITEM_ROW: array[ITEM_HEAD..LAST_PART] of Byte = (8, 9, 10, 13, 14, 15, 16, 17, 18, 19);
  { each part's iconColors1 slot }
  PART_SLOT: array[FIRST_PART..LAST_PART] of Byte = (6, 1, 4, 4, 5, 2, 3);
  { the nibble a one-colour part uses (0 low, 1 high), or 2 for a part with two colours }
  PART_NIBBLE: array[FIRST_PART..LAST_PART] of Byte = (2, 2, 0, 1, 2, 2, 2);
  COLOR_ROW = 12;
  VALUE_COL = 10;
  DIGIT_COL = 11;
  READY_COL = 3;
  ACTION_COL = 10;
  PREVIEW_ROW = 3;
  LABEL_ROW = 6;
  GRID_COL: array[0..3] of Byte = (19, 24, 29, 34);
  GRID_ROW: array[0..3] of Byte = (2, 6, 10, 14);
  { where "(more)" starts on a grid row: centred under the four columns }
  MORE_COL = 25;
  { the message panel's text rows, under its own border }
  MSG_TOP = 18;
  MSG_BOTTOM = 22;
  { an icon frame: 24 pixel rows of 3 character cells }
  ICON_H = 24;
  ICON_W = 3;
  PART_FILE: array[0..1] of String[5] = ('CHEAD', 'CBODY');
  PART_COUNT: array[0..1] of Byte = (NUM_HEADS, NUM_WEAPONS);
  { no block loaded; real blocks go up to 223 }
  NO_BLOCK = 255;
var
  key: Char;
  ext: Boolean;
  done: Boolean;
  cur: Byte;
  i: Byte;
  j: Byte;
  savedChoice: Byte;
  { the icon as it was when the editor opened, which Exit puts back }
  savedHead: Byte;
  savedBody: Byte;
  savedSize: Byte;
  savedCols: Types.TIconCols;
  { the icon shown: the stored one, or with the highlighted option while the grid is up }
  tHead: Byte;
  tBody: Byte;
  tSize: Byte;
  tCols: Types.TIconCols;
  inGrid: Boolean;
  { colour 1 or 2 (0 or 1) of a part with two colours }
  which: Byte;
  pick: Byte;
  { the last-loaded head and body of each frame, by DAX block }
  loaded: array[0..1, 0..1] of Types.PImgBuf;
  loadedBlock: array[0..1, 0..1] of Byte;
  work: Types.PImgBuf;
  cells: array[0..15] of Types.PImgBuf;
  readyPic: Types.PImgBuf;
  actionPic: Types.PImgBuf;
  shownPic: Types.PImgBuf;

  { PartPic: Frame frame of head (kind 0) or weapon (kind 1) id at tSize, loaded from CHEAD or CBODY on disk 3 unless
    it is the one loaded last; nil when id is past the ones there are or the block is missing }
  function PartPic(kind, id, frame: Byte): Types.PImgBuf;
  var
    block: Byte;
  begin
    PartPic := nil;
    if (kind > 1) or (frame > 1) then Exit;
    if id >= PART_COUNT[kind] then Exit;
    block := id + frame * 128;
    if tSize = 2 then
      Inc(block, 64);
    if loadedBlock[kind, frame] <> block then begin
      DaxIo.PushState(3);
      Blit.LoadPic(PART_FILE[kind], block, True, 0, loaded[kind, frame]);
      DaxIo.PopState;
      loadedBlock[kind, frame] := block;
    end;
    PartPic := loaded[kind, frame];
  end;

  { Merge: OR src's pixels onto the top rows of work and AND their transparency masks (VidOps.MergePic; a head is the
    top 8 or 10 rows of the icon), taking src's colour map when it merges (VidOps.CanMerge) }
  procedure Merge(src: Types.PImgBuf);
  begin
    if VidOps.CanMerge(src, work) then begin
      VidOps.MergePic(src, work);
      work^.map := src^.map;
    end;
  end;

  { BuildIcon: Frame frame (0 ready, 1 action) of the icon with head h, weapon b and colours c at tSize into work,
    with its transparency mask }
  procedure BuildIcon(frame, h, b: Byte; var c: Types.TIconCols);
  var
    k: Byte;
    toT: Types.TColorTab;
  begin
    if (work = nil) or (frame > 1) then Exit;
    if work^.transp = nil then Exit;
    Blit.ClearPic(work);
    Merge(PartPic(1, b, frame));
    Merge(PartPic(0, h, frame));
    for k := 0 to 15 do
      toT[k] := k;
    for k := 1 to 6 do begin
      toT[GameDefs.defaultIconColors[k] and $F] := c[k] and $F;
      toT[(GameDefs.defaultIconColors[k] + 8) and $F] := c[k] shr 4;
    end;
    VidOps.RecolorPic(toT, work);
  end;

  { Place: Draw icon frame frame (src, with its mask) into dst, in the game's cursor box (COMSPR 25 in slot 25; plain
    cyan with 4 colours) when boxed and on the plain background otherwise }
  procedure Place(src: Types.PImgBuf; frame: Byte; boxed: Boolean; dst: Types.PImgBuf);
  begin
    if dst = nil then Exit;
    { the cursor box picture needs 16 colours }
    if boxed and (Blit.ColourCount < 16) then
      FillChar(dst^.data, dst^.imgSize, GameDefs.cgaColorFill[Blit.SrcNibble(Cyan, GameDefs.iconColorMap)])
    else
      FillChar(dst^.data, dst^.imgSize, 0);
    if boxed and (Blit.ColourCount = 16) then
      if frame = 0 then
        VidOps.OverlayPic(GameVars.iconAnimation[25, 0], dst)
      else
        VidOps.OverlayPic(GameVars.iconAnimation[25, 1], dst);
    VidOps.OverlayPic(src, dst);
  end;

  { Compose: Frame frame of the icon with head h, weapon b and colours c into dst, in the cursor box }
  procedure Compose(frame, h, b: Byte; var c: Types.TIconCols; dst: Types.PImgBuf);
  begin
    BuildIcon(frame, h, b, c);
    Place(work, frame, True, dst);
  end;

  { OptionCount: How many options the current item has }
  function OptionCount: Byte;
  begin
    case cur of
      ITEM_HEAD: OptionCount := NUM_HEADS;
      ITEM_WEAPON: OptionCount := NUM_WEAPONS;
    else
      OptionCount := NUM_COLORS;
    end;
  end;

  { PageSize: How many options the grid page starting at option first holds. Up to 16 options fit on one page; past
    that the first page holds 12 above a "(more)" row, a later page puts a "(more)" row above them, and one with more
    after it a second below, so it holds 12 when it is the last and 8 otherwise. Pages start on a multiple of 4, so an
    option keeps its column. }
  function PageSize(first: Byte): Byte;
  var
    n: Byte;
  begin
    n := OptionCount;
    if n <= 16 then
      PageSize := n
    else if first = 0 then
      PageSize := 12
    else if n - first <= 12 then
      PageSize := n - first
    else
      PageSize := 8;
  end;

  { PageFirst: The first option of the page holding option v }
  function PageFirst(v: Byte): Byte;
  var
    first: Byte;
  begin
    first := 0;
    while (first < OptionCount) and (v >= first + PageSize(first)) do
      Inc(first, PageSize(first));
    PageFirst := first;
  end;

  { CellOf: The grid cell (0..15) option v is drawn in, below the "(more)" row of a page after the first }
  function CellOf(v: Byte): Byte;
  var
    first: Byte;
  begin
    first := PageFirst(v);
    if first > 0 then
      CellOf := v - first + 4
    else
      CellOf := v - first;
  end;

  { PartNibble: The nibble of its slot the current part changes }
  function PartNibble: Byte;
  begin
    PartNibble := 0;
    if (cur >= FIRST_PART) and (cur <= LAST_PART) then
      if PART_NIBBLE[cur] = 2 then
        PartNibble := which
      else
        PartNibble := PART_NIBBLE[cur];
  end;

  { OptionState: Change h, b or c to option opt of the current item }
  procedure OptionState(opt: Byte; var h, b: Byte; var c: Types.TIconCols);
  var
    slot: Byte;
  begin
    case cur of
      ITEM_HEAD: h := opt;
      ITEM_WEAPON: b := opt;
      FIRST_PART..LAST_PART: begin
          slot := PART_SLOT[cur];
          if PartNibble = 0 then
            c[slot] := c[slot] and $F0 or (opt and $F)
          else
            c[slot] := c[slot] and $0F or ((opt and $F) shl 4);
        end;
    end;
  end;

  { CurrentOption: The option of the current item the icon has now, or 0 when it has none of them }
  function CurrentOption: Byte;
  var
    v: Byte;
  begin
    case cur of
      ITEM_HEAD: v := tHead;
      ITEM_WEAPON: v := tBody;
    else
      if PartNibble = 0 then
        v := tCols[PART_SLOT[cur]] and $F
      else
        v := tCols[PART_SLOT[cur]] shr 4;
    end;
    if v >= OptionCount then
      v := 0;
    CurrentOption := v;
  end;

  { Counter: "n/count", n counting from 1, padded to five characters }
  function Counter(v, count: Byte): Types.TStr40;
  var
    s: Types.TStr40;
  begin
    if v < count then
      s := StrUtil.NumStr(v + 1)
    else
      s := '?';
    s := s + '/' + StrUtil.NumStr(count);
    while Length(s) < 5 do
      s := s + ' ';
    Counter := s;
  end;

  { DrawItem: Item k of the left pane and its value, white when it is the current item and green otherwise; in the
    grid, the colour not being chosen is green. The menu (ITEM_MENU) is MenuHorizontal's to draw. }
  procedure DrawItem(k: Byte);
  var
    col: Byte;
    d1: Byte;
    d2: Byte;
  begin
    if k > LAST_PART then Exit;
    if k = cur then col := White else col := LightGreen;
    TextRend.DisplayString(ITEM_COL[k], ITEM_ROW[k], col, ITEM_NAME[k]);
    case k of
      ITEM_HEAD: TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, Counter(tHead, NUM_HEADS));
      ITEM_WEAPON: TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, Counter(tBody, NUM_WEAPONS));
      ITEM_SIZE: if tSize = 1 then
                   TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, 'Small')
                 else
                   TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, 'Large');
      FIRST_PART..LAST_PART:
        if PART_NIBBLE[k] = 2 then begin
          d1 := col;
          d2 := col;
          if inGrid and (k = cur) then
            if which = 0 then
              d2 := LightGreen
            else
              d1 := LightGreen;
          TextRend.DisplayString(DIGIT_COL, ITEM_ROW[k], d1, '1');
          TextRend.DisplayString(DIGIT_COL + 2, ITEM_ROW[k], d2, '2');
        end;
    end;
  end;

  { ShowCell: Draw grid cell k's icon, in the cursor box when it is the highlight and on the plain background
    otherwise }
  procedure ShowCell(k: Byte; boxed: Boolean);
  begin
    if (k > 15) or (cells[k] = nil) then Exit;
    Place(cells[k], 0, boxed, shownPic);
    Blit.ShowPic(GRID_COL[k mod 4], GRID_ROW[k div 4], shownPic);
  end;

  { DrawGrid: Compose and draw the page of options holding pick, one cell at a time, with "(more)" on the top row when
    there is a page before it and on the bottom row when there is one after it (the font has no arrows) }
  procedure DrawGrid;
  var
    k: Byte;
    opt: Integer;
    h: Byte;
    b: Byte;
    c: Types.TIconCols;
    first: Byte;
    top: Byte;
    moreBelow: Boolean;
  begin
    first := PageFirst(pick);
    if first > 0 then top := 4 else top := 0;
    moreBelow := first + PageSize(first) < OptionCount;
    { a page of several: "(more)" shows between the cells, so the whole grid is cleared first }
    if OptionCount > 16 then
      Border.ClearBox(18, GRID_ROW[0], 38, GRID_ROW[3] + 2);
    for k := 0 to 15 do begin
      opt := first + k - top;
      if ((k < 4) and (top > 0)) or ((k >= 12) and moreBelow) then begin
        { a "(more)" row, written at its first cell }
        if k mod 4 = 0 then
          TextRend.DisplayString(MORE_COL, GRID_ROW[k div 4] + 1, LightGreen, '(more)');
      end else if opt < first + PageSize(first) then begin
        h := tHead;
        b := tBody;
        c := tCols;
        OptionState(opt, h, b, c);
        BuildIcon(0, h, b, c);
        if (cells[k] <> nil) and (work <> nil) and (cells[k]^.imgSize = work^.imgSize)
           and (cells[k]^.transp <> nil) and (work^.transp <> nil) then begin
          Move(work^.data, cells[k]^.data, work^.imgSize);
          Move(work^.transp^, cells[k]^.transp^, Blit.MaskBytes(work^.imgSize));
        end;
        ShowCell(k, opt = pick);
      end else
        Border.ClearBox(GRID_COL[k mod 4], GRID_ROW[k div 4], GRID_COL[k mod 4] + 2, GRID_ROW[k div 4] + 2);
    end;
  end;

  { ShowPreviews: Draw the ready and action frames of the icon shown, in the cursor box; the ready frame of the
    highlight is its cell's icon }
  procedure ShowPreviews;
  begin
    if inGrid then
      Place(cells[CellOf(pick)], 0, True, readyPic)
    else
      Compose(0, tHead, tBody, tCols, readyPic);
    Blit.ShowPic(READY_COL, PREVIEW_ROW, readyPic);
    Compose(1, tHead, tBody, tCols, actionPic);
    Blit.ShowPic(ACTION_COL, PREVIEW_ROW, actionPic);
  end;

  { MsgLine: Print s centred in the message panel on row }
  procedure MsgLine(row: Byte; s: Types.TStr40);
  begin
    TextRend.DisplayCentered(18, 38, row, LightGreen, s);
  end;

  { ShowMessage: The message panel: what is being chosen and the keys, or nothing on the left }
  procedure ShowMessage;
  var
    top: Byte;
  begin
    Border.ClearBox(18, MSG_TOP, 38, MSG_BOTTOM);
    if not inGrid then Exit;
    if (cur >= FIRST_PART) and (cur <= LAST_PART) and (PART_NIBBLE[cur] = 2) then
      top := MSG_TOP
    else
      top := MSG_TOP + 1;
    if cur >= FIRST_PART then
      MsgLine(top, 'Choosing ' + ITEM_NAME[cur] + ' color')
    else
      MsgLine(top, 'Choosing ' + ITEM_NAME[cur]);
    MsgLine(top + 1, 'Arrows to select,');
    MsgLine(top + 2, 'Enter to choose');
    if top = MSG_TOP then begin
      MsgLine(top + 3, 'Space toggles');
      MsgLine(top + 4, 'color 1/2');
    end;
  end;

  { Revert: Make the icon shown the stored one; a size other than small reads as large }
  procedure Revert;
  begin
    with GameVars.curChar^ do begin
      tHead := iconHead;
      tBody := iconBody;
      if iconSize = 1 then tSize := 1 else tSize := 2;
      tCols := iconColors1;
    end;
  end;

  { MovePick: Move the highlight by an arrow key. Left and Right step through the options; Up and Down move a row,
    turning the page past its first or last row and wrapping at the ends }
  procedure MovePick(arrow: Char);
  var
    n: Integer;
    v: Integer;
  begin
    n := OptionCount;
    v := pick;
    case arrow of
      C_KEYS.LEFT: if v > 0 then Dec(v) else v := n - 1;
      C_KEYS.RIGHT: if v < n - 1 then Inc(v) else v := 0;
      C_KEYS.DOWN: if v + 4 < n then
                     Inc(v, 4)
                   else if v div 4 < (n - 1) div 4 then
                     v := n - 1
                   else
                     v := v mod 4;
      C_KEYS.UP: if v >= 4 then
                   Dec(v, 4)
                 else begin
                   v := ((n - 1) div 4) * 4 + v;
                   if v > n - 1 then
                     Dec(v, 4);
                 end;
    end;
    if (v >= 0) and (v < n) then
      pick := v;
  end;

  { ChooseInGrid: Run the right pane for the current item until Enter keeps the highlighted option or Escape leaves
    the icon as it was }
  procedure ChooseInGrid;
  var
    old: Byte;
    finished: Boolean;
  begin
    inGrid := True;
    which := 0;
    pick := CurrentOption;
    { the menu's keys do nothing here }
    TextRend.ClearBottomLine;
    DrawItem(cur);
    ShowMessage;
    DrawGrid;
    ShowPreviews;
    finished := False;
    repeat
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('', '', LightMagenta, LightGreen, White, True, False, ext);
      if ext then begin
        if key in [C_KEYS.UP, C_KEYS.DOWN, C_KEYS.LEFT, C_KEYS.RIGHT] then begin
          old := pick;
          MovePick(key);
          if pick <> old then begin
            OptionState(pick, tHead, tBody, tCols);
            if PageFirst(pick) <> PageFirst(old) then
              DrawGrid
            else begin
              ShowCell(CellOf(old), False);
              ShowCell(CellOf(pick), True);
            end;
            DrawItem(cur);
            ShowPreviews;
          end;
        end;
      end else
        case key of
          C_KEYS.ENTER: begin
              with GameVars.curChar^ do
                case cur of
                  ITEM_HEAD: iconHead := tHead;
                  ITEM_WEAPON: iconBody := tBody;
                else
                  iconColors1 := tCols;
                end;
              finished := True;
            end;
          C_KEYS.NONE: begin
              Revert;
              finished := True;
            end;
          ' ': if (cur >= FIRST_PART) and (cur <= LAST_PART) and (PART_NIBBLE[cur] = 2) then begin
              which := 1 - which;
              pick := CurrentOption;
              DrawItem(cur);
              DrawGrid;
            end;
        end;
    until finished;
    inGrid := False;
    Border.ClearBox(18, 1, 38, 16);
    ShowMessage;
    DrawItem(cur);
    ShowPreviews;
  end;

  { Confirmed: Ask whether the icon is ok on the bottom line; on No, the menu comes back there, on Keep, for more
    editing }
  function Confirmed: Boolean;
  begin
    if MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White) = 'Y' then
      Confirmed := True
    else begin
      GameVars.horizChoice := 1;
      Confirmed := False;
    end;
  end;

begin
  savedChoice := GameVars.horizChoice;
  with GameVars.curChar^ do begin
    savedHead := iconHead;
    savedBody := iconBody;
    savedSize := iconSize;
    savedCols := iconColors1;
  end;
  for i := 0 to 1 do
    for j := 0 to 1 do begin
      loaded[i, j] := nil;
      loadedBlock[i, j] := NO_BLOCK;
    end;
  Blit.AllocPic(ICON_H, ICON_W, 1, 1, work);
  for i := 0 to 15 do
    Blit.AllocPic(ICON_H, ICON_W, 1, 1, cells[i]);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, readyPic);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, actionPic);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, shownPic);
  inGrid := False;
  which := 0;
  pick := 0;
  cur := ITEM_HEAD;
  Revert;
  TextRend.ClearScreen;
  CbtMap.SetCombatPalette;
  Border.DrawBorder(1, 1, 16, 22, 0);
  Border.DrawBorder(18, 1, 38, 22, 0);
  Border.DrawBorder(18, MSG_TOP, 38, MSG_BOTTOM, 0);
  with GameVars.curChar^ do
    TextRend.DisplayCentered(1, 16, 1, Cyan, name);
  TextRend.DisplayString(READY_COL - 1, LABEL_ROW, LightGreen, 'Ready');
  TextRend.DisplayString(ACTION_COL - 1, LABEL_ROW, LightGreen, 'Action');
  TextRend.DisplayString(2, COLOR_ROW, LightGreen, 'Color');
  for i := ITEM_HEAD to LAST_PART do
    DrawItem(i);
  ShowPreviews;
  done := False;
  GameVars.horizChoice := 1;
  repeat
    { on the left pane the arrows and Enter come back here; on the menu Left and Right step through it and Enter takes
      the option there }
    MenuCore.arrowsToCaller := cur <> ITEM_MENU;
    MenuCore.enterToCaller := cur <> ITEM_MENU;
    key := MenuCore.MenuHorizontal('', 'Keep Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if key in [C_KEYS.UP, C_KEYS.DOWN] then begin
        i := cur;
        if key = C_KEYS.UP then begin
          if cur = ITEM_HEAD then cur := ITEM_MENU else Dec(cur);
        end else if cur = ITEM_MENU then
          cur := ITEM_HEAD
        else
          Inc(cur);
        DrawItem(i);
        DrawItem(cur);
      end;
    end else
      case key of
        C_KEYS.ENTER: case cur of
            ITEM_SIZE: begin
                tSize := 3 - tSize;
                GameVars.curChar^.iconSize := tSize;
                DrawItem(cur);
                ShowPreviews;
              end;
          else
            ChooseInGrid;
          end;
        'K': done := Confirmed;
        'E', C_KEYS.NONE: begin
            with GameVars.curChar^ do begin
              iconHead := savedHead;
              iconBody := savedBody;
              iconSize := savedSize;
              iconColors1 := savedCols;
            end;
            done := True;
          end;
      end;
  until done;
  for i := 0 to 1 do
    for j := 0 to 1 do
      Blit.FreePic(loaded[i, j]);
  Blit.FreePic(work);
  for i := 0 to 15 do
    Blit.FreePic(cells[i]);
  Blit.FreePic(readyPic);
  Blit.FreePic(actionPic);
  Blit.FreePic(shownPic);
  { a party member's combat icon; a character being created has no slot of its own yet }
  if Party.IsPartyMember(GameVars.curChar) and (GameVars.curChar^.orderNumber < Types.MAX_PARTY) then begin
    SaveLoad.LoadCharIconAnim(True);
    if GameVars.gLocType > C_AREA.LOC_3D_MAP then
      { the party map icon LoadCharIconAnim freed }
      MapTiles.LoadIconAnim('ICON', 0, 11);
  end;
  TextRend.ClearBottomLine;
  CbtMap.SetNoncombatPalette;
  GameVars.horizChoice := savedChoice;
end;

end.
