{ Spell-list summaries and the full Info page (#839). Values come from the same
  tables and calculations used when casting, so the displayed range, area,
  duration, and caster level match the actual spell behavior. SpellTxt supplies
  the descriptions.

  FROM_ITEM marks scrolls, potions, wands, and other item-cast spells. Those use
  the same page with the item's caster level and targeting rules (#861). }
{$O+,F+}
{$I COMPILER.INC}
unit SpellInf;

interface

uses Types, C_SPELL, C_ITEM;

const
  { the summary line's widest text: the list window's columns }
  SUMMARY_WIDTH = 38;
  { the page's description: its most lines and their columns }
  TEXT_LINES = 9;
  TEXT_COLS = 36;
  { the page's figures: the column their values start in, and the columns they have up to the window's edge }
  VALUE_COL = 15;
  VALUE_WIDTH = 24;

type
  { the list lines a page steps through, each as a list line's spell }
  TLineSpells = array[0..C_SPELL.LINE_LAST] of Word;
  { the items an item page steps through }
  TPageItems = array[0..C_ITEM.CARRY_MAX - 1] of Types.PItemRec;
  PPageItems = ^TPageItems;

{ Returns the result of a successful save: none, negates, half, or partial. The
  spell table only says whether to roll; individual handlers define the result. }
function SaveResult(spell: Byte): Byte;

{ These helpers format one spell-list entry. long selects the full page value
  instead of the compact summary term. Inapplicable values are empty. }

{ Range in squares (RNG 6), or SELF or TOUCH; none for a spell that is not aimed (Snake Charm, Animate Dead) or is cast
  only in camp on a character the player picks. }
function RangeText(line: Word; long: Boolean): Types.TStr40;

{ What the spell reaches (CharHlp.SpellArea): a radius (AREA R2), an aura around its target or caster, Stinking
  Cloud's 2x2 block, Lightning Bolt's path, a cone from the caster (AREA CONE), up to a number of creatures picked
  (TGT 1-3) or as many as a pool buys (TGT POOL), every creature it seeks on the field (AREA ALL) or the whole party in
  camp (AREA PARTY). A single creature, or the caster, has no short term. }
function AreaText(line: Word; long: Boolean): Types.TStr40;

{ AreaText's page value for a spell an item casts: a potion or other item cast only on its user reads USER, not THE
  CASTER (#861). }
function ItemAreaText(line: Word): Types.TStr40;

{ Formats duration in rounds, turns, or hours. Fixed and per-level parts use the
  same unit. Random durations show their dice; immediate and indefinite effects
  use INST and PERM. }
function DurationText(line: Word; long: Boolean): Types.TStr40;

{ The saving throw (SaveResult) and, on the page, its column (VS SPELL); none when no save is rolled. }
function SaveText(spell: Byte; long: Boolean): Types.TStr40;

{ When it can be cast: CAMP or CBT for a spell cast only there, none for either; Knock, cast only at a locked door,
  DOORS. }
function WhenText(spell: Byte; long: Boolean): Types.TStr40;

{ The caster level a line's spell is cast at (CharHlp.GetCasterLevel), or the item fireball's levels, which it rolls
  (3, 5 OR 7). }
function CasterLevelText(line: Word): Types.TStr40;

{ Formats casting time. Item spells and zero-initiative spells act at once;
  other combat spells show their initiative cost. Camp-only spells leave it blank. }
function CastTimeText(line: Word): Types.TStr40;

{ The summary line: the short terms of RangeText, AreaText, DurationText, SaveText and WhenText that apply, two blanks
  apart, or one when two would run past SUMMARY_WIDTH. }
function Summary(line: Word): Types.TStr40;

{ A string as long as Summary(line), K under each term's key (its first word) and a blank under the rest: ShowSummary
  draws the one in white and the other in light green (#1072). }
function SummaryKeys(line: Word): Types.TStr40;

{ Line n (from 1) of spell's description (SpellTxt), or an empty string past its last. }
function TextLine(spell, n: Byte): Types.TStr40;

{ Draw line's summary on row over the list window's columns, each term's key (its first word) in white and its value in
  light green (#1072); line 0 (a level heading) clears it. }
procedure ShowSummary(line: Word; row: Byte);

{ Browses full spell pages over the list window. Next and Previous wrap through
  the entries. cur is updated to the last page shown. }
procedure ShowPage(var lines: TLineSpells; count: Integer; var cur: Integer);

{ True when Use on item casts a spell (CharHlp.ItemSpell) the page has a description for, and item is identified, so
  that the page tells nothing Id would. }
function HasItemPage(item: Types.PItemRec): Boolean;

{ The spell page for items[cur], as ShowPage's, each item's spell worked out as Use casts it. An item effect past
  C_SPELL.LAST, which has no spell name, is headed by the item's name, MAGIC ITEM and its caster level; CAST BY names
  the item. Next and Prev step through the count items, and Exit leaves cur the item shown last. }
procedure ShowItemPage(var items: TPageItems; count: Integer; var cur: Integer);

implementation

uses Crt, GameDefs, GameVars, C_KEYS, CharHlp, FxEngine, StrUtil, TextRend, Border, MenuCore, CharDisp, SpellTxt,
  UiColor;

const
  { what a save does against each spell, checked against the handlers (Magic): Silence's negates its aura, Stinking
    Cloud's leaves the creature coughing for a round (FxEngine.ConsiderStinkingCloud) }
  saveResults: array[1..C_SPELL.TABLE_LAST] of Byte = (
    { 1..10: Bless .. Charm Person }
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    { 11..20: Detect Magic .. Shocking Grasp; Reduce's handler rolls its own }
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    { 21..30: Sleep .. Invisibility; Hold Person, Silence }
    0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
    { 31..40: Knock .. Cause Disease; Ray of Enfeeblement, Stinking Cloud, Cause Blindness, Cause Disease }
    0, 0, 1, 4, 0, 0, 0, 1, 0, 1,
    { 41..50: Dispel Magic .. Invisibility, 10' Radius; Bestow Curse, Fireball, Hold Person }
    0, 0, 0, 1, 0, 0, 2, 0, 1, 0,
    { 51..56: Lightning Bolt .. Restoration }
    2, 0, 0, 0, 0, 0,
    { 57..65: the item spells Potion of Speed .. Wand of Magic Missiles, and 58, Cure Serious Wounds; the Javelin of
      Lightning's bolt (Magic.LightningAttackAt), the Wand of Paralyzation and the item fireball }
    0, 0, 0, 2, 1, 0, 0, 2, 0,
    { 66..70: Cause Serious Wounds .. Sticks to Snakes; Poison }
    0, 0, 1, 0, 0,
    { 71..80: Cure Critical Wounds .. Invisibility to Animals; Flame Strike, Slay Living (it still deals 2d8+1),
      Entangle (it still slows) }
    0, 0, 0, 2, 0, 4, 0, 4, 0, 0,
    { 81..90: Charm Monsters .. Animate Dead; Confusion, Fear, Fumble (it still slows) }
    1, 1, 0, 1, 0, 4, 0, 0, 0, 0,
    { 91..100: Cloudkill (a save spares those of levels 5 and 6), Cone of Cold, Feeblemind, Hold Monsters and Bestow
      Curse; 95..99 hold no spell }
    1, 2, 1, 1, 0, 0, 0, 0, 0, 1,
    { 101..126 hold no spell (#1121) }
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    { 127 and 128: Keoghtom's Ointment and the Manual of Bodily Health }
    0, 0);
  { AreaText's value for a spell cast only on its caster }
  CASTER_AREA = 'THE CASTER';
  { the save columns' names, by C_SAVE; column 0 is paralyzation, poison and death magic, named PARALYSIS }
  saveNames: array[0..4] of String[9] = (
    'PARALYSIS', 'PETRIFY', 'WAND', 'BREATH', 'SPELL');

{ line's spell id, with GameVars.usingItem set as casting it would set it; old receives usingItem to restore. }
function UseLine(line: Word; var old: Boolean): Byte;
begin
  old := GameVars.usingItem;
  GameVars.usingItem := line and C_SPELL.FROM_ITEM <> 0;
  UseLine := line and C_SPELL.LINE_ID_MASK;
end;

{ True for a spell cast only in camp: spellTable's whenCast 0 (CbtActs turns such a spell away in combat). }
function CampOnly(spell: Byte): Boolean;
begin
  CampOnly := GameDefs.spellTable[spell].whenCast = 0;
end;

function SaveResult(spell: Byte): Byte;
begin
  if (spell >= 1) and (spell <= C_SPELL.TABLE_LAST) then
    SaveResult := saveResults[spell]
  else
    SaveResult := C_SPELL.SAVE_NONE;
end;

function RangeText(line: Word; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  size: Byte;
  s: Types.TStr40;
begin
  spell := UseLine(line, old);
  s := '';
  with GameDefs.spellTable[spell] do
    if spell = C_SPELL.KNOCK then begin
      if long then
        s := 'TOUCH';
    end else if CampOnly(spell) then begin
      if target = 1 then
        s := 'SELF'
      else if long then
        s := 'ANY OF THE PARTY';
    end else if CharHlp.SpellArea(spell, size) = C_SPELL.AREA_SELF then begin
      if target = 1 then
        s := 'SELF'
      else if long then
        s := 'ANYWHERE';
    end else if (rangeFixed = C_SPELL.ATTACK_ROLL_RANGE) or (rangeFixed + rangeVar = 0) then
      s := 'TOUCH'
    else if long then
      s := StrUtil.Count(CharHlp.CalcSpellRange(spell), 'SQUARE', 'SQUARES')
    else
      s := StrUtil.NumStr(CharHlp.CalcSpellRange(spell));
  if (s <> '') and not long then
    s := 'RNG ' + s;
  RangeText := s;
  GameVars.usingItem := old;
end;

function AreaText(line: Word; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  kind: Byte;
  size: Byte;
  aura: Byte;
  s: Types.TStr40;
  l: Types.TStr40;
begin
  spell := UseLine(line, old);
  s := '';
  l := '';
  kind := CharHlp.SpellArea(spell, size);
  { the Javelin of Lightning strikes the creature aimed at, then runs on as a bolt (Magic.SpellJavelinOfLightning) }
  if spell = C_SPELL.ITEM_JAVELIN_LIGHTNING then begin
    kind := C_SPELL.AREA_BOLT;
    size := C_SPELL.JAVELIN_BOLT_CELLS;
  end;
  aura := 0;
  with GameDefs.spellTable[spell] do begin
    if effect > 0 then
      aura := FxEngine.AuraRange(effect);
    if spell = C_SPELL.KNOCK then
      l := 'ONE DOOR'
    else if CampOnly(spell) then
      case target of
        1: l := CASTER_AREA;
        4: begin
             s := 'AREA PARTY';
             l := 'THE WHOLE PARTY';
           end;
      else
        l := '1 CHARACTER';
      end
    else if aura > 0 then begin
      s := 'AREA R' + StrUtil.NumStr(aura);
      if kind = C_SPELL.AREA_SELF then
        l := 'RADIUS ' + StrUtil.NumStr(aura) + ' AROUND CASTER'
      else
        l := 'RADIUS ' + StrUtil.NumStr(aura) + ' AROUND TARGET';
    end else
      case kind of
        C_SPELL.AREA_SELF:
          if target = 1 then
            l := CASTER_AREA
          else begin
            s := 'AREA ALL';
            l := 'THE WHOLE FIELD';
          end;
        C_SPELL.AREA_TARGETS:
          if size = 1 then
            l := '1 CREATURE'
          else begin
            s := 'TGT 1-' + StrUtil.NumStr(size);
            l := 'UP TO ' + StrUtil.NumStr(size) + ' CREATURES';
          end;
        C_SPELL.AREA_SPOT: l := '1 CREATURE';
        C_SPELL.AREA_RADIUS: begin
            s := 'AREA R' + StrUtil.NumStr(size);
            l := 'RADIUS ' + StrUtil.Count(size, 'SQUARE', 'SQUARES');
          end;
        C_SPELL.AREA_CLOUD: begin
            s := 'AREA ' + StrUtil.NumStr(size) + 'x' + StrUtil.NumStr(size);
            l := StrUtil.NumStr(size) + 'x' + StrUtil.NumStr(size) + ' SQUARES';
          end;
        C_SPELL.AREA_BOLT: begin
            s := 'AREA BOLT';
            l := 'BOLT, ' + StrUtil.Count(size, 'SQUARE', 'SQUARES') + ' PAST AIM';
          end;
        C_SPELL.AREA_CONE: begin
            s := 'AREA CONE';
            l := 'CONE, ' + StrUtil.Count(size, 'SQUARE', 'SQUARES') + ' LONG';
          end;
        C_SPELL.AREA_POOL: begin
            s := 'TGT POOL';
            l := 'CREATURES BY POOL';
          end;
      end;
  end;
  if long then
    AreaText := l
  else
    AreaText := s;
  GameVars.usingItem := old;
end;

function ItemAreaText(line: Word): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := SpellInf.AreaText(line, True);
  if s = CASTER_AREA then
    s := 'USER';
  ItemAreaText := s;
end;

function DurationText(line: Word; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  d: Types.TDurDice;
  m: Word;
  { minutes to the unit shown: 1 rounds, 10 turns, 60 hours }
  u: Byte;
  s: Types.TStr40;
  n: Types.TStr20;
begin
  spell := UseLine(line, old);
  CharHlp.SpellDuration(spell, d);
  if d.count > 0 then begin
    n := StrUtil.NumStr(d.count) + 'D' + StrUtil.NumStr(d.sides);
    if d.add > 0 then
      n := n + '+' + StrUtil.NumStr(d.add);
    case d.mult of
      1: if long then s := n + ' ROUNDS' else s := n + ' RD';
      10: if long then s := n + ' TURNS' else s := n + ' TU';
    else
      if long then s := n + ' HOURS' else s := n + ' HR';
    end;
  end else begin
    m := d.add * d.mult;
    { the unit both the fixed part and the part per level come in, so a spell keeps its unit at every level }
    with GameDefs.spellTable[spell] do
      if d.mult > 1 then
        u := d.mult
      else if (durFixed mod 60 = 0) and (durVar mod 60 = 0) then
        u := 60
      else if (durFixed mod 10 = 0) and (durVar mod 10 = 0) then
        u := 10
      else
        u := 1;
    { Cloudkill's cloud lasts though the table names no effect for it (#1193) }
    if (m = 0) or ((GameDefs.spellTable[spell].effect = 0) and (spell <> C_SPELL.CLOUDKILL)) then begin
      if (m = 0) and (GameDefs.spellTable[spell].effect > 0) then begin
        if long then s := 'PERMANENT' else s := 'PERM';
      end else if long then
        s := 'INSTANT'
      else
        s := 'INST';
    end else if u = 60 then begin
      if long then s := StrUtil.Count(m div 60, 'HOUR', 'HOURS') else s := StrUtil.NumStr(m div 60) + ' HR';
    end else if u = 10 then begin
      if long then s := StrUtil.Count(m div 10, 'TURN', 'TURNS') else s := StrUtil.NumStr(m div 10) + ' TU';
    end else if long then
      s := StrUtil.Count(m, 'ROUND', 'ROUNDS')
    else
      s := StrUtil.NumStr(m) + ' RD';
  end;
  if not long then
    s := 'DUR ' + s;
  DurationText := s;
  GameVars.usingItem := old;
end;

function SaveText(spell: Byte; long: Boolean): Types.TStr40;
var
  s: Types.TStr40;
  vs: Types.TStr20;
begin
  spell := spell and C_SPELL.ID_MASK;
  { an id past the table has no save (SaveResult) and no column to read }
  vs := '';
  if (spell >= 1) and (spell <= C_SPELL.TABLE_LAST) then
    vs := ' (VS ' + saveNames[GameDefs.spellTable[spell].saveType mod 5] + ')';
  case SpellInf.SaveResult(spell) of
    C_SPELL.SAVE_NEGATES: if long then s := 'NEGATES' + vs else s := 'SAVE NEG';
    C_SPELL.SAVE_HALF: if long then s := 'HALVES DAMAGE' + vs else s := 'SAVE 1/2';
    C_SPELL.SAVE_PARTIAL: if long then s := 'LESSENS' + vs else s := 'SAVE PART';
  else
    if long then s := 'NONE' else s := '';
  end;
  SaveText := s;
end;

function WhenText(spell: Byte; long: Boolean): Types.TStr40;
var
  s: Types.TStr40;
begin
  spell := spell and C_SPELL.ID_MASK;
  if spell = C_SPELL.KNOCK then begin
    if long then s := 'AT A LOCKED DOOR' else s := 'DOORS';
  end else
    case GameDefs.spellTable[spell].whenCast of
      0: if long then s := 'IN CAMP' else s := 'CAMP';
      1: if long then s := 'IN COMBAT' else s := 'CBT';
    else
      if long then s := 'IN CAMP OR COMBAT' else s := '';
    end;
  WhenText := s;
end;

function CasterLevelText(line: Word): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  i: Byte;
  s: Types.TStr40;
begin
  spell := UseLine(line, old);
  if spell = C_SPELL.ITEM_FIREBALL then begin
    { Magic.SpellFireball's 1d ITEM_FIREBALL_DIE * 2 + 1 }
    s := '';
    for i := 1 to C_SPELL.ITEM_FIREBALL_DIE do begin
      if i = C_SPELL.ITEM_FIREBALL_DIE then
        s := s + ' OR '
      else if i > 1 then
        s := s + ', ';
      s := s + StrUtil.NumStr(i * 2 + 1);
    end;
  end else
    s := StrUtil.NumStr(CharHlp.GetCasterLevel(spell));
  CasterLevelText := s;
  GameVars.usingItem := old;
end;

function CastTimeText(line: Word): Types.TStr40;
var
  spell: Byte;
  n: Byte;
begin
  spell := line and C_SPELL.LINE_ID_MASK;
  n := GameDefs.spellTable[spell].castTime div 3;
  if line and C_SPELL.FROM_ITEM <> 0 then
    n := 0;
  if CampOnly(spell) then
    CastTimeText := ''
  else if n = 0 then
    CastTimeText := 'AT ONCE'
  else
    CastTimeText := 'LATER: -' + StrUtil.NumStr(n) + ' INITIATIVE';
end;

{ Line's summary, as Summary describes it, and in keys a string as long, K under each term's key (its first word: RNG,
  AREA, TGT, DUR, SAVE, or CAMP, CBT or DOORS alone) and a blank under the rest (#1072). }
function BuildSummary(line: Word; var keys: Types.TStr40): Types.TStr40;
var
  terms: array[1..5] of Types.TStr40;
  s: String;
  k: String;
  gap: Types.TStr20;
  i: Byte;
  j: Byte;
  n: Byte;
  pass: Byte;
begin
  terms[1] := SpellInf.RangeText(line, False);
  terms[2] := SpellInf.AreaText(line, False);
  terms[3] := SpellInf.DurationText(line, False);
  terms[4] := SpellInf.SaveText(line, False);
  terms[5] := SpellInf.WhenText(line, False);
  gap := '  ';
  for pass := 1 to 2 do begin
    s := '';
    k := '';
    for i := 1 to 5 do
      if terms[i] <> '' then begin
        if s <> '' then begin
          s := s + gap;
          k := k + gap;
        end;
        s := s + terms[i];
        n := Pos(' ', terms[i]);
        if n = 0 then
          n := Length(terms[i]) + 1;
        for j := 1 to Length(terms[i]) do
          if j < n then
            k := k + 'K'
          else
            k := k + ' ';
      end;
    if Length(s) > SUMMARY_WIDTH then
      gap := ' ';
  end;
  if Length(s) > SUMMARY_WIDTH then begin
    s[0] := Chr(SUMMARY_WIDTH);
    k[0] := Chr(SUMMARY_WIDTH);
  end;
  keys := k;
  BuildSummary := s;
end;

function Summary(line: Word): Types.TStr40;
var
  keys: Types.TStr40;
begin
  Summary := SpellInf.BuildSummary(line, keys);
end;

function SummaryKeys(line: Word): Types.TStr40;
var
  keys: Types.TStr40;
  s: Types.TStr40;
begin
  s := SpellInf.BuildSummary(line, keys);
  SummaryKeys := keys;
end;

function TextLine(spell, n: Byte): Types.TStr40;
var
  chunk: String;
  i: Byte;
  p: Byte;
begin
  TextLine := '';
  if (n < 1) or (n > SpellTxt.LineCount(spell)) then
    Exit;
  chunk := SpellTxt.TextChunk(spell, (n - 1) div SpellTxt.CHUNK_LINES);
  for i := 1 to (n - 1) mod SpellTxt.CHUNK_LINES do begin
    p := Pos(#13, chunk);
    if p = 0 then
      chunk := ''
    else
      Delete(chunk, 1, p);
  end;
  p := Pos(#13, chunk);
  if p > 0 then
    chunk[0] := Chr(p - 1);
  TextLine := chunk;
end;

procedure ShowSummary(line: Word; row: Byte);
var
  s: Types.TStr40;
  keys: Types.TStr40;
  i: Byte;
  first: Byte;
  color: Byte;
begin
  TextRend.PrintSpaces(1, row, Black, SUMMARY_WIDTH);
  if line and C_SPELL.LINE_ID_MASK = 0 then
    Exit;
  s := SpellInf.BuildSummary(line, keys);
  { a run of key letters, or of the rest, at a time }
  first := 1;
  for i := 1 to Length(s) do
    if (i = Length(s)) or (keys[i + 1] <> keys[first]) then begin
      if keys[first] = 'K' then
        color := White
      else
        color := LightGreen;
      TextRend.DisplayString(first, row, color, Copy(s, first, i - first + 1));
      first := i + 1;
    end;
end;

{ One figure row: label in light green, value in white from VALUE_COL. }
procedure Figure(row: Byte; lbl, value: Types.TStr40);
begin
  TextRend.DisplayString(1, row, LightGreen, lbl);
  TextRend.DisplayString(VALUE_COL, row, White, value);
end;

{ item's name as the item list would show a single one of it: no count, no Detect Magic mark, no trailing blank.
  item^.name is left as it was. }
function ItemName(item: Types.PItemRec): Types.TStr40;
var
  saved: Types.TStr40;
  qty: Byte;
  s: Types.TStr40;
begin
  saved := item^.name;
  qty := item^.quantity;
  item^.quantity := 0;
  CharHlp.ItemLabel(item, False);
  s := item^.name;
  item^.quantity := qty;
  item^.name := saved;
  if Copy(s, 1, 2) = '* ' then
    Delete(s, 1, 2);
  while (Length(s) > 0) and (s[Length(s)] = ' ') do
    Dec(s[0]);
  ItemName := s;
end;

{ The caster level after a name of used columns on the CAST BY row: ', LEVEL n', or ', LV n' when only that fits in
  VALUE_WIDTH, or nothing when neither does. }
function LevelAfter(used: Byte; lvl: Types.TStr40): Types.TStr40;
begin
  if used + Length(', LEVEL ' + lvl) <= VALUE_WIDTH then
    LevelAfter := ', LEVEL ' + lvl
  else if used + Length(', LV ' + lvl) <= VALUE_WIDTH then
    LevelAfter := ', LV ' + lvl
  else
    LevelAfter := '';
end;

{ Draw the page for line over the list window; item, when not nil, is the item it is used from. }
procedure DrawPage(line: Word; item: Types.PItemRec);
const
  FIGURE_TOP = 6;
  TEXT_TOP = 14;
var
  spell: Byte;
  lvl: Types.TStr40;
  s: Types.TStr40;
  i: Byte;
  row: Byte;
begin
  spell := line and C_SPELL.LINE_ID_MASK;
  lvl := SpellInf.CasterLevelText(line);
  Border.DrawWindow(1, 3, 38, 22, 0, Black, '');
  if CharHlp.IsSpell(spell) then begin
    TextRend.DisplayCentered(1, 38, 3, White, GameDefs.spellNames[spell]);
    case GameDefs.spellTable[spell].castClass of
      C_SPELL.CLASS_CLERIC: s := 'CLERIC';
      C_SPELL.CLASS_DRUID: s := 'DRUID';
    else
      s := 'MAGIC-USER';
    end;
    s := s + ' LEVEL ' + StrUtil.NumStr(GameDefs.spellTable[spell].levelSp);
  end else begin
    { an item spell has no name of its own, and its spell level means nothing }
    if item <> nil then
      TextRend.DisplayCentered(1, 38, 3, White, SpellInf.ItemName(item));
    s := 'MAGIC ITEM, CASTER LEVEL ' + lvl;
  end;
  TextRend.DisplayCentered(1, 38, 4, LightGreen, s);
  TextRend.DisplayString(1, FIGURE_TOP, LightGreen, 'CAST BY');
  if item <> nil then begin
    s := Copy(SpellInf.ItemName(item), 1, VALUE_WIDTH);
    if CharHlp.IsSpell(spell) then
      s := s + SpellInf.LevelAfter(Length(s), lvl);
    TextRend.DisplayString(VALUE_COL, FIGURE_TOP, White, s);
  end else if line and C_SPELL.FROM_ITEM <> 0 then
    TextRend.DisplayString(VALUE_COL, FIGURE_TOP, White, 'A SCROLL, LEVEL ' + lvl)
  else begin
    CharDisp.DisplayCreatureName(GameVars.curChar, VALUE_COL, FIGURE_TOP, False);
    TextRend.DisplayString(VALUE_COL + Length(GameVars.curChar^.name), FIGURE_TOP, White,
                           SpellInf.LevelAfter(Length(GameVars.curChar^.name), lvl));
  end;
  row := FIGURE_TOP + 1;
  Figure(row, 'RANGE', SpellInf.RangeText(line, True));
  if item <> nil then
    Figure(row + 1, 'AREA', SpellInf.ItemAreaText(line))
  else
    Figure(row + 1, 'AREA', SpellInf.AreaText(line, True));
  Figure(row + 2, 'DURATION', SpellInf.DurationText(line, True));
  Figure(row + 3, 'SAVING THROW', SpellInf.SaveText(line, True));
  Figure(row + 4, 'CAST', SpellInf.WhenText(line, True));
  s := SpellInf.CastTimeText(line);
  if s <> '' then
    Figure(row + 5, 'CASTING TIME', s);
  for i := 1 to TEXT_LINES do
    TextRend.DisplayString(1, TEXT_TOP + i - 1, LightGreen, SpellInf.TextLine(spell, i));
end;

{ ShowPage's and ShowItemPage's browser: the page for lines[cur], items^[cur] the item it is used from when items is not
  nil, with query heading the bottom line. }
procedure Browse(var lines: TLineSpells; items: PPageItems; count: Integer; var cur: Integer; query: Types.TStr20);
var
  ch: Char;
  ext: Boolean;
  menu: Types.TStr40;
  step: Integer;
  done: Boolean;
  item: Types.PItemRec;
begin
  if (count < 1) or (cur < 0) or (cur >= count) then
    Exit;
  if count > 1 then
    menu := 'Next Prev Exit'
  else
    menu := 'Exit';
  done := False;
  repeat
    item := nil;
    if items <> nil then
      item := items^[cur];
    SpellInf.DrawPage(lines[cur], item);
    step := 0;
    GameVars.horizChoice := 1;
    repeat
      ch := MenuCore.MenuHorizontal(query, menu, promptColor, optionColor, commandColor, True, False, ext);
      if ext then
        case ch of
          C_KEYS.UP, C_KEYS.PAGE_UP: step := -1;
          C_KEYS.DOWN, C_KEYS.PAGE_DOWN: step := 1;
        end
      else
        case ch of
          'P': step := -1;
          'N': step := 1;
          C_KEYS.NONE, 'E': done := True;
        end;
      if count < 2 then
        step := 0;
    until done or (step <> 0);
    if step <> 0 then
      cur := (cur + count + step) mod count;
  until done;
  TextRend.ClearBottomLine;
end;

procedure ShowPage(var lines: TLineSpells; count: Integer; var cur: Integer);
begin
  SpellInf.Browse(lines, nil, count, cur, 'Spell: ');
end;

function HasItemPage(item: Types.PItemRec): Boolean;
begin
  HasItemPage := (item^.unidMask = 0) and (SpellTxt.LineCount(CharHlp.ItemSpell(item)) > 0);
end;

procedure ShowItemPage(var items: TPageItems; count: Integer; var cur: Integer);
var
  lines: TLineSpells;
  i: Integer;
begin
  if count > C_ITEM.CARRY_MAX then
    count := C_ITEM.CARRY_MAX;
  for i := 0 to count - 1 do
    lines[i] := CharHlp.ItemSpell(items[i]) or C_SPELL.FROM_ITEM;
  SpellInf.Browse(lines, @items, count, cur, 'Item: ');
end;

end.
