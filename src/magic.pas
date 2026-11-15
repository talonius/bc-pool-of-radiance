{ Spell selection, casting, targeting and spell-specific behavior. }
{$O+,F+}
{$I COMPILER.INC}
unit Magic;

interface

{ Types supplies PCharRecord, PItemRec, PEffectRec, TStr40 and TCellList for the declarations below. }
uses Types;

var
  { Optional callback that redraws the caller-owned area below a memorization
    list. SpellSelection invokes it when the list opens and after returning
    from a spell-information page. }
  belowListHook: Types.TIdleProc;
  { combat arena column, 0..Types.ARENA_LAST_X }
  gTargetX: ShortInt;
  { combat arena row, 0..Types.ARENA_LAST_Y }
  gTargetY: ShortInt;

{ Runs the selection menu for the list built by GenerateSpellList. selType is
  1 to cast, 2 to memorize, 3 to scribe, 4 to learn after gaining a level,
  and 5 to display the list without prompting. Other values create a read-only
  list. Long lists use the full-paging behavior from MenuCore (#900).

  idx preserves the cursor between calls; a negative value resets the display
  and starts at the first spell. Except in display-only mode, the highlighted
  spell has a summary and an Info command that opens SpellInf.ShowPage (#839).
  Scroll entries use the scroll's caster level.

  Returns the selected spell ID, or 0 on Exit. scroll receives the source
  scroll for an item spell and nil for a memorized spell. Scribe mode also sets
  currentScrollPtr. The global spellList is freed before returning. }
function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;

{ Builds spellList and spellIds for creature. menuType selects memorized spells
  (0), the spell book (1), the current scroll (2), all readable items (3),
  spells offered after gaining a level (4), pending memorization (5), pending
  scribing (6), or everything currently castable (7). Every list runs level by
  level, each level's heading once with its spells under it (#1199). Returns
  True only when the finished list contains a spell; heading-only lists are
  freed. }
function GenerateSpellList(creature: Types.PCharRecord; menuType: Byte): Boolean;

{ Line n (0 the first, headings counted) of the list GenerateSpellList last built, '' past its end; the unit tests
  read the list with it. }
function SpellListLine(n: Byte): Types.TStr40;

{ Selects targets outside combat. Target mode 1 selects the caster, mode 2 asks
  for a party member, and mode 4 selects the entire creature list. Any other
  mode cancels the cast. b is unused but required by Types.TCastUi. }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Casts spell for GameVars.curChar. Combat-only spells cannot be cast while
  exploring; the player may instead discard a memorized copy or use an item.
  Otherwise this announces the spell, obtains targets through castTargetMenu,
  applies spell-failure checks, animation, invisibility removal, and resource
  consumption, then calls the handler in GameVars.spellFns.

  b enables automatic targeting for AI or Quick mode. In manual combat the
  player may retry targeting or confirm an abort. sel reports whether targets
  were selected. A failed clerical spell still consumes its memorized copy
  (#60); item spells are consumed by their own item-handling path. }
procedure CastSpell(spell: Byte; b, announce: Boolean; var sel: Boolean);

{ Cast's refusal of a combat-only spell outside combat: show the spell's name and 'is a combat-only spell...' in the
  message window. }
procedure ShowCombatOnlySpell(spell: Byte);

{ Counts readable copies of spell on creature's scrolls and chooses the scroll
  with the fewest spells remaining. Inventory order breaks ties, so a partial
  scroll is exhausted before a full one is started (#833). best is nil when no
  usable scroll contains the spell. }
procedure FindScrollCopies(creature: Types.PCharRecord; spell: Byte; var copies: Byte; var best: Types.PItemRec);

{ Removes one copy of spell from a scroll and updates its displayed spell
  count. Exact pending-state matches are preferred so scribing removes the
  queued copy while casting preserves queued copies (POR-0228). The scroll is
  removed from cr when its count reaches zero. }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Announces a cast. Combat uses the standard "Casts a Spell" message and logs
  the spell name (#841); exploration uses msg, pauses, and clears the message
  window afterward. }
procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Remove Curse (spellFns[43], also called by Temple): remove Bestow Curse (effect 36) from spellTargets[1], or
  else clear the curse on its first cursed item. }
procedure SpellRemoveCurse;

{ Spell handlers: each acts on GameVars.curChar, spellTargets and spellId; GameInit.InitSpellFns maps
  spell IDs to them }
procedure SpellBless;

procedure SpellCurse;

procedure SpellCureLightWounds;

procedure SpellCauseLightWounds;

procedure SpellDetection;

procedure SpellProtection;

procedure SpellResistCold;

procedure SpellBurningHands;

procedure SpellCharmPerson;

procedure SpellEnlarge;

procedure SpellReduce;

procedure SpellFriends;

procedure SpellMagicMissile;

procedure SpellShield;

procedure SpellShockingGrasp;

procedure SpellSleep;

procedure SpellHold;

procedure SpellResistFire;

procedure SpellSilence;

procedure SpellSlowPoison;

procedure SpellSnakeCharm;

procedure SpellSpiritualHammer;

procedure SpellInvisibility;

procedure SpellKnock;

procedure SpellMirrorImage;

procedure SpellRayOfEnfeeblement;

procedure SpellStinkingCloud;

procedure SpellStrength;

procedure SpellAnimateDead;

procedure SpellCureBlindness;

procedure SpellCauseBlindness;

procedure SpellCureDisease;

procedure SpellCauseDisease;

procedure SpellDispelMagic;

procedure SpellPrayer;

procedure SpellBestowCurse;

procedure SpellBlink;

procedure SpellFireball;

procedure SpellHaste;

procedure SpellLightningBolt;

{ Calculates the arena cells crossed after the target by a lightning bolt or
  Javelin of Lightning, including bounces, or the cells of a cone spell (Fear,
  Cone of Cold) aimed there from the caster (TraceCone). This only traces the
  current arena; it does not draw or apply damage. }
procedure TraceBolt(spell: Byte; x, y: ShortInt; var cells: Types.TCellList);

procedure SpellSlow;

procedure SpellRestoration;

{ Restoration's change to tgt's record, without its messages: one drained level comes back (#1174). With an entry on
  the drain log (CharExt.PopDrain), its hit points come back, the class it lowered gains the level when it still may
  (RestorableClass), else the class RestoreClass picks, and the experience it cost is added to the experience tgt has
  now, which is at least the restored level's start. A level the log does not hold (an old save's, or one past its
  entries) is restored as SSI's was: drainedHps div drainedLevels hit points, the class RestoreClass picks, and the
  experience raised to that level's start if lower. False when tgt has no drained level. }
function RestoreLevel(tgt: Types.PCharRecord): Boolean;

{ True when Restoration may give tgt a level in class cls: tgt has the class, it is not one a dual-classed human has
  left, it has a next level in the experience table, and it is not at its racial cap (CharHlp.AtLevelCap). }
function RestorableClass(tgt: Types.PCharRecord; cls: ShortInt): Boolean;

{ The class Restoration gives a level the drain log does not hold: scanning classes 0..7, a RestorableClass becomes
  the pick when its level is not above the current pick's and its next-level XP is smaller. -1 when there is none. }
function RestoreClass(tgt: Types.PCharRecord): ShortInt;

{ The levels each class of creature has lost to energy drains, as the View page marks them (#1161): an entry on the
  drain log counts for the class it lowered; a drained level the log does not hold counts for the class Restoration
  would give it to (RestoreClass, after the logged levels have come back). }
procedure DrainedByClass(creature: Types.PCharRecord; var counts: Types.TClassCounts);

procedure SpellPotionOfSpeed;

procedure KeoghtomsOintmentHandler;

procedure SpellGiantStrength;

procedure SpellJavelinOfLightning;

procedure SpellWandOfParalyzation;

procedure SpellPotionOfHealing;

procedure SpellDustOfDisappearance;

procedure SpellWandOfMagicMissiles;

procedure UnusedSpellHandler;

procedure ManualBodilyHealthHandler;

{ The spells of levels 4 and 5 and the druid's first (#1121), ported from Curse's Magic at Curse's ids. }

{ Cure Serious Wounds (58): the target regains 2d8+1 hit points. }
procedure SpellCureSeriousWounds;

{ Cause Serious Wounds (66): a touch, with an attack roll, for 2d8+1 magic damage. }
procedure SpellCauseSeriousWounds;

{ Neutralize Poison (67): the target's poison and Slow Poison end. A target poison put down gets up with at least 1 hit
  point; one the poison killed comes back to life with 1, unless Slow Poison held the poison off, when a wound killed
  it. A stoned, disintegrated, fled or animated target is not brought back, and a target not poisoned is unaffected. }
procedure SpellNeutralizePoison;

{ Poison (68): a touch, with an attack roll; a creature touched saves against poison or dies of it, as a monster's
  poisonous bite kills (C_EFFECT.POISON_HIT0), unless it resists the spell (FxEngine.EffectImmune). }
procedure SpellPoison;

{ Sticks to Snakes (70): a target below level 6 fights snakes, as many as the caster's level, until they are gone
  (C_EFFECT.STICKS_TO_SNAKES), and spends this round's actions on them at once; a stronger one smashes them flat. }
procedure SpellSticksToSnakes;

{ Cure Critical Wounds (71): the target regains 3d8+3 hit points. }
procedure SpellCureCriticalWounds;

{ Cause Critical Wounds (72): a touch, with an attack roll, for 3d8+3 magic damage. }
procedure SpellCauseCriticalWounds;

{ Dispel Evil (73): for its duration the caster is attacked at -7 by evil creatures Dispel Evil reaches
  (C_EFFECT.DISPEL_EVIL), and one it hits may be dispelled (C_EFFECT.DISPEL_EVIL_TOUCH). }
procedure SpellDispelEvil;

{ Flame Strike (74): 6d8 fire damage to one target, half on a save. }
procedure SpellFlameStrike;

{ Raise Dead (75), in camp: a dead or animated target that is no elf and has Constitution left rolls resurrection
  survival on it (AbilAdj.ConResurrectionSurvival). It comes back okay at 1 hit point, its Animate Dead and poison gone,
  at a point of Constitution while it has more than 3 (ClassCal.LoseConstitution); one that fails is gone for good, as
  the 1st-edition PHB and the temple have it (Curse left it to be raised again). A dead target still poisoned is not
  raised, as the poison would kill it again. }
procedure SpellRaiseDead;

{ Slay Living (76): a living target (not undead) that does not resist the spell saves against death magic or is
  slain; one that saves takes 2d8+1 magic damage. }
procedure SpellSlayLiving;

{ Entangle (78): outdoors, every creature in the area not entangled already is held fast by the plants, or, if it
  saves, slowed to half its movement (C_EFFECT.ENTANGLE). Indoors there are no plants and the spell is lost. }
procedure SpellEntangle;

{ Faerie Fire (79): the targets bought from the pool (CbtActs.SelectCombatTargets) are outlined, with no save. }
procedure SpellFaerieFire;

{ Invisibility to Animals (80): the target is hidden from animals (C_EFFECT.INVISIBLE_TO_ANIMALS). }
procedure SpellInvisibilityToAnimals;

{ Charm Monsters (81): the targets bought from the pool (CbtActs.SelectCombatTargets) that fail their saves are
  charmed onto the caster's side, as Charm Person charms, of any kind or size. }
procedure SpellCharmMonsters;

{ Confusion (82): up to 2d8 of the creatures in the area that fail their saves are confused (C_EFFECT.CONFUSION). }
procedure SpellConfusion;

{ Dimension Door (83): the caster steps to the open cell aimed at, breaking any hold on it; a cell it does not fit
  leaves it where it was. }
procedure SpellDimensionDoor;

{ Fear (84): each creature in the cone (C_SPELL.FEAR_CONE_RAYS rays, FEAR_CONE_CELLS long) that fails its save flees
  in terror (C_EFFECT.FEAR, EffHndlr.StartFear). }
procedure SpellFear;

{ Fire Shield (85): the caster picks hot or cold flames (the AI either at random), which guard it against the other
  element, burn melee attackers and leave it open to their own (C_EFFECT.FIRE_SHIELD_HOT, FIRE_SHIELD_COLD,
  FIRE_SHIELD_ZAP). Any key but H or C asks whether to abort the spell. }
procedure SpellFireShield;

{ Fumble (86): a target that fails its save is clumsy and can do nothing (C_EFFECT.FUMBLE); one that saves is slowed
  instead. }
procedure SpellFumble;

{ Ice Storm (87): 3d10 cold damage to everything in the area, with no save. }
procedure SpellIceStorm;

{ Minor Globe of Invulnerability (88): spells of level 3 and below no longer reach the caster (C_EFFECT.MINOR_GLOBE). }
procedure SpellMinorGlobe;

{ Cloudkill (91, #1193): a 3x3 cloud round the aim cell (CbtMap.CloudCell) for a round per caster level, laid as
  Stinking Cloud's is on the GameVars.cloudHead list, tracked by the caster's C_EFFECT.CAST_CLOUDKILL and shown as
  C_TERR.CLOUDKILL; each creature inside then meets it once (ConsiderCloudkill). }
procedure SpellCloudkill;

{ A Cloudkill's turn on creature (#1193), when any of its cells is in one (CbtMap.ProbeTerrain) and it is enabled and
  not CloudkillProof: by FxEngine.CloudkillFate it is poisoned and killed, or saves vs. poison (with the save's
  modifier and its Constitution's poison bonus) or is poisoned and killed, or takes 1d10 poison damage. A save leaves
  it "Unaffected". It runs where a stinking cloud's does: on the creatures inside when the cloud is laid, at each
  round's end and after each step. Magic resistance does not stop it, nor does it in Curse: the cloud is poison in the
  air, not a spell on the creature. }
procedure ConsiderCloudkill(creature: Types.PCharRecord);

{ Cone of Cold (92): caster level + caster level d4 cold damage to each creature in the cone (C_SPELL.COLD_CONE_RAYS
  rays, half the caster level long, rounded up), half on a save. }
procedure SpellConeOfCold;

{ Feeblemind (93): a target that fails its save, a magic-user's at -4, a cleric's at +1 and any other's at -2
  (1st-edition PHB), can no longer cast until a temple heals it (C_EFFECT.FEEBLEMIND). }
procedure SpellFeeblemind;

{ The cone a spell aimed from (ox, oy) at (tx, ty) covers, rays lines reach cells long (Curse's cone): its centre line
  runs on past the aim to the full reach, stopped by walls, and with rays 2 or 3 one or two side lines run beside it.
  CollectConeTargets makes the creatures on it, the caster excepted, the spell's targets; TraceCone lists its cells for
  the spell-aim preview. A cone aimed at its own origin covers nothing. }
procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte);
procedure TraceCone(ox, oy, tx, ty: ShortInt; rays, reach: Byte; var cells: Types.TCellList);

{ The cone spell's rays and reach: Fear's, or Cone of Cold's at the caster's level. }
procedure ConeShape(spell: Byte; var rays, reach: Byte);

{ Bronze dragon breath, installed as effect 88's handler, so it has FxEngine's effect-handler signature }
procedure DragonBreathHandler(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Generate the spell list for menuType (0 in memory, 1 spell book, 2 scroll, 3 scrolls, 4 choosing a spell on gaining a
  level, 5 to be memorized, 6 to be scribed, 7 available to cast) and run Magic.SpellSelection on it, returning the
  chosen spell, or 0 when the list is empty. idx < 0 also draws the heading, "<name>'s Spells" on every list (#900);
  notEmpty receives whether the list has entries. }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ The Cast menu (SpellMenu 7, select 1): the spell chosen, as SpellMenu returns it, with scroll the scroll it is cast
  from (nil for a memorized spell). }
function CastSpellMenu(var idx: Integer; var notEmpty: Boolean; var scroll: Types.PItemRec): Byte;

procedure UseItemSpell(item: Types.PItemRec; spell: Byte; announce: Boolean; var done: Boolean);

{ Spend what casting spell from item cost user: a scroll's copy of the spell (RemoveSpellFromScroll), or else one of
  the item's quantity and then a charge, the item going when its charges run out. An item with no charges spends
  nothing. Use and Fix share it. }
procedure SpendItemSpell(user: Types.PCharRecord; item: Types.PItemRec; spell: Byte);

{ Cast spell from user's item at target, with no menu or question, as Fix does (#1129): the spell's handler runs with
  user as the caster (GameVars.curChar for the cast) and target its one target, at the item caster level
  (GameVars.usingItem), and the item is spent (SpendItemSpell). The handler says what it did. }
procedure CastItemSpellOn(user: Types.PCharRecord; item: Types.PItemRec; spell: Byte; target: Types.PCharRecord);

procedure UseItem(item: Types.PItemRec; var done: Boolean);

const
  { a spell list's markers, in the indent column (SpellMark): none; KNOWN_MARK on a spell already in the creature's
    spell book; or NOT_KNOWN_MARK on a spell the creature's classes could learn but its spell book lacks }
  MARK_NONE = 0;
  MARK_KNOWN = 1;
  MARK_NOT_KNOWN = 2;
  KNOWN_MARK = '-';
  NOT_KNOWN_MARK = '+';

{ The indent-column marker for spell (bit 7 ignored) on a spell list, otherwise a blank: KNOWN_MARK for MARK_KNOWN when
  creature's spell book has it; NOT_KNOWN_MARK for MARK_NOT_KNOWN when the spell book lacks a spell creature's classes
  could learn. A class could learn a spell of its own (castClass 0 needs a cleric level, castClass 1 a magic-user level)
  at spell level 1..Types.CASTER_LEVEL_LAST, the levels a character has slots for, whatever the character's current
  level. An ID that is no spell (CharHlp.IsSpell) gets a blank. }
function SpellMark(creature: Types.PCharRecord; spell, mark: Byte): Char;

{ A spell list's line for spell (#900): two blanks, the marker in the third column and the spell's name, so the name
  sits indented under its level heading. Bit 7 set (pending memorization or scribing) puts '*' in the marker column;
  otherwise it holds SpellMark's character for mark. The magic shop's scroll lists its spells the same way (#1196). }
function SpellLine(creature: Types.PCharRecord; spell, mark: Byte): Types.TStr40;

{ A spell list's heading for spell level level, '1st Level' to '9th Level'; '' for any other level. }
function LevelHeading(level: Byte): Types.TStr40;

implementation

uses Stats, CharDisp, C_SOUND, C_ITEM, Dice, Crt, C_NPC, C_TERR, C_SAVE, C_COND, GameDefs, GameVars, TextRend, Border,
  CharHlp, SoundDrv, MenuCore, Pathing, CbtMap, ClassCal, FxEngine, C_EFFECT, C_KEYS, C_LEVEL, C_STATUS, C_IFC, C_DIR,
  C_SPELL, AbilAdj, StrUtil, ChgClass, SpellInf, CbtLog, C_SPRITE, Bestiary, C_BEAST, CharExt, C_RACE, EffHndlr,
  UiColor;

var
  { the menu string list }
  spellList: Types.PItemRec;
  { spell ID per menu line }
  spellIds: array[0..C_SPELL.LINE_LAST] of Byte;
  { the scroll each Cast line reads from, nil for a memorized spell }
  spellScrolls: array[0..C_SPELL.LINE_LAST] of Types.PItemRec;
  scrollPtrs: array[0..48] of Types.PItemRec;
  scrollCount: Byte;
  { Current item used for spell casting. }
  currentScrollPtr: Types.PItemRec;
  { the list is one scroll's spells (GenerateSpellList's menu 2, read with Use), each cast from the scroll }
  scrollList: Boolean;

const
  { a Cast line's scroll marker, in the indent column just before the spell name }
  SCROLL_MARK = '-';
  { the highest spell level in spellTable (Restoration's 7) }
  SPELL_LEVEL_LAST = 7;
  { the columns a spell list's line has, from the list window's left edge to its right }
  LINE_WIDTH = 38;
  { a spell line's marker column, in the indent before its name (#900): a level heading starts in the list's first
    column, and a spell's name three columns in }
  MARK_COL = 3;
  { Spell-list headings indexed by spell level }
  spellLevelNames: array[1..9] of String[9] = (
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');

procedure ShowCombatOnly(name: Types.TStr40; kind: Types.TStr20); forward;

procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
  forward;
procedure BoltShape(spell: Byte; var boltLen: Byte; var bounce: Boolean); forward;

{ The number of selectable lines (spells) before member n of spellList: its index in spellIds and spellScrolls. }
function LineBefore(n: Integer): Integer;
var
  p: Types.PItemRec;
  k: Integer;
  lines: Integer;
begin
  p := spellList;
  k := 0;
  lines := 0;
  while (p <> nil) and (k < n) do begin
    if p^.inUse = 0 then
      Inc(lines);
    p := p^.next;
    Inc(k);
  end;
  LineBefore := lines;
end;

{ Member n of spellList as SpellInf takes a list line: its spell id, with C_SPELL.FROM_ITEM set when it is read from a
  scroll (the one-scroll list, or a Cast line with a scroll); 0 for a level heading or past the list. }
function LineSpell(n: Integer): Word;
var
  p: Types.PItemRec;
  line: Integer;
begin
  LineSpell := 0;
  p := MenuCore.FindListMember(n, spellList);
  if (p <> nil) and (n >= 0) then
    if p^.inUse = 0 then begin
      line := Magic.LineBefore(n);
      if line <= C_SPELL.LINE_LAST then
        if scrollList or (spellScrolls[line] <> nil) then
          LineSpell := spellIds[line] or C_SPELL.FROM_ITEM
        else
          LineSpell := spellIds[line];
    end;
end;

{ Clear and frame the spell list's window, from C_SPELL.LIST_TOP down to windowRow; for memorize, also the spell
  slots' window under it, to C_SPELL.SUMMARY_ROW, filled by belowListHook (#900). }
procedure DrawListWindows(windowRow: Byte; memorize: Boolean);
begin
  Border.DrawWindow(1, C_SPELL.LIST_TOP, 38, windowRow, 0, Black, '');
  if memorize then begin
    Border.DrawWindow(1, C_SPELL.SLOTS_TOP, 38, C_SPELL.SUMMARY_ROW, 0, Black, '');
    if @belowListHook <> nil then
      belowListHook;
  end;
end;

{ Show the spell page for spellList's member idx, stepping through every spell on the list, then point idx at the
  spell it showed last, scrolled into the list's rows C_SPELL.LIST_TOP..lastRow as MenuVertical pages them
  (fullPaging), and draw the windows again (DrawListWindows). }
procedure SpellPage(var idx: Integer; lastRow, windowRow: Byte; memorize: Boolean);
var
  lines: SpellInf.TLineSpells;
  p: Types.PItemRec;
  n: Integer;
  count: Integer;
  cur: Integer;
  rows: Integer;
begin
  count := 0;
  cur := 0;
  p := spellList;
  n := 0;
  while p <> nil do begin
    if (p^.inUse = 0) and (count <= C_SPELL.LINE_LAST) then begin
      if n = idx then
        cur := count;
      lines[count] := Magic.LineSpell(n);
      Inc(count);
    end;
    p := p^.next;
    Inc(n);
  end;
  SpellInf.ShowPage(lines, count, cur);
  { back to the list, on the spell shown last }
  p := spellList;
  n := 0;
  while (p <> nil) and ((p^.inUse <> 0) or (Magic.LineBefore(n) < cur)) do begin
    p := p^.next;
    Inc(n);
  end;
  if p <> nil then
    idx := n;
  rows := MenuCore.PageRows(spellList, C_SPELL.LIST_TOP, lastRow, True);
  if idx < GameVars.verticalMenuTop then
    GameVars.verticalMenuTop := idx;
  if idx > GameVars.verticalMenuTop + rows - 1 then
    GameVars.verticalMenuTop := idx - rows + 1;
  Magic.DrawListWindows(windowRow, memorize);
end;

function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  count: Byte;
  { the list window's last row, the list's own, and the summary line's (0 for none) }
  windowRow: Byte;
  bottomRow: Byte;
  summaryRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
  moved: Boolean;
begin
  case selType of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := '';
  end;
  { the action names the screen on the bottom line: 'Cast: Cast Info Exit' (#900) }
  if title <> '' then
    prompt := title + ': '
  else
    prompt := '';
  case selType of
    2: begin
         windowRow := C_SPELL.MEMORIZE_LIST_BOTTOM;
         bottomRow := C_SPELL.MEMORIZE_LIST_BOTTOM;
         summaryRow := C_SPELL.SUMMARY_ROW;
       end;
    5: begin
         windowRow := C_SPELL.SUMMARY_ROW;
         bottomRow := C_SPELL.SUMMARY_ROW;
         summaryRow := 0;
       end;
  else
    begin
      windowRow := C_SPELL.SUMMARY_ROW;
      bottomRow := C_SPELL.LIST_BOTTOM;
      summaryRow := C_SPELL.SUMMARY_ROW;
    end;
  end;
  if summaryRow > 0 then
    if title = '' then
      title := 'Info'
    else
      title := title + ' Info';
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    Magic.DrawListWindows(windowRow, selType = 2);
    redraw := True;
    { open at the top of the list on its first spell, the line under the first level heading (MenuVertical, given the
      heading, would wrap up to the page's last line) }
    GameVars.verticalMenuTop := 0;
    idx := 0;
    p := spellList;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(idx);
    end;
    if p = nil then
      idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    if summaryRow > 0 then
      SpellInf.ShowSummary(Magic.LineSpell(idx), summaryRow);
    MenuCore.listOnly := selType = 5;
    MenuCore.movesToCaller := summaryRow > 0;
    MenuCore.fullPaging := True;
    ch := MenuCore.MenuVertical(prompt, title, promptColor, optionColor, commandColor, 1, C_SPELL.LIST_TOP, 38,
                                bottomRow, spellList, addExit, redraw, idx, sel);
    moved := MenuCore.moved;
    if not moved and (ch = 'I') and (summaryRow > 0) and (sel <> nil) then begin
      Magic.SpellPage(idx, bottomRow, windowRow, selType = 2);
      redraw := True;
    end;
  until not moved and (ch in [C_KEYS.NONE, C_KEYS.ENTER, 'C', 'E', 'L', 'M', 'S']);
  if summaryRow > 0 then
    SpellInf.ShowSummary(0, summaryRow);
  p := spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  scroll := nil;
  if (ch in [C_KEYS.NONE, 'E']) or (count > C_SPELL.LINE_LAST) then
    SpellSelection := C_SPELL.NONE
  else begin
    SpellSelection := spellIds[count];
    scroll := spellScrolls[count];
  end;
  if selType = 3 then
    { 48 = High(scrollPtrs) }
    if count <= 48 then
      currentScrollPtr := scrollPtrs[count]
    else
      currentScrollPtr := nil;
  MenuCore.FreeStringList(spellList);
end;

{ Append spell to spellList, first adding a level heading entry (inUse = 1, LevelHeading) when its spell level differs
  from the previous spell's. The spell's line is SpellLine's, indented under its heading (#900), with mark (MARK_NONE,
  MARK_KNOWN or MARK_NOT_KNOWN). Stores spell and $7F in spellIds at the entry's selectable index. }
procedure AddSpellToList(creature: Types.PCharRecord; spell, mark: Byte);
var
  p: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := spellList;
  if spellList = nil then begin
    { Allocate only a TMenuNode, the TItemRec prefix a MenuCore.MenuVertical entry uses (name, inUse and next); the rest
      of the record is never touched }
    GetMem(p, SizeOf(Types.TMenuNode));
    spellList := p;
    lastLevel := 0;
    count := 0;
  end else begin
    count := 1;
    while p^.next <> nil do begin
      if p^.inUse = 0 then
        Inc(count);
      p := p^.next;
    end;
    { a full list takes no more lines }
    if count > C_SPELL.LINE_LAST then
      Exit;
    lastLevel := GameDefs.spellTable[spellIds[count - 1]].levelSp;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GameDefs.spellTable[spell and C_SPELL.ID_MASK].levelSp <> lastLevel then begin
    p^.name := Magic.LevelHeading(GameDefs.spellTable[spell and C_SPELL.ID_MASK].levelSp);
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
  end;
  p^.name := Magic.SpellLine(creature, spell, mark);
  p^.inUse := 0;
  spellIds[count] := spell and C_SPELL.ID_MASK;
end;

function SpellLine(creature: Types.PCharRecord; spell, mark: Byte): Types.TStr40;
begin
  if spell > C_SPELL.ID_MASK then
    SpellLine := '  *' + GameDefs.spellNames[spell and C_SPELL.ID_MASK]
  else
    SpellLine := '  ' + Magic.SpellMark(creature, spell, mark) + GameDefs.spellNames[spell];
end;

function LevelHeading(level: Byte): Types.TStr40;
begin
  if (level >= 1) and (level <= 9) then
    LevelHeading := spellLevelNames[level]
  else
    LevelHeading := '';
end;

function SpellMark(creature: Types.PCharRecord; spell, mark: Byte): Char;
var
  id: Byte;
  learnable: Boolean;
begin
  SpellMark := ' ';
  id := spell and C_SPELL.ID_MASK;
  if CharHlp.IsSpell(id) then
    case mark of
      MARK_KNOWN:
        if CharHlp.KnowsSpell(creature, id) then
          SpellMark := KNOWN_MARK;
      MARK_NOT_KNOWN:
        if not CharHlp.KnowsSpell(creature, id) then begin
          learnable := False;
          with GameDefs.spellTable[id] do
            if (levelSp >= 1) and (levelSp <= Types.CASTER_LEVEL_LAST) then
              case castClassSp of
                C_SPELL.CLASS_CLERIC: learnable := CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT) > 0;
                C_SPELL.CLASS_MAGE: learnable := CharHlp.GetClassLevel(creature, C_LEVEL.MAGE_BIT) > 0;
              end;
          if learnable then
            SpellMark := NOT_KNOWN_MARK;
        end;
    end;
end;

{ Add currentScrollPtr's spells of spell level lvl to the list (forScribe: only those queued for scribing, id > $80),
  each with mark, and record the scroll in scrollPtrs for each while scrollPtrs has room. Read Magic (effect 16), or
  any cleric level with a scroll whose base item slot is 12, identifies the scroll first; an unidentified scroll adds
  nothing. A slot whose spell is past the spell table (CharHlp.ScrollSpellAt gives none) is skipped, so corrupt item
  data cannot index the tables past their ends (#922). }
procedure AddScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte; lvl: ShortInt);
var
  i: Byte;
  id: Byte;
begin
  if CharHlp.ScrollLegible(creature, currentScrollPtr) then
    for i := 1 to SizeOf(currentScrollPtr^.spells) do begin
      id := CharHlp.ScrollSpellAt(currentScrollPtr, i);
      if (id <> C_SPELL.NONE) and (not forScribe or (currentScrollPtr^.spells[i] > C_SPELL.PENDING_FLAG)) then
        if GameDefs.spellTable[id].levelSp = lvl then begin
          Magic.AddSpellToList(creature, currentScrollPtr^.spells[i], mark);
          { 48 = High(scrollPtrs) }
          if scrollCount <= 48 then begin
            scrollPtrs[scrollCount] := currentScrollPtr;
            Inc(scrollCount);
          end;
        end;
    end;
end;

{ Walk creature's inventory: each readable item becomes currentScrollPtr and feeds AddScrollSpells with forScribe, mark
  and lvl. currentScrollPtr itself is the loop variable, so it ends as nil. }
procedure AddAllScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte; lvl: ShortInt);
begin
  currentScrollPtr := creature^.itemsAddr;
  while currentScrollPtr <> nil do begin
    if CharHlp.ItemReadable(currentScrollPtr) then
      Magic.AddScrollSpells(creature, forScribe, mark, lvl);
    currentScrollPtr := currentScrollPtr^.next;
  end;
end;

{ Add ' (xN)' to spellList's last line when copies is two or more, cutting the spell's name when the line would run
  past LINE_WIDTH. }
procedure AddCopies(copies: Byte);
var
  p: Types.PItemRec;
  s: Types.TStr20;
begin
  if (copies < 2) or (spellList = nil) then Exit;
  p := spellList;
  while p^.next <> nil do
    p := p^.next;
  s := ' (x' + StrUtil.NumStr(copies) + ')';
  if Length(p^.name) + Length(s) > LINE_WIDTH then
    p^.name[0] := Chr(LINE_WIDTH - Length(s));
  p^.name := p^.name + s;
end;

{ The number of spells on scroll item. }
function ScrollSpellCount(item: Types.PItemRec): Byte;
var
  i: Byte;
  n: Byte;
begin
  n := 0;
  for i := 1 to SizeOf(item^.spells) do
    if CharHlp.ScrollSpellAt(item, i) <> C_SPELL.NONE then
      Inc(n);
  ScrollSpellCount := n;
end;

{ How many times spell is on the scrolls creature can read and use (CharHlp.CastableScroll), and the one of them to
  read it from: the scroll with the fewest spells on it, the first in the inventory among equals, so a part-used scroll
  is used up before a full one is started (#833). best is nil when no such scroll holds spell. }
procedure FindScrollCopies(creature: Types.PCharRecord; spell: Byte; var copies: Byte; var best: Types.PItemRec);
var
  item: Types.PItemRec;
  i: Byte;
  held: Byte;
  fewest: Byte;
begin
  copies := 0;
  best := nil;
  fewest := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if CharHlp.CastableScroll(creature, item) then begin
      held := 0;
      for i := 1 to SizeOf(item^.spells) do
        if CharHlp.ScrollSpellAt(item, i) = spell then
          Inc(held);
      if held > 0 then begin
        Inc(copies, held);
        if (best = nil) or (Magic.ScrollSpellCount(item) < fewest) then begin
          best := item;
          fewest := Magic.ScrollSpellCount(item);
        end;
      end;
    end;
    item := item^.next;
  end;
end;

{ Add spell to the Cast list as line number lines, read from scroll item (spellScrolls), with its copies counted
  (AddCopies), and count the line. SCROLL_MARK goes in the indent column before the name, in place of the '*' a spell
  queued for scribing gets. Nothing is added once the list is full. }
procedure AddScrollLine(creature: Types.PCharRecord; item: Types.PItemRec; spell, copies: Byte; var lines: Byte);
var
  p: Types.PItemRec;
begin
  if lines <= C_SPELL.LINE_LAST then begin
    Magic.AddSpellToList(creature, spell, MARK_NONE);
    spellScrolls[lines] := item;
    Inc(lines);
    p := spellList;
    while p^.next <> nil do
      p := p^.next;
    if Length(p^.name) >= MARK_COL then
      p^.name[MARK_COL] := SCROLL_MARK;
    Magic.AddCopies(copies);
  end;
end;

{ How many of creature's memorized-spell slots hold what slot i holds, or 0 when an earlier slot holds it too: a list of
  memorized spells shows each once, where its first slot falls, with the number of copies (#833). }
function MemorizedCopies(creature: Types.PCharRecord; i: Byte): Byte;
var
  j: Byte;
  n: Byte;
begin
  n := 0;
  for j := 0 to Types.MEMORIZED_LAST do
    if CharHlp.MemorizedAt(creature, j) = CharHlp.MemorizedAt(creature, i) then begin
      if j < i then begin
        MemorizedCopies := 0;
        Exit;
      end;
      Inc(n);
    end;
  MemorizedCopies := n;
end;

{ Add memorized slot i's spell to spellList as line number lines, once for all its copies (MemorizedCopies, counted by
  AddCopies), and count the line. Nothing is added for a slot an earlier one repeats, or once the list is full. }
procedure AddMemorizedSpell(creature: Types.PCharRecord; i: Byte; var lines: Byte);
var
  copies: Byte;
begin
  copies := Magic.MemorizedCopies(creature, i);
  if (copies = 0) or (lines > C_SPELL.LINE_LAST) then Exit;
  Magic.AddSpellToList(creature, CharHlp.MemorizedAt(creature, i), MARK_NONE);
  Inc(lines);
  Magic.AddCopies(copies);
end;

{ The Cast list, level by level: creature's memorized spells (not those still being memorized), each once with its
  copies counted (AddMemorizedSpell), then the spells on the scrolls creature can read and use (CastableScroll), each
  once in the order the inventory first holds them, marked with SCROLL_MARK and read from the scroll FindScrollCopies
  picks. In combat the memorized spells need castAllowed, as the Cast command does, and the scroll spells
  CharHlp.CanUseItems, as Use does. }
procedure AddAvailableSpells(creature: Types.PCharRecord);
var
  lvl: Byte;
  i: Byte;
  id: Byte;
  lines: Byte;
  memOk: Boolean;
  scrollOk: Boolean;
  item: Types.PItemRec;
  best: Types.PItemRec;
  copies: Byte;
  { the scroll spells already listed }
  listed: set of Byte;
begin
  listed := [];
  memOk := (GameVars.ifcState <> C_IFC.IN_COMBAT) or (creature^.combatAddr^.castAllowed <> 0);
  scrollOk := CharHlp.CanUseItems(creature);
  lines := 0;
  for lvl := 1 to SPELL_LEVEL_LAST do begin
    if memOk then
      for i := 0 to Types.MEMORIZED_LAST do begin
        id := CharHlp.MemorizedAt(creature, i);
        if CharHlp.IsSpell(id) then
          if GameDefs.spellTable[id].levelSp = lvl then
            Magic.AddMemorizedSpell(creature, i, lines);
      end;
    if scrollOk then begin
      item := creature^.itemsAddr;
      while item <> nil do begin
        if CharHlp.CastableScroll(creature, item) then
          for i := 1 to SizeOf(item^.spells) do begin
            id := CharHlp.ScrollSpellAt(item, i);
            if (id <> C_SPELL.NONE) and not (id in listed) then
              if GameDefs.spellTable[id].levelSp = lvl then begin
                listed := listed + [id];
                Magic.FindScrollCopies(creature, id, copies, best);
                Magic.AddScrollLine(creature, best, id, copies, lines);
              end;
          end;
        item := item^.next;
      end;
    end;
  end;
end;

{ The spell level of memorized slot i's spell, its pending flag ignored; 0 for an empty slot. }
function SlotLevel(creature: Types.PCharRecord; i: Byte): ShortInt;
var
  id: Byte;
begin
  id := CharHlp.MemorizedAt(creature, i) and C_SPELL.ID_MASK;
  if id = 0 then
    SlotLevel := 0
  else
    SlotLevel := GameDefs.spellTable[id].levelSp;
end;

function GenerateSpellList(creature: Types.PCharRecord; menuType: Byte): Boolean;
var
  i: Byte;
  p: Types.PItemRec;
  lines: Byte;
  lvl: ShortInt;
begin
  GenerateSpellList := False;
  spellList := nil;
  lines := 0;
  for i := 0 to C_SPELL.LINE_LAST do begin
    spellIds[i] := 0;
    spellScrolls[i] := nil;
  end;
  { every list starts with no scrolls recorded: High(scrollPtrs), 49 slots }
  for i := 0 to 48 do
    scrollPtrs[i] := nil;
  scrollCount := 0;
  scrollList := menuType = 2;
  if menuType = 7 then
    Magic.AddAvailableSpells(creature)
  else
    { level by level, so a level's heading comes once, its spells under it, though their ids run out of level order:
      the 4th- and 5th-level spells' ids (#1121) put the magic-user's Bestow Curse, 100, after the 5th level's (#1199) }
    for lvl := 1 to SPELL_LEVEL_LAST do
      case menuType of
        0: for i := 0 to Types.MEMORIZED_LAST do
             if (CharHlp.MemorizedAt(creature, i) > 0) and
                 (CharHlp.MemorizedAt(creature, i) < C_SPELL.PENDING_FLAG) and (Magic.SlotLevel(creature, i) = lvl) then
               Magic.AddMemorizedSpell(creature, i, lines);
        5: for i := 0 to Types.MEMORIZED_LAST do
             if (CharHlp.MemorizedAt(creature, i) > C_SPELL.ID_MASK) and (Magic.SlotLevel(creature, i) = lvl) then
               Magic.AddMemorizedSpell(creature, i, lines);
        { every known spell, Restoration (56) too: SSI stopped at 55 }
        1: for i := 1 to C_SPELL.LAST do
             if CharHlp.KnowsSpell(creature, i) and (GameDefs.spellTable[i].levelSp = lvl) then
               Magic.AddSpellToList(creature, i, MARK_NONE);
        { one scroll's list marks the spells the character could learn but does not know }
        2: Magic.AddScrollSpells(creature, False, MARK_NOT_KNOWN, lvl);
        { the scribe list marks the spells the character already knows }
        3: Magic.AddAllScrollSpells(creature, False, MARK_KNOWN, lvl);
        6: Magic.AddAllScrollSpells(creature, True, MARK_NONE, lvl);
        { a spell of a kind and level the character has slots for (CharHlp.SpellSlots; Restoration's level 7 has none) }
        4: for i := 1 to C_SPELL.LAST do
             if CharHlp.IsSpell(i) then
               with GameDefs.spellTable[i] do
                 if (levelSp = lvl) and (CharHlp.SpellSlots(creature, castClassSp, levelSp) > 0) and
                     not CharHlp.KnowsSpell(creature, i) then
                   Magic.AddSpellToList(creature, i, MARK_NONE);
      end;
  { a list of headings alone has nothing to pick: it counts as empty }
  p := spellList;
  while (p <> nil) and (p^.inUse <> 0) do
    p := p^.next;
  if p <> nil then
    GenerateSpellList := True
  else if spellList <> nil then begin
    MenuCore.FreeStringList(spellList);
    spellList := nil;
  end;
end;

function SpellListLine(n: Byte): Types.TStr40;
var
  p: Types.PItemRec;
begin
  p := spellList;
  while (p <> nil) and (n > 0) do begin
    p := p^.next;
    Dec(n);
  end;
  if p = nil then
    SpellListLine := ''
  else
    SpellListLine := p^.name;
end;

{ Spell duration in minutes: CharHlp.SpellDuration's dice rolled, or its fixed figure }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Types.TDurDice;
  m: Word;
begin
  CharHlp.SpellDuration(spell, d);
  m := d.add;
  if d.count > 0 then
    Inc(m, Dice.RollDice(d.count, d.sides));
  CalcSpellDuration := m * d.mult;
end;

{ Apply spell to every non-nil spellTargets entry. The save is rolled only when the spell's saveResult is not
  C_SPELL.SAVE_NONE. When its rangeFixed is C_SPELL.ATTACK_ROLL_RANGE an attack roll is needed too; a miss counts as
  saved and zeroes damage for this and every later target. damage > 0 is dealt with elem as GameVars.elementMask and
  saveResult as the save reduction (C_SPELL.SAVE_NEGATES none, C_SPELL.SAVE_HALF half). The spell's effect, if any, is
  added for CalcSpellDuration minutes at strength eff (0 = caster level) with onRemove and msg, a save negating it for
  C_SPELL.SAVE_NEGATES and C_SPELL.SAVE_SPECIAL (Silence, whose aura then never starts). SSI's code read saveResult as a
  Boolean, so Silence's 3 negated under Free Pascal and not under Turbo Pascal (#860). With no targets it does nothing
  but clear elementMask: SSI's set the spell's element first and left it for the next non-weapon damage (#922). }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  saveResult: Byte;
begin
  saveResult := GameDefs.spellTable[spell].saveResult;
  GameVars.elementMask := 0;
  if GameVars.spellTargetCount = 0 then
    Exit;
  if damage > 0 then
    GameVars.elementMask := elem;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GameVars.spellTargetCount do begin
    if GameVars.spellTargets[i] <> nil then begin
      tgt := GameVars.spellTargets[i];
      if saveResult = C_SPELL.SAVE_NONE then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(tgt, GameDefs.spellTable[spell].saveType, 0);
      if GameDefs.spellTable[spell].rangeFixed = C_SPELL.ATTACK_ROLL_RANGE then begin
        CharHlp.RecalcStats(tgt);
        FxEngine.TriggerEffectsWithCondition(C_COND.DEFENDER_AC, tgt);
        if not FxEngine.AttackRoll(GameVars.curChar, tgt, tgt^.acCur) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(tgt, damage, saveResult, saved);
      if GameDefs.spellTable[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(tgt, GameDefs.spellTable[spell].effect, Magic.CalcSpellDuration(spell), effLevel,
                                      onRemove, saveResult in [C_SPELL.SAVE_NEGATES, C_SPELL.SAVE_SPECIAL], saved, msg);
    end;
  end;
  GameVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
begin
  if GameVars.castTarget = nil then
    GameVars.castTarget := GameVars.curChar;
  GameVars.spellTargets[1] := GameVars.curChar;
  GameVars.spellTargetCount := 1;
  cast := True;
  case GameDefs.spellTable[spell].target of
    1: ;
    2: begin
         CharDisp.DisplayNoncombatInterface;
         CharDisp.SelectChar('Cast Spell on whom', True, GameVars.castTarget);
         if GameVars.castTarget = nil then begin
           GameVars.spellTargets[1] := nil;
           GameVars.spellTargetCount := 0;
           cast := False;
         end else
           GameVars.spellTargets[1] := GameVars.castTarget;
       end;
    4: begin
         GameVars.spellTargets[GameVars.spellTargetCount] := GameVars.creatureList;
         while GameVars.spellTargets[GameVars.spellTargetCount]^.nextCharAddr <> nil do begin
           GameVars.spellTargets[GameVars.spellTargetCount + 1] :=
             GameVars.spellTargets[GameVars.spellTargetCount]^.nextCharAddr;
           Inc(GameVars.spellTargetCount);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpell(spell: Byte; b, announce: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { the caster's chance of spell failure, and whether this cast failed }
  chance: Byte;
  failed: Boolean;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
begin
  p := GameVars.curChar;
  ok := True;
  { the feebleminded cast nothing from memory (#1121); in combat EffHndlr.EffFeeblemind keeps them from the Cast menu }
  if not GameVars.usingItem and CharHlp.HasEffect(p, C_EFFECT.FEEBLEMIND, effect) then begin
    CharDisp.PrintNameString(p, 'is too feebleminded to cast', 10, True);
    Exit;
  end;
  if (GameVars.ifcState <> C_IFC.IN_COMBAT) and (GameDefs.spellTable[spell].target = 0) then begin
    if GameVars.usingItem = False then begin
      Magic.ShowCombatOnlySpell(spell);
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, White, LightGreen) = 'Y' then
        CharHlp.RemoveSpell(GameVars.curChar, spell);
    end else begin
      Magic.ShowCombatOnly('That Item', 'item');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y' then
        sel := True;
    end;
    announce := False;
    ok := False;
  end;
  if announce then
    if GameVars.usingItem = False then
      Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GameVars.castTargetMenu(spell, b, sel);
    if sel then begin
      ok := False;
      { a cleric's low Wisdom can make a memorized clerical spell fail (#60), rolled only when there is a chance }
      failed := False;
      if GameVars.usingItem = False then begin
        chance := ClassCal.SpellFailureChance(p, spell);
        if chance > 0 then
          failed := Dice.RollDice(1, 100) <= chance;
      end;
      if failed then begin
        CharHlp.RemoveSpell(p, spell);
        CharDisp.PrintNameString(p, 'fails to cast ' + GameDefs.spellNames[spell] + '.', 10, True);
      end else begin
        if GameVars.ifcState = C_IFC.IN_COMBAT then begin
          CharDisp.BuildIconFacings(C_SPRITE.MISSILE);
          x := CbtMap.CombatCellX(p);
          y := CbtMap.CombatCellY(p);
          k := Pathing.DirToward(x, y, gTargetX, gTargetY);
          if k < C_DIR.CENTER then
            CbtMap.SetCreatureFacing(p, k, 1, 0);
          SoundDrv.SoundSetAutoStop(0);
          case spell of
            C_SPELL.FIREBALL: SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.FIREBALL], C_SOUND.GROUP_SPELL);
            C_SPELL.LIGHTNING_BOLT:
              SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.LIGHTNING], C_SOUND.GROUP_SPELL);
          else
            SoundDrv.SoundEffect(GameDefs.soundIds.commands[C_SOUND.CAST], C_SOUND.GROUP_SPELL);
          end;
          CharDisp.CombatAnimateMovingIcon(x, y, gTargetX, gTargetY, 4, 30);
          SoundDrv.SoundSetAutoStop(10);
          if CbtMap.CombatIconVisible(p, 0) then begin
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 1, 1);
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 0, 0);
          end;
        end;
        FxEngine.RemoveInvisibility(p);
        if GameVars.usingItem = False then begin
          CharHlp.RemoveSpell(GameVars.curChar, spell);
          Stats.Count(p, Stats.SPELLS_CAST, 1);
        end;
        GameVars.spellId := spell;
        GameVars.spellFns[GameVars.spellId];
        GameVars.spellId := C_SPELL.NONE;
        GameVars.gMultiTarget := 0;
      end;
    end else begin
      if GameVars.ifcState <> C_IFC.IN_COMBAT then
        ok := False
      else if b or (MenuCore.YesNoMenu('Abort Spell? ', warnColor, optionColor, commandColor) = 'Y') then
      begin
        CharDisp.PrintActionLine(GameVars.curChar, 'Spell Aborted', 'aborts the spell');
        if GameVars.usingItem = False then
          CharHlp.RemoveSpell(GameVars.curChar, spell);
        ok := False;
      end;
    end;
  end;
  CharDisp.ClearMessageWindow;
  if GameVars.ifcState = C_IFC.IN_COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

{ The message window's refusal of something combat-only outside combat: name, then 'is a combat-only <kind>...' under
  it. }
procedure ShowCombatOnly(name: Types.TStr40; kind: Types.TStr20);
begin
  TextRend.DisplayString(1, 19, LightGreen, name);
  TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only ' + kind + '...');
end;

procedure ShowCombatOnlySpell(spell: Byte);
begin
  Magic.ShowCombatOnly(GameDefs.spellNames[spell], 'spell');
end;

{ Bless and Curse: drop targets not on team side (CharHlp.Team, 0 or 1) and, for Bless in combat, targets with an enemy
  within range 1 (1st edition: Bless spares those already in melee); resolve the rest as a multi-target spell with msg.
  SSI's compared the raw hostile byte, so a byte above 1 (a damaged save) put a creature on neither side and turned
  such a caster's Curse on its own side (POR-0230, #1027). }
procedure CastOneSide(side: Byte; msg: Types.TStr40);
var
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  for i := 1 to GameVars.spellTargetCount do begin
    if GameVars.spellTargets[i] <> nil then
      if (CharHlp.Team(GameVars.spellTargets[i]) <> side) or
          ((GameVars.spellId = C_SPELL.BLESS) and (GameVars.ifcState = C_IFC.IN_COMBAT) and
           (CbtMap.CountTargets(GameVars.spellTargets[i], 1) > 0)) then
        GameVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, msg);
end;

{ Bless: apply the spell to the caster's own team only (see CastOneSide). }
procedure SpellBless;
begin
  Magic.CastOneSide(CharHlp.Team(GameVars.curChar), 'is Blessed');
end;

{ Curse: apply the spell to the caster's enemies only (see CastOneSide). }
procedure SpellCurse;
begin
  Magic.CastOneSide(1 - CharHlp.Team(GameVars.curChar), 'is Cursed');
end;

{ Cure Light Wounds: restore 1d8 hit points to the first target. }
procedure SpellCureLightWounds;
begin
  if GameVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GameVars.spellTargets[1], Dice.RollDice(1, 8), False) then
    CharDisp.PrintHpRestoreMsg(GameVars.spellTargets[1]);
end;

{ Cause Light Wounds: 1d8 damage, element mask 8. }
procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(1, 8), C_EFFECT.ELEM_MAGIC, '');
end;

{ Shared handler for the detection-style spells: apply the spell's effect. }
procedure SpellDetection;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is affected');
end;

{ Shared handler for the protection spells: apply the spell's effect. }
procedure SpellProtection;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is protected');
end;

{ Resist Cold: apply the spell's effect. }
procedure SpellResistCold;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is cold-resistant');
end;

{ Burning Hands: caster-level damage, element mask 9. }
procedure SpellBurningHands;
begin
  { no dice are rolled: the fixed damage counts as one die for the per-die fire protections (effects 61 and 113),
    which otherwise used the die count of whatever damage roll came before }
  GameVars.gDamageDice := 1;
  Magic.ResolveSpell(GameVars.spellId, 0, False, CharHlp.GetCasterLevel(GameVars.spellId),
                     C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, '');
end;

{ Charm Person: only persons (CharHlp.IsPerson) can be charmed (#792). The Charm effect's strength is the caster's
  team (CharHlp.Team) * 128 + caster level; afterwards the target's first Charm effect (normally the one just added)
  has its handler called with removed = False. }
procedure SpellCharmPerson;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.spellTargets[1];
  if not CharHlp.IsPerson(tgt) then
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True)
  else begin
    Magic.ResolveSpell(GameVars.spellId,
                        CharHlp.Team(GameVars.curChar) * 128 + CharHlp.GetCasterLevel(GameVars.spellId),
                        True, 0, 0, 'is charmed');
    if CharHlp.HasEffect(tgt, C_EFFECT.CHARM, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.CHARM, GameVars.spellTargets[1], effect, False);
  end;
end;

{ Enlarge: set the first target's Strength from the caster level and add the Enlarge effect, which keeps the Strength
  encoding AdjustForNewStrength returns. }
procedure SpellEnlarge;
var
  baseStr: Byte;
  excStr: Byte;
  enc: Byte;
  lvl: Byte;
begin
  { Strength 18 with exceptional Strength 0, 1, 51, 76, 91 or 100 for caster levels 1..6; 100 above 6, 0 for level 0 }
  baseStr := 18;
  lvl := CharHlp.GetCasterLevel(GameVars.spellId);
  case lvl of
    1: excStr := 0;
    2: excStr := 1;
    3: excStr := 51;
    4: excStr := 76;
    5: excStr := 91;
    6: excStr := 100;
  else
    if lvl > 6 then
      excStr := 100
    else
      excStr := 0;
  end;
  if FxEngine.AdjustForNewStrength(GameVars.spellTargets[1], baseStr, excStr, enc) then
    CharDisp.PrintNameString(GameVars.spellTargets[1], 'is stronger', 10, True);
  { enc: the Strength encoding AdjustForNewStrength returned, kept as the effect's strength }
  FxEngine.AddEffect(GameVars.spellTargets[1], C_EFFECT.ENLARGE,
                     Magic.CalcSpellDuration(GameVars.spellId), enc, True);
end;

{ Reduce: if spellTargets[1] fails a spell save, remove its Enlarge effect (12) }
procedure SpellReduce;
begin
  if GameVars.spellTargetCount > 0 then
    if not FxEngine.RollSavingThrow(GameVars.spellTargets[1], C_SAVE.SPELL, 0) then
      if FxEngine.RemoveEffectWithMessage(GameVars.spellTargets[1], C_EFFECT.ENLARGE) then
        CharDisp.PrintNameString(GameVars.spellTargets[1], 'has been reduced', 10, True);
end;

{ Friends: +2d4 Charisma for the spell's duration, capped at 25. The effect's strength is C_EFFECT.FRIENDS_BONUS plus
  the Charisma it gave, which EffHndlr.EffFriends takes back as it ends (FxEngine.FriendsEndCha), so each of two at once
  takes back its own. Charisma rises only once the effect is on: a creature immune to it is unaffected. SSI's stored
  the Charisma before the cast and put it back, so casting it twice, or once more as the first lasted, left a lasting
  gain (POR-0212, #920). }
procedure SpellFriends;
var
  tgt: Types.PCharRecord;
  newCha: Byte;
begin
  if GameVars.spellTargetCount = 0 then Exit;
  tgt := GameVars.spellTargets[1];
  if tgt = nil then Exit;
  if FxEngine.EffectImmune(tgt, C_EFFECT.FRIENDS) then
    CharDisp.PrintNameString(tgt, 'is Unaffected', 10, True)
  else begin
    newCha := AbilAdj.ClampScore(tgt^.chaCur + Dice.RollDice(2, 4));
    { a score already past the cap is left as it is }
    if newCha < tgt^.chaCur then
      newCha := tgt^.chaCur;
    FxEngine.AddEffect(tgt, C_EFFECT.FRIENDS, Magic.CalcSpellDuration(GameVars.spellId),
                       C_EFFECT.FRIENDS_BONUS or (newCha - tgt^.chaCur), True);
    tgt^.chaCur := newCha;
    CharDisp.PrintNameStringAnim(tgt, True, 'is friendly');
    CharDisp.ClearMessageWindow;
  end;
end;

{ Magic Missile: one missile of 1d4 + 1 for every two caster levels, the first at level 1 (1st edition and the rule
  book: two at levels 3 and 4, three at 5 and 6), element mask 8. SSI's counted caster level div 2, so a 1st-level
  caster's did no damage and every later pair of levels got its missile a level late (#859). }
procedure SpellMagicMissile;
var
  missiles: Byte;
begin
  missiles := (CharHlp.GetCasterLevel(GameVars.spellId) + 1) div 2;
  Magic.ResolveSpell(GameVars.spellId, 0, False, missiles + Dice.RollDamageDice(missiles, 4),
                     C_EFFECT.ELEM_MAGIC, '');
end;

{ Shield: apply the spell's effect. }
procedure SpellShield;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is shielded');
end;

{ Shocking Grasp: 1d8 + caster level damage, element mask $C. }
procedure SpellShockingGrasp;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False,
                      Dice.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GameVars.spellId),
                      C_EFFECT.ELEM_ELEC or C_EFFECT.ELEM_MAGIC, '');
end;

{ Sleep: a 4d4 hit-dice pool (C_SPELL.SLEEP_DICE d SLEEP_DIE), spent greedily in target order through
  CharHlp.SleepTakes: animated dead, targets already asleep and targets the remaining pool cannot pay for
  (CharHlp.SleepCost) are dropped. }
procedure SpellSleep;
var
  pool: Byte;
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  pool := Dice.RollDice(C_SPELL.SLEEP_DICE, C_SPELL.SLEEP_DIE);
  for i := 1 to GameVars.spellTargetCount do
    if not CharHlp.SleepTakes(GameVars.spellTargets[i], pool) then
      GameVars.spellTargets[i] := nil;
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'falls asleep');
end;

{ Hold Person (spells 23 and 49) and Hold Monsters (94): save modifier -2 (cleric) or -3 (mage) for one target, -1 for
  two, 0 for three or more. Targets are processed in reverse; each one after the first processed (i < spellTargetCount)
  gets its own projectile animation. Against Hold Person, targets that are not persons (CharHlp.IsPerson, #792) always
  save. }
procedure SpellHold;
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  smod: ShortInt;
begin
  case GameVars.spellTargetCount of
    1: if GameVars.spellId = C_SPELL.HOLD_PERSON then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
  else
    smod := 0;
  end;
  for i := GameVars.spellTargetCount downto 1 do begin
    if GameVars.spellTargets[i] <> nil then begin
      tgt := GameVars.spellTargets[i];
      if i < GameVars.spellTargetCount then begin
        SoundDrv.SoundSetAutoStop(0);
        SoundDrv.SoundEffect(GameDefs.soundIds.commands[C_SOUND.CAST], C_SOUND.GROUP_SPELL);
        CharDisp.AnimateBetween(GameVars.curChar, tgt, C_SPRITE.MISSILE, 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      saved := FxEngine.RollSavingThrow(tgt, GameDefs.spellTable[GameVars.spellId].saveType, smod);
      { Hold Monsters holds any kind of creature (#1121) }
      if (GameVars.spellId <> C_SPELL.HOLD_MONSTERS) and not CharHlp.IsPerson(tgt) then
        saved := True;
      FxEngine.AddEffectWithMessage(tgt, GameDefs.spellTable[GameVars.spellId].effect,
                                    Magic.CalcSpellDuration(GameVars.spellId),
                                    CharHlp.GetCasterLevel(GameVars.spellId), False,
                                    GameDefs.spellTable[GameVars.spellId].saveResult = C_SPELL.SAVE_NEGATES,
                                    saved, 'is held');
    end;
  end;
end;

{ Resist Fire: apply the spell's effect. }
procedure SpellResistFire;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is fire resistant');
end;

{ Silence: apply the spell's effect. }
procedure SpellSilence;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is silenced');
end;

{ Stand a downed creature back up with its hit points through FxEngine.ReviveDeadCreature, or, where it cannot stand
  yet (another creature on its cell), a minute later through C_EFFECT.HEAL_WAKE. }
procedure StandUpOrWake(tgt: Types.PCharRecord);
begin
  if not FxEngine.ReviveDeadCreature(tgt, tgt^.hpCur) then
    FxEngine.AddEffect(tgt, C_EFFECT.HEAL_WAKE, 1, 0, True);
end;

{ Slow Poison: animated dead are skipped. A poisoned target (effect 55) has hpCur raised to at least 1, gets the spell's
  effect at strength 255 and gains effect 15 for 10 minutes at strength 255. One that is down (dead or out of play, and
  not fled, petrified or gone) gets back up (StandUpOrWake, as under Keoghtom's Ointment); one still standing is left
  as it is. SSI stood up every poisoned target, so a standing one "got back up" again and a stoned, disintegrated or
  fled one was set Okay. }
procedure SpellSlowPoison;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.spellTargets[1];
  if tgt^.status = C_STATUS.ANIMATED then
    GameVars.spellTargets[1] := nil
  else if CharHlp.HasEffect(tgt, C_EFFECT.POISONED, effect) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    Magic.ResolveSpell(GameVars.spellId, 255, True, 0, 0, 'is affected');
    if ((tgt^.status = C_STATUS.DEAD_STATUS) or (tgt^.enabled = 0)) and
        not (tgt^.status in [C_STATUS.TEMPGONE, C_STATUS.RUNNING, C_STATUS.STONED, C_STATUS.GONE]) then
      StandUpOrWake(tgt);
    FxEngine.AddEffect(tgt, C_EFFECT.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Snake Charm: rebuild the target list from GameVars.creatureList: snakes (C_SPELL.SNAKE_NAME) whose hpCur still fits
  in a pool equal to the caster's hpCur, paid in list order. SSI's took charType 14, which the large and huge scorpions
  share with the giant snake (#802). }
procedure SpellSnakeCharm;
var
  pool: Byte;
  p: Types.PCharRecord;
begin
  pool := GameVars.curChar^.hpCur;
  GameVars.spellTargetCount := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.name = C_SPELL.SNAKE_NAME then
      if pool >= p^.hpCur then begin
        pool := pool - p^.hpCur;
        Inc(GameVars.spellTargetCount);
        GameVars.spellTargets[GameVars.spellTargetCount] := p;
      end;
    p := p^.nextCharAddr;
  end;
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is charmed');
end;

{ Spiritual Hammer: apply the spell's effect, then run the Spiritual Hammer effect handler for the first target. }
procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_EFFECT.SPIRITUAL_HAMMER, GameVars.spellTargets[1], nil, False);
end;

{ Invisibility: apply the spell's effect. }
procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is invisible');
end;

{ Knock: apply the spell's effect. }
procedure SpellKnock;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'Knock-Knock');
end;

{ Mirror Image: apply the spell's effect with 1d4 images as its strength. }
procedure SpellMirrorImage;
begin
  Magic.ResolveSpell(GameVars.spellId, Dice.RollDice(1, 4), False, 0, 0, 'is duplicated');
end;

{ Ray of Enfeeblement: apply the spell's effect. }
procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is weakened');
end;

{ Lay spell's cloud (Stinking Cloud's or Cloudkill's) at the aim cell: append a node to the cloudHead list and give the
  caster effect effId for caster-level minutes at strength FxEngine.CloudStrength (caster level, at most 15, + myClouds
  * 16; SSI let a level above 15 carry into the number), where myClouds is the lowest number none of the caster's
  clouds has (FxEngine.FreeCloudNumber; SSI counted the caster's nodes on the walk to the tail and never checked the
  tail, so a second cloud could share the first one's number and its end clear the older cloud). The cloud covers the
  spell's block (CbtMap.CloudCell, side CharHlp.SpellArea's: Stinking Cloud's 2x2 from the aim cell, center, E, SE, S;
  Cloudkill's 3x3 round it), spread over the arena by CbtMap.SpreadCloud in the cloud's terrain (CbtMap.CloudTerrain);
  after msg, every creature found in its cells meets the cloud (FxEngine.ConsiderStinkingCloud,
  Magic.ConsiderCloudkill), once however many cells it fills (POR-0213, #921). }
procedure LayCloud(spell, effId: Byte; msg: Types.TStr40);
var
  node: Types.PCloudRec;
  crIdx: Types.TCloudCells;
  j: Byte;
  myClouds: Byte;
  cl: Byte;
  k: Byte;
  side: Byte;
  { crIdx[k] is not in an earlier cell }
  first: Boolean;
begin
  GameVars.gMultiTarget := 1;
  if CharHlp.SpellArea(spell, side) <> C_SPELL.AREA_CLOUD then
    side := C_SPELL.STINKING_CLOUD_SIDE;
  cl := CharHlp.GetCasterLevel(GameVars.spellId);
  myClouds := FxEngine.FreeCloudNumber(GameVars.curChar);
  node := CbtMap.AppendCloud;
  FxEngine.AddEffect(GameVars.curChar, effId, cl, FxEngine.CloudStrength(cl, myClouds), True);
  node^.caster := GameVars.curChar;
  node^.idx := myClouds;
  node^.ulX := gTargetX;
  node^.ulY := gTargetY;
  node^.side := side;
  node^.terrain := CbtMap.CloudTerrain(spell);
  CbtMap.SpreadCloud(node, crIdx);
  CharDisp.PrintNameString(GameVars.curChar, msg, 10, False);
  CbtMap.ScrollView(gTargetX, gTargetY, 255, C_DIR.CENTER);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
  for k := 1 to side * side do
    if crIdx[k] > 0 then begin
      first := True;
      for j := 1 to k - 1 do
        if crIdx[j] = crIdx[k] then
          first := False;
      if first then
        if node^.terrain = C_TERR.CLOUDKILL then
          Magic.ConsiderCloudkill(GameVars.creatureArr[crIdx[k]])
        else
          FxEngine.ConsiderStinkingCloud(GameVars.creatureArr[crIdx[k]]);
    end;
end;

{ Stinking Cloud: its 2x2 cloud (LayCloud), tracked by effect 40, C_EFFECT.CAST_STINKING_CLOUD. }
procedure SpellStinkingCloud;
begin
  Magic.LayCloud(C_SPELL.STINKING_CLOUD, C_EFFECT.CAST_STINKING_CLOUD, 'Creates a noxious cloud');
end;

{ Strength: add 1d4 for a mage, 1d6 for a cleric or thief, 1d8 for a fighter, paladin or ranger; when several classes
  match, the last test wins, and with none of them nothing is added. Above 18, those warriors turn each extra point into
  10 points of exceptional Strength (capped at 100) and others are held at 18. }
procedure SpellStrength;
var
  tgt: Types.PCharRecord;
  exStr: Byte;
  roll: Byte;
  newStr: Byte;
  enc: Byte;
begin
  exStr := 0;
  roll := 0;
  tgt := GameVars.spellTargets[1];
  if CharHlp.GetClassLevel(tgt, C_LEVEL.MAGE_BIT) > 0 then
    roll := Dice.RollDice(1, 4);
  if CharHlp.GetClassLevel(tgt, C_LEVEL.CLERIC_BIT + C_LEVEL.THIEF_BIT) > 0 then
    roll := Dice.RollDice(1, 6);
  if CharHlp.WarriorLevel(tgt) > 0 then
    roll := Dice.RollDice(1, 8);
  newStr := tgt^.strCur + roll;
  if newStr > 18 then begin
    if CharHlp.WarriorLevel(tgt) > 0 then begin
      { 10 exceptional points per point above 18 }
      exStr := tgt^.strExc + (newStr - 18) * 10;
      { Percentile cap 100 }
      if exStr > 100 then
        exStr := 100;
      newStr := 18;
    end else
      newStr := 18;
  end;
  if FxEngine.AdjustForNewStrength(tgt, newStr, exStr, enc) then
    CharDisp.PrintNameString(tgt, 'is stronger', 10, True);
  FxEngine.AddEffect(tgt, C_EFFECT.STRENGTH, Magic.CalcSpellDuration(GameVars.spellId), enc, True);
end;

{ Animate Dead: animate up to caster-level dead (C_STATUS.DEAD_STATUS) human (charType 0) creatures whose cell is still
  a valid location. Effect 32's strength is the old side * 16 + caster level (at most 15). Each corpse joins the
  caster's team under computer control (quickfight 1), becomes undead (charType 4, levelUndead 2, movementBase 6,
  attackLevel 0), loses its memorized spells and gets the animated NPC or PC npc code; if ReviveDeadCreature succeeds at
  full hpMax it also gets effect 32 and C_STATUS.ANIMATED. }
procedure SpellAnimateDead;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PCharRecord;
begin
  GameVars.gMultiTarget := 1;
  n := CharHlp.GetCasterLevel(GameVars.spellId);
  GameVars.spellTargetCount := 0;
  p := GameVars.creatureList;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_STATUS.DEAD_STATUS then
      { Human }
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(p, CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), True) then begin
          { the corpse's side in bit 4, the caster level (at most 15) below it: a level of 16 or more carried into the
            side, and EffAnimateDead gave the corpse back a hostile of 2 or more (#710) }
          strength := CharHlp.GetCasterLevel(GameVars.spellId);
          if strength > 15 then
            strength := 15;
          strength := CharHlp.Team(p) * 16 + strength;
          p^.hostile := CharHlp.Team(GameVars.curChar);
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.movementBase := 6;
          CharHlp.ClearMemorized(p);
          { C_NPC.FLAG set }
          if CharHlp.IsNpc(p) then
            p^.npc := C_NPC.ANIMATED_NPC
          else
            p^.npc := C_NPC.ANIMATED_PC;
          { Undead }
          p^.charType := 4;
          if GameVars.ifcState = C_IFC.IN_COMBAT then
            p^.combatAddr^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(p, p^.hpMax) then begin
            FxEngine.AddEffectWithMessage(p, C_EFFECT.ANIMATE_DEAD, 0, strength, True, False, False, 'is animated');
            p^.status := C_STATUS.ANIMATED;
          end;
        end;
    p := p^.nextCharAddr;
  end;
end;

{ Cure Blindness: remove the first target's blindness. }
procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GameVars.spellTargets[1], C_EFFECT.BLIND) then
    CharDisp.PrintNameStringAnim(GameVars.spellTargets[1], True, 'can see');
end;

{ Cause Blindness: apply the spell's effect. }
procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is blind');
end;

{ Cure tgt's diseases (FxEngine.RemoveDiseases, the rule every cure shares, #922) and, when there was one, say
  "<name> is Cured". Returns whether there was one. }
function CureDiseaseOf(tgt: Types.PCharRecord): Boolean;
begin
  CureDiseaseOf := False;
  if FxEngine.RemoveDiseases(tgt) then begin
    CharDisp.PrintNameString(tgt, 'is Cured', 10, True);
    CureDiseaseOf := True;
  end;
end;

{ Cure Disease: cure the first target's diseases (CureDiseaseOf). }
procedure SpellCureDisease;
var
  junk: Boolean;
begin
  if GameVars.spellTargets[1] <> nil then
    junk := Magic.CureDiseaseOf(GameVars.spellTargets[1]);
end;

{ Cause Disease: apply the spell's effect. }
procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, True, 0, 0, 'is diseased');
end;

{ Dispel Magic: on each target, try every effect whose strength is below 255, with its low nibble as the effect's caster
  level: 50%, +5% per caster level above it, -2% per level below. A paladin's lay-on-hands and cure-disease timers are
  left alone, and so are the diseases (C_EFFECT.DISEASES), which Cure Disease removes: SSI's dispelled Strength drain
  re-armed itself and took another point (#787). A removal that frees the next effect (dispelled Animate Dead) ends that
  target's walk; SSI read on into the freed node. }
procedure SpellDispelMagic;
var
  chance: Byte;
  effLevel: Byte;
  i: Byte;
  cl: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  effect: Types.PEffectRec;
  nxt: Types.PEffectRec;
begin
  GameVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GameVars.spellId);
  for i := 1 to GameVars.spellTargetCount do begin
    removed := False;
    if i <= Types.ARENA_SLOTS then
      tgt := GameVars.spellTargets[i]
    else
      tgt := nil;
    if tgt <> nil then
      effect := Types.PEffectRec(tgt^.effectsAddr)
    else
      effect := nil;
    while effect <> nil do begin
      nxt := effect^.next;
      if (effect^.strength < 255)
         and not (effect^.id in C_EFFECT.DISEASES + [C_EFFECT.RECENT_HEAL, C_EFFECT.RECENT_CURE]) then begin
        { dispel treats the low nibble as caster level }
        effLevel := effect^.strength and $F;
        if cl > effLevel then
          chance := (cl - effLevel) * 5 + 50
        else if cl < effLevel then
          chance := 50 - (effLevel - cl) * 2
        else
          chance := 50;
        if Dice.RollDice(1, 100) <= chance then begin
          FxEngine.RemoveEffect(tgt, effect^.id, effect);
          removed := True;
          { a removal that kills the creature (Animate Dead's) strips its 0-HP effects, which may free the next node:
            the walk goes on only while that node is still in the list }
          if (nxt <> nil) and not FxEngine.HasEffectNode(tgt, nxt) then
            nxt := nil;
        end;
      end;
      effect := nxt;
    end;
    if removed then
      CharDisp.PrintNameStringAnim(tgt, True, 'is affected');
  end;
end;

{ Prayer: apply the spell's effect at FxEngine.PrayerStrength, the caster's team and level. }
procedure SpellPrayer;
begin
  Magic.ResolveSpell(GameVars.spellId,
                      FxEngine.PrayerStrength(GameVars.curChar, CharHlp.GetCasterLevel(GameVars.spellId)),
                      False, 0, 0, 'is praying');
end;

procedure SpellRemoveCurse;
var
  item: Types.PItemRec;
  found: Boolean;
begin
  if FxEngine.RemoveEffectWithMessage(GameVars.spellTargets[1], C_EFFECT.BESTOW_CURSE) then
    CharDisp.PrintNameStringAnim(GameVars.spellTargets[1], True, 'is un-cursed')
  else begin
    found := False;
    item := GameVars.spellTargets[1]^.itemsAddr;
    while (item <> nil) and (found = False) do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.cursed := 0;
      end;
      item := item^.next;
    end;
    if found then
      CharDisp.PrintNameStringAnim(GameVars.spellTargets[1], True, '''s item is un-cursed');
  end;
end;

{ Bestow Curse: apply the spell's effect. }
procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'has been cursed!');
end;

{ Blink: apply the spell's effect. }
procedure SpellBlink;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is blinking');
end;

{ Fireball: spell 64 (an item fireball) uses level 1d C_SPELL.ITEM_FIREBALL_DIE * 2 + 1. When zone0^.view3dFlag is 0 the
  target list is rebuilt with Pathing.TargetArea, radius 2 around the aim cell. Damage is level d6, element mask 9. }
procedure SpellFireball;
var
  cl: Byte;
begin
  GameVars.gMultiTarget := 1;
  if GameVars.spellId = C_SPELL.ITEM_FIREBALL then
    cl := Dice.RollDice(1, C_SPELL.ITEM_FIREBALL_DIE) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GameVars.spellId);
  if GameVars.zone0^.view3dFlag = 0 then begin
    Pathing.TargetArea(gTargetX, gTargetY, 2);
  end;
  CbtMap.ScrollView(gTargetX, gTargetY, 0, C_DIR.CENTER);
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(cl, 6),
                     C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, '');
end;

{ Haste and Slow: keep up to caster-level targets on team side (CharHlp.Team; SSI's compared the raw hostile byte,
  POR-0230, #1027) and drop the rest. A kept target carrying removeId,
  the opposing Slowed or Hasted effect, just loses it; the others get the spell's effect and have their
  C_COND.MOVE_ATTACK_RATE effects re-run on their own attack count, as at a round's start (#797), so a hasted one ages
  at once; its rates are worked out where they are used (CbtActs). }
procedure HasteSlowLogic(removeId: Byte; side: Byte; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GameVars.spellId);
  for i := 1 to GameVars.spellTargetCount do begin
    if (GameVars.spellTargets[i] <> nil) and (CharHlp.Team(GameVars.spellTargets[i]) = side) and
        (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(GameVars.spellTargets[i], removeId) then
        GameVars.spellTargets[i] := nil;
    end else
      GameVars.spellTargets[i] := nil;
  end;
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, msg);
  for i := 1 to GameVars.spellTargetCount do
    if GameVars.spellTargets[i] <> nil then begin
      GameVars.currentAttackCurrent := GameVars.spellTargets[i]^.attacks2;
      GameVars.currentCreatureCalculatingFlag := 0;
      FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, GameVars.spellTargets[i]);
    end;
end;

{ Haste: the caster's team loses Slowed or is hasted (see HasteSlowLogic). }
procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_EFFECT.SLOWED, CharHlp.Team(GameVars.curChar), 'is Hasted');
end;

{ Lightning damage to the creature at one bolt cell (half on a save of saveType). blocked returns whether the cell's
  terrain is impassable (cost 255). }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; var blocked: Boolean);
var
  tgt: Types.PCharRecord;
  crIdx: Byte;
  terr: Byte;
begin
  blocked := False;
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if terr > 0 then
    if GameDefs.terrainInfo[terr].cost = 255 then
      blocked := True;
  if crIdx > 0 then begin
    tgt := GameVars.creatureArr[crIdx];
    GameVars.elementMask := C_EFFECT.ELEM_ELEC or C_EFFECT.ELEM_MAGIC;
    FxEngine.InflictNonWeaponDamage(tgt, damage, C_SPELL.SAVE_HALF, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharDisp.BuildIconFacings(C_SPRITE.LIGHTNING);
    GameVars.elementMask := 0;
  end;
end;

{ Run a lightning bolt from the aim cell (gTargetX/Y) directly away from the caster, attacking each creature
  cell it reaches; callers attack the aim cell itself first. The budget is boltLen * 2 in Pathing's doubled distance
  units. Impassable terrain reflects the bolt back the other way; with bounce set, a first reflection at most 8 units
  from the caster costs 8 extra units. An off-map cell ends the bolt. }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  cells: Types.TCellList;
begin
  Magic.WalkBolt(boltLen, damage, saveType, bounce, False, cells);
end;

{ LightningPath's walk. With trace set it neither animates nor attacks: it lists every arena cell the bolt crosses in
  cells and leaves gTargetX/Y and GameVars.gMultiTarget as it found them. }
procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
var
  req: Types.TPathReq;
  req2: Types.TPathReq;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terr: Byte;
  budget: Byte;
  savedX: ShortInt;
  savedY: ShortInt;
  savedMulti: Byte;
begin
  cells.count := 0;
  savedX := gTargetX;
  savedY := gTargetY;
  savedMulti := GameVars.gMultiTarget;
  if not trace then
    CharDisp.BuildIconFacings(C_SPRITE.LIGHTNING);
  CbtMap.GetArenaContents(gTargetX, gTargetY, prevCr, terr);
  sign := 1;
  x0 := CbtMap.CombatCellX(GameVars.curChar);
  y0 := CbtMap.CombatCellY(GameVars.curChar);
  doBounce := bounce;
  if x0 = gTargetX then
    if y0 = gTargetY then
      Exit;
  budget := boltLen * 2;
  GameVars.gMultiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := gTargetX;
    req.sy := gTargetY;
    req.ex := gTargetX + (gTargetX - x0) * sign * budget;
    req.ey := gTargetY + (gTargetY - y0) * sign * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then begin
        repeat
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
          if trace and valid and (terr <> 0) and (cells.count < SizeOf(cells.x)) then begin
            Inc(cells.count);
            cells.x[cells.count] := req.cx;
            cells.y[cells.count] := req.cy;
          end;
        until (valid = False) or ((crIdx > 0) and (crIdx <> prevCr)) or (terr = 0) or
            (GameDefs.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      prevCr := crIdx;
      if terr = 0 then
        budget := 0;
      if trace then begin
        { LightningAttackAt's test }
        blocked := False;
        if terr > 0 then
          blocked := GameDefs.terrainInfo[terr].cost = 255;
      end else begin
        CharDisp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
        Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, blocked);
      end;
      if blocked then begin
        gTargetX := req.cx;
        gTargetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := gTargetX;
        req2.sy := gTargetY;
        req2.ex := x0;
        req2.ey := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if doBounce then
          if req2.dist <= 8 then
            Inc(req.dist, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0;
      end;
      if req.dist < budget then
        Dec(budget, req.dist)
      else
        budget := 0;
    until blocked or (budget = 0);
  end;
  GameVars.gMultiTarget := 0;
  if trace then begin
    gTargetX := savedX;
    gTargetY := savedY;
    GameVars.gMultiTarget := savedMulti;
  end;
end;

{ The bolt spell runs past its aim cell: Lightning Bolt's C_SPELL.LIGHTNING_BOLT_CELLS, with LightningPath's extra
  cost for a first rebound near the caster (bounce), or the Javelin of Lightning's C_SPELL.JAVELIN_BOLT_CELLS,
  without it. Their handlers and TraceBolt's preview share it. }
procedure BoltShape(spell: Byte; var boltLen: Byte; var bounce: Boolean);
begin
  bounce := spell <> C_SPELL.ITEM_JAVELIN_LIGHTNING;
  if bounce then
    boltLen := C_SPELL.LIGHTNING_BOLT_CELLS
  else
    boltLen := C_SPELL.JAVELIN_BOLT_CELLS;
end;

{ Lightning Bolt: caster-level d6 damage at the aim cell, then a bouncing bolt of 8 cells. }
procedure SpellLightningBolt;
var
  dmg: Byte;
  junk: Boolean;
  boltLen: Byte;
  bounce: Boolean;
begin
  dmg := Dice.RollDice(CharHlp.GetCasterLevel(GameVars.spellId), 6);
  Magic.LightningAttackAt(gTargetX, gTargetY, dmg, C_SAVE.SPELL, junk);
  Magic.BoltShape(C_SPELL.LIGHTNING_BOLT, boltLen, bounce);
  Magic.LightningPath(boltLen, dmg, C_SAVE.SPELL, bounce);
end;

procedure TraceBolt(spell: Byte; x, y: ShortInt; var cells: Types.TCellList);
var
  savedX: ShortInt;
  savedY: ShortInt;
  boltLen: Byte;
  bounce: Boolean;
  rays: Byte;
begin
  if (spell = C_SPELL.FEAR) or (spell = C_SPELL.CONE_OF_COLD) then begin
    Magic.ConeShape(spell, rays, boltLen);
    Magic.TraceCone(CbtMap.CombatCellX(GameVars.curChar), CbtMap.CombatCellY(GameVars.curChar), x, y, rays, boltLen,
                    cells);
    Exit;
  end;
  savedX := gTargetX;
  savedY := gTargetY;
  gTargetX := x;
  gTargetY := y;
  Magic.BoltShape(spell, boltLen, bounce);
  Magic.WalkBolt(boltLen, 0, C_SAVE.SPELL, bounce, True, cells);
  gTargetX := savedX;
  gTargetY := savedY;
end;

{ Slow: the caster's enemies lose Hasted or are slowed (see HasteSlowLogic). }
procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_EFFECT.HASTED, 1 - CharHlp.Team(GameVars.curChar), 'is Slowed');
end;

function RestorableClass(tgt: Types.PCharRecord; cls: ShortInt): Boolean;
var
  lvl: ShortInt;
begin
  lvl := tgt^.classLevels[cls];
  if tgt^.portExt.formerClasses and (1 shl cls) <> 0 then
    lvl := 0;
  { a level given back, not trained: the experience table's end (ClassCal.LevelXp) bounds it, not the Game Level Cap }
  RestorableClass := (lvl > 0) and (ClassCal.LevelXp(cls, lvl + 1) > 0) and (not CharHlp.AtLevelCap(tgt, cls));
end;

function RestoreClass(tgt: Types.PCharRecord): ShortInt;
var
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  cls: ShortInt;
begin
  { above any class level, so the first eligible class passes lvl <= bestLvl }
  bestLvl := C_LEVEL.LEVEL_LAST + 1;
  { sentinel above any table entry }
  bestXp := 10000000;
  { no class picked yet }
  RestoreClass := -1;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if Magic.RestorableClass(tgt, cls) then begin
      lvl := tgt^.classLevels[cls];
      if (lvl <= bestLvl) and (ClassCal.LevelXp(cls, lvl + 1) < bestXp) then begin
        bestLvl := lvl;
        RestoreClass := cls;
        bestXp := ClassCal.LevelXp(cls, lvl + 1);
      end;
    end;
end;

function RestoreLevel(tgt: Types.PCharRecord): Boolean;
var
  entry: Types.TDrainRec;
  logged: Boolean;
  share: Byte;
  cls: ShortInt;
  levelXp: LongInt;
begin
  RestoreLevel := tgt^.drainedLevels > 0;
  if tgt^.drainedLevels = 0 then
    Exit;
  logged := CharExt.PopDrain(tgt, entry);
  if logged then begin
    share := entry.hp;
    if share > tgt^.drainedHps then
      tgt^.drainedHps := 0
    else
      Dec(tgt^.drainedHps, share);
  end else begin
    share := tgt^.drainedHps div tgt^.drainedLevels;
    Dec(tgt^.drainedHps, share);
  end;
  Inc(tgt^.hpMax, share);
  Inc(tgt^.hpCur, share);
  Inc(tgt^.hpRolled, share);
  Dec(tgt^.drainedLevels);
  if logged and Magic.RestorableClass(tgt, entry.cls) then
    cls := entry.cls
  else
    cls := Magic.RestoreClass(tgt);
  if cls >= 0 then begin
    levelXp := ClassCal.LevelXp(cls, tgt^.classLevels[cls] + 1);
    Inc(tgt^.classLevels[cls]);
    if logged then
      Inc(tgt^.experience, entry.xp);
    if tgt^.experience < levelXp then
      tgt^.experience := levelXp;
  end;
  ClassCal.RecalcBaseSkills(tgt);
end;

procedure DrainedByClass(creature: Types.PCharRecord; var counts: Types.TClassCounts);
var
  cls: ShortInt;
  j: ShortInt;
  i: Byte;
  unlogged: Byte;
  raised: Types.TClassCounts;
begin
  FillChar(counts, SizeOf(counts), 0);
  FillChar(raised, SizeOf(raised), 0);
  for i := 1 to creature^.portExt.drainCount do begin
    cls := creature^.portExt.drains[i].cls;
    if (cls >= C_LEVEL.CLERIC) and (cls <= C_LEVEL.MONK) then
      Inc(counts[cls]);
  end;
  if creature^.drainedLevels <= creature^.portExt.drainCount then
    Exit;
  unlogged := creature^.drainedLevels - creature^.portExt.drainCount;
  { the logged levels come back first; then each unlogged level goes where Restoration would put it, the levels raised
    for the look ahead and taken off again after }
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
    raised[cls] := counts[cls];
    Inc(creature^.classLevels[cls], raised[cls]);
  end;
  for i := 1 to unlogged do begin
    cls := Magic.RestoreClass(creature);
    { with no class to raise, the level stays on the class a drain takes first: the highest one not left }
    if cls < 0 then
      for j := C_LEVEL.CLERIC to C_LEVEL.MONK do
        if (creature^.portExt.formerClasses and (1 shl j) = 0) and (creature^.classLevels[j] > 0) then
          if (cls < 0) or (creature^.classLevels[j] >= creature^.classLevels[cls]) then
            cls := j;
    if cls >= 0 then begin
      Inc(counts[cls]);
      Inc(raised[cls]);
      Inc(creature^.classLevels[cls]);
    end;
  end;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    Dec(creature^.classLevels[cls], raised[cls]);
end;

{ Restoration: give back one drained level (RestoreLevel). A class the restored level passes wakes again
  (ChgClass.AnnounceWoken, #838). SSI's gave back the average drainedHps div drainedLevels and raised the class with the
  lowest next level, not the one drained, and only to that level's start; a class a dual-classed human has left is
  never raised, as Curse restores classLevels alone (curse-disassembly v13 magic.pas:2016-2047). }
procedure SpellRestoration;
var
  tgt: Types.PCharRecord;
  resting: Byte;
begin
  tgt := GameVars.spellTargets[1];
  resting := ChgClass.RestingMask(tgt);
  if Magic.RestoreLevel(tgt) then begin
    CharDisp.PrintNameString(tgt, 'is restored', 10, True);
    if resting <> 0 then
      ChgClass.AnnounceWoken(tgt, resting);
  end;
end;

{ Potion of Speed: remove Slowed, or else apply the potion's effect. }
procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GameVars.spellTargets[1], C_EFFECT.SLOWED) then
    Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is Speedy');
end;

{ Keoghtom's Ointment: cure poison (also removing effect 22 silently), else cure disease, else heal 1d4 + 8. Poison
  kills on the spot, so a target the poison left dead gets back up with at least 1 hp, as under Slow Poison
  (StandUpOrWake). A dead target still under Slow Poison was kept up through the poison and died of something else (a
  wound, bleeding out), so it stays dead, as at the temple (Temple.NeutralizePoison). }
procedure KeoghtomsOintmentHandler;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
  slowed: Boolean;
begin
  tgt := GameVars.spellTargets[1];
  slowed := CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_END, effect) or
            CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_HIT, effect);
  if FxEngine.RemoveEffectWithMessage(tgt, C_EFFECT.POISONED) then begin
    GameVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_EFFECT.SLOW_POISON_END, nil);
    GameVars.effectLock := 0;
    if (tgt^.status = C_STATUS.DEAD_STATUS) and not slowed then begin
      if tgt^.hpCur = 0 then
        tgt^.hpCur := 1;
      StandUpOrWake(tgt);
    end;
  end else if not Magic.CureDiseaseOf(tgt) then begin
    if FxEngine.RestoreHitPoints(GameVars.spellTargets[1], Dice.RollDice(1, 4) + 8, False) then
      CharDisp.PrintNameStringAnim(GameVars.spellTargets[1], True, 'is Healed');
  end;
end;

{ Giant Strength: raise Strength to 21 and add the Strength effect, which keeps the Strength encoding
  AdjustForNewStrength returns. }
procedure SpellGiantStrength;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GameVars.spellTargets[1], 21, 0, enc) then
    CharDisp.PrintNameString(GameVars.spellTargets[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GameVars.spellTargets[1], C_EFFECT.STRENGTH,
                     Magic.CalcSpellDuration(GameVars.spellId), enc, True);
end;

{ Javelin of Lightning: 1d6 + 20 damage at the aim cell, then a bolt of 20 damage C_SPELL.JAVELIN_BOLT_CELLS cells
  on. }
procedure SpellJavelinOfLightning;
var
  junk: Boolean;
  boltLen: Byte;
  bounce: Boolean;
begin
  Magic.LightningAttackAt(gTargetX, gTargetY, Dice.RollDice(1, 6) + 20, C_SAVE.SPELL, junk);
  Magic.BoltShape(C_SPELL.ITEM_JAVELIN_LIGHTNING, boltLen, bounce);
  Magic.LightningPath(boltLen, 20, C_SAVE.SPELL, bounce);
end;

{ Wand of Paralyzation: apply the item's effect. }
procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is paralyzed');
end;

{ Potion of Healing: restore 2d4 + 2 hit points. }
procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GameVars.spellTargets[1], Dice.RollDice(2, 4) + 2, False) then
    CharDisp.PrintNameStringAnim(GameVars.spellTargets[1], True, 'is Healed');
end;

{ Dust of Disappearance: apply the item's effect. }
procedure SpellDustOfDisappearance;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is invisible');
end;

{ Wand of Magic Missiles: 2d4 + 2 damage, element C_EFFECT.ELEM_MAGIC. }
procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(2, 4) + 2, C_EFFECT.ELEM_MAGIC, '');
end;

procedure SpellCureSeriousWounds;
begin
  if GameVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GameVars.spellTargets[1], Dice.RollDice(2, 8) + 1, False) then
    CharDisp.PrintHpRestoreMsg(GameVars.spellTargets[1]);
end;

procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(2, 8) + 1, C_EFFECT.ELEM_MAGIC, '');
end;

procedure SpellNeutralizePoison;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
  { the poison was held off by Slow Poison, so a wound, not the poison, killed a dead target }
  slowed: Boolean;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  if (tgt^.status <> C_STATUS.ANIMATED) and CharHlp.HasEffect(tgt, C_EFFECT.POISONED, effect) then begin
    slowed := CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_END, effect) or
              CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_HIT, effect);
    GameVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_EFFECT.POISONED, nil);
    FxEngine.RemoveEffect(tgt, C_EFFECT.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(tgt, C_EFFECT.SLOW_POISON_HIT, nil);
    GameVars.effectLock := 0;
    CharDisp.PrintNameString(tgt, 'is unpoisoned', 10, True);
    if tgt^.status in [C_STATUS.TEMPGONE, C_STATUS.RUNNING, C_STATUS.STONED, C_STATUS.GONE] then
    else if (tgt^.status <> C_STATUS.DEAD_STATUS) or not slowed then begin
      if tgt^.hpCur = 0 then
        tgt^.hpCur := 1;
      if GameVars.ifcState = C_IFC.IN_COMBAT then
        Magic.StandUpOrWake(tgt)
      else begin
        tgt^.enabled := 1;
        tgt^.status := C_STATUS.OKAY;
      end;
    end;
    CharDisp.RedrawPartyOutOfCombat;
  end else
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True);
end;

procedure SpellPoison;
var
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.spellTargets[1];
  if (tgt = nil) or (GameVars.ifcState <> C_IFC.IN_COMBAT) then
    Exit;
  CharHlp.RecalcStats(tgt);
  FxEngine.TriggerEffectsWithCondition(C_COND.DEFENDER_AC, tgt);
  if not FxEngine.AttackRoll(GameVars.curChar, tgt, tgt^.acCur) then
    CharDisp.PrintNameString(GameVars.curChar, 'misses', 10, True)
  else if FxEngine.EffectImmune(tgt, C_EFFECT.POISONED) then
    CharDisp.PrintNameString(tgt, 'is Unaffected', 10, True)
  else begin
    GameVars.curChar^.combatAddr^.other := tgt;
    FxEngine.CallEffectHandler(C_EFFECT.POISON_HIT0, GameVars.curChar, nil, False);
  end;
end;

procedure SpellSticksToSnakes;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  if tgt^.levelHighest < 6 then begin
    Magic.ResolveSpell(GameVars.spellId, CharHlp.GetCasterLevel(GameVars.spellId), False, 0, 0, '');
    if CharHlp.HasEffect(tgt, C_EFFECT.STICKS_TO_SNAKES, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.STICKS_TO_SNAKES, tgt, effect, False);
  end else
    CharDisp.PrintNameString(tgt, 'smashes them flat', 10, True);
end;

procedure SpellCureCriticalWounds;
begin
  if GameVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GameVars.spellTargets[1], Dice.RollDice(3, 8) + 3, False) then
    CharDisp.PrintHpRestoreMsg(GameVars.spellTargets[1]);
end;

procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(3, 8) + 3, C_EFFECT.ELEM_MAGIC, '');
end;

procedure SpellDispelEvil;
begin
  FxEngine.AddEffectWithMessage(GameVars.curChar, C_EFFECT.DISPEL_EVIL, Magic.CalcSpellDuration(GameVars.spellId),
                                CharHlp.GetCasterLevel(GameVars.spellId), False, False, False, '');
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is affected');
end;

procedure SpellFlameStrike;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(6, 8), C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC,
                     '');
end;

procedure SpellRaiseDead;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  if (tgt^.status = C_STATUS.DEAD_STATUS) and CharHlp.HasEffect(tgt, C_EFFECT.POISONED, effect) then
    CharDisp.PrintNameString(tgt, 'is still poisoned', 10, True)
  else if ((tgt^.status = C_STATUS.DEAD_STATUS) or (tgt^.status = C_STATUS.ANIMATED)) and (tgt^.conCur > 0) and
      (tgt^.race <> C_RACE.ELF) then begin
    GameVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_EFFECT.ANIMATE_DEAD, nil);
    if Dice.RollDice(1, 100) > AbilAdj.ConResurrectionSurvival(tgt^.conCur) then begin
      GameVars.effectLock := 0;
      tgt^.status := C_STATUS.GONE;
      tgt^.enabled := 0;
      tgt^.hpCur := 0;
      CharDisp.PrintNameString(tgt, 'does not survive', 10, True);
    end else begin
      FxEngine.RemoveEffect(tgt, C_EFFECT.POISONED, nil);
      GameVars.effectLock := 0;
      tgt^.status := C_STATUS.OKAY;
      tgt^.enabled := 1;
      if tgt^.conCur > AbilAdj.SCORE_MIN then
        ClassCal.LoseConstitution(tgt);
      tgt^.hpCur := 1;
      Stats.Count(tgt, Stats.RAISED, 1);
      CharDisp.PrintNameString(tgt, 'is raised', 10, True);
    end;
    CharDisp.RedrawPartyOutOfCombat;
  end else
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True);
end;

procedure SpellSlayLiving;
var
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  { the spell's resistances: magic resistance, the globes }
  GameVars.elementMask := C_EFFECT.ELEM_MAGIC;
  GameVars.pendingDamage := 1;
  GameVars.pendingEffectId := 0;
  FxEngine.TriggerEffectsWithCondition(C_COND.EFFECT_IMMUNITY, tgt);
  { the undead are not living (1st-edition PHB; Curse slew them too) }
  if (GameVars.pendingDamage = 0) or (tgt^.charType = CharHlp.UNDEAD_TYPE) then
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True)
  else if not FxEngine.RollSavingThrow(tgt, C_SAVE.PARALYZE, 0) then
    EffHndlr.InflictStatusMsg(tgt, C_STATUS.DEAD_STATUS, 'is slain')
  else
    FxEngine.InflictNonWeaponDamage(tgt, Dice.RollDamageDice(2, 8) + 1, 0, False);
  GameVars.elementMask := 0;
end;

procedure SpellEntangle;
var
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  effect: Types.PEffectRec;
begin
  GameVars.gMultiTarget := 1;
  if GameVars.zone0^.view3dFlag <> 0 then begin
    CharDisp.PrintNameString(GameVars.curChar, 'finds no plants here', 10, True);
    Exit;
  end;
  for i := 1 to GameVars.spellTargetCount do
    if GameVars.spellTargets[i] <> nil then begin
      tgt := GameVars.spellTargets[i];
      { a creature an earlier Entangle holds or slows keeps that one, unsaved, so it never carries two }
      if CharHlp.HasEffect(tgt, C_EFFECT.ENTANGLE, effect) then
        CharDisp.PrintNameString(tgt, 'is already entangled', 10, True)
      else begin
        saved := FxEngine.RollSavingThrow(tgt, C_SAVE.SPELL, 0);
        { 1st-edition PHB: a creature that saves still moves at half speed through the plants }
        if saved then
          FxEngine.AddEffectWithMessage(tgt, C_EFFECT.ENTANGLE, Magic.CalcSpellDuration(GameVars.spellId), 1, False,
                                        False, False, 'is slowed by the plants')
        else
          FxEngine.AddEffectWithMessage(tgt, C_EFFECT.ENTANGLE, Magic.CalcSpellDuration(GameVars.spellId), 0, False,
                                        False, False, 'is entangled');
        { this round's movement too }
        if CharHlp.HasEffect(tgt, C_EFFECT.ENTANGLE, effect) and (tgt^.combatAddr <> nil) then
          if saved then
            tgt^.combatAddr^.movement := tgt^.combatAddr^.movement div 2
          else
            tgt^.combatAddr^.movement := 0;
      end;
    end;
end;

{ The spell's effect on each target, the last picked first, a missile drawn to each but the last, with a save at
  saveMod (none against Faerie Fire), at the caster level; for Charm Monsters the caster's team in bit 7, as Charm
  Person does, and the handler asked for on removal so EffCharm gives a creature its side back. Curse's, for the pool
  spells. }
procedure ApplyEffectToTargets(saveMod: ShortInt; msg: Types.TStr40);
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  saveNegates: Boolean;
  i: Byte;
  strength: Byte;
begin
  for i := GameVars.spellTargetCount downto 1 do
    if GameVars.spellTargets[i] <> nil then begin
      tgt := GameVars.spellTargets[i];
      if i < GameVars.spellTargetCount then begin
        SoundDrv.SoundSetAutoStop(0);
        SoundDrv.SoundEffect(GameDefs.soundIds.commands[C_SOUND.CAST], C_SOUND.GROUP_SPELL);
        CharDisp.AnimateBetween(GameVars.curChar, tgt, C_SPRITE.MISSILE, 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      if GameVars.spellId = C_SPELL.FAERIE_FIRE then begin
        saved := False;
        saveNegates := False;
      end else begin
        saved := FxEngine.RollSavingThrow(tgt, GameDefs.spellTable[GameVars.spellId].saveType, saveMod);
        saveNegates := GameDefs.spellTable[GameVars.spellId].saveResult in [C_SPELL.SAVE_NEGATES, C_SPELL.SAVE_SPECIAL];
      end;
      strength := CharHlp.GetCasterLevel(GameVars.spellId);
      if GameVars.spellId = C_SPELL.CHARM_MONSTERS then
        strength := CharHlp.Team(GameVars.curChar) * 128 + strength;
      FxEngine.AddEffectWithMessage(tgt, GameDefs.spellTable[GameVars.spellId].effect,
                                    Magic.CalcSpellDuration(GameVars.spellId), strength,
                                    GameVars.spellId = C_SPELL.CHARM_MONSTERS, saveNegates, saved, msg);
    end;
end;

procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, 'is outlined');
end;

procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is hidden from animals');
end;

procedure SpellCharmMonsters;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  Magic.ApplyEffectToTargets(0, 'is charmed');
  for i := 1 to GameVars.spellTargetCount do
    if GameVars.spellTargets[i] <> nil then
      if CharHlp.HasEffect(GameVars.spellTargets[i], C_EFFECT.CHARM, effect) then
        FxEngine.CallEffectHandler(C_EFFECT.CHARM, GameVars.spellTargets[i], effect, False);
end;

procedure SpellConfusion;
var
  i: Byte;
  most: Byte;
  tgt: Types.PCharRecord;
begin
  GameVars.gMultiTarget := 1;
  most := Dice.RollDice(C_SPELL.CONFUSION_DICE, C_SPELL.CONFUSION_DIE);
  if GameVars.spellTargetCount > most then
    GameVars.spellTargetCount := most;
  for i := 1 to GameVars.spellTargetCount do
    if GameVars.spellTargets[i] <> nil then begin
      tgt := GameVars.spellTargets[i];
      FxEngine.AddEffectWithMessage(tgt, C_EFFECT.CONFUSION, Magic.CalcSpellDuration(GameVars.spellId),
                                    CharHlp.GetCasterLevel(GameVars.spellId), False, True,
                                    FxEngine.RollSavingThrow(tgt, C_SAVE.SPELL, 0), 'is confused');
    end;
end;

procedure SpellDimensionDoor;
var
  caster: Types.PCharRecord;
  x: ShortInt;
  y: ShortInt;
begin
  caster := GameVars.curChar;
  if (GameVars.ifcState <> C_IFC.IN_COMBAT) or (CbtMap.CombatSlot(caster) = 0) then
    Exit;
  x := CbtMap.CombatCellX(caster);
  y := CbtMap.CombatCellY(caster);
  if CbtMap.IsValidCreatureLoc(caster, gTargetX, gTargetY, True) then begin
    { a hold on the caster lets go once it is no longer held fast (FxEngine.HoldTarget) }
    FxEngine.RemoveEffect(caster, C_EFFECT.IMMOBILE, nil);
    CbtMap.RedrawArenaCell(x, y);
    CbtMap.DisplayMapViewCentered(caster, 3, False);
    CharDisp.PrintNameString(caster, 'teleports', 10, True);
  end else begin
    { IsValidCreatureLoc took the caster off the map: put it back }
    if CbtMap.IsValidCreatureLoc(caster, x, y, False) then ;
    CbtMap.RedrawArenaCell(x, y);
    CharDisp.PrintNameString(caster, 'cannot teleport there', 10, True);
  end;
end;

procedure SpellFear;
var
  caster: Types.PCharRecord;
  tgt: Types.PCharRecord;
  i: Byte;
  effect: Types.PEffectRec;
begin
  caster := GameVars.curChar;
  GameVars.gMultiTarget := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(caster), CbtMap.CombatCellY(caster), gTargetX, gTargetY,
                           C_SPELL.FEAR_CONE_RAYS, C_SPELL.FEAR_CONE_CELLS);
  for i := 1 to GameVars.spellTargetCount do begin
    tgt := GameVars.spellTargets[i];
    if not FxEngine.RollSavingThrow(tgt, C_SAVE.SPELL, 0) then begin
      FxEngine.AddEffectWithMessage(tgt, C_EFFECT.FEAR, Magic.CalcSpellDuration(GameVars.spellId),
                                    CharHlp.GetCasterLevel(GameVars.spellId), True, True, False, 'runs in terror');
      { only when the fear took: nothing would undo it for a creature that resisted }
      if CharHlp.HasEffect(tgt, C_EFFECT.FEAR, effect) then
        EffHndlr.StartFear(tgt);
    end else
      CharDisp.PrintNameString(tgt, 'is unaffected', 10, True);
  end;
end;

procedure SpellFireShield;
var
  ch: Char;
  ext: Boolean;
  done: Boolean;
  own: Byte;
  other: Byte;
  minutes: Word;
  lvl: Byte;
begin
  done := False;
  repeat
    if GameVars.curChar^.quickfight <> 0 then begin
      if Dice.RollDice(1, 2) = 1 then
        ch := 'H'
      else
        ch := 'C';
    end else
      ch := MenuCore.MenuHorizontal('flame type: ', 'Hot Cold', promptColor, optionColor, commandColor, False, False,
                                    ext);
    if (ch = 'H') or (ch = 'C') then begin
      if ch = 'H' then begin
        own := C_EFFECT.FIRE_SHIELD_HOT;
        other := C_EFFECT.FIRE_SHIELD_COLD;
      end else begin
        own := C_EFFECT.FIRE_SHIELD_COLD;
        other := C_EFFECT.FIRE_SHIELD_HOT;
      end;
      minutes := Magic.CalcSpellDuration(GameVars.spellId);
      lvl := CharHlp.GetCasterLevel(GameVars.spellId);
      { one kind of flames at a time }
      FxEngine.RemoveEffect(GameVars.curChar, other, nil);
      FxEngine.AddEffectWithMessage(GameVars.curChar, own, minutes, lvl, False, False, False, 'is protected');
      FxEngine.AddEffectWithMessage(GameVars.curChar, C_EFFECT.FIRE_SHIELD_ZAP, minutes, lvl, False, False, False, '');
      done := True;
    end else if MenuCore.YesNoMenu('Abort spell? ', promptColor, optionColor, commandColor) = 'Y' then
      done := True;
  until done;
end;

procedure SpellFumble;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  if not FxEngine.RollSavingThrow(tgt, C_SAVE.SPELL, 0) then begin
    FxEngine.AddEffectWithMessage(tgt, C_EFFECT.FUMBLE, Magic.CalcSpellDuration(GameVars.spellId),
                                  CharHlp.GetCasterLevel(GameVars.spellId), False, False, False, 'is clumsy');
    if CharHlp.HasEffect(tgt, C_EFFECT.FUMBLE, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.FUMBLE, tgt, effect, False);
  end else
    { 1st-edition PHB: a creature that saves is slowed }
    FxEngine.AddEffectWithMessage(tgt, C_EFFECT.SLOWED, Magic.CalcSpellDuration(GameVars.spellId),
                                  CharHlp.GetCasterLevel(GameVars.spellId), False, False, False, 'is slowed');
end;

procedure SpellIceStorm;
begin
  GameVars.gMultiTarget := 1;
  Magic.ResolveSpell(GameVars.spellId, 0, False, Dice.RollDamageDice(3, 10), C_EFFECT.ELEM_COLD or C_EFFECT.ELEM_MAGIC,
                     '');
end;

procedure SpellMinorGlobe;
begin
  Magic.ResolveSpell(GameVars.spellId, 0, False, 0, 0, 'is protected');
end;

procedure ConeShape(spell: Byte; var rays, reach: Byte);
begin
  if spell = C_SPELL.FEAR then
    rays := C_SPELL.FEAR_CONE_RAYS
  else
    rays := C_SPELL.COLD_CONE_RAYS;
  { the reach is CharHlp.SpellArea's, which the spell page shows }
  if CharHlp.SpellArea(spell, reach) = C_SPELL.AREA_CONE then ;
end;

procedure SpellCloudkill;
begin
  Magic.LayCloud(C_SPELL.CLOUDKILL, C_EFFECT.CAST_CLOUDKILL, 'Creates a poisonous cloud');
end;

procedure ConsiderCloudkill(creature: Types.PCharRecord);
var
  saveMod: ShortInt;
  killed: Boolean;
begin
  if (creature^.enabled = 0) or FxEngine.CloudkillProof(creature) then Exit;
  if not CbtMap.ProbeTerrain(creature, C_DIR.CENTER, C_TERR.CLOUDKILL) then Exit;
  killed := False;
  case FxEngine.CloudkillFate(creature^.levelHighest, saveMod) of
    C_SPELL.CLOUDKILL_KILLS: killed := True;
    C_SPELL.CLOUDKILL_SAVE:
      if FxEngine.RollSavingThrow(creature, C_SAVE.PARALYZE, saveMod + AbilAdj.ConPoisonSave(creature^.conCur)) then
        CharDisp.PrintNameString(creature, 'is Unaffected', 10, True)
      else
        killed := True;
  end;
  if killed then begin
    CharDisp.PrintNameString(creature, 'is Poisoned', 10, False);
    TextRend.PauseOnly;
    FxEngine.AddEffect(creature, C_EFFECT.POISONED, 0, 255, False);
    EffHndlr.InflictStatusMsg(creature, C_STATUS.DEAD_STATUS, 'is killed');
  end;
end;

procedure SpellConeOfCold;
var
  p: Types.PCharRecord;
  rays: Byte;
  reach: Byte;
  lvl: Byte;
begin
  p := GameVars.curChar;
  GameVars.gMultiTarget := 1;
  lvl := CharHlp.GetCasterLevel(GameVars.spellId);
  Magic.ConeShape(GameVars.spellId, rays, reach);
  Magic.CollectConeTargets(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), gTargetX, gTargetY, rays, reach);
  Magic.ResolveSpell(GameVars.spellId, 0, False, lvl + Dice.RollDamageDice(lvl, 4),
                     C_EFFECT.ELEM_COLD or C_EFFECT.ELEM_MAGIC, '');
end;

procedure SpellFeeblemind;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
  saveMod: ShortInt;
begin
  tgt := GameVars.spellTargets[1];
  if tgt = nil then
    Exit;
  if CharHlp.GetClassLevel(tgt, C_LEVEL.MAGE_BIT) > 0 then
    saveMod := -4
  else if CharHlp.GetClassLevel(tgt, C_LEVEL.CLERIC_BIT) > 0 then
    saveMod := 1
  else
    saveMod := -2;
  FxEngine.AddEffectWithMessage(tgt, C_EFFECT.FEEBLEMIND, 0, CharHlp.GetCasterLevel(GameVars.spellId), False, True,
                                FxEngine.RollSavingThrow(tgt, C_SAVE.SPELL, saveMod), 'is stupid');
  if CharHlp.HasEffect(tgt, C_EFFECT.FEEBLEMIND, effect) then
    FxEngine.CallEffectHandler(C_EFFECT.FEEBLEMIND, tgt, effect, False);
end;

{ The side ray beside a cone's line, from the line's last direction dir (C_DIR): its left-hand neighbour's direction
  (left) or its right-hand one's, as Curse's tables give them: a straight line's sides are the perpendiculars, a
  diagonal's the straight steps beside it. }
function SideDir(dir: Byte; left: Boolean): Byte;
begin
  if left then
    SideDir := (dir + 6 + (dir and 1)) and 7
  else
    SideDir := (dir + 2 - (dir and 1)) and 7;
end;

{ CollectConeTargets' and TraceCone's walk, Curse's WalkCone. With trace set it lists in cells every arena cell its
  lines cross and leaves the spell targets alone. }
procedure WalkCone(ox, oy, tx, ty: ShortInt; rays, reach: Byte; trace: Boolean; var cells: Types.TCellList);
var
  req: Types.TPathReq;
  done: Boolean;
  i: Word;
  n: Byte;
  lastDir: Byte;
  dirs: array[0..49] of Byte;
  list: array[0..30] of Byte;
  listCount: Byte;
  crIdx: Byte;
  terr: Byte;
  centerDir: Byte;
  walkDist: Word;
  sx: ShortInt;
  sy: ShortInt;
  k: Byte;

  { Start the line walk req from (ox, oy) to (ex, ey). }
  procedure SetLine(ex, ey: ShortInt);
  begin
    FillChar(req, SizeOf(req), 0);
    req.sx := ox;
    req.sy := oy;
    req.ex := ex;
    req.ey := ey;
    Pathing.PathFind(req);
  end;

  { Keep (cx, cy) on the arena. }
  procedure ClampCell(var cx, cy: ShortInt);
  begin
    if cx > Types.ARENA_LAST_X then
      cx := Types.ARENA_LAST_X
    else if cx < 0 then
      cx := 0;
    if cy > Types.ARENA_LAST_Y then
      cy := Types.ARENA_LAST_Y
    else if cy < 0 then
      cy := 0;
  end;

  { Walk the rest of req's line: with trace set list its cells, and add each creature on it to list once. }
  procedure CollectAlong(steer: Boolean);
  var
    j: Byte;
    found: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(req);
      if not done then begin
        if trace and (cells.count < SizeOf(cells.x)) then begin
          Inc(cells.count);
          cells.x[cells.count] := req.cx;
          cells.y[cells.count] := req.cy;
        end;
        CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
        if crIdx > 0 then begin
          { each cell afresh: a large creature fills several cells of a line }
          found := False;
          for j := 1 to listCount do
            if list[j] = crIdx then
              found := True;
          if not found and (listCount < 30) then begin
            Inc(listCount);
            list[listCount] := crIdx;
          end;
          { the side rays turn from the step onto the centre line's last creature }
          if steer then
            centerDir := req.step;
        end;
      end;
    until done;
  end;

begin
  cells.count := 0;
  listCount := 0;
  if (ox = tx) and (oy = ty) then begin
    if not trace then
      GameVars.spellTargetCount := 0;
    Exit;
  end;
  { the line's steps from the origin to the aim, repeated to carry it on to the full reach }
  n := 0;
  SetLine(tx, ty);
  repeat
    done := not Pathing.NextPathStep(req);
    if not done and (n <= 49) then begin
      dirs[n] := req.step;
      Inc(n);
    end;
  until done;
  lastDir := n - 1;
  n := 0;
  walkDist := reach;
  i := req.dist;
  done := False;
  while (i < Word(reach) * 2) and not done do
    if (tx < Types.ARENA_LAST_X) and (tx > 0) and (ty < Types.ARENA_LAST_Y) and (ty > 0) then begin
      if dirs[n] and 1 = 0 then
        Inc(i, 2)
      else
        Inc(i, 3);
      Inc(tx, GameDefs.dirDX[dirs[n]]);
      Inc(ty, GameDefs.dirDY[dirs[n]]);
      if n = lastDir then
        n := 0
      else
        Inc(n);
    end else
      done := True;
  ClampCell(tx, ty);
  { walls stop the centre line within the reach }
  if Pathing.WalkLine(ox, oy, tx, ty, walkDist, GameVars.arenaPtr) then ;
  centerDir := dirs[lastDir];
  SetLine(tx, ty);
  CollectAlong(True);
  if rays > 1 then begin
    sx := tx + GameDefs.dirDX[Magic.SideDir(centerDir, False)];
    sy := ty + GameDefs.dirDY[Magic.SideDir(centerDir, False)];
    ClampCell(sx, sy);
    SetLine(sx, sy);
    CollectAlong(False);
    if rays > 2 then begin
      sx := tx + GameDefs.dirDX[Magic.SideDir(centerDir, True)];
      sy := ty + GameDefs.dirDY[Magic.SideDir(centerDir, True)];
      ClampCell(sx, sy);
      SetLine(sx, sy);
      CollectAlong(False);
    end;
  end;
  if trace then
    Exit;
  GameVars.spellTargetCount := 0;
  FillChar(GameVars.spellTargets, SizeOf(GameVars.spellTargets), 0);
  for k := 1 to listCount do
    if GameVars.creatureArr[list[k]] <> GameVars.curChar then begin
      Inc(GameVars.spellTargetCount);
      GameVars.spellTargets[GameVars.spellTargetCount] := GameVars.creatureArr[list[k]];
    end;
end;

procedure CollectConeTargets(ox, oy, tx, ty: ShortInt; rays, reach: Byte);
var
  cells: Types.TCellList;
begin
  Magic.WalkCone(ox, oy, tx, ty, rays, reach, False, cells);
end;

procedure TraceCone(ox, oy, tx, ty: ShortInt; rays, reach: Byte; var cells: Types.TCellList);
begin
  Magic.WalkCone(ox, oy, tx, ty, rays, reach, True, cells);
end;

{ Unused item spell slot: does nothing. }
procedure UnusedSpellHandler;
begin
end;

{ Manual of Bodily Health: apply the item's effect at strength 255. }
procedure ManualBodilyHealthHandler;
begin
  Magic.ResolveSpell(GameVars.spellId, 255, True, 0, 0, 'is Reading');
end;

{ Bronze dragon breath, effect 88's handler. After the first round (roundCounter <> 0) it holds fire half the time.
  Otherwise the cast-target UI picks an aim for spell 51 (Lightning Bolt) with automatic targeting, and the aim becomes
  one step from the dragon toward it, plus one more step on each axis where that step is +1. A bolt of hpMax damage
  (save type 3) then hits that cell and runs C_SPELL.DRAGON_BOLT_CELLS cells. Charges live in the effect's strength:
  255 and 254 are decremented, anything lower removes the effect. removed is unused. }
procedure DragonBreathHandler(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  junk: Boolean;
  x: ShortInt;
  y: ShortInt;
begin
  if GameVars.roundCounter <> 0 then
    if Dice.RollDice(1, 100) <= 50 then
      Exit;
  x := CbtMap.CombatCellX(creature);
  y := CbtMap.CombatCellY(creature);
  CharDisp.PrintNameString(creature, 'Breathes!', 10, True);
  { the party sees it breathe, in the Bestiary (#1142) }
  Bestiary.Learn(creature, nil, C_BEAST.ATK_BREATH);
  GameVars.castTargetMenu(C_SPELL.LIGHTNING_BOLT, True, junk);
  gTargetX := x + Pathing.SignOf(gTargetX - x);
  gTargetY := y + Pathing.SignOf(gTargetY - y);
  if gTargetX = x + 1 then
    Inc(gTargetX);
  if gTargetY = y + 1 then
    Inc(gTargetY);
  FxEngine.RemoveInvisibility(creature);
  CharDisp.BuildIconFacings(C_SPRITE.LIGHTNING);
  CharDisp.CombatAnimateMovingIcon(x, y, gTargetX, gTargetY, 4, 50);
  Magic.LightningAttackAt(gTargetX, gTargetY, creature^.hpMax, C_SAVE.BREATH, junk);
  Magic.LightningPath(C_SPELL.DRAGON_BOLT_CELLS, creature^.hpMax, C_SAVE.BREATH, False);
  { Remaining breath charges }
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(creature, C_EFFECT.DRAGON_BREATH, p);
  junk := CharHlp.EndActions(creature);
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);
var
  item: Types.PItemRec;
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  item := it;
  sp := spell and C_SPELL.ID_MASK;
  found := 0;
  for i := 1 to SizeOf(item^.spells) do
    if item^.spells[i] and C_SPELL.ID_MASK = sp then
      found := i;
  for i := 1 to 3 do
    if Types.PItemRec(it)^.spells[i] = spell then
      found := i;
  if found = 0 then
    Exit;
  item^.spells[found] := 0;
  { scroll spell-count name component }
  Dec(item^.nameIds[2]);
  if item^.nameIds[2] < C_ITEM.NAME_WITH_1_SPELL then
    CharHlp.RemoveItem(Types.PCharRecord(cr), item);
end;

procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GameVars.ifcState = C_IFC.IN_COMBAT then begin
    CharDisp.PrintNameString(creature, 'Casts a Spell', 10, True);
    { the combat log names the spell after the message (#841) }
    CbtLog.Add(LightGreen, ' (' + GameDefs.spellNames[spell] + ')');
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 'Spell:' + GameDefs.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharDisp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 2, 19, LightGreen, msg);
    TextRend.DisplayString(1, 20, LightGreen, GameDefs.spellNames[spell]);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
end;

{ SpellMenu's work, with the chosen line's scroll in scroll. }
function ChooseSpell(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean;
  var scroll: Types.PItemRec): Byte;
begin
  notEmpty := Magic.GenerateSpellList(GameVars.curChar, menuType);
  if notEmpty then begin
    { every spell list has the same heading, centred in light cyan: "<name>'s Spells" (#900) }
    if idx < 0 then begin
      Border.DrawWindow(1, 1, 38, 1, 0, Black, '');
      TextRend.DisplayCentered(1, 38, 1, LightCyan, GameVars.curChar^.name + '''s Spells');
    end;
    ChooseSpell := Magic.SpellSelection(selType, idx, scroll);
  end else begin
    scroll := nil;
    ChooseSpell := 0;
  end;
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  scroll: Types.PItemRec;
begin
  SpellMenu := Magic.ChooseSpell(menuType, selType, idx, notEmpty, scroll);
end;

function CastSpellMenu(var idx: Integer; var notEmpty: Boolean; var scroll: Types.PItemRec): Byte;
begin
  CastSpellMenu := Magic.ChooseSpell(7, 1, idx, notEmpty, scroll);
end;

{ Cast spell from item, a scroll or an effect-bearing item (spell is then CharHlp.ItemSpell's), setting usingItem during
  the cast. A combat-only scroll spell outside combat is not cast: Cast's message (Magic.ShowCombatOnlySpell) and 'Use
  it?', where Yes sets done and spends the scroll spell and No leaves done clear. In combat, a spell castable in combat
  (whenCast <> 0) ends the user's actions and sets done, cast or not. Past that prompt, only when the spell was cast,
  consume the scroll spell, or use quantity and then charges; remove the item when its charges run out (SSI spent them
  on done, so an aborted spell in combat still used them up). announce (the Cast list's scroll lines) names the spell
  first, as casting a memorized one does (Magic.PrintCastSpellMsg); Use names none. A spell id past the spell table,
  from corrupt or edited item data, does nothing and leaves done clear. }
procedure UseItemSpell(item: Types.PItemRec; spell: Byte; announce: Boolean; var done: Boolean);
var
  { set only when the spell was cast (not on an aborted aim); the item is spent on it, not on done, which in combat
    also reports the end of the turn }
  cast: Boolean;
begin
  if (spell < 1) or (spell > C_SPELL.TABLE_LAST) then begin
    done := False;
    Exit;
  end;
  if CharHlp.ItemReadable(item) and (GameVars.ifcState <> C_IFC.IN_COMBAT) and
      (GameDefs.spellTable[spell].target = 0) then begin
    Magic.ShowCombatOnlySpell(spell);
    done := MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y';
    CharDisp.ClearMessageWindow;
    if done then
      Magic.RemoveSpellFromScroll(GameVars.curChar, item, spell);
    Exit;
  end;
  if (GameVars.ifcState = C_IFC.IN_COMBAT) and (GameVars.curChar^.quickfight = 0) then
    CharDisp.DisplayCombatInterface;
  if not CharHlp.ItemReadable(item) then begin
    CharDisp.PrintNameString(GameVars.curChar, 'uses an item', 10, False);
    if GameVars.ifcState = C_IFC.IN_COMBAT then begin
      TextRend.DisplayString(0, 23, LightGreen, 'Item:');
      CharDisp.PrintItemLabel(item, 5, 23);
    end else
      CharDisp.PrintItemLabel(item, 1, 22);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
  GameVars.usingItem := True;
  if announce then
    Magic.PrintCastSpellMsg(GameVars.curChar, 'casts', spell);
  cast := False;
  Magic.CastSpell(spell, GameVars.curChar^.quickfight <> 0, False, cast);
  GameVars.usingItem := False;
  done := cast;
  if GameVars.ifcState = C_IFC.IN_COMBAT then
    if GameDefs.spellTable[spell].whenCast <> 0 then
      done := CharHlp.EndActions(GameVars.curChar);
  if cast then
    Magic.SpendItemSpell(GameVars.curChar, item, spell);
end;

procedure SpendItemSpell(user: Types.PCharRecord; item: Types.PItemRec; spell: Byte);
begin
  if CharHlp.ItemReadable(item) then
    Magic.RemoveSpellFromScroll(user, item, spell)
  else if item^.charges > 0 then begin
    if item^.quantity > 1 then
      Dec(item^.quantity)
    else begin
      Dec(item^.charges);
      if item^.charges = 0 then
        CharHlp.RemoveItem(user, item);
    end;
  end;
end;

procedure CastItemSpellOn(user: Types.PCharRecord; item: Types.PItemRec; spell: Byte; target: Types.PCharRecord);
var
  caster: Types.PCharRecord;
begin
  if (spell < 1) or (spell > C_SPELL.TABLE_LAST) then Exit;
  caster := GameVars.curChar;
  GameVars.curChar := user;
  GameVars.spellTargets[1] := target;
  GameVars.spellTargetCount := 1;
  GameVars.usingItem := True;
  GameVars.spellId := spell;
  GameVars.spellFns[spell];
  GameVars.spellId := C_SPELL.NONE;
  GameVars.usingItem := False;
  Magic.SpendItemSpell(user, item, spell);
  CharHlp.RecalcStats(user);
  GameVars.curChar := caster;
end;

{ Cast from a scroll (spell chosen from its list) or an effect-bearing item through UseItemSpell. }
procedure UseItem(item: Types.PItemRec; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GameVars.usingItem := False;
  spell := 0;
  if CharHlp.ItemReadable(item) then begin
    currentScrollPtr := item;
    spell := Magic.SpellMenu(2, 1, idx, notEmpty);
  end else
    spell := CharHlp.ItemSpell(item);
  if spell = 0 then
    done := False
  else
    Magic.UseItemSpell(item, spell, False, done);
end;

begin
  { Turbo Pascal clears no variable }
  gTargetX := 0;
  gTargetY := 0;
  @belowListHook := nil;
  scrollList := False;
end.
