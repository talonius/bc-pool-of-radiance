{ Implements the Companion Tools character editor. It edits party members in
  place from their character sheets. The tools can change abilities, hit
  points, levels, equipment, money, known spells, and health. Level increases
  use the normal training code; decreases remove the average hit points for the
  lost hit die. Edited characters are not specially marked. }
{$O+,F+}
{$I COMPILER.INC}
unit CharEdit;

interface

{ Edit the party's characters until Exit or Escape, starting with curChar; Up, Down, Home and End pick another. }
procedure EditMenu;

implementation

uses Crt, Types, C_STAT, C_ITEM, C_KEYS, C_LEVEL, C_MONEY, C_MSG, C_SPELL, C_STATUS, GameDefs, GameVars, Border,
  CharDisp, CharGen, CharHlp, ChgClass, ClassCal, MenuCore, Party, RandItem, Shop, StrUtil, TextRend, ViewChar;

const
  { the Levels screen's first row and its columns }
  LEVEL_ROW = 4;
  NAME_COL = 3;
  VALUE_COL = 16;
  { the Add list: titles, weapons and armour by item type, the magic items by template (TEMPLATE_CODE + template) and
    the scrolls by item type; lines past MAX_LINES are left off }
  MAX_LINES = 100;
  TEMPLATE_CODE = 256;
  { the item type each of RandItem.randomItemTemplates is made on, as RandItem rolls them; 0 for the Scroll of Restoring
    Levels, which RandItem never makes }
  TEMPLATE_KINDS: array[1..RandItem.TEMPLATE_LAST] of Byte = (
    71, 84, 71, 71, 0, 69, 78, 79, 78, 63, 71, 70, 92, 21, 78, 69, 69, 70, 67);
  { the highest plus a weapon or armour takes here: name parts run to +5 (C_ITEM.NAME_PLUS_BASE) }
  PLUS_LAST = 5;
  { the bracers' choices, AC 6, 4 and 2: their plus, as RandItem gives it, and their name part; each is worth 3000 gp a
    point of plus }
  BRACERS_LAST = 3;
  BRACERS_PLUS: array[1..BRACERS_LAST] of Byte = (4, 6, 8);
  BRACERS_NAME: array[1..BRACERS_LAST] of Byte = (C_ITEM.NAME_AC_6, C_ITEM.NAME_AC_4, C_ITEM.NAME_AC_2);
  BRACERS_GP = 3000;

type
  THeld = array[0..7] of ShortInt;
  TCodes = array[0..MAX_LINES] of Word;

{ The class slots (C_LEVEL) curChar has levels in, in order, and how many; a class a dual-classed human has left is not
  one, as its level is kept as it was (#838). }
procedure HeldClasses(var held: THeld; var count: Byte);
var
  cls: ShortInt;
begin
  count := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if (GameVars.curChar^.classLevels[cls] > 0) and (GameVars.curChar^.portExt.formerClasses and (1 shl cls) = 0) then
    begin
      held[count] := cls;
      Inc(count);
    end;
end;

{ A level of class slot cls taken off curChar: hit points less a hit die's average and the class's Constitution bonus
  divided by the class count (at least 1, not below ClassCal.HpMinimum, damage kept), the skills recalculated, and a
  cleric or magic-user back at level 1 given level 1's one slot. A dual-classed human's level that gave no hit points
  (ClassCal.HitDice) takes none, and a class it left that the lower level puts back to rest rests
  (ChgClass.SyncClassPowers). }
procedure LowerLevel(cls: ShortInt; clsCount: Byte);
var
  avg: Integer;
  loss: Integer;
  gave: Boolean;
begin
  with GameVars.curChar^ do begin
    if classLevels[cls] <= 1 then Exit;
    gave := ClassCal.HitDice(GameVars.curChar, cls) > 0;
    avg := GameDefs.hpSides[cls] div 2 + 1;
    loss := (avg + ClassCal.ConHpPerDie(cls, stats[C_STAT.CONSTITUTION])) div clsCount;
    if loss < 1 then
      loss := 1;
    Dec(classLevels[cls]);
    if gave then begin
      CharGen.SetHpMax(hpMax - loss);
      if hpRolled > avg div clsCount then
        Dec(hpRolled, avg div clsCount);
    end;
    if classLevels[cls] = 1 then
      case cls of
        C_LEVEL.CLERIC: ClassCal.ResetClericSlots(Types.PCharRecord(GameVars.curChar));
        C_LEVEL.MAGE: ClassCal.FirstLevelSlots(Types.PCharRecord(GameVars.curChar), C_LEVEL.MAGE);
      end;
    { the level drained or lowered to is the creature's level, as EffHndlr's drain sets it }
    levelHighest := 0;
    ClassCal.RecalcBaseSkills(Types.PCharRecord(GameVars.curChar));
  end;
  ChgClass.SyncClassPowers(Types.PCharRecord(GameVars.curChar));
end;

{ The Levels screen: each class's level, the experience and hit points; row sel's class in inverse video, black on
  light magenta. }
procedure DrawLevels(sel: Byte);
var
  held: THeld;
  count: Byte;
  i: Byte;
begin
  HeldClasses(held, count);
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  CharDisp.DisplayCreatureName(Types.PCharRecord(GameVars.curChar), NAME_COL, 2, False);
  for i := 0 to count - 1 do begin
    if i = sel then
      TextRend.DisplayStringOn(NAME_COL, LEVEL_ROW + i, Black, LightMagenta, GameDefs.classNames[held[i]])
    else
      TextRend.DisplayString(NAME_COL, LEVEL_ROW + i, LightGreen, GameDefs.classNames[held[i]]);
    TextRend.DisplayString(VALUE_COL, LEVEL_ROW + i, White,
                           'level ' + StrUtil.NumStr(GameVars.curChar^.classLevels[held[i]]) + ' ');
  end;
  TextRend.DisplayString(NAME_COL, LEVEL_ROW + count + 1, LightGreen, 'Experience');
  TextRend.DisplayString(VALUE_COL, LEVEL_ROW + count + 1, White, StrUtil.NumStr(GameVars.curChar^.experience) + '   ');
  TextRend.DisplayString(NAME_COL, LEVEL_ROW + count + 2, LightGreen, 'Hit points');
  TextRend.DisplayString(VALUE_COL, LEVEL_ROW + count + 2, White, StrUtil.NumStr(GameVars.curChar^.hpCur) + '/' +
                         StrUtil.NumStr(GameVars.curChar^.hpMax) + '   ');
end;

{ The Levels tool: Up and Down pick a class, Left and Right lower or raise its level (1 to C_LEVEL.LEVEL_LAST, past the
  racial limits), the experience following into the level's range; Experience types a new total. }
procedure LevelsTool;
var
  held: THeld;
  count: Byte;
  sel: Byte;
  key: Char;
  ext: Boolean;
  cls: ShortInt;
  s: Types.TStr40;
  xp: LongInt;
  code: Integer;
begin
  HeldClasses(held, count);
  if count = 0 then Exit;
  sel := 0;
  repeat
    DrawLevels(sel);
    MenuCore.arrowsToCaller := True;
    key := MenuCore.MenuHorizontal('Levels: ', 'Experience Done', LightMagenta, LightGreen, White, True, False, ext);
    cls := held[sel];
    if ext then
      with GameVars.curChar^ do
        case key of
          C_KEYS.DOWN: sel := (sel + 1) mod count;
          C_KEYS.UP: sel := (sel + count - 1) mod count;
          C_KEYS.LEFT:
            if classLevels[cls] > 1 then begin
              LowerLevel(cls, ClassCal.HpClassCount(Types.PCharRecord(GameVars.curChar)));
              { past the level's range, the experience comes down to one short of the next level; a next level
                the table does not reach (-1) leaves it, as one short of that is negative }
              xp := ClassCal.LevelXp(cls, classLevels[cls] + 1);
              if (xp > 0) and (experience >= xp) then
                experience := xp - 1;
            end;
          C_KEYS.RIGHT:
            if classLevels[cls] < C_LEVEL.LEVEL_LAST then begin
              CharGen.GainLevels(GameDefs.classBits[cls], False);
              if experience < ClassCal.LevelXp(cls, classLevels[cls]) then
                experience := ClassCal.LevelXp(cls, classLevels[cls]);
            end;
        end
    else if key = 'E' then begin
      s := TextRend.ReadString('Experience: ', LightGreen, 7);
      Val(s, xp, code);
      if (code = 0) and (xp >= 0) then
        GameVars.curChar^.experience := xp;
    end;
  until (not ext) and (key in ['D', C_KEYS.NONE]);
end;

{ The Health tool, on the character sheet: Heal restores every hit point and wakes the unconscious and dying; Status
  steps through okay, unconscious, dying, dead, stoned and gone, an okay character keeping at least 1 hit point and the
  rest none. Either way the character is in action (enabled) only when okay or animated, as the temple and the healing
  spells and CharHlp's damage leave one (#694): the party list and combat go by enabled, not status. }
procedure HealthTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GameVars.curChar);
    key := MenuCore.MenuHorizontal('Health: ', 'Heal Status Exit', LightMagenta, LightGreen, White, False, False, ext);
    with GameVars.curChar^ do
      case key of
        'H': begin
               hpCur := hpMax;
               if status in [C_STATUS.UNCONSCIOUS, C_STATUS.DYING] then
                 status := C_STATUS.OKAY;
               enabled := Ord(status in [C_STATUS.OKAY, C_STATUS.ANIMATED]);
             end;
        'S': begin
               case status of
                 C_STATUS.OKAY: status := C_STATUS.UNCONSCIOUS;
                 C_STATUS.UNCONSCIOUS: status := C_STATUS.DYING;
                 C_STATUS.DYING: status := C_STATUS.DEAD_STATUS;
                 C_STATUS.DEAD_STATUS: status := C_STATUS.STONED;
                 C_STATUS.STONED: status := C_STATUS.GONE;
               else
                 status := C_STATUS.OKAY;
               end;
               if status = C_STATUS.OKAY then begin
                 if hpCur = 0 then
                   hpCur := 1;
               end else
                 hpCur := 0;
               enabled := Ord(status in [C_STATUS.OKAY, C_STATUS.ANIMATED]);
             end;
      end;
  until key in ['E', C_KEYS.NONE];
end;

{ Add a line to the Add list with its code, while there is room. }
procedure AddLine(var head, tail: Types.PItemRec; var codes: TCodes; var n: Byte; name: Types.TStr40; code: Word);
begin
  if n > MAX_LINES then Exit;
  MenuCore.AppendMenuLine(head, tail, name, code = 0);
  codes[n] := code;
  Inc(n);
end;

{ item's name as the inventory shows it, identified or not as its unidMask says, without the trailing space. }
function Named(item: Types.PItemRec): Types.TStr40;
begin
  CharHlp.ItemLabel(item, False);
  while (Length(item^.name) > 0) and (item^.name[Length(item^.name)] = ' ') do
    Dec(item^.name[0]);
  Named := item^.name;
end;

{ Make item the item of an Add list code: a weapon or armour (RandItem's, its plus then chosen), a magic item, or a
  scroll of rolled spells. }
procedure Make(code: Word; item: Types.PItemRec);
begin
  if code > TEMPLATE_CODE then begin
    RandItem.GenerateRandomItem(TEMPLATE_KINDS[code - TEMPLATE_CODE], item);
    RandItem.ApplyTemplate(item, code - TEMPLATE_CODE);
  end else
    RandItem.GenerateRandomItem(code, item);
end;

{ Choose a weapon's or armour's plus, 0 to PLUS_LAST from +1, with Left and Right, its name and value following; False
  when left with Exit. Bracers, named by their AC rather than their plus, choose AC 6, 4 or 2 the same way, from AC 6
  (#772). }
function ChoosePlus(item: Types.PItemRec): Boolean;
var
  pos: Byte;
  i: Byte;
  per: Word;
  key: Char;
  ext: Boolean;
  ac: Byte;

  procedure SetBracers;
  begin
    item^.plus := BRACERS_PLUS[ac];
    item^.nameIds[1] := BRACERS_NAME[ac];
    item^.value := Word(item^.plus) * BRACERS_GP;
  end;

begin
  ac := 1;
  if item^.itemType = C_ITEM.BRACERS then
    SetBracers;
  pos := 0;
  for i := 1 to 3 do
    if (item^.nameIds[i] > C_ITEM.NAME_PLUS_BASE) and (item^.nameIds[i] <= C_ITEM.NAME_PLUS_BASE + PLUS_LAST) then
      pos := i;
  per := 0;
  if item^.plus > 0 then
    per := item^.value div Word(item^.plus);
  { every choice starts at +1, whatever RandItem rolled }
  if pos <> 0 then begin
    item^.plus := 1;
    item^.nameIds[pos] := C_ITEM.NAME_PLUS_BASE + 1;
    item^.value := per;
  end;
  repeat
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    TextRend.DisplayString(NAME_COL, LEVEL_ROW, White, Named(item));
    if pos <> 0 then
      TextRend.DisplayString(NAME_COL, LEVEL_ROW + 2, LightGreen, 'Left and Right change its plus.')
    else if item^.itemType = C_ITEM.BRACERS then
      TextRend.DisplayString(NAME_COL, LEVEL_ROW + 2, LightGreen, 'Left and Right change its AC.');
    MenuCore.arrowsToCaller := True;
    key := MenuCore.MenuHorizontal('Add: ', 'Take Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext and (pos <> 0) then begin
      if (key = C_KEYS.LEFT) and (item^.plus > 0) then
        Dec(item^.plus);
      if (key = C_KEYS.RIGHT) and (item^.plus < PLUS_LAST) then
        Inc(item^.plus);
      if item^.plus = 0 then
        item^.nameIds[pos] := 0
      else
        item^.nameIds[pos] := C_ITEM.NAME_PLUS_BASE + item^.plus;
      item^.value := per * Word(item^.plus);
    end else if ext and (item^.itemType = C_ITEM.BRACERS) then begin
      if (key = C_KEYS.LEFT) and (ac > 1) then
        Dec(ac);
      if (key = C_KEYS.RIGHT) and (ac < BRACERS_LAST) then
        Inc(ac);
      SetBracers;
    end;
  until (not ext) and (key in ['T', 'E', C_KEYS.NONE]);
  ChoosePlus := key = 'T';
end;

{ The Add tool: a list of every weapon and armour RandItem makes, the magic items of its templates and the two scrolls;
  the one picked, identified, goes to curChar if it can carry it. }
procedure AddItem;
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  item: Types.PItemRec;
  codes: TCodes;
  n: Byte;
  k: Byte;
  line: Integer;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  code: Word;
  failed: Boolean;
begin
  GetMem(item, SizeOf(Types.TItemRec));
  head := nil;
  tail := nil;
  n := 0;
  AddLine(head, tail, codes, n, 'Weapons and armor', 0);
  for k := 1 to C_ITEM.RANDOM_ARMS_LAST do
    if k in C_ITEM.RANDOM_ARMS_KINDS then begin
      RandItem.GenerateRandomItem(k, item);
      if Named(item) <> '' then
        AddLine(head, tail, codes, n, Named(item), k);
    end;
  AddLine(head, tail, codes, n, 'Magic items', 0);
  for k := 1 to RandItem.TEMPLATE_LAST do
    if TEMPLATE_KINDS[k] <> 0 then begin
      Make(TEMPLATE_CODE + k, item);
      item^.unidMask := 0;
      AddLine(head, tail, codes, n, Named(item), TEMPLATE_CODE + k);
    end;
  for k := C_ITEM.MAGE_SCROLL to C_ITEM.CLERIC_SCROLL do begin
    RandItem.GenerateRandomItem(k, item);
    AddLine(head, tail, codes, n, Named(item), k);
  end;
  idx := 0;
  redraw := True;
  sel := nil;
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  key := MenuCore.MenuVertical('Add: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True, redraw,
                               idx, sel);
  code := 0;
  if (key <> C_KEYS.NONE) and (sel <> nil) then begin
    line := MenuCore.ListIndex(head, sel);
    if line >= 0 then
      code := codes[line];
  end;
  MenuCore.FreeStringList(head);
  if code <> 0 then begin
    Make(code, item);
    item^.unidMask := 0;
    if (code > TEMPLATE_CODE) or (code = C_ITEM.MAGE_SCROLL) or (code = C_ITEM.CLERIC_SCROLL) or ChoosePlus(item) then
    begin
      Shop.GiveItemCopyToCreature(item, failed);
      if failed then
        TextRend.PauseOnly;
    end;
  end;
  FreeMem(item, SizeOf(Types.TItemRec));
end;

{ The Money tool: a list of the seven coin types with curChar's count of each; the one picked takes a typed count. }
procedure MoneyTool;
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  m: ShortInt;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  s: Types.TStr40;
  count: LongInt;
  code: Integer;
begin
  idx := 0;
  repeat
    head := nil;
    tail := nil;
    for m := C_MONEY.COPPER to C_MONEY.JEWELRY do
      MenuCore.AppendMenuLine(head, tail, StrUtil.PadLeft(GameDefs.moneyNames[m], 8) + ' ' +
                              StrUtil.NumStr(GameVars.curChar^.coins[m]), False);
    redraw := True;
    sel := nil;
    key := MenuCore.MenuVertical('Money: ', 'Set', LightMagenta, LightGreen, White, 12, 7, 27, 13, head, True,
                                 redraw, idx, sel);
    m := -1;
    if (key <> C_KEYS.NONE) and (sel <> nil) and (MenuCore.ListIndex(head, sel) >= 0) then
      m := C_MONEY.COPPER + MenuCore.ListIndex(head, sel);
    MenuCore.FreeStringList(head);
    if m >= C_MONEY.COPPER then begin
      s := TextRend.ReadString(GameDefs.moneyNames[m] + ': ', LightGreen, 5);
      Val(s, count, code);
      if (code = 0) and (count >= 0) and (count <= 65535) then
        GameVars.curChar^.coins[m] := count;
      CharHlp.RecalcStats(Types.PCharRecord(GameVars.curChar));
    end;
  until m < C_MONEY.COPPER;
end;

{ The Gear tool, on the character sheet: Add an item, or set the Money. The Items menu drops what is not wanted. }
procedure GearTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GameVars.curChar);
    key := MenuCore.MenuHorizontal('Gear: ', 'Add Money Exit', LightMagenta, LightGreen, White, False, False, ext);
    case key of
      'A': AddItem;
      'M': MoneyTool;
    end;
  until key in ['E', C_KEYS.NONE];
end;

{ The spells of class cls (a spellTable castClass: 0 cleric, 1 magic-user) a character here can know, levels 1 to
  Types.CASTER_LEVEL_LAST, each marked * when curChar knows it; picking one learns or forgets it, until Exit. }
procedure SpellList(cls: Byte);
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  spells: array[1..C_SPELL.LAST] of Byte;
  n: Byte;
  m: Byte;
  k: Byte;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  mark: string[2];
begin
  idx := 0;
  repeat
    head := nil;
    tail := nil;
    n := 0;
    for m := 1 to C_SPELL.LAST do
      with GameDefs.spellTable[m] do
        if CharHlp.IsSpell(m) and (castClass = cls) and (levelSp >= 1) and (levelSp <= Types.CASTER_LEVEL_LAST)
        then begin
          mark := '  ';
          if CharHlp.KnowsSpell(GameVars.curChar, m) then
            mark := '* ';
          MenuCore.AppendMenuLine(head, tail, mark + StrUtil.NumStr(levelSp) + ' ' + GameDefs.spellNames[m], False);
          Inc(n);
          spells[n] := m;
        end;
    redraw := True;
    sel := nil;
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    key := MenuCore.MenuVertical('Known: ', 'Toggle', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True,
                                 redraw, idx, sel);
    k := 0;
    if (key <> C_KEYS.NONE) and (sel <> nil) then
      k := MenuCore.ListIndex(head, sel) + 1;
    MenuCore.FreeStringList(head);
    if k <> 0 then
      CharHlp.SetSpellKnown(GameVars.curChar, spells[k], not CharHlp.KnowsSpell(GameVars.curChar, spells[k]));
  until k = 0;
end;

{ The Magic tool: the magic-user's or the cleric's spells known. }
procedure MagicTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GameVars.curChar);
    key := MenuCore.MenuHorizontal('Spells known: ', 'Mage Cleric Exit', LightMagenta, LightGreen, White, False,
                                   False, ext);
    case key of
      'M': SpellList(1);
      'C': SpellList(0);
    end;
  until key in ['E', C_KEYS.NONE];
end;

procedure EditMenu;
var
  key: Char;
  ext: Boolean;
begin
  if GameVars.curChar = nil then Exit;
  repeat
    ViewChar.DisplayChar(GameVars.curChar);
    key := MenuCore.MenuHorizontal('', 'Abilities Levels Gear Magic Health Exit', LightMagenta, LightGreen, White,
                                   True, False, ext);
    if ext then begin
      if key in [C_KEYS.HOME, C_KEYS.END_KEY, C_KEYS.UP, C_KEYS.DOWN] then
        Party.SelectPrevNextChar(key);
    end else
      case key of
        'A': CharGen.ModifyCharacter(True);
        'L': LevelsTool;
        'G': GearTool;
        'M': MagicTool;
        'H': HealthTool;
      end;
  until (not ext) and (key in ['E', C_KEYS.NONE]);
end;

end.
