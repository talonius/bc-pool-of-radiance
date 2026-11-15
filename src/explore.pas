{ Dungeon and wilderness movement, door opening and the map menu. }
{$O+,F+}
{$I COMPILER.INC}
unit Explore;

interface

uses Types;

procedure ResolveMovement;

function MapMainMenu: Char;

{ F1, F2, F4, F6 and Alt-1 to Alt-8 on the map and camp menus: the Command Keys window (KeyHelp.ShowKeys, #855;
  quickKeys says whether it lists F5 and F8), the Bestiary (#842), the training hall's menu while the Train Anywhere
  setting is on (CharGen.TrainAnywhere, #1212), the Companion Tools while that setting is on (phase 8) and party
  member n's items (ViewChar.AltItems, #1175; nothing without a member n), each followed by the screen drawn
  again (CharDisp.DisplayWildernessInterface when wild, else DisplayNoncombatInterface). False for any other key, which
  the caller handles. }
function SideScreen(c: Char; quickKeys, wild: Boolean): Boolean;

{ The party member who would cast Knock at a door (#1015): the first Okay member with it memorized (scroll nil), or
  else the first Okay member who can use items and carries a scroll with Knock on it that it can read and use
  (Magic.FindScrollCopies; scroll the one to read). False, with caster nil, when nobody can. }
function FindKnockCaster(var caster: Types.PCharRecord; var scroll: Types.PItemRec): Boolean;

var
  { Set by F8 on the map menu when there is a quick save to load: MapMainMenu returns, GameLoop returns, and the
    program loads it (SaveLoad.QuickLoad) and runs GameLoop again; the program clears it. }
  quickLoadAsked: Boolean;
  { 0 when an ECL script has written a message to the bottom text window; Explore.MapMainMenu clears that window on its
    way out and sets it back to 1 }
  bottomMessageCleared: Byte;

{ Put the doors in a new game's state, every way of opening one (bash, pick, knock) still to try
  (GameInit.ResetGameState). }
procedure ResetGame;

implementation

uses Crt, C_AREA, C_TIME, C_MSG, GameDefs, GameVars, SoundDrv, Camp, ViewChar, JrnlView, View3D, MapTiles, C_ECL,
  C_KEYS, C_LEVEL, C_STATUS, C_GBVM, C_DIR, C_SOUND, C_SPELL, SaveLoad, Blit, Border, CharHlp, FxEngine,
  MenuCore, Portrait, TextRend, CharDisp, Party, Dice, CompTool, KeyHelp, BeastMnu, Magic, JrnlSeen, Wilds,
  CharGen, UiColor;

var
  { Door-opening flags: bash, pick and knock. }
  doorOpen: array[0..2] of Byte;
  { the wilderness menu's Move mode (#1159), on from Move until Exit, Escape or the party leaves the wilderness }
  moveMode: Boolean;

{ ChangeBarrierImpassable: clear the facing's two BARRIER bits (barriers plane), making it barrier type 0; the wall
  nibbles are untouched, and coordinates outside the map (0..Types.MAP_LAST) are ignored. }
procedure ChangeBarrierImpassable(x, y: ShortInt; facing: Byte);
begin
  if not Types.OnMap(x, y) then Exit;
  case facing of
    C_DIR.WEST: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $3F;
    C_DIR.SOUTH: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $CF;
    C_DIR.EAST: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $F3;
    C_DIR.NORTH: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $FC;
  end;
end;

{ ChangeBarrierPassable: set the facing's two BARRIER bits to 01 (type 1, open); coordinates outside the map
  (0..Types.MAP_LAST) are ignored. }
procedure ChangeBarrierPassable(x, y: ShortInt; facing: Byte);
begin
  if not Types.OnMap(x, y) then Exit;
  case facing of
    C_DIR.WEST: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $3F or $40;
    C_DIR.SOUTH: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $CF or $10;
    C_DIR.EAST: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $F3 or $4;
    C_DIR.NORTH: GameVars.map3d^.barriers[y, x] := GameVars.map3d^.barriers[y, x] and $FC or $1;
  end;
end;

{ Open the barrier the party faces, from both sides: its own cell's side and the facing cell's opposite side. }
procedure OpenBarrierAhead;
begin
  Explore.ChangeBarrierPassable(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
  Explore.ChangeBarrierPassable(GameVars.gMapX + GameDefs.dirDX[GameVars.gFacing],
                                GameVars.gMapY + GameDefs.dirDY[GameVars.gFacing], (GameVars.gFacing + 4) mod 8);
end;

{ Return True if any party member has a level in the requested class. }
function PartyHasClass(idx: ShortInt): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not found) do begin
    if CharHlp.GetClassLevel(p, 1 shl idx) > 0 then found := True;
    p := p^.nextCharAddr;
  end;
  PartyHasClass := found;
end;

{ BashDoor: Okay party members try in list order, on the AD&D Strength open-doors table, until one succeeds. BARRIER
  type 3 (barred door) uses the locked/barred/magically-held column: 18/91 to 25 roll, and each member below 18/91
  clears doorOpen[0] so Bash is not offered again at this door (later members still try this time). Otherwise the normal
  column covers Strength 3 to 25 (19 and above, from a Potion of Giant Strength, on the Players Handbook's odds).
  Strength above 25 counts as 25 and exceptional strength above 100 as 18/00. Success opens the barrier from both
  sides. }
function BashDoor: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not success) do begin
    { only an Okay member can force the door }
    if p^.status = C_STATUS.OKAY then
    with p^ do begin
      if View3D.GetBarrierType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing) = 3 then begin
        case strCur of
          18: case strExc of
                 91..99: if Dice.RollDice(1, 6) = 1 then success := True;
                 100..255: if Dice.RollDice(1, 6) <= 2 then success := True;
               else
                 doorOpen[0] := 0;
               end;
          19, 20: if Dice.RollDice(1, 6) <= 3 then success := True;
          21, 22: if Dice.RollDice(1, 6) <= 4 then success := True;
          23: if Dice.RollDice(1, 6) <= 5 then success := True;
          24: if Dice.RollDice(1, 8) <= 7 then success := True;
          25..255: if Dice.RollDice(1, 10) <= 9 then success := True;
        else
          doorOpen[0] := 0;
        end;
      end else
        case strCur of
          3..7: if Dice.RollDice(1, 6) = 1 then success := True;
          8..15: if Dice.RollDice(1, 6) <= 2 then success := True;
          16..17: if Dice.RollDice(1, 6) <= 3 then success := True;
          18: case strExc of
                 0..50: if Dice.RollDice(1, 6) <= 3 then success := True;
                 51..99: if Dice.RollDice(1, 6) <= 4 then success := True;
                 100..255: if Dice.RollDice(1, 6) <= 5 then success := True;
               end;
          19, 20: if Dice.RollDice(1, 8) <= 7 then success := True;
          21: if Dice.RollDice(1, 10) <= 9 then success := True;
          22, 23: if Dice.RollDice(1, 12) <= 11 then success := True;
          24: if Dice.RollDice(1, 20) <= 19 then success := True;
          25..255: if Dice.RollDice(1, 24) <= 23 then success := True;
        end;
    end;
    p := p^.nextCharAddr;
  end;
  if success then
    Explore.OpenBarrierAhead;
  BashDoor := success;
end;

{ PickLock: each Okay party member in turn rolls d100 against Open Locks (thiefSkills[2]). One attempt per door:
  doorOpen[1] is cleared whatever the result. Success opens the barrier from both sides. }
function PickLock: Boolean;
var
  p: Types.PCharRecord;
  success: Boolean;
begin
  success := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not success) do begin
    with p^ do
      if (status = C_STATUS.OKAY) and (Dice.RollDice(1, 100) <= thiefSkills[2]) then
        success := True;
    p := p^.nextCharAddr;
  end;
  doorOpen[1] := 0;
  if success then
    Explore.OpenBarrierAhead;
  PickLock := success;
end;

{ Return the first memorized-spell slot (0..Types.MEMORIZED_LAST, CharHlp.MemorizedAt) holding spellId, or 255 when
  none does. }
function FindMemorizedSpell(spellId: Byte; creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  i := 0;
  while (i <= Types.MEMORIZED_LAST) and (CharHlp.MemorizedAt(creature, i) <> spellId) do
    Inc(i);
  if i <= Types.MEMORIZED_LAST then
    FindMemorizedSpell := i
  else
    FindMemorizedSpell := 255;
end;

{ Return the first Okay party member with spellId memorized, or nil: a dead, unconscious or otherwise disabled member
  cannot cast. }
function FindCharWithSpell(spellId: Byte): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  while (p <> nil) and ((p^.status <> C_STATUS.OKAY) or (Explore.FindMemorizedSpell(spellId, p) = 255)) do
    p := p^.nextCharAddr;
  FindCharWithSpell := p;
end;

function FindKnockCaster(var caster: Types.PCharRecord; var scroll: Types.PItemRec): Boolean;
var
  p: Types.PCharRecord;
  copies: Byte;
begin
  scroll := nil;
  caster := Explore.FindCharWithSpell(C_SPELL.KNOCK);
  p := GameVars.creatureList;
  while (caster = nil) and (p <> nil) do begin
    if (p^.status = C_STATUS.OKAY) and CharHlp.CanUseItems(p) then begin
      Magic.FindScrollCopies(p, C_SPELL.KNOCK, copies, scroll);
      if scroll <> nil then
        caster := p;
    end;
    p := p^.nextCharAddr;
  end;
  FindKnockCaster := caster <> nil;
end;

{ PartyCastsKnock: the party member FindKnockCaster names casts Knock (C_SPELL.KNOCK), clearing the memorized slot or
  taking the spell off the scroll (which may use it up), and the barrier opens from both sides; False when nobody
  can. }
function PartyCastsKnock: Boolean;
var
  p: Types.PCharRecord;
  scroll: Types.PItemRec;
begin
  PartyCastsKnock := Explore.FindKnockCaster(p, scroll);
  if p <> nil then begin
    if scroll = nil then
      CharHlp.RemoveSpell(p, C_SPELL.KNOCK)
    else begin
      Magic.RemoveSpellFromScroll(p, scroll, C_SPELL.KNOCK);
      { recount the items and their weight, as Items > Use does: the scroll may be gone }
      CharHlp.RecalcStats(p);
    end;
    Explore.OpenBarrierAhead;
  end;
end;

{ MoveForward: clear C_GBVM.LEAVE_MAP, then, unless the barrier ahead is type 0, compute the next square without moving
  there. A step off the 16x16 map puts gMapX/gMapY on that edge and sets C_GBVM.LEAVE_MAP to 1. }
procedure MoveForward;
var
  nx: Integer;
  ny: Integer;
  f: Integer;
begin
  nx := GameVars.gMapX;
  ny := GameVars.gMapY;
  f := GameVars.gFacing;
  GameVars.zone1^[C_GBVM.LEAVE_MAP] := 0;
  if View3D.GetBarrierType(nx, ny, f) <> 0 then begin
    Inc(nx, GameDefs.dirDX[f]);
    Inc(ny, GameDefs.dirDY[f]);
    if nx > Types.MAP_LAST then begin
      GameVars.gMapX := Types.MAP_LAST;
      GameVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if nx < 0 then begin
      GameVars.gMapX := 0;
      GameVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if ny > Types.MAP_LAST then begin
      GameVars.gMapY := Types.MAP_LAST;
      GameVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
    if ny < 0 then begin
      GameVars.gMapY := 0;
      GameVars.zone1^[C_GBVM.LEAVE_MAP] := 1;
    end;
  end;
end;

{ MovePartyForward3D: play the step sound, step with 16x16 edge wrap, refresh wallAhead and eventAtCell, reset the door
  flags and advance the clock one minute, or one turn when Search (C_GBVM.SEARCH_FLAGS bit 0) is on. EclVm.GameLoop
  plays the step sound again once the party has moved, as SSI's code does; a driver that sets singleStep (the Sound
  Blaster's) gets GameLoop's alone (POR-0170). }
procedure MovePartyForward3D;
begin
  if not GameVars.sound.singleStep then
    SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
  Inc(GameVars.gMapX, GameDefs.dirDX[GameVars.gFacing]);
  Inc(GameVars.gMapY, GameDefs.dirDY[GameVars.gFacing]);
  View3D.WrapCoords(GameVars.gMapX, GameVars.gMapY);
  GameVars.wallAhead := View3D.GetWallType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
  FillChar(doorOpen, SizeOf(doorOpen), 1);
  GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
  if GameVars.zone1^[C_GBVM.SEARCH_FLAGS] and 1 > 0 then
    FxEngine.AdvanceTime(1, C_TIME.TURNS)
  else
    FxEngine.AdvanceTime(1, C_TIME.MINUTES);
end;

{ End the wilderness menu's Move mode (#1159) and its wide view (#1186): the 5x5 view's buffer comes back; the caller
  draws the screen. }
procedure EndMoveMode;
begin
  moveMode := False;
  Wilds.wideWanted := False;
  Wilds.ShowWide(False);
end;

{ MovePartyWilderness: one step toward gFacing on the 44x36 wilderness map, held to the region (Wilds.StepTo). Impassable
  terrain blocks, and so does a diagonal between two cells that are not open (#1159); river glyphs block with a message
  until zone0^.yarashPyramidLeft is nonzero. A step advances the clock 12 hours, a diagonal one 18 (#1159). }
procedure MovePartyWilderness;
var
  nx: ShortInt;
  ny: ShortInt;
  diagonal: Boolean;
begin
  case Wilds.StepTo(GameVars.zone0^.partyX.value, GameVars.zone0^.partyY.value, GameVars.gFacing,
                    GameDefs.wildColOfs[GameVars.gLocType], GameVars.zone0^.yarashPyramidLeft = 0, nx, ny) of
    Wilds.STEP_OPEN: begin
        diagonal := (nx <> GameVars.zone0^.partyX.value) and (ny <> GameVars.zone0^.partyY.value);
        GameVars.zone0^.partyX.value := nx;
        GameVars.zone0^.partyY.value := ny;
        if diagonal then
          FxEngine.AdvanceTime(Wilds.DIAGONAL_HOURS, C_TIME.HOURS)
        else
          FxEngine.AdvanceTime(Wilds.STEP_HOURS, C_TIME.HOURS);
      end;
    Wilds.STEP_RIVER: TextRend.PrintAndPause('The river''s stench drives you back.', Yellow);
  end;
end;

{ F8 on the map menu: when the quick-save slot holds a game, set quickLoadAsked and return True, ending the menu so
  GameLoop can return and the program load it; otherwise say there is none and return False. }
function AskQuickLoad: Boolean;
begin
  AskQuickLoad := SaveLoad.QuickLoadable;
  if SaveLoad.QuickLoadable then begin
    quickLoadAsked := True;
    { the loaded game starts out of Move mode, with the view buffer its scripts draw into }
    Explore.EndMoveMode;
  end else begin
    TextRend.DisplayAndPause(Yellow, 'There is no quick save.');
    TextRend.ClearBottomLine;
  end;
end;

function SideScreen(c: Char; quickKeys, wild: Boolean): Boolean;
var
  shown: Boolean;
  member: Types.PCharRecord;
begin
  member := nil;
  case c of
    C_KEYS.F1, C_KEYS.F2: shown := True;
    { a party member's items (#1175); with no member n, nothing }
    C_KEYS.ALT_1..C_KEYS.ALT_8: begin
                                  if Party.AltMember(c) > 0 then
                                    member := Party.MemberAt(Party.AltMember(c));
                                  shown := member <> nil;
                                end;
    { with the setting off, nothing }
    C_KEYS.F4: shown := GameVars.trainAnywhereOn <> 0;
    C_KEYS.F6: shown := GameVars.companionOn <> 0;
  else begin
    SideScreen := False;
    Exit;
  end;
  end;
  SideScreen := True;
  if not shown then Exit;
  { the screens draw into the 5x5 view's buffer (a portrait on the items screen), so the wide view goes until the screen
    is drawn again below (#1186) }
  Wilds.ShowWide(False);
  case c of
    C_KEYS.F1: KeyHelp.ShowKeys(quickKeys);
    C_KEYS.ALT_1..C_KEYS.ALT_8: ViewChar.MemberItems(member);
    C_KEYS.F2: BeastMnu.BestiaryMenu;
    C_KEYS.F4: CharGen.TrainAnywhere;
    C_KEYS.F6: CompTool.ToolsMenu;
  end;
  { a game loaded from the training hall's menu starts out of Move mode, as a quick load does (AskQuickLoad) }
  if GameVars.loadedSave <> 0 then
    Explore.EndMoveMode;
  if wild then
    CharDisp.DisplayWildernessInterface
  else
    CharDisp.DisplayNoncombatInterface;
end;

{ MapMainMenu: the 3D / wilderness command loop. Returns the key that ended it: 'E' (Encamp), 'L' (Look: sets
  C_GBVM.SEARCH_FLAGS bit 1, advances the clock one turn and points eclIp at the search script entry), an arrow scan
  code (in 3D 'H' after MoveForward, in the wilderness 'H', 'M', 'P' or 'K' after setting the facing), or F8's after
  AskQuickLoad has set quickLoadAsked. F5 quick-saves (SaveLoad.QuickSave) and F1, F2, F4, F6 and Alt-1 to Alt-8 open
  their screens (SideScreen); the menu goes on after each. In 3D the other arrows turn the party. Cast goes to
  Camp.NoncombatCastMenu, which says why a character who cannot cast cannot; SSI's 3D menu ignored Cast from a
  character not Okay. The wilderness menu's Move, as Pools of Darkness's, turns the bottom line to Exit: there the
  arrows and Home, Page Up, End and Page Down (the keypad's 7, 9, 1 and 3) set the facing in all eight directions and
  end the menu for the step, until Exit or Escape (#1159); the mode lasts between steps while the party stays in the
  wilderness. Move mode shows the wide view across the top of the screen, the status line before Exit on the bottom
  line (#1186); a script that narrows it during a step (Wilds.KeepsWide) leaves it narrow until the menu comes back,
  which widens it again. }
function MapMainMenu: Char;
const
  { 3D exploration menu }
  menu3D: String[40] = 'Area Cast View Encamp Search Look Jrnl';
  { wilderness exploration menu; Move turns to menuMove (#1159) }
  menuWild: String[40] = 'Move Cast View Encamp Search Look Jrnl';
  menuMove: String[40] = 'Exit';
var
  done: Boolean;
  c: Char;
  ext: Boolean;
  viewDone: Boolean;
  wild: Boolean;

  { 3D: turn the party by eighths of a circle, with the step sound when sound, and draw the view again. }
  procedure Turn(eighths: Byte; sound: Boolean);
  begin
    GameVars.gFacing := (GameVars.gFacing + eighths) mod 8;
    if sound then
      SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
    GameVars.wallAhead := View3D.GetWallType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
    View3D.Display3DMapView(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
  end;

  { Move mode's keys (#1159): an arrow or a diagonal key faces that way and ends the menu for the step; any other key
    does nothing. }
  procedure MoveKey(key: Char);
  const
    keys: array[C_DIR.NORTH..C_DIR.NORTHWEST] of Char = (
      C_KEYS.UP, C_KEYS.PAGE_UP, C_KEYS.RIGHT, C_KEYS.PAGE_DOWN, C_KEYS.DOWN, C_KEYS.END_KEY, C_KEYS.LEFT, C_KEYS.HOME);
  var
    dir: Byte;
  begin
    for dir := C_DIR.NORTH to C_DIR.NORTHWEST do
      if keys[dir] = key then begin
        GameVars.gFacing := dir;
        done := True;
      end;
  end;

  { An arrow key: in the wilderness, face dir and end the menu for the step; in 3D, step forward (ahead) or Turn. }
  procedure Arrow(dir, eighths: Byte; sound, ahead: Boolean);
  begin
    if wild then begin
      GameVars.gFacing := dir;
      done := True;
    end else if ahead then begin
      Explore.MoveForward;
      done := True;
    end else
      Turn(eighths, sound);
  end;

begin
  c := C_KEYS.NONE;
  GameVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
  wild := GameVars.gLocType in [C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST];
  if not wild then
    Explore.EndMoveMode;
  if wild or (GameVars.gLocType = C_AREA.LOC_3D_MAP) then begin
    if wild and (GameVars.locTypePrev < C_AREA.LOC_WILD_WEST) then begin
      MapTiles.LoadWildIcons;
      CharDisp.DisplayWildernessInterface;
    end;
    done := False;
    repeat
      MenuCore.arrowsToCaller := True;
      MenuCore.quickKeysToCaller := True;
      MenuCore.helpToCaller := True;
      { Move mode's wide view, on Move and again after a script narrowed it during a step }
      if Wilds.wideWanted then
        CharDisp.SetWildView(True);
      { the status line before Exit while the wide view hides the party window, in the window's light green }
      if moveMode and Wilds.wideShown then
        c := MenuCore.MenuHorizontal(CharDisp.MiscInfoText + ' ', menuMove, LightGreen, LightGreen, White, True, False,
                                     ext)
      else if moveMode then
        c := MenuCore.MenuHorizontal('', menuMove, promptColor, optionColor, commandColor, True, False, ext)
      else if wild then
        c := MenuCore.MenuHorizontal('', menuWild, promptColor, optionColor, commandColor, True, False, ext)
      else
        c := MenuCore.MenuHorizontal('', menu3D, promptColor, optionColor, commandColor, True, False, ext);
      if not ext and moveMode then begin
        { Exit or Escape }
        if c in [C_KEYS.NONE, 'E'] then begin
          CharDisp.SetWildView(False);
          Explore.EndMoveMode;
        end;
      end else if not ext then begin
        case c of
          { the next pass shows the wide view }
          'M': if wild then begin
                 moveMode := True;
                 Wilds.wideWanted := True;
               end;
          { STING maps anywhere, as Curse's debug mode does; elsewhere the Journal's map of the area allows it (#1090) }
          'A': if JrnlSeen.AreaMapAllowed or GameVars.stingArg then begin
                 GameVars.automapOn := not GameVars.automapOn;
                 View3D.Display3DMapView(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
               end else
                 TextRend.PrintAndPause('Not Here', Yellow);
          'C': Camp.NoncombatCastMenu;
          'V': ViewChar.ViewCharMenu(viewDone);
          'J': JrnlView.JournalMenu;
          'E': done := True;
          'S': GameVars.zone1^[C_GBVM.SEARCH_FLAGS] := GameVars.zone1^[C_GBVM.SEARCH_FLAGS] xor 1;
          'L': begin
                 GameVars.zone1^[C_GBVM.SEARCH_FLAGS] := GameVars.zone1^[C_GBVM.SEARCH_FLAGS] or 2;
                 FxEngine.AdvanceTime(1, C_TIME.TURNS);
                 GameVars.eclIp := GameVars.scriptEntryAddrs[C_ECL.ENTRY_SEARCH];
                 done := True;
               end;
        end;
      end else if not Explore.SideScreen(c, True, wild) then
        if moveMode and (c <> C_KEYS.F5) and (c <> C_KEYS.F8) then
          { Home and End step here, so they don't pick the character }
          MoveKey(c)
        else
          case c of
            C_KEYS.UP: Arrow(C_DIR.NORTH, 0, False, True);
            { 3D: turn around, without the step sound }
            C_KEYS.DOWN: Arrow(C_DIR.SOUTH, 4, False, False);
            C_KEYS.LEFT: Arrow(C_DIR.WEST, 6, True, False);
            C_KEYS.RIGHT: Arrow(C_DIR.EAST, 2, True, False);
            C_KEYS.F5: SaveLoad.QuickSave;
            C_KEYS.F8: done := Explore.AskQuickLoad;
          else begin
            Party.SelectPrevNextChar(c);
            CharDisp.DisplayParty(GameVars.curChar);
          end;
          end;
      CharDisp.PrintMiscInfo;
    until done;
  end;
  GameVars.locTypePrev := GameVars.gLocType;
  if bottomMessageCleared = 0 then begin
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    bottomMessageCleared := 1;
  end;
  MapMainMenu := c;
end;

{ The 'Locked.' menu for the door ahead, barred when its barrier is type 3, assembled from the door flags: Bash, Pick
  (party has a thief), Knock (someone has it memorized or on a scroll it can read, FindKnockCaster) and Exit; a bare
  ' Exit' walls the door off. On a barred door Pick only clears doorOpen[1]. SSI's code offered Knock at a barred door
  to any party with a magic-user, though only a memorized Knock opened it, so the door was never walled off (POR-0229,
  #1015). True when the door opens. }
function DoorMenu(barred: Boolean): Boolean;
var
  menuStr: String[40];
  unusedExtendedKey: Boolean;
  caster: Types.PCharRecord;
  scroll: Types.PItemRec;
begin
  DoorMenu := False;
  menuStr := '';
  if doorOpen[0] <> 0 then
    menuStr := 'Bash';
  if (doorOpen[1] <> 0) and Explore.PartyHasClass(C_LEVEL.THIEF) then
    menuStr := menuStr + ' Pick';
  if (doorOpen[2] <> 0) and Explore.FindKnockCaster(caster, scroll) then
    menuStr := menuStr + ' Knock';
  menuStr := menuStr + ' Exit';
  if menuStr = ' Exit' then
    Explore.ChangeBarrierImpassable(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing)
  else
    case MenuCore.MenuHorizontal('Locked. ', menuStr, promptColor, optionColor, commandColor, False, False,
                                 unusedExtendedKey) of
      'B': DoorMenu := Explore.BashDoor;
      'P': if barred then
             doorOpen[1] := 0
           else
             DoorMenu := Explore.PickLock;
      'K': DoorMenu := Explore.PartyCastsKnock;
    end;
end;

{ ResolveMovement: while C_GBVM.MOVE_LOCKED is 255 movement is refused and the flag is reset to 0 instead. On a 3D map
  BARRIER type 1 steps forward and type 0 or an unopened door plays the impact sound. Types 2 and 3 run the 'Locked.'
  door menu (DoorMenu). A wilderness map takes a MovePartyWilderness step. The portrait and animation buffers are always
  freed on the way out. }
procedure ResolveMovement;
var
  moved: Boolean;
  barrier: Byte;
begin
  moved := False;
  case GameVars.gLocType of
    C_AREA.LOC_3D_MAP: if GameVars.zone1^[C_GBVM.MOVE_LOCKED] < 255 then begin
         barrier := View3D.GetBarrierType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
         case barrier of
           1: moved := True;
           2, 3: moved := Explore.DoorMenu(barrier = 3);
         end;
         if moved then
           Explore.MovePartyForward3D
         else
           SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.IMPACT], C_SOUND.GROUP_WALL);
         CharDisp.PrintMiscInfo;
       end else
         GameVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
    C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST: if GameVars.zone1^[C_GBVM.MOVE_LOCKED] < 255 then begin
            Explore.MovePartyWilderness;
            CharDisp.PrintMiscInfo;
          end else
            GameVars.zone1^[C_GBVM.MOVE_LOCKED] := 0;
  end;
  Portrait.FreeAnimation(GameVars.animData);
  Blit.FreePic(GameVars.portraits[1].pic);
  Blit.FreePic(GameVars.portraits[2].pic);
  GameVars.portraits[1].pictureId := 255;
  GameVars.portraits[2].pictureId := 255;
end;

procedure ResetGame;
begin
  FillChar(doorOpen, SizeOf(doorOpen), 1);
  Explore.EndMoveMode;
end;

begin
  quickLoadAsked := False;
  bottomMessageCleared := 0;
  moveMode := False;
end.
