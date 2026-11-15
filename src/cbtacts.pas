{ Combat movement, attacks, aiming and spell targeting. }
{$O+,F+}
{$I COMPILER.INC}
unit CbtActs;

interface

uses Types;

const
  { the most thrown weapons a fight notes for Retrieve Thrown; any after them stay in the loot }
  MAX_THROWN = 24;

type
  { a thrown weapon in the loot and the party member who threw it }
  TThrownItem = record
    item: Types.PItemRec;
    thrower: Types.PCharRecord;
  end;

var
  { suppress targeting }
  suppressTargeting: Byte;
  { the creatures (CbtMap.CombatSlot) seen casting a spell this fight: CastSpellCombat marks them and
    CombatSt.CombatStart clears it. A caster is what Silence is worth casting at (#1087). }
  seenCasting: set of Byte;
  hitsMade: array[1..2] of Byte;
  { Hostile creatures' hit points, percent remaining }
  hostileHpPct: Byte;
  { Done flag for the acting creature's attacks; combat menus also return their extended-key flag here }
  doneRoundFlag: Boolean;
  { the single thrown weapons that dropped into the loot this fight (GameVars.treasureItems), each with its thrower,
    for Retrieve Thrown (#1118): MakeAttack notes them (NoteThrown), CombatSt.CombatStart clears thrownCount, and
    PostCbt hands them back (ReturnThrown) }
  thrownCount: Byte;
  thrown: array[1..MAX_THROWN] of TThrownItem;

procedure BeginRound(creature: Types.PCharRecord);

function CalcCreatureMovement(creature: Types.PCharRecord): Byte;

procedure CombatMoveCreature(creature: Types.PCharRecord; dir: Byte);

procedure AttacksOfOpportunity(creature: Types.PCharRecord; dir: Byte);

{ One combat step in dir with what comes with it: the free attacks of the enemies the step leaves
  (AttacksOfOpportunity), then, while the mover is still up and not helpless, the step (CombatMoveCreature, where
  guarding enemies attack) and the clouds' checks (Stinking Cloud's, Cloudkill's). A mover that goes down or is left
  helpless on the way ends its actions, and True is returned: one paralysed, held or put to sleep by the free attacks
  does not take the step (POR-0216, #933). Combat's move menu and CombatAi's step share it. }
function StepCreature(creature: Types.PCharRecord; dir: Byte): Boolean;

{ Clear creature's flanking accumulators (flankCount, flankSpread): at the start of its turn and when it moves. }
procedure ResetFlanking(creature: Types.PCharRecord);

{ The direction a cursor key (an arrow, Home, End, Page Up or Page Down scan code) points, or C_DIR.CENTER for any other
  key: the steps of the combat move menu and of the aim cursor. }
function DirOfKey(ch: Char): Byte;

{ att attacks def, noted for flanking (NoteAttackDirection), with the item that does a ranged weapon's damage (its
  ammunition, or the thrown weapon itself; CharHlp.FindDamagingRangedWeapon), except that a throwable weapon used at
  distance 1 strikes as melee, with none. done is MakeAttack's. The aim menu and CombatAi's attack share it. }
procedure AttackWithReadied(att, def: Types.PCharRecord; var done: Boolean);

{ A weapon blow's damage: base (the dice and modifier) floored at 0, times mult (the backstab's multiplier, 1 for
  none), plus bonus (a ranger's level against a giant-class foe), held to 255. }
function WeaponDamage(base: Integer; mult, bonus: Byte): Byte;

{ The missiles left when used are taken from quantity: never below 0. }
function AmmoLeft(quantity, used: Byte): Byte;

function AttemptFlee(creature: Types.PCharRecord): Boolean;

procedure RecalcAttacksLeft(creature: Types.PCharRecord);

function SweepAttack(att, def: Types.PCharRecord): Boolean;

{ True when creature may aim at other: False for nil, True for itself. Without allowAlly a creature on creature's own
  side (hostile the same) is refused (#1137). Otherwise the target's veto effects run first, then the attacker's with
  other as its temporary target; any veto sets suppressTargeting. }
function CanTarget(creature, other: Types.PCharRecord; allowAlly: Boolean): Boolean;

{ True when the aim menu's Next and Prev step to other from creature (#1137): creature itself always; else one creature
  may target (CanTarget), and with Aim Cycles at ENEMIES (GameVars.aimEnemiesOn) only one of the other side, or with
  allies (a spell that is not offensive) only one of creature's own side. }
function AimCycles(creature, other: Types.PCharRecord; allies: Boolean): Boolean;

{ Note that thrower's single thrown weapon has dropped into the loot as item (the head of GameVars.treasureItems), for
  ReturnThrown. A party member's only, and only while thrown has room. }
procedure NoteThrown(thrower: Types.PCharRecord; item: Types.PItemRec);

{ Hand thrown weapon n (1..thrownCount) back to its thrower after the fight (#1118), when the item is still in the loot,
  the thrower is still in the party (alive or not: PoR's characters keep their items) and can carry it
  (ViewChar.CannotCarryItem). The loot's copy goes into the thrower's items (CharHlp.AddToInventory, which joins a
  stack under Auto Join) and leaves the loot; the copy is readied when the thrower's weapon hand is empty and the
  ready checks pass (hands, class). thrower and back are the creature and its copy (back nil once joined to a stack),
  and name the item's label (CharHlp.ItemLabel). False when it stays in the loot. }
function ReturnThrown(n: Byte; var thrower: Types.PCharRecord; var back: Types.PItemRec; var name: string): Boolean;

procedure CombatTurnUndead(creature: Types.PCharRecord);

function FindTurnUndeadTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;

procedure NoteAttackDirection(att, def: Types.PCharRecord);

procedure MakeAttack(att, def: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);

function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;

{ False when it is obvious that spell would do nothing to target, cast by caster (#1086). The combat AI weighs only what
  could be seen across the table: a creature's kind (undead, animated dead, a person by CharHlp.IsPerson, the snake),
  its visible conditions (already under the spell's effect, or helpless for a spell that leaves it so), and what it
  has done this fight (seenCasting); for the party's caster, too, the immunities the Bestiary has seen. Items, saving
  throws, resistances and the like are hidden, and never count. }
function SpellCanAffect(spell: Byte; target, caster: Types.PCharRecord): Boolean;

{ How many of GameVars.curChar's enemies cloud spell spell (Stinking Cloud, Cloudkill) aimed at cell (x, y) would
  usefully catch (SpellCanAffect): each creature once, in the cloud's block (CbtMap.CloudCell: Stinking Cloud's 2x2,
  the aim cell, E, SE, S; Cloudkill's 3x3 round the aim cell), on a cell the cloud can fill (terrain cost below 255).
  0 when the block holds anyone not of the enemy team. }
function CloudCatch(spell: Byte; x, y: ShortInt): Byte;

{ The best aim of spell for the creature acting (GameVars.curChar), among the enemies in its range (CbtMap.CountTargets)
  it may target (enabled, CbtActs.CanTarget): for an area spell (aiRadius > 0), the one whose area catches the most
  enemies spell can affect (SpellCanAffect) and no one else (AreaHitsNonEnemy; a cloud counts its own block,
  CloudCatch), ties at random; for any other, one at random of those spell can affect and not among
  GameVars.spellTargets already. count is how many it would affect: the area's catch, or those it can affect up to its
  count of targets (CharHlp.SpellArea). nil and 0 when none. }
function BestAim(spell: Byte; var count: Byte): Types.PCharRecord;

procedure SelectCombatTargets(spell: Byte; b: Boolean; var cast: Boolean);

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

function CheckAttackAlly(att, def: Types.PCharRecord): Boolean;

{ allies: a spell that is not offensive, whose Next and Prev step through the caster's own side (AimCycles). }
procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; allies: Boolean;
                        var done: Boolean; var tgt);

function DirTowardTarget(creature, other: Types.PCharRecord): Byte;

procedure UpdateHostileHpPercent;

function HighestEnemyMovement(creature: Types.PCharRecord): Byte;

function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;

procedure AttackClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

function VictoryCheat: Boolean;

{ Would an area spell aimed at cell (x, y) with walk budget radius catch anyone not on GameVars.curChar's enemy team?
  Rebuilds the target list around the aim point. }
function AreaHitsNonEnemy(x, y: ShortInt; radius: Byte): Boolean;

{ The spell-aim preview's count (CbtMap.aimReport, #840): line 23 shows the spell being aimed and who it will catch,
  caught (nearest first): how many of the caster's enemies and how many allies, the caster too, every spell the
  enemies first. Where a spell's rule (areaRules) says so, a side's count is followed by the most of it the spell may
  take: for Sleep, the most CharHlp.SleepMost finds over every pool the dice can roll. No immunity is shown or left out
  of a count: the creature counts as any other would. }
procedure ReportAreaCatch(var caught: Types.TSlotList);

{ Paladin leadership (#1124), as Death Knights of Krynn and Pools of Darkness have it. The base chance in 100 that a
  paladin of paladin level lvl leads an NPC: 20 at levels 1 to 3, 40 at 4 to 7, 80 from 8; 0 below level 1. }
function LeadershipBase(lvl: ShortInt): Byte;

{ The chance in 100 that paladin leads an NPC: LeadershipBase of its paladin level (CharHlp.GetClassLevel, so a
  dual-classed human's old paladin levels count once they are usable) plus 5 for each point of Charisma above 13. }
function LeadershipChance(paladin: Types.PCharRecord): Byte;

{ True when p can lead: one of the player's own characters (not an NPC) on the party's side, with a paladin level it
  can use, Okay and in action (enabled). }
function CanLead(p: Types.PCharRecord): Boolean;

{ True when p can be led: an NPC on the party's side, under the computer's control (quickfight), Okay and in action
  (enabled), with Intelligence above 3. An NPC a script gave the player (quickfight 0) is not, and stays as it is. }
function CanBeLed(p: Types.PCharRecord): Boolean;

{ paladin tries to lead npc with roll, a d100 roll: it does when roll is under LeadershipChance, and then npc comes
  under the player's control (quickfight 0) for this fight, marked in its combat record (led) so that
  PostCbt.PostCombatCreatureCleanup gives it back to the computer after it. Returns whether it led. The caller checks
  CanLead and CanBeLed. }
function TryLead(paladin, npc: Types.PCharRecord; roll: Byte): Boolean;

{ At the start of a fight, once the creatures have combat records (CombatSt.CombatStart): each paladin who CanLead
  tries to lead each NPC who CanBeLed and is not led yet, with a d100 roll. The first success opens a window titled
  "Using leadership ability", each success adds "<paladin> leads <NPC>." and the window waits for Enter; nothing is
  shown when none succeeds. In the demo (#1109) no one leads: a led NPC comes under the player, and no one plays. }
procedure UseLeadership;

implementation

uses C_ITEM, C_TERR, C_COND, GameDefs, GameVars, Crt, MenuCore, Magic, C_EFFECT, C_EQUIP, C_KEYS, C_LEVEL,
  C_STATUS, C_GBVM, C_DIR, C_SOUND, C_SPELL, C_SPRITE, Border, CbtMap, CharHlp, FxEngine, Pathing, SoundDrv, TextRend,
  StrUtil, CharDisp, AbilAdj, Dice, Blit, ClassCal, Bestiary, CbtLog, C_BEAST, Party, ViewChar, C_MSG,
  CbtMini, UiColor;

type
  { A spell's rule for the spell-aim count (#840): how it tells who the spell cannot affect, whatever the dice }
  TAreaRule = record
    spell: Byte;
    rule: Byte;
  end;
  { Who an aimed area spell catches on one side: how many, and the most of them it may take (Sleep), 0 for none }
  TSideTally = record
    count: Byte;
    most: Byte;
  end;
  { [True] the caster's enemies, [False] everyone else }
  TAreaTally = array[Boolean] of TSideTally;

var
  { Primary and secondary attack counts. }
  attacksMade: array[1..2] of Byte;
  { The spell the player is aiming, for ReportAreaCatch. }
  aimSpell: Byte;

const
  { The spell-aim count's rules: none, or Sleep's pool, which takes only so many. Curse, Secret and Pools keep their
    own table here. }
  RULE_NONE = 0;
  RULE_SLEEP = 1;
  areaRules: array[1..1] of TAreaRule = (
    (spell: C_SPELL.SLEEP; rule: RULE_SLEEP));

function AttacksFromRate(n: Byte): Byte; forward;

procedure ApplyRangePenalty(att, def: Types.PCharRecord; var defense: Byte); forward;

function IsBackstab(att, def: Types.PCharRecord): Boolean; forward;

procedure AnimateMissile(att, def: Types.PCharRecord; weapon: Types.PItemRec); forward;

{ Per-creature round reset: combat record flags, current attacks (RecalcAttacksLeft, then the secondary attacks through
  AttacksFromRate), the sweep budget, initiative (1d6 + missile dex adjustment, at least 1, -6 when surprised, 0 if
  disabled or outside 0..20) and movement. }
procedure BeginRound(creature: Types.PCharRecord);
begin
  with creature^.combatAddr^ do begin
    spellCast := 0;
    castAllowed := 1;
    itemUseAllowed := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GameVars.currentAttackCurrent := creature^.attacks2;
    GameVars.currentCreatureCalculatingFlag := 0;
    FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
    creature^.curAttacks2 := CbtActs.AttacksFromRate(GameVars.currentAttackCurrent);
    sweepBudget := creature^.attackLevel;
    if creature^.enabled <> 0 then begin
      initiative := Dice.RollDice(1, 6) + AbilAdj.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      { Surprise mask: bit 0 for the party, bit 1 for monsters }
      if Byte((creature^.hostile + 1) and Integer(GameVars.zone1^[C_GBVM.SURPRISE])) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  creature^.combatAddr^.movement := CbtActs.CalcCreatureMovement(creature);
end;

{ Calculate movement from the current speed plus, for the party, the GBVM movement modifier (values outside 1..96 become
  1), then let haste, slow and immobile effects adjust it. Return it in half-step units. }
function CalcCreatureMovement(creature: Types.PCharRecord): Byte;
var
  m: Byte;
begin
  m := creature^.movementCur;
  if creature^.hostile = 0 then
    m := m + GameVars.zone1^[C_GBVM.MOD_PARTY_MOVE];
  GameVars.currentCreatureCalculatingFlag := 1;
  if (m < 1) or (m > 96) then
    m := 1;
  GameVars.currentAttackCurrent := m * 2;
  FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
  GameVars.currentCreatureCalculatingFlag := 0;
  CalcCreatureMovement := GameVars.currentAttackCurrent;
end;

{ Roll attack idx's (1 or 2) current dice plus modifier into pendingDamage, multiply it on a backstab by the AD&D band
  for the thief level (x2 at 1-4, x3 at 5-8, x4 at 9-12), add the attacker's ranger level against a giant-class foe
  (GameDefs.rangerFoes) in melee, up to 255 (WeaponDamage), clear elementMask and fire the attacker's and defender's
  weapon-damage effect conditions. }
procedure CalcWeaponDamage(att, def: Types.PCharRecord; idx: Byte);
var
  i: Byte;
  mult: Byte;
  bonus: Byte;
begin
  mult := 1;
  if CbtActs.IsBackstab(att, def) then
    { (level + 3) div 4 + 1 is (level - 1) div 4 + 2 without the underflow at level 0 }
    mult := (Word(CharHlp.GetClassLevel(att, C_LEVEL.THIEF_BIT)) + 3) div 4 + 1;
  bonus := 0;
  if (CharHlp.GetClassLevel(att, C_LEVEL.RANGER_BIT) > 0) and (CbtMap.CalcDistance(att, def) <= 1) then
    for i := 1 to SizeOf(GameDefs.rangerFoes) div SizeOf(GameDefs.rangerFoes[1]) do
      if def^.name = GameDefs.rangerFoes[i] then
        bonus := CharHlp.GetClassLevel(att, C_LEVEL.RANGER_BIT);
  GameVars.pendingDamage := CbtActs.WeaponDamage(att^.curModA[idx] +
                                                 Dice.RollDamageDice(att^.curRollsA[idx], att^.curDiceA[idx]),
                                                 mult, bonus);
  GameVars.elementMask := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.WEAPON_DAMAGE_ATT, att);
  FxEngine.TriggerEffectsWithCondition(C_COND.WEAPON_DAMAGE_DEF, def);
end;

{ Worked in a LongInt: SSI's Byte wrapped a backstab's product past 255, so a x5 backstab of 52 did 4. }
function WeaponDamage(base: Integer; mult, bonus: Byte): Byte;
var
  d: LongInt;
begin
  d := base;
  if d < 0 then
    d := 0;
  d := d * mult + bonus;
  if d > 255 then
    d := 255;
  WeaponDamage := d;
end;

function AmmoLeft(quantity, used: Byte): Byte;
begin
  if quantity > used then
    AmmoLeft := quantity - used
  else
    AmmoLeft := 0;
end;

{ Print the attack message and inflict the damage (dmg = inflicted, dmgDisp = displayed). atkType: 1 = from behind, 2 =
  backstab, 3 = slays a helpless target, else a plain attack. Any damage cancels the defender's casting for the round
  and loses a spell being cast; a defender that goes down gets its hp-0 effects and, if still disabled,
  CbtMap.CreatureDowned. The attack and its result are one combat log message (#841). A monster's hit on a party
  member, but for slaying it helpless, is the Bestiary's most damage in a blow if it is more (#842). }
procedure ProcessAttackResult(att, def: Types.PCharRecord; atkType, dmg, dmgDisp: Byte; isHit: Boolean);
var
  row: Byte;
  verb: String[80];
begin
  case atkType of
    2: verb := '-Backstabs-';
    3: verb := 'slays helpless';
  else
    verb := 'Attacks';
  end;
  CharDisp.PrintNameString(att, verb, 10, False);
  row := 12;
  CharDisp.LogCreatureName(def);
  if atkType = 1 then
    verb := '(from behind) '
  else
    verb := '';
  if isHit then begin
    if atkType = 3 then
      verb := 'with one cruel blow'
    else begin
      verb := verb + 'Hitting for ' + StrUtil.Count(dmgDisp, 'point', 'points') + ' of damage';
    end;
    CharHlp.InflictDamage(def, dmg);
    { slaying the helpless is no measure of a blow }
    if atkType <> 3 then
      Bestiary.LearnBlow(att, def, dmg);
  end else
    verb := verb + 'and Misses';
  CbtLog.NextLine;
  CbtLog.Add(LightGreen, verb);
  CharDisp.PrintNameLine(def, verb, row);
  row := GameVars.curRow + 1;
  if dmg > 0 then begin
    def^.combatAddr^.castAllowed := 0;
    if def^.combatAddr^.spellCast > 0 then begin
      TextRend.PauseOnly;
      CharDisp.PrintNameString(def, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(def, def^.combatAddr^.spellCast);
      def^.combatAddr^.spellCast := 0;
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if def^.enabled = 0 then begin
    CharDisp.PrintNameString(def, 'goes down', row, False);
    Inc(row, 2);
    if def^.status = C_STATUS.DYING then begin
      CbtLog.NextLine;
      CbtLog.Add(LightGreen, 'and is Dying');
      CharDisp.PrintMsgTail('and is Dying', LightGreen, row);
    end;
    if def^.status in [C_STATUS.DEAD_STATUS, C_STATUS.STONED, C_STATUS.GONE] then
      CharDisp.PrintNameString(def, 'is killed', row, False);
    FxEngine.RemoveEffectsHp0(def);
    FxEngine.TriggerEffectsWithCondition(C_COND.HP_ZERO, def);
    if def^.enabled = 0 then
      CbtMap.CreatureDowned(def)
    else
      TextRend.PauseOnly;
  end;
  CharDisp.ClearMessageWindow;
end;

{ Each adjacent enemy that is guarding and not helpless spends its guard on a free attack against the mover. }
procedure GuardersAttack(creature: Types.PCharRecord);
var
  cnt: Byte;
  i: Byte;
  p: Types.PCharRecord;
  done: Boolean;
begin
  cnt := CbtMap.CountTargets(creature, 1);
  for i := 1 to cnt do
    if creature^.enabled <> 0 then begin
      p := GameVars.creatureArr[GameVars.combatTargetSlots[i]];
      if (p^.combatAddr^.guarding <> 0) and (not CharHlp.IsHelpless(p)) then begin
        CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_DIR.CENTER);
        p^.combatAddr^.guarding := 0;
        CbtActs.NoteAttackDirection(p, creature);
        CbtActs.MakeAttack(p, creature, False, nil, done);
      end;
    end;
end;

{ One step in dir: pay 2 half-moves (3 on a diagonal; with too few left, movement drops to 0 and nothing moves), move
  the icon, reset the flanking accumulators and let guarding enemies attack. A mover left disabled or helpless loses the
  rest of its movement. }
procedure CombatMoveCreature(creature: Types.PCharRecord; dir: Byte);
var
  cost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  if Odd(dir) then
    cost := 3
  else
    cost := 2;
  if cost > creature^.combatAddr^.movement then begin
    creature^.combatAddr^.movement := 0;
    Exit;
  end;
  Dec(creature^.combatAddr^.movement, cost);
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then begin
    { not on the map: nothing to move }
    creature^.combatAddr^.movement := 0;
    Exit;
  end;
  x := GameVars.arenaLoc[slot].x;
  y := GameVars.arenaLoc[slot].y;
  nx := x + GameDefs.dirDX[dir];
  ny := y + GameDefs.dirDY[dir];
  { cost is reused as the ScrollView delta: 1 under manual control, 3 under quickfight }
  cost := 1;
  if creature^.quickfight <> 0 then begin
    cost := 3;
    if not CbtMap.ViewCoordsValid(nx - GameVars.arenaPtr^.ox, ny - GameVars.arenaPtr^.oy) then
      CbtMap.ScrollView(x, y, 2, C_DIR.CENTER);
  end;
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  GameVars.arenaLoc[slot].x := nx;
  GameVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(nx, ny, cost, C_DIR.CENTER);
  CbtActs.ResetFlanking(creature);
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.STEP], C_SOUND.GROUP_FOOTSTEPS);
  CbtActs.GuardersAttack(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0;
end;

{ Enemies adjacent before a step in dir but not after it get one free attack on the mover, made as from behind.
  Helpless, effect-vetoed, blood-draining and bite-holding enemies are skipped. An enemy with no initiative left that
  has already been attacked this round (flankCount > 0) attacks only if the mover is in its 5-direction front cone. The
  free attack is one attack and costs the enemy nothing: MakeAttack would spend every attack it has left and end its
  turn, so its attacks, phase, turn state and sweep (madeAttack, sweepBudget) are put back afterwards while it is still
  up (#711, #770). Its special attacks (breath, gaze, acid) still come at the start of its own move
  (CombatAi.AiMoveAttack). }
procedure AttacksOfOpportunity(creature: Types.PCharRecord; dir: Byte);
var
  adj: array[1..12] of Byte;
  effect: Types.PEffectRec;
  still: Boolean;
  attacked: Boolean;
  slot: Byte;
  cntBefore: Byte;
  cntAfter: Byte;
  j: Byte;
  i: Byte;
  k: Byte;
  phase: Byte;
  a: Byte;
  p: Types.PCharRecord;
  savedOther: Types.PCharRecord;
  savedAtt: array[1..2] of Byte;
  savedPhase: Byte;
  savedInit: ShortInt;
  savedSpell: Byte;
  savedGuard: Byte;
  savedMove: Byte;
  savedMade: Byte;
  savedSweep: Byte;
begin
  FillChar(adj, SizeOf(adj), 0);
  slot := CbtMap.CombatSlot(creature);
  { not on the map: no step to probe }
  if slot = 0 then
    Exit;
  cntBefore := CbtMap.CountTargets(creature, 1);
  if cntBefore = 0 then
    Exit;
  for i := 1 to cntBefore do
    adj[i] := GameVars.combatTargetSlots[i];
  { probe: step the icon, recount, step back }
  Inc(GameVars.arenaLoc[slot].x, GameDefs.dirDX[dir]);
  Inc(GameVars.arenaLoc[slot].y, GameDefs.dirDY[dir]);
  cntAfter := CbtMap.CountTargets(creature, 1);
  Dec(GameVars.arenaLoc[slot].x, GameDefs.dirDX[dir]);
  Dec(GameVars.arenaLoc[slot].y, GameDefs.dirDY[dir]);
  { enemies still adjacent after the step get no free attack }
  for i := 1 to cntBefore do begin
    still := False;
    for j := 1 to cntAfter do
      if GameVars.combatTargetSlots[j] = adj[i] then
        still := True;
    if still then
      adj[i] := 0;
  end;
  for i := 1 to cntBefore do
    if adj[i] > 0 then
      if creature^.enabled <> 0 then begin
        attacked := False;
        p := GameVars.creatureArr[adj[i]];
        if not CharHlp.IsHelpless(p) then
          if CbtActs.CanTarget(p, creature, True) then
            if not CharHlp.HasEffect(p, C_EFFECT.BLOOD_DRAIN, effect) then
              if not CharHlp.HasEffect(p, C_EFFECT.BITE_HOLD, effect) then
                for a := p^.combatAddr^.direction + 6 to p^.combatAddr^.direction + 10 do
                  if not attacked then
                    if (p^.combatAddr^.initiative > 0) or (p^.combatAddr^.flankCount = 0) or
                        Pathing.IsDirToward(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), CbtMap.CombatCellX(creature),
                                            CbtMap.CombatCellY(creature), a mod 8) then begin
                      phase := 1;
                      if p^.attacks = 0 then
                        phase := 2;
                      { 2 = curAtt's upper bound }
                      for k := 1 to 2 do
                        if Types.PAttackPhaseView(p)^.curAtt[k] > 0 then
                          phase := k;
                      savedAtt[1] := Types.PAttackPhaseView(p)^.curAtt[1];
                      savedAtt[2] := Types.PAttackPhaseView(p)^.curAtt[2];
                      savedPhase := p^.combatAddr^.attackPhase;
                      savedInit := p^.combatAddr^.initiative;
                      savedSpell := p^.combatAddr^.spellCast;
                      savedGuard := p^.combatAddr^.guarding;
                      savedMove := p^.combatAddr^.movement;
                      savedMade := p^.combatAddr^.madeAttack;
                      savedSweep := p^.combatAddr^.sweepBudget;
                      { exactly one attack, in that phase }
                      Types.PAttackPhaseView(p)^.curAtt[1] := 0;
                      Types.PAttackPhaseView(p)^.curAtt[2] := 0;
                      Types.PAttackPhaseView(p)^.curAtt[phase] := 1;
                      p^.combatAddr^.attackPhase := phase;
                      savedOther := p^.combatAddr^.other;
                      CbtActs.MakeAttack(p, creature, True, nil, doneRoundFlag);
                      attacked := True;
                      p^.combatAddr^.other := savedOther;
                      if p^.enabled <> 0 then begin
                        Types.PAttackPhaseView(p)^.curAtt[1] := savedAtt[1];
                        Types.PAttackPhaseView(p)^.curAtt[2] := savedAtt[2];
                        p^.combatAddr^.attackPhase := savedPhase;
                        p^.combatAddr^.initiative := savedInit;
                        p^.combatAddr^.spellCast := savedSpell;
                        p^.combatAddr^.guarding := savedGuard;
                        p^.combatAddr^.movement := savedMove;
                        p^.combatAddr^.madeAttack := savedMade;
                        p^.combatAddr^.sweepBudget := savedSweep;
                      end;
                      if creature^.enabled <> 0 then
                        CharDisp.CombatPrintCreatureInfo(creature);
                    end;
      end;
end;

function StepCreature(creature: Types.PCharRecord; dir: Byte): Boolean;
var
  done: Boolean;
begin
  done := False;
  CbtActs.AttacksOfOpportunity(creature, dir);
  { a mover the free attacks leave down or helpless neither steps nor acts again this turn (POR-0216, #933) }
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    done := CharHlp.EndActions(creature)
  else begin
    CbtActs.CombatMoveCreature(creature, dir);
    if creature^.enabled = 0 then
      done := CharHlp.EndActions(creature);
    FxEngine.ConsiderStinkingCloud(creature);
    { a Cloudkill that kills the mover ends its turn }
    if creature^.enabled <> 0 then begin
      Magic.ConsiderCloudkill(creature);
      if creature^.enabled = 0 then
        done := CharHlp.EndActions(creature);
    end;
    { helpless after the step (a guarding enemy's blow, the cloud): the turn ends }
    if CharHlp.IsHelpless(creature) then
      done := CharHlp.EndActions(creature);
  end;
  StepCreature := done;
end;

procedure ResetFlanking(creature: Types.PCharRecord);
begin
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
end;

{ Flee: automatic when the target list (range 255) holds no enemy; otherwise it succeeds when the creature's movement in
  whole moves beats the fastest enemy's (HighestEnemyMovement), on 1 in 2 when they tie. Success takes it out of play as
  'Got Away' (C_STATUS.RUNNING). EndActions runs on both outcomes and supplies the result. }
function AttemptFlee(creature: Types.PCharRecord): Boolean;
var
  ok: Boolean;
  enemyMove: Byte;
  halfMove: Byte;
begin
  ok := False;
  if CbtMap.CountTargets(creature, 255) = 0 then
    ok := True
  else begin
    halfMove := CbtActs.CalcCreatureMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < halfMove then
      ok := True
    else if enemyMove = halfMove then
      if Dice.RollDice(1, 2) = 1 then
        ok := True;
  end;
  if ok then
    FxEngine.PutOutOfPlayWithStatus(creature, C_STATUS.RUNNING, 'Got Away')
  else
    CharDisp.PrintActionLine(creature, 'Escape is blocked', 'is blocked from escaping');
  AttemptFlee := CharHlp.EndActions(creature);
end;

{ Set curAttacks for the round. Start from the weapon's rate of fire (at least 2) for a damaging ranged weapon, else the
  base attacks, both in half-attacks; apply haste/slow effects, then AttacksFromRate (odd rounds round up, then halve)
  and cap a ranged weapon by its ammunition. Once an attack has been made the result is used only when it is below the
  previous curAttacks (melee: below twice it); otherwise curAttacks keeps the previous value. }
procedure RecalcAttacksLeft(creature: Types.PCharRecord);
var
  adj: Byte;
  saved: Byte;
  qty: Byte;
  rof: Byte;
  ranged: Boolean;
  weapon: Types.PItemRec;
begin
  ranged := False;
  saved := creature^.curAttacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rof := CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.rateOfFire;
    if rof < 2 then
      rof := 2;
    GameVars.currentAttackCurrent := rof;
  end else
    GameVars.currentAttackCurrent := creature^.attacks;
  GameVars.currentCreatureCalculatingFlag := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, creature);
  adj := CbtActs.AttacksFromRate(GameVars.currentAttackCurrent);
  if ranged and (weapon <> nil) then begin
    qty := 1;
    if weapon^.quantity > qty then
      qty := weapon^.quantity;
    if qty < adj then
      { ammo-limited }
      adj := qty;
  end;
  if (creature^.combatAddr^.madeAttack = 0) or (adj < saved)
     or ((creature^.combatAddr^.madeAttack <> 0) and (adj < saved * 2) and (not ranged)) then
    creature^.curAttacks := adj;
end;

{ Half-attacks to attacks: add 1 on odd rounds, then halve. }
function AttacksFromRate(n: Byte): Byte;
var
  v: Byte;
begin
  v := n;
  if Odd(GameVars.roundCounter) then
    Inc(v);
  AttacksFromRate := v div 2;
end;

{ Sweep sub-1-HD foes: when def is an adjacent level-0 foe, the sweep budget (attack level) exceeds the current attacks
  and more adjacent level-0 enemies stand around than there are current attacks, make one attack on each of up to
  sweepBudget of them, def first, while att stays up. Returns True if it swept. }
function SweepAttack(att, def: Types.PCharRecord): Boolean;
var
  cnt: Byte;
  weak: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PCharRecord;
begin
  SweepAttack := False;
  if att^.curAttacks >= att^.combatAddr^.sweepBudget then
    Exit;
  if def^.levelHighest <> 0 then
    Exit;
  if CbtMap.CalcDistance(att, def) <> 1 then
    Exit;
  cnt := CbtMap.CountTargets(att, 1);
  weak := 0;
  defIdx := 0;
  for i := 1 to cnt do begin
    p := GameVars.creatureArr[GameVars.combatTargetSlots[i]];
    if p = def then
      defIdx := i;
    if p^.levelHighest = 0 then
      Inc(weak);
  end;
  { def is not in the enemy list (an ally, such as an animated corpse): no sweep }
  if defIdx = 0 then
    Exit;
  if weak <= att^.curAttacks then
    Exit;
  if weak > att^.combatAddr^.sweepBudget then
    weak := att^.combatAddr^.sweepBudget;
  CharDisp.PrintNameString(att, 'sweeps', 10, True);
  { def becomes the first sweep target }
  p := GameVars.creatureArr[GameVars.combatTargetSlots[1]];
  if p <> def then begin
    GameVars.combatTargetSlots[defIdx] := GameVars.combatTargetSlots[1];
    GameVars.combatTargetSlots[1] := CbtMap.CombatSlot(def);
  end;
  { a sweeper that goes down stops }
  for i := 1 to cnt do
    if (weak > 0) and (att^.enabled <> 0) then
      if GameVars.creatureArr[GameVars.combatTargetSlots[i]]^.levelHighest = 0 then begin
        p := GameVars.creatureArr[GameVars.combatTargetSlots[i]];
        CbtActs.NoteAttackDirection(att, p);
        att^.curAttacks := 1;
        CbtActs.MakeAttack(att, p, False, nil, doneRoundFlag);
        Dec(weak);
      end;
  SweepAttack := True;
end;

function CanTarget(creature, other: Types.PCharRecord; allowAlly: Boolean): Boolean;
var
  saved: Types.PCharRecord;
begin
  CanTarget := False;
  if other = nil then
    Exit;
  if creature = other then begin
    CanTarget := True;
    Exit;
  end;
  if not allowAlly and (other^.hostile = creature^.hostile) then
    Exit;
  suppressTargeting := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.TARGET_VETO, other);
  if suppressTargeting = 0 then begin
    saved := creature^.combatAddr^.other;
    creature^.combatAddr^.other := other;
    FxEngine.TriggerEffectsWithCondition(C_COND.ATTACKER_VETO, creature);
    creature^.combatAddr^.other := saved;
  end;
  CanTarget := suppressTargeting = 0;
end;

function AimCycles(creature, other: Types.PCharRecord; allies: Boolean): Boolean;
begin
  if (other = nil) or (creature = other) then
    AimCycles := other <> nil
  else if GameVars.aimEnemiesOn = 0 then
    AimCycles := CbtActs.CanTarget(creature, other, True)
  else if allies then
    AimCycles := (other^.hostile = creature^.hostile) and CbtActs.CanTarget(creature, other, True)
  else
    AimCycles := CbtActs.CanTarget(creature, other, False);
end;

procedure NoteThrown(thrower: Types.PCharRecord; item: Types.PItemRec);
begin
  if (thrower^.hostile <> 0) or (thrownCount >= MAX_THROWN) then Exit;
  Inc(thrownCount);
  thrown[thrownCount].item := item;
  thrown[thrownCount].thrower := thrower;
end;

function ReturnThrown(n: Byte; var thrower: Types.PCharRecord; var back: Types.PItemRec; var name: string): Boolean;
var
  item: Types.PItemRec;
  prev: Types.PItemRec;
  p: Types.PCharRecord;
  last: Types.PItemRec;
  saved: Types.PCharRecord;
  base: Types.PBaseItemRec;
begin
  ReturnThrown := False;
  back := nil;
  name := '';
  item := thrown[n].item;
  thrower := thrown[n].thrower;
  { still in the loot: prev is the node before it, nil for the head }
  prev := nil;
  if GameVars.treasureItems <> item then begin
    prev := GameVars.treasureItems;
    while (prev <> nil) and (prev^.next <> item) do
      prev := prev^.next;
    if prev = nil then Exit;
  end;
  { still in the party }
  p := GameVars.creatureList;
  while (p <> nil) and (p <> thrower) do
    p := p^.nextCharAddr;
  if (p = nil) or (thrower^.hostile <> 0) then Exit;
  if ViewChar.CannotCarryItem(thrower, item) then Exit;
  CharHlp.ItemLabel(item, False);
  name := item^.name;
  last := thrower^.itemsAddr;
  while (last <> nil) and (last^.next <> nil) do
    last := last^.next;
  CharHlp.AddToInventory(thrower, item);
  { the copy is the last item, unless it joined a stack whole }
  back := thrower^.itemsAddr;
  while (back <> nil) and (back^.next <> nil) do
    back := back^.next;
  if back = last then
    back := nil;
  { out of the loot; DetermineLootExp has read lastMissileItem already, and it moves on with the list }
  if prev = nil then
    GameVars.treasureItems := item^.next
  else
    prev^.next := item^.next;
  if GameVars.lastMissileItem = item then
    GameVars.lastMissileItem := item^.next;
  item^.next := nil;
  FreeMem(item, SizeOf(Types.TItemRec));
  CharHlp.RecalcStats(thrower);
  if back <> nil then begin
    back^.equipped := 0;
    base := CharHlp.BaseItem(back^.itemType);
    if (thrower^.equipped[C_EQUIP.WEAPON] = nil) and (base^.slot = C_EQUIP.WEAPON) and
       (thrower^.handsEquipped + base^.hands <= 2) and (base^.classMask and thrower^.itemLimits <> 0) then begin
      { ToggleReadyItem readies GameVars.curChar's item, with its effect }
      saved := GameVars.curChar;
      GameVars.curChar := thrower;
      FxEngine.ToggleReadyItem(back);
      GameVars.curChar := saved;
      CharHlp.RecalcStats(thrower);
    end;
  end;
  ReturnThrown := True;
end;

{ Turn undead at ClassCal.TurnLevel: one d20 roll against the turning table (ClassCal.TurnValue), applied to up to 1d12
  targets (lowest-level undead first) until a target resists. A negative value extends exhausted attempts until six
  successes. }
procedure CombatTurnUndead(creature: Types.PCharRecord);
var
  roll: Byte;
  attempts: Byte;
  destroys: Byte;
  turnVal: ShortInt;
  any: Boolean;
  stop: Boolean;
  tgt: Pointer;
  lvl: ShortInt;
begin
  CharDisp.PrintNameString(creature, 'turns undead...', 10, False);
  TextRend.ClearBottomLine;
  TextRend.PauseOnly;
  any := False;
  stop := False;
  creature^.combatAddr^.usedTurnUndead := 1;
  destroys := 6;
  attempts := Dice.RollDice(1, 12);
  roll := Dice.RollDice(1, 20);
  lvl := ClassCal.TurnLevel(creature);
  while CbtActs.FindTurnUndeadTarget(creature, tgt) and (attempts > 0)
        and (stop = False) do begin
    { FindTurnUndeadTarget admits undead levels up to 12; TurnValue reads those above 10 from row 10 }
    turnVal := ClassCal.TurnValue(Types.PCharRecord(tgt)^.levelUndead, lvl);
    if roll >= Abs(turnVal) then begin
      any := True;
      CbtMap.DisplayMapViewCentered(Types.PCharRecord(tgt), 3, False);
      CharDisp.CombatPrintCreatureInfo(Types.PCharRecord(tgt));
      if turnVal > 0 then begin
        Types.PCharRecord(tgt)^.combatAddr^.turned := 1;
        CharDisp.PrintNameStringAnim(Types.PCharRecord(tgt), True, 'is turned');
      end else begin
        CharDisp.PrintNameString(Types.PCharRecord(tgt), 'Is destroyed', 10, False);
        CbtMap.CreatureDowned(Types.PCharRecord(tgt));
        Types.PCharRecord(tgt)^.status := C_STATUS.GONE;
        Types.PCharRecord(tgt)^.enabled := 0;
      end;
      if destroys > 0 then
        Dec(destroys);
      Dec(attempts);
      if attempts = 0 then
        if destroys > 0 then
          if turnVal < 0 then
            { extend while below six successes }
            Inc(attempts);
      CharDisp.ClearMessageWindow;
    end else
      stop := True;
  end;
  if not any then
    CharDisp.PrintBottomLine('Nothing Happens...');
  CharHlp.CountTeams;
  doneRoundFlag := CharHlp.EndActions(creature);
  CharDisp.ClearMessageWindow;
end;

{ The lowest-level unturned undead in the target list (any range); equal levels keep the earlier, nearer one. }
function FindTurnUndeadTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  cnt: Byte;
  i: Byte;
  best: ShortInt;
  p: Types.PCharRecord;
begin
  best := 13;
  tgt := nil;
  cnt := CbtMap.CountTargets(creature, 255);
  FindTurnUndeadTarget := False;
  for i := 1 to cnt do begin
    p := GameVars.creatureArr[GameVars.combatTargetSlots[i]];
    if (p^.combatAddr^.turned = 0) and (p^.levelUndead > 0)
       and (p^.levelUndead < best) then begin
      best := p^.levelUndead;
      tgt := p;
      FindTurnUndeadTarget := True;
    end;
  end;
end;

{ Resolve att's remaining attacks on def. A helpless defender is slain with one blow (hp + 5 damage) and all attacks are
  spent. Otherwise use the large-target dice against a large defender and pick the defense: backstab, acBehind - 2; from
  behind (fromBehind, or flanked by more than one attacker with att at its back and a flank spread above 4), the rear
  AC. Add range penalties, roll the attacks from attackPhase down to 1 until def drops, and spend the sweep budget. A
  hit on a defender with Mirror Image (C_EFFECT.MIRROR_IMAGE) strikes an image unless 1d(images + 1) rolls 1: it shows
  as a miss, the defender loses the image and the blow does no damage and has no on-hit effects. With no attacks left,
  att's actions end. The blows' sounds are of the Settings screen's ranged kind for a ranged attack, else melee. A
  party member's armed blow shows the Bestiary whether def is Large, and each roll from the front narrows def's armor
  class there (#842). }
procedure RollAttacks(att, def: Types.PCharRecord; fromBehind, ranged: Boolean; var done: Boolean);
var
  base: Types.TBaseItemRec;
  anyHit: Boolean;
  defDowned: Boolean;
  behind: Boolean;
  defense: Byte;
  phase: Byte;
  startPhase: Byte;
  atkType: Byte;
  behindIdx: ShortInt;
  image: Types.PEffectRec;
  slay: Byte;
  { the Settings screen's kind for the blows' sounds }
  group: Byte;
  { the attack roll hit }
  rolled: Boolean;
  backstab: Boolean;
begin
  if ranged then
    group := C_SOUND.GROUP_RANGED
  else
    group := C_SOUND.GROUP_MELEE;
  behind := fromBehind;
  done := False;
  hitsMade[1] := 0;
  hitsMade[2] := 0;
  attacksMade[1] := 0;
  attacksMade[2] := 0;
  anyHit := False;
  defDowned := False;
  GameVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.IMPACT], group);
    { phase 1 is curAtt's lower bound }
    while (att^.combatAddr^.attackPhase > 1)
          and (Types.PAttackPhaseView(att)^.curAtt[att^.combatAddr^.attackPhase] = 0) do
      Dec(att^.combatAddr^.attackPhase);
    Inc(attacksMade[att^.combatAddr^.attackPhase]);
    { hp + 5, held to the Byte }
    if def^.hpCur > 250 then
      slay := 255
    else
      slay := def^.hpCur + 5;
    CbtActs.ProcessAttackResult(att, def, 3, slay, 1, True);
    FxEngine.RemoveInvisibility(att);
    { 2 = curAtt's upper bound }
    for phase := 1 to 2 do
      Types.PAttackPhaseView(att)^.curAtt[phase] := 0;
    anyHit := True;
    done := True;
  end else begin
    if (att^.equipped[C_EQUIP.WEAPON] <> nil) and (def^.iconDimensions and Types.ICON_LARGE <> 0) then begin
      { large target: swap in the large-damage dice. SSI's took any creature with a two-tile icon for Large, so wolves,
        wild boars and basilisks took them (#748). }
      base := CharHlp.BaseItem(att^.equipped[C_EQUIP.WEAPON]^.itemType)^;
      att^.curRollsA[1] := base.dmgLgRolls;
      att^.curDiceA[1] := base.dmgLgDice;
      att^.curModA[1] := att^.curModA[1] - base.dmgSmMod + base.dmgLgMod;
    end;
    if att^.equipped[C_EQUIP.WEAPON] <> nil then
      Bestiary.LearnSize(def, att, def^.iconDimensions and Types.ICON_LARGE <> 0);
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(C_COND.DEFENDER_AC, def);
    behindIdx := 0;
    backstab := CbtActs.IsBackstab(att, def);
    if backstab then
      defense := def^.acBehind - 2
    else begin
      if def^.combatAddr^.flankCount > 1 then
        if (CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction)
           and (def^.combatAddr^.flankSpread > 4) then
          behind := True;
      if behind then
        behindIdx := 1;
      defense := Types.PAttackPhaseView(def)^.acCurArr[behindIdx];
    end;
    CbtActs.ApplyRangePenalty(att, def, defense);
    atkType := 0;
    if behind then
      atkType := 1;
    if backstab then
      atkType := 2;
    startPhase := att^.combatAddr^.attackPhase;
    { the downto's own entry guard covers startPhase < 1 }
    for phase := startPhase downto 1 do
      while (Types.PAttackPhaseView(att)^.curAtt[phase] > 0)
            and (defDowned = False) do begin
        Dec(Types.PAttackPhaseView(att)^.curAtt[phase]);
        att^.combatAddr^.attackPhase := phase;
        Inc(attacksMade[phase]);
        rolled := FxEngine.AttackRoll(att, def, defense);
        { the roll against the front armor, without the range's penalty }
        if atkType = 0 then
          Bestiary.LearnArmor(def, att, GameVars.gAttackRoll + FxEngine.HitBonus(att) -
                              (Integer(defense) - Types.PAttackPhaseView(def)^.acCurArr[0]), rolled);
        if rolled or CharHlp.IsHelpless(def) then begin
          anyHit := True;
          if CharHlp.HasEffect(def, C_EFFECT.MIRROR_IMAGE, image) and FxEngine.ImageStruck(image) then begin
            { the blow strikes an image }
            SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.MISS], group);
            CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
            FxEngine.LoseImage(def, image);
          end else begin
            Inc(hitsMade[phase]);
            SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.IMPACT], group);
            CbtActs.CalcWeaponDamage(att, def, phase);
            CbtActs.ProcessAttackResult(att, def, atkType, GameVars.pendingDamage, GameVars.pendingDamage, True);
            if def^.enabled <> 0 then
              FxEngine.TriggerEffectsWithCondition(C_COND.HIT_PHASE_1 + phase - 1, att);
            if def^.enabled = 0 then
              defDowned := True;
          end;
        end;
      end;
    if not anyHit then begin
      SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.MISS], group);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    { 2 = curAtt's upper bound }
    for phase := 1 to 2 do
      if Types.PAttackPhaseView(att)^.curAtt[phase] > 0 then
        done := False;
    { sweep budget spent }
    att^.combatAddr^.sweepBudget := 0;
  end;
  if done then
    done := CharHlp.EndActions(att);
end;

{ The flanking accumulator: count attacks on def (flankCount) and add each attacker's angular offset from def's facing
  (0..4) into flankSpread (mod 8). RollAttacks's from-behind test and IsBackstab read them; they reset when def moves
  and at the start of its turn. }
procedure NoteAttackDirection(att, def: Types.PCharRecord);
var
  rel: Byte;
  d: Byte;
begin
  Inc(def^.combatAddr^.flankCount);
  d := CbtActs.DirTowardTarget(def, att);
  rel := (d - def^.combatAddr^.direction + 8) mod 8;
  if rel > 4 then
    rel := 8 - rel;
  def^.combatAddr^.flankSpread := (def^.combatAddr^.flankSpread + rel) mod 8;
end;

{ The public attack wrapper. def turns to face att (unless fromBehind or already attacked three times) and att turns and
  animates, with a missile flight for weapon and for an equipped sling. If attacks remain, RollAttacks runs; weapon (the
  missile or thrown item, nil for melee) then loses attacksMade[1] from its quantity, and once used up it is removed, an
  expended thrown weapon other than a spirit hammer dropping into the treasure pile. }
procedure MakeAttack(att, def: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec; var done: Boolean);
var
  item: Types.PItemRec;
  savedCur: Types.PCharRecord;
  dir: Byte;
  { a missile or thrown weapon, or an equipped sling: the attack is ranged }
  ranged: Boolean;
begin
  ranged := weapon <> nil;
  if (def^.combatAddr^.flankCount < 3) and (not fromBehind) then begin
    dir := CbtActs.DirTowardTarget(def, att);
    if CbtMap.CombatIconVisible(def, 0) then
      CbtMap.SetCreatureFacing(def, dir, 0, 0)
    else
      def^.combatAddr^.direction := dir;
  end;
  dir := CbtActs.DirTowardTarget(att, def);
  CharDisp.CombatPrintCreatureInfo(att);
  CbtMap.SetCreatureFacing(att, dir, 1, 0);
  att^.combatAddr^.other := def;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(att, def, weapon);
  { a sling's stone animates a second time }
  if (att^.equipped[C_EQUIP.WEAPON] <> nil) and (att^.equipped[C_EQUIP.WEAPON]^.itemType = C_ITEM.SLING) then begin
    CbtActs.AnimateMissile(att, def, att^.equipped[C_EQUIP.WEAPON]);
    ranged := True;
  end;
  done := True;
  if (att^.curAttacks > 0) or (att^.curAttacks2 > 0) then begin
    savedCur := GameVars.curChar;
    GameVars.curChar := att;
    CbtActs.RollAttacks(att, def, fromBehind, ranged, done);
    if weapon <> nil then begin
      { a quantity of 0 is a single item, thrown and gone }
      weapon^.quantity := CbtActs.AmmoLeft(weapon^.quantity, attacksMade[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(att) and (weapon^.special <> C_EFFECT.SPIRIT_HAMMER_GONE) then begin
          { the expended thrown weapon drops into the loot pile }
          CharHlp.PrependItemCopy(GameVars.treasureItems, weapon);
          item := GameVars.treasureItems;
          item^.equipped := 0;
          CharHlp.RemoveItem(att, weapon);
          GameVars.lastMissileItem := item;
          CbtActs.NoteThrown(att, item);
        end else
          CharHlp.RemoveItem(att, weapon);
    end;
    CharHlp.RecalcStats(att);
    GameVars.curChar := savedCur;
  end;
  if done then
    done := CharHlp.EndActions(att);
  if CbtMap.CombatIconVisible(att, 0) then begin
    CbtMap.SetCreatureFacing(att, att^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(att, att^.combatAddr^.direction, 0, 0);
  end;
end;

{ Range penalty: with a ranged weapon the subrange is (range - 1) div 3, and defense rises by 2 beyond one subrange and
  by 3 more beyond two. Melee adds nothing. }
procedure ApplyRangePenalty(att, def: Types.PCharRecord; var defense: Byte);
var
  subrange: ShortInt;
  dist: ShortInt;
begin
  dist := CbtMap.CalcDistance(att, def);
  if CharHlp.HasRangedWeapon(att) then
    subrange := (CharHlp.BaseItem(att^.equipped[C_EQUIP.WEAPON]^.itemType)^.range - 1) div 3
  else
    subrange := dist;
  if dist - subrange > 0 then begin
    dist := dist - subrange;
    defense := defense + 2;
  end;
  if dist - subrange > 0 then begin
    dist := dist - subrange;
    { cumulative with the first +2 }
    defense := defense + 3;
  end;
end;

{ Cure Light Wounds target in the creature's own cell or the 8 around it. Candidates: the wounded ally with the fewest
  hp (the creature itself, checked last, also wins whenever below half its max) and the last downed, not dead body of
  its own side found on a corpse cell. The body wins unless there is none or the ally has 7 hp or fewer. }
function FindCureTarget(creature: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  best: Pointer;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  best := nil;
  downIdx := 0;
  bestHp := 255;
  for d := 0 to C_DIR.CENTER do begin
    nx := CbtMap.CombatCellX(creature) + GameDefs.dirDX[d];
    ny := CbtMap.CombatCellY(creature) + GameDefs.dirDY[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      { the var param is the scratch }
      tgt := GameVars.creatureArr[crIdx];
      if Types.PCharRecord(tgt)^.hostile = creature^.hostile then
        if Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax then
          if (Types.PCharRecord(tgt)^.hpCur < bestHp)
             or ((tgt = creature) and (Types.PCharRecord(tgt)^.hpCur < Types.PCharRecord(tgt)^.hpMax div 2)) then begin
            best := tgt;
            bestHp := Types.PCharRecord(tgt)^.hpCur;
          end;
    end else if terrIdx = C_TERR.CORPSE then
      for j := 1 to GameVars.downedCount do
        if GameVars.downed[j].cr <> nil then
          if not (GameVars.downed[j].cr^.status in
                  [C_STATUS.DEAD_STATUS, C_STATUS.STONED, C_STATUS.GONE]) then
            if GameVars.downed[j].x = nx then
              if GameVars.downed[j].y = ny then
                { a body of its own side only: downed holds the party's, which a hostile cleric healed (#714) }
                if GameVars.downed[j].cr^.hostile = creature^.hostile then
                  downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GameVars.downed[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ True when caster is a party member and the party has seen target's kind shrug off what fact names (the Bestiary,
  #842): an immunity the party knows of is obvious to its caster. }
function PartyKnows(caster, target: Types.PCharRecord; fact: Byte): Boolean;
var
  i: Word;
begin
  PartyKnows := False;
  if (caster = nil) or not Party.IsPartyMember(caster) or Party.IsPartyMember(target) then Exit;
  i := Bestiary.Find(target^.name);
  if i <> 0 then
    PartyKnows := Bestiary.Knows(Bestiary.Entry(i)^, fact);
end;

{ True when creature stands in a cloud of terrain terr (C_TERR.STINKING_CLOUD, CLOUDKILL): the clouds' test, a cloud
  cell under any of its own cells (ConsiderStinkingCloud's CbtMap.ProbeDirection, where a stinking cloud wins, or
  CbtMap.ProbeTerrain). }
function InCloud(creature: Types.PCharRecord; terr: Byte): Boolean;
var
  crIdx: Byte;
  terrIdx: Byte;
begin
  if terr = C_TERR.STINKING_CLOUD then begin
    CbtMap.ProbeDirection(creature, C_DIR.CENTER, crIdx, terrIdx);
    InCloud := terrIdx = C_TERR.STINKING_CLOUD;
  end else
    InCloud := CbtMap.ProbeTerrain(creature, C_DIR.CENTER, terr);
end;

function CloudCatch(spell: Byte; x, y: ShortInt): Byte;
var
  crIdx: array[1..9] of Byte;
  terr: Byte;
  caught: Byte;
  side: Byte;
  k: Byte;
  j: Byte;
  cx: ShortInt;
  cy: ShortInt;
  first: Boolean;
  p: Types.PCharRecord;
begin
  CloudCatch := 0;
  caught := 0;
  if CharHlp.SpellArea(spell, side) <> C_SPELL.AREA_CLOUD then
    Exit;
  for k := 1 to side * side do begin
    CbtMap.CloudCell(side, k, x, y, cx, cy);
    CbtMap.GetArenaContents(cx, cy, crIdx[k], terr);
    if (terr = 0) or (GameDefs.terrainInfo[terr].cost >= 255) then
      crIdx[k] := 0;
    if crIdx[k] > 0 then begin
      p := GameVars.creatureArr[crIdx[k]];
      if CharHlp.Team(p) <> CharHlp.EnemyTeam(GameVars.curChar) then Exit;
      first := True;
      for j := 1 to k - 1 do
        if crIdx[j] = crIdx[k] then
          first := False;
      if first and CbtActs.SpellCanAffect(spell, p, GameVars.curChar) then
        Inc(caught);
    end;
  end;
  CloudCatch := caught;
end;

function SpellCanAffect(spell: Byte; target, caster: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
  eff: Byte;
  i: Byte;
  pool: Byte;
  ok: Boolean;
begin
  SpellCanAffect := False;
  if (target = nil) or (target^.enabled = 0) then Exit;
  eff := GameDefs.spellTable[spell].effect;
  { under the spell's effect already }
  if (eff <> 0) and CharHlp.HasEffect(target, eff, effect) then Exit;
  { helpless already, for a spell that would leave it so }
  if CharHlp.IsHelpless(target) then
    for i := 1 to GameDefs.HELPLESS_FX_COUNT do
      if eff = GameDefs.helplessFx[i] then Exit;
  ok := True;
  case spell of
    C_SPELL.CHARM_PERSON:
      ok := CharHlp.IsPerson(target) and not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_SLEEP_CHARM);
    C_SPELL.HOLD_PERSON, C_SPELL.HOLD_PERSON_MU:
      ok := CharHlp.IsPerson(target) and not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_PARALYSIS);
    C_SPELL.SLEEP: begin
      { the largest pool the dice can roll }
      pool := C_SPELL.SLEEP_DICE * C_SPELL.SLEEP_DIE;
      ok := (target^.charType <> CharHlp.UNDEAD_TYPE) and CharHlp.SleepTakes(target, pool) and
            not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_SLEEP_CHARM);
    end;
    C_SPELL.SNAKE_CHARM: ok := target^.name = C_SPELL.SNAKE_NAME;
    { a creature nauseated already, or standing in a cloud that tries it each round, gains nothing from a new one }
    C_SPELL.STINKING_CLOUD:
      ok := not FxEngine.CloudSpares(target) and not CbtActs.InCloud(target, C_TERR.STINKING_CLOUD);
    { Cloudkill (#1193) passes over one it cannot touch, or one in a Cloudkill already, which it meets each round }
    C_SPELL.CLOUDKILL:
      ok := not FxEngine.CloudkillProof(target) and not CbtActs.InCloud(target, C_TERR.CLOUDKILL);
    C_SPELL.CAUSE_DISEASE: ok := target^.charType <> CharHlp.UNDEAD_TYPE;
    C_SPELL.SILENCE: ok := CbtMap.CombatSlot(target) in CbtActs.seenCasting;
    { the spells of levels 4 and 5 (#1121): Hold Monsters and Charm Monsters take any kind of creature but the ones
      the party has seen shrug them off; Slay Living kills no undead, Sticks to Snakes troubles none of level 6 or
      more, and Poison needs a creature that can be poisoned }
    C_SPELL.HOLD_MONSTERS: ok := not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_PARALYSIS);
    C_SPELL.CHARM_MONSTERS: ok := not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_SLEEP_CHARM);
    C_SPELL.SLAY_LIVING: ok := target^.charType <> CharHlp.UNDEAD_TYPE;
    C_SPELL.STICKS_TO_SNAKES: ok := target^.levelHighest < 6;
    C_SPELL.POISON: ok := not CbtActs.PartyKnows(caster, target, C_BEAST.IMMUNE_POISON);
  end;
  SpellCanAffect := ok;
end;

function BestAim(spell: Byte; var count: Byte): Types.PCharRecord;
var
  slots: array[1..Types.ARENA_SLOTS] of Byte;
  n: Byte;
  i: Byte;
  j: Byte;
  caught: Byte;
  ties: Byte;
  size: Byte;
  radius: Byte;
  { a cloud's side, which BestAim does not use }
  side: Byte;
  p: Types.PCharRecord;
  best: Types.PCharRecord;
  taken: Boolean;
begin
  count := 0;
  best := nil;
  ties := 0;
  n := CbtMap.CountTargets(GameVars.curChar, CharHlp.CalcSpellRange(spell));
  { AreaHitsNonEnemy rebuilds the target list }
  for i := 1 to n do
    slots[i] := GameVars.combatTargetSlots[i];
  radius := GameDefs.spellTable[spell].aiRadius;
  if CharHlp.SpellArea(spell, size) <> C_SPELL.AREA_TARGETS then
    size := 1;
  for i := 1 to n do begin
    p := GameVars.creatureArr[slots[i]];
    if (p^.enabled <> 0) and CbtActs.CanTarget(GameVars.curChar, p, True) then
      if radius > 0 then begin
        if not CbtActs.AreaHitsNonEnemy(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), radius) then begin
          caught := 0;
          if CharHlp.SpellArea(spell, side) = C_SPELL.AREA_CLOUD then
            { a cloud fills its own block, not the radius around the aim }
            caught := CbtActs.CloudCatch(spell, CbtMap.CombatCellX(p), CbtMap.CombatCellY(p))
          else
            for j := 1 to GameVars.targetCount do
              if CbtActs.SpellCanAffect(spell, GameVars.creatureArr[GameVars.targetList[j].idx], GameVars.curChar) then
                Inc(caught);
          if caught > count then begin
            count := caught;
            best := p;
            ties := 1;
          end else if (caught = count) and (caught > 0) then begin
            { each of the ties as likely as the others }
            Inc(ties);
            if Dice.RollDice(1, ties) = 1 then
              best := p;
          end;
        end;
      end else if CbtActs.SpellCanAffect(spell, p, GameVars.curChar) then begin
        if count < size then
          Inc(count);
        taken := False;
        for j := 1 to Types.ARENA_SLOTS do
          if GameVars.spellTargets[j] = p then
            taken := True;
        if not taken then begin
          Inc(ties);
          if Dice.RollDice(1, ties) = 1 then
            best := p;
        end;
      end;
  end;
  if best = nil then
    count := 0;
  BestAim := best;
end;

{ Pick one spell target. Manual: the spell-mode aim menu, which also locks the target. AI: a non-offensive spell targets
  the caster (Cure Light Wounds: FindCureTarget's pick); an offensive one takes BestAim's, which only aims where the
  spell will obviously do something (SpellCanAffect, #1086), and locks it. SSI made up to 20 random picks, vetoing an
  area that caught a non-enemy and a helpless target for a spell that leaves one helpless, and so held skeletons and
  silenced kobolds. On success set gTargetX/gTargetY; on failure clear tgt. }
function SelectSpellTarget(spell: Byte; ai: Boolean; ground: Byte; var tgt: Types.TAimTarget): Boolean;
var
  found: Boolean;
  p: Types.PCharRecord;
  caught: Byte;
begin
  found := False;
  if not ai then begin
    CbtActs.CombatAimMenu(GameVars.curChar, CharHlp.CalcSpellRange(spell), 0, ground,
                          GameDefs.spellTable[spell].offensive = 0, found, tgt);
    GameVars.curChar^.combatAddr^.other := tgt.cr;
  end else begin
    if GameDefs.spellTable[spell].offensive = 0 then begin
      tgt.cr := GameVars.curChar;
      if not (spell in C_SPELL.CURE_WOUNDS) or CbtActs.FindCureTarget(GameVars.curChar, tgt.cr) then begin
        tgt.x := CbtMap.CombatCellX(tgt.cr);
        tgt.y := CbtMap.CombatCellY(tgt.cr);
        found := True;
      end;
    end else begin
      p := CbtActs.BestAim(spell, caught);
      if p <> nil then begin
        GameVars.curChar^.combatAddr^.other := p;
        tgt.cr := p;
        tgt.x := CbtMap.CombatCellX(p);
        tgt.y := CbtMap.CombatCellY(p);
        found := True;
      end;
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    Magic.gTargetX := tgt.x;
    Magic.gTargetY := tgt.y;
  end else begin
    SelectSpellTarget := False;
    FillChar(tgt, SizeOf(tgt), 0);
  end;
end;

{ True for a hostile spell: spellTable offensive 1 and target 0. A spell outside the table is not. }
function HostileSpell(spell: Byte): Boolean;
begin
  HostileSpell := False;
  if (spell >= 1) and (spell <= SizeOf(GameDefs.spellTable) div SizeOf(GameDefs.spellTable[1])) then
    HostileSpell := (GameDefs.spellTable[spell].offensive = 1) and (GameDefs.spellTable[spell].target = 0);
end;

{ The sprite cell the spell-aim preview marks a spell's cells with: the spell missile for a hostile spell
  (HostileSpell), otherwise the sparkle. }
function AimMarker(spell: Byte): Byte;
begin
  if CbtActs.HostileSpell(spell) then
    AimMarker := C_SPRITE.MISSILE
  else
    AimMarker := C_SPRITE.SPARKLE;
end;

{ The spell-aim count's rule for spell (areaRules), RULE_NONE when it has none. }
function AreaRuleOf(spell: Byte): Byte;
var
  i: Byte;
begin
  AreaRuleOf := RULE_NONE;
  for i := 1 to SizeOf(areaRules) div SizeOf(areaRules[1]) do
    if areaRules[i].spell = spell then
      AreaRuleOf := areaRules[i].rule;
end;

{ The name line 23 gives spell while it is aimed: its own, the Fireball's for the item fireball, and none for another
  item spell. }
function AimSpellName(spell: Byte): Types.TStr40;
begin
  AimSpellName := '';
  if spell = C_SPELL.ITEM_FIREBALL then
    spell := C_SPELL.FIREBALL;
  if CharHlp.IsSpell(spell) then
    AimSpellName := GameDefs.spellNames[spell];
end;

{ Line 23 for ReportAreaCatch (#840): the spell's name and ': ', then the enemies it catches in yellow and the allies
  in light cyan, the colours their names have in combat, each side as CharHlp.CatchText gives it, as
  "SLEEP: 3 OF 2 ENEMIES, 1 ALLY"; a side it catches no one of is left out, and "NO TARGETS" stands for both. A line
  too long for the screen drops the spell's name. }
procedure ShowAreaTally(var side: TAreaTally);
const
  SEGS = 6;
  LINE_WIDTH = 40;
var
  text: array[1..SEGS] of Types.TStr40;
  tint: array[1..SEGS] of Byte;
  n: Byte;
  len: Byte;
  col: Byte;
  i: Byte;
  name: Types.TStr40;

  procedure Add(color: Byte; s: Types.TStr40);
  begin
    Inc(n);
    text[n] := s;
    tint[n] := color;
    Inc(len, Length(s));
  end;

  { Add the sides' parts. }
  procedure AddSides;
  begin
    if (side[True].count = 0) and (side[False].count = 0) then
      Add(LightGreen, 'NO TARGETS')
    else begin
      if side[True].count > 0 then
        Add(Yellow, CharHlp.CatchText(side[True].count, side[True].most, True));
      if (side[True].count > 0) and (side[False].count > 0) then
        Add(LightGreen, ', ');
      if side[False].count > 0 then
        Add(LightCyan, CharHlp.CatchText(side[False].count, side[False].most, False));
    end;
  end;

begin
  name := CbtActs.AimSpellName(aimSpell);
  n := 0;
  len := 0;
  if name <> '' then begin
    Add(White, name);
    Add(White, ': ');
  end;
  AddSides;
  if len > LINE_WIDTH then begin
    n := 0;
    len := 0;
    AddSides;
  end;
  Border.ClearBox(0, 23, 39, 23);
  col := 0;
  for i := 1 to n do begin
    TextRend.DisplayString(col, 23, tint[i], text[i]);
    Inc(col, Length(text[i]));
  end;
end;

procedure ReportAreaCatch(var caught: Types.TSlotList);
var
  side: TAreaTally;
  i: Byte;
  enemy: ShortInt;
begin
  FillChar(side, SizeOf(side), 0);
  enemy := CharHlp.EnemyTeam(GameVars.curChar);
  for i := 1 to caught.count do
    Inc(side[CharHlp.Team(GameVars.creatureArr[caught.slot[i]]) = enemy].count);
  if CbtActs.AreaRuleOf(aimSpell) = RULE_SLEEP then
    CharHlp.SleepMost(caught, enemy, side[True].most, side[False].most);
  CbtActs.ShowAreaTally(side);
end;

{ The cast-target menu in combat (GameVars.castTargetMenu): build the spell-target list from the spell's shape
  (CharHlp.SpellArea). The caster alone; one picked creature (a bare cell gets a zero-radius area); everything within
  the table radius (area and 7) of the picked cell, for a radius, a bolt or a cloud (the Fireball, Lightning Bolt and
  Stinking Cloud handlers then take their own cells); a cone toward the picked cell, whose handler takes its cells; the
  creatures a pool buys (Faerie Fire, Charm Monsters); or up to its count of creatures picked one at a time. b is the
  AI flag, passed to SelectSpellTarget. While the player aims, the CbtMap spell-aim preview shows the cells the spell
  will reach: Lightning Bolt's path, Stinking Cloud's 2x2 block, or the blast at SpellArea's radius (a fireball bursts
  in flame); for a radius, a bolt or a cloud, line 23 shows who it will catch (ReportAreaCatch). The Javelin of
  Lightning is aimed at one creature, but its preview and count show the bolt that runs on past it (#861). }
procedure SelectCombatTargets(spell: Byte; b: Boolean; var cast: Boolean);
var
  remaining: Byte;
  k: Byte;
  j: Byte;
  sel: Types.TAimTarget;
  dup: Boolean;
  { CharHlp.SpellArea's shape, and its radius or creature count }
  kind: Byte;
  size: Byte;
  picked: Boolean;
  { a pool spell's pool (CharHlp.PoolCost), what its targets cost so far, and the end of its picks }
  pool: Byte;
  spent: Byte;
  stop: Boolean;
begin
  cast := True;
  GameVars.spellTargetCount := 0;
  { BestAim passes over the targets picked already }
  FillChar(GameVars.spellTargets, SizeOf(GameVars.spellTargets), 0);
  GameVars.gMultiTarget := 0;
  Magic.gTargetX := CbtMap.CombatCellX(GameVars.curChar);
  Magic.gTargetY := CbtMap.CombatCellY(GameVars.curChar);
  kind := CharHlp.SpellArea(spell, size);
  case kind of
    C_SPELL.AREA_SELF:
      begin
        GameVars.spellTargets[1] := GameVars.curChar;
        GameVars.spellTargetCount := 1;
      end;
    C_SPELL.AREA_SPOT:
      { the picked creature, or an area at the picked cell }
      begin
        if not b then
          if spell = C_SPELL.ITEM_JAVELIN_LIGHTNING then begin
            aimSpell := spell;
            CbtMap.StartSpellPreview(Types.AimBolt, spell, 0, C_SPRITE.LIGHTNING, True);
          end else
            CbtMap.StartSpellPreview(Types.AimBlast, spell, 0, CbtActs.AimMarker(spell), False);
        picked := CbtActs.SelectSpellTarget(spell, b, 0, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          { the pick, not combatAddr^.other: the AI's pick of a non-offensive spell's target leaves its lock there }
          if sel.cr <> nil then begin
            GameVars.spellTargets[1] := sel.cr;
            GameVars.spellTargetCount := 1;
          end else begin
            { radius 0: the picked cell alone }
            Pathing.TargetArea(Magic.gTargetX, Magic.gTargetY, 0);
            GameVars.gMultiTarget := 1;
          end;
        end else
          cast := False;
      end;
    C_SPELL.AREA_RADIUS, C_SPELL.AREA_CLOUD, C_SPELL.AREA_BOLT:
      { fixed radius, ground OK }
      begin
        if not b then begin
          { line 23 counts who the spell will catch (#840) }
          aimSpell := spell;
          case kind of
            C_SPELL.AREA_BOLT: CbtMap.StartSpellPreview(Types.AimBolt, spell, 0, C_SPRITE.LIGHTNING, True);
            C_SPELL.AREA_CLOUD: CbtMap.StartSpellPreview(Types.AimCloud, spell, size, C_SPRITE.SPARKLE, True);
          else
            if (spell = C_SPELL.FIREBALL) or (spell = C_SPELL.ITEM_FIREBALL) then
              CbtMap.StartSpellPreview(Types.AimBlast, spell, size, C_SPRITE.BURST, True)
            else
              CbtMap.StartSpellPreview(Types.AimBlast, spell, size, CbtActs.AimMarker(spell), True);
          end;
        end;
        picked := CbtActs.SelectSpellTarget(spell, b, 1, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          Pathing.TargetArea(Magic.gTargetX, Magic.gTargetY, GameDefs.spellTable[spell].area and 7);
          GameVars.gMultiTarget := 1;
        end else
          cast := False;
      end;
    C_SPELL.AREA_CONE:
      { a cone from the caster toward the picked cell: the handler gathers the creatures on it (Magic.WalkCone), which
        the preview shows (Magic.TraceBolt) }
      begin
        if not b then begin
          aimSpell := spell;
          CbtMap.StartSpellPreview(Types.AimBolt, spell, 0, CbtActs.AimMarker(spell), True);
        end;
        picked := CbtActs.SelectSpellTarget(spell, b, 1, sel);
        CbtMap.StopSpellPreview;
        if picked then
          GameVars.gMultiTarget := 1
        else
          cast := False;
      end;
    C_SPELL.AREA_POOL:
      { creatures picked one at a time against the pool (Curse's): each costs CharHlp.PoolCost, the first is always
        taken, and the pick that would overspend the pool ends the picking untaken }
      begin
        if spell = C_SPELL.FAERIE_FIRE then
          pool := CharHlp.GetCasterLevel(spell)
        else
          pool := Dice.RollDice(C_SPELL.CHARM_MONSTERS_DICE, C_SPELL.CHARM_MONSTERS_DIE);
        spent := 0;
        k := 0;
        stop := False;
        repeat
          if not b then
            CbtMap.StartSpellPreview(Types.AimBlast, spell, 0, CbtActs.AimMarker(spell), False);
          picked := CbtActs.SelectSpellTarget(spell, b, 0, sel);
          CbtMap.StopSpellPreview;
          if picked and (sel.cr <> nil) then begin
            dup := False;
            for j := 1 to k do
              if GameVars.spellTargets[j] = sel.cr then
                dup := True;
            if not dup then begin
              Inc(spent, CharHlp.PoolCost(spell, sel.cr));
              if (k > 0) and (spent > pool) then
                stop := True
              else begin
                Inc(k);
                GameVars.spellTargets[k] := sel.cr;
              end;
            end else if not b then
              CharDisp.PrintBottomLine('Already been targeted')
            else
              Dec(pool);
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(sel.cr), CbtMap.CombatCellY(sel.cr));
          end else
            stop := True;
        until stop or (pool = 0) or (k = Types.ARENA_SLOTS);
        GameVars.spellTargetCount := k;
        if k = 0 then
          cast := False;
      end;
  else
    { C_SPELL.AREA_TARGETS: up to size creatures, picked one at a time }
    begin
      remaining := size;
      k := 0;
      while remaining > 0 do begin
        if not b then
          CbtMap.StartSpellPreview(Types.AimBlast, spell, 0, CbtActs.AimMarker(spell), False);
        picked := CbtActs.SelectSpellTarget(spell, b, 0, sel);
        CbtMap.StopSpellPreview;
        if picked then begin
          dup := False;
          for j := 1 to k do
            if GameVars.spellTargets[j] = sel.cr then
              dup := True;
          if not dup then begin
            Inc(k);
            GameVars.spellTargets[k] := sel.cr;
            Dec(remaining);
          end else if not b then
            CharDisp.PrintBottomLine('Already been targeted')
          else
            Dec(remaining);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(GameVars.spellTargets[k]),
                                 CbtMap.CombatCellY(GameVars.spellTargets[k]));
        end else
          Dec(remaining);
      end;
      GameVars.spellTargetCount := k;
      if k = 0 then
        cast := False;
    end;
  end;
end;

{ Pick (C_SPELL.NONE: from the Cast list) and validate a spell, rejecting camp-only ones. A casting time (castTime div
  3) of 0 casts it now and ends the caster's actions; otherwise the caster "Begins Casting": spellCast holds the spell
  and initiative drops by the casting time (to at least 1), so it resolves on a later action. A scroll spell picked from
  the list gets the same camp-only check, then is cast from its scroll as Use does (Magic.UseItemSpell), but named as a
  memorized spell is, followed by Use's stat and attack updates. }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  castTime: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
  scroll: Types.PItemRec;
begin
  caster := GameVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  spellId := spell;
  scroll := nil;
  if spellId = C_SPELL.NONE then begin
    spellId := Magic.CastSpellMenu(idx, notEmpty, scroll);
    if spellId = C_SPELL.NONE then
      scroll := nil;
  end;
  if spellId > C_SPELL.NONE then
    if GameDefs.spellTable[spellId].whenCast = 0 then begin
      CharDisp.PrintBottomLine('Camp Only Spell');
      spellId := C_SPELL.NONE;
      scroll := nil;
    end else
      { seen casting: from here on Silence is worth casting at it (#1087) }
      CbtActs.seenCasting := CbtActs.seenCasting + [CbtMap.CombatSlot(caster)];
  if scroll <> nil then begin
    Magic.UseItemSpell(scroll, spellId, True, cast);
    CharHlp.RecalcStats(caster);
    CbtActs.RecalcAttacksLeft(caster);
    if not cast then
      CharDisp.DisplayCombatInterface;
    Exit;
  end;
  if ai = 0 then begin
    CharDisp.DisplayCombatInterface;
    CbtMap.DisplayMapViewCentered(caster, 3, True);
    CharDisp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > C_SPELL.NONE then begin
    castTime := GameDefs.spellTable[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpell(spellId, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharDisp.PrintNameString(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellCast := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
    end;
  end;
end;

{ Backstabbing requires a thief in leather or no armor and with no shield (ClassCal.ArmorBarsThiefSkills), using a club,
  dagger, broad, long or short sword, or no weapon. The target must have been attacked more than once this round and
  face away from the attacker. }
function IsBackstab(att, def: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
  wItem: Byte;
  can: Boolean;
begin
  can := False;
  weapon := att^.equipped[C_EQUIP.WEAPON];
  if weapon <> nil then
    wItem := weapon^.itemType;
  if CharHlp.GetClassLevel(att, C_LEVEL.THIEF_BIT) > 0 then
    if not ClassCal.ArmorBarsThiefSkills(att) then
      if (weapon = nil) or (wItem = C_ITEM.CLUB) or (wItem = C_ITEM.DAGGER)
         or ((wItem >= C_ITEM.BROAD_SWORD) and (wItem <= C_ITEM.SHORT_SWORD)) then
        can := True;
  if can and (def^.combatAddr^.flankCount > 1)
     and (CbtActs.DirTowardTarget(att, def) = def^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

{ The direction from creature's cell toward the other creature's (Pathing.DirToward); the same cell gives 0. }
function DirTowardTarget(creature, other: Types.PCharRecord): Byte;
begin
  DirTowardTarget := Pathing.DirToward(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                       CbtMap.CombatCellX(other), CbtMap.CombatCellY(other));
end;

{ Build the missile icon for weapon's type and fly it from att to def between the ranged-attack sounds. }
procedure AnimateMissile(att, def: Types.PCharRecord; weapon: Types.PItemRec);
var
  sym: Byte;
  frames: Byte;
  dir: Byte;
  pace: Byte;
  size: Word;
begin
  dir := CbtActs.DirTowardTarget(att, def);
  frames := 1;
  pace := 10;
  sym := 13;
  size := Blit.MaskBytes(GameVars.moveIconSheet^.imgSize);
  case weapon^.itemType of
    { straight-flying missiles }
    C_ITEM.DART, C_ITEM.JAVELIN, C_ITEM.QUARREL, C_ITEM.SPEAR, C_ITEM.ARROW:
      if Odd(dir) then begin
        if (dir = C_DIR.SOUTHEAST) or (dir = C_DIR.SOUTHWEST) then
          CharDisp.CopyIconFacing(sym + 1, 1, 0, dir = C_DIR.SOUTHWEST)
        else
          CharDisp.CopyIconFacing(sym + 1, 0, 0, dir = C_DIR.NORTHWEST);
      end else
        CharDisp.CopyIconFacing(sym + dir mod 4, dir div 4, 0, False);
    { spinning thrown weapons }
    C_ITEM.HAND_AXE, C_ITEM.CLUB, C_ITEM.HAMMER:
      begin
        CharDisp.BuildIconFacings(sym + 3);
        frames := 4;
        pace := 50;
      end;
    { holy water / oil flask }
    C_ITEM.HOLY_WATER_VIAL, C_ITEM.FLASK_OF_OIL:
      begin
        CharDisp.BuildIconFacings(sym + 4);
        frames := 4;
        pace := 50;
      end;
  else begin
      if weapon^.itemType = C_ITEM.SLING then
        Inc(sym);
      CharDisp.CopyIconFacing(sym + 7, 0, 0, False);
      CharDisp.CopyIconFacing(sym + 7, 1, 1, False);
      frames := 2;
      pace := 20;
    end;
  end;
  SoundDrv.SoundSetAutoStop(0);
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.RANGED_START], C_SOUND.GROUP_RANGED);
  CharDisp.AnimateIconBetween(att, def, frames, pace);
  SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.RANGED_END], C_SOUND.GROUP_RANGED);
  SoundDrv.SoundSetAutoStop(10);
end;

{ Set hostileHpPct to the enabled hostiles' current HP as a percentage of all hostiles' maximum HP, rounded down to a
  multiple of five; it is left unchanged when there are no hostiles. }
procedure UpdateHostileHpPercent;
var
  maxSum: Word;
  curSum: Word;
  p: Types.PCharRecord;
begin
  maxSum := 0;
  curSum := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      if p^.enabled <> 0 then
        curSum := curSum + p^.hpCur;
      maxSum := maxSum + p^.hpMax;
    end;
    p := p^.nextCharAddr;
  end;
  if maxSum > 0 then
    { LongInt: curSum * 20 passes a Word above 3276 }
    hostileHpPct := LongInt(curSum) * 20 div maxSum * 5;
end;

{ The fastest enabled enemy's movement in whole moves (CalcCreatureMovement div 2); no range or line-of-sight check. }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var
  best: Byte;
  m: Byte;
  p: Types.PCharRecord;
begin
  best := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if (CharHlp.EnemyTeam(creature) = CharHlp.Team(p)) and (p^.enabled <> 0) then begin
      m := CbtActs.CalcCreatureMovement(p) div 2;
      if m > best then
        best := m;
    end;
    p := p^.nextCharAddr;
  end;
  HighestEnemyMovement := best;
end;

{ Confirm a physical attack on an ally (enemies and quick-fighting attackers pass unasked). Yes sets the GBVM
  attacked-allies flag, and every NPC-flagged creature in okay status turns hostile and drops its target. }
function CheckAttackAlly(att, def: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
begin
  if (CharHlp.EnemyTeam(def) = CharHlp.Team(att)) or (att^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', promptColor, optionColor, commandColor) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GameVars.zone1^[C_GBVM.ATTACKED_ALLIES] := 1;
    p := GameVars.creatureList;
    while p <> nil do begin
      { NPC flag (high bit) set }
      if (p^.status = C_STATUS.OKAY) and CharHlp.IsNpc(p) then begin
        p^.hostile := 1;
        p^.combatAddr^.other := nil;
      end;
      p := p^.nextCharAddr;
    end;
    CharHlp.CountTeams;
  end;
end;

function DirOfKey(ch: Char): Byte;
begin
  case ch of
    C_KEYS.UP: DirOfKey := C_DIR.NORTH;
    C_KEYS.PAGE_UP: DirOfKey := C_DIR.NORTHEAST;
    C_KEYS.RIGHT: DirOfKey := C_DIR.EAST;
    C_KEYS.PAGE_DOWN: DirOfKey := C_DIR.SOUTHEAST;
    C_KEYS.DOWN: DirOfKey := C_DIR.SOUTH;
    C_KEYS.END_KEY: DirOfKey := C_DIR.SOUTHWEST;
    C_KEYS.LEFT: DirOfKey := C_DIR.WEST;
    C_KEYS.HOME: DirOfKey := C_DIR.NORTHWEST;
  else
    DirOfKey := C_DIR.CENTER;
  end;
end;

{ Line 23's range to the target, in the weapon aim. }
procedure ShowRange(dist: Byte);
begin
  TextRend.DisplayString(0, 23, LightGreen, 'Range = ' + StrUtil.NumStr(dist) + '  ');
end;

{ True when cur's readied weapon may strike now: no ranged weapon, or one with damaging ammunition
  (CharHlp.FindDamagingRangedWeapon) and either no enemy adjacent or a throwable weapon. }
function WeaponCanStrike(cur: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
begin
  if not CharHlp.HasRangedWeapon(cur) then
    WeaponCanStrike := True
  else if not CharHlp.FindDamagingRangedWeapon(cur, weapon) then
    WeaponCanStrike := False
  else
    WeaponCanStrike := (CbtMap.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur);
end;

{ One aim-menu round on the target: center the view on it, show the range (weapon mode) and offer Target when it is in
  range (a weapon attack needs another creature and WeaponCanStrike), then Next/Prev/Manual/Center/Exit. A cursor key
  (keypad digits included) returns through dir the direction it points, so the caller can switch to manual aim and move
  the cursor that way; any other choice sets dir to C_DIR.CENTER. }
function AimTargetMenu(cur, tgt: Types.PCharRecord; range, weaponMode: Byte; var dir: Byte): Char;
var
  menu: String[40];
  ext: Boolean;
  dist: Byte;
  ch: Char;
begin
  menu := '';
  dist := CbtMap.CalcDistance(cur, tgt);
  if weaponMode <> 0 then
    CbtActs.ShowRange(dist);
  if dist <= range then
    if (weaponMode = 0) or ((cur <> tgt) and CbtActs.WeaponCanStrike(cur)) then
      menu := 'Target ';
  menu :='Next Prev Manual ' + menu + 'Center Exit';
  CbtMap.DisplayMapViewCentered(tgt, 3, True);
  CharDisp.CombatPrintCreatureInfo(tgt);
  { the arena with the target marked, when the minimap is on (#1210) }
  CbtMini.Show(cur, CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt));
  repeat
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('Aim: ', menu, promptColor, optionColor, commandColor, True, False, ext);
    dir := C_DIR.CENTER;
    if ext then
      dir := CbtActs.DirOfKey(ch);
  until (not ext) or (dir <> C_DIR.CENTER);
  AimTargetMenu := ch;
end;

procedure AttackWithReadied(att, def: Types.PCharRecord; var done: Boolean);
var
  weapon: Types.PItemRec;
begin
  CbtActs.NoteAttackDirection(att, def);
  weapon := nil;
  if CharHlp.HasRangedWeapon(att) then
    if CharHlp.FindDamagingRangedWeapon(att, weapon) then
      if CharHlp.HasThrowableWeapon(att) then
        if CbtMap.CalcDistance(att, def) = 1 then
          weapon := nil;
  CbtActs.MakeAttack(att, def, False, weapon, done);
end;

{ Confirm an aim selection. weaponMode=1 performs a weapon attack; 0 selects a spell target. An attack on an ally needs
  CheckAttackAlly's consent, else sel is cleared and done is False. The attack tries a sweep first, then
  AttackWithReadied. }
procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; weaponMode: Byte; var done: Boolean;
                              var sel: Types.TAimTarget);
begin
  done := True;
  if weaponMode = 1 then
    if not CbtActs.CheckAttackAlly(cur, tgt) then
      done := False;
  if done then begin
    sel.cr := tgt;
    sel.x := CbtMap.CombatCellX(tgt);
    sel.y := CbtMap.CombatCellY(tgt);
    GameVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(CbtMap.CenterX, CbtMap.CenterY, 3, C_DIR.CENTER);
    if weaponMode = 1 then
      if CbtActs.SweepAttack(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else
        CbtActs.AttackWithReadied(cur, tgt, done);
  end else
    FillChar(sel, SizeOf(sel), 0);
end;

{ The free cursor aim: the arrow-key scans move a cell cursor (clamped to the arena) from underCursor's cell, after a
  first step toward startDir (C_DIR.CENTER stays put), Pathing.WalkLine checks the line and range, Target takes a valid
  cell (a weapon attack goes through ConfirmAttackTarget), Center recenters and Exit/Escape cancels. A bare cell is
  valid only when ground is set. }
procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, ground, startDir: Byte;
                          var done: Boolean; var sel: Types.TAimTarget);
var
  menu: String[40];
  ch: Char;
  dir: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  cx: ShortInt;
  cy: ShortInt;
  crIdx: Byte;
  terrIdx: Byte;
  dist: Word;
  valid: Boolean;
begin
  FillChar(sel, SizeOf(sel), 0);
  cx := CbtMap.CombatCellX(underCursor);
  cy := CbtMap.CombatCellY(underCursor);
  ch := ' ';
  dir := startDir;
  done := False;
  GameVars.arenaPtr^.cursorOn := True;
  GameVars.arenaPtr^.cursorSize := 1;
  while not (ch in [C_KEYS.NONE, 'E', 'T']) do
  begin
    CbtMap.ScrollView(cx, cy, 3, dir);
    Inc(cx, GameDefs.dirDX[dir]);
    Inc(cy, GameDefs.dirDY[dir]);
    if cx < 0 then
      cx := 0;
    if cy < 0 then
      cy := 0;
    if cx > Types.ARENA_LAST_X then
      cx := Types.ARENA_LAST_X;
    if cy > Types.ARENA_LAST_Y then
      cy := Types.ARENA_LAST_Y;
    CbtMap.GetArenaContents(cx, cy, crIdx, terrIdx);
    valid := False;
    dist := 255;
    wx := cx;
    wy := cy;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GameVars.arenaPtr) then begin
      valid := True;
      if weaponMode <> 0 then
        CbtActs.ShowRange(dist div 2);
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GameVars.creatureArr[crIdx]
      else if terrIdx = C_TERR.CORPSE then
        for j := 1 to GameVars.downedCount do
          if GameVars.downed[j].x = cx then
            if GameVars.downed[j].y = cy then
              underCursor := GameVars.downed[j].cr;
    end;
    if underCursor <> nil then
      CharDisp.CombatPrintCreatureInfo(underCursor)
    else
      CharDisp.ClearCreatureInfo;
    { the arena with the cursor on it, when the minimap is on (#1210) }
    CbtMini.Show(cur, cx, cy);
    if (range < dist) or (GameDefs.terrainInfo[terrIdx].cost = 255) then
      valid := False;
    if underCursor <> nil then begin
      if not CbtActs.CanTarget(cur, underCursor, True) then
        valid := False;
      if weaponMode = 1 then
        if (cur = underCursor)
           or ((crIdx = 0) and (terrIdx = C_TERR.CORPSE)) then
          valid := False
        else if not CbtActs.WeaponCanStrike(cur) then
          valid := False;
    end else if ground = 0 then
      valid := False;
    menu := 'Center Exit';
    if valid then
      menu := 'Target ' + menu;
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, promptColor, optionColor, commandColor, True, False,
                                  doneRoundFlag);
    case ch of
      'T':
        begin
          GameVars.arenaPtr^.cursorOn := False;
          if valid then begin
            sel.x := cx;
            sel.y := cy;
            if underCursor <> nil then
              sel.cr := underCursor
            else
              sel.cr := nil;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cur, sel.cr, weaponMode, done, sel)
            else
              done := True;
          end;
          if (valid = False) or (done = False) then begin
            CbtMap.RedrawArenaCell(cx, cy);
            done := False;
            FillChar(sel, SizeOf(sel), 0);
          end;
        end;
      C_KEYS.NONE, 'E':
        begin
          CbtMap.RedrawArenaCell(cx, cy);
          FillChar(sel, SizeOf(sel), 0);
          done := False;
        end;
      'C':
        begin
          CbtMap.ScrollView(cx, cy, 0, C_DIR.CENTER);
          dir := C_DIR.CENTER;
        end;
    else
      dir := CbtActs.DirOfKey(ch);
    end;
  end;
end;

{ Run target selection, allowing cycling, manual aim and confirmation. tgt is a TAimTarget passed as an untyped var
  parameter. weaponMode is 1 for weapon attacks or 0 for spell casting. range 255 means the equipped weapon's range
  minus 1 (1 unarmed); targets the creature may not attack are skipped. Next and Prev step through the creatures
  AimCycles keeps: with Aim Cycles at ENEMIES the creature and its enemies, or for allies (a spell that is not
  offensive) its own side; Manual and the cursor keys still reach anyone (#1137). The aim starts on the creature's
  current target when the list holds it on the side wanted, else on the nearest enemy, or for allies on the creature
  itself. }
procedure CombatAimMenu(creature: Types.PCharRecord; range, weaponMode, groundOk: Byte; allies: Boolean;
                        var done: Boolean; var tgt);
var
  targets: Types.TTargetList;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  skipStep: ShortInt;
  menuStep: ShortInt;
  curX: ShortInt;
  curY: ShortInt;
  nextX: ShortInt;
  nextY: ShortInt;
  p: Types.PCharRecord;
  ch: Char;
  keyDir: Byte;

  { Build the parent routine's aiming list from targets within range 127 that AimCycles keeps; when it keeps none, every
    one, as SSI's list was. curIdx stays within the list. }
  procedure BuildAimTargets(c: Types.PCharRecord);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127, 255, CbtMap.GetIconSize(c),
                            GameVars.arenaPtr);
    tgtCount := 0;
    for i := 1 to GameVars.targetCount do
      if CbtActs.AimCycles(c, GameVars.creatureArr[GameVars.targetList[i].idx], allies) then begin
        Inc(tgtCount);
        targets[tgtCount] := GameVars.targetList[i];
      end;
    if tgtCount = 0 then begin
      tgtCount := GameVars.targetCount;
      for i := 1 to tgtCount do
        targets[i] := GameVars.targetList[i];
    end;
    if (curIdx < 1) or (curIdx > tgtCount) then
      curIdx := 1;
  end;

  { The list entry the aim starts on: the creature's current target (combatAddr^.other) on the side wanted, the enemies
    or for allies the creature's own; else the nearest enemy (the list goes nearest first), or for allies the creature
    itself; else the first. }
  function AimStart(c: Types.PCharRecord): Byte;
  var
    i: Byte;
    other: Types.PCharRecord;
    current: Byte;
    nearest: Byte;
    own: Byte;
  begin
    current := 0;
    nearest := 0;
    own := 0;
    for i := tgtCount downto 1 do begin
      other := GameVars.creatureArr[targets[i].idx];
      if other = c then
        own := i
      else if other <> nil then
        if (other^.hostile = c^.hostile) = allies then begin
          nearest := i;
          if other = c^.combatAddr^.other then
            current := i;
        end;
    end;
    if current = 0 then
      if allies then
        current := own
      else
        current := nearest;
    if current = 0 then
      current := 1;
    AimStart := current;
  end;

  { Move the aim highlight step entries through the list (wrapping) and return that creature; animate flies the cursor
    from the current target, otherwise the old cursor cell is redrawn. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCharRecord;
  begin
    if animate then begin
      curX := GameVars.arenaLoc[targets[curIdx].idx].x;
      curY := GameVars.arenaLoc[targets[curIdx].idx].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then
      curIdx := tgtCount;
    if curIdx > tgtCount then
      curIdx := 1;
    AdvanceAimTarget := GameVars.creatureArr[targets[curIdx].idx];
    nextX := GameVars.arenaLoc[targets[curIdx].idx].x;
    nextY := GameVars.arenaLoc[targets[curIdx].idx].y;
    if animate then begin
      CharDisp.CombatAnimateMovingIcon(curX, curY, nextX, nextY, 1, 0);
      curX := nextX;
      curY := nextY;
    end;
  end;

begin
  { the aim cursor icon }
  CharDisp.CopyIconFacing(25, 0, 0, False);
  FillChar(tgt, SizeOf(Types.TAimTarget), 0);
  done := False;
  effRange := range;
  if effRange = 255 then
    if creature^.equipped[C_EQUIP.WEAPON] <> nil then
      effRange := CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.range - 1
    else
      effRange := 1;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  curIdx := 1;
  BuildAimTargets(creature);
  curIdx := AimStart(creature);
  skipStep := 0;
  p := AdvanceAimTarget(skipStep, True);
  skipStep := 1;
  { Exit or Escape as the first choice moves nowhere }
  menuStep := 0;
  ch := ' ';
  while (done = False) and (not (ch in [C_KEYS.NONE, 'E'])) do
  begin
    if not CbtActs.CanTarget(creature, p, True) then
      p := AdvanceAimTarget(skipStep, False)
    else begin
      ch := CbtActs.AimTargetMenu(creature, p, effRange, weaponMode, keyDir);
      { a cursor key goes straight to manual aim }
      if keyDir <> C_DIR.CENTER then
        ch := 'M';
      case ch of
        'N':
          begin
            skipStep := 1;
            menuStep := 1;
          end;
        'P':
          begin
            skipStep := -1;
            menuStep := -1;
          end;
        'M':
          begin
            CbtActs.ManualAimCursor(creature, p, effRange, weaponMode, groundOk, keyDir, done,
                                    Types.TAimTarget(tgt));
            CharDisp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'T':
          begin
            CbtActs.ConfirmAttackTarget(creature, p, weaponMode, done, Types.TAimTarget(tgt));
            CharDisp.CopyIconFacing(25, 0, 0, False);
            BuildAimTargets(creature);
            menuStep := 0;
          end;
        'C':
          begin
            CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, C_DIR.CENTER);
            menuStep := 0;
          end;
      end;
      CbtMap.RedrawArenaCell(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p));
      p := AdvanceAimTarget(menuStep, (done = False) and (not (ch in [C_KEYS.NONE, 'E'])));
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Make sure combatAddr^.other holds a target. An existing lock is kept (without a range check) unless forceNew is set or
  it is now an ally, disabled or vetoed by CanTarget. Otherwise make up to 20 random picks among the enemies
  within range, dropping vetoed ones. If that fails a second pass repeats it, with the arena's distMode set (terrain no
  longer blocks) unless forceNew; there relaxed <> 0 accepts a pick without CanTarget. }
function AcquireTarget(creature: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCharRecord;
begin
  pass := False;
  found := False;
  second := False;
  p := creature^.combatAddr^.other;
  { Drop the lock when forceNew is set or the locked target is no longer valid; a nil lock skips the checks }
  if (forceNew <> 0) or
      ((p <> nil) and
       ((p^.hostile = creature^.hostile) or (p^.enabled = 0) or (not CbtActs.CanTarget(creature, p, True)))) then
    creature^.combatAddr^.other := nil;
  if creature^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GameVars.arenaPtr^.distMode := 1;
    tries := 20;
    cnt := CbtMap.CountTargets(creature, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      pick := Dice.RollDice(1, cnt);
      if GameVars.combatTargetSlots[pick] > 0 then begin
        p := GameVars.creatureArr[GameVars.combatTargetSlots[pick]];
        if ((relaxed <> 0) and (GameVars.arenaPtr^.distMode <> 0))
           or CbtActs.CanTarget(creature, p, True) then begin
          found := True;
          creature^.combatAddr^.other := p;
        end else begin
          GameVars.combatTargetSlots[pick] := 0;
          { pick is reused as the index: do any targets remain? }
          for pick := 1 to cnt do
            if GameVars.combatTargetSlots[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GameVars.arenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

{ C_EFFECT.REAR_CLAW_RAKE (73) handler (TEffectHandler shape; p and removed unused): when both primary attacks hit
  (hitsMade[1] = 2) and the locked target is still up, rake it with two 2d4 secondary attacks, then end the creature's
  actions. The target sees the rake, in the Bestiary (#1142). }
procedure AttackClawRake(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
begin
  if hitsMade[1] = 2 then
    if creature^.combatAddr^.other^.enabled <> 0 then begin
      creature^.combatAddr^.attackPhase := 2;
      creature^.curAttacks2 := 2;
      creature^.curRollsA[2] := 2;
      creature^.curDiceA[2] := 4;
      creature^.curAttacks := 0;
      CharDisp.PrintNameString(creature, 'Rakes...', 10, True);
      Bestiary.Learn(creature, creature^.combatAddr^.other, C_BEAST.ATK_RAKE);
      CbtActs.MakeAttack(creature, creature^.combatAddr^.other, False, nil, done);
      done := CharHlp.EndActions(creature);
    end;
end;

{ C_EFFECT.BITE_HOLD (74) handler; p is the effect, whose strength holds the victim's creature index. While the hold
  lasts, each trigger is one 3d4 bite on the victim as from behind, ending the creature's actions; a victim that drops
  ends the hold. On removal, when either side is down or when the victim is no longer immobile (#709), the victim loses
  C_EFFECT.IMMOBILE (58), and the hold itself is removed (onRemove cleared first) unless it is already being removed. An
  index outside creatureArr[1..arenaCount] (CombatSlot's 0 for a creature not in the arena) has no victim: the hold just
  goes, as in EffHndlr.EffBloodDrain. }
procedure BiteAndHold(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  done: Boolean;
  released: Boolean;
begin
  if FxEngine.HoldTarget(creature, p, removed, C_EFFECT.BITE_HOLD, released) <> nil then begin
    creature^.curAttacks := 1;
    creature^.curAttacks2 := 0;
    creature^.curRollsA[1] := 3;
    creature^.curDiceA[1] := 4;
    CbtActs.MakeAttack(creature, GameVars.combatTarget, True, nil, done);
    done := CharHlp.EndActions(creature);
    if GameVars.combatTarget^.enabled = 0 then
      FxEngine.RemoveEffect(creature, C_EFFECT.BITE_HOLD, p);
  end;
end;

{ Alt-X cheat, active only when the first command-line parameter is STING: every hostile drops dead, every creature's
  actions end and the view is rebuilt. Returns False without STING. }
function VictoryCheat: Boolean;
var
  done: Boolean;
  p: Types.PCharRecord;
  slot: Byte;
begin
  VictoryCheat := False;
  if not GameVars.stingArg then
    Exit;
  VictoryCheat := True;
  CharDisp.PrintBottomLine('The Gods intervene!');
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.hostile = 1 then begin
      p^.enabled := 0;
      p^.status := C_STATUS.DEAD_STATUS;
      slot := CbtMap.CombatSlot(p);
      { slot 0: not on the map }
      if slot > 0 then
        GameVars.arenaLoc[slot].size := 0;
    end;
    done := CharHlp.EndActions(p);
    p := p^.nextCharAddr;
  end;
  CbtMap.ScrollView(CbtMap.CenterX, CbtMap.CenterY, 255, C_DIR.CENTER);
end;

function AreaHitsNonEnemy(x, y: ShortInt; radius: Byte): Boolean;
var
  i: Byte;
begin
  AreaHitsNonEnemy := False;
  Pathing.BuildAreaList(x, y, radius);
  for i := 1 to GameVars.targetCount do
    if CharHlp.Team(GameVars.creatureArr[GameVars.targetList[i].idx]) <> CharHlp.EnemyTeam(GameVars.curChar) then
      AreaHitsNonEnemy := True;
end;

function LeadershipBase(lvl: ShortInt): Byte;
begin
  if lvl >= 8 then
    LeadershipBase := 80
  else if lvl >= 4 then
    LeadershipBase := 40
  else if lvl >= 1 then
    LeadershipBase := 20
  else
    LeadershipBase := 0;
end;

function LeadershipChance(paladin: Types.PCharRecord): Byte;
var
  chance: Byte;
begin
  chance := CbtActs.LeadershipBase(CharHlp.GetClassLevel(paladin, C_LEVEL.PALADIN_BIT));
  if paladin^.chaCur > 13 then
    Inc(chance, (paladin^.chaCur - 13) * 5);
  LeadershipChance := chance;
end;

function CanLead(p: Types.PCharRecord): Boolean;
begin
  CanLead := not CharHlp.IsNpc(p) and (CharHlp.Team(p) = 0) and
    (CharHlp.GetClassLevel(p, C_LEVEL.PALADIN_BIT) > 0) and (p^.status = C_STATUS.OKAY) and (p^.enabled <> 0);
end;

function CanBeLed(p: Types.PCharRecord): Boolean;
begin
  CanBeLed := CharHlp.IsNpc(p) and (CharHlp.Team(p) = 0) and (p^.quickfight <> 0) and
    (p^.status = C_STATUS.OKAY) and (p^.enabled <> 0) and (p^.intCur > 3);
end;

function TryLead(paladin, npc: Types.PCharRecord; roll: Byte): Boolean;
var
  leads: Boolean;
begin
  leads := roll < CbtActs.LeadershipChance(paladin);
  if leads then begin
    npc^.quickfight := 0;
    npc^.combatAddr^.led := 1;
  end;
  TryLead := leads;
end;

procedure UseLeadership;
const
  { the window's row for the first "leads" line, and the last row one may start on }
  FIRST_ROW = 3;
  LAST_ROW = 19;
var
  paladin: Types.PCharRecord;
  npc: Types.PCharRecord;
  row: Byte;
  c: Char;
  ext: Boolean;
begin
  if GameVars.demoMode then Exit;
  row := 0;
  paladin := GameVars.creatureList;
  while paladin <> nil do begin
    if CbtActs.CanLead(paladin) then begin
      npc := GameVars.creatureList;
      while npc <> nil do begin
        if CbtActs.CanBeLed(npc) then
          if CbtActs.TryLead(paladin, npc, Dice.RollDice(1, 100)) then begin
            if (row = 0) or (row > LAST_ROW) then begin
              if row > LAST_ROW then
                c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White, True, False, ext);
              Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, LightMagenta,
                                'Using leadership ability');
              row := FIRST_ROW;
            end;
            TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, row, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, White, True,
                                          paladin^.name + ' leads ' + npc^.name + '.');
            Inc(row, 2);
          end;
        npc := npc^.nextCharAddr;
      end;
    end;
    paladin := paladin^.nextCharAddr;
  end;
  if row > 0 then
    c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White, True, False, ext);
end;

begin
  { Turbo Pascal clears no variable }
  suppressTargeting := 0;
  aimSpell := C_SPELL.NONE;
  FillChar(hitsMade, SizeOf(hitsMade), 0);
  hostileHpPct := 0;
  doneRoundFlag := False;
end.
