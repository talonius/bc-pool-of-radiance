{ Initialized data that several units share; a table only one unit reads lives in that unit, in the routine that reads
  it when there is only one. A new section starts wherever the data needs a word boundary. }
{$I COMPILER.INC}
unit GameDefs;

interface

uses C_GENDER, C_CLASS, C_LEVEL, C_MONEY, Types, Crt, C_EFFECT, C_DIR, C_RACE, C_STATUS, C_ALIGN, C_STAT, C_SPELL,
  C_TERR;

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  GAME_VERSION: String[40] = BUILD_VERSION + ' (BC)';

const
  { The monsters Charm Person and Hold Person affect, as the 1st-edition list names them (#792): rangerFoes' first
    RANGER_PERSONS (kobolds, goblins, orcs, hobgoblins and the gnoll) and these. CharHlp.IsPerson }
  RANGER_PERSONS = 9;
  { The giant class a ranger does extra damage to in melee: the game's monster names for kobolds, goblins, orcs,
    hobgoblins, gnolls, bugbears, ettins, ogres, trolls and giants. The first RANGER_PERSONS are persons. }
  rangerFoes: array[1..16] of Types.TName15 = (
    'KOBOLD', 'KOBOLD LEADER', 'GOBLIN GUARD', 'GOBLIN LEADER', 'ORC', 'ORC LEADER', 'HOBGOBLIN', 'HOBGOBLIN LDR',
    'GNOLL', 'BUGBEAR', 'ETTIN', 'OGRE', 'OGRE LEADER', 'TROLL', 'HILL GIANT', 'FIRE GIANT');

const
  { Training-hall class bits (C_GBVM.TRAIN_CLASS_MASK) by class slot. Paladins and rangers train with fighters; the
    monk combines two bits. }
  classBits: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of Byte = (
    2, 2, 8, 8, 8, 1, 4, 6);

const
  { RollFirstLevelHp }
  { hit-die sides per class }
  hpSides: array[0..7] of Byte = (
    { Cleric: d8 }
    8,
    { Druid: d8 }
    8,
    { Fighter: d10 }
    10,
    { Paladin: d10 }
    10,
    { Ranger: d8 }
    8,
    { Magic-User: d4 }
    4,
    { Thief: d6 }
    6,
    { Monk: d4 }
    4);

const
  { Solid fill bytes for FillPicRect. Packed fill byte for each mapped CGA color (0..3), indexed by SrcNibble(color,
    map): four identical 2-bit pixels. }
  cgaColorFill: array[0..3] of Byte = ($00, $55, $AA, $FF);
  { Character and money names }
  { Coin values in copper: copper 1, silver 10, electrum 100, gold 200, platinum 1000. }
  coinValues: array[C_MONEY.COPPER..C_MONEY.PLATINUM] of LongInt = (
    1, 10, 100, 200, 1000);
  { Class names, indexed by TCharRecord.charClass. }
  classNames: array[C_CLASS.CLERIC..C_CLASS.MAGE_THIEF] of string[25] = (
    'Cleric',
    'Druid',
    'Fighter',
    'Paladin',
    'Ranger',
    'Magic-User',
    'Thief',
    'Monk',
    'Cleric/Fighter',
    'Cleric/Fighter/Magic-User',
    'Cleric/Ranger',
    'Cleric/Magic-User',
    'Cleric/Thief',
    'Fighter/Magic-User',
    'Fighter/Thief',
    'Fighter/Magic-User/Thief',
    'Magic-User/Thief');
  { The abilities' three-letter labels, indexed like TCharRecord.stats (C_STAT): the character sheet's, the race
    screen's and the Dual Class screen's. }
  abilityNames: array[C_STAT.STRENGTH..C_STAT.CHARISMA] of string[3] = ('STR', 'INT', 'WIS', 'DEX', 'CON', 'CHA');
  { Race names, indexed by TCharRecord.race. }
  raceNames: array[C_RACE.MONSTER..C_RACE.HUMAN] of string[8] = (
    'Monster',
    'Dwarf',
    'Elf',
    'Gnome',
    'Half-Elf',
    'Halfling',
    'Half-Orc',
    'Human');
  { Alignment names, indexed by TCharRecord.alignment. }
  alignNames: array[C_ALIGN.LAWFUL_GOOD..C_ALIGN.CHAOTIC_EVIL] of string[15] = (
    'Lawful Good',
    'Lawful Neutral',
    'Lawful Evil',
    'Neutral Good',
    'True Neutral',
    'Neutral Evil',
    'Chaotic Good',
    'Chaotic Neutral',
    'Chaotic Evil');
  { Gender names, indexed by TCharRecord.gender. }
  genderNames: array[C_GENDER.MALE..C_GENDER.FEMALE] of string[6] = (
    'Male',
    'Female');
  { Money names, indexed like TCharRecord.coins and TMoney. }
  moneyNames: array[C_MONEY.COPPER..C_MONEY.JEWELRY] of string[8] = (
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Gems',
    'Jewelry');
  { Status names, indexed by TCharRecord.status; see C_STATUS. }
  statusNames: array[C_STATUS.OKAY..C_STATUS.GONE] of string[11] = (
    'Okay',
    'Animated',
    'tempgone',
    'Running',
    'Unconscious',
    'Dying',
    'Dead',
    'Stoned',
    'Gone');

const
  { Text-mode colour and pixel tables; EGA plane and CGA pixel tables; icon colour map }
  { EGA-to-CGA font color map. }
  attrTable: array[0..15] of Byte = (
    { EGA 0 Black -> CGA colour 0 }
    0,
    { EGA 1 Blue -> CGA colour 0 }
    0,
    { EGA 2 Green -> CGA colour 0 }
    0,
    { EGA 3 Cyan -> CGA colour 1 }
    1,
    { EGA 4 Red -> CGA colour 2 }
    2,
    { EGA 5 Magenta -> CGA colour 2 }
    2,
    { EGA 6 Brown -> CGA colour 2 }
    2,
    { EGA 7 LightGray -> CGA colour 3 }
    3,
    { EGA 8 DarkGray -> CGA colour 3 }
    3,
    { EGA 9 LightBlue -> CGA colour 1 }
    1,
    { EGA 10 LightGreen -> CGA colour 1 }
    1,
    { EGA 11 LightCyan -> CGA colour 1 }
    1,
    { EGA 12 LightRed -> CGA colour 2 }
    2,
    { EGA 13 LightMagenta -> CGA colour 2 }
    2,
    { EGA 14 Yellow -> CGA colour 3 }
    3,
    { EGA 15 White -> CGA colour 3 }
    3);
  { One mask per 2-bit pixel position within a CGA pixel word, high pair first. Blit uses them to isolate, place and
    reflect CGA pixels; TextRend.RenderChar uses them to draw characters. }
  cgaPixelMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003);

const
  { Color bit (1, 2, 4, 8) carried by each of the four EGA planes. Blit uses it to split a 4-bit color into plane bytes
    and to select planes through the sequencer map mask. }
  egaPlaneBit: array[0..3] of Byte = ($01, $02, $04, $08);
  { Packed EGA-to-CGA color map, two EGA colors per byte, used by Blit.FillPicRect for the CharGen icon previews and the
    View3D backgrounds }
  iconColorMap: Types.TColorMap = (
    { EGA 0 Black -> CGA 0; EGA 1 Blue -> CGA 0 }
    $00,
    { EGA 2 Green -> CGA 1; EGA 3 Cyan -> CGA 1 }
    $11,
    { EGA 4 Red -> CGA 2; EGA 5 Magenta -> CGA 2 }
    $22,
    { EGA 6 Brown -> CGA 1; EGA 7 LightGray -> CGA 2 }
    $12,
    { EGA 8 DarkGray -> CGA 0; EGA 9 LightBlue -> CGA 0 }
    $00,
    { EGA 10 LightGreen -> CGA 2; EGA 11 LightCyan -> CGA 1 }
    $21,
    { EGA 12 LightRed -> CGA 3; EGA 13 LightMagenta -> CGA 0 }
    $30,
    { EGA 14 Yellow -> CGA 3; EGA 15 White -> CGA 3 }
    $33);
  { Every color, in palette order: the source side of Blit.RemapPic's remaps. }
  colorIdentity: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    LightMagenta,
    Yellow,
    White);
  { Every color but LightMagenta, which becomes Black: the transparent sprite color made black (MapTiles' ICON frames,
    Portrait's animations). }
  colorPinkToBlack: Types.TColorTab = (
    Black,
    Blue,
    Green,
    Cyan,
    Red,
    Magenta,
    Brown,
    LightGray,
    DarkGray,
    LightBlue,
    LightGreen,
    LightCyan,
    LightRed,
    Black,
    Yellow,
    White);
  { Sound command tables }
  { One table of sound command ids, a slice for each subsystem (C_SOUND names the indexes). }
  soundIds: record
    commands: array[0..3] of Word;
    damage: Word;
    combat: array[0..10] of Word;
  end = (
    commands: (255, 0, 1, 2);
    damage: 3;
    combat: (4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14));
  { The first symbol of each 8x8 symbol set; set 4 ends at 286, and set 5, the scroll bar's cells (Sym8x8.BAR_FIRST),
    at 294 }
  symSetFirst: array[0..5] of Word = (1, 46, 116, 186, 256, 287);
  { Direction steps, combat terrain, icon footprints, helpless effects }
  dirDX: array[C_DIR.NORTH..C_DIR.CENTER] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0);
  dirDY: array[C_DIR.NORTH..C_DIR.CENTER] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0);
  { Combat terrain by arena cell value: movement cost (255 = impassable), what it blocks of a line walk, and the combat
    tile graphic; 66, Cloudkill's cloud (C_TERR.CLOUDKILL), names the stinking cloud's tile, drawn recoloured
    (CbtMap.DrawTerrain) }
  terrainInfo: array[1..C_TERR.CLOUDKILL] of Types.TTerrainRec = (
    (cost: 255; blocking: 2; tileId: 0),
    (cost: 255; blocking: 2; tileId: 1),
    (cost: 255; blocking: 2; tileId: 2),
    (cost: 255; blocking: 2; tileId: 3),
    (cost: 1; blocking: 0; tileId: 4),
    (cost: 255; blocking: 2; tileId: 5),
    (cost: 255; blocking: 2; tileId: 6),
    (cost: 255; blocking: 2; tileId: 7),
    (cost: 1; blocking: 0; tileId: 8),
    (cost: 255; blocking: 2; tileId: 9),
    (cost: 1; blocking: 0; tileId: 10),
    (cost: 255; blocking: 2; tileId: 11),
    (cost: 1; blocking: 0; tileId: 12),
    (cost: 255; blocking: 2; tileId: 13),
    (cost: 1; blocking: 0; tileId: 14),
    (cost: 255; blocking: 2; tileId: 15),
    (cost: 1; blocking: 0; tileId: 16),
    (cost: 255; blocking: 2; tileId: 17),
    (cost: 255; blocking: 2; tileId: 18),
    (cost: 255; blocking: 2; tileId: 19),
    (cost: 255; blocking: 2; tileId: 20),
    (cost: 255; blocking: 2; tileId: 21),
    (cost: 1; blocking: 0; tileId: 22),
    (cost: 1; blocking: 0; tileId: 23),
    (cost: 255; blocking: 2; tileId: 24),
    (cost: 1; blocking: 0; tileId: 34),
    (cost: 1; blocking: 0; tileId: 35),
    (cost: 1; blocking: 0; tileId: 36),
    (cost: 1; blocking: 0; tileId: 37),
    (cost: 1; blocking: 0; tileId: 38),
    (cost: 1; blocking: 0; tileId: 39),
    (cost: 255; blocking: 2; tileId: 0),
    (cost: 255; blocking: 2; tileId: 1),
    (cost: 255; blocking: 2; tileId: 2),
    (cost: 255; blocking: 2; tileId: 3),
    (cost: 1; blocking: 0; tileId: 4),
    (cost: 1; blocking: 0; tileId: 5),
    (cost: 1; blocking: 0; tileId: 6),
    (cost: 1; blocking: 0; tileId: 7),
    (cost: 255; blocking: 0; tileId: 8),
    (cost: 255; blocking: 0; tileId: 9),
    (cost: 1; blocking: 0; tileId: 10),
    (cost: 1; blocking: 0; tileId: 11),
    (cost: 1; blocking: 0; tileId: 12),
    (cost: 1; blocking: 0; tileId: 13),
    (cost: 1; blocking: 0; tileId: 14),
    (cost: 1; blocking: 0; tileId: 15),
    (cost: 1; blocking: 0; tileId: 16),
    (cost: 1; blocking: 0; tileId: 17),
    (cost: 255; blocking: 0; tileId: 18),
    (cost: 255; blocking: 0; tileId: 19),
    (cost: 1; blocking: 0; tileId: 20),
    (cost: 1; blocking: 0; tileId: 21),
    (cost: 1; blocking: 0; tileId: 22),
    (cost: 255; blocking: 0; tileId: 23),
    (cost: 255; blocking: 0; tileId: 24),
    (cost: 1; blocking: 0; tileId: 25),
    (cost: 1; blocking: 0; tileId: 26),
    (cost: 1; blocking: 0; tileId: 27),
    (cost: 255; blocking: 0; tileId: 28),
    (cost: 255; blocking: 2; tileId: 29),
    (cost: 255; blocking: 2; tileId: 30),
    (cost: 255; blocking: 2; tileId: 31),
    (cost: 1; blocking: 0; tileId: 32),
    (cost: 255; blocking: 2; tileId: 33),
    (cost: 1; blocking: 0; tileId: 38));
  { Effects that leave a creature helpless }
  HELPLESS_FX_COUNT = 4;
  helplessFx: array[1..HELPLESS_FX_COUNT] of Byte = (C_EFFECT.SNAKE_CHARM, C_EFFECT.PARALYZED, C_EFFECT.SLEEP,
    C_EFFECT.HELPLESS);
  { Portrait head and body tables }
  { portraitHead -> HEAD DAX ID: SSI's 14 player heads, then the other heads HEAD3.DAX holds, then the heads only the
    other disks hold. New heads go at the end so the numbers saved characters carry keep their faces. }
  headTbl: array[1..41] of Byte = (
     0,  8,  9, 13, 16, 18, 22,
    34, 45, 51, 53, 57, 67, 68,
    24, 32, 42, 44, 55, 63, 71,
     1,  3,  5,  6, 10, 11, 12,
    14, 25, 48, 52, 54, 56, 59,
    61, 62, 69, 70, 72, 74
  );
  { portraitBody -> BODY DAX ID, extended the same way }
  bodyTbl: array[1..21] of Byte = (
     1,  2,  3,  4,  7,  8, 18,
    24, 26, 33, 35, 37,  9, 31,
    32, 34,  5,  6, 13, 25, 30
  );
  { Cloud directions, spell names and spell table }
  { Stinking Cloud's cells as directions from its aim cell, the block's upper left: center, E, SE, S }
  cloudDir: array[1..4] of Byte = (
    8, 2, 3, 4);
  { Cloudkill's cells as directions from its aim cell, the block's middle: center, then N round to NW (Curse's) }
  cloudkillDir: array[1..9] of Byte = (
    8, 0, 1, 2, 3, 4, 5, 6, 7);
  { spell IDs 1..C_SPELL.LAST: the item spells' 57 and 59..65 and the empty ids have no name }
  spellNames: array[1..C_SPELL.LAST] of string[32] = (
    'Bless',
    'Curse',
    'Cure Light Wounds',
    'Cause Light Wounds',
    'Detect Magic',
    'Protection From Evil',
    'Protection From Good',
    'Resist Cold',
    'Burning Hands',
    'Charm Person',
    'Detect Magic',
    'Enlarge',
    'Reduce',
    'Friends',
    'Magic Missile',
    'Protection From Evil',
    'Protection From Good',
    'Read Magic',
    'Shield',
    'Shocking Grasp',
    'Sleep',
    'Find Traps',
    'Hold Person',
    'Resist Fire',
    'Silence, 15'' Radius',
    'Slow Poison',
    'Snake Charm',
    'Spiritual Hammer',
    'Detect Invisibility',
    'Invisibility',
    'Knock',
    'Mirror Image',
    'Ray of Enfeeblement',
    'Stinking Cloud',
    'Strength',
    'Animate Dead',
    'Cure Blindness',
    'Cause Blindness',
    'Cure Disease',
    'Cause Disease',
    'Dispel Magic',
    'Prayer',
    'Remove Curse',
    'Bestow Curse',
    'Blink',
    'Dispel Magic',
    'Fireball',
    'Haste',
    'Hold Person',
    'Invisibility, 10'' Radius',
    'Lightning Bolt',
    'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius',
    'Protection From Normal Missiles',
    'Slow',
    'Restoration',
    '',
    'Cure Serious Wounds',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    'Cause Serious Wounds',
    'Neutralize Poison',
    'Poison',
    'Protection From Evil, 10'' Radius',
    'Sticks to Snakes',
    'Cure Critical Wounds',
    'Cause Critical Wounds',
    'Dispel Evil',
    'Flame Strike',
    'Raise Dead',
    'Slay Living',
    'Detect Magic',
    'Entangle',
    'Faerie Fire',
    'Invisibility to Animals',
    'Charm Monsters',
    'Confusion',
    'Dimension Door',
    'Fear',
    'Fire Shield',
    'Fumble',
    'Ice Storm',
    'Minor Globe of Invulnerability',
    'Remove Curse',
    'Animate Dead',
    'Cloudkill',
    'Cone of Cold',
    'Feeblemind',
    'Hold Monsters',
    '',
    '',
    '',
    '',
    '',
    'Bestow Curse');
  { IDs 57, 59..65 and 127..128 are item spells; 58, 66..90, 92..94 and 100 are the spells of levels 4 and 5 and the
    druid's first, from Curse's table with its castClass remapped (Curse's druid 1 and magic-user 2 are 2 and 1 here);
    95..99 and 101..126 hold no spell (#1121) }
  spellTable: array[1..C_SPELL.TABLE_LAST] of Types.TSpellRec = (
    { Spell 1: Bless }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 1; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 2: Curse }
    (castClass: 0; level: 1; rangeFixed: 6; rangeVar: 0;
     durFixed: 6; durVar: 0; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 2; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 3: Cure Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 4: Cause Light Wounds }
    (castClass: 0; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 5: Detect Magic }
    (castClass: 0; level: 1; rangeFixed: 3; rangeVar: 0;
     durFixed: 10; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 6: Protection From Evil }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 7: Protection From Good }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 3; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 4; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 8: Resist Cold }
    (castClass: 0; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 10; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 9: Burning Hands }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 10: Charm Person }
    (castClass: 1; level: 1; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 11; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 11: Detect Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 12: Enlarge }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 12; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 13: Reduce }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 2;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 1; saveType: 4; effect: 13; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 14: Friends }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 14; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 15: Magic Missile }
    (castClass: 1; level: 1; rangeFixed: 6; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 16: Protection From Evil }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 8; whenCast: 2;
     castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 17: Protection From Good }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 9; whenCast: 2;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 18: Read Magic }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 16; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 19: Shield }
    (castClass: 1; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 17; whenCast: 2;
     castTime: 1; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 20: Shocking Grasp }
    (castClass: 1; level: 1; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 21: Sleep }
    (castClass: 1; level: 1; rangeFixed: 3; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 9; target: 0;
     saveResult: 0; saveType: 4; effect: 53; whenCast: 1;
     castTime: 1; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 22: Find Traps }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 30; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 19; whenCast: 0;
     castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 23: Hold Person }
    (castClass: 0; level: 2; rangeFixed: 6; rangeVar: 0;
     durFixed: 4; durVar: 1; area: 6; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 24: Resist Fire }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 20; whenCast: 2;
     castTime: 5; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 25: Silence, 15' Radius }
    (castClass: 0; level: 2; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 31; target: 0;
     saveResult: 3; saveType: 4; effect: 21; whenCast: 1;
     castTime: 5; aiPriority: 4; offensive: 1; aiRadius: 1),
    { Spell 26: Slow Poison }
    (castClass: 0; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 22; whenCast: 2;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 27: Snake Charm }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 0;
     saveResult: 0; saveType: 4; effect: 51; whenCast: 1;
     castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 28: Spiritual Hammer }
    (castClass: 0; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 23; whenCast: 2;
     castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 29: Detect Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 4;
     durFixed: 0; durVar: 5; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 24; whenCast: 2;
     castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 30: Invisibility }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 31: Knock }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 32: Mirror Image }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 28; whenCast: 2;
     castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 33: Ray of Enfeeblement }
    (castClass: 1; level: 2; rangeFixed: 1; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 29; whenCast: 1;
     castTime: 2; aiPriority: 2; offensive: 1; aiRadius: 0),
    { Spell 34: Stinking Cloud }
    (castClass: 1; level: 2; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 0;
     saveResult: 3; saveType: 0; effect: 30; whenCast: 1;
     castTime: 2; aiPriority: 7; offensive: 1; aiRadius: 1),
    { Spell 35: Strength }
    (castClass: 1; level: 2; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 60; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 0;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 36: Animate Dead }
    (castClass: 0; level: 3; rangeFixed: 1; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 4;
     saveResult: 0; saveType: 4; effect: 32; whenCast: 2;
     castTime: 10; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 37: Cure Blindness }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 38: Cause Blindness }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 33; whenCast: 1;
     castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { Spell 39: Cure Disease }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 40: Cause Disease }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 34; whenCast: 1;
     castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 41: Dispel Magic }
    (castClass: 0; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 4; aiPriority: 5; offensive: 1; aiRadius: 1),
    { Spell 42: Prayer }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 49; whenCast: 2;
     castTime: 6; aiPriority: 6; offensive: 0; aiRadius: 0),
    { Spell 43: Remove Curse }
    (castClass: 0; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 44: Bestow Curse }
    (castClass: 0; level: 3; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 36; whenCast: 1;
     castTime: 6; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 45: Blink }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 37; whenCast: 1;
     castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 46: Dispel Magic }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 1; aiRadius: 1),
    { Spell 47: Fireball }
    (castClass: 1; level: 3; rangeFixed: 10; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 48: Haste }
    (castClass: 1; level: 3; rangeFixed: 6; rangeVar: 0;
     durFixed: 3; durVar: 1; area: 10; target: 4;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 49: Hold Person }
    (castClass: 1; level: 3; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 7; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 50: Invisibility, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 9; target: 4;
     saveResult: 0; saveType: 4; effect: 25; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 51: Lightning Bolt }
    (castClass: 1; level: 3; rangeFixed: 4; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 8; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 52: Protection From Evil, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 45; whenCast: 2;
     castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 53: Protection From Good, 10' Radius }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 46; whenCast: 2;
     castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 54: Protection From Normal Missiles }
    (castClass: 1; level: 3; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 41; whenCast: 2;
     castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 55: Slow }
    (castClass: 1; level: 3; rangeFixed: 9; rangeVar: 1;
     durFixed: 3; durVar: 1; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 42; whenCast: 1;
     castTime: 3; aiPriority: 5; offensive: 1; aiRadius: 0),
    { Spell 56: Restoration }
    (castClass: 0; level: 7; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 57 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 58: Cure Serious Wounds }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 7; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 59 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 38; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 60 }
    (castClass: 3; level: 6; rangeFixed: 4; rangeVar: 4;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 61 }
    (castClass: 3; level: 6; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 0; effect: 52; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 62 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 39; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 63 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 7; target: 4;
     saveResult: 0; saveType: 4; effect: 71; whenCast: 2;
     castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 64 }
    (castClass: 3; level: 6; rangeFixed: 7; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 11; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 65 }
    (castClass: 3; level: 6; rangeFixed: 12; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 66: Cause Serious Wounds }
    (castClass: 0; level: 4; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 7; aiPriority: 5; offensive: 1; aiRadius: 0),
    { Spell 67: Neutralize Poison }
    (castClass: 0; level: 4; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 68: Poison: a touch, saved against as poison }
    (castClass: 0; level: 4; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 0; effect: 0; whenCast: 1;
     castTime: 7; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 69: Protection From Evil, 10' Radius, the cleric's }
    (castClass: 0; level: 4; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 45; whenCast: 2;
     castTime: 7; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 70: Sticks to Snakes }
    (castClass: 0; level: 4; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 2; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: C_EFFECT.STICKS_TO_SNAKES; whenCast: 1;
     castTime: 7; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 71: Cure Critical Wounds }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 8; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 72: Cause Critical Wounds }
    (castClass: 0; level: 5; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 73: Dispel Evil }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 0; target: 0;
     saveResult: 0; saveType: 4; effect: C_EFFECT.DISPEL_EVIL_TOUCH; whenCast: 1;
     castTime: 8; aiPriority: 3; offensive: 0; aiRadius: 0),
    { Spell 74: Flame Strike }
    (castClass: 0; level: 5; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 75: Raise Dead }
    (castClass: 0; level: 5; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 0;
     castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 76: Slay Living, saved against as death magic (Curse's row names the spell column, which its handler does
      not roll) }
    (castClass: 0; level: 5; rangeFixed: 3; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 0; effect: 0; whenCast: 1;
     castTime: 10; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 77: Detect Magic, the druid's; AI priority 0, as the others' (Curse's 1 had the AI cast it in combat) }
    (castClass: 2; level: 1; rangeFixed: 3; rangeVar: 0;
     durFixed: 12; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 5; whenCast: 2;
     castTime: 3; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 78: Entangle; the AI's friendly-fire radius is the area's (Curse's 0 let it entangle its own side) }
    (castClass: 2; level: 1; rangeFixed: 8; rangeVar: 0;
     durFixed: 10; durVar: 0; area: 11; target: 0;
     saveResult: 1; saveType: 4; effect: C_EFFECT.ENTANGLE; whenCast: 1;
     castTime: 3; aiPriority: 3; offensive: 1; aiRadius: 3),
    { Spell 79: Faerie Fire }
    (castClass: 2; level: 1; rangeFixed: 8; rangeVar: 0;
     durFixed: 0; durVar: 4; area: 5; target: 0;
     saveResult: 0; saveType: 4; effect: C_EFFECT.FAERIE_FIRE; whenCast: 1;
     castTime: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 80: Invisibility to Animals: by touch, with no attack roll and not at foes (Curse's range 255 asked an
      attack roll, and its AI aimed it at enemies) }
    (castClass: 2; level: 1; rangeFixed: 0; rangeVar: 0;
     durFixed: 10; durVar: 1; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: C_EFFECT.INVISIBLE_TO_ANIMALS; whenCast: 2;
     castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 81: Charm Monsters }
    (castClass: 1; level: 4; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 5; target: 0;
     saveResult: 1; saveType: 4; effect: 11; whenCast: 1;
     castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 82: Confusion; the AI's friendly-fire radius is the area's, as for Entangle }
    (castClass: 1; level: 4; rangeFixed: 12; rangeVar: 0;
     durFixed: 2; durVar: 1; area: 11; target: 0;
     saveResult: 1; saveType: 4; effect: C_EFFECT.CONFUSION; whenCast: 1;
     castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 3),
    { Spell 83: Dimension Door }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 3;
     durFixed: 0; durVar: 0; area: 8; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { Spell 84: Fear }
    (castClass: 1; level: 4; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 8; target: 0;
     saveResult: 1; saveType: 4; effect: C_EFFECT.FEAR; whenCast: 1;
     castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 85: Fire Shield }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 0;
     durFixed: 2; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 4; aiPriority: 8; offensive: 0; aiRadius: 0),
    { Spell 86: Fumble }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: C_EFFECT.FUMBLE; whenCast: 1;
     castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 87: Ice Storm; the AI's friendly-fire radius is the area's, as for Entangle }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 10; target: 0;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 1;
     castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 2),
    { Spell 88: Minor Globe Of Invulnerability }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: C_EFFECT.MINOR_GLOBE; whenCast: 2;
     castTime: 4; aiPriority: 5; offensive: 0; aiRadius: 0),
    { Spell 89: Remove Curse, the magic-user's }
    (castClass: 1; level: 4; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 4; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 90: Animate Dead, the magic-user's: a 5th-level spell (1st-edition PHB; Curse made it a special one no class
      casts) }
    (castClass: 1; level: 5; rangeFixed: 1; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 240; target: 4;
     saveResult: 0; saveType: 4; effect: 32; whenCast: 2;
     castTime: 5; aiPriority: 2; offensive: 0; aiRadius: 0),
    { Spell 91: Cloudkill (#1193): a 3x3 cloud round the aim cell for a round per level (Magic.SpellCloudkill). Curse's
      range of 2, not the PHB's 1", as the cloud does not roll away from its caster here; the handler rolls the saves
      vs. poison }
    (castClass: 1; level: 5; rangeFixed: 2; rangeVar: 0;
     durFixed: 0; durVar: 1; area: 9; target: 0;
     saveResult: 3; saveType: 0; effect: 0; whenCast: 1;
     castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 1),
    { Spell 92: Cone of Cold }
    (castClass: 1; level: 5; rangeFixed: 6; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 8; target: 0;
     saveResult: 2; saveType: 4; effect: 0; whenCast: 1;
     castTime: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 93: Feeblemind }
    (castClass: 1; level: 5; rangeFixed: 0; rangeVar: 1;
     durFixed: 0; durVar: 0; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: C_EFFECT.FEEBLEMIND; whenCast: 1;
     castTime: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { Spell 94: Hold Monsters }
    (castClass: 1; level: 5; rangeFixed: 0; rangeVar: 1;
     durFixed: 0; durVar: 1; area: 7; target: 0;
     saveResult: 1; saveType: 4; effect: 52; whenCast: 1;
     castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { Spell 95: Curse's monster power, not cast here }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 96: Curse's monster power, not cast here }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 97: Curse's monster power, not cast here }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 98: Curse's monster power, not cast here }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 99: Curse's monster power, not cast here }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 100: Bestow Curse, the magic-user's }
    (castClass: 1; level: 4; rangeFixed: 255; rangeVar: 0;
     durFixed: 0; durVar: 10; area: 4; target: 0;
     saveResult: 1; saveType: 4; effect: 36; whenCast: 1;
     castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { Spell 101 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 102 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 103 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 104 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 105 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 106 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 107 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 108 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 109 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 110 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 111 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 112 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 113 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 114 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 115 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 116 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 117 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 118 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 119 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 120 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 121 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 122 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 123 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 124 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 125 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 126 }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { Spell 127: Keoghtom's Ointment, item effect 150 (#1121) }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 4; target: 2;
     saveResult: 0; saveType: 4; effect: 0; whenCast: 2;
     castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { Spell 128: Manual of Bodily Health, item effect 151 (#1121) }
    (castClass: 3; level: 6; rangeFixed: 0; rangeVar: 0;
     durFixed: 0; durVar: 0; area: 0; target: 1;
     saveResult: 0; saveType: 4; effect: 4; whenCast: 0;
     castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0));
  { Rest time units }
  unitScale: array[0..6] of Word = (
    { segment, minute, turn, hour, day, month, year }
    10, 10, 6, 24, 30, 12, 256);
  { Wilderness map: 1-based tile ids; after the - 1, bit 7 selects the second tile set. }
  { row, column }
  wildMap: array[0..35, 0..43] of Byte = (
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02,
     $01, $02, $01, $02, $01, $28, $9D, $9E, $9B, $9C, $35, $65, $31, $9B, $33, $62, $5E, $9D, $35, $36, $9E, $37),
    ($02, $01, $02, $01, $02, $01, $05, $06, $08, $06, $08, $09, $02, $01, $02, $01, $02, $01, $02, $05, $06, $08,
     $09, $01, $02, $01, $25, $2D, $2E, $9C, $2D, $30, $62, $63, $64, $32, $9C, $35, $36, $44, $4A, $9D, $38, $63),
    ($01, $02, $01, $01, $02, $05, $12, $07, $0D, $21, $04, $12, $08, $09, $05, $06, $08, $06, $03, $12, $07, $04,
     $12, $10, $01, $02, $26, $1A, $62, $2F, $62, $62, $36, $5F, $5F, $9B, $37, $5E, $9D, $43, $4B, $9B, $9C, $33),
    ($02, $05, $06, $03, $0D, $0F, $0E, $0F, $0C, $0B, $0A, $23, $07, $04, $0D, $0E, $0F, $23, $12, $0D, $21, $04,
     $12, $07, $10, $01, $02, $27, $33, $65, $64, $5E, $9B, $9C, $9D, $44, $65, $34, $37, $34, $9C, $9D, $9E, $2D),
    ($03, $07, $0D, $0F, $0C, $0B, $22, $0C, $0B, $22, $0B, $1F, $12, $07, $0E, $22, $0C, $0B, $0A, $0C, $0B, $21,
     $04, $12, $07, $10, $01, $02, $28, $38, $65, $34, $9D, $9E, $9B, $43, $62, $63, $62, $63, $4C, $9B, $9C, $48),
    ($0E, $0F, $22, $0B, $22, $0C, $0B, $22, $24, $24, $1F, $07, $04, $0D, $22, $24, $22, $0C, $0B, $24, $22, $24,
     $21, $04, $12, $11, $02, $29, $9C, $37, $62, $63, $32, $9D, $37, $63, $64, $65, $64, $65, $62, $32, $9D, $43),
    ($0C, $0B, $24, $22, $24, $22, $0C, $0B, $22, $1F, $07, $04, $12, $0E, $0C, $0B, $24, $22, $24, $22, $0C, $0B,
     $1F, $07, $04, $11, $01, $02, $28, $33, $64, $5E, $9B, $9C, $48, $65, $3A, $62, $3A, $62, $63, $4D, $9E, $35),
    ($0B, $24, $22, $24, $0C, $0B, $22, $24, $22, $21, $12, $0E, $0F, $22, $24, $22, $0B, $24, $22, $24, $22, $1F,
     $04, $12, $16, $13, $02, $29, $9B, $33, $62, $5E, $9D, $9E, $43, $42, $7B, $3D, $93, $3B, $65, $4B, $44, $63),
    ($22, $22, $0C, $0B, $22, $24, $24, $22, $0C, $0B, $C9, $CA, $22, $0C, $0B, $24, $22, $0C, $0B, $22, $1F, $12,
     $07, $11, $01, $02, $01, $02, $27, $9C, $35, $65, $32, $44, $42, $93, $92, $FF, $A7, $3C, $64, $4D, $43, $65),
    ($24, $0B, $22, $0C, $0B, $22, $0C, $0B, $22, $24, $CB, $CC, $24, $22, $0C, $0B, $24, $20, $1B, $1C, $16, $04,
     $12, $13, $02, $01, $02, $01, $29, $37, $62, $63, $32, $49, $41, $88, $93, $A7, $3E, $65, $62, $63, $64, $36),
    ($0B, $22, $24, $24, $22, $24, $22, $22, $24, $22, $CD, $CE, $CF, $24, $1F, $1D, $1C, $04, $12, $13, $01, $17,
     $15, $02, $01, $02, $01, $02, $01, $2A, $64, $5E, $9B, $37, $62, $41, $3F, $3E, $62, $63, $64, $65, $36, $9C),
    ($24, $0C, $0B, $22, $24, $22, $0C, $0B, $22, $24, $D0, $D1, $D2, $1C, $12, $07, $04, $12, $D8, $94, $02, $01,
     $02, $01, $02, $FB, $02, $01, $02, $01, $2A, $36, $2C, $62, $46, $47, $62, $63, $64, $65, $62, $36, $9E, $9B),
    ($22, $24, $22, $24, $22, $0B, $22, $24, $22, $1F, $04, $12, $D3, $D4, $EF, $D5, $D6, $D7, $79, $7A, $95, $02,
     $01, $02, $01, $8A, $95, $02, $01, $02, $01, $2B, $01, $45, $9B, $9C, $48, $62, $63, $64, $34, $9B, $9C, $9D),
    ($1B, $1B, $1C, $1D, $1E, $0C, $0B, $22, $1F, $04, $12, $07, $04, $12, $07, $DA, $D9, $79, $7C, $79, $7A, $95,
     $02, $01, $8A, $91, $7B, $95, $02, $01, $02, $01, $02, $39, $9D, $9E, $43, $36, $33, $62, $36, $9D, $9E, $2D),
    ($04, $12, $07, $04, $12, $1D, $1E, $1F, $04, $12, $07, $04, $14, $18, $15, $EE, $DB, $DC, $79, $7A, $79, $91,
     $95, $86, $7A, $90, $91, $7B, $95, $02, $01, $02, $40, $9B, $2D, $30, $36, $9E, $44, $64, $4C, $9C, $44, $62),
    ($14, $15, $2B, $17, $18, $18, $19, $14, $15, $17, $18, $15, $01, $02, $8A, $91, $79, $DD, $E7, $E6, $E5, $7D,
     $88, $89, $79, $7A, $7B, $91, $92, $96, $02, $29, $FC, $2F, $62, $4A, $9B, $9C, $5D, $65, $63, $32, $61, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $8A, $89, $93, $7B, $91, $DE, $E9, $E8, $E4, $01,
     $7D, $88, $7A, $90, $91, $7B, $92, $93, $95, $02, $27, $BA, $64, $4B, $9D, $9E, $9B, $48, $4A, $9B, $43, $64),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $86, $89, $7B, $91, $92, $93, $79, $DF, $E1, $E2, $E3, $6F,
     $01, $7D, $88, $92, $93, $92, $93, $79, $7B, $95, $02, $B9, $B8, $2E, $2D, $4C, $9C, $5D, $4B, $44, $62, $63),
    ($01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $86, $88, $91, $7B, $92, $93, $79, $E0, $6D, $72, $66, $70,
     $02, $01, $7D, $91, $92, $93, $91, $7C, $91, $8E, $01, $02, $BB, $B7, $48, $63, $4D, $9D, $9E, $61, $64, $65),
    ($02, $01, $02, $01, $02, $01, $52, $5C, $02, $01, $02, $7D, $88, $92, $93, $79, $7B, $8F, $76, $68, $67, $71,
     $01, $02, $8A, $91, $7B, $91, $7B, $91, $79, $8D, $02, $01, $29, $B6, $5D, $65, $60, $9B, $9C, $61, $62, $36),
    ($01, $02, $01, $02, $01, $02, $53, $4F, $5B, $02, $01, $02, $7D, $88, $91, $7C, $8E, $02, $77, $69, $6D, $70,
     $02, $01, $88, $90, $91, $7B, $93, $7B, $91, $93, $95, $02, $99, $C8, $B5, $48, $60, $9D, $9E, $43, $36, $9B),
    ($02, $01, $02, $01, $02, $01, $54, $4F, $50, $01, $02, $01, $02, $7D, $7B, $79, $8D, $01, $F6, $6A, $6B, $73,
     $01, $02, $7D, $7A, $7B, $91, $92, $93, $79, $7A, $8C, $01, $9F, $C7, $9C, $43, $31, $9B, $44, $4A, $9D, $9E),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $5B, $02, $01, $02, $01, $86, $88, $A7, $8C, $02, $8A, $59, $6A, $6B,
     $74, $01, $02, $A6, $91, $7B, $92, $93, $79, $97, $9A, $9A, $9B, $C6, $44, $62, $F2, $4D, $61, $60, $9C, $44),
    ($02, $01, $02, $01, $02, $01, $02, $54, $5C, $01, $02, $01, $02, $01, $7D, $8C, $02, $8A, $91, $58, $6D, $66,
     $6D, $74, $01, $7D, $93, $92, $93, $79, $7B, $97, $9C, $FA, $9E, $C5, $5D, $F1, $01, $2A, $5D, $31, $9B, $43),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $5B, $01, $02, $01, $02, $01, $02, $8A, $91, $7B, $91, $59, $6A,
     $6B, $6D, $75, $01, $A6, $93, $91, $7C, $91, $97, $9C, $C2, $C3, $C4, $A4, $01, $02, $01, $F3, $62, $4C, $35),
    ($02, $01, $02, $01, $02, $01, $52, $4F, $4F, $50, $02, $01, $02, $01, $02, $86, $7A, $90, $91, $7B, $58, $6D,
     $6A, $6C, $6B, $75, $7D, $88, $7B, $79, $7B, $93, $98, $C5, $A4, $01, $01, $02, $8A, $89, $B4, $64, $65, $B2),
    ($01, $02, $01, $02, $01, $02, $55, $4F, $51, $02, $01, $02, $01, $02, $01, $02, $7D, $7A, $7B, $91, $92, $59,
     $6D, $6D, $66, $6D, $75, $7D, $88, $A7, $8C, $A6, $92, $C0, $02, $8A, $89, $89, $92, $93, $87, $B2, $B3, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $4F, $5B, $02, $01, $02, $01, $02, $01, $86, $90, $91, $7B, $92, $93,
     $5A, $59, $F4, $FD, $6E, $01, $7D, $8C, $02, $7D, $93, $BF, $A3, $A1, $A2, $92, $A0, $83, $84, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $53, $4F, $50, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $93, $79,
     $7B, $7A, $57, $F5, $AE, $AD, $01, $02, $01, $02, $A6, $BE, $BD, $EB, $ED, $83, $84, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $54, $51, $01, $02, $01, $02, $01, $02, $01, $02, $01, $7D, $88, $92, $7C,
     $91, $93, $85, $4E, $4E, $4E, $AC, $AA, $A9, $A9, $A8, $BC, $EA, $EC, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $02, $01, $02, $01, $55, $56, $02, $01, $02, $01, $02, $AA, $AB, $AD, $AA, $AF, $7E, $7F, $80,
     $81, $83, $84, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $02, $01, $F9, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $82, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($01, $02, $01, $FE, $01, $02, $AD, $02, $01, $02, $01, $02, $B0, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($B1, $AD, $B1, $AD, $AA, $AF, $4E, $AC, $B1, $AD, $AA, $AF, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E),
    ($4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E,
     $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E, $4E));
  { map column offset for location types 2..4 }
  wildColOfs: array[2..4] of Byte = (0, 13, 26);

const
  { Class, race and level rules }
  { 60 - THAC0 }
  classThac0: array[C_LEVEL.CLERIC..C_LEVEL.MONK, 0..10] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49),
    (40, 40, 40, 40, 40, 40, 41, 41, 41, 41, 41),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46));
  defaultIconColors: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
  { Racial ability limits, by race; the strength columns are by gender. Human women reach 18/00 like human men. }
  minimumMaximumStatistics: array[1..7] of Types.TRuleRace = (
    (strMin: (8, 8); strMax: (18, 17); excMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    (strMin: (3, 3); strMax: (18, 16); excMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 15); excMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); excMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); excMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    (strMin: (6, 6); strMax: (18, 18); excMax: (99, 75); intMin: 3; intMax: 17;
     wisMin: 3; wisMax: 14; dexMin: 3; dexMax: 17; conMin: 13; conMax: 19; chaMin: 3; chaMax: 12),
    (strMin: (3, 3); strMax: (18, 18); excMax: (100, 100); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { The classLevels indexes each class trains, in the order its name gives them; -1 fills a shorter list. }
  classParts: array[C_CLASS.CLERIC..C_CLASS.MAGE_THIEF] of Types.TRuleClassParts = (
    (first: 0; second: -1; third: -1), { cleric }
    (first: 1; second: -1; third: -1), { druid }
    (first: 2; second: -1; third: -1), { fighter }
    (first: 3; second: -1; third: -1), { paladin }
    (first: 4; second: -1; third: -1), { ranger }
    (first: 5; second: -1; third: -1), { magic-user }
    (first: 6; second: -1; third: -1), { thief }
    (first: 7; second: -1; third: -1), { monk }
    (first: 0; second: 2; third: -1), { cleric/fighter }
    (first: 0; second: 2; third: 5), { cleric/fighter/magic-user }
    (first: 0; second: 4; third: -1), { cleric/ranger }
    (first: 0; second: 5; third: -1), { cleric/magic-user }
    (first: 0; second: 6; third: -1), { cleric/thief }
    (first: 2; second: 5; third: -1), { fighter/magic-user }
    (first: 2; second: 6; third: -1), { fighter/thief }
    (first: 2; second: 5; third: 6), { fighter/magic-user/thief }
    (first: 5; second: 6; third: -1)); { magic-user/thief }
  { Experience and spell slots by class slot, from the 1st-edition PHB to level 9 (#1121): xp[n] is the experience
    level n starts at, -1 for a class with no table (druid, monk). How far a class trains is ClassCal.MaxLevel's, which
    with the Game Level Cap setting on stops at SSI's levels. slots[n] are a cleric's or magic-user's spell slots at
    level n by spell level, before the Wisdom bonus; level 1's one slot is ClassCal.FirstLevelSlots'. }
  classExperience: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of Types.TRuleXp = (
    (xp: (1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001);
     slots: ((2, 0, 0, 0, 0), (2, 1, 0, 0, 0), (3, 2, 0, 0, 0), (3, 3, 1, 0, 0), (3, 3, 2, 0, 0), (3, 3, 2, 1, 0),
             (3, 3, 3, 2, 0), (4, 4, 3, 2, 1))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xp: (2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xp: (2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xp: (2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001);
     slots: ((2, 0, 0, 0, 0), (2, 1, 0, 0, 0), (3, 2, 0, 0, 0), (4, 2, 1, 0, 0), (4, 2, 2, 0, 0), (4, 3, 2, 1, 0),
             (4, 3, 3, 2, 0), (4, 3, 3, 2, 1))),
    (xp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))),
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1);
     slots: ((0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0),
             (0, 0, 0, 0, 0), (0, 0, 0, 0, 0))));
  { The spells a paladin and a ranger cast (1st-edition PHB), by class level from PALADIN_SPELLS_FROM and
    RANGER_SPELLS_FROM to C_LEVEL.LEVEL_LAST: the paladin's cleric slots, and the ranger's druid and magic-user slots,
    each by spell level. ClassCal.RecalcBaseSkills adds them to the character's slots of that kind (#1121). }
  PALADIN_SPELLS_FROM = 9;
  RANGER_SPELLS_FROM = 8;
  paladinSlots: array[PALADIN_SPELLS_FROM..C_LEVEL.LEVEL_LAST, 1..Types.CASTER_LEVEL_LAST] of Byte = (
    (1, 0, 0, 0, 0));
  rangerDruidSlots: array[RANGER_SPELLS_FROM..C_LEVEL.LEVEL_LAST, 1..Types.CASTER_LEVEL_LAST] of Byte = (
    (1, 0, 0, 0, 0), (1, 0, 0, 0, 0));
  rangerMageSlots: array[RANGER_SPELLS_FROM..C_LEVEL.LEVEL_LAST, 1..Types.CASTER_LEVEL_LAST] of Byte = (
    (0, 0, 0, 0, 0), (1, 0, 0, 0, 0));
  { the Wisdom a cleric needs for a fifth-level spell, which a level-9 cleric's table row gives (1st-edition PHB) }
  CLERIC_FIFTH_LEVEL_WISDOM = 17;

implementation

end.
