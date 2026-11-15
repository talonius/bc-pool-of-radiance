{ Temple services: the Heal menu over TownCore's temple (its services, rules and words), Repair for the whole party,
  the money they cost, and what each does to a character here. }
{$O+,F+}
{$I COMPILER.INC}
unit Temple;

interface

uses TownCore;

{ The temple: its counter and Heal menu, at prices by mode, MoneyCal.TEMPLE_FULL_PRICE or TEMPLE_TENTH_OFF (the value
  the script stored in C_GBVM.ENTER_TEMPLE). }
procedure TempleMainMenu(mode: Byte);

{ The Heal menu: the services the temple sells (TempleRules), for the current character, and Repair for the party. }
procedure HealMenu;

{ The temple's rules at full price: every service at TownCore's 1st-edition gold prices (Heal 5000, Resurrection 11000
  and Restoration 7000 among them, #1125); Raise Dead and Resurrection for every race but the elf, the monster too,
  since SSI's temple raised any corpse but an elf's (a creature that joined through Animate Dead, #1089, is of race 0);
  a failed survival roll gone for good (#752). The script's tenth off is TempleMainMenu's to take
  (MoneyCal.TemplePrice). }
procedure TempleRules(var r: TTempleRules);

{ TownCore's race (TownCore.RACE_*) for one of this game's (C_RACE); RACE_MONSTER for any other value. }
function CanonRace(race: ShortInt): Byte;

{ Reads the current character for TownCore: its status, hit points, Constitution (PoR keeps only the one score, which
  the survival roll and system shock both read), canonical race, highest class level, the effects the temple cures
  (a cursed item counts whether it is readied or not, as Remove Curse lifts every one) and its drained levels. }
procedure Look(var c: TTempleChar);

implementation

uses Types, Crt, C_MSG, C_MONEY, C_LEVEL, GameVars, TextRend, Money, Magic, FxEngine, C_EFFECT, C_KEYS, C_STATUS,
  C_RACE, Stats, Border, CharHlp, MenuCore, Shop, CharDisp, Dice, ClassCal, MoneyCal, StrUtil, ViewChar, UiColor;

var
  { the temple's rules, at the prices TempleMainMenu was entered with }
  rules: TTempleRules;

procedure TempleRules(var r: TTempleRules);
begin
  TownCore.DefaultRules(r);
  TownCore.StandardPrices(r, 1);
  r.raiseRaces := r.raiseRaces + [RACE_MONSTER];
  r.resurrectRaces := r.resurrectRaces + [RACE_MONSTER];
  r.failGone := True;
end;

function CanonRace(race: ShortInt): Byte;
begin
  case race of
    C_RACE.DWARF: CanonRace := RACE_DWARF;
    C_RACE.ELF: CanonRace := RACE_ELF;
    C_RACE.GNOME: CanonRace := RACE_GNOME;
    C_RACE.HALF_ELF: CanonRace := RACE_HALFELF;
    C_RACE.HALFLING: CanonRace := RACE_HALFLING;
    C_RACE.HALF_ORC: CanonRace := RACE_HALFORC;
    C_RACE.HUMAN: CanonRace := RACE_HUMAN;
  else
    CanonRace := RACE_MONSTER;
  end;
end;

procedure Look(var c: TTempleChar);
var
  cr: Types.PCharRecord;
  effect: Types.PEffectRec;
  item: Types.PItemRec;
  i: Integer;
begin
  cr := GameVars.curChar;
  c.status := cr^.status;
  c.hp := cr^.hpCur;
  c.hpMax := cr^.hpMax;
  c.conPerm := cr^.conCur;
  c.conCur := cr^.conCur;
  c.race := Temple.CanonRace(cr^.race);
  c.level := 0;
  for i := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if cr^.classLevels[i] > c.level then
      c.level := cr^.classLevels[i];
  c.flags := 0;
  if CharHlp.HasEffect(cr, C_EFFECT.BLIND, effect) then
    c.flags := c.flags or TF_BLIND;
  if FxEngine.HasDisease(cr) then
    c.flags := c.flags or TF_DISEASED;
  if CharHlp.HasEffect(cr, C_EFFECT.POISONED, effect) then
    c.flags := c.flags or TF_POISONED;
  if CharHlp.HasEffect(cr, C_EFFECT.SLOW_POISON_END, effect) or
      CharHlp.HasEffect(cr, C_EFFECT.SLOW_POISON_HIT, effect) then
    c.flags := c.flags or TF_SLOW_POISON;
  if CharHlp.HasEffect(cr, C_EFFECT.ROT_NO_HEAL, effect) then
    c.flags := c.flags or TF_ROT;
  if CharHlp.HasEffect(cr, C_EFFECT.BESTOW_CURSE, effect) then
    c.flags := c.flags or TF_CURSED;
  if CharHlp.HasEffect(cr, C_EFFECT.FEEBLEMIND, effect) then
    c.flags := c.flags or TF_FEEBLE;
  item := cr^.itemsAddr;
  while item <> nil do begin
    if item^.cursed <> 0 then
      c.flags := c.flags or TF_CURSED;
    item := item^.next;
  end;
  c.drained := cr^.drainedLevels;
  if cr^.drainedLevels > 0 then
    c.flags := c.flags or TF_DRAINED;
end;

{ "<name> <msg>", then "cast cure anyway: " Yes or No. }
function Ask(msg: String): Boolean;
begin
  CharDisp.PrintNameString(GameVars.curChar, msg, 0, False);
  Ask := MenuCore.YesNoMenu('cast cure anyway: ', promptColor, optionColor, commandColor) = 'Y';
  CharDisp.ClearMessageWindow;
end;

{ The quote and "pay for cure "; a Yes pays from the current character first, then the pooled treasure. True only when
  it was paid. The menu is in the bottom line's colors: SSI swapped them here, Yes and No white with green hotkeys
  (POR-0231). }
function Pay(quote: String; cost: LongInt): Boolean;
begin
  TextRend.ShowMessage(LightGreen, True, quote);
  Pay := False;
  if MenuCore.YesNoMenu('pay for cure ', promptColor, optionColor, commandColor) = 'Y' then
    Pay := Money.PayGold(GameVars.curChar, cost);
end;

{ "<name> <msg>" in a cleared message window until a key. }
procedure Say(msg: String);
begin
  CharDisp.ClearMessageWindow;
  CharDisp.PrintNameString(GameVars.curChar, msg, 0, True);
end;

{ Carries out a TownCore deed on the current character, in TownCore's order. TA_FEEBLE, Heal's, ends the Feeblemind
  spell (#1121). }
procedure Act(d: TTempleDeed);
var
  cr: Types.PCharRecord;
  i: Byte;
  hp: Integer;
begin
  cr := GameVars.curChar;
  if d.acts and TA_BLIND <> 0 then
    FxEngine.RemoveEffect(cr, C_EFFECT.BLIND, nil);
  if d.acts and TA_DISEASE <> 0 then
    if FxEngine.RemoveDiseases(cr) then ;
  if d.acts and TA_FEEBLE <> 0 then
    FxEngine.RemoveEffect(cr, C_EFFECT.FEEBLEMIND, nil);
  GameVars.effectLock := 1;
  if d.acts and TA_POISON <> 0 then begin
    FxEngine.RemoveEffect(cr, C_EFFECT.POISONED, nil);
    FxEngine.RemoveEffect(cr, C_EFFECT.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(cr, C_EFFECT.SLOW_POISON_HIT, nil);
  end;
  if d.acts and TA_ANIMATE <> 0 then
    FxEngine.RemoveEffect(cr, C_EFFECT.ANIMATE_DEAD, nil);
  GameVars.effectLock := 0;
  if d.acts and TA_CURSE <> 0 then begin
    GameVars.spellTargets[1] := cr;
    Magic.SpellRemoveCurse;
  end;
  if d.acts and TA_RESTORE <> 0 then begin
    GameVars.spellTargets[1] := cr;
    Magic.SpellRestoration;
  end;
  { Constitution goes no lower than AbilAdj.SCORE_MIN (#615): TownCore asks for no more than that }
  if d.acts and TA_LOSE_CON <> 0 then
    for i := 1 to d.conLoss do
      ClassCal.LoseConstitution(cr);
  if d.acts and TA_STATUS <> 0 then begin
    cr^.status := d.status;
    cr^.enabled := Ord(d.status = C_STATUS.OKAY);
  end;
  if d.acts and TA_SET_HP <> 0 then
    cr^.hpCur := d.hp;
  if d.acts and TA_FULL_HP <> 0 then
    cr^.hpCur := cr^.hpMax;
  if d.acts and TA_HEAL_HP <> 0 then begin
    hp := d.hp;
    if hp > 255 then
      hp := 255;
    if FxEngine.RestoreHitPoints(cr, hp, False) then ;
  end;
  if d.acts and TA_RAISED <> 0 then
    Stats.Count(cr, Stats.RAISED, 1);
  if d.acts and TA_DIED <> 0 then
    Stats.Death(cr);
end;

function Roll(n, sides: Byte): Integer;
begin
  Roll := Dice.RollDice(n, sides);
end;

{ Pool of Radiance's own words where TownCore's differ, '' for the rest. }
function Words(msg: Byte): String;
begin
  case msg of
    TM_STILL_POISONED: Words := 'is poisoned, and RAISE DEAD cannot help.';
  else
    Words := '';
  end;
end;

{ The temple's side of TownCore: Look, Ask, Pay, Say, Act, Roll and Words. }
procedure TempleIO(var io: TTempleIO);
begin
  io.Look := Look;
  io.Ask := Ask;
  io.Pay := Pay;
  io.Say := Say;
  io.Act := Act;
  io.Roll := Roll;
  io.Words := Words;
end;

{ Sells service svc (TownCore.TS_*) to the current character. }
procedure Serve(svc: Byte);
var
  io: TTempleIO;
begin
  Temple.TempleIO(io);
  TownCore.TempleService(rules, svc, io);
end;

{ Repair (#1125), Pools of Darkness's whole-party cure at this temple's prices: each member's needs
  (TownCore.RepairPlan) are added up into one quote, paid once from the current character or else the pool, and carried
  out with no further question, the survival roll and system shock rolled as each service rolls them (#752, #1004). A
  member the temple will not raise, or one gone, is named first and left out. When a roll fails, the services that
  member still had coming are not done, and the priests put their price in the pool. A party that needs nothing is
  told so, with no quote. }
procedure RepairParty;
var
  plans: array[1..Types.MAX_PARTY] of TRepairPlan;
  who: array[1..Types.MAX_PARTY] of Types.PCharRecord;
  n: Byte;
  i: Byte;
  p: Types.PCharRecord;
  buyer: Types.PCharRecord;
  c: TTempleChar;
  total: LongInt;
  undone: LongInt;
  io: TTempleIO;
begin
  Temple.TempleIO(io);
  buyer := GameVars.curChar;
  n := 0;
  total := 0;
  p := GameVars.creatureList;
  while (p <> nil) and (n < Types.MAX_PARTY) do begin
    Inc(n);
    who[n] := p;
    GameVars.curChar := p;
    Temple.Look(c);
    TownCore.RepairPlan(rules, c, plans[n]);
    Inc(total, TownCore.RepairCost(rules, plans[n]));
    p := p^.nextCharAddr;
  end;
  for i := 1 to n do
    if plans[i].refusal <> TM_NONE then begin
      GameVars.curChar := who[i];
      Temple.Say(TownCore.TempleWords(io, plans[i].refusal));
    end;
  GameVars.curChar := buyer;
  if total = 0 then begin
    { held until a key: a timed pause is gone at once at the fastest game speed, and the player is left not knowing
      what Repair did (#1155) }
    CharDisp.MessageText('The party needs nothing the temple can give.', LightGreen, True);
    CharDisp.MessageWait;
  end else if Temple.Pay(TownCore.RepairQuote(rules, total), total) then begin
    undone := 0;
    for i := 1 to n do begin
      GameVars.curChar := who[i];
      Inc(undone, TownCore.TempleRepair(rules, plans[i], io));
    end;
    GameVars.curChar := buyer;
    if undone > 0 then begin
      Inc(GameVars.treasureMoney[C_MONEY.GOLD], undone);
      TextRend.ShowMessage(LightGreen, True, 'The priests put ' + StrUtil.NumStr(undone) +
                           ' gold pieces back in the pool.');
      TextRend.PauseOnly;
    end;
  end;
  GameVars.curChar := buyer;
  CharDisp.ClearMessageWindow;
end;

{ HealMenu: lists the services the temple sells (TownCore.ServiceName) and Exit in a string list, runs
  MenuCore.MenuVertical over it and sells the chosen one (Exit, or a #0 key, leaves); Repair (RepairParty) is on the
  menu's bottom line, as the counter's line has no room for it (#1125). }
procedure HealMenu;
var
  list: Types.PItemRec;
  sel: Types.PItemRec;
  { the service each line sells; the line past the last is Exit }
  svcs: array[0..TS_LAST] of Byte;
  count: Byte;
  { Seeded True; MenuVertical draws the page and clears it. }
  redraw: Boolean;
  i: Byte;
  idx: Integer;
  done: Boolean;
  s: String[40];
  c: Char;
  { the windows around the list want drawing: at the start and after a member's items (Alt-n) took the screen }
  frame: Boolean;
begin
  done := False;
  count := 0;
  for i := 0 to TS_LAST do
    if TownCore.Offers(rules, i) then begin
      svcs[count] := i;
      Inc(count);
    end;
  list := nil;
  MenuCore.AllocStringList(count + 1, list);
  sel := list;
  i := 0;
  while list <> nil do begin
    if i < count then
      list^.name := TownCore.ServiceName(svcs[i])
    else
      list^.name := 'Exit';
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := sel;
  frame := True;
  { open on the first cure; MenuVertical also brings a verticalMenuTop left by an earlier menu back to it }
  idx := 0;
  repeat
    if frame then begin
      TextRend.ClearRect(0, 24, 39, 24);
      redraw := True;
      Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
      { the top divider row }
      Border.DrawWindow(1, 1, 38, 1, 0, White, '');
      frame := False;
    end;
    s := GameVars.curChar^.name + ', how can we help you?';
    TextRend.DisplayString(1, 1, White, s);
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
    { from row 3, the row under the divider: the twelve services and Exit fill rows 3..15 without a second page. Alt-n
      opens member n's items (ViewChar.AltItems, #1195), and member n is the patient when the list comes back. }
    MenuCore.memberKeysToCaller := True;
    c := MenuCore.MenuVertical('', 'Heal Repair Exit', promptColor, optionColor, commandColor, 2, 3, 38, 15, list,
                               False, redraw, idx, sel);
    case c of
      'H', C_KEYS.ENTER:
        if (idx >= 0) and (idx < count) then
          Temple.Serve(svcs[idx])
        else
          done := True;
      'R': Temple.RepairParty;
      C_KEYS.NONE: done := True;
    else
      if ViewChar.AltItems(c) then
        frame := True;
    end;
  until done;
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(0, 0, 39, 24);
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ TempleMainMenu: Run the temple counter (Shop.CounterMenu, on the shared treasure state) with HealMenu as its Heal
  command, at TempleRules' prices less what mode takes off (MoneyCal.TemplePrice). }
procedure TempleMainMenu(mode: Byte);
var
  i: Byte;
begin
  Temple.TempleRules(rules);
  for i := 0 to TS_LAST do
    if rules.price[i] > 0 then
      rules.price[i] := MoneyCal.TemplePrice(rules.price[i], mode);
  Shop.CounterMenu(True, Temple.HealMenu);
end;

end.
