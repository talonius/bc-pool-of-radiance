{ Pool of Radiance's 80x25 setup program (#876). It edits POOL.CFG hardware and
  path settings, plus the gameplay settings stored in POOLOPT.CFG. Paths must
  already exist. Save and Exit writes each file through
  a temporary replacement so a failed write leaves the old file intact. Exit
  status 0 means the configuration was saved or unchanged; status 1 means the
  user left with unsaved changes.

  Under DOS, START runs POOLCFG from the game directory when POOL.CFG is missing
  or damaged. The native poolcfg program runs separately beside poolrad (#894).
  It uses the same data and writable-folder discovery as the game and translates
  DOS hardware choices to the native VGA and Digital Audio implementations
  (#1064). }
{$IFNDEF FPC}
{$M 16384,0,16384}
{$ENDIF}
{$F+,I-}
{$I COMPILER.INC}
program PoolCfg;

uses Dos, C_KEYS, C_OPT, FileUtil, CfgFile, StrUtil, TuiKit{$IFDEF FPC}, SysUtils, NatFile, GameDirs, OwnTerm{$ENDIF};

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  { the Main Menu's items: the pages, then Save and Exit and Exit Without Saving }
  ITEM_HARDWARE = 1;
  ITEM_SETTINGS = 2;
  ITEM_SOUND = 3;
  ITEM_CAMP = 4;
  ITEM_COMBAT = 5;
  ITEM_SAVE = 6;
  ITEM_QUIT = 7;
  ITEMS = 7;
  { the Hardware page's lines: the three with choices, then POOL.CFG's data and save paths, which the Paths page had
    before it went (#1177) }
  HW_VIDEO = 1;
  HW_SOUND = 2;
  HW_INTRO = 3;
  HW_CHOICES = 3;
  HW_DATA = 4;
  HW_SAVE = 5;
  HW_LINES = 5;
  { the Hardware page's values: their column, and a path's edit field }
  VALUE_COL = 26;
  FIELD_WIDTH = 50;
  { the longest path that can be typed: a DOS path's 79 characters, natively 255 }
  PATH_TYPED = C_OPT.MAX_PATH_TEXT + C_OPT.LONGEST_NAME + C_OPT.WORK_FOLDERS;
  { the program that reads POOL.CFG: START under DOS, the game itself natively }
{$IFDEF FPC}
  GAME_PROG = 'POOLRAD';
{$ELSE}
  GAME_PROG = 'START';
{$ENDIF}

var
  { POOL.CFG as Setup will write it (its paths normalized), and as it was read; what the read found, and its notes }
  cfg: CfgFile.TPoolCfg;
  cfgRead: CfgFile.TPoolCfg;
  cfgState: CfgFile.TReadResult;
  notes: CfgFile.TCfgNotes;
  { POOL.CFG's defaults (CfgFile.PoolDefaults), for a missing file and F5 }
  cfgDefaults: CfgFile.TPoolCfg;
  { a path, as read, that START refuses as too long for DOS: shown in red until corrected }
  tooLong: array[HW_DATA..HW_SAVE] of Boolean;
  { POOLOPT.CFG as Setup will write it, as it was read, and every setting's default; what the read found, and how many
    values it would not take }
  opts: CfgFile.TSettings;
  optsRead: CfgFile.TSettings;
  defaults: CfgFile.TSettings;
  optState: CfgFile.TReadResult;
  optBad: Byte;
  { the folder Setup runs in, normalized (the Pool data path's default), POOL.CFG's full name, and the folder
    POOLOPT.CFG was read from }
  homeDir: string;
  cfgName: string;
  optDir: string;
{$IFDEF FPC}
  { the data folder the game finds (GameDirs.dataFolder), normalized as POOL.CFG holds it: the data path's default }
  dataHome: string;
{$ENDIF}
  { a stepping setting's choice on the Game Settings page: the right one (Faster, More) }
  stepRight: Boolean;
  { run by START (C_OPT.SETUP_FROM_START on the command line) }
  fromStart: Boolean;
  { leave the program, with this exit code }
  leave: Boolean;
  exitCode: Byte;

{ path as shown, cut to width characters: a path too long keeps its end, after '...', as its last folders say the most.
  On Linux and macOS its backslashes are shown as the system's '/'. }
function CutPath(path: string; width: Byte): string;
{$IFDEF UNIX}
var
  i: Byte;
{$ENDIF}
begin
{$IFDEF UNIX}
  for i := 1 to Length(path) do
    if path[i] = '\' then
      path[i] := '/';
{$ENDIF}
  if Length(path) > width then
    path := '...' + Copy(path, Length(path) - (width - 3) + 1, width - 3);
  CutPath := path;
end;

{ The title bar, and the blue page under it from row 2 to row 24. }
procedure ClearPage;
begin
  TuiKit.TitleBar('Pool of Radiance Setup', 'POOLCFG ' + CfgFile.Tidy(BUILD_VERSION));
  TuiKit.Fill(1, 2, TuiKit.COLS, TuiKit.ROWS - 1, TuiKit.A_TEXT);
end;

{ --- the Hardware page's choices ------------------------------------------------------------------------------- }

{ How many choices Hardware line has. }
function ChoiceCount(line: Byte): Byte;
begin
  case line of
    HW_VIDEO: ChoiceCount := 5;
    HW_SOUND: ChoiceCount := 5;
  else
    ChoiceCount := 2;
  end;
end;

{ The POOL.CFG letter of choice i of Hardware line. }
function ChoiceLetter(line, i: Byte): Char;
const
  VIDEO: array[1..5] of Char = (C_OPT.VIDEO_CGA, C_OPT.VIDEO_EGA, C_OPT.VIDEO_TANDY, C_OPT.VIDEO_VGA,
    C_OPT.VIDEO_VESA);
  SOUND: array[1..5] of Char = (C_OPT.SOUND_SILENT, C_OPT.SOUND_SPEAKER, C_OPT.SOUND_TANDY, C_OPT.SOUND_ADLIB,
    C_OPT.SOUND_BLASTER);
  INTRO: array[1..2] of Char = (C_OPT.INTRO_FULL, C_OPT.INTRO_SHORT);
begin
  case line of
    HW_VIDEO: ChoiceLetter := VIDEO[i];
    HW_SOUND: ChoiceLetter := SOUND[i];
  else
    ChoiceLetter := INTRO[i];
  end;
end;

{ The name of choice i of Hardware line. }
function ChoiceName(line, i: Byte): TuiKit.TLine;
const
  VIDEO: array[1..5] of string[11] = ('CGA', 'EGA', 'Tandy', 'VGA', 'VGA 640x400');
  SOUND: array[1..5] of string[13] = ('None', 'PC Speaker', 'Tandy', 'AdLib', 'Sound Blaster');
  INTRO: array[1..2] of string[5] = ('Full', 'Short');
begin
  case line of
    HW_VIDEO: ChoiceName := VIDEO[i];
    HW_SOUND: ChoiceName := SOUND[i];
  else
    ChoiceName := INTRO[i];
  end;
end;

{ Hardware line's label, on the page and over its pick list. }
function LineName(line: Byte): TuiKit.TLine;
const
  NAMES: array[1..HW_LINES] of string[12] = ('Video', 'Sound Device', 'Introduction', 'Data Path',
    'Save Path');
begin
  LineName := NAMES[line];
end;

{ Hardware line's letter in c. }
function LineLetter(var c: CfgFile.TPoolCfg; line: Byte): Char;
begin
  case line of
    HW_VIDEO: LineLetter := c.video;
    HW_SOUND: LineLetter := c.sound;
  else
    LineLetter := c.intro;
  end;
end;

{ The choice Hardware line has in c: the index of its letter (1 for a letter that is no choice's). }
function ChoiceOf(var c: CfgFile.TPoolCfg; line: Byte): Byte;
var
  i: Byte;
begin
  ChoiceOf := 1;
  for i := 1 to ChoiceCount(line) do
    if ChoiceLetter(line, i) = LineLetter(c, line) then
      ChoiceOf := i;
end;

{ Set Hardware line to choice i. }
procedure SetChoice(line, i: Byte);
begin
  case line of
    HW_VIDEO: cfg.video := ChoiceLetter(line, i);
    HW_SOUND: cfg.sound := ChoiceLetter(line, i);
  else
    cfg.intro := ChoiceLetter(line, i);
  end;
end;

{ --- the paths ------------------------------------------------------------------------------------------------- }

{ Path line's path in c (HW_DATA or HW_SAVE). }
function PathOf(var c: CfgFile.TPoolCfg; line: Byte): string;
begin
  if line = HW_DATA then
    PathOf := c.dataDir
  else
    PathOf := c.saveDir;
end;

{ Set path line to path (a normalized one), marked when it is too long for START (tooLong), as a default can be in a
  folder too deep for DOS. }
procedure SetPath(line: Byte; path: string);
begin
  if line = HW_DATA then
    cfg.dataDir := path
  else
    cfg.saveDir := path;
  tooLong[line] := Length(path) > C_OPT.MAX_PATH_TEXT;
end;

{ Path line's default: the data in the folder Setup runs in (natively the data folder the game finds) and the saves in
  SAVE\ under it (natively under the writable folder). }
function DefaultPath(line: Byte): string;
begin
  if line = HW_DATA then
    DefaultPath := {$IFDEF FPC}dataHome{$ELSE}homeDir{$ENDIF}
  else
    DefaultPath := homeDir + 'SAVE\';
end;

{ True when folder dir holds Pool of Radiance's data: ITEMS or GEO1.DAX. }
function HasPoolData(dir: string): Boolean;
begin
  HasPoolData := FileUtil.Exists(dir + 'ITEMS') or FileUtil.Exists(dir + 'GEO1.DAX');
end;

{ --- what has changed ------------------------------------------------------------------------------------------ }

function PathChanged(line: Byte): Boolean;
begin
  PathChanged := PathOf(cfg, line) <> PathOf(cfgRead, line);
end;

{ True when anything on the Hardware page differs from POOL.CFG as read: a letter or a path. }
function HardwareChanged: Boolean;
begin
  HardwareChanged := (cfg.video <> cfgRead.video) or (cfg.sound <> cfgRead.sound) or (cfg.intro <> cfgRead.intro) or
                     PathChanged(HW_DATA) or PathChanged(HW_SAVE);
end;

{ True when setting opt differs from POOLOPT.CFG as read. }
function SettingChanged(opt: Byte): Boolean;
begin
  SettingChanged := CfgFile.StoredValue(opts, opt) <> CfgFile.StoredValue(optsRead, opt);
end;

function SettingsChanged(page: Byte): Boolean;
var
  opt: Byte;
  changed: Boolean;
begin
  changed := False;
  for opt := 1 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) = page then
      changed := changed or SettingChanged(opt);
  SettingsChanged := changed;
end;

{ True when a setting of any settings page differs from POOLOPT.CFG as read. }
function AnySettingChanged: Boolean;
var
  page: Byte;
  changed: Boolean;
begin
  changed := False;
  for page := 1 to C_OPT.OPT_PAGES do
    changed := changed or SettingsChanged(page);
  AnySettingChanged := changed;
end;

{ True when saving writes POOL.CFG: something in it changed, or it was missing or is not as START would read it. }
function PoolCfgDue: Boolean;
begin
  PoolCfgDue := HardwareChanged or (cfgState in [CfgFile.CFG_MISSING, CfgFile.CFG_FIXED]);
end;

{ True when saving writes POOLOPT.CFG: something in it changed, or the save folder did (the settings go with it), or it
  was missing or not as the game would read it and the save folder is there. }
function OptionsDue: Boolean;
var
  due: Boolean;
begin
  due := AnySettingChanged or PathChanged(HW_SAVE);
  if (optState in [CfgFile.CFG_MISSING, CfgFile.CFG_FIXED]) and CfgFile.DirExists(cfg.saveDir) then
    due := True;
  OptionsDue := due;
end;

{ True when leaving now would lose something: a change, or a POOL.CFG still to be written. }
function Unsaved: Boolean;
begin
  Unsaved := AnySettingChanged or PoolCfgDue;
end;

{ --- the Main Menu --------------------------------------------------------------------------------------------- }

{ What a file's read found (state), as the Files box says it, and its colour in attr; fixed is what CFG_FIXED says. }
function ReadState(state: CfgFile.TReadResult; fixed: string; var attr: Byte): string;
begin
  attr := TuiKit.A_WARN;
  case state of
    CfgFile.CFG_READ: begin
                        ReadState := 'read';
                        attr := TuiKit.A_GOOD;
                      end;
    CfgFile.CFG_MISSING: ReadState := 'not found: defaults';
    CfgFile.CFG_FIXED: ReadState := fixed;
  else begin
      ReadState := 'cannot read';
      attr := TuiKit.A_BAD;
    end;
  end;
end;

{ The Files box: each file's name, where it is and what the read found, and the pages with changes. }
procedure DrawFiles;
var
  state: string;
  attr: Byte;
  changes: string;

  { Add page to the pages with changes. }
  procedure Changed(page: string);
  begin
    if changes <> '' then
      changes := changes + ', ';
    changes := changes + page;
  end;

begin
  TuiKit.Box(3, 15, 78, 19, TuiKit.A_FRAME, 'Files');
  TuiKit.PutText(5, 16, TuiKit.A_TEXT, C_OPT.CFG_NAME);
  TuiKit.PutText(18, 16, TuiKit.A_TEXT, CutPath(cfgName, 30));
  state := ReadState(cfgState, 'fixed', attr);
  TuiKit.PutText(49, 16, attr, state);
  TuiKit.PutText(5, 17, TuiKit.A_TEXT, C_OPT.OPT_NAME);
  TuiKit.PutText(18, 17, TuiKit.A_TEXT, CutPath(optDir + C_OPT.OPT_NAME, 30));
  state := ReadState(optState, 'fixed: ' + StrUtil.Count(optBad, 'value', 'values') + ' out of range', attr);
  TuiKit.PutText(49, 17, attr, state);
  TuiKit.PutText(5, 18, TuiKit.A_TEXT, 'Changes');
  changes := '';
  if HardwareChanged then
    Changed('Hardware');
  if SettingsChanged(C_OPT.OPT_PAGE_GAME) then
    Changed('Game Settings');
  if SettingsChanged(C_OPT.OPT_PAGE_SOUND) then
    Changed('Sound Settings');
  if SettingsChanged(C_OPT.OPT_PAGE_CAMP) then
    Changed('Camp Settings');
  if SettingsChanged(C_OPT.OPT_PAGE_COMBAT) then
    Changed('Combat Settings');
  if (changes = '') and PoolCfgDue then
    changes := 'none; saving writes POOL.CFG';
  if changes <> '' then
    TuiKit.PutText(18, 18, TuiKit.A_WARN, changes)
  else
    TuiKit.PutText(18, 18, TuiKit.A_TEXT, 'none');
end;

{ The Main Menu's row of item i. }
function ItemRow(i: Byte): Byte;
begin
  ItemRow := 4 + i + Ord(i >= ITEM_SAVE);
end;

{ The Main Menu, item sel highlighted. }
procedure DrawMain(sel: Byte);
const
  NAMES: array[1..ITEMS] of string[19] = ('Hardware', 'Game Settings', 'Sound Settings', 'Camp Settings',
    'Combat Settings', 'Save and Exit', 'Exit Without Saving');
  { each item's hot letter's place in its name: Sound Settings' O, as Save and Exit has S, and Combat Settings' M, as
    Camp Settings has C }
  HOT: array[1..ITEMS] of Byte = (1, 1, 2, 1, 3, 1, 2);
  ABOUT: array[1..ITEM_SAVE - 1] of string[28] = ('Video, sound, intro, folders', 'Speed, portraits, Journal',
    'Music and sound effects', 'Auto Memorize, Fix', 'Quick Mode, aim, combat log');
var
  i: Byte;
begin
  ClearPage;
  TuiKit.Box(16, 3, 65, 13, TuiKit.A_FRAME, 'Main Menu');
  for i := 1 to ITEMS do begin
    TuiKit.PutText(20, ItemRow(i), TuiKit.A_TEXT, NAMES[i]);
    TuiKit.PutRun(19 + HOT[i], ItemRow(i), TuiKit.A_HOT, NAMES[i][HOT[i]], 1);
    if i < ITEM_SAVE then
      TuiKit.PutText(36, ItemRow(i), TuiKit.A_HELP, ABOUT[i]);
  end;
  TuiKit.Recolor(17, ItemRow(sel), 48, TuiKit.A_HIGHLIGHT);
  DrawFiles;
  TuiKit.KeyLine('~Enter~ Select   ~Esc~ Exit   ~F10~ Save and Exit');
end;

{ --- saving ---------------------------------------------------------------------------------------------------- }

{ Show an error: title Error, the lines first and second (second, a file or folder, in the error box's value colour). }
procedure ShowError(first, second: string);
var
  lines: TuiKit.TLines;
begin
  TuiKit.ClearLines(lines);
  TuiKit.AddLine(lines, first, 0);
  if second <> '' then begin
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, second, TuiKit.A_ERROR_VALUE);
  end;
  TuiKit.Message('Error', lines, TuiKit.STYLE_ERROR, 44);
end;

{ Save: POOLOPT.CFG into the save folder being written, then POOL.CFG, each only when due. True when every file due
  was written (or none was), and the files written are said; else the error is shown and Setup stays open with the
  changes kept. A POOL.CFG that could not be read is not written over, nor one with a path START refuses. }
function Save: Boolean;
var
  lines: TuiKit.TLines;
  poolDue: Boolean;
  optDue: Boolean;
begin
  Save := False;
  if cfgState = CfgFile.CFG_UNREADABLE then begin
    ShowError('POOL.CFG could not be read, so Setup will not', 'write over it: ' + CutPath(cfgName, 22));
    Exit;
  end;
  if tooLong[HW_DATA] or tooLong[HW_SAVE] then begin
    ShowError('A Pool of Radiance path is too long for DOS.', 'Correct it on the Hardware page first.');
    Exit;
  end;
  poolDue := PoolCfgDue;
  optDue := OptionsDue;
  if optDue and not CfgFile.WriteOptions(cfg.saveDir, opts) then begin
    ShowError('Could not write ' + C_OPT.OPT_NAME + '. The folder may be',
              'missing or read-only: ' + CutPath(cfg.saveDir, 20));
    Exit;
  end;
  if poolDue and not CfgFile.WritePoolCfg({$IFDEF FPC}cfgName{$ELSE}C_OPT.CFG_NAME{$ENDIF}, cfg) then begin
    ShowError('Could not write ' + C_OPT.CFG_NAME + '. The folder may be', 'read-only; nothing in it was changed.');
    Exit;
  end;
{$IFDEF FPC}
  { the data folder the game is to use from now on (#1064) }
  if PathChanged(HW_DATA) and not GameDirs.Remember(GameDirs.POOL, NatFile.NativeName(cfg.dataDir)) then begin
    ShowError('Could not remember the data folder in', CutPath(GameDirs.UserFolder(GameDirs.POOL, GameDirs.THIS_OS,
              GetUserDir), 38));
    Exit;
  end;
{$ENDIF}
  TuiKit.ClearLines(lines);
  if not optDue and not poolDue then
    TuiKit.AddLine(lines, 'Nothing has changed, so no file was written.', 0)
  else begin
    TuiKit.AddLine(lines, 'Setup wrote:', 0);
    TuiKit.AddLine(lines, '', 0);
    if optDue then
      TuiKit.AddLine(lines, '  ' + CutPath(cfg.saveDir + C_OPT.OPT_NAME, 60), TuiKit.A_POP_VALUE);
    if poolDue then
      TuiKit.AddLine(lines, '  ' + CutPath(cfgName, 60), TuiKit.A_POP_VALUE);
  end;
  TuiKit.KeyLine('Press any key');
  TuiKit.Message('Saved', lines, TuiKit.STYLE_NOTICE, 64);
  Save := True;
end;

{ Save and, when it did, leave with exit code 0. }
procedure SaveAndLeave;
begin
  if Save then begin
    exitCode := 0;
    leave := True;
  end;
end;

{ --- the Hardware page ----------------------------------------------------------------------------------------- }

{ The Hardware page's help for line, under the divider: for a path START refuses or whose folder is not there, what
  that means. }
procedure DrawHardwareHelp(line: Byte);
var
  row: Byte;

  procedure Put(indent: Byte; s: string);
  begin
    TuiKit.PutText(6 + indent, row, TuiKit.A_HELP, s);
    Inc(row);
  end;

  { s in attr }
  procedure Warn(attr: Byte; s: string);
  begin
    TuiKit.PutText(6, row, attr, s);
    Inc(row);
  end;

begin
  TuiKit.Fill(4, 12, 77, 22, TuiKit.A_TEXT);
  row := 12;
  if line >= HW_DATA then begin
{$IFDEF FPC}
    if line = HW_DATA then begin
      Put(0, 'The folder the native game reads SSI''s files from, found beside it');
      Put(0, 'or in GOG''s or Steam''s folders. Saving a change makes the game use');
      Put(0, 'it. It needs GEO1.DAX; poolrad --choose-data-folder chooses it too.');
      Inc(row);
    end;
{$ENDIF}
    if tooLong[line] then begin
      Warn(TuiKit.A_BAD, 'This path is too long for DOS (' + StrUtil.NumStr(C_OPT.MAX_PATH_TEXT) +
           ' characters at most).');
      Warn(TuiKit.A_BAD, 'START will not run until it is corrected.');
    end else if not CfgFile.DirExists(PathOf(cfg, line)) then begin
      Warn(TuiKit.A_WARN, 'This folder is not there.');
      if line = HW_DATA then
        Warn(TuiKit.A_WARN, 'START will ask for the disk when it needs a file.')
      else
        Warn(TuiKit.A_WARN, 'The game will create it on the first save.');
      Warn(TuiKit.A_WARN, 'Enter a folder that exists, or F5 for the default.');
    end else begin
      Put(0, 'A folder must already exist: Setup checks each path as it is');
      Put(0, 'entered and creates none.');
    end;
    Inc(row);
    if line = HW_DATA then
      Put(0, GAME_PROG + ' reads this as POOL.CFG''s third line.')
    else
      Put(0, GAME_PROG + ' reads this as POOL.CFG''s fourth line.');
    Exit;
  end;
{$IFDEF FPC}
  case line of
    HW_VIDEO: begin
                Put(0, 'The graphics card the DOS game draws with. The native game always');
                Put(0, 'draws in VGA (EGA''s 16 colours), whatever this says:');
                Inc(row);
                Put(2, 'CGA, EGA, Tandy, VGA, VGA 640x400   all VGA natively');
                Inc(row);
                Put(0, 'It is kept for a copy of the game run under DOS or DOSBox.');
                Put(0, 'POOLRAD reads this as POOL.CFG''s first line.');
              end;
    HW_SOUND: begin
                Put(0, 'The card the DOS game plays music and effects on. The native game');
                Put(0, 'always plays Digital Audio, whatever this says: the Tandy''s music');
                Put(0, 'and the Sound Blaster''s recorded effects.');
                Inc(row);
                Put(0, 'For silence, turn off Music and Sound on the Settings page');
                Put(0, '(Ctrl-S in the game).');
                Inc(row);
                Put(0, 'It is kept for a copy of the game run under DOS or DOSBox.');
                Put(0, 'POOLRAD reads this as POOL.CFG''s second line.');
              end;
  else begin
      Put(0, 'Full: SSI''s whole title sequence. Short: the title and straight to');
      Put(0, 'the menu.');
      Inc(row);
      Put(0, 'POOLRAD reads this as POOL.CFG''s fifth line.');
    end;
  end;
{$ELSE}
  case line of
    HW_VIDEO: begin
                Put(0, 'The graphics card the game draws with:');
                Inc(row);
                Put(2, 'CGA     4 colours');
                Put(2, 'EGA     16 colours');
                Put(2, 'Tandy   16 colours, Tandy 1000 and PCjr');
                Put(2, 'VGA     EGA''s 16 colours in VGA''s 320x200 mode (not in SSI''s game)');
                Put(2, 'VGA 640x400   VGA through VESA, a prototype: the art 2x2, more');
                Put(2, '              text room; VGA where the card has no VESA');
                Inc(row);
                Put(0, 'START reads this as POOL.CFG''s first line.');
              end;
    HW_SOUND: begin
                Put(0, 'The card the game plays music and effects on:');
                Inc(row);
                Put(2, 'None            silence');
                Put(2, 'PC Speaker      music and effects on the speaker');
                Put(2, 'Tandy           the Tandy 1000''s three voices');
                Put(2, 'AdLib           AdLib music, effects on the speaker');
                Put(2, 'Sound Blaster   AdLib music, SSI''s recorded effects');
                Inc(row);
                Put(0, 'START reads this as POOL.CFG''s second line.');
              end;
  else begin
      Put(0, 'Full: SSI''s whole title sequence. Short: the title and straight to');
      Put(0, 'the menu.');
      Inc(row);
      Put(0, 'START reads this as POOL.CFG''s fifth line.');
    end;
  end;
{$ENDIF}
end;

{ The Hardware page's row of line. }
function HardwareRow(line: Byte): Byte;
begin
  HardwareRow := 4 + line;
end;

{ Hardware line on its row, highlighted when sel: a choice's name, or a path, red when START refuses it; a changed one
  white with a '*'. }
procedure DrawHardwareLine(line: Byte; sel: Boolean);
var
  row: Byte;
  value: string;
  attr: Byte;
begin
  row := HardwareRow(line);
  TuiKit.PutRun(4, row, TuiKit.A_TEXT, ' ', 74);
  TuiKit.PutText(6, row, TuiKit.A_TEXT, LineName(line));
  attr := TuiKit.A_VALUE;
  if line >= HW_DATA then begin
    value := CutPath(PathOf(cfg, line), FIELD_WIDTH - 1);
    if tooLong[line] then
      attr := TuiKit.A_BAD
    else if PathChanged(line) then
      attr := TuiKit.A_CHANGED;
  end else begin
    value := ChoiceName(line, ChoiceOf(cfg, line));
    if LineLetter(cfg, line) <> LineLetter(cfgRead, line) then
      attr := TuiKit.A_CHANGED;
  end;
  if attr = TuiKit.A_CHANGED then
    value := value + '*';
  TuiKit.PutText(VALUE_COL, row, attr, value);
  if sel then
    TuiKit.Recolor(4, row, 74, TuiKit.A_HIGHLIGHT);
end;

procedure DrawHardware(sel: Byte);
var
  line: Byte;
begin
  ClearPage;
  TuiKit.Box(3, 3, 78, 23, TuiKit.A_FRAME, 'Hardware (POOL.CFG)');
  TuiKit.Divider(3, 78, HardwareRow(HW_LINES) + 2, TuiKit.A_FRAME);
  for line := 1 to HW_LINES do
    DrawHardwareLine(line, line = sel);
  DrawHardwareHelp(sel);
  if sel >= HW_DATA then
    TuiKit.KeyLine('~Up Dn~ Move  ~Enter~ Edit  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save and Exit')
  else
    TuiKit.KeyLine('~Up Dn~ Move  ~Lt Rt~ Change  ~Enter~ List  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save+Exit');
end;

{ Edit path line in place, starting with character first (#0: the path as it is) until a path is accepted or Escape
  puts the old one back. A path is checked as it is accepted (CfgFile.CheckPath): one that is empty, holds a character
  no path may, is too long for DOS or is not an existing folder is refused with the reason, and the edit goes on with
  the text kept. A data folder without the game's data is taken with a warning; a changed save folder with a note that
  the saved games stay where they are. }
procedure EditPath(line: Byte; first: Char);
var
  text: string;
  full: string;
  key: Char;
  check: CfgFile.TPathCheck;
  lines: TuiKit.TLines;
  accepted: Boolean;
begin
  text := CutPath(PathOf(cfg, line), 255);
  accepted := False;
  { the field in place of the highlight, its brackets on the page's own colour }
  DrawHardwareLine(line, False);
  repeat
    TuiKit.KeyLine('Type the folder   ~Lt Rt Home End Del Bksp~   ~Enter~ Accept   ~Esc~ Cancel');
    key := TuiKit.EditLine(VALUE_COL, HardwareRow(line), FIELD_WIDTH, text, PATH_TYPED, first);
    first := #0;
    if key = C_KEYS.ENTER then begin
      check := CfgFile.CheckPath(text, full);
      case check of
{$IFDEF FPC}
        CfgFile.PATH_OK: if (line <> HW_DATA) or GameDirs.HoldsData(NatFile.NativeName(full), GameDirs.POOL) then
                           accepted := True
                         else
                           ShowError('No Pool of Radiance data (GEO1.DAX) is in', CutPath(full, 38));
{$ELSE}
        CfgFile.PATH_OK: accepted := True;
{$ENDIF}
        CfgFile.PATH_EMPTY: ShowError('Please type the folder''s path.', '');
        CfgFile.PATH_BAD_CHAR: ShowError('A folder''s path cannot hold * ? " < > or |.', CutPath(full, 38));
        CfgFile.PATH_TOO_LONG: ShowError('This path is too long for DOS (' + StrUtil.NumStr(C_OPT.MAX_PATH_TEXT) +
                                         ' characters at most).', CutPath(full, 38));
      else
        ShowError('Please verify the directory exists.', CutPath(full, 38));
      end;
    end;
  until accepted or (key = C_KEYS.ESCAPE);
  if not accepted then Exit;
{$IFNDEF FPC}
  if (line = HW_DATA) and not HasPoolData(full) then begin
    TuiKit.ClearLines(lines);
    TuiKit.AddLine(lines, 'No Pool of Radiance data (ITEMS, GEO1.DAX) is in', 0);
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, '  ' + CutPath(full, 54), TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, 'Setup takes it, but START will ask for the disk.', 0);
    TuiKit.Message('Warning', lines, TuiKit.STYLE_NOTICE, 64);
  end;
{$ENDIF}
  if (line = HW_SAVE) and (full <> cfgRead.saveDir) and (full <> cfg.saveDir) then begin
    TuiKit.ClearLines(lines);
    TuiKit.AddLine(lines, 'Saved games stay in ' + CutPath(cfgRead.saveDir, 38), 0);
    TuiKit.AddLine(lines, 'Setup does not move them. The settings go with', 0);
    TuiKit.AddLine(lines, 'the new folder when you save.', 0);
    TuiKit.Message('Note', lines, TuiKit.STYLE_NOTICE, 64);
  end;
  SetPath(line, full);
end;

{ The Hardware page (POOL.CFG's letters and paths) until Escape, or F10 saves and leaves. On a path, Enter or a
  character typed edits it (EditPath); Left, Right and Space change only a choice. }
procedure HardwarePage;
var
  sel: Byte;
  i: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
  path: Boolean;
  items: TuiKit.TLines;
begin
  sel := HW_VIDEO;
  DrawHardware(sel);
  done := False;
  repeat
    TuiKit.GetKey(ch, ext);
    path := sel >= HW_DATA;
    i := 1;
    if not path then
      i := ChoiceOf(cfg, sel);
    if ext then begin
      TuiKit.MoveInList(ch, sel, HW_LINES);
      case ch of
        C_KEYS.LEFT: if not path then
                       SetChoice(sel, (i + ChoiceCount(sel) - 2) mod ChoiceCount(sel) + 1);
        C_KEYS.RIGHT: if not path then
                        SetChoice(sel, i mod ChoiceCount(sel) + 1);
        C_KEYS.F5: if path then
                     SetPath(sel, DefaultPath(sel))
                   else
                     SetChoice(sel, ChoiceOf(cfgDefaults, sel));
        C_KEYS.F10: begin
                      SaveAndLeave;
                      done := leave;
                    end;
      end;
    end else
      case ch of
        ' ': if not path then
               SetChoice(sel, i mod ChoiceCount(sel) + 1);
        C_KEYS.ENTER: if path then
                        EditPath(sel, #0)
                      else begin
                        TuiKit.ClearLines(items);
                        for i := 1 to ChoiceCount(sel) do
                          TuiKit.AddLine(items, ChoiceName(sel, i), 0);
                        i := ChoiceOf(cfg, sel);
                        TuiKit.KeyLine('~Up Dn~ Move  ~Enter~ Choose  ~Esc~ Cancel');
                        if TuiKit.PickList(41, 4, LineName(sel), items, i) then
                          SetChoice(sel, i);
                      end;
        C_KEYS.ESCAPE: done := True;
        '!'..'~': if path then
                    EditPath(sel, ch);
      end;
    if not done then
      DrawHardware(sel);
  until done;
end;

{ --- the Game and Sound Settings pages ------------------------------------------------------------------------- }

{ The row of setting opt on its settings page: its line (CfgFile.SettingLine) from row 3, as on the game's Settings
  screen. }
function SettingRow(opt: Byte): Byte;
begin
  SettingRow := 3 + CfgFile.SettingLine(opt);
end;

{ POOL.CFG as Setup will write it gives the game no sound device (CfgFile.NoSoundDevice), so the Sound Settings page
  shows Music and Sound OFF and greys its lines, which the arrows pass by (#1156). Never natively, where the game plays
  Digital Audio whatever the letter (#1097). }
function NoDevice: Boolean;
begin
{$IFDEF FPC}
  NoDevice := False;
{$ELSE}
  NoDevice := CfgFile.NoSoundDevice(cfg.sound);
{$ENDIF}
end;

{ The settings a settings page cannot change: without a sound device the Sound page's (CfgFile.Silenced). }
function Locked(opt: Byte): Boolean;
var
  skip: CfgFile.TOptSet;
begin
  skip := [];
  CfgFile.Silenced(NoDevice, skip);
  Locked := opt in skip;
end;

{ What setting opt does, its lines split at '|', for the About box. }
function AboutText(opt: Byte): string;
begin
  case opt of
    C_OPT.OPT_SPEED: AboutText := 'How long the game waits over|its messages and animations:|' +
                                  '0 is the fastest, 9 the|slowest. Slower raises it.';
    C_OPT.OPT_PORTRAITS_ALL: AboutText := 'Every portrait at once: off,|the game shows none.';
    C_OPT.OPT_MONSTERS: AboutText := 'The monsters'' pictures when|an encounter starts.';
    C_OPT.OPT_PORTRAITS: AboutText := 'The party''s portraits on the|character screens.';
    C_OPT.OPT_AUTO_JOIN: AboutText := 'Arrows, darts and the like|join the stack you carry as|' +
                                      'you buy, take or trade them,|so a new bundle takes no|' +
                                      'item slot of its own. Up to|255 to a stack; a readied|stack stays readied.';
    C_OPT.OPT_CONSOLIDATE: AboutText := 'When a character picks up|coins, its purse is changed|' +
                                        'into the fewest coins of the|same value: 5 gold make a|' +
                                        'platinum. Coins weigh the|same, so the load drops.';
    C_OPT.OPT_JOURNAL: AboutText := 'FOUND: the Journal lists the|entries, tavern tales and|' +
                                    'proclamations the party has|come across. ALL: the whole|' +
                                    'printed Journal.||A game saved before this|version counts them all|found.';
    C_OPT.OPT_NONHUMAN_CAP: AboutText := 'Dwarves, elves, gnomes,|half-elves, halflings and|' +
                                         'half-orcs stop at their|race''s level limits.||' +
                                         'Off: they train as far as|the experience table goes,|as humans do.';
    C_OPT.OPT_LEVEL_CAP: AboutText := 'Each class stops where|SSI''s game stopped it:|' +
                                      'clerics and magic-users at|6, paladins and rangers at|' +
                                      '7, fighters at 8.||Off: every class trains to|' +
                                      '9, with the spells of|levels 4 and 5.';
    C_OPT.OPT_TRAIN_ANYWHERE: AboutText := 'F4 opens the training hall''s|menu anywhere outside|' +
                                           'combat: Train, View and Dual|Class. The hall''s rules all|' +
                                           'hold: 1000 gp, the|experience, one level at a|' +
                                           'time and the level caps.|Training takes no time.';
    C_OPT.OPT_MUSIC: AboutText := 'Every tune at once.';
    C_OPT.OPT_TITLE_MUSIC: AboutText := 'The title theme.';
    C_OPT.OPT_BATTLE_MUSIC: AboutText := 'The music as a fight starts.';
    C_OPT.OPT_SOUND: AboutText := 'Every sound effect at once|(Ctrl-S in the game).';
    C_OPT.OPT_FOOTSTEPS: AboutText := 'The party''s steps.';
    C_OPT.OPT_RANGED: AboutText := 'Missiles in flight and their|hits and misses.';
    C_OPT.OPT_MELEE: AboutText := 'Melee attacks'' hits and|misses.';
    C_OPT.OPT_DEATH: AboutText := 'A creature going down.';
    C_OPT.OPT_WALL: AboutText := 'The party walking into a|wall.';
    C_OPT.OPT_SPELLS: AboutText := 'Spells being cast, and their|effects.';
    C_OPT.OPT_QUICK: AboutText := 'Quick mode ends with the|fight it was turned on in.';
    C_OPT.OPT_MAGIC: AboutText := 'Characters in quick mode|cast their spells.';
    C_OPT.OPT_GEAR: AboutText := 'Characters in quick mode|change weapons and shields.||' +
                                 'Off: they keep what you|readied. One holding a bow|' +
                                 'with an enemy beside it|ends its turn instead.';
    C_OPT.OPT_AIM: AboutText := 'What Next and Prev step|through when you aim.||' +
                                'ENEMIES: the other side, or|your own side for a spell|' +
                                'that is not an attack.|ALL: every creature.||Manual reaches anyone.';
    C_OPT.OPT_RETRIEVE: AboutText := 'A thrown hammer, axe, spear|or the like goes back to|' +
                                     'whoever threw it after the|fight, readied if the hand|' +
                                     'is free. One who cannot|carry it leaves it in the|loot.';
    C_OPT.OPT_MINIMAP: AboutText := 'The whole arena as a small|map under the creature''s|' +
                                    'details in combat: walls in|blue, the party light cyan,|' +
                                    'enemies yellow, the fallen|light red and whoever acts|' +
                                    'white.||F3 in combat turns it on|and off. Not shown in the|Wide View.';
    C_OPT.OPT_WIDE_COMBAT: AboutText := 'The combat map across the|whole screen, 13 squares by|' +
                                        '6, with the creature and the|messages on three lines|' +
                                        'under it. It costs memory: a|fight without enough has the|' +
                                        'usual view. No minimap in it.';
    C_OPT.OPT_COMPANION: AboutText := 'The Companion Tools: F6 on|the map and camp menus.';
    C_OPT.OPT_CLUES: AboutText := 'The Companion Tools'' notes|from the Clue Book.';
    C_OPT.OPT_AUTO_MEMORIZE: AboutText := 'Rest memorizes each caster''s|usual spells again (those it|' +
                                          'last confirmed memorizing)|when it has none picked.|' +
                                          'Spells picked in Memorize|come first.';
    C_OPT.OPT_FIX_SCROLLS: AboutText := 'Fix reads the party''s|scrolls: Restoration for a|' +
                                        'drained level, before the|clerics plan their spells,|' +
                                        'then cures and Cure Light|Wounds for what is left.';
    C_OPT.OPT_FIX_POTIONS: AboutText := 'Fix uses Potions of Healing|and Keoghtom''s Ointment on|' +
                                        'what the spells leave.';
    C_OPT.OPT_FIX_CURE: AboutText := 'A paladin cures a disease the|spells leave, from the cures|' +
                                     'a week allows.';
    C_OPT.OPT_FIX_HEAL: AboutText := 'A paladin lays on hands, once|a day, on the most wounded|' +
                                     'character the spells leave.';
    C_OPT.OPT_COMBAT_LOG: AboutText := 'Keeps the fight''s messages for|F7 to page back through.||' +
                                       'Under DOS the log needs EMS:|without it the game keeps none,|' +
                                       'whatever this says.';
    C_OPT.OPT_LOG_LINES: AboutText := 'How many messages the combat|log keeps, from 10 to 60 in|steps of 5.';
  else
    AboutText := '';
  end;
end;

{ The About box for setting opt: its name, what it does, its default and its key; for a setting without a sound device
  to play on (Locked), how to get one. }
procedure DrawAbout(opt: Byte);
var
  text: string;
  row: Byte;
  bar: Byte;
begin
  TuiKit.Fill(47, 3, 78, 23, TuiKit.A_TEXT);
  text := CfgFile.SettingName(opt);
  while (text <> '') and (text[1] = ' ') do
    Delete(text, 1, 1);
  TuiKit.PutText(48, 3, TuiKit.A_FRAME, text);
  text := AboutText(opt) + '|';
  row := 5;
  while text <> '' do begin
    bar := Pos('|', text);
    TuiKit.PutText(48, row, TuiKit.A_HELP, Copy(text, 1, bar - 1));
    Delete(text, 1, bar);
    Inc(row);
  end;
  if Locked(opt) then begin
    Inc(row);
    TuiKit.PutText(48, row, TuiKit.A_WARN, 'No sound device in POOL.CFG:');
    TuiKit.PutText(48, row + 1, TuiKit.A_WARN, 'pick one on the Hardware page');
    TuiKit.PutText(48, row + 2, TuiKit.A_WARN, 'to change these.');
    Inc(row, 3);
  end;
  Inc(row);
  TuiKit.PutText(48, row, TuiKit.A_TEXT, 'Default  ' + CfgFile.StoredValue(defaults, opt));
  TuiKit.PutText(48, row + 1, TuiKit.A_TEXT, 'Key      ' + CfgFile.KeyName(opt));
end;

{ Setting opt on its row, highlighted when sel: its label, and its value (CfgFile.ShownValue), or a stepping line's two
  choices; all in TuiKit.A_OFF, and never highlighted, when it cannot be changed (Locked). }
procedure DrawSettingLine(opt: Byte; sel: Boolean);
var
  row: Byte;
  left: CfgFile.TName;
  right: CfgFile.TName;
  value: string;
  attr: Byte;
begin
  row := SettingRow(opt);
  TuiKit.PutRun(3, row, TuiKit.A_TEXT, ' ', 42);
  attr := TuiKit.A_TEXT;
  if Locked(opt) then
    attr := TuiKit.A_OFF;
  TuiKit.PutText(4, row, attr, CfgFile.SettingLabel(opts, opt));
  attr := TuiKit.A_VALUE;
  if SettingChanged(opt) then
    attr := TuiKit.A_CHANGED;
  if Locked(opt) then
    attr := TuiKit.A_OFF;
  if CfgFile.StepNames(opt, left, right) then
    value := left + ' ' + right
  else
    value := CfgFile.ShownValue(opts, opt, NoDevice);
  if SettingChanged(opt) then
    value := value + '*';
  TuiKit.PutText(28, row, attr, value);
  if sel and not Locked(opt) then begin
    TuiKit.Recolor(3, row, 42, TuiKit.A_HIGHLIGHT);
    if CfgFile.StepNames(opt, left, right) then
      if stepRight then
        TuiKit.Recolor(28, row, Length(left), TuiKit.A_HIGHLIGHT_OTHER)
      else
        TuiKit.Recolor(28 + Length(left) + 1, row, Length(right), TuiKit.A_HIGHLIGHT_OTHER);
  end;
end;

{ Settings page page (C_OPT.OPT_PAGE_GAME, OPT_PAGE_SOUND, OPT_PAGE_CAMP or OPT_PAGE_COMBAT): its settings, setting
  sel highlighted, each heading (CfgFile.Heading) above the setting it comes before. }
procedure DrawSettings(page, sel: Byte);
var
  opt: Byte;
begin
  ClearPage;
  case page of
    C_OPT.OPT_PAGE_SOUND: TuiKit.Box(2, 2, 45, 24, TuiKit.A_FRAME, 'Sound Settings (POOLOPT.CFG)');
    C_OPT.OPT_PAGE_CAMP: TuiKit.Box(2, 2, 45, 24, TuiKit.A_FRAME, 'Camp Settings (POOLOPT.CFG)');
    C_OPT.OPT_PAGE_COMBAT: TuiKit.Box(2, 2, 45, 24, TuiKit.A_FRAME, 'Combat Settings (POOLOPT.CFG)');
  else
    TuiKit.Box(2, 2, 45, 24, TuiKit.A_FRAME, 'Game Settings (POOLOPT.CFG)');
  end;
  TuiKit.Box(46, 2, 79, 24, TuiKit.A_FRAME, 'About');
  for opt := 1 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) = page then
      DrawSettingLine(opt, opt = sel);
  for opt := 1 to C_OPT.OPT_COUNT do
    if (CfgFile.SettingPage(opt) = page) and (CfgFile.Heading(opt) <> '') then
      TuiKit.PutText(4, SettingRow(opt) - 1, TuiKit.A_FRAME, CfgFile.Heading(opt));
  DrawAbout(sel);
  TuiKit.KeyLine('~Up Dn~ Move  ~Lt Rt~ Change  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save and Exit');
end;

{ Settings page page (POOLOPT.CFG's settings, as the game's Settings screen lists them) until Escape, or F10 saves
  and leaves. A setting that cannot be changed (Locked) is passed by; when they all are, the keys change nothing. }
procedure SettingsPage(page: Byte);
var
  sel: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
  left: CfgFile.TName;
  right: CfgFile.TName;
  stepping: Boolean;
  { the other page's settings, and those that cannot be changed (Locked), which the arrows pass by }
  other: CfgFile.TOptSet;
  first: Byte;
  last: Byte;
  opt: Byte;
begin
  other := [];
  first := 0;
  last := 0;
  for opt := 1 to C_OPT.OPT_COUNT do
    if (CfgFile.SettingPage(opt) <> page) or Locked(opt) then
      other := other + [opt]
    else begin
      if first = 0 then
        first := opt;
      last := opt;
    end;
  { a page with nothing to change keeps its first line for the About box }
  if first = 0 then
    for opt := C_OPT.OPT_COUNT downto 1 do
      if CfgFile.SettingPage(opt) = page then
        first := opt;
  if last = 0 then
    last := first;
  sel := first;
  stepRight := False;
  DrawSettings(page, sel);
  done := False;
  repeat
    TuiKit.GetKey(ch, ext);
    stepping := CfgFile.StepNames(sel, left, right);
    if Locked(sel) and ((ext and (ch <> C_KEYS.F10)) or (ch in [' ', C_KEYS.ENTER])) then
      ch := C_KEYS.NONE;
    if ext then
      case ch of
        C_KEYS.UP: sel := CfgFile.NextSetting(sel, False, other);
        C_KEYS.DOWN: sel := CfgFile.NextSetting(sel, True, other);
        C_KEYS.HOME: sel := first;
        C_KEYS.END_KEY: sel := last;
        C_KEYS.LEFT, C_KEYS.RIGHT: if stepping then
                                     stepRight := ch = C_KEYS.RIGHT
                                   else
                                     CfgFile.ChangeSetting(opts, sel, False);
        C_KEYS.F5: case sel of
                     C_OPT.OPT_SPEED: opts.speed := defaults.speed;
                     C_OPT.OPT_LOG_LINES: opts.logLines := defaults.logLines;
                   else
                     CfgFile.SetFlag(opts, sel, CfgFile.Flag(defaults, sel));
                   end;
        C_KEYS.F10: begin
                      SaveAndLeave;
                      done := leave;
                    end;
      end
    else
      case ch of
        ' ', C_KEYS.ENTER: CfgFile.ChangeSetting(opts, sel, stepRight);
        C_KEYS.ESCAPE: done := True;
      end;
    if not done then
      DrawSettings(page, sel);
  until done;
end;

{ --- starting ---------------------------------------------------------------------------------------------------- }

{ POOL.CFG's path line, normalized as START would: too long for DOS, kept as it is and marked (SetPath). Under DOS in
  capitals, as CheckPath gives a path typed in, so the same folder typed again is no change. }
procedure NormalizeRead(line: Byte);
var
  full: string;
  ok: Boolean;
begin
  ok := CfgFile.NormalizePath(PathOf(cfg, line), full);
{$IFNDEF FPC}
  full := CfgFile.Tidy(full);
{$ENDIF}
  SetPath(line, full);
end;

{ Read POOL.CFG (or start from the defaults without it) and then POOLOPT.CFG from the save folder it names. }
procedure ReadFiles;
var
  ok: Boolean;
begin
{$IFDEF FPC}
  { POOL.CFG in the writable folder, or until one is written there the data folder's (#1064) }
  ok := CfgFile.NormalizePath(GameDirs.writeFolder, homeDir);
  ok := CfgFile.NormalizePath(GameDirs.dataFolder, dataHome);
  if GameDirs.dataFolder = '' then
    dataHome := '';
  cfgName := GameDirs.writeFolder + C_OPT.CFG_NAME;
  cfgState := CfgFile.ReadPoolCfg(GameDirs.ReadName(C_OPT.CFG_NAME), cfg, notes);
{$ELSE}
  ok := CfgFile.NormalizePath('', homeDir);
  cfgName := FExpand(C_OPT.CFG_NAME);
  cfgState := CfgFile.ReadPoolCfg(C_OPT.CFG_NAME, cfg, notes);
{$ENDIF}
  CfgFile.PoolDefaults(cfgDefaults, homeDir);
  if cfgState in [CfgFile.CFG_MISSING, CfgFile.CFG_UNREADABLE] then
    cfg := cfgDefaults;
  { the defaults too, which in a folder too deep for DOS START would refuse }
  NormalizeRead(HW_DATA);
  NormalizeRead(HW_SAVE);
{$IFDEF FPC}
  { the folders as the native game takes them (GameBoot.NativeFolders) }
  SetPath(HW_SAVE, CfgFile.NativeSaveFolder(cfg.dataDir, cfg.saveDir, homeDir));
  SetPath(HW_DATA, dataHome);
{$ENDIF}
  cfgRead := cfg;
  optDir := cfg.saveDir;
  CfgFile.Defaults(defaults);
  opts := defaults;
  optState := CfgFile.ReadOptions(optDir, opts, optBad);
  optsRead := opts;
end;

{ The notice for a POOL.CFG that is missing, could not be read, or holds values START does not know. When START ran
  Setup for a damaged one, the notice starts by saying why. }
procedure ShowNotice;
const
  WHAT: array[1..C_OPT.CFG_LINES] of string[11] = ('video', 'sound', 'data path', 'save path', 'intro');
var
  lines: TuiKit.TLines;
  i: Byte;
  raw: string;
  reads: string;
begin
  TuiKit.ClearLines(lines);
  if fromStart and (cfgState in [CfgFile.CFG_UNREADABLE, CfgFile.CFG_FIXED]) then begin
    TuiKit.AddLine(lines, 'POOL.CFG was damaged, unreadable, or unparseable.', TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, 'Please reconfigure the game.', TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, '', 0);
  end;
  case cfgState of
    CfgFile.CFG_MISSING: begin
                           TuiKit.AddLine(lines, 'POOL.CFG was not found in ' + CutPath(homeDir, 30) + '.', 0);
                           TuiKit.AddLine(lines, '', 0);
{$IFDEF FPC}
                           TuiKit.AddLine(lines, 'Setup starts from the defaults: VGA, Digital Audio, the full',
                                          0);
{$ELSE}
                           TuiKit.AddLine(lines, 'Setup starts from the defaults: VGA, no sound, the full', 0);
{$ENDIF}
                           TuiKit.AddLine(lines, 'introduction, the data in this folder and the saves in', 0);
                           TuiKit.AddLine(lines, 'SAVE\ under it. Nothing is written until you save.', 0);
                         end;
    CfgFile.CFG_UNREADABLE: begin
                              TuiKit.AddLine(lines, 'POOL.CFG is in ' + CutPath(homeDir, 30) + ',', 0);
                              TuiKit.AddLine(lines, 'but it could not be read.', 0);
                              TuiKit.AddLine(lines, '', 0);
                              TuiKit.AddLine(lines, 'Setup shows the defaults, and will not write over a', 0);
                              TuiKit.AddLine(lines, 'file it could not read.', 0);
                            end;
    CfgFile.CFG_FIXED: begin
                         TuiKit.AddLine(lines, 'POOL.CFG holds values ' + GAME_PROG + ' does not know:', 0);
                         TuiKit.AddLine(lines, '', 0);
                         for i := 1 to notes.count do begin
                           if notes.items[i].missing then
                             raw := 'missing'
                           else
                             raw := '''' + notes.items[i].raw + '''';
                           case notes.items[i].line of
                             1: reads := GAME_PROG + ' reads it as ' + ChoiceName(HW_VIDEO, ChoiceOf(cfg, HW_VIDEO));
                             2: reads := GAME_PROG + ' reads it as none';
                             5: reads := GAME_PROG + ' reads it as short';
                           else
                             reads := GAME_PROG + ' uses this folder';
                           end;
                           TuiKit.AddLine(lines, '  ' + StrUtil.PadRight('Line ' + StrUtil.NumStr(notes.items[i].line) +
                                          ' (' + WHAT[notes.items[i].line] + ')', 21) + StrUtil.PadRight(raw, 15) +
                                          reads, TuiKit.A_POP_VALUE);
                         end;
                         TuiKit.AddLine(lines, '', 0);
                         TuiKit.AddLine(lines, 'Setup shows what ' + GAME_PROG + ' would use. Saving writes the', 0);
                         TuiKit.AddLine(lines, 'file back in the form ' + GAME_PROG + ' expects.', 0);
                       end;
  else
    Exit;
  end;
  ClearPage;
  TuiKit.KeyLine('Press any key');
  TuiKit.Message('Notice', lines, TuiKit.STYLE_NOTICE, 64);
end;

{ Leave by Escape: with changes, ask first whether to save them (Yes saves and leaves, No leaves with exit code 1,
  Cancel stays). }
procedure AskToLeave;
begin
  if not Unsaved then begin
    exitCode := 0;
    leave := True;
    Exit;
  end;
  TuiKit.KeyLine('~Lt Rt~ Move  ~Enter~ Choose  ~Y~ Yes  ~N~ No  ~Esc~ Cancel');
  case TuiKit.Ask('Exit', 'Save the changes before leaving?') of
    'Y': SaveAndLeave;
    'N': begin
           exitCode := 1;
           leave := True;
         end;
  end;
end;

{$IFDEF FPC}
{ The game's folders, as the game finds them (GameDirs.Settle) but without asking: of several copies the first, and
  with none no data folder and the player's own folder to write in. }
procedure FindFolders;
var
  hits: GameDirs.TCandidates;
  ask: Boolean;
begin
  if GameDirs.Settle(GameDirs.POOL, hits, ask) then Exit;
  if Length(hits) > 0 then
    GameDirs.Place(GameDirs.POOL, hits[0].path, False)
  else begin
    GameDirs.writeFolder := GameDirs.UserFolder(GameDirs.POOL, GameDirs.THIS_OS, GetUserDir);
    ForceDirectories(GameDirs.writeFolder);
  end;
end;
{$ENDIF}

{ The Main Menu until the program leaves. }
procedure MainMenu;
var
  sel: Byte;
  ch: Char;
  ext: Boolean;
  item: Byte;
begin
  sel := ITEM_HARDWARE;
  repeat
    DrawMain(sel);
    TuiKit.GetKey(ch, ext);
    item := 0;
    if ext then begin
      TuiKit.MoveInList(ch, sel, ITEMS);
      if ch = C_KEYS.F10 then
        item := ITEM_SAVE;
    end else
      case UpCase(ch) of
        C_KEYS.ENTER: item := sel;
        'H': item := ITEM_HARDWARE;
        'G': item := ITEM_SETTINGS;
        'O': item := ITEM_SOUND;
        'C': item := ITEM_CAMP;
        'M': item := ITEM_COMBAT;
        'S': item := ITEM_SAVE;
        'X': item := ITEM_QUIT;
        C_KEYS.ESCAPE: AskToLeave;
      end;
    if item <> 0 then
      sel := item;
    case item of
      ITEM_HARDWARE: HardwarePage;
      ITEM_SETTINGS: SettingsPage(C_OPT.OPT_PAGE_GAME);
      ITEM_SOUND: SettingsPage(C_OPT.OPT_PAGE_SOUND);
      ITEM_CAMP: SettingsPage(C_OPT.OPT_PAGE_CAMP);
      ITEM_COMBAT: SettingsPage(C_OPT.OPT_PAGE_COMBAT);
      ITEM_SAVE: SaveAndLeave;
      ITEM_QUIT: begin
                   exitCode := Ord(Unsaved);
                   leave := True;
                 end;
    end;
  until leave;
end;

begin
{$IFDEF FPC}
  { double-clicked, with no terminal: run again in one (#1098) }
  OwnTerm.Start;
  FindFolders;
{$ENDIF}
  fromStart := ParamStr(1) = C_OPT.SETUP_FROM_START;
  exitCode := 0;
  leave := False;
  TuiKit.Init;
  ReadFiles;
  ShowNotice;
  MainMenu;
  TuiKit.Done;
  Halt(exitCode);
end.
