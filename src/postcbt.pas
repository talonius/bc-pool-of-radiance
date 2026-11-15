{ Resolve combat results, distribute experience and treasure, show the loot menus and clean up creatures. }
{$O+,F+}
{$I COMPILER.INC}
unit PostCbt;

interface

uses Types;

type
  { The monsters Animate Dead raised on the party's side that PostCombatCreatureCleanup keeps to join the party
    (#1089), out of the creature list, and the names of those it could not keep for want of room. }
  TRisen = record
    kept: array[1..Types.MAX_PARTY] of Types.PCharRecord;
    keptCount: Byte;
    lost: array[1..Types.MAX_PARTY] of Types.TStr40;
    lostCount: Byte;
  end;

{ Settles the outcome, awards experience, runs the loot menus, and frees the
  combat state. In the demo (#1109) it only takes the monsters away and keeps the result for the script
  (C_GBVM.COMBAT_RESULT 0 when the party won, else 1): no experience, treasure or summary, and the Bestiary learns
  nothing. }
procedure PostCombat;

{ Monsters and hostile creatures are removed, counting the ones not enabled in C_GBVM.MONSTERS_DEFEATED; the others get
  their combat records freed, and while the Quick Ends With Fight setting is on (GameVars.quickEnds) party members leave
  Quick (quickfight 0) so that the treasure screen and the next combat find them under manual control. NPCs and animated
  creatures keep quickfight, as Space in combat leaves them, but an NPC a paladin led this fight (the combat record's
  led, #1124) goes back under the computer's control (quickfight 1). When the party won (won), a monster Animate Dead
  raised on its side and still animated is kept instead, while the party has room for it (#1089): taken out of the list
  with its combat record freed and its Animate Dead effect's stored side made the party's, so that Dispel Magic ending
  the spell (EffHndlr.EffAnimateDead, which gives the creature back that side) leaves a party member on the party's
  side, and marked CharExt.EXT_ANIMATE_JOINED; it goes into risen.kept for JoinRisen. One with no room is removed as
  before, its name in risen.lost. curChar is left at the list head. }
procedure PostCombatCreatureCleanup(won: Boolean; var risen: TRisen);

{ Runs the post-combat loot menu. When only money or items remain, opens that
  menu directly. }
procedure LootTakeMenu(var treasure, items: Boolean);

implementation

uses Crt, C_MSG, C_SPELL, GameVars, Shop, SaveLoad, Magic, C_KEYS, C_STATUS, C_IFC, C_GBVM, C_MONEY, C_EFFECT, Stats,
  Bestiary, BeastFil, Border, CharHlp, CharExt, EclMenu, MenuCore, Money, TextRend, ViewChar, CharDisp, Party, Dice,
  ClassCal, CbtActs, C_ITEM, UiColor;

var
  { Combat outcome. }
  nonEscapedHostileFound: Boolean;
  partyFled: Boolean;
  { party members who get no experience share: the disabled and the Animated }
  nonSharerCount: Byte;
  { Experience share before individual bonuses. }
  expShare: LongInt;
  combatWon: Boolean;

{ Collect coins, experience and items from hostile creatures that did not run away. An item is taken when its value is
  above 0, or on a 3-in-10 roll while fewer than 8 items have been taken. Coins add experience (copper div 200, silver
  div 20, electrum div 2, gold x1, platinum x5, gems x250, jewelry x2200), as does each taken item's positive plus x400
  (items before GameVars.lastMissileItem). The total is divided by C_GBVM.PARTY_SIZE minus nonSharerCount, and the share
  is 0 when that leaves no one (a fight won by Animated members alone). A mirror duel instead awards 100 experience per
  level (levelHighest) of the current character. }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  item: Types.PItemRec;
  cnt: Byte;
  sharers: Integer;
begin
  if GameVars.duelFlag and (GameVars.zone1^[C_GBVM.MIRROR_DUEL] <> 0) then
    share := GameVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GameVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      item := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_STATUS.RUNNING) then begin
        nonEscapedHostileFound := True;
        for i := C_MONEY.COPPER to C_MONEY.JEWELRY do
          Inc(GameVars.treasureMoney[i], p^.coins[i]);
        expTotal := expTotal + p^.xpAward + LongInt(p^.xpBonusPerHp) * p^.hpRolled;
        if GameVars.zone1^[C_GBVM.NO_COMBAT_ITEMS] <> 1 then
          while item <> nil do begin
            if (item^.value > 0) or ((cnt < 8) and (Dice.RollDice(1, 10) <= 3)) then begin
              Inc(cnt);
              CharHlp.ItemLabel(item, False);
              CharHlp.PrependItemCopy(GameVars.treasureItems, item);
              GameVars.treasureItems^.equipped := 0;
              GameVars.treasureItems^.weaponSet := C_ITEM.SET_NONE;
            end;
            item := item^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.COPPER] div 200);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.SILVER] div 20);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.ELECTRUM] div 2);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.GOLD]);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.PLATINUM] * 5);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.GEMS] * 250);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.JEWELRY] * 2200);
    q := GameVars.treasureItems;
    while (q <> nil) and (q <> GameVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    sharers := GameVars.zone1^[C_GBVM.PARTY_SIZE] - nonSharerCount;
    if sharers > 0 then
      share := expTotal div sharers
    else
      share := 0;
  end;
end;

{ Every enabled, non-Animated creature in the list gets its share of exp (ClassCal.ExperienceShare). }
procedure AwardExperience(experience: LongInt);
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_STATUS.ANIMATED) then
      Inc(p^.experience, ClassCal.ExperienceShare(p, experience));
    p := p^.nextCharAddr;
  end;
end;

{ True for a monster: notPcNpc = 1 in its combat record. A creature without a combat record counts as a party member; a
  COMBAT with no monsters (a treasure-only pickup) reaches the results without giving the party combat records. }
function IsMonster(p: Types.PCharRecord): Boolean;
begin
  IsMonster := (p^.combatAddr <> nil) and (p^.combatAddr^.notPcNpc = 1);
end;

{ Classify the combat outcome. Outside a duel the party (the creatures before the first notPcNpc = 1 entry) is defeated
  unless some non-hostile, non-NPC member is Running, Animated or Okay; while C_GBVM.MIRROR_DUEL is 1 any non-hostile,
  non-NPC member will do, so a lost mirror duel does not end the game. Any Animated or Okay member wins the combat and
  experience is awarded; otherwise a Running member means the party fled. Not fled: Running members return Okay, Dying
  ones become Unconscious and Unconscious ones with HP above 0 recover. Fled: C_GBVM.COMBAT_RESULT becomes $81, Running
  members return and every other member is removed. Defeated: every party member is removed and the party size is set to
  0. In a duel the party is never defeated: an enabled, Okay, non-hostile creature wins it (combatWon), and experience
  is awarded once; Okay and Animated creatures are re-enabled and Dying ones become Unconscious. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  nxt: Types.PCharRecord;
  b: Boolean;
begin
  nonSharerCount := 0;
  GameVars.partyDefeated := True;
  partyFled := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not IsMonster(p)) do begin
    if p^.status = C_STATUS.RUNNING then
      partyFled := True;
    p := p^.nextCharAddr;
  end;
  if GameVars.duelFlag then
    GameVars.partyDefeated := False;
  combatWon := False;
  p := GameVars.creatureList;
  if not GameVars.duelFlag then begin
    while (p <> nil) and (not IsMonster(p)) do begin
      { C_NPC.FLAG clear }
      if ((p^.status = C_STATUS.RUNNING) or (p^.status = C_STATUS.ANIMATED) or
          (p^.status = C_STATUS.OKAY) or
          (GameVars.zone1^[C_GBVM.MIRROR_DUEL] = 1)) and (p^.hostile = 0) and not CharHlp.IsNpc(p) then
        GameVars.partyDefeated := False;
      if (p^.status = C_STATUS.ANIMATED) or (p^.status = C_STATUS.OKAY) then begin
        combatWon := True;
        partyFled := False;
      end;
      if (p^.enabled = 0) or (p^.status = C_STATUS.ANIMATED) then
        Inc(nonSharerCount);
      p := p^.nextCharAddr;
    end;
    if combatWon then begin
      PostCbt.DetermineLootExp(expShare);
      PostCbt.AwardExperience(expShare);
    end;
    p := GameVars.creatureList;
    if not GameVars.partyDefeated then begin
      while (p <> nil) and (not IsMonster(p)) do begin
        { RemoveCreature below frees p }
        nxt := p^.nextCharAddr;
        if not partyFled then begin
          case p^.status of
            C_STATUS.RUNNING: begin
                                p^.status := C_STATUS.OKAY;
                                p^.enabled := 1;
                              end;
            C_STATUS.DYING: p^.status := C_STATUS.UNCONSCIOUS;
            C_STATUS.UNCONSCIOUS: if p^.hpCur > 0 then begin
                                    p^.status := C_STATUS.OKAY;
                                    p^.enabled := 1;
                                  end;
          end;
        end else begin
          GameVars.zone1^[C_GBVM.COMBAT_RESULT] := $81;
          if p^.status = C_STATUS.RUNNING then begin
            p^.status := C_STATUS.OKAY;
            p^.enabled := 1;
          end else begin
            GameVars.curChar := p;
            SaveLoad.RemoveCreature(False, True);
          end;
        end;
        p := nxt;
      end;
    end else begin
      p := GameVars.creatureList;
      b := False;
      while (p <> nil) and not b do begin
        { RemoveCreature frees p }
        nxt := p^.nextCharAddr;
        if not IsMonster(p) then begin
          GameVars.curChar := p;
          SaveLoad.RemoveCreature(False, True);
        end else
          b := True;
        p := nxt;
      end;
      GameVars.zone1^[C_GBVM.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GameVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_STATUS.OKAY) and (p^.hostile <> 1) then
        combatWon := True;
      p := p^.nextCharAddr;
    end;
    { once: SSI gathered the loot and awarded the experience again for each such creature }
    if combatWon then begin
      PostCbt.DetermineLootExp(expShare);
      PostCbt.AwardExperience(expShare);
    end;
    p := GameVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_STATUS.OKAY) or (p^.status = C_STATUS.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_STATUS.DYING then
        p^.status := C_STATUS.UNCONSCIOUS;
      p := p^.nextCharAddr;
    end;
  end;
end;

{ Show the combat outcome and the experience each character (or the duelist) received; the figure shown is 0 when the
  party fled or lost a duel. }
procedure PostCombatSummary(experience: LongInt);
var
  numStr: String[10];
  msg: String;
  c: Char;
  query: String[1];
  ext: Boolean;
begin
  query[0] := #0;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  if nonEscapedHostileFound or GameVars.duelFlag then begin
    if GameVars.duelFlag and not combatWon then begin
      TextRend.DisplayString(1, 3, LightGreen, 'You have lost the duel.');
      experience := 0;
    end else if GameVars.duelFlag then
      TextRend.DisplayString(1, 3, LightGreen, 'You have won the duel.')
    else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has won.');
  end else begin
    if partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, 'The party has fled.');
      experience := 0;
    end else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has found Treasure!');
  end;
  Str(experience, numStr);
  if GameVars.duelFlag then
    msg := 'The duelist receives ' + numStr
  else
    msg := 'Each character receives ' + numStr;
  TextRend.DisplayString(1, 5, LightGreen, msg);
  TextRend.DisplayString(1, 7, LightGreen, 'experience points.');
  c := MenuCore.MenuHorizontal(query, C_MSG.CONTINUE_PROMPT, White, White, White,
                               True, False, ext);
end;

{ Draw the Loot list (rebuilding each item's display name) and run the Items/Take menu; returns the menu key in c and
  the highlighted item in itemToTake. }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { seeded True so MenuVertical paints the list; MenuVertical clears it }
  redraw: Boolean;
begin
  redraw := True;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'Loot');
  CharHlp.LabelItems(GameVars.treasureItems);
  head := GameVars.treasureItems;
  { Alt-n opens member n's items (ViewChar.AltItems), for LootTakeItemMenu to run }
  MenuCore.memberKeysToCaller := True;
  c := MenuCore.MenuVertical('Items: ', 'Take', promptColor, optionColor, commandColor, 1, 4, 38, 22,
                             head, True, redraw, idx, cursor);
  itemToTake := cursor;
end;

{ Take loop: give a copy to the current character, then unlink and free the treasure node. Alt-n opens member n's
  items, who then takes (ViewChar.AltItems, #1195), and the list comes back. Ends on any key other than 'T' or Enter,
  with no item highlighted, or when no treasure items are left. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
  { AltItems's result: the list is drawn again either way }
  opened: Boolean;
begin
  itemToTake := nil;
  cursor := GameVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    done := False;
    if Party.AltMember(c) > 0 then
      opened := ViewChar.AltItems(c)
    { no item highlighted (an empty list) leaves too, before anything reads it }
    else if ((c <> 'T') and (c <> C_KEYS.ENTER)) or (itemToTake = nil) then
      done := True
    else begin
      done := False;
      { a weapon set is its owner's (#1209): a thrown weapon left in the loot goes back to its thrower with its set
        (CbtActs.ReturnThrown), but a member who takes one from the loot tags it afresh }
      itemToTake^.weaponSet := C_ITEM.SET_NONE;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      { loot after a fight, not the vault's own items (#611) }
      if not failed and (GameVars.ifcState = C_IFC.LOOT) then
        Stats.Count(GameVars.curChar, Stats.ITEMS_LOOTED, 1);
      if not failed then begin
        p := GameVars.treasureItems;
        if p = itemToTake then
          GameVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        FreeMem(itemToTake, SizeOf(Types.TItemRec));
        if GameVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharDisp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var treasure, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if treasure then begin
    if items then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', promptColor, optionColor, commandColor,
                                     True, True, ext);
        { an extended key only steps the character: its scan code is no command letter (keypad 6 and 9 came back as 'M'
          and 'I', #730); Alt-n opens member n's items (#1195) }
        if ext then begin
          if ViewChar.AltItems(c) then
            CharDisp.DisplayNoncombatInterface
          else
            Party.SelectPrevNextChar(c);
        end else
          case c of
            'M': begin
                   Money.TakeMoneyMenu;
                   CharDisp.DisplayNoncombatInterface;
                 end;
            'I': PostCbt.LootTakeItemMenu;
            'E', C_KEYS.NONE: done := True;
          end;
        CharDisp.DisplayParty(GameVars.curChar);
        Money.DetermineTreasure(treasure, items);
        if not treasure or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharDisp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ The loot menu is 'View Take Pool Share' with money left, 'View Take Pool' with only items left (each followed by
  ' Detect Exit' when items are left and the current character has Detect Magic (C_SPELL.DETECT_MAGIC) memorized,
  else ' Exit'), or 'View Pool Exit' with nothing left. Leaving with treasure left asks for confirmation. }
procedure LootMenu;
var
  treasure: Boolean;
  items: Boolean;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  query: String[1];
  i: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharDisp.DisplayNoncombatInterface;
  treasure := False;
  repeat
    Money.DetermineTreasure(treasure, items);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := False;
    if items then
      while (i <= Types.MEMORIZED_LAST) and not hasDetect do begin
        if CharHlp.MemorizedAt(GameVars.curChar, i) in C_SPELL.DETECT_MAGIC then begin
          hasDetect := True;
          detectSpell := CharHlp.MemorizedAt(GameVars.curChar, i);
        end;
        Inc(i);
      end;
    if hasDetect then
      tail := ' Detect Exit';
    if treasure then
      menu := 'View Take Pool Share' + tail
    else if items then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, promptColor, optionColor, commandColor, True, True, ext);
    { the coin each party member gains or puts back here, Take, Share, Pool or Drop alike, is Coin looted (net) (#611) }
    Stats.MarkCoins;
    { an extended key only steps the character: its scan code is no command letter (Delete came back as 'S' and shared
      the money, F10 as 'D' and cast Detect Magic, #730); Alt-n opens member n's items (#1195) }
    if ext then begin
      if ViewChar.AltItems(c) then
        CharDisp.DisplayNoncombatInterface
      else
        Party.SelectPrevNextChar(c);
      CharDisp.DisplayParty(GameVars.curChar);
    end else
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': PostCbt.LootTakeMenu(treasure, items);
        'P': Money.PoolMoney;
        'S': if treasure then
               Money.ShareMoney;
        'D': if hasDetect then
               Magic.CastSpell(detectSpell, False, False, ext);
        'E', C_KEYS.NONE: begin
                            Money.DetermineTreasure(treasure, items);
                            done := not (treasure or items) or
                                    not Money.GoBackForIt('There is still treasure left.  ',
                                                          'Do you want to go back and claim your treasure?');
                          end;
      end;
    Stats.SettleCoins;
  until done;
end;

{ True for a monster Animate Dead raised on the party's side that is animated still: one that may join the party. }
function RisenForParty(p: Types.PCharRecord): Boolean;
begin
  RisenForParty := IsMonster(p) and (p^.status = C_STATUS.ANIMATED) and (p^.hostile = 0);
end;

{ Take p out of the creature list, freeing nothing: it is not the list's head, since the party comes first. }
procedure Unlink(p: Types.PCharRecord);
var
  prev: Types.PCharRecord;
begin
  prev := GameVars.creatureList;
  while (prev <> nil) and (prev^.nextCharAddr <> p) do
    prev := prev^.nextCharAddr;
  if prev <> nil then
    prev^.nextCharAddr := p^.nextCharAddr;
  p^.nextCharAddr := nil;
end;

{ Ready risen monster p, out of the list, to join: no combat record, its Animate Dead effect's side the party's (the
  effect's strength holds the side in bit 4 and the caster level below it, Magic.SpellAnimateDead), and the mark. }
procedure KeepRisen(p: Types.PCharRecord);
var
  effect: Types.PEffectRec;
begin
  if p^.combatAddr <> nil then begin
    FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    p^.combatAddr := nil;
  end;
  if CharHlp.HasEffect(p, C_EFFECT.ANIMATE_DEAD, effect) then
    effect^.strength := effect^.strength and $0F;
  p^.portExt.flags := p^.portExt.flags or CharExt.EXT_ANIMATE_JOINED;
end;

procedure PostCombatCreatureCleanup(won: Boolean; var risen: TRisen);
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
  room: Integer;
begin
  risen.keptCount := 0;
  risen.lostCount := 0;
  room := Types.MAX_PARTY - GameVars.zone1^[C_GBVM.PARTY_SIZE];
  GameVars.zone1^[C_GBVM.MONSTERS_DEFEATED] := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    next := p^.nextCharAddr;
    if won and RisenForParty(p) and (risen.keptCount < room) then begin
      Unlink(p);
      KeepRisen(p);
      Inc(risen.keptCount);
      risen.kept[risen.keptCount] := p;
      p := next;
    end else if IsMonster(p) or (p^.hostile = 1) then begin
      if won and RisenForParty(p) and (risen.lostCount < Types.MAX_PARTY) then begin
        Inc(risen.lostCount);
        risen.lost[risen.lostCount] := p^.name;
      end;
      if p^.enabled <> 1 then
        Inc(GameVars.zone1^[C_GBVM.MONSTERS_DEFEATED]);
      GameVars.curChar := p;
      SaveLoad.RemoveCreature(IsMonster(p), True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        { an NPC a paladin led goes back under the computer's control (#1124) }
        if p^.combatAddr^.led <> 0 then
          p^.quickfight := 1;
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      if (GameVars.quickEnds <> 0) and CharHlp.ComesUnderPlayer(p) then
        p^.quickfight := 0;
      p := p^.nextCharAddr;
    end;
  end;
  GameVars.curChar := GameVars.creatureList;
end;

{ Retrieve Thrown (GameVars.retrieveThrownOn, #1118): each single thrown weapon a party member dropped into the loot
  this fight goes back to its thrower when it can (CbtActs.ReturnThrown), each told in the window three rows apart,
  with the continue prompt when the window fills and after the last. }
procedure RetrieveThrownWeapons;
const
  { the window's first row for the messages, and the last one a message starts on }
  FIRST_ROW = 3;
  LAST_ROW = 19;
var
  n: Byte;
  row: Byte;
  thrower: Types.PCharRecord;
  back: Types.PItemRec;
  name: string;
  c: Char;
  ext: Boolean;
begin
  if GameVars.retrieveThrownOn = 0 then Exit;
  row := 0;
  for n := 1 to CbtActs.thrownCount do
    if CbtActs.ReturnThrown(n, thrower, back, name) then begin
      if (row = 0) or (row > LAST_ROW) then begin
        if row > LAST_ROW then
          c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White, True, False, ext);
        Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
        row := FIRST_ROW;
      end;
      TextRend.DisplayMessageWindow(1, row, 38, 22, LightGreen, True, thrower^.name + ' retrieves ' + name + '.');
      Inc(row, 3);
    end;
  if row > 0 then
    c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White, True, False, ext);
  CbtActs.thrownCount := 0;
end;

{ The risen monsters kept (#1089) join the party (EclMenu.JoinParty, as a script-joined NPC joins), and a window says
  "<NAME> joins the party." for each and "<NAME> collapses; the party is full." for each one there was no room for,
  until a key. curChar is left at the list head. }
procedure JoinRisen(var risen: TRisen);
var
  i: Byte;
  row: Byte;
  ext: Boolean;
  c: Char;
begin
  if risen.keptCount + risen.lostCount = 0 then
    Exit;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  row := 0;
  for i := 1 to risen.keptCount do begin
    EclMenu.JoinParty(risen.kept[i]);
    TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, True, risen.kept[i]^.name + ' joins the party.');
    Inc(row, 2);
  end;
  { the window's rows run out after nine lines; the rest go unnamed }
  i := 1;
  while (i <= risen.lostCount) and (row <= 16) do begin
    TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, True,
                                  risen.lost[i] + ' collapses; the party is full.');
    Inc(row, 2);
    Inc(i);
  end;
  c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White, True, False, ext);
  GameVars.curChar := GameVars.creatureList;
end;

{ Each Okay NPC claims (npcTreasureShare and 7) shares, every other creature one share. Each coin type above 0 is cut
  into that many shares and the NPCs' shares are removed. If any coin type was cut, list the NPCs with a nonzero
  npcTreasureShare as taking their share. }
procedure NpcTreasureShare;
var
  p: Types.PCharRecord;
  npcShares: Byte;
  total: Byte;
  cut: LongInt;
  row: Byte;
  i: ShortInt;
  took: Boolean;
  ext: Boolean;
  c: Char;
begin
  took := False;
  p := GameVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    { C_NPC.FLAG set }
    if CharHlp.IsNpc(p) and (p^.status = C_STATUS.OKAY) then begin
      Inc(npcShares, p^.npcTreasureShare and 7);
      Inc(total, p^.npcTreasureShare and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := C_MONEY.COPPER to C_MONEY.JEWELRY do
      if GameVars.treasureMoney[i] > 0 then begin
        cut := GameVars.treasureMoney[i] div total;
        Dec(GameVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
    p := GameVars.creatureList;
    row := 0;
    while p <> nil do begin
      { C_NPC.FLAG set }
      if CharHlp.IsNpc(p) and (p^.status = C_STATUS.OKAY) and (p^.npcTreasureShare > 0) then begin
        TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, True,
                                      p^.name + ' takes and hides his share.');
        Inc(row, 2);
      end;
      p := p^.nextCharAddr;
    end;
    c := MenuCore.MenuHorizontal('', C_MSG.CONTINUE_PROMPT, White, White, White,
                                 True, False, ext);
  end;
end;

{ Resolve combat results and remove combat state. On survival or in a duel, hand thrown weapons back
  (RetrieveThrownWeapons), take the NPC shares, display the summary, offer loot and free the leftover treasure items;
  on defeat, set C_GBVM.COMBAT_RESULT to $80 and show the game-over screen. Then clear the one-combat GBVM modifiers:
  THAC0 adjustments, party movement, no-items and mirror duel, and write what the Bestiary learned in the fight, the
  next fight a new encounter for it (#842). }
procedure PostCombat;
var
  risen: TRisen;
begin
  if GameVars.demoMode then begin
    { the demo's party is NPCs alone, which DetermineCombatResults would take for a destroyed party }
    CharHlp.CountTeams;
    if (GameVars.teamCount[0] > 0) and (GameVars.teamCount[1] = 0) then
      GameVars.zone1^[C_GBVM.COMBAT_RESULT] := 0
    else
      GameVars.zone1^[C_GBVM.COMBAT_RESULT] := 1;
    PostCbt.PostCombatCreatureCleanup(False, risen);
    Bestiary.NewEncounter;
    Exit;
  end;
  GameVars.zone1^[C_GBVM.COMBAT_RESULT] := 0;
  nonEscapedHostileFound := False;
  GameVars.ifcState := C_IFC.LOOT;
  PostCbt.DetermineCombatResults;
  { only a won fight brings the dead along: a party that fled leaves them behind, and a duel is no battle (#1089) }
  PostCbt.PostCombatCreatureCleanup(combatWon and not partyFled and not GameVars.partyDefeated and
                                    not GameVars.duelFlag, risen);
  if not GameVars.partyDefeated or GameVars.duelFlag then begin
    { before the loot, so that a new member can carry some, and before Retrieve Thrown, which hands a weapon back only
      to a thrower in the party: a risen monster's own throws come back to it once it has joined }
    PostCbt.JoinRisen(risen);
    PostCbt.RetrieveThrownWeapons;
    PostCbt.NpcTreasureShare;
    PostCbt.PostCombatSummary(expShare);
    PostCbt.LootMenu;
    CharHlp.FreeItemList(GameVars.treasureItems);
  end else begin
    GameVars.zone1^[C_GBVM.COMBAT_RESULT] := $80;
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'The END!');
    GameVars.curCol := 2;
    GameVars.curRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, True,
                                  'The monsters rejoice for the party has been destroyed');
    TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  end;
  GameVars.msgDelayFlag := 1;
  GameVars.zone1^[C_GBVM.MONSTER_HIT_MOD] := 0;
  GameVars.zone1^[C_GBVM.PARTY_HIT_MOD] := 0;
  GameVars.zone1^[C_GBVM.MOD_PARTY_MOVE] := 0;
  GameVars.zone1^[C_GBVM.NO_COMBAT_ITEMS] := 0;
  GameVars.zone1^[C_GBVM.MIRROR_DUEL] := 0;
  Bestiary.NewEncounter;
  BeastFil.Flush;
end;

end.
