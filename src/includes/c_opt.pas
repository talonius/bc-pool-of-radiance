{ Shared constants for POOL.CFG and POOLOPT.CFG (#876). The game and POOLCFG
  both use these values through CfgFile. }
{$I COMPILER.INC}
unit C_OPT;

interface

const
  { the files: POOL.CFG in the game's folder, POOLOPT.CFG in the save folder, and the program that writes them }
  CFG_NAME = 'POOL.CFG';
  OPT_NAME = 'POOLOPT.CFG';
  SETUP_NAME = 'POOLCFG.EXE';
  { the switch START runs the set-up program with, so it says why it came up and leaves to DOS unsaved }
  SETUP_FROM_START = '/START';
  { POOL.CFG's first line, the video: CGA, EGA, Tandy or VGA; START reads any other letter as CGA }
  VIDEO_CGA = 'C';
  VIDEO_EGA = 'E';
  VIDEO_TANDY = 'T';
  VIDEO_VGA = 'V';
  { VGA at 640 x 400 through VESA (#1231), a prototype: the 320 x 200 art drawn 2 x 2, and some text at the screen's own
    pixels }
  VIDEO_VESA = 'H';
  { POOL.CFG's second line, the sound device. S is silent, as SSI's data card and the Curse port have it, and B the
    Sound Blaster (#880); START reads any other letter as silent, N included. }
  SOUND_SILENT = 'S';
  SOUND_NONE = 'N';
  SOUND_SPEAKER = 'P';
  SOUND_TANDY = 'T';
  SOUND_ADLIB = 'A';
  SOUND_BLASTER = 'B';
  { POOL.CFG's fifth line: the full introduction, or (any other letter) the short one }
  INTRO_FULL = 'F';
  INTRO_SHORT = 'N';
  { POOL.CFG's lines: video, sound, data path, save path, introduction }
  CFG_LINES = 5;
  { the most lines after the fifth that a POOL.CFG read keeps, for a write to put back }
  CFG_EXTRA_LINES = 4;
  { the longest file name the game appends to a path (WALLDEF1.DAX), and the folders a file's temporary copy and
    backup are written in beside it (FileUtil.BACKUP_FOLDER, TMP\BAK\, #1084), and so the longest path START takes: a
    path, those folders and that name fit a DOS path of 79 characters }
  LONGEST_NAME = 12;
  WORK_FOLDERS = 8;
{$IFDEF FPC}
  MAX_PATH_TEXT = 255 - LONGEST_NAME - WORK_FOLDERS;
{$ELSE}
  MAX_PATH_TEXT = 79 - LONGEST_NAME - WORK_FOLDERS;
{$ENDIF}
  { the most lines read from POOLOPT.CFG; anything after them is ignored, and dropped when the file is written }
  MAX_LINES = 100;
  { The settings, numbered page by page in the Settings screen's order (#1180): the Game page's (1 to OPT_LAST_GAME),
    the Sound page's (OPT_FIRST_SOUND to OPT_LAST_SOUND), the Camp page's (OPT_FIRST_CAMP to OPT_LAST_CAMP) and the
    Combat page's (OPT_FIRST_COMBAT to OPT_LAST_COMBAT, which is OPT_COUNT). The sub-settings follow the setting or
    heading (CfgFile.Heading) they come under. The speed stays first and the log lines last, so the ON/OFF settings
    are the ones between; POOLOPT.CFG goes by key name, so renumbering leaves its files as they were. }
  OPT_SPEED = 1;
  OPT_PORTRAITS_ALL = 2;
  OPT_MONSTERS = 3;
  OPT_PORTRAITS = 4;
  { a stackable item joins its like as it is bought, taken or traded (#1088) }
  OPT_AUTO_JOIN = 5;
  { a character's purse is changed into the fewest coins of the same value whenever it picks coins up (#1179) }
  OPT_CONSOLIDATE = 6;
  { the Journal lists only what the party has found (ON, shown as FOUND) or every item (OFF, shown as ALL) (#1090) }
  OPT_JOURNAL = 7;
  { the racial level limits of dwarves, elves, gnomes, half-elves, halflings and half-orcs apply (ON), or they train as
    far as the experience table goes, as humans do (OFF) (#1176) }
  OPT_NONHUMAN_CAP = 8;
  { each class stops at the level SSI's game stopped it (ON), or every class trains to 9 (OFF) (#1121) }
  OPT_LEVEL_CAP = 9;
  { F4 opens the training hall's menu anywhere outside combat, its rules and fee kept (#1212) }
  OPT_TRAIN_ANYWHERE = 10;
  OPT_COMPANION = 11;
  OPT_CLUES = 12;
  OPT_LAST_GAME = OPT_CLUES;
  { the Sound page's: the music, then the sound effects }
  OPT_MUSIC = 13;
  OPT_TITLE_MUSIC = 14;
  OPT_BATTLE_MUSIC = 15;
  OPT_SOUND = 16;
  OPT_FOOTSTEPS = 17;
  OPT_RANGED = 18;
  OPT_MELEE = 19;
  OPT_DEATH = 20;
  OPT_WALL = 21;
  OPT_SPELLS = 22;
  OPT_FIRST_SOUND = OPT_MUSIC;
  OPT_LAST_SOUND = OPT_SPELLS;
  { the Camp page's: Rest memorizes each caster's usual spells when none is pending (#1119), and under the Fix heading
    (#1129) what Fix may use besides the clerics' spells: scrolls, potions, and a paladin's weekly cure and daily laying
    on of hands }
  OPT_AUTO_MEMORIZE = 23;
  OPT_FIX_SCROLLS = 24;
  OPT_FIX_POTIONS = 25;
  OPT_FIX_CURE = 26;
  OPT_FIX_HEAL = 27;
  OPT_FIRST_CAMP = OPT_AUTO_MEMORIZE;
  OPT_LAST_CAMP = OPT_FIX_HEAL;
  { the Combat page's (#1180): first, under the Quick Mode heading, Auto End Quick Mode, Use Magic and Allow Gear
    Changes, with which quick mode re-equips the party's weapons and shields (#1127) }
  OPT_QUICK = 28;
  OPT_MAGIC = 29;
  OPT_GEAR = 30;
  { the aim menu's Next and Prev reach one side only, ENEMIES, or every creature, ALL (#1137) }
  OPT_AIM = 31;
  { a single thrown weapon goes back to its thrower after the fight (#1118) }
  OPT_RETRIEVE = 32;
  { the whole arena as a small map in the combat panel, which F3 turns over in combat (#1210) }
  OPT_MINIMAP = 33;
  { the full-width combat view, the creature and the messages on three lines under it (#1211) }
  OPT_WIDE_COMBAT = 34;
  { the combat log (#841), and how many messages it keeps }
  OPT_COMBAT_LOG = 35;
  OPT_LOG_LINES = 36;
  OPT_FIRST_COMBAT = OPT_QUICK;
  OPT_LAST_COMBAT = OPT_LOG_LINES;
  OPT_COUNT = 36;
  { the pages the settings are shown on (CfgFile.SettingPage), in the order the game's Settings screen and POOLCFG
    offer them }
  OPT_PAGE_GAME = 1;
  OPT_PAGE_SOUND = 2;
  OPT_PAGE_CAMP = 3;
  OPT_PAGE_COMBAT = 4;
  OPT_PAGES = 4;
  { the settings that are ON or OFF }
  OPT_FIRST_FLAG = OPT_PORTRAITS_ALL;
  OPT_LAST_FLAG = OPT_COMBAT_LOG;
  { POOLOPT.CFG's key past the settings: the last version the startup advisory's support part was shown for (#1173),
    which Advisory shows again when this is not the build's own. The later games' paths that came before it (CURSEDATA
    to POOLSSAVE) are gone (#1177): a file that still has them keeps them as lines this version does not know. }
  KEY_ADVISED = OPT_COUNT + 1;
  KEY_COUNT = KEY_ADVISED;
  { the game speed: 0 the fastest, SLOWEST the slowest, and the default }
  SLOWEST = 9;
  SPEED_DEFAULT = 1;
  { Log Lines: the fewest and most messages the combat log keeps, the default, and the Settings screen's step }
  LOG_MIN = 10;
  LOG_MAX = 60;
  LOG_DEFAULT = 50;
  LOG_STEP = 5;

implementation

end.
