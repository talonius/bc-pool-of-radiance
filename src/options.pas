{ Implements the Settings screen and its POOLOPT.CFG storage. Settings are
  global rather than part of a saved game. CfgFile reads and writes the shared
  KEY=VALUE format used by both the game and POOLCFG (#876), while Collect and
  Apply translate between TSettings and GameVars.

  The screen has Game, Sound, Camp, Combat and System pages (#835, #1088, #1180). Combat-log settings are
  editable only when CbtLog has a backing store (#841). Changes are written when
  the player leaves the screen. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit Options;

interface

uses CfgFile;

{ Loads POOLOPT.CFG over GameInit's defaults and applies the result. Missing,
  unreadable, unknown, or invalid values leave their defaults unchanged. }
procedure LoadOptions;

{ Saves POOLOPT.CFG while preserving unknown keys. A temporary replacement
  keeps the old file intact if writing fails. }
procedure SaveOptions;

{ Applies s to GameVars and retains the version advised for the next save. }
procedure Apply(var s: CfgFile.TSettings);

{ The version POOLOPT.CFG says the startup advisory's support part was last shown for (#1173), '' for none. }
function AdvisedVersion: CfgFile.TName;

{ Record version as the one the support part was last shown for, and save POOLOPT.CFG. }
procedure SetAdvised(version: CfgFile.TName);

{ Show the Settings screen until Exit or Escape. Game, Sound, Camp, coMbat and System on the bottom line, which has no
  prompt, show its pages. On a settings page Up and Down (also Home and End) move the highlight through its settings,
  wrapping at either end, past its headings (Quick Mode, Fix); Enter, Left or Right turn the highlighted one over, at
  once. On the Game Speed and Log Lines lines Left and Right pick Slower or Faster (Less or More) instead, and Enter
  applies the one picked. Without a store for the combat log (CbtLog.Usable) its two lines are grey, Combat Log says it
  needs EMS, and the highlight passes them by. Without a sound device (POOL.CFG's None under DOS) Music and Sound show
  OFF and every Sound page line is grey and passed by, POOLOPT.CFG keeping their values (#1156). The System page only
  shows. Leaving writes POOLOPT.CFG when something changed. The caller redraws its own screen afterwards. }
procedure OptionsMenu;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, Types, C_KEYS, C_SOUND, C_DATA, C_OPT, GameVars, TextRend, Border, MenuCore,
  GameIo, SoundDrv, DaxIo, DataArc, GameDefs, VidOps, CbtLog, StrUtil, Advisory, UiColor;

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  { The two choices of a line that steps a number (speed, log lines), by stepChoice: Slower or Less on the left, Faster
    or More on the right. }
  CHOICE_LEFT = 0;
  CHOICE_RIGHT = 1;
  { The pages, in the bottom line's order: the settings split over Game, Sound (#1088), Camp (#1119, #1129) and Combat
    (#1180), which hold too many for one box, as CfgFile.SettingPage numbers them, then System. }
  PAGE_GAME = C_OPT.OPT_PAGE_GAME;
  PAGE_SOUND = C_OPT.OPT_PAGE_SOUND;
  PAGE_CAMP = C_OPT.OPT_PAGE_CAMP;
  PAGE_COMBAT = C_OPT.OPT_PAGE_COMBAT;
  PAGE_SYSTEM = C_OPT.OPT_PAGES + 1;
  SETTINGS_PAGES = [PAGE_GAME, PAGE_SOUND, PAGE_CAMP, PAGE_COMBAT];
  { One framed box from TOP_ROW to BOTTOM_ROW: the page's title on TOP_ROW, then its lines from FIRST_ROW, the row
    below, 20 rows to the row above BOTTOM_ROW. A settings page's settings have their labels at LABEL_COL and their
    values at SETTING_COL, with each heading (CfgFile.Heading: Quick Mode, Fix) on its own row; the System page's
    values start at VALUE_COL. }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  TOP_ROW = 1;
  BOTTOM_ROW = 22;
  FIRST_ROW = TOP_ROW + 1;
  LABEL_COL = 2;
  SETTING_COL = 24;
  VALUE_COL = 20;
  { the colours: titles, and the lines; a settings page's highlight is TITLE_COLOR too, and a setting that cannot be
    changed here is OFF_COLOR }
  TITLE_COLOR = White;
  LINE_COLOR = LightGreen;
  OFF_COLOR = DarkGray;

var
  { a stepping line's choice, CHOICE_LEFT or CHOICE_RIGHT, while the screen is up }
  stepChoice: Byte;
  { the settings as POOLOPT.CFG keeps them: the version advised, and the rest as Collect last copied them from
    GameVars }
  cur: CfgFile.TSettings;
  { the settings the screen greys and passes by, while it is up: the combat log's two without a store for it
    (CbtLog.Usable), and the Sound page's without a sound device (noDevice, CfgFile.Silenced) }
  unchangeable: CfgFile.TOptSet;
  { POOL.CFG gave the game no sound device (SndNone): Music and Sound show OFF and the Sound page is grey (#1156). The
    native game always has Digital Audio. }
  noDevice: Boolean;

{ The GameVars.soundGroups bit of a sound setting, or musicGroups bit of a music setting; 0 for any other setting. }
function GroupBit(opt: Byte): Byte;
begin
  case opt of
    C_OPT.OPT_TITLE_MUSIC: GroupBit := C_SOUND.GROUP_TITLE_MUSIC;
    C_OPT.OPT_BATTLE_MUSIC: GroupBit := C_SOUND.GROUP_BATTLE_MUSIC;
    C_OPT.OPT_FOOTSTEPS: GroupBit := C_SOUND.GROUP_FOOTSTEPS;
    C_OPT.OPT_RANGED: GroupBit := C_SOUND.GROUP_RANGED;
    C_OPT.OPT_MELEE: GroupBit := C_SOUND.GROUP_MELEE;
    C_OPT.OPT_DEATH: GroupBit := C_SOUND.GROUP_DEATH;
    C_OPT.OPT_WALL: GroupBit := C_SOUND.GROUP_WALL;
    C_OPT.OPT_SPELLS: GroupBit := C_SOUND.GROUP_SPELL;
  else
    GroupBit := 0;
  end;
end;

{ The game's settings (GameVars) into s, the version advised left as it is; each bit of the music and sound groups is
  a setting of its own. }
procedure Collect(var s: CfgFile.TSettings);
var
  opt: Byte;
begin
  s.speed := GameVars.gameDelay;
  s.logLines := GameVars.combatLogLines;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    case opt of
      C_OPT.OPT_PORTRAITS_ALL: s.flags[opt] := GameVars.portraitsAll;
      C_OPT.OPT_MONSTERS: s.flags[opt] := GameVars.monsterPics;
      C_OPT.OPT_PORTRAITS: s.flags[opt] := GameVars.portraitsOn;
      C_OPT.OPT_AUTO_JOIN: s.flags[opt] := GameVars.autoJoinOn;
      C_OPT.OPT_CONSOLIDATE: s.flags[opt] := GameVars.consolidateOn;
      C_OPT.OPT_JOURNAL: s.flags[opt] := GameVars.journalFoundOn;
      C_OPT.OPT_NONHUMAN_CAP: s.flags[opt] := GameVars.nonHumanCapOn;
      C_OPT.OPT_LEVEL_CAP: s.flags[opt] := GameVars.levelCapOn;
      C_OPT.OPT_TRAIN_ANYWHERE: s.flags[opt] := GameVars.trainAnywhereOn;
      C_OPT.OPT_MUSIC: s.flags[opt] := GameVars.musicOn;
      C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC:
        s.flags[opt] := Ord(GameVars.musicGroups and Options.GroupBit(opt) <> 0);
      C_OPT.OPT_SOUND: s.flags[opt] := GameVars.soundOn;
      C_OPT.OPT_FOOTSTEPS..C_OPT.OPT_SPELLS: s.flags[opt] := Ord(GameVars.soundGroups and Options.GroupBit(opt) <> 0);
      C_OPT.OPT_QUICK: s.flags[opt] := GameVars.quickEnds;
      C_OPT.OPT_MAGIC: s.flags[opt] := GameVars.quickMagicOn;
      C_OPT.OPT_GEAR: s.flags[opt] := GameVars.gearChangesOn;
      C_OPT.OPT_AIM: s.flags[opt] := GameVars.aimEnemiesOn;
      C_OPT.OPT_RETRIEVE: s.flags[opt] := GameVars.retrieveThrownOn;
      C_OPT.OPT_MINIMAP: s.flags[opt] := GameVars.minimapOn;
      C_OPT.OPT_WIDE_COMBAT: s.flags[opt] := GameVars.wideCombatOn;
      C_OPT.OPT_COMPANION: s.flags[opt] := GameVars.companionOn;
      C_OPT.OPT_CLUES: s.flags[opt] := GameVars.clueNotesOn;
      C_OPT.OPT_AUTO_MEMORIZE: s.flags[opt] := GameVars.autoMemorizeOn;
      C_OPT.OPT_FIX_SCROLLS: s.flags[opt] := GameVars.fixScrollsOn;
      C_OPT.OPT_FIX_POTIONS: s.flags[opt] := GameVars.fixPotionsOn;
      C_OPT.OPT_FIX_CURE: s.flags[opt] := GameVars.fixCureOn;
      C_OPT.OPT_FIX_HEAL: s.flags[opt] := GameVars.fixHealOn;
      C_OPT.OPT_COMBAT_LOG: s.flags[opt] := GameVars.combatLogOn;
    end;
end;

procedure Apply(var s: CfgFile.TSettings);
var
  opt: Byte;
begin
  GameVars.gameDelay := s.speed;
  GameVars.combatLogLines := s.logLines;
  GameVars.musicGroups := 0;
  GameVars.soundGroups := 0;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    case opt of
      C_OPT.OPT_PORTRAITS_ALL: GameVars.portraitsAll := s.flags[opt];
      C_OPT.OPT_MONSTERS: GameVars.monsterPics := s.flags[opt];
      C_OPT.OPT_PORTRAITS: GameVars.portraitsOn := s.flags[opt];
      C_OPT.OPT_AUTO_JOIN: GameVars.autoJoinOn := s.flags[opt];
      C_OPT.OPT_CONSOLIDATE: GameVars.consolidateOn := s.flags[opt];
      C_OPT.OPT_JOURNAL: GameVars.journalFoundOn := s.flags[opt];
      C_OPT.OPT_NONHUMAN_CAP: GameVars.nonHumanCapOn := s.flags[opt];
      C_OPT.OPT_LEVEL_CAP: GameVars.levelCapOn := s.flags[opt];
      C_OPT.OPT_TRAIN_ANYWHERE: GameVars.trainAnywhereOn := s.flags[opt];
      C_OPT.OPT_MUSIC: GameVars.musicOn := s.flags[opt];
      C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC:
        if s.flags[opt] <> 0 then
          GameVars.musicGroups := GameVars.musicGroups or Options.GroupBit(opt);
      C_OPT.OPT_SOUND: GameVars.soundOn := s.flags[opt];
      C_OPT.OPT_FOOTSTEPS..C_OPT.OPT_SPELLS:
        if s.flags[opt] <> 0 then
          GameVars.soundGroups := GameVars.soundGroups or Options.GroupBit(opt);
      C_OPT.OPT_QUICK: GameVars.quickEnds := s.flags[opt];
      C_OPT.OPT_MAGIC: GameVars.quickMagicOn := s.flags[opt];
      C_OPT.OPT_GEAR: GameVars.gearChangesOn := s.flags[opt];
      C_OPT.OPT_AIM: GameVars.aimEnemiesOn := s.flags[opt];
      C_OPT.OPT_RETRIEVE: GameVars.retrieveThrownOn := s.flags[opt];
      C_OPT.OPT_MINIMAP: GameVars.minimapOn := s.flags[opt];
      C_OPT.OPT_WIDE_COMBAT: GameVars.wideCombatOn := s.flags[opt];
      C_OPT.OPT_COMPANION: GameVars.companionOn := s.flags[opt];
      C_OPT.OPT_CLUES: GameVars.clueNotesOn := s.flags[opt];
      C_OPT.OPT_AUTO_MEMORIZE: GameVars.autoMemorizeOn := s.flags[opt];
      C_OPT.OPT_FIX_SCROLLS: GameVars.fixScrollsOn := s.flags[opt];
      C_OPT.OPT_FIX_POTIONS: GameVars.fixPotionsOn := s.flags[opt];
      C_OPT.OPT_FIX_CURE: GameVars.fixCureOn := s.flags[opt];
      C_OPT.OPT_FIX_HEAL: GameVars.fixHealOn := s.flags[opt];
      C_OPT.OPT_COMBAT_LOG: GameVars.combatLogOn := s.flags[opt];
    end;
  cur.advised := s.advised;
end;

function AdvisedVersion: CfgFile.TName;
begin
  AdvisedVersion := cur.advised;
end;

procedure SetAdvised(version: CfgFile.TName);
begin
  cur.advised := CfgFile.Tidy(version);
  Options.SaveOptions;
end;

{ The row of setting opt on its page: its line (CfgFile.SettingLine) from FIRST_ROW. }
function SettingRow(opt: Byte): Byte;
begin
  SettingRow := FIRST_ROW + CfgFile.SettingLine(opt);
end;

{ The settings the arrows pass by on settings page page, into skip: the other page's, and those the screen cannot
  change. (Turbo Pascal returns no set from a function.) }
procedure Passed(page: Byte; var skip: CfgFile.TOptSet);
var
  opt: Byte;
begin
  skip := unchangeable;
  for opt := 1 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) <> page then
      skip := skip + [opt];
end;

{ The value of setting opt as the screen shows it, from cur as DrawSetting has just collected it: Sound shows whether
  sound is on now, Combat Log that it needs EMS when it has no store, and without a sound device Music and Sound OFF
  (CfgFile.ShownValue). }
function ShownValue(opt: Byte): Types.TStr20;
begin
  if (opt = C_OPT.OPT_SOUND) and not noDevice then
    ShownValue := CfgFile.OnOff(Ord(GameVars.soundMode <> C_SOUND.MODE_DISABLED))
  else if (opt = C_OPT.OPT_COMBAT_LOG) and not CbtLog.Usable then
    ShownValue := 'Needs EMS'
  else
    ShownValue := CfgFile.ShownValue(cur, opt, noDevice);
end;

procedure LoadOptions;
var
  bad: Byte;
  found: CfgFile.TReadResult;
begin
  Options.Collect(cur);
  found := CfgFile.ReadOptions(GameVars.saveDirectory, cur, bad);
  Options.Apply(cur);
  GameIo.SetSound(GameVars.soundOn <> 0);
  GameIo.saveSettings := Options.SaveOptions;
end;

procedure SaveOptions;
var
  written: Boolean;
begin
  Options.Collect(cur);
  written := CfgFile.WriteOptions(GameVars.saveDirectory, cur);
end;

{ Draw setting opt on its row, its label and value in color, or in OFF_COLOR when the page cannot change it. While it
  is highlighted (color TITLE_COLOR) its chosen value is in inverse video, black on TITLE_COLOR (#1160): a stepping
  line's value is its two choices, the one picked (stepChoice) inverse and the other in LINE_COLOR. }
procedure DrawSetting(opt: Byte; color: Byte);
var
  row: Byte;
  highlighted: Boolean;
  left: CfgFile.TName;
  right: CfgFile.TName;

  { Draw s from column col: in inverse video when it is chosen on the highlighted line, else in c. }
  procedure DrawValue(col: Byte; s: CfgFile.TName; chosen: Boolean; c: Byte);
  begin
    if highlighted and chosen then
      TextRend.DisplayStringOn(col, row, Black, TITLE_COLOR, s)
    else
      TextRend.DisplayString(col, row, c, s);
  end;

begin
  if (opt < 1) or (opt > C_OPT.OPT_COUNT) then Exit;
  if opt in unchangeable then
    color := OFF_COLOR;
  highlighted := color = TITLE_COLOR;
  row := Options.SettingRow(opt);
  TextRend.PrintSpaces(LABEL_COL, row, Black, RIGHT_COL - LABEL_COL + 1);
  Options.Collect(cur);
  TextRend.DisplayString(LABEL_COL, row, color, CfgFile.SettingLabel(cur, opt));
  if CfgFile.StepNames(opt, left, right) then begin
    { on the highlighted line the choice not picked is LINE_COLOR }
    if highlighted then
      color := LINE_COLOR;
    DrawValue(SETTING_COL, left, stepChoice <> CHOICE_RIGHT, color);
    DrawValue(SETTING_COL + Length(left) + 1, right, stepChoice = CHOICE_RIGHT, color);
  end else
    DrawValue(SETTING_COL, Options.ShownValue(opt), True, color);
end;

{ Draw a display-only line on row: its label, and value cut to the space from VALUE_COL; a value too long keeps its
  end, after '...', as a path's last folders say the most. The game font has no backslash (that character is a solid
  block), so a path shows '/' in its place. }
procedure DrawInfo(row: Byte; lab, value: string);
const
  WIDTH = RIGHT_COL - VALUE_COL + 1;
var
  i: Byte;
begin
  for i := 1 to Length(value) do
    if value[i] = '\' then
      value[i] := '/';
  if Length(value) > WIDTH then
    value := '...' + Copy(value, Length(value) - (WIDTH - 3) + 1, WIDTH - 3);
  TextRend.DisplayString(LABEL_COL, row, LINE_COLOR, Copy(lab, 1, VALUE_COL - LABEL_COL - 1));
  TextRend.DisplayString(VALUE_COL, row, LINE_COLOR, value);
end;

{ How many data families read their merged archive, and how many have files here at all. }
procedure CountMerged(var merged, present: Byte);
var
  fam: Byte;
  disk: Byte;
  found: Boolean;
begin
  merged := 0;
  present := 0;
  for fam := 1 to C_DATA.FAMILIES do
    if DaxIo.FamilyUsable(fam) then begin
      Inc(merged);
      Inc(present);
    end else begin
      found := False;
      for disk := 1 to Types.LAST_DISK do
        if not found then
          found := DataArc.FileLength(GameVars.gameDir + DataArc.SourceFile(fam, disk)) >= 0;
      if found then
        Inc(present);
    end;
end;

{ Settings page page (PAGE_GAME, PAGE_SOUND, PAGE_CAMP or PAGE_COMBAT): its settings, setting sel highlighted, each
  heading (CfgFile.Heading) on the row above the setting it comes before; the Sound page without a sound device says
  so two rows under its last setting. }
procedure DrawSettingsPage(page, sel: Byte);
var
  opt: Byte;
begin
  for opt := 1 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) = page then begin
      if opt = sel then
        Options.DrawSetting(opt, TITLE_COLOR)
      else
        Options.DrawSetting(opt, LINE_COLOR);
      if CfgFile.Heading(opt) <> '' then
        TextRend.DisplayString(LABEL_COL, Options.SettingRow(opt) - 1, LINE_COLOR, CfgFile.Heading(opt));
    end;
  if (page = PAGE_SOUND) and noDevice then
    TextRend.DisplayString(LABEL_COL, Options.SettingRow(C_OPT.OPT_LAST_SOUND) + 2, LINE_COLOR,
                           'No sound device in POOL.CFG');
end;

{ The System page: the video and sound device the game runs with, the build, the data archives and memory, the speed
  check's time and the DOSBox cycles it matches (#1178), the STING, NORAND and ADVISE switches when they are given, and
  where to send questions and bug reports. The page's 20 rows are full. }
procedure DrawSystemPage;
var
  merged: Byte;
  present: Byte;
  switches: Types.TStr20;
begin
  Options.DrawInfo(FIRST_ROW, 'Video', VidOps.ModeName);
  Options.DrawInfo(FIRST_ROW + 1, 'Sound Device', GameVars.sound.name);
  Options.DrawInfo(FIRST_ROW + 2, 'Version', GameDefs.GAME_VERSION);
  Options.DrawInfo(FIRST_ROW + 3, 'Commit', BUILD_COMMIT);
  Options.CountMerged(merged, present);
  Options.DrawInfo(FIRST_ROW + 5, 'Data', 'V' + StrUtil.Grouped(C_DATA.VERSION));
  Options.DrawInfo(FIRST_ROW + 6, 'Merged Files', StrUtil.Grouped(merged) + '/' + StrUtil.Grouped(present));
  Options.DrawInfo(FIRST_ROW + 8, 'Free Memory', StrUtil.Grouped(MemAvail));
  Options.DrawInfo(FIRST_ROW + 9, 'Largest Block', StrUtil.Grouped(MaxAvail));
{$IFDEF FPC}
  { the native build has no overlays to keep in EMS }
  Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'N/A');
{$ELSE}
  if GameVars.ovrInEms then
    Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'Yes')
  else
    Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'No');
{$ENDIF}
  Options.DrawInfo(FIRST_ROW + 11, 'Speed Check', Advisory.SpeedText);
  Options.DrawInfo(FIRST_ROW + 12, 'Cycles', Advisory.CyclesText);
  switches := '';
  if GameVars.stingArg then
    switches := 'STING ';
  if GameVars.norandArg then
    switches := switches + 'NORAND ';
  if GameVars.adviseArg then
    switches := switches + 'ADVISE';
  if switches <> '' then
    Options.DrawInfo(FIRST_ROW + 13, 'Switches', switches);
  { the startup advisory's support lines (#1173), wrapped to the box }
  Advisory.DisplayText(LABEL_COL, FIRST_ROW + 15, LINE_COLOR, 'This is a modified version of the');
  Advisory.DisplayText(LABEL_COL, FIRST_ROW + 16, LINE_COLOR, 'game. GOG, Steam and SNEG can''t help');
  Advisory.DisplayText(LABEL_COL, FIRST_ROW + 17, LINE_COLOR, 'with it. Please send questions and');
  Advisory.DisplayText(LABEL_COL, FIRST_ROW + 18, LINE_COLOR, 'bug reports to');
  Advisory.DisplayText(LABEL_COL, FIRST_ROW + 19, TITLE_COLOR, Advisory.SUPPORT_EMAIL + '.');
end;

{ Clear the screen and draw page with its title in the frame, setting sel highlighted on a settings page. }
procedure DrawPage(page, sel: Byte);
begin
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, TOP_ROW, RIGHT_COL, BOTTOM_ROW, 0);
  case page of
    PAGE_GAME: begin
                 TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Game Settings');
                 Options.DrawSettingsPage(PAGE_GAME, sel);
               end;
    PAGE_SOUND: begin
                  TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Sound Settings');
                  Options.DrawSettingsPage(PAGE_SOUND, sel);
                end;
    PAGE_CAMP: begin
                 TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Camp Settings');
                 Options.DrawSettingsPage(PAGE_CAMP, sel);
               end;
    PAGE_COMBAT: begin
                   TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Combat Settings');
                   Options.DrawSettingsPage(PAGE_COMBAT, sel);
                 end;
    PAGE_SYSTEM: begin
                   TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'System Info');
                   Options.DrawSystemPage;
                 end;
  end;
end;

{ Change setting opt, as Enter does (CfgFile.ChangeSetting). The speed takes the speed line's choice: Slower raises
  gameDelay (the game's text and animation delays grow with it) and Faster lowers it. Log Lines takes its line's choice
  too; the next fight's log has the new size. Every other setting turns over. A music setting turned off ends the tune
  it covers now; Sound goes through GameIo.SetSound, as Ctrl-S does. }
procedure ChangeSetting(opt: Byte);
begin
  if opt = C_OPT.OPT_SOUND then
    GameIo.SetSound(GameVars.soundMode = C_SOUND.MODE_DISABLED)
  else begin
    Options.Collect(cur);
    CfgFile.ChangeSetting(cur, opt, stepChoice = CHOICE_RIGHT);
    Options.Apply(cur);
    if opt in [C_OPT.OPT_MUSIC, C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC] then
      SoundDrv.ApplyMusicSettings;
  end;
end;

procedure OptionsMenu;
var
  sel: Byte;
  page: Byte;
  ch: Char;
  ext: Boolean;
  { changed: a setting has changed since the screen opened; touched: on this pass }
  changed: Boolean;
  touched: Boolean;
  savedChoice: Byte;
  soundState: Byte;
  { the settings the arrows pass by on the page shown (Passed) }
  skip: CfgFile.TOptSet;

  { Move the highlight to setting n. }
  procedure MoveTo(n: Byte);
  begin
    Options.DrawSetting(sel, LINE_COLOR);
    sel := n;
    Options.DrawSetting(sel, TITLE_COLOR);
  end;

  { Turn setting sel over, or on a stepping line pick choice; nothing for a setting the screen cannot change (without
    a sound device the whole Sound page is grey, its highlight left on Music). }
  procedure Arrow(choice: Byte);
  var
    left: CfgFile.TName;
    right: CfgFile.TName;
  begin
    if sel in unchangeable then
      Exit;
    if CfgFile.StepNames(sel, left, right) then begin
      stepChoice := choice;
      Options.DrawSetting(sel, TITLE_COLOR);
    end else begin
      Options.ChangeSetting(sel);
      touched := True;
    end;
  end;

  { Show page p, a settings page with its first setting highlighted. }
  procedure ShowPage(p: Byte);
  var
    opt: Byte;
  begin
    page := p;
    if page in SETTINGS_PAGES then
      for opt := C_OPT.OPT_COUNT downto 1 do
        if CfgFile.SettingPage(opt) = page then
          sel := opt;
    stepChoice := CHOICE_LEFT;
    Options.DrawPage(page, sel);
  end;

begin
  savedChoice := GameVars.horizChoice;
  if CbtLog.Usable then
    unchangeable := []
  else
    unchangeable := [C_OPT.OPT_COMBAT_LOG, C_OPT.OPT_LOG_LINES];
  noDevice := GameVars.sound.mode = C_SOUND.MODE_DISABLED;
  CfgFile.Silenced(noDevice, unchangeable);
  sel := 1;
  stepChoice := CHOICE_LEFT;
  changed := False;
  ShowPage(PAGE_GAME);
  repeat
    { Ctrl-S on the bottom line turns the sound over too }
    soundState := GameVars.soundMode;
    touched := False;
    { the bottom line shows the page's option current }
    GameVars.horizChoice := page;
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := True;
    { no prompt: with Camp the pages fill the bottom line; Combat's key is M, as C is Camp's }
    ch := MenuCore.MenuHorizontal('', 'Game Sound Camp coMbat sYstem Exit', promptColor, optionColor, commandColor,
                                  True, False, ext);
    if ext then begin
      if page in SETTINGS_PAGES then begin
        Options.Passed(page, skip);
        case ch of
          C_KEYS.UP, C_KEYS.HOME: MoveTo(CfgFile.NextSetting(sel, False, skip));
          C_KEYS.DOWN, C_KEYS.END_KEY: MoveTo(CfgFile.NextSetting(sel, True, skip));
          C_KEYS.LEFT: Arrow(CHOICE_LEFT);
          C_KEYS.RIGHT: Arrow(CHOICE_RIGHT);
        end;
      end;
    end else
      case ch of
        C_KEYS.ENTER: if (page in SETTINGS_PAGES) and not (sel in unchangeable) then begin
                        Options.ChangeSetting(sel);
                        touched := True;
                      end;
        'G': if page <> PAGE_GAME then
               ShowPage(PAGE_GAME);
        'S': if page <> PAGE_SOUND then
               ShowPage(PAGE_SOUND);
        'C': if page <> PAGE_CAMP then
               ShowPage(PAGE_CAMP);
        'M': if page <> PAGE_COMBAT then
               ShowPage(PAGE_COMBAT);
        'Y': if page <> PAGE_SYSTEM then
               ShowPage(PAGE_SYSTEM);
      end;
    if touched then
      changed := True;
    if (page in SETTINGS_PAGES) and (touched or (GameVars.soundMode <> soundState)) then begin
      { Ctrl-S turns the sound over on any page, and the Sound page shows it }
      if (page = PAGE_SOUND) and (sel <> C_OPT.OPT_SOUND) then
        Options.DrawSetting(C_OPT.OPT_SOUND, LINE_COLOR);
      Options.DrawSetting(sel, TITLE_COLOR);
    end;
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  if changed then
    Options.SaveOptions;
  GameVars.horizChoice := savedChoice;
end;

end.
