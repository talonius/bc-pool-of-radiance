{ Reads and writes the configuration files (#876). POOL.CFG contains the video,
  sound, introduction, data path, and save path used at startup. POOLOPT.CFG
  contains the Settings screen values.

  Both the game and POOLCFG use this unit, so they parse the files identically.
  The routines operate on TSettings rather than global game state and report
  I/O failures instead of raising them. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit CfgFile;

interface

uses C_OPT, FileUtil;

type
  { a setting's label, a key's name, a step's name or ON/OFF }
  TName = string[24];
  { POOL.CFG as START reads it: the letters always one of C_OPT's (what START uses, whatever the file said), the paths
    as written (GameBoot and POOLCFG normalize them), and the lines after the fifth, which START does not read but a
    write keeps }
  TPoolCfg = record
    video: Char;
    sound: Char;
    intro: Char;
    dataDir: FileUtil.TPathName;
    saveDir: FileUtil.TPathName;
    extraCount: Byte;
    extra: array[1..C_OPT.CFG_EXTRA_LINES] of string[79];
  end;
  { a POOL.CFG line START would not take as written: its number, and what it held (cut to 12 characters), or missing
    when the file ended before it }
  TCfgNote = record
    line: Byte;
    missing: Boolean;
    raw: string[12];
  end;
  TCfgNotes = record
    count: Byte;
    items: array[1..C_OPT.CFG_LINES] of TCfgNote;
  end;
  { POOLOPT.CFG's values: the speed (0..C_OPT.SLOWEST), the log lines, each ON/OFF setting as 1 or 0 by its OPT_
    number, and the version the startup advisory's support part was last shown for (KEY_ADVISED, tidied; '' before it
    ever was, #1173) }
  TSettings = record
    speed: Byte;
    logLines: Byte;
    flags: array[C_OPT.OPT_FIRST_FLAG..C_OPT.OPT_LAST_FLAG] of Byte;
    advised: TName;
  end;
  { settings to pass by }
  TOptSet = set of 1..C_OPT.OPT_COUNT;
  { what a read found: the file as written, no file, a file read with values the reader would not take as written
    (left at the default, or read as START would), or a file there that could not be read }
  TReadResult = (CFG_READ, CFG_MISSING, CFG_FIXED, CFG_UNREADABLE);
  { a path checked (CheckPath): good, empty, holding a character no DOS path may, too long, or not an existing folder }
  TPathCheck = (PATH_OK, PATH_EMPTY, PATH_BAD_CHAR, PATH_TOO_LONG, PATH_MISSING);

{ The POOLOPT.CFG key of setting key: SPEED, ALLPORTRAITS ... LOGLINES, then ADVISED (C_OPT.KEY_ADVISED); '' for none. }
function KeyName(key: Byte): TName;

{ The label of setting opt on the Settings screen, a sub-setting's indented two spaces under its setting. A setting a
  key acts on outside the Settings screen names the key after it (#1215): Train Anywhere's F4, Sound's Ctrl-S, the
  Minimap's F3, the Companion Tools' F6 and the Combat Log's F7. }
function SettingName(opt: Byte): TName;

{ The page setting opt is on: C_OPT.OPT_PAGE_SOUND for the music and the sound (OPT_FIRST_SOUND to OPT_LAST_SOUND,
  #1088), OPT_PAGE_CAMP for Auto Memorize and Fix's settings (OPT_FIRST_CAMP to OPT_LAST_CAMP, #1119, #1129),
  OPT_PAGE_COMBAT for Quick Mode's, Aim Cycles, Retrieve Thrown and the combat log's (OPT_FIRST_COMBAT to
  OPT_LAST_COMBAT, #1180), and OPT_PAGE_GAME for the rest; the game's Settings screen and POOLCFG split them so. }
function SettingPage(opt: Byte): Byte;

{ The heading on the line above setting opt on its page, for a setting that starts a group: Quick Mode above
  C_OPT.OPT_QUICK and Fix above OPT_FIX_SCROLLS; '' for every other setting. }
function Heading(opt: Byte): TName;

{ The line of setting opt on its page (SettingPage), from 0: the page's settings in order, with a line for each
  heading (Heading) above the setting it comes before. }
function SettingLine(opt: Byte): Byte;

{ SettingName with the number the speed and log lines lines show after it: 'Game Speed (1)', '  Log Lines (50)'. }
function SettingLabel(var s: TSettings; opt: Byte): TName;

{ True when setting opt steps a number with two choices, the left lowering it and the right raising it, and if so
  their names: Slower and Faster, Less and More. }
function StepNames(opt: Byte; var left, right: TName): Boolean;

{ The setting after opt, or before it when down is clear, wrapping at either end and passing by the settings in skip
  (all of them: opt). }
function NextSetting(opt: Byte; down: Boolean; skip: TOptSet): Byte;

{ ON for a nonzero flag, OFF for zero. }
function OnOff(flag: Byte): TName;

{ The value an ON/OFF setting opt shows and POOLOPT.CFG keeps for flag: OnOff, but for Aim Cycles ENEMIES for a nonzero
  flag and ALL for zero (#1137), and for the Journal FOUND for a nonzero flag, the Journal listing only what the party
  has found, and ALL for zero (#1090). }
function FlagValue(opt, flag: Byte): TName;

{ s without the spaces and tabs at either end. }
function Trim(s: string): string;

{ s trimmed (Trim) and upper-cased. }
function Tidy(s: string): string;

{ The setting or key whose key line names before its '=' (in any case, spaces around it), or 0 for none. }
function KeyOf(line: string): Byte;

{ Every setting's default: speed 1, every portrait, Auto Join, music and sound setting on, Consolidate Coin off, the
  Journal FOUND, Non-Human Level Cap and Game Level Cap on, Train Anywhere off, Auto End Quick Mode on, Use Magic off,
  Allow Gear Changes on, Aim Cycles at ENEMIES, Retrieve Thrown on, the Minimap and Wide View off, the Companion Tools
  off with their Clue Book notes on, Auto Memorize on, the four Fix settings off, the combat log on with 50 lines, and
  no version advised. }
procedure Defaults(var s: TSettings);

{ Setting opt (an ON/OFF one) as 1 for on and 0 for off; 0 for any other. }
function Flag(var s: TSettings; opt: Byte): Byte;

{ Set setting opt (an ON/OFF one) on for a nonzero value, else off. }
procedure SetFlag(var s: TSettings; opt, value: Byte);

{ Change setting opt as the Settings screen's Enter does: the speed and the log lines step to the choice on the right
  (Faster lowers the speed, More raises the lines by C_OPT.LOG_STEP), or the left, within their ranges; every other
  setting turns over. }
procedure ChangeSetting(var s: TSettings; opt: Byte; right: Boolean);

{ The value of key as POOLOPT.CFG keeps it: the speed's digit, the log lines' number, the version advised, ON or OFF
  (FlagValue: ENEMIES or ALL for Aim Cycles, FOUND or ALL for the Journal). }
function StoredValue(var s: TSettings; key: Byte): FileUtil.TPathName;

{ True when POOL.CFG's sound letter sound gives the DOS game no sound device: START installs a driver only for the
  speaker, the Tandy, the AdLib and the Sound Blaster, and none for S, N or any other letter. The native game plays
  Digital Audio whatever the letter (#1097), so its callers do not ask. }
function NoSoundDevice(sound: Char): Boolean;

{ Add to skip the settings a game with no sound device (silent) cannot change, which the Settings screen and POOLCFG
  grey and pass by: every one on the Sound page (#1156). Nothing when not silent. }
procedure Silenced(silent: Boolean; var skip: TOptSet);

{ The value setting opt shows on a settings page: StoredValue, but with no sound device (silent) OFF for Music and
  Sound, which play nothing (#1156). What POOLOPT.CFG keeps for them is left as it is, so a device chosen later brings
  it back. }
function ShownValue(var s: TSettings; opt: Byte; silent: Boolean): FileUtil.TPathName;

{ Set key from value (tidied): a digit 0..9 for the speed, a number from C_OPT.LOG_MIN to LOG_MAX for the log lines,
  the version advised as it is, ON or OFF (or 1 or 0) for the others, and the names FlagValue gives them too. False
  when the value was refused, which leaves the setting as it is. }
function ReadValue(var s: TSettings; key: Byte; value: string): Boolean;

{ Read POOLOPT.CFG in folder dir (with its trailing backslash) over what s holds (the caller sets the defaults first).
  bad counts the known keys whose values were not taken. A missing file is CFG_MISSING; one that would not open,
  CFG_UNREADABLE; one with bad values, CFG_FIXED. At most C_OPT.MAX_LINES lines are read. }
function ReadOptions(dir: FileUtil.TPathName; var s: TSettings; var bad: Byte): TReadResult;

{ Write s as POOLOPT.CFG in folder dir: every key in order, then each line of the old file whose key this version does
  not know, kept for a newer one (blank lines dropped). It is written as TMP\POOLOPT.CFG beside the old file
  (FileUtil.TempName) and put in its place, so a failed write leaves the old file. A folder dir that is not there yet
  is made first, with any above it, as a save makes its folder (FileUtil.MakeFolder): a new save folder, or natively a
  new per-user one, keeps the settings from the first change (#1067). True when it was written. }
function WriteOptions(dir: FileUtil.TPathName; var s: TSettings): Boolean;

{ Read POOL.CFG file name into c as START reads it. A letter is taken in either case (#895); an unknown video letter
  is CGA, an unknown sound letter silent and an introduction other than F the short one. notes lists each letter line
  START would not take as written, and each line missing from a short file (whose paths are then empty, the current
  folder, and its introduction the short one). CFG_FIXED when there are notes. }
function ReadPoolCfg(name: FileUtil.TPathName; var c: TPoolCfg; var notes: TCfgNotes): TReadResult;

{ POOL.CFG's defaults, for a game with none: VGA, the full introduction, the data in folder home and the saves in SAVE\
  under it; no sound under DOS, where the card is not known, and natively Digital Audio (the Sound Blaster's letter),
  which every system plays (#894). }
procedure PoolDefaults(var c: TPoolCfg; home: string);

{ Write c as POOL.CFG file name: the five lines, then the extra ones, each ending CR LF whatever the system, through a
  temporary copy put in place (FileUtil.PutInPlace). True when it was written; else the old file is as it was. }
function WritePoolCfg(name: FileUtil.TPathName; var c: TPoolCfg): Boolean;

{ path made ready for file names to be appended, as START does with POOL.CFG's paths: spaces trimmed, the current
  drive (or, for a relative path, the current directory) put in front of a path without a drive letter, and a closing
  backslash. An empty path gives the current directory, and a drive alone (C:) the current directory on that drive.
  False when the result leaves no room for a file name within a DOS path (longer than C_OPT.MAX_PATH_TEXT); full is
  the result either way. Natively every '/' is a backslash too (NatFile turns them back), and on Linux and macOS, which
  have no drives, a path from '\' is whole (#894). }
function NormalizePath(path: string; var full: string): Boolean;

{ True when path (a full one, as NormalizePath makes) names a folder that exists: a drive's root when the drive
  answers. A path with a wildcard is never one. }
function DirExists(path: string): Boolean;

{ Check text as a folder for a POOL.CFG or POOLOPT.CFG path: tidied (Tidy), not empty, no * ? " < > or |, normalized
  (NormalizePath) within C_OPT.MAX_PATH_TEXT, and an existing folder; nothing is created. full is the normalized
  path. Natively its case is kept, as a system that tells cases apart shows it. }
function CheckPath(text: string; var full: string): TPathCheck;

{$IFDEF FPC}
{ The save folder the native game uses for POOL.CFG's dataDir and saveDir (GameBoot.NativeFolders; POOLCFG shows it),
  with its closing separator, where home is the writable folder (GameDirs.writeFolder, with its own): a save folder
  inside the data folder (SSI's C:\POOLRAD\SAVE\, both normalized, #894) is that part in home; else a whole path (from
  a drive or the root) to a folder that is there is that folder, normalized, which need not lie in the game's (#1064);
  else SAVE\ in home. }
function NativeSaveFolder(dataDir, saveDir, home: string): string;
{$ENDIF}

implementation

uses Dos{$IFDEF FPC}, NatFile{$ENDIF};

function KeyName(key: Byte): TName;
begin
  case key of
    C_OPT.OPT_SPEED: KeyName := 'SPEED';
    C_OPT.OPT_PORTRAITS_ALL: KeyName := 'ALLPORTRAITS';
    C_OPT.OPT_MONSTERS: KeyName := 'MONSTERS';
    C_OPT.OPT_PORTRAITS: KeyName := 'PORTRAITS';
    C_OPT.OPT_AUTO_JOIN: KeyName := 'AUTOJOIN';
    C_OPT.OPT_CONSOLIDATE: KeyName := 'CONSOLIDATECOIN';
    C_OPT.OPT_JOURNAL: KeyName := 'JOURNAL';
    C_OPT.OPT_NONHUMAN_CAP: KeyName := 'NONHUMANCAP';
    C_OPT.OPT_LEVEL_CAP: KeyName := 'LEVELCAP';
    C_OPT.OPT_TRAIN_ANYWHERE: KeyName := 'TRAINANYWHERE';
    C_OPT.OPT_MUSIC: KeyName := 'MUSIC';
    C_OPT.OPT_TITLE_MUSIC: KeyName := 'TITLEMUSIC';
    C_OPT.OPT_BATTLE_MUSIC: KeyName := 'BATTLEMUSIC';
    C_OPT.OPT_SOUND: KeyName := 'SOUND';
    C_OPT.OPT_FOOTSTEPS: KeyName := 'FOOTSTEPS';
    C_OPT.OPT_RANGED: KeyName := 'RANGEDSOUND';
    C_OPT.OPT_MELEE: KeyName := 'MELEESOUND';
    C_OPT.OPT_DEATH: KeyName := 'DEATHSCREAM';
    C_OPT.OPT_WALL: KeyName := 'WALLHIT';
    C_OPT.OPT_SPELLS: KeyName := 'SPELLSOUND';
    C_OPT.OPT_QUICK: KeyName := 'AUTOENDQUICK';
    C_OPT.OPT_MAGIC: KeyName := 'QUICKMAGIC';
    C_OPT.OPT_GEAR: KeyName := 'GEARCHANGES';
    C_OPT.OPT_AIM: KeyName := 'AIMCYCLES';
    C_OPT.OPT_RETRIEVE: KeyName := 'RETRIEVETHROWN';
    C_OPT.OPT_MINIMAP: KeyName := 'MINIMAP';
    C_OPT.OPT_WIDE_COMBAT: KeyName := 'WIDECOMBAT';
    C_OPT.OPT_COMPANION: KeyName := 'COMPANION';
    C_OPT.OPT_CLUES: KeyName := 'CLUENOTES';
    C_OPT.OPT_AUTO_MEMORIZE: KeyName := 'AUTOMEMORIZE';
    C_OPT.OPT_FIX_SCROLLS: KeyName := 'FIXSCROLLS';
    C_OPT.OPT_FIX_POTIONS: KeyName := 'FIXPOTIONS';
    C_OPT.OPT_FIX_CURE: KeyName := 'FIXPALADINCURE';
    C_OPT.OPT_FIX_HEAL: KeyName := 'FIXPALADINHEAL';
    C_OPT.OPT_COMBAT_LOG: KeyName := 'COMBATLOG';
    C_OPT.OPT_LOG_LINES: KeyName := 'LOGLINES';
    C_OPT.KEY_ADVISED: KeyName := 'ADVISED';
  else
    KeyName := '';
  end;
end;

function SettingName(opt: Byte): TName;
begin
  case opt of
    C_OPT.OPT_SPEED: SettingName := 'Game Speed';
    C_OPT.OPT_PORTRAITS_ALL: SettingName := 'Portraits';
    C_OPT.OPT_MONSTERS: SettingName := '  Monster Portraits';
    C_OPT.OPT_PORTRAITS: SettingName := '  Character Portraits';
    C_OPT.OPT_AUTO_JOIN: SettingName := 'Auto Join';
    C_OPT.OPT_CONSOLIDATE: SettingName := 'Consolidate Coin';
    C_OPT.OPT_JOURNAL: SettingName := 'Journal';
    C_OPT.OPT_NONHUMAN_CAP: SettingName := 'Non-Human Level Cap';
    C_OPT.OPT_LEVEL_CAP: SettingName := 'Game Level Cap';
    C_OPT.OPT_TRAIN_ANYWHERE: SettingName := 'Train Anywhere (F4)';
    C_OPT.OPT_MUSIC: SettingName := 'Music';
    C_OPT.OPT_TITLE_MUSIC: SettingName := '  Title Music';
    C_OPT.OPT_BATTLE_MUSIC: SettingName := '  Battle Music';
    C_OPT.OPT_SOUND: SettingName := 'Sound (Ctrl-S)';
    C_OPT.OPT_FOOTSTEPS: SettingName := '  Footsteps';
    C_OPT.OPT_RANGED: SettingName := '  Ranged Weapon Usage';
    C_OPT.OPT_MELEE: SettingName := '  Melee Attacks';
    C_OPT.OPT_DEATH: SettingName := '  Death Scream';
    C_OPT.OPT_WALL: SettingName := '  Wall Hit';
    C_OPT.OPT_SPELLS: SettingName := '  Spell Effects';
    C_OPT.OPT_QUICK: SettingName := '  Auto End Quick Mode';
    C_OPT.OPT_MAGIC: SettingName := '  Use Magic';
    C_OPT.OPT_GEAR: SettingName := '  Allow Gear Changes';
    C_OPT.OPT_AIM: SettingName := 'Aim Cycles';
    C_OPT.OPT_RETRIEVE: SettingName := 'Retrieve Thrown';
    C_OPT.OPT_MINIMAP: SettingName := 'Minimap (F3)';
    C_OPT.OPT_WIDE_COMBAT: SettingName := 'Wide View';
    C_OPT.OPT_COMPANION: SettingName := 'Companion Tools (F6)';
    C_OPT.OPT_CLUES: SettingName := '  Clue Book Notes';
    C_OPT.OPT_AUTO_MEMORIZE: SettingName := 'Auto Memorize';
    C_OPT.OPT_FIX_SCROLLS: SettingName := '  Use Scrolls';
    C_OPT.OPT_FIX_POTIONS: SettingName := '  Use Potions';
    C_OPT.OPT_FIX_CURE: SettingName := '  Use Paladin''s Cure';
    C_OPT.OPT_FIX_HEAL: SettingName := '  Use Paladin''s Heal';
    C_OPT.OPT_COMBAT_LOG: SettingName := 'Combat Log (F7)';
    C_OPT.OPT_LOG_LINES: SettingName := '  Log Lines';
  else
    SettingName := '';
  end;
end;

function SettingLabel(var s: TSettings; opt: Byte): TName;
begin
  if opt in [C_OPT.OPT_SPEED, C_OPT.OPT_LOG_LINES] then
    SettingLabel := CfgFile.SettingName(opt) + ' (' + CfgFile.StoredValue(s, opt) + ')'
  else
    SettingLabel := CfgFile.SettingName(opt);
end;

function StepNames(opt: Byte; var left, right: TName): Boolean;
begin
  StepNames := True;
  case opt of
    C_OPT.OPT_SPEED: begin
                       left := 'Slower';
                       right := 'Faster';
                     end;
    C_OPT.OPT_LOG_LINES: begin
                           left := 'Less';
                           right := 'More';
                         end;
  else
    StepNames := False;
  end;
end;

function NextSetting(opt: Byte; down: Boolean; skip: TOptSet): Byte;
var
  tries: Byte;
begin
  tries := 0;
  repeat
    if down then
      opt := opt mod C_OPT.OPT_COUNT + 1
    else if opt > 1 then
      Dec(opt)
    else
      opt := C_OPT.OPT_COUNT;
    Inc(tries);
  until not (opt in skip) or (tries >= C_OPT.OPT_COUNT);
  NextSetting := opt;
end;

function OnOff(flag: Byte): TName;
begin
  if flag <> 0 then
    OnOff := 'ON'
  else
    OnOff := 'OFF';
end;

function FlagValue(opt, flag: Byte): TName;
begin
  if opt = C_OPT.OPT_AIM then begin
    if flag <> 0 then
      FlagValue := 'ENEMIES'
    else
      FlagValue := 'ALL';
  end else if opt = C_OPT.OPT_JOURNAL then begin
    if flag <> 0 then
      FlagValue := 'FOUND'
    else
      FlagValue := 'ALL';
  end else
    FlagValue := CfgFile.OnOff(flag);
end;

function Trim(s: string): string;
begin
  while (Length(s) > 0) and (s[1] in [' ', #9]) do
    Delete(s, 1, 1);
  while (Length(s) > 0) and (s[Length(s)] in [' ', #9]) do
    Dec(s[0]);
  Trim := s;
end;

function Tidy(s: string): string;
var
  i: Byte;
begin
  s := CfgFile.Trim(s);
  for i := 1 to Length(s) do
    s[i] := UpCase(s[i]);
  Tidy := s;
end;

function KeyOf(line: string): Byte;
var
  eq: Byte;
  key: string;
  k: Byte;
begin
  KeyOf := 0;
  eq := Pos('=', line);
  if eq = 0 then Exit;
  key := CfgFile.Tidy(Copy(line, 1, eq - 1));
  for k := 1 to C_OPT.KEY_COUNT do
    if key = CfgFile.KeyName(k) then
      KeyOf := k;
end;

function SettingPage(opt: Byte): Byte;
begin
  if (opt >= C_OPT.OPT_FIRST_SOUND) and (opt <= C_OPT.OPT_LAST_SOUND) then
    SettingPage := C_OPT.OPT_PAGE_SOUND
  else if (opt >= C_OPT.OPT_FIRST_CAMP) and (opt <= C_OPT.OPT_LAST_CAMP) then
    SettingPage := C_OPT.OPT_PAGE_CAMP
  else if (opt >= C_OPT.OPT_FIRST_COMBAT) and (opt <= C_OPT.OPT_LAST_COMBAT) then
    SettingPage := C_OPT.OPT_PAGE_COMBAT
  else
    SettingPage := C_OPT.OPT_PAGE_GAME;
end;

function Heading(opt: Byte): TName;
begin
  case opt of
    C_OPT.OPT_QUICK: Heading := 'Quick Mode';
    C_OPT.OPT_FIX_SCROLLS: Heading := 'Fix';
  else
    Heading := '';
  end;
end;

function SettingLine(opt: Byte): Byte;
var
  o: Byte;
  line: Byte;
begin
  { the page's settings before opt, and its headings down to opt's own }
  line := 0;
  for o := 1 to opt do
    if CfgFile.SettingPage(o) = CfgFile.SettingPage(opt) then
      Inc(line, Ord(o < opt) + Ord(CfgFile.Heading(o) <> ''));
  SettingLine := line;
end;

procedure Defaults(var s: TSettings);
var
  opt: Byte;
begin
  s.speed := C_OPT.SPEED_DEFAULT;
  s.logLines := C_OPT.LOG_DEFAULT;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    s.flags[opt] := Ord(not (opt in [C_OPT.OPT_CONSOLIDATE, C_OPT.OPT_MAGIC, C_OPT.OPT_COMPANION,
                                     C_OPT.OPT_TRAIN_ANYWHERE, C_OPT.OPT_FIX_SCROLLS..C_OPT.OPT_FIX_HEAL,
                                     C_OPT.OPT_MINIMAP, C_OPT.OPT_WIDE_COMBAT]));
  s.advised := '';
end;

function Flag(var s: TSettings; opt: Byte): Byte;
begin
  if (opt >= C_OPT.OPT_FIRST_FLAG) and (opt <= C_OPT.OPT_LAST_FLAG) then
    Flag := s.flags[opt]
  else
    Flag := 0;
end;

procedure SetFlag(var s: TSettings; opt, value: Byte);
begin
  if (opt >= C_OPT.OPT_FIRST_FLAG) and (opt <= C_OPT.OPT_LAST_FLAG) then
    s.flags[opt] := Ord(value <> 0);
end;

procedure ChangeSetting(var s: TSettings; opt: Byte; right: Boolean);
begin
  case opt of
    C_OPT.OPT_SPEED: if not right then begin
                       if s.speed < C_OPT.SLOWEST then
                         Inc(s.speed);
                     end else if s.speed > 0 then
                       Dec(s.speed);
    C_OPT.OPT_LOG_LINES: if not right then begin
                           if s.logLines >= C_OPT.LOG_MIN + C_OPT.LOG_STEP then
                             Dec(s.logLines, C_OPT.LOG_STEP)
                           else
                             s.logLines := C_OPT.LOG_MIN;
                         end else if s.logLines <= C_OPT.LOG_MAX - C_OPT.LOG_STEP then
                           Inc(s.logLines, C_OPT.LOG_STEP)
                         else
                           s.logLines := C_OPT.LOG_MAX;
  else
    CfgFile.SetFlag(s, opt, Ord(CfgFile.Flag(s, opt) = 0));
  end;
end;

function StoredValue(var s: TSettings; key: Byte): FileUtil.TPathName;
var
  n: string[3];
begin
  if key = C_OPT.OPT_SPEED then
    StoredValue := Chr(Ord('0') + s.speed mod (C_OPT.SLOWEST + 1))
  else if key = C_OPT.OPT_LOG_LINES then begin
    Str(s.logLines, n);
    StoredValue := n;
  end else if key = C_OPT.KEY_ADVISED then
    StoredValue := s.advised
  else
    StoredValue := CfgFile.FlagValue(key, CfgFile.Flag(s, key));
end;

function ReadValue(var s: TSettings; key: Byte; value: string): Boolean;
var
  n: Integer;
  code: Integer;
begin
  ReadValue := True;
  if key = C_OPT.OPT_SPEED then begin
    if (Length(value) = 1) and (value[1] in ['0'..'9']) then
      s.speed := Ord(value[1]) - Ord('0')
    else
      ReadValue := False;
  end else if key = C_OPT.OPT_LOG_LINES then begin
    Val(value, n, code);
    if (code = 0) and (n >= C_OPT.LOG_MIN) and (n <= C_OPT.LOG_MAX) then
      s.logLines := n
    else
      ReadValue := False;
  end else if key = C_OPT.KEY_ADVISED then
    s.advised := value
  else if (value = 'ON') or (value = '1') or (value = CfgFile.FlagValue(key, 1)) then
    CfgFile.SetFlag(s, key, 1)
  else if (value = 'OFF') or (value = '0') or (value = CfgFile.FlagValue(key, 0)) then
    CfgFile.SetFlag(s, key, 0)
  else
    ReadValue := False;
end;

{ Open text file name for reading: CFG_READ when it opened, CFG_MISSING when there is no such file (or folder),
  CFG_UNREADABLE when it is there but would not open. A write of it the game was ended in is undone first
  (FileUtil.RecoverFile). }
function OpenText(var f: Text; name: FileUtil.TPathName): TReadResult;
var
  ioRes: Integer;
  recovered: Boolean;
begin
  recovered := FileUtil.RecoverFile(name);
  ioRes := IOResult;
  Assign(f, name);
  Reset(f);
  ioRes := IOResult;
  if ioRes = 0 then
    OpenText := CFG_READ
  else if (ioRes = 2) or (ioRes = 3) then
    OpenText := CFG_MISSING
  else
    OpenText := CFG_UNREADABLE;
end;

function ReadOptions(dir: FileUtil.TPathName; var s: TSettings; var bad: Byte): TReadResult;
var
  f: Text;
  line: string;
  key: Byte;
  lines: Integer;
  done: Boolean;
  found: TReadResult;
  ioRes: Integer;
begin
  bad := 0;
  found := CfgFile.OpenText(f, dir + C_OPT.OPT_NAME);
  if found = CFG_READ then begin
    lines := 0;
    done := False;
    repeat
      if Eof(f) then
        done := True
      else begin
        ReadLn(f, line);
        Inc(lines);
        key := CfgFile.KeyOf(line);
        if key <> 0 then
          if not CfgFile.ReadValue(s, key, CfgFile.Tidy(Copy(line, Pos('=', line) + 1, 255))) then
            Inc(bad);
      end;
      if (IOResult <> 0) or (lines >= C_OPT.MAX_LINES) then
        done := True;
    until done;
    Close(f);
    ioRes := IOResult;
    if bad > 0 then
      found := CFG_FIXED;
  end;
  ReadOptions := found;
end;

function WriteOptions(dir: FileUtil.TPathName; var s: TSettings): Boolean;
var
  newFile: Text;
  oldFile: Text;
  line: string;
  key: Byte;
  lines: Integer;
  done: Boolean;
  ok: Boolean;
  ioRes: Integer;
  name: FileUtil.TPathName;
begin
  WriteOptions := False;
  name := dir + C_OPT.OPT_NAME;
  ioRes := IOResult;
  if not FileUtil.MakeFolder(dir) or not FileUtil.MakeTempFolder(name) then Exit;
  Assign(newFile, FileUtil.TempName(name));
  Rewrite(newFile);
  if IOResult <> 0 then Exit;
  for key := 1 to C_OPT.KEY_COUNT do
    WriteLn(newFile, CfgFile.KeyName(key), '=', CfgFile.StoredValue(s, key));
  ok := IOResult = 0;
  if ok then begin
    Assign(oldFile, name);
    Reset(oldFile);
    if IOResult = 0 then begin
      lines := 0;
      done := False;
      repeat
        if Eof(oldFile) then
          done := True
        else begin
          ReadLn(oldFile, line);
          Inc(lines);
          if (CfgFile.KeyOf(line) = 0) and (CfgFile.Tidy(line) <> '') then
            WriteLn(newFile, line);
        end;
        if IOResult <> 0 then begin
          ok := False;
          done := True;
        end;
        if lines >= C_OPT.MAX_LINES then
          done := True;
      until done;
      Close(oldFile);
      ioRes := IOResult;
    end;
  end;
  Close(newFile);
  if IOResult <> 0 then
    ok := False;
  if ok then
    ok := FileUtil.PutInPlace(name)
  else
    FileUtil.DeleteFile(FileUtil.TempName(name));
  WriteOptions := ok;
end;

function NoSoundDevice(sound: Char): Boolean;
begin
  NoSoundDevice := not (UpCase(sound) in [C_OPT.SOUND_SPEAKER, C_OPT.SOUND_TANDY, C_OPT.SOUND_ADLIB,
                                          C_OPT.SOUND_BLASTER]);
end;

procedure Silenced(silent: Boolean; var skip: TOptSet);
begin
  if silent then
    skip := skip + [C_OPT.OPT_FIRST_SOUND..C_OPT.OPT_LAST_SOUND];
end;

function ShownValue(var s: TSettings; opt: Byte; silent: Boolean): FileUtil.TPathName;
begin
  if silent and (opt in [C_OPT.OPT_MUSIC, C_OPT.OPT_SOUND]) then
    ShownValue := CfgFile.OnOff(0)
  else
    ShownValue := CfgFile.StoredValue(s, opt);
end;

function ReadPoolCfg(name: FileUtil.TPathName; var c: TPoolCfg; var notes: TCfgNotes): TReadResult;
var
  f: Text;
  found: TReadResult;
  lineNo: Byte;
  line: string;
  missing: Boolean;
  letter: Char;
  known: Boolean;
  ioRes: Integer;
begin
  c.video := C_OPT.VIDEO_CGA;
  c.sound := C_OPT.SOUND_SILENT;
  c.intro := C_OPT.INTRO_SHORT;
  c.dataDir := '';
  c.saveDir := '';
  c.extraCount := 0;
  notes.count := 0;
  found := CfgFile.OpenText(f, name);
  if found <> CFG_READ then begin
    ReadPoolCfg := found;
    Exit;
  end;
  for lineNo := 1 to C_OPT.CFG_LINES do begin
    missing := Eof(f);
    line := '';
    if not missing then
      ReadLn(f, line);
    if Length(line) > 0 then
      letter := UpCase(line[1])
    else
      letter := ' ';
    known := not missing;
    case lineNo of
      1: if letter in [C_OPT.VIDEO_CGA, C_OPT.VIDEO_EGA, C_OPT.VIDEO_TANDY, C_OPT.VIDEO_VGA, C_OPT.VIDEO_VESA] then
           c.video := letter
         else
           known := False;
      2: if letter in [C_OPT.SOUND_SPEAKER, C_OPT.SOUND_TANDY, C_OPT.SOUND_ADLIB, C_OPT.SOUND_BLASTER] then
           c.sound := letter
         else if not (letter in [C_OPT.SOUND_SILENT, C_OPT.SOUND_NONE]) then
           known := False;
      3: c.dataDir := line;
      4: c.saveDir := line;
      5: if letter = C_OPT.INTRO_FULL then
           c.intro := letter
         else if letter <> C_OPT.INTRO_SHORT then
           known := False;
    end;
    if not known then begin
      Inc(notes.count);
      notes.items[notes.count].line := lineNo;
      notes.items[notes.count].missing := missing;
      notes.items[notes.count].raw := Copy(line, 1, 12);
    end;
  end;
  while not Eof(f) and (c.extraCount < C_OPT.CFG_EXTRA_LINES) and (IOResult = 0) do begin
    Inc(c.extraCount);
    ReadLn(f, c.extra[c.extraCount]);
  end;
  Close(f);
  ioRes := IOResult;
  if notes.count > 0 then
    ReadPoolCfg := CFG_FIXED
  else
    ReadPoolCfg := CFG_READ;
end;

procedure PoolDefaults(var c: TPoolCfg; home: string);
begin
  c.video := C_OPT.VIDEO_VGA;
{$IFDEF FPC}
  c.sound := C_OPT.SOUND_BLASTER;
{$ELSE}
  c.sound := C_OPT.SOUND_SILENT;
{$ENDIF}
  c.intro := C_OPT.INTRO_FULL;
  c.dataDir := home;
  c.saveDir := home + 'SAVE\';
  c.extraCount := 0;
end;

function WritePoolCfg(name: FileUtil.TPathName; var c: TPoolCfg): Boolean;
var
  f: file;
  ok: Boolean;
  i: Byte;

  { Write line s and CR LF. }
  procedure PutLine(s: string);
  begin
    s := s + #13#10;
    FileUtil.WriteChecked(f, s[1], Length(s), ok);
  end;

begin
  WritePoolCfg := False;
  if not FileUtil.RewriteTemp(f, name) then Exit;
  ok := True;
  PutLine(c.video);
  PutLine(c.sound);
  PutLine(c.dataDir);
  PutLine(c.saveDir);
  PutLine(c.intro);
  for i := 1 to c.extraCount do
    PutLine(c.extra[i]);
  if FileUtil.CloseTemp(f, name, ok) then
    WritePoolCfg := FileUtil.PutInPlace(name);
end;

{$IFDEF FPC}
{ s with each '/' a backslash. }
function Backslashed(s: string): string;
var
  i: Byte;
begin
  for i := 1 to Length(s) do
    if s[i] = '/' then
      s[i] := '\';
  Backslashed := s;
end;
{$ENDIF}

function NormalizePath(path: string; var full: string): Boolean;
var
  cur: string;
begin
  while (Length(path) > 0) and (path[1] = ' ') do
    Delete(path, 1, 1);
  while (Length(path) > 0) and (path[Length(path)] = ' ') do
    Dec(path[0]);
{$IFDEF FPC}
  path := CfgFile.Backslashed(path);
{$ENDIF}
  if (Length(path) = 2) and (path[2] = ':') then
    GetDir(Ord(UpCase(path[1])) - Ord('A') + 1, path)
  else begin
    GetDir(0, cur);
{$IFDEF FPC}
    cur := CfgFile.Backslashed(cur);
{$ENDIF}
    if cur[Length(cur)] <> '\' then cur := cur + '\';
    if (Length(path) < 2) or (path[2] <> ':') then
      if (Length(path) > 0) and (path[1] = '\') then begin
{$IFNDEF UNIX}
        path := Copy(cur, 1, 2) + path;
{$ENDIF}
      end else
        path := cur + path;
  end;
{$IFDEF FPC}
  path := CfgFile.Backslashed(path);
{$ENDIF}
  if path[Length(path)] <> '\' then path := path + '\';
  full := path;
  NormalizePath := Length(path) <= C_OPT.MAX_PATH_TEXT;
end;

function DirExists(path: string): Boolean;
var
  sr: SearchRec;
begin
  DirExists := False;
  if (path = '') or (Pos('*', path) > 0) or (Pos('?', path) > 0) then Exit;
{$IFNDEF FPC}
  if (Length(path) = 3) and (path[2] = ':') and (path[3] = '\') then begin
    DirExists := (UpCase(path[1]) in ['A'..'Z']) and (DiskFree(Ord(UpCase(path[1])) - Ord('A') + 1) <> -1);
    Exit;
  end;
{$ENDIF}
  if (Length(path) > 1) and (path[Length(path)] = '\') then
    Dec(path[0]);
{$IFDEF FPC}
  path := NatFile.NativeName(path);
{$ENDIF}
  FindFirst(path, Directory or Hidden or SysFile or ReadOnly or Archive, sr);
  DirExists := (DosError = 0) and (sr.Attr and Directory <> 0);
{$IFDEF FPC}
  FindClose(sr);
{$ENDIF}
end;

function CheckPath(text: string; var full: string): TPathCheck;
var
  i: Byte;
begin
{$IFDEF FPC}
  text := CfgFile.Trim(text);
{$ELSE}
  text := CfgFile.Tidy(text);
{$ENDIF}
  full := text;
  if text = '' then begin
    CheckPath := PATH_EMPTY;
    Exit;
  end;
  for i := 1 to Length(text) do
    if text[i] in ['*', '?', '"', '<', '>', '|'] then begin
      CheckPath := PATH_BAD_CHAR;
      Exit;
    end;
  if not CfgFile.NormalizePath(text, full) then
    CheckPath := PATH_TOO_LONG
  else begin
{$IFNDEF FPC}
    full := CfgFile.Tidy(full);
{$ENDIF}
    if CfgFile.DirExists(full) then
      CheckPath := PATH_OK
    else
      CheckPath := PATH_MISSING;
  end;
end;

{$IFDEF FPC}
function NativeSaveFolder(dataDir, saveDir, home: string): string;
var
  game: string;
  save: string;
  t: string;
  ok: Boolean;
begin
  { a path too long is compared as it is: this only places the saves }
  ok := CfgFile.NormalizePath(dataDir, game);
  ok := CfgFile.NormalizePath(saveDir, save);
  t := CfgFile.Trim(saveDir);
  if (Length(save) > Length(game)) and NatFile.SameName(Copy(save, 1, Length(game)), game) then
    NativeSaveFolder := home + Copy(save, Length(game) + 1, 255)
  else if (Length(t) > 0) and ((t[1] in ['\', '/']) or ((Length(t) >= 2) and (t[2] = ':'))) and
          CfgFile.DirExists(save) then
    NativeSaveFolder := save
  else
    NativeSaveFolder := home + 'SAVE\';
end;
{$ENDIF}

end.
