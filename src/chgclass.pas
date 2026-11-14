{ Implements dual-classing at the training hall (#838, #879). An eligible human
  leaves the current class and begins another at level 1, following the
  first-edition rules used by Curse of the Azure Bonds. ClassCal applies the
  transition rules, while CharHlp determines when the former class's abilities
  become available again. }
{$O+,F+}
{$I COMPILER.INC}
unit ChgClass;

interface

uses Types;

const
  { what a change of class costs, in gold pieces, and only at a hall that trains the new class (#838) }
  CHANGE_FEE = 2500;

{ The classes creature has left and cannot use yet, one C_LEVEL bit each (CharHlp.ClassResting): taken before a level
  is gained, drained or restored, and given to AnnounceWoken after. }
function RestingMask(creature: Types.PCharRecord): Byte;

{ Bring the powers that go with a class into line with the classes creature can use: a paladin's own Protection from
  Evil (C_EFFECT.PROT_EVIL_10FT, permanent at strength 255, as creation gives it) is there while its paladin levels
  are usable and gone while they rest, and a readied item none of its usable classes may use (itemLimits) is put
  away unless it is cursed. Then RecalcStats. Only a dual-classed human is touched. }
procedure SyncClassPowers(creature: Types.PCharRecord);

{ For each class of wasResting (RestingMask before) creature can use again, say so in the message window ('Alias can
  again use the skills of a Fighter.') and, for a level 1 cleric or magic-user, give its first-level slot
  (ClassCal.StartCasterClass), which RecalcBaseSkills leaves to creation; then SyncClassPowers. }
procedure AnnounceWoken(creature: Types.PCharRecord; wasResting: Byte);

{ Why creature may not open the Dual Class screen, as line 25 of the party menu says it (#879), or '' when it may:
  atHall is a training hall here or free training on. In order: no hall ('Dual classing requires a training hall.'),
  not human ('Only humans can dual class.'), changed class already ('Alias already has two classes.'), not okay
  ('Alias isn't able to do that.', free training or not) and drained of a level ('Alias needs restoration first.'),
  as a class left would need restoring after the change. A nil creature at a hall gets ''. }
function Refusal(creature: Types.PCharRecord; atHall: Boolean): Types.TStr40;

{ The Dual Class screen for curChar (mocks/change-class.txt): the level and class it follows now, then the classes a
  human can take, each with its prime requisites one to a line, what each needs and what the character has, white for
  one it qualifies for here and dark gray for one it does not; the explanation of the rule; and a status line for the
  highlighted class. Up and Down move the highlight (the class in yellow, its name in inverse video) through the
  classes. A class qualifies when ClassCal.CanTakeClass allows it, this hall trains it (CharHlp.HallMask,
  GameDefs.classBits) and the character has the CHANGE_FEE; freeTraining (CharGen's STING switch) waives the hall and
  the fee. The status line says which of these fails, or what choosing it costs. Choose, offered on a qualifying class,
  asks Yes or No, takes the fee and changes the class (ClassCal.ChangeClass, SyncClassPowers). A character whose current
  class's prime requisites are too low has no highlight and the menu is Exit alone. The party menu has turned away a
  character Refusal refuses. }
procedure ChangeClassMenu(freeTraining: Boolean);

implementation

uses Crt, C_STAT, C_EFFECT, C_KEYS, C_LEVEL, C_MSG, C_RACE, C_STATUS, GameDefs, GameVars, Border,
  CharDisp, CharHlp, ClassCal, FxEngine, MenuCore, Money, MoneyCal, StrUtil, TextRend;

const
  { the screen's columns: the labels and class names, what is needed and what the character has }
  LABEL_COL = 2;
  NEEDS_COL = 14;
  HAS_COL = 29;
  { its rows: the title, the class followed now, the heading of the classes and the first and last line of them, the
    explanation's first and last, and the status message's }
  TITLE_ROW = 1;
  NOW_ROW = 3;
  HEAD_ROW = 5;
  FIRST_CLASS_ROW = 6;
  LAST_CLASS_ROW = 13;
  TEXT_TOP_ROW = 15;
  TEXT_BOTTOM_ROW = 19;
  STATUS_TOP_ROW = 21;
  STATUS_BOTTOM_ROW = 22;
  { the most classes listed: a human's six less the one it follows }
  MAX_LISTED = 5;
  { what stands in the way of a class (Obstacle): nothing, the rules, a hall that does not train it, the fee }
  NO_OBSTACLE = 0;
  RULES_OBSTACLE = 1;
  HALL_OBSTACLE = 2;
  FEE_OBSTACLE = 3;

function RestingMask(creature: Types.PCharRecord): Byte;
var
  mask: Byte;
  cls: ShortInt;
begin
  mask := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if CharHlp.ClassResting(creature, cls) then
      mask := mask or (1 shl cls);
  RestingMask := mask;
end;

{ creature's own Protection from Evil, creation's: permanent, at strength 255; nil when it has none. }
function OwnWard(creature: Types.PCharRecord): Types.PEffectRec;
var
  p: Types.PEffectRec;
begin
  OwnWard := nil;
  p := creature^.effectsAddr;
  while p <> nil do begin
    if (p^.id = C_EFFECT.PROT_EVIL_10FT) and (p^.duration = 0) and (p^.strength = 255) then
      OwnWard := p;
    p := p^.next;
  end;
end;

procedure SyncClassPowers(creature: Types.PCharRecord);
var
  ward: Types.PEffectRec;
  item: Types.PItemRec;
begin
  if not CharHlp.IsDualClass(creature) then Exit;
  ward := ChgClass.OwnWard(creature);
  if CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT) > 0 then begin
    if ward = nil then
      FxEngine.AddEffect(creature, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  end else if ward <> nil then
    FxEngine.RemoveEffect(creature, C_EFFECT.PROT_EVIL_10FT, ward);
  item := creature^.itemsAddr;
  while item <> nil do begin
    if (item^.equipped <> 0) and (item^.cursed = 0) and
        (CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits = 0) then
      FxEngine.UnreadyItem(creature, item);
    item := item^.next;
  end;
  CharHlp.RecalcStats(creature);
end;

procedure AnnounceWoken(creature: Types.PCharRecord; wasResting: Byte);
var
  cls: ShortInt;
begin
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if (wasResting and (1 shl cls) <> 0) and not CharHlp.ClassResting(creature, cls) then begin
      if creature^.classLevels[cls] = 1 then
        ClassCal.StartCasterClass(creature, cls);
      CharDisp.MessageText(creature^.name + ' can again use the skills of a ' + GameDefs.classNames[cls] + '.',
                           LightGreen, True);
      CharDisp.MessageWait;
    end;
  ChgClass.SyncClassPowers(creature);
end;

function Refusal(creature: Types.PCharRecord; atHall: Boolean): Types.TStr40;
begin
  Refusal := '';
  if not atHall then
    Refusal := 'Dual classing requires a training hall.'
  else if creature = nil then
    Exit
  else if creature^.race <> C_RACE.HUMAN then
    Refusal := 'Only humans can dual class.'
  else if CharHlp.IsDualClass(creature) then
    Refusal := creature^.name + ' already has two classes.'
  else if creature^.status <> C_STATUS.OKAY then
    Refusal := creature^.name + ' isn''t able to do that.'
  else if creature^.drainedLevels > 0 then
    Refusal := creature^.name + ' needs restoration first.';
end;

{ s in color in the status rows, word-wrapped between the frame's sides. The rows are cleared and the text starts at
  their corner, not where an earlier message left the cursor (#888). }
procedure ShowStatus(color: Byte; s: string);
var
  delayFlag: Byte;
begin
  delayFlag := GameVars.msgDelayFlag;
  GameVars.msgDelayFlag := 0;
  TextRend.DisplayMessageWindow(LABEL_COL, STATUS_TOP_ROW, C_MSG.TEXT_RIGHT - 1, STATUS_BOTTOM_ROW, color, True, s);
  GameVars.msgDelayFlag := delayFlag;
end;

{ The lines class cls takes on the screen: one for each of its prime requisites (ClassCal.primeRequisites). }
function PrimeCount(cls: ShortInt): Byte;
var
  ab: ShortInt;
  n: Byte;
begin
  n := 0;
  for ab := C_STAT.STRENGTH to C_STAT.CHARISMA do
    if ClassCal.primeRequisites[cls] and (1 shl ab) <> 0 then
      Inc(n);
  PrimeCount := n;
end;

{ Class cls's lines from row: its name on the first, and on each a prime requisite with the score it needs and the
  creature's own (Strength CharHlp.PermanentStrength), all in color, but for the name in inverse video (black on
  color) when highlighted. }
procedure DrawClassLines(creature: Types.PCharRecord; cls: ShortInt; row, color: Byte; highlighted: Boolean);
var
  ab: ShortInt;
  score: Byte;
begin
  if highlighted then
    TextRend.DisplayStringOn(LABEL_COL, row, Black, color, GameDefs.classNames[cls])
  else
    TextRend.DisplayString(LABEL_COL, row, color, GameDefs.classNames[cls]);
  for ab := C_STAT.STRENGTH to C_STAT.CHARISMA do
    if ClassCal.primeRequisites[cls] and (1 shl ab) <> 0 then begin
      if ab = C_STAT.STRENGTH then
        score := CharHlp.PermanentStrength(creature)
      else
        score := creature^.stats[ab];
      TextRend.DisplayString(NEEDS_COL, row, color,
                             GameDefs.abilityNames[ab] + ' ' + StrUtil.NumStr(ClassCal.TAKE_CLASS_SCORE));
      TextRend.DisplayString(HAS_COL, row, color, StrUtil.NumStr(score));
      Inc(row);
    end;
end;

{ What stands in the way of creature becoming a cls here, the first of: the rules (ClassCal.CanTakeClass), and unless
  free training is on, a hall that does not train it and the fee; NO_OBSTACLE when nothing does. }
function Obstacle(creature: Types.PCharRecord; cls: ShortInt; freeTraining: Boolean): Byte;
begin
  if not ClassCal.CanTakeClass(creature, cls) then
    Obstacle := RULES_OBSTACLE
  else if freeTraining then
    Obstacle := NO_OBSTACLE
  else if GameDefs.classBits[cls] and CharHlp.HallMask = 0 then
    Obstacle := HALL_OBSTACLE
  else if MoneyCal.CreatureGold(creature) < CHANGE_FEE then
    Obstacle := FEE_OBSTACLE
  else
    Obstacle := NO_OBSTACLE;
end;

{ True when creature may become a cls here: nothing stands in the way (Obstacle). }
function Qualifies(creature: Types.PCharRecord; cls: ShortInt; freeTraining: Boolean): Boolean;
begin
  Qualifies := ChgClass.Obstacle(creature, cls, freeTraining) = NO_OBSTACLE;
end;

{ The status line for class cls: why creature cannot become one here (Obstacle), in yellow, or what it costs, in
  white. }
procedure ShowClassStatus(creature: Types.PCharRecord; cls: ShortInt; freeTraining: Boolean);
var
  name: Types.TStr40;
begin
  name := GameDefs.classNames[cls];
  case ChgClass.Obstacle(creature, cls, freeTraining) of
    RULES_OBSTACLE: ChgClass.ShowStatus(Yellow, creature^.name + ' does not meet ' + name + ' requirements.');
    HALL_OBSTACLE: ChgClass.ShowStatus(Yellow, 'This hall cannot train a ' + name + '.');
    FEE_OBSTACLE: ChgClass.ShowStatus(Yellow, creature^.name + ' can''t afford to change class (' +
                                      StrUtil.Grouped(CHANGE_FEE) + ' gp).');
  else
    if freeTraining then
      ChgClass.ShowStatus(White, creature^.name + ' can become a ' + name + '.')
    else
      ChgClass.ShowStatus(White, creature^.name + ' can become a ' + name + ' for ' + StrUtil.Grouped(CHANGE_FEE) +
                          ' gp.');
  end;
end;

procedure ChangeClassMenu(freeTraining: Boolean);
var
  creature: Types.PCharRecord;
  listed: array[1..MAX_LISTED] of ShortInt;
  firstRow: array[1..MAX_LISTED] of Byte;
  count: Byte;
  sel: Byte;
  i: Byte;
  row: Byte;
  cls: ShortInt;
  old: ShortInt;
  ch: Char;
  ext: Boolean;
  done: Boolean;

  { Draw listed class n yellow, its name in inverse video, when highlighted, else white when it qualifies and dark
    gray when not. }
  procedure DrawListed(n: Byte; highlighted: Boolean);
  var
    color: Byte;
  begin
    if highlighted then
      color := Yellow
    else if ChgClass.Qualifies(creature, listed[n], freeTraining) then
      color := White
    else
      color := DarkGray;
    ChgClass.DrawClassLines(creature, listed[n], firstRow[n], color, highlighted);
  end;

  procedure MoveTo(n: Byte);
  begin
    if sel > 0 then
      DrawListed(sel, False);
    sel := n;
    DrawListed(sel, True);
    ChgClass.ShowClassStatus(creature, listed[sel], freeTraining);
  end;

begin
  creature := GameVars.curChar;
  old := creature^.charClass;
  Border.ClearToFrame;
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT + 1, C_MSG.TEXT_RIGHT - 1, TITLE_ROW, LightCyan,
                           'Dual Class ' + creature^.name);
  TextRend.DisplayString(LABEL_COL, NOW_ROW, LightGreen, 'Now');
  TextRend.DisplayString(NEEDS_COL, NOW_ROW, White,
                         'Level ' + StrUtil.NumStr(creature^.classLevels[old]) + ' ' + GameDefs.classNames[old]);
  TextRend.DisplayString(LABEL_COL, HEAD_ROW, LightGreen, 'New Class');
  TextRend.DisplayString(NEEDS_COL, HEAD_ROW, LightGreen, 'Needs');
  TextRend.DisplayString(HAS_COL, HEAD_ROW, LightGreen, 'Has');
  { from the explanation's corner: the cursor an earlier message left inside these rows ran it past them (#888) }
  TextRend.DisplayMessageWindow(LABEL_COL, TEXT_TOP_ROW, C_MSG.TEXT_RIGHT - 1, TEXT_BOTTOM_ROW, LightGreen, True,
                                'To dual class a character must have ' + StrUtil.NumStr(ClassCal.LEAVE_CLASS_SCORE) +
                                ' or more in the prime requisites of their current class, and ' +
                                StrUtil.NumStr(ClassCal.TAKE_CLASS_SCORE) +
                                ' or more in their new class'' prime requisites.');
  { the classes a human takes, but the one it follows, as many as the rows hold }
  count := 0;
  row := FIRST_CLASS_ROW;
  for i := 1 to ClassCal.classesByRace[C_RACE.HUMAN].count do begin
    cls := ClassCal.classesByRace[C_RACE.HUMAN].classes[i];
    if (cls <> old) and (count < MAX_LISTED) and (row + ChgClass.PrimeCount(cls) - 1 <= LAST_CLASS_ROW) then begin
      Inc(count);
      listed[count] := cls;
      firstRow[count] := row;
      Inc(row, ChgClass.PrimeCount(cls));
    end;
  end;
  sel := 0;
  for i := 1 to count do
    DrawListed(i, False);
  if not ClassCal.CanChangeClass(creature) then
    ChgClass.ShowStatus(Yellow, creature^.name + ' does not meet current class requirements.')
  else if count > 0 then begin
    { the highlight starts on the first class it qualifies for, or else on the first class }
    i := 1;
    while (i < count) and not ChgClass.Qualifies(creature, listed[i], freeTraining) do
      Inc(i);
    if not ChgClass.Qualifies(creature, listed[i], freeTraining) then
      i := 1;
    MoveTo(i);
  end;
  done := False;
  repeat
    MenuCore.arrowsToCaller := True;
    if (sel > 0) and ChgClass.Qualifies(creature, listed[sel], freeTraining) then begin
      MenuCore.enterToCaller := True;
      ch := MenuCore.MenuHorizontal('Change class: ', 'Choose Exit', LightMagenta, LightGreen, White, True, False,
                                    ext);
    end else
      ch := MenuCore.MenuHorizontal('Change class: ', 'Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if sel > 0 then
        case ch of
          C_KEYS.UP: MoveTo((sel + count - 2) mod count + 1);
          C_KEYS.DOWN: MoveTo(sel mod count + 1);
        end;
    end else if (sel > 0) and ((ch = 'C') or (ch = C_KEYS.ENTER)) and
        ChgClass.Qualifies(creature, listed[sel], freeTraining) then begin
      cls := listed[sel];
      if MenuCore.YesNoMenu('Change ' + creature^.name + ' to a ' + GameDefs.classNames[cls] + '? ', LightMagenta,
                            LightGreen, White) = 'Y' then begin
        if not freeTraining then
          Money.PayFromCreature(creature, CHANGE_FEE);
        ClassCal.ChangeClass(creature, cls);
        ChgClass.SyncClassPowers(creature);
        CharDisp.PrintBottomLine(creature^.name + ' is now a ' + GameDefs.classNames[cls] + '.');
        done := True;
      end;
    end else if (ch = 'E') or (ch = C_KEYS.NONE) then
      done := True;
  until done;
end;

end.
