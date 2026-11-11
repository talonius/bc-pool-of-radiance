{ Tests for the shop's Buy screen (ShopBuy, mocks/new-shop.txt): which tab lists which item types, with Misc taking
  every type no other tab does; the Show Usable filter; a list line's price and name; what readying a copy of the
  highlighted item would do to the buyer's armor class and damage (TryOn), with the shield put away for a two-handed
  weapon, arrows that fit the readied bow and quarrels that do not, a cursed weapon in the way and a class that may not
  use the item, the character left as it was each time; the NEW line's texts (NewTexts); and the scroll bar's thumb
  (MenuCore.ScrollThumb). }
{$I COMPILER.INC}
program TShopBuy;

uses Types, C_EQUIP, C_ITEM, CharHlp, MenuCore, ShopBuy, StrUtil, TestKit;

const
  TWO_HANDED_SWORD = 38;
  PLATE_TYPE = 58;
  SHIELD_TYPE = 59;
  { an unused type with the weapon slot and no hands, as ITEMS has some }
  HANDLESS = 60;
  { armor classes as TCharRecord.acCur has them: 60 less the armor class }
  AC_10 = 50;

var
  c: Types.PCharRecord;
  plate: Types.TItemRec;
  shield: Types.TItemRec;
  sword: Types.TItemRec;
  bow: Types.TItemRec;
  item: Types.TItemRec;
  cur: ShopBuy.TCombatFigures;
  t: ShopBuy.TTryOn;
  shown: ShopBuy.TShownList;
  ac: Types.TStr40;
  dmg: Types.TStr40;
  i: Integer;
  ok: Boolean;
  first: Integer;
  size: Integer;

{ Make item one of itemType with plus, not readied. }
procedure MakeItem(var it: Types.TItemRec; itemType: Byte; plus: ShortInt);
begin
  FillChar(it, SizeOf(it), 0);
  it.itemType := itemType;
  it.nameIds[3] := itemType;
  it.plus := plus;
end;

{ Give base item itemType its slot, hands, small-creature damage, AC descriptor and weapon properties. }
procedure SetBase(itemType, slot, hands, rolls, dice, acDescr, props: Byte);
begin
  CharHlp.baseItems^[itemType].slot := slot;
  CharHlp.baseItems^[itemType].hands := hands;
  CharHlp.baseItems^[itemType].dmgSmRolls := rolls;
  CharHlp.baseItems^[itemType].dmgSmDice := dice;
  CharHlp.baseItems^[itemType].acDescr := acDescr;
  CharHlp.baseItems^[itemType].props := props;
  CharHlp.baseItems^[itemType].classMask := $FF;
end;

{ Try item on c and check the NEW line's texts, whether it readies and puts the shield away, and that c's items, their
  readied marks and its stats are as they were. }
procedure CheckTry(what, wantAc, wantDmg: String; readies, shieldOff: Boolean);
var
  head: Types.PItemRec;
  marks: array[1..4] of Byte;
  before: ShopBuy.TCombatFigures;
  after: ShopBuy.TCombatFigures;
begin
  head := c^.itemsAddr;
  marks[1] := plate.equipped;
  marks[2] := shield.equipped;
  marks[3] := sword.equipped;
  marks[4] := bow.equipped;
  CharHlp.RecalcStats(c);
  ShopBuy.GetFigures(c, before);
  ShopBuy.TryOn(c, @item, t);
  ShopBuy.NewTexts(before, t, ac, dmg);
  TestKit.CheckEqualsS(wantAc, ac, what + ': the new armor class');
  TestKit.CheckEqualsS(wantDmg, dmg, what + ': the new damage');
  TestKit.Check(t.readies = readies, what + ': readies');
  TestKit.Check(t.shieldOff = shieldOff, what + ': the shield put away');
  TestKit.Check(c^.itemsAddr = head, what + ': the items as they were');
  TestKit.Check((plate.equipped = marks[1]) and (shield.equipped = marks[2]) and (sword.equipped = marks[3]) and
                (bow.equipped = marks[4]), what + ': the readied marks as they were');
  ShopBuy.GetFigures(c, after);
  TestKit.Check((after.ac = before.ac) and (after.rolls = before.rolls) and (after.dice = before.dice) and
                (after.dmgMod = before.dmgMod), what + ': the stats as they were');
end;

begin
  TestKit.Start('TSHOPBUY');
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  SetBase(C_ITEM.LONG_SWORD, C_EQUIP.WEAPON, 1, 1, 8, 0, 0);
  SetBase(TWO_HANDED_SWORD, C_EQUIP.WEAPON, 2, 1, 10, 0, 0);
  SetBase(C_ITEM.LONG_BOW, C_EQUIP.WEAPON, 2, 1, 6, 0, C_ITEM.PROP_FIRES_AMMO or C_ITEM.PROP_ARROWS);
  SetBase(C_ITEM.ARROW, 11, 0, 1, 6, 0, C_ITEM.PROP_ARROWS);
  SetBase(C_ITEM.QUARREL, 12, 0, 1, 4, 0, C_ITEM.PROP_QUARRELS);
  { plate gives armor class 3, the shield one better }
  SetBase(PLATE_TYPE, C_EQUIP.ARMOR, 0, 0, 0, $80 + AC_10 + 7, 0);
  SetBase(SHIELD_TYPE, C_EQUIP.SHIELD, 1, 0, 0, $80 + 1, 0);
  SetBase(C_ITEM.MAGE_SCROLL, C_ITEM.SLOT_MAGE_SCROLL, 0, 0, 0, 0, 0);
  SetBase(HANDLESS, C_EQUIP.WEAPON, 0, 0, 0, 0, 0);

  { the tabs }
  TestKit.Check(ShopBuy.InTab(C_ITEM.LONG_SWORD, ShopBuy.TAB_MELEE), 'a long sword is melee');
  TestKit.Check(not ShopBuy.InTab(C_ITEM.LONG_SWORD, ShopBuy.TAB_RANGED), 'and not ranged');
  TestKit.Check(ShopBuy.InTab(C_ITEM.SPEAR, ShopBuy.TAB_MELEE) and ShopBuy.InTab(C_ITEM.SPEAR, ShopBuy.TAB_RANGED),
                'a spear is melee and ranged');
  TestKit.Check(ShopBuy.InTab(C_ITEM.LONG_BOW, ShopBuy.TAB_RANGED), 'a long bow is ranged');
  TestKit.Check(not ShopBuy.InTab(C_ITEM.LONG_BOW, ShopBuy.TAB_MELEE), 'and not melee');
  TestKit.Check(ShopBuy.InTab(C_ITEM.DART, ShopBuy.TAB_RANGED) and not ShopBuy.InTab(C_ITEM.DART, ShopBuy.TAB_MELEE),
                'darts are ranged alone');
  TestKit.Check(ShopBuy.InTab(C_ITEM.DAGGER, ShopBuy.TAB_MELEE) and
                not ShopBuy.InTab(C_ITEM.DAGGER, ShopBuy.TAB_RANGED),
                'a dagger, which ITEMS does not let be thrown, is melee alone');
  TestKit.Check(ShopBuy.InTab(C_ITEM.FLASK_OF_OIL, ShopBuy.TAB_RANGED), 'a flask of oil is thrown');
  TestKit.Check(ShopBuy.InTab(63, ShopBuy.TAB_ARMOR) and ShopBuy.InTab(67, ShopBuy.TAB_ARMOR),
                'gauntlets and cloaks are armor');
  TestKit.Check(ShopBuy.InTab(69, ShopBuy.TAB_MISC) and ShopBuy.InTab(93, ShopBuy.TAB_MISC),
                'rings, the Ring of Protection among them, are misc');
  TestKit.Check(ShopBuy.InTab(PLATE_TYPE, ShopBuy.TAB_ARMOR), 'plate is armor');
  TestKit.Check(ShopBuy.InTab(SHIELD_TYPE, ShopBuy.TAB_ARMOR), 'so is a shield');
  TestKit.Check(ShopBuy.InTab(C_ITEM.BRACERS, ShopBuy.TAB_ARMOR), 'and bracers');
  TestKit.Check(ShopBuy.InTab(C_ITEM.ARROW, ShopBuy.TAB_AMMO) and ShopBuy.InTab(C_ITEM.QUARREL, ShopBuy.TAB_AMMO),
                'arrows and quarrels are ammo');
  TestKit.Check(not ShopBuy.InTab(C_ITEM.QUARREL, ShopBuy.TAB_MELEE), 'quarrels are no melee weapon');
  TestKit.Check(ShopBuy.InTab(C_ITEM.MAGE_SCROLL, ShopBuy.TAB_MISC), 'a scroll is misc');
  TestKit.Check(ShopBuy.InTab(71, ShopBuy.TAB_MISC), 'so is a potion');
  ok := True;
  for i := 0 to 255 do
    if not ShopBuy.InTab(i, ShopBuy.TAB_ALL) or
        (ShopBuy.InTab(i, ShopBuy.TAB_MISC) =
         (ShopBuy.InTab(i, ShopBuy.TAB_MELEE) or ShopBuy.InTab(i, ShopBuy.TAB_RANGED) or
          ShopBuy.InTab(i, ShopBuy.TAB_ARMOR) or ShopBuy.InTab(i, ShopBuy.TAB_AMMO))) then
      ok := False;
  TestKit.Check(ok, 'All lists every type, and Misc every type no other tab lists');
  TestKit.CheckEqualsS('LMRAOI', ShopBuy.tabKeys, 'the tabs'' keys');

  { the filter: the stock is plate, the shield, the sword and the bow, and the character's class may use all but the
    bow }
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.dexCur := 10;
  c^.acBase := AC_10;
  { bare hands, as a character's are }
  c^.unarmedRollsA[1] := 1;
  c^.unarmedDiceA[1] := 2;
  c^.itemLimits := $01;
  CharHlp.baseItems^[C_ITEM.LONG_BOW].classMask := $02;
  MakeItem(plate, PLATE_TYPE, 0);
  MakeItem(shield, SHIELD_TYPE, 0);
  MakeItem(sword, C_ITEM.LONG_SWORD, 0);
  MakeItem(bow, C_ITEM.LONG_BOW, 0);
  plate.next := @shield;
  shield.next := @sword;
  sword.next := @bow;
  ShopBuy.FilterStock(@plate, c, ShopBuy.TAB_ALL, False, shown);
  TestKit.CheckEqualsL(4, shown.count, 'All, Show All: the whole stock');
  ShopBuy.FilterStock(@plate, c, ShopBuy.TAB_ALL, True, shown);
  TestKit.CheckEqualsL(3, shown.count, 'All, Show Usable: all but the bow');
  ShopBuy.FilterStock(@plate, c, ShopBuy.TAB_ARMOR, False, shown);
  TestKit.CheckEqualsL(2, shown.count, 'Armor: plate and the shield');
  TestKit.Check((shown.items[0] = @plate) and (shown.items[1] = @shield), 'in the stock''s order');
  TestKit.CheckEqualsL(1, ShopBuy.FindShown(shown, @shield), 'the shield is the second line');
  TestKit.CheckEqualsL(-1, ShopBuy.FindShown(shown, @sword), 'the sword is not listed');
  TestKit.CheckEqualsL(-1, ShopBuy.FindShown(shown, nil), 'nothing is nowhere');
  ShopBuy.FilterStock(@plate, c, ShopBuy.TAB_RANGED, True, shown);
  TestKit.CheckEqualsL(0, shown.count, 'Ranged, Show Usable: nothing');
  c^.itemLimits := $FF;
  CharHlp.baseItems^[C_ITEM.LONG_BOW].classMask := $FF;

  { a list line }
  MakeItem(item, C_ITEM.LONG_SWORD, 0);
  item.value := 15;
  TestKit.CheckEqualsS('    15 Long Sword', ShopBuy.RowText(@item), 'the price right-aligned, then the name');
  item.value := 0;
  TestKit.CheckEqualsS('     1 Long Sword', ShopBuy.RowText(@item), 'an item priced 0 sells for 1');
  item.value := 65535;
  item.nameIds[2] := C_ITEM.COMPOSITE_LONG_BOW;
  TestKit.CheckEqualsS(' 65535 Long Sword Composite Long B', ShopBuy.RowText(@item),
                       'a name past 27 columns is cut');
  TestKit.CheckEqualsL(ShopBuy.PRICE_WIDTH + 1 + ShopBuy.NAME_WIDTH, Length(ShopBuy.RowText(@item)),
                       'a line is at most 34 columns');

  { trying an item on: the character wears plate and a shield and holds a long sword }
  plate.equipped := 1;
  shield.equipped := 1;
  sword.equipped := 1;
  bow.next := nil;
  sword.next := nil;
  c^.itemsAddr := @plate;
  CharHlp.RecalcStats(c);
  ShopBuy.GetFigures(c, cur);
  TestKit.CheckEqualsS('2', ShopBuy.AcText(cur.ac), 'plate and a shield: armor class 2');
  TestKit.CheckEqualsS('1d8', ShopBuy.DmgText(cur), 'a long sword: 1d8');
  MakeItem(item, TWO_HANDED_SWORD, 0);
  CheckTry('a two-handed sword', '3', '1d10', True, True);
  MakeItem(item, C_ITEM.LONG_SWORD, 2);
  CheckTry('a long sword +2', '2', '1d8+2', True, False);
  MakeItem(item, PLATE_TYPE, 1);
  CheckTry('plate +1', '1', '1d8', True, False);
  MakeItem(item, C_ITEM.MAGE_SCROLL, 0);
  CheckTry('a scroll, which no one readies', '2', '1d8', False, False);
  MakeItem(item, HANDLESS, 0);
  TestKit.Check(not ShopBuy.Wearable(@item), 'a weapon-slot type with no hands is not readied');
  { a scroll with hands, as ITEMS gives the scrolls two: no one readies it for the NEW line, so the sword stays }
  CharHlp.baseItems^[C_ITEM.MAGE_SCROLL].hands := 2;
  MakeItem(item, C_ITEM.MAGE_SCROLL, 0);
  CheckTry('a scroll with hands', '2', '1d8', False, False);
  CharHlp.baseItems^[C_ITEM.MAGE_SCROLL].hands := 0;
  { bracers AC 4: a slot of their own, past the equipment slots, and an armor class better than plate's }
  SetBase(C_ITEM.BRACERS, 77, 0, 0, 0, $80 + AC_10 + 6, 0);
  MakeItem(item, C_ITEM.BRACERS, 2);
  CheckTry('bracers AC 2 over plate', '1', '1d8', True, False);
  MakeItem(item, C_ITEM.ARROW, 1);
  item.quantity := 10;
  CheckTry('arrows with a sword', '2', '--', True, False);
  MakeItem(item, TWO_HANDED_SWORD, 0);
  CharHlp.baseItems^[TWO_HANDED_SWORD].classMask := $02;
  c^.itemLimits := $01;
  CheckTry('a weapon of another class', '--', '--', False, False);
  c^.itemLimits := $FF;
  CharHlp.baseItems^[TWO_HANDED_SWORD].classMask := $FF;
  sword.cursed := 1;
  MakeItem(item, C_ITEM.LONG_SWORD, 2);
  CheckTry('a sword past a cursed one', '--', '--', False, False);
  MakeItem(item, TWO_HANDED_SWORD, 0);
  CheckTry('a two-handed sword past a cursed one', '--', '--', False, False);
  TestKit.Check(shield.equipped <> 0, 'the shield stays readied');
  sword.cursed := 0;

  { now the long bow, with no shield: arrows fit it, quarrels do not }
  shield.equipped := 0;
  sword.equipped := 0;
  bow.equipped := 1;
  sword.next := @bow;
  CharHlp.RecalcStats(c);
  ShopBuy.GetFigures(c, cur);
  TestKit.CheckEqualsS('1d6', ShopBuy.DmgText(cur), 'a long bow with no arrows: its own damage');
  MakeItem(item, C_ITEM.ARROW, 1);
  item.quantity := 10;
  CheckTry('arrows +1 with the bow', '3', '1d6+1', True, False);
  MakeItem(item, C_ITEM.QUARREL, 0);
  item.quantity := 10;
  CheckTry('quarrels with the bow', '3', '--', True, False);
  MakeItem(item, SHIELD_TYPE, 0);
  CheckTry('a shield, which puts the bow away', '2', '1d2', True, False);

  { the scroll bar's thumb }
  MenuCore.ScrollThumb(10, 13, 0, first, size);
  TestKit.Check((first = 0) and (size = 13), 'a list that fits: the whole bar');
  MenuCore.ScrollThumb(26, 13, 0, first, size);
  TestKit.Check((first = 0) and (size = 6), 'twice the box: half the bar, at the top');
  MenuCore.ScrollThumb(26, 13, 13, first, size);
  TestKit.Check(first + size = 13, 'at the end: at the bottom');
  MenuCore.ScrollThumb(26, 13, 12, first, size);
  TestKit.Check(first + size < 13, 'a line short of the end: off the bottom');
  MenuCore.ScrollThumb(26, 13, 1, first, size);
  TestKit.Check(first > 0, 'a line past the start: off the top');
  MenuCore.ScrollThumb(1000, 13, 500, first, size);
  TestKit.Check((size = 1) and (first > 0) and (first < 12), 'a long list: a one-row thumb in the middle');
  TestKit.Done;
end.
