{ Tests for UiColor (docs/ui-design.md, Color): the roles start at their defaults, SetDefaults brings them back, and
  CharDisp.NameColor picks among the name roles, so changing a role changes the names drawn in it. }
{$I COMPILER.INC}
program TUiColor;

uses Crt, Types, CharDisp, UiColor, TestKit;

var
  c: Types.TCharRecord;

begin
  TestKit.Start('TUICOLOR');

  { the defaults, as the screens were drawn before the roles }
  TestKit.CheckEqualsL(White, keyColor, 'keys are white');
  TestKit.CheckEqualsL(LightGreen, valueColor, 'values are light green');
  TestKit.CheckEqualsL(White, commandColor, 'command keys are white');
  TestKit.CheckEqualsL(LightGreen, optionColor, 'menu options are light green');
  TestKit.CheckEqualsL(LightMagenta, promptColor, 'prompts are light magenta');
  TestKit.CheckEqualsL(LightMagenta, headerColor, 'headers are light magenta');
  TestKit.CheckEqualsL(White, titleColor, 'titles are white');
  TestKit.CheckEqualsL(LightCyan, partyColor, 'party names are light cyan');
  TestKit.CheckEqualsL(LightMagenta, trainColor, 'names ready to train are light magenta');
  TestKit.CheckEqualsL(LightRed, downColor, 'names out of action are light red');
  TestKit.CheckEqualsL(Yellow, hostileColor, 'hostile names are yellow');
  TestKit.CheckEqualsL(Yellow, warnColor, 'not normal is yellow');
  TestKit.CheckEqualsL(LightRed, badColor, 'bad is light red');
  TestKit.CheckEqualsL(LightGreen, betterColor, 'improved is light green');
  TestKit.CheckEqualsL(Blue, betterBack, 'on blue');
  TestKit.CheckEqualsL(DarkGray, unavailableColor, 'unavailable is dark gray');

  { a role is a variable: it changes, and SetDefaults restores it }
  titleColor := Yellow;
  TestKit.CheckEqualsL(Yellow, titleColor, 'a role can be changed');
  UiColor.SetDefaults;
  TestKit.CheckEqualsL(White, titleColor, 'SetDefaults restores the default');

  { NameColor through the roles }
  FillChar(c, SizeOf(c), 0);
  c.enabled := 0;
  TestKit.CheckEqualsL(downColor, CharDisp.NameColor(@c), 'out of action: downColor');
  c.enabled := 1;
  c.hostile := 1;
  TestKit.CheckEqualsL(hostileColor, CharDisp.NameColor(@c), 'hostile: hostileColor');
  c.hostile := 0;
  TestKit.CheckEqualsL(partyColor, CharDisp.NameColor(@c), 'a party member with nothing to train: partyColor');
  partyColor := White;
  TestKit.CheckEqualsL(White, CharDisp.NameColor(@c), 'changing partyColor changes the name''s color');
  UiColor.SetDefaults;

  TestKit.Done;
end.
