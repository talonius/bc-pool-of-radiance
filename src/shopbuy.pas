{ The shop's Buy screen (mocks/new-shop.txt), in place of SSI's Buy list. The stock is listed under tabs by item type
  (All, Melee, Ranged, Armor, Ammo and Misc), all of it or only what the current character can use, a price and a name
  to a line, scrolling a line at a time with a scroll bar (MenuCore.lineScroll). Under the list are the character's and
  the pool's gold, then the character's armor class and damage now and with the highlighted item readied (TryOn), over
  the armor, shield, weapon and ammunition it has readied. Alt-1 to Alt-8 make another member the buyer; F1 lists the
  keys (KeyHelp.SHOP_KEYS). Overlaid. }
{$O+,F+}
{$I COMPILER.INC}
unit ShopBuy;

interface

uses Types, C_ITEM;

const
  { the tabs, in their order on the screen }
  TAB_ALL = 0;
  TAB_MELEE = 1;
  TAB_RANGED = 2;
  TAB_ARMOR = 3;
  TAB_AMMO = 4;
  TAB_MISC = 5;
  TAB_LAST = 5;
  { each tab's key, by tab (index tab + 1): All's L, Ammo's O and Misc's I, as A, M and the rest are taken }
  tabKeys: string[TAB_LAST + 1] = 'LMRAOI';
  { The item types the Melee, Ranged, Armor and Ammo tabs list, from the shipped ITEMS; Misc lists every type none of
    them does (scrolls, potions, wands, rings, jewellery), so no item is left off every tab but All. A weapon that
    strikes and is thrown (hand axe, club, hammer, javelin, spear: ITEMS's thrown bit) is on both Melee and Ranged.
    Melee: the weapons 1..40 but darts and quarrels, and the two-handed weapon 89. Ranged: the thrown weapons, darts,
    the bows, crossbows and sling, holy water and oil (85, 86, thrown) and the bows built on the Heavy Crossbow's row
    (94..96). Armor: body armor 48..58, the shield, what is worn in the gauntlets to boots slots (63..68), the girdle
    (76), bracers and the Cloak of Displacement (92). Ammo: quarrels and arrows. }
  MELEE_TYPES = [1..8, 10..27, 29..40, 89];
  RANGED_TYPES = [C_ITEM.HAND_AXE, C_ITEM.CLUB, C_ITEM.DART, C_ITEM.HAMMER, C_ITEM.JAVELIN, C_ITEM.SPEAR,
                  C_ITEM.COMPOSITE_LONG_BOW..C_ITEM.SLING, C_ITEM.HOLY_WATER_VIAL, C_ITEM.FLASK_OF_OIL, 94..96];
  ARMOR_TYPES = [48..59, 63..68, 76, C_ITEM.BRACERS, 92];
  AMMO_TYPES = [C_ITEM.QUARREL, C_ITEM.ARROW];
  { a list line: the price right-aligned in PRICE_WIDTH columns, a blank, and the name cut to NAME_WIDTH, the width the
    list box leaves before its blank column and the scroll bar's }
  PRICE_WIDTH = 6;
  NAME_WIDTH = 27;
  { the most items the list holds; a shop's stock past it is not listed }
  MAX_SHOWN = 128;

type
  { a character's armor class (TCharRecord.acCur) and its first attack's damage dice and bonus, as RecalcStats leaves
    them }
  TCombatFigures = record
    ac: Byte;
    rolls: Byte;
    dice: Byte;
    dmgMod: ShortInt;
  end;
  { what readying an item would do (TryOn) }
  TTryOn = record
    { the item is one a character readies: a weapon, armor, a shield, a ring or other worn item, arrows or quarrels }
    wearable: Boolean;
    { arrows or quarrels }
    ammo: Boolean;
    { it could be readied: the class may use it and no cursed item stands in its way; figures are then the character's
      with it readied }
    readies: Boolean;
    { arrows or quarrels the readied weapon shoots: the damage is the weapon's with them }
    ammoFits: Boolean;
    { the readied shield would be put away for the hands the item needs }
    shieldOff: Boolean;
    figures: TCombatFigures;
  end;
  { the stock a tab lists, in the stock's order }
  TShownList = record
    count: Integer;
    items: array[0..MAX_SHOWN - 1] of Types.PItemRec;
  end;

{ True when tab lists items of itemType: All every type, Misc every type no other tab lists. }
function InTab(itemType, tab: Byte): Boolean;

{ True when creature's classes may use item: its base item's class mask meets the character's item limits. }
function CanUse(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ True when readying item would change a character's armor class or damage, the items the NEW line shows: a weapon
  held in a hand or two (ITEMS gives some unused types the weapon slot and no hands), anything worn in the shield to
  ring slots, arrows or quarrels, and anything with an armor class of its own (acDescr above $7F, bracers among them,
  whose slot is none of those). Ready is offered on every item, but a scroll or potion readied changes nothing: ITEMS
  even gives some of them hands, which would put the weapon away. }
function Wearable(item: Types.PItemRec): Boolean;

{ True when the list for tab shows item to creature: in the tab, and usable by creature (CanUse) under usableOnly. }
function Shown(creature: Types.PCharRecord; item: Types.PItemRec; tab: Byte; usableOnly: Boolean): Boolean;

{ The items of stock that tab shows creature (Shown), in order, at most MAX_SHOWN. }
procedure FilterStock(stock: Types.PItemRec; creature: Types.PCharRecord; tab: Byte; usableOnly: Boolean;
                      var shown: TShownList);

{ item's place in shown from 0, or -1 when it is not there (nil is nowhere). }
function FindShown(var shown: TShownList; item: Types.PItemRec): Integer;

{ item's list line: its price (value, 1 when it is 0, as SSI's Buy list made it) right-aligned in PRICE_WIDTH columns,
  a blank and its label (CharHlp.ItemLabel, not as inventory) cut to NAME_WIDTH. }
function RowText(item: Types.PItemRec): Types.TStr40;

{ creature's armor class and damage as its stats stand (RecalcStats first). }
procedure GetFigures(creature: Types.PCharRecord; var f: TCombatFigures);

{ What readying a copy of item would do to creature, as Ready would do it with whatever is in the way put away first:
  what holds its slot or its ammunition slot (the first of two rings, for a third), then, while the hands it needs are
  not free, readied items held in a hand. A cursed item in the way, or one whose class mask the character does not meet,
  leaves readies False. creature's items and stats are as they were afterwards; no effect handler runs. }
procedure TryOn(creature: Types.PCharRecord; item: Types.PItemRec; var t: TTryOn);

{ An armor class as the View screen shows it (CharDisp.ArmorClassText): acCur less 60, negative above it. }
function AcText(ac: Byte): Types.TStr40;

{ Damage as the View screen shows it: '1d8', '1d8+1', '2d4-1'. }
function DmgText(var f: TCombatFigures): Types.TStr40;

{ The NEW line's armor class and damage for t against cur, the CURRENT line's: an item no one readies changes nothing,
  so both are cur's; one that cannot be readied gives '--' for both; arrows or quarrels the readied weapon does not
  shoot give '--' for damage. }
procedure NewTexts(var cur: TCombatFigures; var t: TTryOn; var ac, dmg: Types.TStr40);

{ Run the Buy screen over the shop's stock (GameVars.treasureItems) until Exit or Escape. }
procedure BuyScreen;

implementation

uses Crt, C_EQUIP, C_KEYS, GameVars, Border, CharDisp, CharHlp, KeyHelp, MenuCore, MoneyCal, Party, Shop, StrUtil,
  TextRend;

const
  { the screen (mocks/new-shop.txt): the tabs' row and their columns, the list box, the panel's rows and its right
    edge }
  TAB_ROW = 1;
  tabCols: array[TAB_ALL..TAB_LAST] of Byte = (2, 6, 12, 19, 25, 30);
  tabNames: array[TAB_ALL..TAB_LAST] of string[6] = ('All', 'Melee', 'Ranged', 'Armor', 'Ammo', 'Misc');
  { where each tab's key is in its name }
  tabKeyAt: array[TAB_ALL..TAB_LAST] of Byte = (2, 1, 1, 1, 4, 2);
  LIST_LEFT = 2;
  LIST_TOP = 3;
  LIST_RIGHT = 37;
  LIST_BOTTOM = 15;
  GOLD_ROW = 17;
  CURR_ROW = 18;
  NEW_ROW = 19;
  ARMOR_ROW = 20;
  WEAPON_ROW = 21;
  AMMO_ROW = 22;
  PANEL_LEFT = 2;
  PANEL_RIGHT = 37;
  { the gold line: 'Gold' at GOLD_COL, the character's gold ending at CHAR_GOLD_END and the pool's at PANEL_RIGHT }
  GOLD_COL = 18;
  CHAR_GOLD_END = 29;
  { where the Curr and New lines start }
  FIGURES_COL = 5;
  { the most items TryOn puts away: what holds the slot, a ring, and what holds the hands }
  OFF_MAX = 8;

function InTab(itemType, tab: Byte): Boolean;
begin
  case tab of
    TAB_ALL: InTab := True;
    TAB_MELEE: InTab := itemType in MELEE_TYPES;
    TAB_RANGED: InTab := itemType in RANGED_TYPES;
    TAB_ARMOR: InTab := itemType in ARMOR_TYPES;
    TAB_AMMO: InTab := itemType in AMMO_TYPES;
    TAB_MISC: InTab := not ((itemType in MELEE_TYPES) or (itemType in RANGED_TYPES) or (itemType in ARMOR_TYPES) or
                            (itemType in AMMO_TYPES));
  else
    InTab := False;
  end;
end;

function CanUse(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
begin
  CanUse := CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits <> 0;
end;

function Wearable(item: Types.PItemRec): Boolean;
var
  base: Types.PBaseItemRec;
begin
  base := CharHlp.BaseItem(item^.itemType);
  Wearable := ((base^.slot = C_EQUIP.WEAPON) and (base^.hands > 0)) or
              ((base^.slot >= C_EQUIP.SHIELD) and (base^.slot <= C_EQUIP.RING1)) or
              (item^.itemType = C_ITEM.ARROW) or (item^.itemType = C_ITEM.QUARREL) or (base^.acDescr > $7F);
end;

function Shown(creature: Types.PCharRecord; item: Types.PItemRec; tab: Byte; usableOnly: Boolean): Boolean;
begin
  Shown := ShopBuy.InTab(item^.itemType, tab) and (not usableOnly or ShopBuy.CanUse(creature, item));
end;

procedure FilterStock(stock: Types.PItemRec; creature: Types.PCharRecord; tab: Byte; usableOnly: Boolean;
                      var shown: TShownList);
begin
  shown.count := 0;
  while (stock <> nil) and (shown.count < MAX_SHOWN) do begin
    if ShopBuy.Shown(creature, stock, tab, usableOnly) then begin
      shown.items[shown.count] := stock;
      Inc(shown.count);
    end;
    stock := stock^.next;
  end;
end;

function FindShown(var shown: TShownList; item: Types.PItemRec): Integer;
var
  i: Integer;
begin
  FindShown := -1;
  if item <> nil then
    for i := shown.count - 1 downto 0 do
      if shown.items[i] = item then
        FindShown := i;
end;

function RowText(item: Types.PItemRec): Types.TStr40;
var
  name: Types.TStr40;
  price: Word;
begin
  CharHlp.ItemLabel(item, False);
  name := item^.name;
  while (Length(name) > 0) and (name[Length(name)] = ' ') do
    Dec(name[0]);
  if Length(name) > NAME_WIDTH then
    name[0] := Chr(NAME_WIDTH);
  price := item^.value;
  if price = 0 then
    price := 1;
  RowText := StrUtil.PadLeft(StrUtil.NumStr(price), PRICE_WIDTH) + ' ' + name;
end;

procedure GetFigures(creature: Types.PCharRecord; var f: TCombatFigures);
begin
  f.ac := creature^.acCur;
  f.rolls := creature^.curRollsA[1];
  f.dice := creature^.curDiceA[1];
  f.dmgMod := creature^.curModA[1];
end;

{ True when a readied item, other, holds the slot or the ammunition slot that item needs (FxEngine's InTheWay). }
function InTheWay(item, other: Types.PItemRec): Boolean;
var
  slot: Byte;
begin
  slot := CharHlp.BaseItem(item^.itemType)^.slot;
  InTheWay := ((slot <= C_EQUIP.BOOTS) and (CharHlp.BaseItem(other^.itemType)^.slot = slot)) or
              ((item^.itemType = C_ITEM.ARROW) and (other^.itemType = C_ITEM.ARROW)) or
              ((item^.itemType = C_ITEM.QUARREL) and (other^.itemType = C_ITEM.QUARREL));
end;

procedure TryOn(creature: Types.PCharRecord; item: Types.PItemRec; var t: TTryOn);
var
  trial: Types.TItemRec;
  base: Types.PBaseItemRec;
  off: array[1..OFF_MAX] of Types.PItemRec;
  offCount: Byte;
  p: Types.PItemRec;
  ammo: Types.PItemRec;
  hands: Integer;
  rings: Byte;
  blocked: Boolean;
  i: Byte;

  { Put p away for the trial, or note that a cursed p cannot go. }
  procedure PutAway(q: Types.PItemRec);
  begin
    if q^.cursed <> 0 then
      blocked := True
    else if offCount < OFF_MAX then begin
      Inc(offCount);
      off[offCount] := q;
      q^.equipped := 0;
    end else
      blocked := True;
  end;

begin
  FillChar(t, SizeOf(t), 0);
  t.wearable := ShopBuy.Wearable(item);
  t.ammo := item^.itemType in AMMO_TYPES;
  if not t.wearable or not ShopBuy.CanUse(creature, item) then
    Exit;
  trial := item^;
  trial.equipped := 1;
  trial.weaponSet := C_ITEM.SET_NONE;
  trial.next := nil;
  base := CharHlp.BaseItem(trial.itemType);
  offCount := 0;
  blocked := False;
  { what holds its slot or its ammunition slot }
  p := creature^.itemsAddr;
  while p <> nil do begin
    if (p^.equipped <> 0) and ShopBuy.InTheWay(@trial, p) then
      PutAway(p);
    p := p^.next;
  end;
  { a third ring: the first worn that is not cursed comes off }
  if base^.slot = C_EQUIP.RING1 then begin
    rings := 0;
    p := creature^.itemsAddr;
    while p <> nil do begin
      if (p^.equipped <> 0) and (CharHlp.BaseItem(p^.itemType)^.slot = C_EQUIP.RING1) then
        Inc(rings);
      p := p^.next;
    end;
    if rings >= 2 then begin
      p := creature^.itemsAddr;
      while (p <> nil) and
            ((p^.equipped = 0) or (p^.cursed <> 0) or (CharHlp.BaseItem(p^.itemType)^.slot <> C_EQUIP.RING1)) do
        p := p^.next;
      if p = nil then
        blocked := True
      else
        PutAway(p);
    end;
  end;
  { then, while the hands it needs are not free, readied items held in a hand, in the list's order, as ReadySet does;
    a cursed one stays }
  hands := 0;
  p := creature^.itemsAddr;
  while p <> nil do begin
    if p^.equipped <> 0 then
      Inc(hands, CharHlp.BaseItem(p^.itemType)^.hands);
    p := p^.next;
  end;
  p := creature^.itemsAddr;
  while (p <> nil) and (hands + base^.hands > 2) do begin
    if (p^.equipped <> 0) and (p^.cursed = 0) and (CharHlp.BaseItem(p^.itemType)^.hands > 0) and
        (offCount < OFF_MAX) then begin
      Dec(hands, CharHlp.BaseItem(p^.itemType)^.hands);
      if CharHlp.BaseItem(p^.itemType)^.slot = C_EQUIP.SHIELD then
        t.shieldOff := True;
      PutAway(p);
    end;
    p := p^.next;
  end;
  if hands + base^.hands > 2 then
    blocked := True;
  if blocked then
    t.shieldOff := False
  else begin
    t.readies := True;
    trial.next := creature^.itemsAddr;
    creature^.itemsAddr := @trial;
    CharHlp.RecalcStats(creature);
    ShopBuy.GetFigures(creature, t.figures);
    t.ammoFits := CharHlp.FindDamagingRangedWeapon(creature, ammo) and (ammo = @trial);
    creature^.itemsAddr := trial.next;
  end;
  for i := 1 to offCount do
    off[i]^.equipped := 1;
  CharHlp.RecalcStats(creature);
end;

function AcText(ac: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := StrUtil.NumStr(Abs(Integer(ac) - 60));
  if ac > 60 then
    s := '-' + s;
  AcText := s;
end;

function DmgText(var f: TCombatFigures): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := StrUtil.NumStr(f.rolls) + 'd' + StrUtil.NumStr(f.dice);
  if f.dmgMod > 0 then
    s := s + '+' + StrUtil.NumStr(f.dmgMod);
  if f.dmgMod < 0 then
    s := s + '-' + StrUtil.NumStr(Abs(f.dmgMod));
  DmgText := s;
end;

procedure NewTexts(var cur: TCombatFigures; var t: TTryOn; var ac, dmg: Types.TStr40);
begin
  if not t.wearable then begin
    ac := ShopBuy.AcText(cur.ac);
    dmg := ShopBuy.DmgText(cur);
  end else if not t.readies then begin
    ac := '--';
    dmg := '--';
  end else begin
    ac := ShopBuy.AcText(t.figures.ac);
    if t.ammo and not t.ammoFits then
      dmg := '--'
    else
      dmg := ShopBuy.DmgText(t.figures);
  end;
end;

{ Draw the tab line in the bottom line's colors: the current tab in inverse video (black on white), the others in
  light green with their keys in white. }
procedure DrawTabs(cur: Byte);
var
  tab: Byte;
  name: string[6];
begin
  Border.ClearBox(LIST_LEFT - 1, TAB_ROW, LIST_RIGHT + 1, TAB_ROW);
  for tab := TAB_ALL to TAB_LAST do begin
    name := tabNames[tab];
    if tab = cur then
      TextRend.DisplayStringOn(tabCols[tab], TAB_ROW, Black, White, name)
    else begin
      TextRend.DisplayString(tabCols[tab], TAB_ROW, LightGreen, name);
      TextRend.DisplayString(tabCols[tab] + tabKeyAt[tab] - 1, TAB_ROW, White, name[tabKeyAt[tab]]);
    end;
  end;
end;

{ Draw the label of creature's readied item at (col, row) in light green, as the View screen shows gear, cut to width;
  nothing for nil. }
procedure DrawGear(item: Types.PItemRec; col, row, width: Byte; color: Byte);
var
  s: Types.TStr40;
begin
  if item = nil then
    Exit;
  CharHlp.ItemLabel(item, False);
  s := item^.name;
  while (Length(s) > 0) and (s[Length(s)] = ' ') do
    Dec(s[0]);
  if Length(s) > width then
    s[0] := Chr(width);
  TextRend.DisplayString(col, row, color, s);
end;

{ The ammunition to show under creature's weapon: the quarrels a crossbow shoots, the arrows anything else does, or
  whichever is readied when the weapon shoots neither. }
function ShownAmmo(creature: Types.PCharRecord): Types.PItemRec;
var
  w: Types.PItemRec;
  arrows: Types.PItemRec;
  bolts: Types.PItemRec;
begin
  w := creature^.equipped[C_EQUIP.WEAPON];
  arrows := creature^.equipped[C_EQUIP.ARROW];
  bolts := creature^.equipped[C_EQUIP.BOLT];
  if (w <> nil) and ((CharHlp.BaseItem(w^.itemType)^.props and C_ITEM.PROP_QUARRELS) <> 0) and (bolts <> nil) then
    ShownAmmo := bolts
  else if arrows <> nil then
    ShownAmmo := arrows
  else
    ShownAmmo := bolts;
end;

{ Draw a figures line on row: 'Curr AC  3    Dmg 1d8+1', the label and AC and Dmg in white, the armor class
  right-aligned to its column and the damage in light green. }
procedure DrawFigures(row: Byte; lbl, ac, dmg: Types.TStr40);
begin
  TextRend.DisplayString(FIGURES_COL, row, White, lbl);
  TextRend.DisplayString(FIGURES_COL + 5, row, White, 'AC');
  TextRend.DisplayString(FIGURES_COL + 10 - Length(ac), row, LightGreen, ac);
  TextRend.DisplayString(FIGURES_COL + 14, row, White, 'Dmg');
  TextRend.DisplayString(FIGURES_COL + 18, row, LightGreen, dmg);
end;

{ Draw the panel under the list for creature with item highlighted (nil for none): its party number and name, then the
  character's and the pool's gold; its armor class and damage now (CURR) and with item readied (NEW, NewTexts); and
  its readied armor, with the shield at the right (light red when item would put it away), weapon and ammunition. }
procedure DrawPanel(creature: Types.PCharRecord; item: Types.PItemRec);
var
  cur: TCombatFigures;
  t: TTryOn;
  curAc: Types.TStr40;
  curDmg: Types.TStr40;
  newAc: Types.TStr40;
  newDmg: Types.TStr40;
  n: Byte;
  num: Types.TStr40;
  name: Types.TStr40;
  shield: Types.PItemRec;
  shieldName: Types.TStr40;
  shieldColor: Byte;
  armorWidth: Byte;
  gold: Types.TStr40;
begin
  Border.ClearBox(PANEL_LEFT - 1, GOLD_ROW, PANEL_RIGHT + 1, AMMO_ROW);
  { '1: Brianna', cut to end a blank before 'Gold' }
  num := '';
  for n := 1 to 8 do
    if Party.MemberAt(n) = creature then
      num := StrUtil.NumStr(n) + ': ';
  name := creature^.name;
  if PANEL_LEFT + Length(num) + Length(name) > GOLD_COL - 1 then
    name[0] := Chr(GOLD_COL - 1 - PANEL_LEFT - Length(num));
  TextRend.DisplayString(PANEL_LEFT, GOLD_ROW, White, num);
  TextRend.DisplayString(PANEL_LEFT + Length(num), GOLD_ROW, CharDisp.NameColor(creature), name);
  { 'Gold  128072   15102': the character's gold and the pool's, each right-aligned to its column }
  TextRend.DisplayString(GOLD_COL, GOLD_ROW, White, 'Gold');
  gold := StrUtil.NumStr(MoneyCal.CreatureGold(creature));
  TextRend.DisplayString(CHAR_GOLD_END + 1 - Length(gold), GOLD_ROW, LightGreen, gold);
  gold := StrUtil.NumStr(MoneyCal.CoinValueInGold(GameVars.treasureMoney));
  TextRend.DisplayString(PANEL_RIGHT + 1 - Length(gold), GOLD_ROW, LightGreen, gold);
  CharHlp.RecalcStats(creature);
  ShopBuy.GetFigures(creature, cur);
  curAc := ShopBuy.AcText(cur.ac);
  curDmg := ShopBuy.DmgText(cur);
  if item <> nil then begin
    ShopBuy.TryOn(creature, item, t);
    ShopBuy.NewTexts(cur, t, newAc, newDmg);
  end else begin
    FillChar(t, SizeOf(t), 0);
    newAc := curAc;
    newDmg := curDmg;
  end;
  ShopBuy.DrawFigures(CURR_ROW, 'Curr', curAc, curDmg);
  ShopBuy.DrawFigures(NEW_ROW, 'New', newAc, newDmg);
  { the gear: armor, with the shield at the right edge, then the weapon and the ammunition }
  shield := creature^.equipped[C_EQUIP.SHIELD];
  armorWidth := PANEL_RIGHT - PANEL_LEFT + 1;
  if shield <> nil then begin
    CharHlp.ItemLabel(shield, False);
    shieldName := shield^.name;
    while (Length(shieldName) > 0) and (shieldName[Length(shieldName)] = ' ') do
      Dec(shieldName[0]);
    if t.shieldOff then
      shieldColor := LightRed
    else
      shieldColor := LightGreen;
    TextRend.DisplayString(PANEL_RIGHT + 1 - Length(shieldName), ARMOR_ROW, shieldColor, shieldName);
    armorWidth := PANEL_RIGHT - PANEL_LEFT - Length(shieldName) - 1;
  end;
  ShopBuy.DrawGear(creature^.equipped[C_EQUIP.ARMOR], PANEL_LEFT, ARMOR_ROW, armorWidth, LightGreen);
  ShopBuy.DrawGear(creature^.equipped[C_EQUIP.WEAPON], PANEL_LEFT, WEAPON_ROW, PANEL_RIGHT - PANEL_LEFT + 1,
                   LightGreen);
  ShopBuy.DrawGear(ShopBuy.ShownAmmo(creature), PANEL_LEFT, AMMO_ROW, PANEL_RIGHT - PANEL_LEFT + 1, LightGreen);
end;

{ The screen's frame: a box for the tabs, one for the list and one for the panel, sharing their edges. }
procedure DrawFrame;
begin
  TextRend.ClearScreen;
  Border.DrawBorder(LIST_LEFT - 1, TAB_ROW, LIST_RIGHT + 1, TAB_ROW, 0);
  Border.DrawBorder(LIST_LEFT - 1, LIST_TOP, LIST_RIGHT + 1, LIST_BOTTOM, 0);
  Border.DrawBorder(PANEL_LEFT - 1, GOLD_ROW, PANEL_RIGHT + 1, AMMO_ROW, 0);
end;

procedure BuyScreen;
var
  shown: TShownList;
  lines: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  node: Types.PItemRec;
  creature: Types.PCharRecord;
  member: Types.PCharRecord;
  tab: Byte;
  usableOnly: Boolean;
  rebuild: Boolean;
  redraw: Boolean;
  done: Boolean;
  ext: Boolean;
  idx: Integer;
  c: Char;
  menu: Types.TStr40;

  { Rebuild the list for the tab, the filter and the buyer, keeping sel highlighted when it is listed still and going
    back to the top of the list when it is not. }
  procedure BuildList;
  var
    i: Integer;
  begin
    if lines <> nil then
      MenuCore.FreeStringList(lines);
    lines := nil;
    tail := nil;
    ShopBuy.FilterStock(GameVars.treasureItems, creature, tab, usableOnly, shown);
    for i := 0 to shown.count - 1 do begin
      { an item priced 0 sells for 1, as SSI's Buy list made it }
      if shown.items[i]^.value = 0 then
        shown.items[i]^.value := 1;
      MenuCore.AppendMenuLine(lines, tail, ShopBuy.RowText(shown.items[i]), False);
    end;
    idx := ShopBuy.FindShown(shown, sel);
    if idx < 0 then begin
      idx := 0;
      GameVars.verticalMenuTop := 0;
    end;
    if shown.count > 0 then
      sel := shown.items[idx]
    else
      sel := nil;
    ShopBuy.DrawTabs(tab);
    Border.ClearBox(LIST_LEFT - 1, LIST_TOP, LIST_RIGHT + 1, LIST_BOTTOM);
    if shown.count = 0 then
      TextRend.DisplayCentered(LIST_LEFT, LIST_RIGHT, (LIST_TOP + LIST_BOTTOM) div 2, White, '** No Items **');
    redraw := True;
  end;

begin
  creature := GameVars.curChar;
  lines := nil;
  sel := nil;
  tab := TAB_ALL;
  usableOnly := False;
  GameVars.verticalMenuTop := 0;
  ShopBuy.DrawFrame;
  rebuild := True;
  done := False;
  repeat
    if rebuild then begin
      BuildList;
      rebuild := False;
    end;
    ShopBuy.DrawPanel(creature, sel);
    if usableOnly then
      menu := 'Showing usable'
    else
      menu := 'Showing all';
    MenuCore.extraKeys := tabKeys;
    MenuCore.memberKeysToCaller := True;
    { F1: the screen's keys (KeyHelp.SHOP_KEYS) }
    MenuCore.helpToCaller := True;
    if shown.count = 0 then begin
      c := MenuCore.MenuHorizontal('Shop: ', menu + ' Exit', LightMagenta, LightGreen, White, True, False, ext);
      { only Alt-n and F1 among the extended keys: the list has nothing to move through }
      if ext and (Party.AltMember(c) = 0) and (c <> C_KEYS.F1) then
        c := ' ';
    end else begin
      MenuCore.lineScroll := True;
      MenuCore.movesToCaller := True;
      c := MenuCore.MenuVertical('Shop: ', menu + ' Buy', LightMagenta, LightGreen, White, LIST_LEFT, LIST_TOP,
                                 LIST_RIGHT, LIST_BOTTOM, lines, True, redraw, idx, node);
      if node <> nil then
        sel := shown.items[idx];
      { the highlight moved: the panel follows it }
      if MenuCore.moved then
        c := ' ';
    end;
    if c = C_KEYS.F1 then begin
      KeyHelp.ShowPage(@KeyHelp.SHOP_KEYS, KeyHelp.SHOP_LINES);
      ShopBuy.DrawFrame;
      rebuild := True;
    end else if Party.AltMember(c) > 0 then begin
      member := Party.MemberAt(Party.AltMember(c));
      if (member <> nil) and (member <> creature) then begin
        creature := member;
        GameVars.curChar := member;
        rebuild := usableOnly;
      end;
    end else
      case c of
        C_KEYS.NONE, C_KEYS.ESCAPE, 'E': done := True;
        'S': begin
               usableOnly := not usableOnly;
               rebuild := True;
             end;
        'L', 'M', 'R', 'A', 'O', 'I': begin
               tab := Pos(c, tabKeys) - 1;
               rebuild := True;
             end;
        'B', C_KEYS.ENTER:
          if sel <> nil then begin
            Shop.BuyItem(sel);
            { a scroll's spells were listed over the panel, and the bottom line said what happened }
            redraw := True;
          end;
      end;
  until done;
  if lines <> nil then
    MenuCore.FreeStringList(lines);
end;

end.
