{ The vault's menu, its own unit so Vault, which ViewChar's Deposit uses, need not use ViewChar. }
{$O+,F+}
{$I COMPILER.INC}
unit VaultMnu;

interface

uses Types;

{ Runs the vault menu entered by New Phlan's script. Load the session vault into
  the shared treasure pool, then offer View/Deposit, Take, Pool, Share, and Exit.
  Save the pool back on exit. If writing fails, leave the items available so the
  player can take them back; leaving anyway preserves the old session vault. }
procedure VaultMenu;

implementation

uses Crt, GameVars, C_IFC, C_KEYS, CharDisp, CharHlp, MenuCore, Money, Party, PostCbt, TextRend, Vault, ViewChar
  {$IFDEF FPC}, TpRand{$ENDIF}, UiColor;

procedure VaultMenu;
var
  menu: Types.TStr40;
  c: Char;
  ext: Boolean;
  hasMoney: Boolean;
  hasItems: Boolean;
  done: Boolean;
begin
  GameVars.ifcState := C_IFC.VAULT;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GameVars.curChar);
  Vault.ReadVault;
  if Vault.WasVisited and (Random(20) = 0) then
    TextRend.ShowMessage(LightGreen, True, 'OH, YOU''RE ALIVE... I MEAN  WELCOME BACK!')
  else
    TextRend.ShowMessage(LightGreen, True, 'WELCOME TO THE HOARDER''S RESPITE. LET ME LIGHTEN YOUR LOAD.');
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'View';
    if hasMoney or hasItems then
      menu := menu + ' Take';
    menu := menu + ' Pool';
    if hasMoney then
      menu := menu + ' Share';
    menu := menu + ' Exit';
    c := MenuCore.MenuHorizontal('', menu, promptColor, optionColor, commandColor, True, False, ext);
    { an extended key only steps the character, as at the shop's counter (Shop.CounterMenu): the arrows and Home and
      End; SelectPrevNextChar ignores the rest. Alt-n opens member n's items (ViewChar.AltItems, #1195). }
    if ext then begin
      if ViewChar.AltItems(c) then
        CharDisp.DisplayNoncombatInterface
      else
        Party.SelectPrevNextChar(c);
    end else
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': if hasMoney or hasItems then begin
               PostCbt.LootTakeMenu(hasMoney, hasItems);
               CharDisp.DisplayNoncombatInterface;
             end;
        'P': Money.PoolMoney;
        'S': if hasMoney then
               Money.ShareMoney;
        'E', C_KEYS.NONE:
          done := Vault.WriteVault or
                  (MenuCore.YesNoMenu('Leave anyway? ', warnColor, optionColor, commandColor) = 'Y');
      end;
    CharDisp.DisplayParty(GameVars.curChar);
  until done;
  CharHlp.ClearTreasure;
end;

end.
