{ The screens' colors by role (docs/ui-design.md, Color). A screen draws a key in keyColor, a header in headerColor and
  so on, not in a color of its own choosing, so the roles stay consistent and a role's color is changed in one place.
  They are variables, not constants, so a color can be changed while the game runs (to try one, or from a setting);
  SetDefaults sets every role to its default, as the unit's start does. Used unqualified, as Crt's colors are. }
{$I COMPILER.INC}
unit UiColor;

interface

var
  { a key in a key/value pair (GOLD, AC, DMG) }
  keyColor: Byte;
  { a value in a key/value pair, and a value with no key }
  valueColor: Byte;
  { a command key: a menu option's hotkey; the current option is in inverse video, black on it (#1160) }
  commandColor: Byte;
  { the rest of a menu option's letters }
  optionColor: Byte;
  { the bottom line's prompt (GAME:, SHOP:) }
  promptColor: Byte;
  { a heading over a section or a column }
  headerColor: Byte;
  { a frame's title, in its top edge }
  titleColor: Byte;
  { a party member's name; the four names are chosen among by CharDisp.NameColor }
  partyColor: Byte;
  { a party member's name when the member is ready to train, as in Pools of Darkness }
  trainColor: Byte;
  { a name out of action (enabled = 0) }
  downColor: Byte;
  { a hostile creature's name }
  hostileColor: Byte;
  { not normal: injured hit points, a warning, a confirmation's prompt }
  warnColor: Byte;
  { bad, negative: a loss, a failure, a worse value }
  badColor: Byte;
  { an improved value (a bonus, a better figure), on betterBack: on trial (docs/ui-design.md) }
  betterColor: Byte;
  betterBack: Byte;
  { a command or entry that cannot be taken now }
  unavailableColor: Byte;

{ Set every role to its default color. }
procedure SetDefaults;

implementation

uses Crt;

procedure SetDefaults;
begin
  keyColor := White;
  valueColor := LightGreen;
  commandColor := White;
  optionColor := LightGreen;
  promptColor := LightMagenta;
  headerColor := LightMagenta;
  titleColor := White;
  partyColor := LightCyan;
  trainColor := LightMagenta;
  downColor := LightRed;
  hostileColor := Yellow;
  warnColor := Yellow;
  badColor := LightRed;
  betterColor := LightGreen;
  betterBack := Blue;
  unavailableColor := DarkGray;
end;

begin
  UiColor.SetDefaults;
end.
