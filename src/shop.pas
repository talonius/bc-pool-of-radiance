{ Shop menus, item selection and purchases. Shop inventory uses the shared treasure state. }
{$O+,F+}
{$I COMPILER.INC}
unit Shop;

interface

uses Types;

procedure ShopMainMenu;

{ Runs the counter menu shared by shops and temples. command supplies the Buy
  or Heal action, keeping this unit independent of Temple. Leaving money on the
  counter prompts the player before exiting. }
procedure CounterMenu(atTemple: Boolean; command: Types.TMenuAction);

procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);

{ The current character buys item, once it still wants it (WantsItem): paid for from its own coins when they cover the
  price, otherwise from the pooled treasure money, and given a copy (GiveItemCopyToCreature); 'Not enough money.' when
  neither covers it. The Buy screen (ShopBuy.BuyScreen) calls it. }
procedure BuyItem(item: Types.PItemRec);

implementation

uses Crt, C_MSG, C_SPELL, GameDefs, GameVars, EclMenu, ViewChar, Money, C_IFC, CharHlp, MenuCore, TextRend, CharDisp,
  MoneyCal, Party, Magic, ShopBuy;

{ Give the current character a copy of item (CharHlp.AddToInventory, which joins it to a stack it matches while Auto
  Join is on) and recalculate its stats. When the character cannot carry it, print that it is overloaded and set
  failed instead. }
procedure GiveItemCopyToCreature(item: Types.PItemRec; var failed: Boolean);
begin
  if ViewChar.CannotCarryItem(GameVars.curChar, item) then begin
    CharDisp.PrintBottomLine('OverLoaded');
    failed := True;
  end else begin
    failed := False;
    CharHlp.AddToInventory(GameVars.curChar, item);
    CharHlp.RecalcStats(GameVars.curChar);
  end;
end;

{ True when the player buys item after seeing it. A scroll whose spells can be read (identified, as the magic shop's
  are, #1091) lists its spells under "The scroll holds:" in the message window and asks; anything else is bought
  without asking. The spells are listed as the scribe list shows them (#1196): each a line indented under a light
  magenta heading for its level (Magic.LevelHeading), the heading given again only when the level changes, and with
  '+' before a spell the current character could learn but doesn't know (Magic.SpellLine, MARK_NOT_KNOWN). When the
  headings would not fit in the window below the title, the spells are listed without them. Each line is drawn at its
  row, so the message window's word wrap can't take away the indent. }
function WantsItem(item: Types.PItemRec): Boolean;
var
  i: Byte;
  id: Byte;
  { how many spells the scroll holds, and how many lines they take with their level headings }
  spells: Byte;
  lines: Byte;
  lastLevel: ShortInt;
  headings: Boolean;
  row: Byte;
begin
  WantsItem := True;
  if CharHlp.ItemReadable(item) and (item^.unidMask = 0) then begin
    spells := 0;
    lines := 0;
    lastLevel := 0;
    for i := 1 to SizeOf(item^.spells) do begin
      id := CharHlp.ScrollSpellAt(item, i);
      if id <> C_SPELL.NONE then begin
        Inc(spells);
        Inc(lines);
        if GameDefs.spellTable[id].levelSp <> lastLevel then begin
          lastLevel := GameDefs.spellTable[id].levelSp;
          Inc(lines);
        end;
      end;
    end;
    if spells > 0 then begin
      CharDisp.MessageText('The scroll holds:', LightGreen, True);
      { MessageText leaves the cursor on the title's row: the window holds the rows below it to TEXT_BOTTOM }
      row := GameVars.curRow;
      headings := row + lines <= C_MSG.TEXT_BOTTOM;
      lastLevel := 0;
      for i := 1 to SizeOf(item^.spells) do begin
        id := CharHlp.ScrollSpellAt(item, i);
        if id <> C_SPELL.NONE then begin
          if headings and (GameDefs.spellTable[id].levelSp <> lastLevel) then begin
            lastLevel := GameDefs.spellTable[id].levelSp;
            Inc(row);
            TextRend.DisplayString(C_MSG.TEXT_LEFT, row, LightMagenta, Magic.LevelHeading(lastLevel));
          end;
          Inc(row);
          if row <= C_MSG.TEXT_BOTTOM then
            TextRend.DisplayString(C_MSG.TEXT_LEFT, row, White,
                                   Magic.SpellLine(GameVars.curChar, id, Magic.MARK_NOT_KNOWN));
        end;
      end;
      WantsItem := MenuCore.YesNoMenu('Buy it? ', LightMagenta, LightGreen, White) = 'Y';
    end;
  end;
end;

procedure BuyItem(item: Types.PItemRec);
var
  price: Word;
  payer: Byte;
  failed: Boolean;
begin
  if Shop.WantsItem(item) then begin
    price := item^.value;
    payer := MoneyCal.WhoPays(GameVars.curChar, price);
    if payer = MoneyCal.PAY_NOBODY then
      CharDisp.PrintBottomLine('Not enough money.')
    else begin
      Shop.GiveItemCopyToCreature(item, failed);
      if not failed then
        Money.PayBy(GameVars.curChar, payer, price);
    end;
  end;
end;

{ Buy: the Buy screen (mocks/new-shop.txt, ShopBuy.BuyScreen), which lists the stock under tabs, scrolls it a line at a
  time and shows what the highlighted item would do for the buyer; Alt-n makes member n the buyer there. }
procedure ShopBuyMenu;
begin
  ShopBuy.BuyScreen;
end;

{ The counter menu: Buy or Heal (command), View, Take, Pool, Share, Appraise and Exit, with Take and Share offered only
  while there is pooled money; an extended key steps through the party, and Alt-n opens member n's items
  (ViewChar.AltItems, #1195). Leaving with money still in the pool asks
  whether to go back for it. }
procedure CounterMenu(atTemple: Boolean; command: Types.TMenuAction);
var
  menu: String[40];
  first: String[4];
  ext: Boolean;
  done: Boolean;
  c: Char;
  hasMoney: Boolean;
  hasItems: Boolean;
  apprOk: Boolean;
begin
  GameVars.ifcState := C_IFC.SHOP_TEMPLE;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GameVars.curChar);
  FillChar(GameVars.treasureMoney, SizeOf(Types.TMoney), 0);
  done := False;
  if atTemple then
    first := 'Heal'
  else begin
    first := 'Buy';
    CharHlp.LabelItems(GameVars.treasureItems);
  end;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    if hasMoney then
      menu := first + ' View Take Pool Share Appraise Exit'
    else
      menu := first + ' View Pool Appraise Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    { an extended key only steps the character: its scan code is no command letter (H is the up arrow, P the down
      arrow, Delete S, which shared the pool, F7 A, #731) }
    if ext then begin
      if ViewChar.AltItems(c) then
        CharDisp.DisplayNoncombatInterface
      else
        Party.SelectPrevNextChar(c);
    end else begin
      case c of
        'B': if not atTemple then command;
        'H': if atTemple then command;
        'V': ViewChar.ViewCharMenu(ext);
        'T': if hasMoney then
               Money.TakeMoneyMenu;
        'P': Money.PoolMoney;
        'S': if hasMoney then
               Money.ShareMoney;
        'A': Money.AppraiseMenu(apprOk);
        'E': begin
               Money.DetermineTreasure(hasMoney, hasItems);
               if atTemple then
                 done := not hasMoney or
                         not Money.GoBackForIt(
                           'As you leave a priest says, "Excuse me but you have left some money here" ',
                           'Do you want to go back and retrieve your money?')
               else
                 done := not hasMoney or
                         not Money.GoBackForIt(
                           'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ',
                           'Do you want to go back and get your Money?');
             end;
      end;
      case c of
        'B', 'T': CharDisp.DisplayNoncombatInterface;
        'A': if apprOk then CharDisp.DisplayNoncombatInterface;
      end;
    end;
    CharDisp.DisplayParty(GameVars.curChar);
  until done;
end;

procedure ShopMainMenu;
begin
  Shop.CounterMenu(False, Shop.ShopBuyMenu);
end;

end.
