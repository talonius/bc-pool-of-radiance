{ Character sheets, inventory actions, coin menus and spell-menu access. }
{$O+,F+}
{$I COMPILER.INC}
unit ViewChar;

interface

uses Types;

procedure DisplayChar(creature: Types.PCharRecord);

{ The secondary statuses the View page shows after creature's status, in red (#1161): ', Poisoned' while it has the
  POISONED effect (a character killed by poison keeps it: 'Dead, Poisoned'), and ', Drained' while it has drained
  levels; '' with neither. How many levels each class lost is shown on the Level line (Magic.DrainedByClass). }
function SecondaryStatus(creature: Types.PCharRecord): Types.TStr40;

procedure PrintCombatStats;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

procedure PrintMoney;

procedure ViewCharMenu(var done: Boolean);

procedure UseItemMenu(var done: Boolean);

{ Alt-1 to Alt-8 outside combat (#1175, AltItems): make creature the current character and open its items, as View's
  Items does, or say it has none. The caller redraws its screen afterwards. }
procedure MemberItems(creature: Types.PCharRecord);

{ Alt-1 to Alt-8 on a menu outside combat (#1195): when c is Alt-n (Party.AltMember) and the party has a member n, open
  that member's items (MemberItems) and return True, for the caller to redraw its screen. Otherwise, in combat among
  them, do nothing and return False. A list menu reached from those items switches to member n's in place instead
  (UseItemMenu). }
function AltItems(c: Char): Boolean;

{ Paladin p lays on hands on tgt: two hit points per paladin level, counted as healing given, and RECENT_HEAL on p so
  it waits a day for the next (CharHlp.PaladinCanHeal). True when tgt was healed. View's Heal and Fix use it. }
function PaladinHeal(p, tgt: Types.PCharRecord): Boolean;

{ Paladin p uses one of its weekly cures on tgt: tgt's diseases go (FxEngine.RemoveDiseases), and p's RECENT_CURE,
  lasting a week, counts the cure (CharHlp.PaladinCanCure). View's Cure and Fix use it. }
procedure PaladinCure(p, tgt: Types.PCharRecord);

{ True when creature cannot take item: it carries C_ITEM.CARRY_MAX items already, unless Auto Join is on and item
  joins one of its stacks whole (CharHlp.JoinsWhole, #1088), or item's weight would overload it. }
function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ The inventory's action line for creature's item: Ready, then Use, Trade, Drop or Deposit, Halve, Join and Sell as
  they apply. The I key is Id at a shop's or temple's counter, offered on every item as SSI offered it, so that the
  line does not tell which items are magic (#1115); elsewhere it is Info, on an item with a spell page. Halve is
  dropped when the complete line would exceed 40 columns. ' 1 2', the weapon-set keys (#1209), end the line where
  sets are tagged (TagsSets) on an item that takes one, when they fit. }
function ItemMenuLine(creature: Types.PCharRecord; item: Types.PItemRec): Types.TStr40;

{ True where the Items screen tags weapon sets (#1209): everywhere but the vault and a shop's or temple's counter. }
function TagsSets: Boolean;

{ Tag item for weapon set n (#1209), or clear the tag when it already has n; "Weapons and shields only" for an item
  that takes none (CharHlp.SetTaggable). }
procedure TagSet(item: Types.PItemRec; n: Byte);

implementation

uses Crt, GameDefs, GameVars, DaxIo, TextRend, Border, CharHlp, MenuCore, Portrait, CbtMap, Money, Magic, FxEngine,
  C_EFFECT, C_EQUIP, C_KEYS, C_LEVEL, C_STATUS, C_IFC, C_STAT, C_MONEY, C_SAVE, Vault, Stats, StrUtil, CharDisp,
  MoneyCal, C_MSG, ClassCal, C_ITEM, C_SPELL, SpellInf, Party, KeyHelp;

const
  { the character sheet's right column: Exp on the Level line, and Encumbrance under it (PrintCombatStats) }
  RIGHT_COL = 22;

var
  { the last character traded to, offered first by the next trade; ViewCharMenu starts it at curChar }
  tradeTarget: Types.PCharRecord;

procedure ItemTradeMenu(item: Types.PItemRec); forward;

procedure HalveItem(item: Types.PItemRec); forward;

function CanJoin(item: Types.PItemRec): Boolean; forward;

procedure SellItem(item: Types.PItemRec); forward;

procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

{ What a shopkeeper or an item prompt says, in yellow on the bottom two rows (1, 21 to 38, 22). }
procedure SayBelow(clearFirst: Boolean; s: String);
begin
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, clearFirst, s);
end;

{ The Level line's mark after a class's level for the n levels drained from it (#1161): ' (-n)', '' when none. }
function DrainMark(n: Byte): Types.TStr40;
begin
  if n = 0 then
    DrainMark := ''
  else
    DrainMark := ' (-' + StrUtil.NumStr(n) + ')';
end;

{ Draw the level of class cls at levelCol of levelRow in color, with its drain mark in red after it (DrainMark),
  moving levelCol past both. prefix ('/' or ' (') goes before the level and suffix (')' or '') after it. }
procedure DrawLevel(creature: Types.PCharRecord; cls: ShortInt; drained: Byte; levelRow, color: Byte;
  prefix, suffix: Types.TStr40; var levelCol: Byte);
var
  s: Types.TStr40;
begin
  s := prefix + StrUtil.NumStr(creature^.classLevels[cls]);
  TextRend.DisplayString(levelCol, levelRow, color, s);
  Inc(levelCol, Length(s));
  s := ViewChar.DrainMark(drained);
  if s <> '' then begin
    TextRend.DisplayString(levelCol, levelRow, LightRed, s);
    Inc(levelCol, Length(s));
  end;
  if suffix <> '' then begin
    TextRend.DisplayString(levelCol, levelRow, color, suffix);
    Inc(levelCol, Length(suffix));
  end;
end;

{ Draws a dual-classed human's current and former classes (#838). A former class
  is gray and parenthesized while inactive, then white once its abilities return.
  Each level has its drain mark (drained, DrainMark); levelCol ends past the levels. }
procedure DrawDualClass(creature: Types.PCharRecord; classRow, levelRow: Byte; var drained: Types.TClassCounts;
  var levelCol: Byte);
var
  col: Byte;
  cls: ShortInt;
  s: Types.TStr40;
begin
  s := GameDefs.classNames[creature^.charClass];
  TextRend.DisplayString(1, classRow, White, s);
  col := 1 + Length(s);
  levelCol := 7;
  ViewChar.DrawLevel(creature, creature^.charClass, drained[creature^.charClass], levelRow, White, '', '', levelCol);
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if (creature^.portExt.formerClasses and (1 shl cls) <> 0) and (creature^.classLevels[cls] > 0) then begin
      if CharHlp.ClassResting(creature, cls) then begin
        ViewChar.DrawLevel(creature, cls, drained[cls], levelRow, DarkGray, ' (', ')', levelCol);
        s := ' (' + GameDefs.classNames[cls] + ')';
        TextRend.DisplayString(col, classRow, DarkGray, s);
      end else begin
        ViewChar.DrawLevel(creature, cls, drained[cls], levelRow, White, '/', '', levelCol);
        s := ' (' + GameDefs.classNames[cls] + ')';
        TextRend.DisplayString(col, classRow, White, s);
      end;
      Inc(col, Length(s));
    end;
end;

function SecondaryStatus(creature: Types.PCharRecord): Types.TStr40;
var
  s: Types.TStr40;
  effect: Types.PEffectRec;
begin
  s := '';
  if CharHlp.HasEffect(creature, C_EFFECT.POISONED, effect) then
    s := s + ', Poisoned';
  if creature^.drainedLevels > 0 then
    s := s + ', Drained';
  SecondaryStatus := s;
end;

{ Draw the secondary statuses s (SecondaryStatus) from col of row: each ', ' that joins one on in green, as the
  status before it is, and each status in red. }
procedure DrawSecondaryStatus(col, row: Byte; s: Types.TStr40);
var
  i: Byte;
  start: Byte;
begin
  i := 1;
  while i <= Length(s) do begin
    if (s[i] = ',') and (i < Length(s)) and (s[i + 1] = ' ') then begin
      TextRend.DisplayString(col + i - 1, row, LightGreen, ', ');
      Inc(i, 2);
    end else begin
      start := i;
      while (i <= Length(s)) and (s[i] <> ',') do
        Inc(i);
      TextRend.DisplayString(col + start - 1, row, LightRed, Copy(s, start, i - start));
    end;
  end;
end;

{ Draw creature's character sheet; the portrait is curChar's (Portrait.DisplayCharPortrait), which every caller shows.
  A dual-classed human's class and level lines show the classes it has left too (DrawDualClass). A class that lost
  levels to energy drains has their count after its level, in red (DrainMark, #1161); a mark that would run into Exp
  moves it right. The status has its secondary statuses after it, in red joined in green (DrawSecondaryStatus). }
procedure DisplayChar(creature: Types.PCharRecord);
var
  row: Byte;
  col: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
  drained: Types.TClassCounts;
begin
  Border.ClearToFrame;
  CharDisp.DisplayCreatureName(creature, 1, 1, False);
  { C_NPC.FLAG set: not a party member }
  if CharHlp.IsNpc(creature) then
    TextRend.DisplayString(Length(creature^.name) + 3, 1, LightGreen, '(NPC)');
  col := 1;
  s := GameDefs.genderNames[creature^.genderIdx];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  s := GameDefs.raceNames[creature^.race];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  TextRend.DisplayString(col, 3, White, 'Age ' + StrUtil.NumStr(creature^.age));
  s := GameDefs.alignNames[creature^.alignmentIdx];
  TextRend.DisplayString(1, 4, White, s);
  if not CharHlp.IsDualClass(creature) then
    TextRend.DisplayString(1, 5, White, GameDefs.classNames[creature^.charClass]);
  { the six ability scores }
  for i := C_STAT.STRENGTH to C_STAT.CHARISMA do begin
    TextRend.DisplayString(1, i + 7, LightGreen, GameDefs.abilityNames[i] + ' ');
    ViewChar.PrintStat(i, False);
  end;
  ViewChar.PrintMoney;
  TextRend.DisplayString(1, 15, White, 'Level');
  Magic.DrainedByClass(creature, drained);
  if CharHlp.IsDualClass(creature) then
    ViewChar.DrawDualClass(creature, 5, 15, drained, col)
  else begin
    multi := False;
    col := 7;
    { one entry per class the character has levels in, joined with '/' }
    for j := C_LEVEL.CLERIC to C_LEVEL.MONK do
      if creature^.classLevels[j] > 0 then begin
        if multi then
          ViewChar.DrawLevel(creature, j, drained[j], 15, White, '/', '', col)
        else
          ViewChar.DrawLevel(creature, j, drained[j], 15, White, '', '', col);
        multi := True;
      end;
  end;
  { Exp lined up with Encumbrance, or a column past drain marks that reach it: a triple class drained in each
    still fits }
  if col < RIGHT_COL - 1 then
    col := RIGHT_COL - 1;
  TextRend.DisplayString(col + 1, 15, White, 'Exp ' + StrUtil.NumStr(creature^.experience));
  ViewChar.PrintCombatStats;
  row := 20;
  if creature^.equipped[C_EQUIP.WEAPON] <> nil then begin
    TextRend.DisplayString(1, row, White, 'Weapon');
    CharDisp.PrintItemLabel(creature^.equipped[C_EQUIP.WEAPON], 8, row);
  end;
  Inc(row);
  if creature^.equipped[C_EQUIP.ARMOR] <> nil then begin
    { 'Armor' starts one column right of 'Weapon' so the two labels end in the same column }
    TextRend.DisplayString(2, row, White, 'Armor');
    CharDisp.PrintItemLabel(creature^.equipped[C_EQUIP.ARMOR], 8, row);
  end;
  Inc(row);
  TextRend.DisplayString(1, row, White, 'Status');
  s := GameDefs.statusNames[creature^.status];
  TextRend.DisplayString(8, row, LightGreen, s);
  { the longest, 'Unconscious, Poisoned, Drained', ends in column 37 }
  ViewChar.DrawSecondaryStatus(8 + Length(s), row, ViewChar.SecondaryStatus(creature));
  if (GameVars.portraitsAll <> 0) and (GameVars.portraitsOn <> 0) and Portrait.PlayerPortraitsHere then
    Portrait.DisplayCharPortrait;
end;

{ Print nonzero coin holdings, highest type first: names right-aligned to end at column 19, amounts from column 21.
  Reads curChar. }
procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(12, 7, 26, 14);
  row := 7;
  for m := C_MONEY.JEWELRY downto C_MONEY.COPPER do
    if GameVars.curChar^.coins[m] > 0 then begin
      s := GameDefs.moneyNames[m];
      TextRend.DisplayString(20 - Length(s), row, LightGreen, s);
      TextRend.DisplayString(21, row, LightGreen, StrUtil.NumStr(GameVars.curChar^.coins[m]));
      Inc(row);
    end;
end;

function PaladinHeal(p, tgt: Types.PCharRecord): Boolean;
var
  hpBefore: Byte;
  healed: Boolean;
begin
  hpBefore := tgt^.hpCur;
  healed := FxEngine.RestoreHitPoints(tgt, CharHlp.GetClassLevel(p, C_LEVEL.PALADIN_BIT) * 2, False);
  if healed then
    Stats.Count(p, Stats.HEALED_GIVEN, tgt^.hpCur - hpBefore);
  FxEngine.AddEffect(p, C_EFFECT.RECENT_HEAL, 1440, 255, False);
  PaladinHeal := healed;
end;

procedure PaladinCure(p, tgt: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  if FxEngine.RemoveDiseases(tgt) then ;
  if CharHlp.HasEffect(p, C_EFFECT.RECENT_CURE, effect) then
    Inc(effect^.strength)
  else
    FxEngine.AddEffect(p, C_EFFECT.RECENT_CURE, 10080, 1, False);
end;

{ Lets the paladin heal a selected party member for two hit points per level (PaladinHeal). Cancelling spends
  nothing. }
procedure LayOnHands(p: Types.PCharRecord);
var
  tgt: Types.PCharRecord;
begin
  CharDisp.DisplayNoncombatInterface;
  tgt := GameVars.creatureList;
  CharDisp.SelectChar('Heal whom? ', True, tgt);
  if tgt = nil then
    Exit;
  if ViewChar.PaladinHeal(p, tgt) then
    CharDisp.PrintBottomLine(tgt^.name + ' feels better')
  else
    CharDisp.PrintBottomLine(tgt^.name + ' is unaffected');
end;

{ Uses one of the paladin's weekly cures on a selected party member (PaladinCure). Confirm before spending a use on
  someone without a disease. Cancelling spends nothing. }
procedure CureDisease(p: Types.PCharRecord);
var
  tgt: Types.PCharRecord;
  ch: Char;
begin
  CharDisp.DisplayNoncombatInterface;
  tgt := GameVars.creatureList;
  CharDisp.SelectChar('Cure whom? ', True, tgt);
  if tgt = nil then
    Exit;
  ch := 'Y';
  if not FxEngine.HasDisease(tgt) then begin
    CharDisp.PrintNameString(tgt, 'is not diseased', 0, False);
    ch := MenuCore.YesNoMenu('cure anyway: ', LightMagenta, LightGreen, White);
    CharDisp.ClearMessageWindow;
  end;
  if ch <> 'Y' then
    Exit;
  ViewChar.PaladinCure(p, tgt);
  CharDisp.PrintBottomLine(tgt^.name + ' is cured');
end;

type
  { the kinds a stats block holds, in the order the Kills page lists them }
  TKillOrder = array[1..Stats.KINDS] of Byte;

const
  { the Kill Count page: two columns of KILL_ROWS rows, an entry a column wide, a "(more)" row above and below }
  KILL_TOP = 6;
  KILL_ROWS = 15;
  KILL_COL_WIDTH = 18;
  KILLS_SHOWN = 2 * KILL_ROWS;
  { More Info's pages, in the order of its menu }
  PAGE_SAVES = 1;
  PAGE_STATS = 2;
  PAGE_KILLS = 3;
  PAGE_THIEF = 4;
  PAGE_CLERIC = 5;

{ Clear the screen, draw the border and centre creature's name in light cyan on row 2: the top of a More Info page. }
procedure MoreHeading(creature: Types.PCharRecord);
begin
  Border.ClearToFrame;
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT + 1, C_MSG.TEXT_RIGHT - 1, 2, LightCyan, creature^.name);
end;

{ A More Info page's top (MoreHeading) with title centred in white on row 4, under the name and a blank line. }
procedure MoreTitle(creature: Types.PCharRecord; title: Types.TStr40);
begin
  ViewChar.MoreHeading(creature);
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT + 1, C_MSG.TEXT_RIGHT - 1, 4, White, title);
end;

{ The Game Stats page: the creature's twelve counters in this game, from row 6, coin in gold, each name in light green
  and its count in white; b nil reads every counter as 0. }
procedure DrawGameStats(creature: Types.PCharRecord; b: Stats.PStatBlock);
var
  i: Byte;
  n: LongInt;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(creature, 'Game Stats');
  for i := 1 to Stats.STAT_COUNT do begin
    n := 0;
    if b <> nil then
      n := b^.counts[i];
    if i = Stats.COIN_LOOTED then
      n := n div GameDefs.coinValues[C_MONEY.GOLD];
    Str(n, s);
    TextRend.DisplayString(3, 5 + i, LightGreen, Stats.NAMES[i]);
    TextRend.DisplayString(36 - Length(s), 5 + i, White, s);
  end;
end;

{ The Kill Count page from entry top of order (b's kinds, sorted by name): left then right along each row, each count
  right-aligned to the widest in white and its name after it in light green, cut to fit the column, and "(more)" above
  or below when entries are hidden there. }
procedure DrawKills(creature: Types.PCharRecord; b: Stats.PStatBlock; var order: TKillOrder; kinds, top: Byte);
var
  i: Byte;
  k: Byte;
  width: Byte;
  col: Byte;
  row: Byte;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(creature, 'Kill Count');
  if kinds = 0 then begin
    TextRend.DisplayString(3, KILL_TOP, LightGreen, 'None');
    Exit;
  end;
  width := 1;
  for i := 1 to kinds do
    if Length(StrUtil.NumStr(b^.kills[i].count)) > width then
      width := Length(StrUtil.NumStr(b^.kills[i].count));
  if top > 1 then
    MenuCore.DrawMore(1, 38, KILL_TOP - 1);
  for k := 0 to KILLS_SHOWN - 1 do
    if top + k <= kinds then begin
      i := order[top + k];
      col := 2 + (k mod 2) * KILL_COL_WIDTH;
      row := KILL_TOP + k div 2;
      s := StrUtil.PadLeft(StrUtil.NumStr(b^.kills[i].count), width);
      TextRend.DisplayString(col, row, White, s);
      TextRend.DisplayString(col + width + 1, row, LightGreen, Copy(b^.kills[i].name, 1, KILL_COL_WIDTH - 2 - width));
    end;
  if top + KILLS_SHOWN <= kinds then
    MenuCore.DrawMore(1, 38, KILL_TOP + KILL_ROWS);
end;

{ creature's statistics block (#611, #672), made the first time, and the kinds it has killed in alphabetical order. }
procedure ReadStats(creature: Types.PCharRecord; var b: Stats.PStatBlock; var order: TKillOrder; var kinds: Byte);
var
  i: Byte;
  j: Byte;
  t: Byte;
begin
  { a creature outside the party has no block: its counters read 0 }
  b := Stats.BlockOf(creature);
  kinds := 0;
  if b <> nil then
    kinds := b^.kindCount;
  for i := 1 to kinds do
    order[i] := i;
  for i := 1 to kinds do
    for j := i + 1 to kinds do
      if b^.kills[order[j]].name < b^.kills[order[i]].name then begin
        t := order[i];
        order[i] := order[j];
        order[j] := t;
      end;
end;

{ Shows the five saving throws as the minimum d20 roll needed. Clamp results to
  2..20 because 1 always fails and 20 always succeeds. Situational racial
  bonuses apply during the roll and are not included here. }
procedure DrawSaves(p: Types.PCharRecord);
var
  i: ShortInt;
  need: Integer;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(p, 'Saving Throws');
  for i := C_SAVE.PARALYZE to C_SAVE.SPELL do begin
    case i of
      C_SAVE.PARALYZE: s := 'Paralysis, Poison, Death';
      C_SAVE.PETRIFY: s := 'Petrification, Polymorph';
      C_SAVE.WAND: s := 'Rod, Staff, Wand';
      C_SAVE.BREATH: s := 'Breath Weapon';
    else
      s := 'Spell';
    end;
    TextRend.DisplayString(2, 6 + i, LightGreen, s);
    need := p^.saves[i] - p^.saveBonus;
    if need < 2 then
      need := 2;
    if need > 20 then
      need := 20;
    s := StrUtil.NumStr(need);
    TextRend.DisplayString(32 - Length(s), 6 + i, White, s);
  end;
end;

{ n signed, its digits padded to two: '+ 0', '-15', '+40', '+103'. }
function SignedNum(n: Integer): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := StrUtil.NumStr(Abs(n));
  if Length(s) < 2 then
    s := ' ' + s;
  if n < 0 then
    s := '-' + s
  else
    s := '+' + s;
  SignedNum := s;
end;

{ Shows each thief skill's racial, Dexterity, and level contributions alongside
  the final percentage used by the game (#685). The final value may differ from
  their sum because it is clamped to zero or disabled by armor; a note under the
  table, wrapped over two rows, says when armor disables them. }
procedure DrawThief(p: Types.PCharRecord);
var
  j: Byte;
  base: ShortInt;
  racial: ShortInt;
  dexterity: ShortInt;
  s: Types.TStr40;
begin
  ViewChar.MoreHeading(p);
  TextRend.DisplayString(18, 4, White, 'Race Dex Level Total');
  { 8 = High(thiefSkills) }
  for j := 1 to 8 do begin
    case j of
      1: s := 'Pick Pockets';
      2: s := 'Open Lock';
      3: s := 'Find Traps';
      4: s := 'Move Silently';
      5: s := 'Hide in Shadows';
      6: s := 'Hear Noise';
      7: s := 'Climb Walls';
    else
      s := 'Read Languages';
    end;
    TextRend.DisplayString(2, 4 + j, LightGreen, s);
    ClassCal.ThiefSkillParts(p, j, base, racial, dexterity);
    { the adjustments and the base are three characters wide; a total can be four }
    TextRend.DisplayString(19, 4 + j, White, ViewChar.SignedNum(racial));
    TextRend.DisplayString(23, 4 + j, White, ViewChar.SignedNum(dexterity));
    TextRend.DisplayString(29, 4 + j, White, ViewChar.SignedNum(base));
    s := ViewChar.SignedNum(p^.thiefSkills[j]);
    TextRend.DisplayString(38 - Length(s), 4 + j, White, s);
  end;
  if ClassCal.ArmorBarsThiefSkills(p) then
    { two rows: the line is longer than the page is wide }
    TextRend.DisplayMessageWindow(2, 14, 37, 15, Yellow, True, 'Most armor or a shield bars the use of thief skills.');
end;

{ Shows the character's effective turning level and result against each undead
  type (#904). D destroys automatically, T turns automatically, a number is the
  minimum successful d20 roll, and '-' means the target cannot be turned. }
procedure DrawCleric(p: Types.PCharRecord);
var
  i: Byte;
  lvl: ShortInt;
  v: ShortInt;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(p, 'Turn Undead');
  lvl := ClassCal.TurnLevel(p);
  TextRend.DisplayString(2, 6, LightGreen, 'Cleric Level');
  s := StrUtil.NumStr(lvl);
  TextRend.DisplayString(38 - Length(s), 6, White, s);
  TextRend.DisplayString(2, 8, White, 'Undead');
  TextRend.DisplayString(32, 8, White, 'Result');
  for i := 1 to ClassCal.TURN_UNDEAD_KINDS do begin
    case i of
      1: s := 'Skeleton';
      2: s := 'Zombie';
      3: s := 'Ghoul';
      4: s := 'Shadow';
      5: s := 'Wight';
      6: s := 'Ghast';
      7: s := 'Wraith';
      8: s := 'Mummy';
      9: s := 'Spectre';
    else
      s := 'Vampire';
    end;
    TextRend.DisplayString(2, 8 + i, LightGreen, s);
    v := ClassCal.TurnValue(i, lvl);
    if v = ClassCal.TURN_IMMUNE then
      s := '-'
    { any roll succeeds: a 0 or -1 destroys, a 1 turns }
    else if v = 1 then
      s := 'T'
    else if Abs(v) <= 1 then
      s := 'D'
    else
      s := StrUtil.NumStr(Abs(v));
    TextRend.DisplayString(38 - Length(s), 8 + i, White, s);
  end;
  TextRend.DisplayString(2, 20, LightGreen, 'D  Destroyed automatically');
  TextRend.DisplayString(2, 21, LightGreen, 'T  Turned automatically');
  TextRend.DisplayString(2, 22, LightGreen, '#  Minimum d20 roll to turn');
end;

{ Runs the More Info pages (#592, #685, #904). Saves, statistics, and kills are
  always available; thief and turning pages appear only when usable. The kill
  page supports row and page scrolling. Statistics are allocated lazily when a
  statistics page is first opened. }
procedure MorePage;
var
  p: Types.PCharRecord;
  menu: Types.TStr40;
  page: Byte;
  b: Stats.PStatBlock;
  kinds: Byte;
  order: TKillOrder;
  haveStats: Boolean;
  top: Integer;
  ch: Char;
  ext: Boolean;
begin
  p := GameVars.curChar;
  CharHlp.RecalcStats(p);
  menu := 'Saves sTats Kills';
  if CharHlp.GetClassLevel(p, C_LEVEL.THIEF_BIT) > 0 then
    menu := menu + ' tHief';
  if ClassCal.TurnLevel(p) > 0 then
    menu := menu + ' Cler';
  menu := menu + ' Exit';
  page := PAGE_SAVES;
  haveStats := False;
  top := 1;
  GameVars.horizChoice := 1;
  repeat
    case page of
      PAGE_STATS: ViewChar.DrawGameStats(p, b);
      PAGE_KILLS: ViewChar.DrawKills(p, b, order, kinds, top);
      PAGE_THIEF: ViewChar.DrawThief(p);
      PAGE_CLERIC: ViewChar.DrawCleric(p);
    else
      ViewChar.DrawSaves(p);
    end;
    ch := MenuCore.MenuHorizontal('Info: ', menu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if page = PAGE_KILLS then
        case ch of
          C_KEYS.UP: if top > 1 then
                       Dec(top, 2);
          C_KEYS.DOWN: if top + KILLS_SHOWN <= kinds then
                         Inc(top, 2);
          C_KEYS.PAGE_UP: begin
                         Dec(top, KILLS_SHOWN);
                         if top < 1 then
                           top := 1;
                       end;
          C_KEYS.PAGE_DOWN: if top + KILLS_SHOWN <= kinds then
                         Inc(top, KILLS_SHOWN);
        end;
    end else
      case ch of
        'S': page := PAGE_SAVES;
        'H': page := PAGE_THIEF;
        'C': page := PAGE_CLERIC;
        'T', 'K': begin
               if not haveStats then
                 ViewChar.ReadStats(p, b, order, kinds);
               haveStats := True;
               if ch = 'T' then
                 page := PAGE_STATS
               else begin
                 page := PAGE_KILLS;
                 top := 1;
               end;
             end;
      end;
  until (not ext) and (ch in [C_KEYS.NONE, 'E']);
end;

{ Draw "More Info" under the character sheet's portrait frame (columns 28..38, rows 1..11), the M in white as a hotkey
  is and the rest in light green. ViewCharMenu takes M through MenuCore.extraKeys. The rows below the frame hold nothing
  else, so it is drawn whether or not a portrait is shown. }
procedure DrawMoreInfoLabel;
begin
  TextRend.DisplayString(29, 13, White, 'M');
  TextRend.DisplayString(30, 13, LightGreen, 'ore Info');
end;

{ Recalculate curChar's stats, then display armor class, hit points, THAC0 (60 - thac0Cur), damage, attacks a round,
  encumbrance and movement (as Haste and Slow make it, CharHlp.HasteSlowRate). }
procedure PrintCombatStats;
var
  p: Types.PCharRecord;
  row: Byte;
  col: Byte;
  mv: Byte;
  s: Types.TStr40;
begin
  p := GameVars.curChar;
  CharHlp.RecalcStats(p);
  row := 17;
  TextRend.DisplayString(1, row, White, 'AC    ');
  CharDisp.PrintArmorClass(p, 4, row);
  TextRend.DisplayString(1, row + 1, White, 'HP    ');
  CharDisp.PrintHitPoints(p, 4, row + 1, False);
  col := 8;
  TextRend.DisplayString(col + 1, row, White, 'THAC0   ');
  TextRend.DisplayString(col + 7, row, LightGreen, StrUtil.NumStr(60 - p^.thac0Cur));
  s := StrUtil.NumStr(p^.curRollsA[1]) + 'd' + StrUtil.NumStr(p^.curDiceA[1]);
  if p^.curModA[1] > 0 then
    s := s + '+' + StrUtil.NumStr(p^.curModA[1]);
  if p^.curModA[1] < 0 then
    s := s + '-' + StrUtil.NumStr(Abs(p^.curModA[1]));
  TextRend.DisplayString(col, row + 1, White, 'Damage        ');
  TextRend.DisplayString(col + 7, row + 1, LightGreen, s);
  { the attacks a round the character's classes give (ClassCal.RecalcBaseSkills), under Damage and lined up with it
    (#836, #911) }
  TextRend.DisplayString(col, row + 2, White, 'Att/Rd        ');
  TextRend.DisplayString(col + 7, row + 2, LightGreen, StrUtil.HalvesStr(p^.attacks));
  col := RIGHT_COL;
  TextRend.DisplayString(col, row, White, 'Encumbrance      ');
  TextRend.DisplayString(col + 12, row, LightGreen, StrUtil.NumStr(p^.encumbrance));
  mv := CharHlp.HasteSlowRate(p, p^.movementCur);
  TextRend.DisplayString(col + 3, row + 1, White, 'Movement   ');
  TextRend.DisplayString(col + 12, row + 1, LightGreen, StrUtil.NumStr(mv));
end;

{ Print stat statIdx (0..5) of curChar in light green, or light magenta while modifying. Strength 18 with exceptional
  strength adds '(xx)', zero-padded, with 100 shown as 00. }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := LightMagenta
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 7, 11, statIdx + 7);
  if GameVars.curChar^.stats[statIdx] < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 7, hlCol, StrUtil.NumStr(GameVars.curChar^.stats[statIdx]));
  if (statIdx = C_STAT.STRENGTH) and (GameVars.curChar^.strCur = 18) and (GameVars.curChar^.strExc > 0) then begin
    { 100 shows as 00 }
    s := StrUtil.ZeroPad2(GameVars.curChar^.strExc);
    TextRend.DisplayString(7, 7, hlCol, '(' + s + ')');
  end;
end;

{ Runs the character-sheet menu until Exit, Escape, or an action sets done.
  Available commands depend on the character's items, spells, money, and paladin
  abilities. More Info uses the M shown below the portrait because the menu line
  is full. During combat, temporarily switch to the noncombat palette. }
procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
  shown: Types.PCharRecord;
begin
  if GameVars.ifcState = C_IFC.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  tradeTarget := GameVars.curChar;
  shown := GameVars.curChar;
  ViewChar.DisplayChar(shown);
  ViewChar.DrawMoreInfoLabel;
  while not (ch in [C_KEYS.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    { every memorized-spell slot }
    for i := 0 to Types.MEMORIZED_LAST do
      if CharHlp.MemorizedAt(shown, i) > 0 then
        hasSpells := True;
    { every coin type, gems and jewelry included }
    for j := C_MONEY.COPPER to C_MONEY.JEWELRY do
      if shown^.coins[j] > 0 then
        hasMoney := True;
    if shown^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    if CharHlp.MayTrade(shown) and hasMoney and
        (GameVars.ifcState <> C_IFC.IN_COMBAT) then
      s := s + 'Trade ';
    { in the vault, dropped money is deposited there (Money.DropMoney) }
    if hasMoney and (GameVars.ifcState = C_IFC.VAULT) then
      s := s + 'Deposit '
    else if hasMoney then
      s := s + 'Drop ';
    if CharHlp.PaladinCanHeal(shown) then
      s := s + 'Heal ';
    if CharHlp.PaladinCanCure(shown) then
      s := s + 'Cure ';
    s := s + 'Exit';
    MenuCore.extraKeys := 'M';
    { Alt-n opens member n's items, outside combat (AltItems) }
    MenuCore.memberKeysToCaller := GameVars.ifcState <> C_IFC.IN_COMBAT;
    ch := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    if ext then begin
      { the sheet shows the member whose items were opened, as after Items }
      if ViewChar.AltItems(ch) then begin
        shown := GameVars.curChar;
        ViewChar.DisplayChar(shown);
        ViewChar.DrawMoreInfoLabel;
      end;
      ch := ' ';
    end;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := Magic.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
             { the lighter load shows in Encumbrance and Movement (#700) }
             ViewChar.PrintCombatStats;
           end;
      'H': if CharHlp.PaladinCanHeal(shown) then
             ViewChar.LayOnHands(shown);
      'C': if CharHlp.PaladinCanCure(shown) then
             ViewChar.CureDisease(shown);
      'M': ViewChar.MorePage;
    end;
    if not done and (ch in ['I', 'S', 'T', 'H', 'C', 'M']) then begin
      shown := GameVars.curChar;
      ViewChar.DisplayChar(shown);
      ViewChar.DrawMoreInfoLabel;
    end;
  end;
  if GameVars.ifcState = C_IFC.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharDisp.DisplayNoncombatInterface;
end;

{ True when the item may leave curChar's inventory. Equipped items must be unreadied first. If a scroll has pending
  scribing (charges, effect or special above $7F), ask before discarding that work. }
function CheckItemAvail(item: Types.PItemRec): Boolean;
begin
  CheckItemAvail := False;
  if item^.equipped <> 0 then
    CharDisp.PrintBottomLine('Must be unreadied')
  else if not CharHlp.ItemReadable(item) then
    CheckItemAvail := True
  else if (item^.charges > $7F) or (item^.effect > $7F) or (item^.special > $7F) then begin
    CharDisp.DisplayCreatureName(GameVars.curChar, 1, 21, False);
    GameVars.curCol := Length(GameVars.curChar^.name) + 2;
    GameVars.curRow := 21;
    ViewChar.SayBelow(False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

{ STING's raw item viewer (V in the Items menu, #612), Curse's ViewItemDetail: the item's type, name ids, plus, save
  bonus, ready, identified mask, cursed, value, charges, effect and special, and its base type's large-creature damage
  dice, until a key. The caller redraws the screen. The labels are literals, in the overlay, rather than a typed
  constant in the data segment (#973). }
procedure ViewItemDetail(it: Types.PItemRec);
var
  v: array[1..15] of LongInt;
  i: Byte;
  s: Types.TStr40;
begin
  with it^ do begin
    v[1] := itemType;
    v[2] := nameIds[1];
    v[3] := nameIds[2];
    v[4] := nameIds[3];
    v[5] := Byte(plus);
    v[6] := Byte(saveBonus);
    v[7] := equipped;
    v[8] := unidMask;
    v[9] := cursed;
    v[10] := value;
    v[11] := charges;
    v[12] := effect;
    v[13] := special;
    v[14] := CharHlp.BaseItem(itemType)^.dmgLgRolls;
    v[15] := CharHlp.BaseItem(itemType)^.dmgLgDice;
  end;
  Border.ClearToFrame;
  for i := 1 to 15 do begin
    case i of
      1: s := 'itemtype:';
      2: s := 'namenum(1):';
      3: s := 'namenum(2):';
      4: s := 'namenum(3):';
      5: s := 'plus:';
      6: s := 'plussave:';
      7: s := 'ready:';
      8: s := 'identified:';
      9: s := 'cursed:';
      10: s := 'value:';
      11: s := 'charges:';
      12: s := 'effect:';
      13: s := 'special:';
      14: s := 'dice large:';
    else
      s := 'sides large:';
    end;
    TextRend.DisplayString(2, i + 1, LightGreen, s);
    TextRend.DisplayString(20, i + 1, LightGreen, StrUtil.NumStr(v[i]));
  end;
  TextRend.DisplayAndPause(LightGreen, 'press a key');
end;

function TagsSets: Boolean;
begin
  TagsSets := (GameVars.ifcState <> C_IFC.VAULT) and (GameVars.ifcState <> C_IFC.SHOP_TEMPLE);
end;

procedure TagSet(item: Types.PItemRec; n: Byte);
begin
  if not CharHlp.SetTaggable(item) then
    CharDisp.PrintBottomLine('Weapons and shields only')
  else if item^.weaponSet = n then
    item^.weaponSet := C_ITEM.SET_NONE
  else
    item^.weaponSet := n;
end;

function ItemMenuLine(creature: Types.PCharRecord; item: Types.PItemRec): Types.TStr40;
const
  { the bottom line's columns, and MenuVertical's ' Exit' }
  LINE_WIDTH = 40;
  EXIT_WIDTH = 5;
  SET_KEYS = ' 1 2';
var
  s: String;
  halve: Boolean;
begin
  s := 'Ready';
  if CharHlp.CanUseItems(creature) then
    s := s + ' Use';
  if CharHlp.MayTrade(creature) and (GameVars.ifcState <> C_IFC.IN_COMBAT) then
    s := s + ' Trade';
  if GameVars.ifcState = C_IFC.VAULT then
    s := s + ' Deposit'
  else
    s := s + ' Drop';
  halve := (creature^.numberOfItems < C_ITEM.CARRY_MAX) and (item^.quantity > 1);
  if halve then
    s := s + ' Halve';
  if ViewChar.CanJoin(item) then
    s := s + ' Join';
  { the characters that may trade may sell, but only in a shop }
  if CharHlp.MayTrade(creature) and (GameVars.ifcState = C_IFC.SHOP_TEMPLE) then
    s := s + ' Sell';
  { Id on every item at the counter: offered only where something was hidden, it marked the magic ones (#1115) }
  if GameVars.ifcState = C_IFC.SHOP_TEMPLE then
    s := s + ' Id'
  else if SpellInf.HasItemPage(item) then
    s := s + ' Info';
  if halve and (Length(s) + EXIT_WIDTH > LINE_WIDTH) then
    Delete(s, Pos(' Halve', s), Length(' Halve'));
  { the weapon-set keys (#1209), shown when they fit; they work either way }
  if ViewChar.TagsSets and CharHlp.SetTaggable(item) and (Length(s) + Length(SET_KEYS) + EXIT_WIDTH <= LINE_WIDTH) then
    s := s + SET_KEYS;
  ItemMenuLine := s;
end;

{ The spell page for sel (SpellInf.ShowItemPage), stepping through every item of creature's that has one; idx
  receives the list line of the item shown last. }
procedure ItemInfo(creature: Types.PCharRecord; sel: Types.PItemRec; var idx: Integer);
var
  items: SpellInf.TPageItems;
  count: Integer;
  cur: Integer;
  p: Types.PItemRec;
begin
  count := 0;
  cur := 0;
  p := creature^.itemsAddr;
  while (p <> nil) and (count < C_ITEM.CARRY_MAX) do begin
    if SpellInf.HasItemPage(p) then begin
      if p = sel then
        cur := count;
      items[count] := p;
      Inc(count);
    end;
    p := p^.next;
  end;
  SpellInf.ShowItemPage(items, count, cur);
  if count > 0 then
    idx := MenuCore.ListIndex(creature^.itemsAddr, items[cur]);
end;

{ Run curChar's inventory menu, offering actions according to the character's state, the current interface state and
  the highlighted item (ItemMenuLine), until Escape, done, or no items remain. The line is rebuilt as the highlight
  moves. Outside combat Alt-n switches the menu to member n's items in place (#1195): member n becomes the current
  character and the one Trade offers first, and the highlight goes to its first item. It does not open a second menu,
  so Escape still leaves to whatever opened the first. Alt-n for the member shown, or for no member, does nothing; for
  a member with no items it says so and stays. F1 lists the screen's keys (KeyHelp.ITEM_KEYS). }
procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  creature: Types.PCharRecord;
  member: Types.PCharRecord;
  itemCount: Byte;
begin
  creature := GameVars.curChar;
  ch := ' ';
  sel := creature^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  { the list as well as the count: a stale count over a nil list would never leave the loop }
  while not (ch in [C_KEYS.NONE, 'E']) and not done and (creature^.numberOfItems > 0) and
      (creature^.itemsAddr <> nil) do begin
    itemCount := creature^.numberOfItems;
    { the highlighted item, as MenuVertical takes it: a line past the list's end is its last item }
    p := MenuCore.FindListMember(idx, creature^.itemsAddr);
    while (p = nil) and (idx > 0) do begin
      Dec(idx);
      p := MenuCore.FindListMember(idx, creature^.itemsAddr);
    end;
    s := ViewChar.ItemMenuLine(creature, p);
    { rebuild every item name }
    p := creature^.itemsAddr;
    while p <> nil do begin
      CharHlp.ItemLabel(p, True);
      p := p^.next;
    end;
    if needRedraw or (GameVars.invRedraw <> 0) then begin
      Border.ClearToFrame;
      CharDisp.DisplayCreatureName(creature, 1, 1, True);
      TextRend.DisplayString(Length(creature^.name) + 4, 1, LightGreen, 'Items');
      Border.DrawWindow(1, 3, 38, 22, 0, Black, '');
      TextRend.DisplayString(1, 3, White, 'Ready Item');
      if ViewChar.TagsSets then
        TextRend.DisplayString(CharHlp.SET_LABEL_COL - 2, 3, White, 'Set');
      vmRedraw := True;
      needRedraw := False;
      GameVars.invRedraw := 0;
    end;
    { 1 and 2 tag the item for a weapon set (#1209), whether the line shows them or not; STING: V, not on the menu
      line, shows the selected item's raw record, as Curse's debug mode does }
    MenuCore.extraKeys := '';
    if ViewChar.TagsSets then
      MenuCore.extraKeys := '12';
    if GameVars.stingArg then
      MenuCore.extraKeys := MenuCore.extraKeys + 'V';
    { a move returns, so that the line follows the highlighted item }
    MenuCore.movesToCaller := True;
    MenuCore.memberKeysToCaller := GameVars.ifcState <> C_IFC.IN_COMBAT;
    { F1: the screen's keys, the weapon sets' among them (KeyHelp.ITEM_KEYS) }
    MenuCore.helpToCaller := True;
    ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22,
                                creature^.itemsAddr, True, vmRedraw, idx, sel);
    if MenuCore.moved then
      { Page Up's scan code is 'I': a move is no choice }
      ch := ' '
    else if ch = C_KEYS.F1 then begin
      KeyHelp.ShowPage(@KeyHelp.ITEM_KEYS, KeyHelp.ITEM_LINES);
      needRedraw := True;
      ch := ' ';
    end
    else if Party.AltMember(ch) > 0 then begin
      member := Party.MemberAt(Party.AltMember(ch));
      if (member <> nil) and (member <> creature) then
        if (member^.numberOfItems = 0) or (member^.itemsAddr = nil) then begin
          TextRend.DisplayAndPause(Yellow, member^.name + ' has no items.');
          TextRend.ClearBottomLine;
        end else begin
          creature := member;
          GameVars.curChar := member;
          tradeTarget := member;
          idx := 0;
          needRedraw := True;
        end;
      ch := ' ';
    end else if sel <> nil then
      case ch of
        'V': if GameVars.stingArg then begin
               ViewChar.ViewItemDetail(sel);
               needRedraw := True;
             end;
        'R': FxEngine.ToggleReadyItem(sel);
        '1', '2': if ViewChar.TagsSets then begin
                    ViewChar.TagSet(sel, Ord(ch) - Ord('0'));
                    vmRedraw := True;
                  end;
        { a scroll the Cast list offers (CharHlp.CastableScroll) need not be readied; other items must be }
        'U': if (sel^.equipped = 0) and not CharHlp.CastableScroll(creature, sel) then
             begin
               CharDisp.PrintBottomLine('Must be Readied');
               ch := ' ';
             end else if CharHlp.ItemReadable(sel) or (CharHlp.ItemSpell(sel) <> C_SPELL.NONE) then begin
               Magic.UseItem(sel, done);
               if GameVars.ifcState <> C_IFC.IN_COMBAT then
                 { outside combat, using an item does not end the menu }
                 done := False;
               if not done then
                 needRedraw := True;
             end;
        'T': begin
               if ViewChar.CheckItemAvail(sel) then
                 ViewChar.ItemTradeMenu(sel)
               else
                 ch := ' ';
               needRedraw := True;
             end;
        { asked once: a refusal in the vault must not fall through to Drop and ask again (#973) }
        'D': if not ViewChar.CheckItemAvail(sel) then
               ch := ' '
             else if GameVars.ifcState = C_IFC.VAULT then begin
               { the vault keeps it, with the game it is saved with }
               if Vault.HasRoom then begin
                 Vault.DepositItem(GameVars.curChar, sel);
                 vmRedraw := True;
               end else
                 TextRend.DisplayAndPause(Yellow, 'The vault is full.');
             end else begin
               { the item label ends in a space }
               CharHlp.ItemLabel(sel, False);
               ViewChar.SayBelow(True, 'Your ' + sel^.name + 'will be gone forever');
               if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
               begin
                 CharHlp.RemoveItem(GameVars.curChar, sel);
                 vmRedraw := True;
               end;
               Border.ClearBox(1, 21, 38, 22);
             end;
        'H': ViewChar.HalveItem(sel);
        'J': CharHlp.JoinStacks(GameVars.curChar, sel);
        'S': if ViewChar.CheckItemAvail(sel) then
               ViewChar.SellItem(sel)
             else
               ch := ' ';
        'I': if GameVars.ifcState = C_IFC.SHOP_TEMPLE then
               ViewChar.IdentifyItem(sel, vmRedraw)
             else if SpellInf.HasItemPage(sel) then begin
               ViewChar.ItemInfo(creature, sel, idx);
               needRedraw := True;
             end;
      end;
    if not MenuCore.moved then
      CharHlp.RecalcStats(creature);
    if creature^.numberOfItems <> itemCount then
      vmRedraw := True;
  end;
end;

procedure MemberItems(creature: Types.PCharRecord);
var
  done: Boolean;
begin
  GameVars.curChar := creature;
  { Trade offers this character's last recipient first; it may be stale without View having run }
  tradeTarget := creature;
  if (creature^.numberOfItems = 0) or (creature^.itemsAddr = nil) then
    TextRend.DisplayAndPause(Yellow, creature^.name + ' has no items.')
  else begin
    done := False;
    ViewChar.UseItemMenu(done);
  end;
  TextRend.ClearBottomLine;
end;

function AltItems(c: Char): Boolean;
var
  member: Types.PCharRecord;
begin
  member := nil;
  if (GameVars.ifcState <> C_IFC.IN_COMBAT) and (Party.AltMember(c) > 0) then
    member := Party.MemberAt(Party.AltMember(c));
  if member <> nil then
    ViewChar.MemberItems(member);
  AltItems := member <> nil;
end;

{ Select a trade recipient, check carrying capacity, then copy the item to the recipient and remove it from curChar. }
procedure ItemTradeMenu(item: Types.PItemRec);
var
  tgt: Types.PCharRecord;
begin
  tgt := tradeTarget;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.SelectChar('Trade with Whom?', True, tgt);
  if tgt <> nil then begin
    tradeTarget := tgt;
    if ViewChar.CannotCarryItem(tgt, item) then
      CharDisp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddToInventory(tgt, item);
      CharHlp.RemoveItem(GameVars.curChar, item);
      CharHlp.RecalcStats(tgt);
    end;
  end;
end;

{ Split an item stack: a copy holding half the quantity (rounded down), unreadied, is linked in right after the
  original, which keeps the rest. }
procedure HalveItem(item: Types.PItemRec);
var
  newIt: Types.PItemRec;
  half: Byte;
  remainder: Byte;
begin
  half := item^.quantity div 2;
  if half > 0 then begin
    remainder := item^.quantity - half;
    GetMem(newIt, SizeOf(Types.TItemRec));
    Move(item^, newIt^, SizeOf(Types.TItemRec));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := item^.next;
    item^.quantity := remainder;
    item^.next := newIt;
  end else
    CharDisp.PrintBottomLine('Can''t halve that');
end;

{ True when item is a stack (quantity > 0) another of curChar's stacks can join (CharHlp.SameStack): Join has
  something to do. }
function CanJoin(item: Types.PItemRec): Boolean;
var
  p: Types.PItemRec;
begin
  CanJoin := False;
  if item^.quantity > 0 then begin
    p := GameVars.curChar^.itemsAddr;
    while p <> nil do begin
      if CharHlp.SameStack(item, p) then
        CanJoin := True;
      p := p^.next;
    end;
  end;
end;

{ Offer MoneyCal.ItemSalePrice for the item: half what it is worth, with ammunition valued per bundle of 20 at any
  quantity, so a single arrow fetches a twentieth of a bundle's price. Pay as platinum (price div 5) plus gold (price
  mod 5) through Money.GiveCoins: the coins the character cannot carry go to the treasure pool. }
procedure SellItem(item: Types.PItemRec);
var
  price: Word;
begin
  price := MoneyCal.ItemSalePrice(item);
  CharHlp.ItemLabel(item, False);
  ViewChar.SayBelow(True, 'I''ll give you ' + StrUtil.NumStr(price) + ' gold pieces for your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharDisp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(GameVars.curChar, item);
    { only the coins that fit: SSI gave all the platinum when there was room for it alone, and always the gold (#739) }
    Money.GiveCoins(GameVars.curChar, price div 5, price mod 5);
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Identify an item for 200 gold, paid from the character's coins if they are worth enough (converting them to platinum
  and gold), else from the treasure pool. newInfo is set, never cleared, when identification reveals new information. }
procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean);
var
  paid: Boolean;
begin
  paid := False;
  CharHlp.ItemLabel(item, False);
  ViewChar.SayBelow(True, 'For 200 gold pieces I''ll identify your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    paid := Money.PayGold(GameVars.curChar, 200);
  end;
  if paid then begin
    if item^.unidMask = 0 then
      ViewChar.SayBelow(True, 'I can''t tell anything new about your ' + item^.name)
    else begin
      item^.unidMask := 0;
      CharHlp.ItemLabel(item, False);
      ViewChar.SayBelow(True, 'It looks like some sort of ' + item^.name);
      newInfo := True;
    end;
    TextRend.PauseOnly;
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Show the current character's coins as a menu (Money.CoinMenu) and return the line picked, or nil on Escape. list
  receives the menu list, for MenuCore.FreeStringList (nil when there is no coin). }
function PickCoinType(var list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  prev: Types.PItemRec;
  idx: Integer;
  redraw: Boolean;
  ch: Char;
begin
  p := Money.CoinMenu(GameVars.curChar);
  list := p;
  prev := nil;
  idx := 0;
  redraw := True;
  ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 12, 7, 25, 13, p, True,
                              redraw, idx, prev);
  PickCoinType := prev;
end;

{ Trade coins from curChar to another character. The outer loop picks the recipient, starting from tradeTarget; the
  inner loop lists curChar's nonzero coin types (linked backwards, so the highest type heads the list), lets the player
  pick a type and an amount up to the holding, and hands it over with Money.TradeMoney, repeating while coins remain.
  Escaping the coin menu goes back to choosing the recipient. }
procedure TradeTreasureMenu;
var
  tgt: Types.PCharRecord;
  m: ShortInt;
  mType: ShortInt;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  s2: String;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := tradeTarget;
    CharDisp.DisplayNoncombatInterface;
    CharDisp.SelectChar('Trade to?', True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar(GameVars.curChar);
      repeat
        ViewChar.PrintMoney;
        tradeTarget := tgt;
        prev := ViewChar.PickCoinType(list);
        if prev = nil then begin
          exitInner := True;
          exitOuter := False;
        end else begin
          s2 := '';
          mType := MoneyCal.ParseMoneyType(prev^.name, s2);
          s2 := 'How much ' + s2 + 'will you trade? ';
          amount := Money.InputNumberMax(GameVars.curChar^.coins[mType], s2, LightGreen);
          Money.TradeMoney(GameVars.curChar, tgt, amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := C_MONEY.COPPER to C_MONEY.JEWELRY do
            if GameVars.curChar^.coins[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(list);
      until exitInner;
    end;
  until exitOuter;
end;

{ Choose a coin type and amount to drop from the character's holdings, repeating until Escape or no coins remain. }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  exitFlag: Boolean;
  s2: String;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    prev := ViewChar.PickCoinType(list);
    if prev = nil then
      exitFlag := True
    else begin
      s2 := '';
      mType := MoneyCal.ParseMoneyType(prev^.name, s2);
      if GameVars.ifcState = C_IFC.VAULT then
        s2 := 'How much ' + s2 + 'will you deposit? '
      else
        s2 := 'How much ' + s2 + 'will you drop? ';
      amount := Money.InputNumberMax(GameVars.curChar^.coins[mType], s2, LightGreen);
      Money.DropMoney(GameVars.curChar, amount, mType);
      exitFlag := True;
      for m := C_MONEY.COPPER to C_MONEY.JEWELRY do
        if GameVars.curChar^.coins[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(list);
  until exitFlag;
end;

{ True when the creature already holds C_ITEM.CARRY_MAX (16) items or more, or the item's weight (times its quantity)
  is more than it can still carry (Money.CheckOverload, which counts a readied Bag of Holding). Recalculates the
  creature's stats first. }
function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
var
  takable: Word;
begin
  CharHlp.RecalcStats(creature);
  CannotCarryItem := ((creature^.numberOfItems >= C_ITEM.CARRY_MAX) and
                      not ((GameVars.autoJoinOn <> 0) and CharHlp.JoinsWhole(creature, item))) or
    Money.CheckOverload(creature, CharHlp.ItemWeight(item), takable);
end;

end.
