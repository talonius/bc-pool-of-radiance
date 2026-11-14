{ Tests for KeyHelp (#855): the Command Keys window lists a key only where and while it works. }
{$I COMPILER.INC}
program TKeyHelp;

uses C_SOUND, GameVars, KeyHelp, TestKit;

{ The table line whose key starts with k, or 0 for none. }
function LineOf(k: string): Byte;
var
  n: Byte;
begin
  LineOf := 0;
  for n := 1 to KeyHelp.KEY_LINES do
    if Copy(KeyHelp.KEYS[n].key, 1, Length(k)) = k then
      LineOf := n;
end;

{ The line of table t (count lines) whose key starts with k, or 0 for none. }
function PageLineOf(t: KeyHelp.PKeyLines; count: Byte; k: string): Byte;
var
  n: Byte;
begin
  PageLineOf := 0;
  for n := 1 to count do
    if (k <> '') and (Copy(t^[n].key, 1, Length(k)) = k) then
      PageLineOf := n;
end;

{ Whether every line of table t (count lines) fits ShowPage's box, 20 rows of 36 columns, its keys all 9 columns wide
  and a continued line's text under the text above it. }
function PageFits(t: KeyHelp.PKeyLines; count: Byte): Boolean;
var
  n: Byte;
  w: Byte;
  fits: Boolean;
begin
  fits := count <= 20;
  w := 9;
  for n := 1 to count do
    if t^[n].key = '' then
      fits := fits and (w + Length(t^[n].what) <= 36)
    else
      fits := fits and (Length(t^[n].key) = w) and (w + Length(t^[n].what) <= 36);
  PageFits := fits;
end;

{ Whether the line for key k shows, on a menu that takes F5 and F8 when quickKeys is set. }
function Shows(k: string; quickKeys: Boolean): Boolean;
begin
  Shows := (LineOf(k) <> 0) and KeyHelp.LineShown(LineOf(k), quickKeys);
end;

var
  i: Byte;
  shown: Byte;

begin
  TestKit.Start('TKEYHELP');
  GameVars.companionOn := 0;
  GameVars.stingArg := False;
  GameVars.sound.mode := C_SOUND.MODE_DISABLED;
  TestKit.Check(Shows('F1 ', True) and Shows('F1 ', False), 'F1 always shows');
  TestKit.Check(Shows('F5 ', True) and Shows('F8 ', True), 'F5 and F8 show on the map menus');
  TestKit.Check(not Shows('F5 ', False) and not Shows('F8 ', False), 'but not in camp');
  TestKit.Check(not Shows('F6 ', True), 'F6 not with the Companion Tools off');
  GameVars.companionOn := 1;
  TestKit.Check(Shows('F6 ', True) and Shows('F6 ', False), 'and with them on, on either menu');
  TestKit.Check(not Shows('CTRL-Y', True), 'Ctrl-Y not without STING');
  GameVars.stingArg := True;
  TestKit.Check(Shows('CTRL-Y', True), 'and under STING');
  TestKit.Check(not Shows('CTRL-S', True), 'Ctrl-S not without a sound device');
  GameVars.sound.mode := C_SOUND.MODE_ADLIB;
  TestKit.Check(Shows('CTRL-S', True), 'and with one');
  TestKit.Check(Shows('F2 ', True) and Shows('F2 ', False), 'F2, the Bestiary, shows on either menu (#842)');
  GameVars.combatLogOn := 0;
  TestKit.Check(not Shows('F7 ', True), 'F7 not with the Combat Log off');
  GameVars.combatLogOn := 1;
  TestKit.Check(Shows('F7 ', True) and Shows('F7 ', False), 'and with it on, on either menu (#903)');
  TestKit.Check(LineOf('ALT-n ') <> 0, 'Alt-1 to Alt-8 are listed, as one line (#1175)');
  TestKit.Check(KeyHelp.KEYS[LineOf('ALT-n ')].what = 'View PC n''s items (1 to 8)', 'as the member''s items');
  TestKit.Check(Shows('ALT-n ', True) and Shows('ALT-n ', False), 'on either menu');
  TestKit.Check(LineOf('ALT-n ') = LineOf('1, 2') + 1, 'after the function keys and 1, 2');
  TestKit.Check(LineOf('1, 2') = LineOf('F8 ') + 1, '1, 2, the weapon sets, after F8 (#1209)');
  TestKit.Check(Shows('1, 2', True) and Shows('1, 2', False), 'on either menu, as the combat menu may not show them');
  TestKit.Check(KeyHelp.KeyGroup(LineOf('1, 2')) = KeyHelp.KeyGroup(LineOf('F8 ')), 'in the function keys'' group');
  TestKit.Check(Shows('F3 ', True) and Shows('F3 ', False), 'F3, the combat minimap, shows on either menu (#1210)');
  TestKit.Check(LineOf('F3 ') = LineOf('F2 ') + 1, 'in key order');
  GameVars.trainAnywhereOn := 0;
  TestKit.Check(not Shows('F4 ', True) and not Shows('F4 ', False), 'F4 not with Train Anywhere off');
  GameVars.trainAnywhereOn := 1;
  TestKit.Check(Shows('F4 ', True) and Shows('F4 ', False), 'and with it on, on either menu (#1212)');
  TestKit.Check(LineOf('F4 ') = LineOf('F3 ') + 1, 'after F3');
  TestKit.Check(KeyHelp.GroupGaps(True), 'with every line shown the groups keep their blank rows');
  shown := 0;
  for i := 1 to KeyHelp.KEY_LINES do
    if KeyHelp.LineShown(i, True) then
      Inc(shown);
  TestKit.CheckEqualsL(12, shown, 'every line shown, F4''s among them (#1212)');
  GameVars.stingArg := False;
  GameVars.companionOn := 0;
  TestKit.Check(KeyHelp.GroupGaps(True) and KeyHelp.GroupGaps(False), 'and with fewer');
  { the help pages of the shop's Buy screen and the Items screen }
  TestKit.Check(PageFits(@KeyHelp.SHOP_KEYS, KeyHelp.SHOP_LINES), 'Shop Keys fits the window');
  TestKit.Check(PageFits(@KeyHelp.ITEM_KEYS, KeyHelp.ITEM_LINES), 'Item Keys fits the window');
  TestKit.Check(PageLineOf(@KeyHelp.SHOP_KEYS, KeyHelp.SHOP_LINES, 'ALT-n') <> 0, 'Shop Keys lists Alt-n');
  TestKit.Check(PageLineOf(@KeyHelp.ITEM_KEYS, KeyHelp.ITEM_LINES, 'ALT-n') <> 0, 'Item Keys lists Alt-n');
  TestKit.Check(PageLineOf(@KeyHelp.ITEM_KEYS, KeyHelp.ITEM_LINES, '1, 2') <> 0, 'Item Keys lists the weapon sets');
  TestKit.Check(PageLineOf(@KeyHelp.SHOP_KEYS, KeyHelp.SHOP_LINES, 'S ') <> 0, 'Shop Keys lists the filter');
  for i := 1 to 6 do
    TestKit.Check(PageLineOf(@KeyHelp.SHOP_KEYS, KeyHelp.SHOP_LINES, Copy('LMRAOI', i, 1) + ' ') <> 0,
                  'Shop Keys lists tab key ' + Copy('LMRAOI', i, 1));
  TestKit.Done;
end.
