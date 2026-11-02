{$F+}
{$I COMPILER.INC}
unit Types;

interface

uses C_GENDER, C_SAVE, C_EQUIP, C_LEVEL, C_STAT, C_MONEY, C_GBVM, C_SPELL;

const
  { the longest name a character or creature has }
  NAME_LEN = 15;
  { the most drained levels a character's drain log keeps (TCharExt.drains, #1174); a drain past them drops the
    oldest }
  DRAIN_LOG_LEN = 8;
  { how much bigger a pointer is than the 4-byte far pointer the saved records hold: 0 in DOS and a 32-bit program, 4 in
    a 64-bit one. TCharRecord's pads grow by it, as the pointer before the field each skips to does (DiskRec has the
    records' disk form). }
  PTR_GROWTH = SizeOf(Pointer) - 4;
  { the most creatures in the party: a saved game's party names, the usual spells, the statistics, the icon slots }
  MAX_PARTY = 8;
  { the most creatures in play at once, party and monsters: combat's slots (GameVars.creatureArr, arenaLoc and the
    target lists) and the creature list's ordinals }
  ARENA_SLOTS = 72;
  { the combat arena's last column and row (TArena.cells): 50 cells by 25 }
  ARENA_LAST_X = 49;
  ARENA_LAST_Y = 24;
  { the most party corpses the arena keeps (GameVars.downed) }
  DOWNED_SLOTS = 8;
  { the data disks the game shipped on, 1..LAST_DISK }
  LAST_DISK = 8;
  { a 3D map's last row and column: maps are 16 by 16 }
  MAP_LAST = 15;
  { the last memorized-spell slot in SSI's record (TCharRecord.memorizedSpells); Turbo Pascal 6 has no High() }
  SPELL_SLOT_LAST = 20;
  { the last memorized-spell slot of all (TMemorized): the record's, then TCharExt.moreMemorized's, enough for a cleric
    and magic-user both at level 9 with the Wisdom bonus (#1121); CharHlp.MemorizedAt reaches them }
  MEMORIZED_LAST = 47;
  { the most classes a race takes (TRuleRaceClasses.classes), 1..RACE_CLASSES_LAST }
  RACE_CLASSES_LAST = 13;
  { the highest spell level a character has slots for (CharHlp.SpellSlots), and the levels SSI's record holds
    (TCharRecord.clericSpells and mageSpells); the rest are TCharExt's (#1121) }
  CASTER_LEVEL_LAST = 5;
  RECORD_SPELL_LEVELS = 3;
  { the bytes of TCharExt.moreKnown: a bit for each spell id past the record's spellsKnown, KNOWN_RECORD_LAST + 1 to
    C_SPELL.LAST }
  KNOWN_RECORD_LAST = 56;
  KNOWN_EXT_BYTES = 6;
  { the item types ITEMS holds, 0..BASE_ITEM_LAST; CharHlp.baseItems has one entry more, BASE_ITEM_OVERFLOW }
  BASE_ITEM_LAST = 127;
  BASE_ITEM_OVERFLOW = 128;
  { the script strings EclVars.LoadEclVars keeps, GameVars.gbStrings^[1..GB_STRING_LAST]; later ones overwrite the
    last }
  GB_STRING_LAST = 20;
  { TAcAdjust's parts: Dexterity, the shield, the pluses of items with no AC of their own, the best ring, the best
    armour }
  AC_DEX = 0;
  AC_SHIELD = 1;
  AC_PLUSES = 2;
  AC_RING = 3;
  AC_ARMOR = 4;
  { TCharRecord.iconDimensions: the low bits are the combat icon's size, and this bit marks a Large creature (size L),
    which takes weapons' damage against large targets }
  ICON_LARGE = $80;

  { a transparent pixel in a keyed video mode's picture (TVideoDriver.keyed, VGA): no colour drawn is 255 }
  PIC_KEY = $FF;

type
  { Shared types. }
  TStr40 = String[40];
  { a line of the 640 x 400 screen's 80 columns (TVideoDriver.fine): the bottom-line menus }
  TStr80 = String[80];
  { A DOS path with its file name, as Dos.PathStr: DOS allows 64 characters of directory after the drive, 79 in all. A
    native build's paths are longer: there, a short string's most. }
{$IFDEF FPC}
  TPathStr = String[255];
{$ELSE}
  TPathStr = String[79];
{$ENDIF}
  TBaseItemRec = record
    { equip slot }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice number }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged rate of fire x2 }
    rateOfFire: Byte;
    { AC adjustment descriptor }
    acDescr: Byte;
    { melee damage type; the C_ITEM.WPN_ constants }
    wpnClass: Byte;
    { reserved }
    unk8: Byte;
    { damage vs small/medium: dice number }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { ranged range (exclusive) }
    range: Byte;
    { class usability bitmask }
    classMask: Byte;
    { weapon-property bitmask; see the PROP_ bits of C_ITEM and CharHlp }
    props: Byte;
    { reserved }
    unkF: Byte;
  end;
  PBaseItemRec = ^TBaseItemRec;
  PCharRecord = ^TCharRecord;
  PCombatRec = ^TCombatRec;
  PEffectRec = ^TEffectRec;
  PItemRec = ^TItemRec;
  TIconCols = array[1..6] of Byte;
  { A character's memorized spells in SSI's record: spell IDs, 0 = empty, C_SPELL.PENDING_FLAG set while still being
    memorized. }
  TSpellSlots = array[0..SPELL_SLOT_LAST] of Byte;
  { All of a character's memorized spells, the record's and the port's (CharHlp.GetMemorized). }
  TMemorized = array[0..MEMORIZED_LAST] of Byte;
  { a count for each class, by C_LEVEL slot }
  TClassCounts = array[C_LEVEL.CLERIC..C_LEVEL.MONK] of Byte;
  { One level an energy drain took (#1174): the experience it cost (the experience before less the experience after),
    the hit points it took and the class it lowered (a C_LEVEL slot). Restoration gives back that level, those hit
    points and that experience. }
  TDrainRec = record
    xp: LongInt;
    hp: Byte;
    cls: ShortInt;
  end;
  { The port's own fields of a character, kept past the record's saved bytes: no file of SSI's has them. A character's
    are kept in its .chx file (CharExt), read when it is loaded; a record from SSI's form (DiskRec.CharFromDisk: a
    .cha or .sav, a monster from MONxCHA.DAX) has them all zero. }
  TCharExt = record
    { The class a human has left (dual-classing, #838), as its C_LEVEL bit (1 shl slot): a class it can no longer
      train, whose levels it may use only once the class it follows now (charClass) is the higher
      (CharHlp.GetClassLevel). 0 for every other character. A human changes class once (#879); the field stays a mask,
      as the .chx files already written hold it. }
    formerClasses: Byte;
    { CharExt.EXT_* bits: EXT_ANIMATE_JOINED for a creature that joined the party through Animate Dead (#1089). }
    flags: Byte;
    { The drain log (#1174): the last drainCount levels drained, drains[1] the oldest, drains[drainCount] the most
      recent, which Restoration gives back first (CharExt.PushDrain, PopDrain). drainedLevels counts every drained
      level: the ones before the log was kept (an old save) or past its DRAIN_LOG_LEN entries have none, and are
      restored as before. drainCount is never above drainedLevels. }
    drainCount: Byte;
    drains: array[1..DRAIN_LOG_LEN] of TDrainRec;
    { The spells past SSI's record (#1121), read through CharHlp: the cleric's and magic-user's spell slots of levels
      4 and 5, a ranger's druid slots, the spells known past KNOWN_RECORD_LAST (a bit each, id - KNOWN_RECORD_LAST - 1
      from bit 0 of the first byte), and the memorized-spell slots past the record's. }
    moreSlots: array[C_SPELL.CLASS_CLERIC..C_SPELL.CLASS_MAGE, RECORD_SPELL_LEVELS + 1..CASTER_LEVEL_LAST] of Byte;
    druidSlots: array[1..CASTER_LEVEL_LAST] of Byte;
    moreKnown: array[0..KNOWN_EXT_BYTES - 1] of Byte;
    moreMemorized: array[SPELL_SLOT_LAST + 1..MEMORIZED_LAST] of Byte;
  end;
  TCharRecord = record
    { character name }
    name: string[NAME_LEN];
    case Integer of
      0: (
    { strength }
    strCur: Byte;
    { intelligence }
    intCur: Byte;
    { wisdom }
    wisCur: Byte;
    { dexterity }
    dexCur: Byte;
    { constitution }
    conCur: Byte;
    { charisma }
    chaCur: Byte;
    { exceptional strength (18/xx pct) }
    strExc: Byte;
    { currently memorized }
    memorizedSpells: TSpellSlots;
    { camp writes the hours code 0/4/6, rest counts it down }
    spellPrepTime: Byte;
    { base THAC0 }
    thac0Base: Byte;
    { Race. }
    race: ShortInt;
    charClass: ShortInt;
    age: Word;
    { hit points maximum }
    hpMax: Byte;
    { Known spells, indexed by spell ID, to KNOWN_RECORD_LAST; the later ones are portExt.moreKnown's
      (CharHlp.KnowsSpell). }
    spellsKnown: array[1..KNOWN_RECORD_LAST] of Byte;
    attackLevel: Byte;
    { the combat icon's size, with ICON_LARGE for a Large creature }
    iconDimensions: Byte;
    { Saving throws: paralysis, petrification, wand, breath and spell. }
    saves: array[C_SAVE.PARALYZE..C_SAVE.SPELL] of Byte;
    movementBase: Byte;
    { Highest level across the character's classes. }
    levelHighest: ShortInt;
    drainedLevels: Byte;
    drainedHps: Byte;
    { Undead level for turning. }
    levelUndead: ShortInt;
    { Thief skill values. }
    thiefSkills: array[1..8] of Byte;
    { far ptr to effects list }
    effectsAddr: PEffectRec;
    { reserved }
    unknown083: Byte;
    { packed -- see C_NPC.NPC_* }
    npc: Byte;
    { Low three bits hold the NPC's treasure-share weight. }
    npcTreasureShare: Byte;
    { reserved }
    unknown086: Byte;
    { reserved }
    unknown087: Byte;
    { Coins: copper, silver, electrum, gold, platinum, gems and jewelry. }
    coins: array[C_MONEY.COPPER..C_MONEY.JEWELRY] of Word;
    { Class levels; indexed by C_LEVEL. }
    classLevels: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of ShortInt;
    { Gender; see GENDER_*. }
    gender: Byte;
    charType: Byte;
    alignment: Byte;
    { attacks per round }
    attacks: Byte;
    attacks2: Byte;
    { unarmed dice rolls }
    unarmedRollsA: array[1..2] of Byte;
    { unarmed dice sides }
    unarmedDiceA: array[1..2] of Byte;
    { unarmed dmg mods }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    { strength to-hit/damage applies }
    useStrength: Byte;
    { Random duplicate-detection key assigned at creation. The roster loader rejects characters whose name and key both
      match a party member. }
    randByte: Byte;
    experience: LongInt;
    itemLimits: Byte;
    hpRolled: Byte;
    { Cleric and magic-user spell slots by level, including wisdom bonuses, to RECORD_SPELL_LEVELS; CharHlp.SpellSlots
      reads every level. }
    clericSpells: array[1..RECORD_SPELL_LEVELS] of Byte;
    mageSpells: array[1..RECORD_SPELL_LEVELS] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    portraitHead: Byte;
    portraitBody: Byte;
    iconHead: Byte;
    iconBody: Byte;
    orderNumber: Byte;
    iconSize: Byte;
    { Color pairs: body, arm, leg, hair, shield and weapon. }
    iconColors: array[0..5] of Byte;
    numberOfItems: Byte;
    { far ptr to item list }
    itemsAddr: PItemRec;
    { Readied items, indexed by EQUIP_*. }
    equipped: array[C_EQUIP.WEAPON..C_EQUIP.BOLT] of PItemRec;
    handsEquipped: Byte;
    { accumulated save bonus (signed) }
    saveBonus: ShortInt;
    encumbrance: Word;
    { far ptr to next character }
    nextCharAddr: PCharRecord;
    { far ptr to combatant }
    combatAddr: PCombatRec;
    status: 0..127;
    enabled: Byte;
    hostile: ShortInt;
    quickfight: Byte;
    { current THAC0 }
    thac0Cur: Byte;
    { current AC }
    acCur: Byte;
    acBehind: Byte;
    curAttacks: Byte;
    curAttacks2: Byte;
    { current dice rolls }
    curRollsA: array[1..2] of Byte;
    { current dice sides }
    curDiceA: array[1..2] of Byte;
    { current dmg mods }
    curModA: array[1..2] of ShortInt;
    { current hit points }
    hpCur: Byte;
    { current movement }
    movementCur: Byte;
    { the port's own fields, after the saved bytes (DiskRec.CHAR_DISK_BYTES) }
    portExt: TCharExt);
      1: (
    { Current attributes as an array for character creation and display. }
    stats: array[C_STAT.STRENGTH..C_STAT.CHARISMA] of Byte);
      2: (
    { skips to gender }
    genderPad: array[0..141 + PTR_GROWTH] of Byte;
    { Signed gender value used to index racial strength limits. }
    genderSp: ShortInt);
      3: (
    { skips to iconColors }
    iconColorsPad: array[0..176 + PTR_GROWTH] of Byte;
    { One-based icon-color array for character customization and saving. }
    iconColors1: TIconCols);
      4: (
    { skips to gender }
    viewPad0: array[0..141 + PTR_GROWTH] of Byte;
    { gender as a 0..127 subrange -- ViewChar indexes genderNames with it }
    genderIdx: 0..127;
    { charType }
    viewPad1: Byte;
    { alignment as a 0..127 subrange -- ViewChar indexes alignNames with it }
    alignmentIdx: 0..127);
  end;
  TCombatRec = record
    { spell being cast }
    spellCast: Byte;
    { may cast this round }
    castAllowed: Byte;
    { may use an item this round }
    itemUseAllowed: Byte;
    { signed (Combat.NextCreature and CreatureAction compare signed); cleared on death and by EndActions }
    initiative: ShortInt;
    attackPhase: Byte;
    { sweep allowance (attackLevel) }
    sweepBudget: Byte;
    { movement left this round }
    movement: Byte;
    { guarding flag }
    guarding: Byte;
    madeAttack: Byte;
    { facing 0..7 }
    direction: Byte;
    { opponent/target }
    other: PCharRecord;
    { damage past 0 hp (dying) }
    overkill: Byte;
    { attackers this round }
    flankCount: Byte;
    { undead-turned flag }
    turned: Byte;
    usedTurnUndead: Byte;
    { summed offset from facing, mod 8 }
    flankSpread: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    { AI approach-pattern index 1..6 }
    aiStance: Byte;
    { 1 when a paladin's leadership put this NPC under the player's control for the fight (CbtActs.TryLead, #1124) }
    led: Byte;
  end;
  TDownedRec = record
    { the downed creature }
    cr: PCharRecord;
    { Corpse cell coordinates. }
    x: ShortInt;
    y: ShortInt;
    { cell terrain saved from under it }
    terrain: Byte;
  end;
  TEffectRec = record
    { effect id }
    id: Byte;
    { minutes; 0 = permanent -- blood drain packs a damage budget in the upper bits }
    duration: Word;
    { strength; handlers pack flags in the nibbles, and the hold family stores a creature index here }
    strength: Byte;
    { removal calls the handler }
    onRemove: Boolean;
    { next effect }
    next: PEffectRec;
  end;
  { One line of a list MenuCore.MenuVertical shows. Its fields are the leading fields of TItemRec, so an item list is
    shown in place and a line that is never an item is allocated at this size. }
  TMenuNode = record
    { the line's text }
    name: string[40];
    { Nonzero marks a menu-list title. }
    inUse: Byte;
    { the next line, nil after the last }
    next: PItemRec;
  end;
  TItemRec = record
    { item name }
    name: string[40];
    { Nonzero marks a menu-list title; zero for inventory items. }
    inUse: Byte;
    { next item in inventory list }
    next: PItemRec;
    { base-item index (into baseItems) }
    itemType: Byte;
    { identified name components [1]=component 3, [2]=2, [3]=1 }
    nameIds: array[1..3] of Byte;
    { magical bonus }
    plus: ShortInt;
    { saving throw bonus }
    saveBonus: ShortInt;
    { 0 = unequipped, 1 = equipped }
    equipped: Byte;
    { Unidentified name-component mask. }
    unidMask: Byte;
    cursed: Byte;
    { weight in coins }
    weight: Word;
    { 0 = single, non-stacking }
    quantity: Byte;
    { value in gold pieces }
    value: Word;
    case Integer of
      0: (
        { properties (scroll spells / charges) }
        charges: Byte;
        { effect id }
        effect: Byte;
        { special-item id }
        special: Byte;
        { The weapon set the player tagged the item for (#1209): C_ITEM.SET_NONE, or SET_FIRST..SET_LAST, which 1 and 2
          ready in combat (FxEngine.ReadySet). The port's own, past SSI's 63 bytes: DiskRec never writes it and reads
          it as SET_NONE, and the .chx file keeps it (CharExt). In this variant only because a field may not follow
          the variant part; spells, 3 bytes, never reach it. }
        weaponSet: Byte);
      1: (
        { scroll spell slots }
        spells: array[1..3] of Byte);
  end;
  PBytes = ^TBytes;
  PImgBuf = ^TImgBuf;
  TArenaLoc = record
    { Arena coordinates. }
    x: ShortInt;
    y: ShortInt;
    { Registration slot stored by CombatSt. }
    slotIndex: Byte;
    { icon footprint, zero marks out of play }
    size: Byte;
  end;
  { constant rowBand entries }
  TBandRec = record
    { valid row range }
    lo: ShortInt;
    hi: ShortInt;
  end;
  TBrkSet = set of ' '..'?';
  TBytes = array[0..65000] of Byte;
  TColorMap = array[0..7] of Byte;
  { eight pixel colours, left to right: one scanline of a cell (VidOps.PutPixelRow) }
  TPixelRow = array[0..7] of Byte;
  TColorTab = array[0..15] of Byte;
  TCombatTarget = record
    { arena registration index }
    idx: Byte;
    { doubled walk distance from the acting creature }
    dist: Byte;
    { best facing direction }
    dir: Byte;
  end;
  { the creatures Pathing.BuildTargetList finds, nearest first (GameVars.targetList) }
  TTargetList = array[1..ARENA_SLOTS] of TCombatTarget;
  { a copy of the target list and its count, which a caller that builds a list of its own puts back after it
    (Pathing.SaveTargets, RestoreTargets) }
  TTargetSnapshot = record
    list: TTargetList;
    count: Byte;
  end;
  TIconCoordinateDelta = record
    { cell X offset; negative marks an absent footprint cell }
    dx: ShortInt;
    { cell Y offset }
    dy: ShortInt;
  end;
  TImgBuf = record
    { image height in pixels }
    height: Word;
    { image width in CHARS (x8 for pixels) }
    width: Word;
    { image placement X from DAX header }
    originX: Word;
    { image placement Y from DAX header }
    originY: Word;
    { images in buffer }
    count: Byte;
    { EGA->CGA colour map }
    map: TColorMap;
    { bytes in one image }
    imgSize: Word;
    { extra transparency space (default nil) }
    transp: PBytes;
    { the frames from count on, when one heap block cannot hold them all (Blit.AllocPic): VGA's wilderness tile sheets;
      nil otherwise }
    more: PImgBuf;
    { image data (open-ended) }
    data: array[0..32000] of Byte;
  end;
  TName15 = string[NAME_LEN];
  TRandomItemTemplate = record
    { low bytes copied to TItemRec nameIds (components 3, 2, 1) }
    nameIds: array[1..3] of Word;
    { copied to TItemRec weight (coins) and value (gold pieces) }
    weight: Word;
    value: Word;
    { low bytes copied to TItemRec charges/effect/special }
    properties: array[1..3] of Word;
  end;
  TRuleAge = record
    { years before the dice roll }
    base: Word;
    num: Byte;
    sides: Byte;
  end;
  TRuleGold = record
    { CharGen awards ten gold per point, averaged over the classes }
    num: Byte;
    sides: Byte;
  end;
  { racial ability limits (GameDefs.minimumMaximumStatistics) }
  TRuleRace = record
    { by gender }
    strMin: array[C_GENDER.MALE..C_GENDER.FEMALE] of Byte;
    strMax: array[C_GENDER.MALE..C_GENDER.FEMALE] of Byte;
    excMax: array[C_GENDER.MALE..C_GENDER.FEMALE] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;
  { thief abilities (ClassCal.ThiefSkillParts' thiefBase and raceAdj), by skill number or by name }
  TRuleThief = packed record
    case Byte of
      0: (values: array[1..8] of ShortInt);
      1: (pickPockets: ShortInt; openLocks: ShortInt; findTraps: ShortInt; moveSilently: ShortInt;
          hideShadows: ShortInt; hearNoise: ShortInt; climbWalls: ShortInt; readLanguages: ShortInt);
  end;
  { Dexterity adjustments to the first five thief abilities (ClassCal.ThiefSkillParts' dexAdj), by skill number or by
    name }
  TRuleThiefDex = packed record
    case Byte of
      0: (values: array[1..5] of ShortInt);
      1: (pickPockets: ShortInt; openLocks: ShortInt; findTraps: ShortInt; moveSilently: ShortInt;
          hideShadows: ShortInt);
  end;
  { classes a race can take (ClassCal.classesByRace), in class-menu order }
  TRuleRaceClasses = record
    count: ShortInt;
    { class IDs; 0 fills past count }
    classes: array[1..RACE_CLASSES_LAST] of ShortInt;
  end;
  { classLevels indexes a class trains (GameDefs.classParts), by position or by name; -1 fills a shorter list }
  TRuleClassParts = packed record
    case Byte of
      0: (values: array[1..3] of ShortInt);
      1: (first: ShortInt; second: ShortInt; third: ShortInt);
  end;
  { one value per ability (CharGen's raceAbilityAdj, ClassCal.ClassAbilityMin's classMin), by C_STAT index or by name }
  TRuleAbilities = packed record
    case Byte of
      0: (values: array[C_STAT.STRENGTH..C_STAT.CHARISMA] of ShortInt);
      1: (strength: ShortInt; intelligence: ShortInt; wisdom: ShortInt; dexterity: ShortInt; constitution: ShortInt;
          charisma: ShortInt);
  end;
  { one value per classLevels index (CharGen.ShowRaceInfo's raceMaxLevel), by index or by class name }
  TRuleClassLevels = packed record
    case Byte of
      0: (values: array[C_LEVEL.CLERIC..C_LEVEL.MONK] of ShortInt);
      1: (cleric: ShortInt; druid: ShortInt; fighter: ShortInt; paladin: ShortInt; ranger: ShortInt; mage: ShortInt;
          thief: ShortInt; monk: ShortInt);
  end;
  { the oldest age in each age category (CharGen.CreateCharacterMenu's ageThresholds), by category number or by name }
  TRuleAgeCategories = packed record
    case Byte of
      0: (values: array[1..5] of Word);
      1: (youngAdult: Word; mature: Word; middleAged: Word; old: Word; venerable: Word);
  end;
  { alignments a class can take (ClassCal.alignByClass), in alignment-menu order }
  TRuleClassAlignments = record
    count: ShortInt;
    { alignment IDs; 0 fills past count }
    alignments: array[1..9] of ShortInt;
  end;
  { saving throws (ClassCal.RecalcSaves' saveTbl), by C_SAVE index or by name }
  TRuleSaves = packed record
    case Byte of
      0: (values: array[C_SAVE.PARALYZE..C_SAVE.SPELL] of Byte);
      1: (paralyze: Byte; petrify: Byte; wand: Byte; breath: Byte; spell: Byte);
  end;
  TRuleXp = record
    { XP to reach level; -1 = unavailable }
    xp: array[2..C_LEVEL.LEVEL_LAST] of LongInt;
    { a cleric's or magic-user's slots at class level 2..9, by spell level }
    slots: array[2..9, 1..CASTER_LEVEL_LAST] of Byte;
  end;
  TSpecLoc = record
    x: Word;
    y: Word;
    icon: Word;
  end;
  TTerrainRec = record
    { movement cost multiplier and passability threshold }
    cost: Byte;
    { a line walk (Pathing.WalkLine) stops at a cell whose blocking is above 0 }
    blocking: Byte;
    { combat tile graphic index }
    tileId: Byte;
  end;
  TTurnUndeadTable = array[1..10, 1..10] of ShortInt;
  TViewSlotGeom = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  { one loaded-wallset cache slot (GameVars.wallSetCache) }
  TWallSetCacheSlot = record
    { cached WALLDEF reload ID; -1 invalidates the slot }
    wallDefId: Integer;
    { destination 8x8 slot, also invalidated with -1 }
    symbolSlot: Integer;
  end;

  { Game-memory (GBVM) zone types. }
  { the game clock's seven words, in C_TIME order (C_GBVM.CLOCK) }
  TClock = array[0..6] of Word;
  TGbvmClock = packed record
    case Byte of
      0: (values: TClock);
      1: (segment: Word; minute: Word; turn: Word; hour: Word; day: Word; month: Word; year: Word);
  end;
  TGbvmSavedWalls = packed record
    case Byte of
      0: (wallSetIds: array[1..3] of Word;
          symbolSlots: array[1..3] of Word);
      1: (menuPrefix: array[1..5] of Word;
          { Shares symbolSlots[3]. }
          menuAnimation: Word);
  end;
  TGbvmWord = packed record
    case Byte of
      0: (value: Word);
      1: (lo: Byte; hi: Byte);
  end;
  TGbvmZone0 = array[$4900..$4CFF] of Word;
  TGbvmZone0State = packed record
    case Byte of
      0: (words: TGbvmZone0);
      1: (bytes: array[0..2047] of Byte);
      2: (
        scriptWords4900: array[$4900..$49C2] of Word;
        partyX: TGbvmWord;
        partyY: TGbvmWord;
        mapId: TGbvmWord;
        clock: TGbvmClock;
        scriptWords49CD: array[$49CD..$49E4] of Word;
        antimagic: Word;
        view3dFlag: Word;
        mapGraphics1: Word;
        mapGraphics2: Word;
        scriptWords49E9: array[$49E9..$49EF] of Word;
        previousX: Word;
        previousY: Word;
        previousScriptId: Word;
        scriptWords49F3: array[$49F3..$49FA] of Word;
        noAutomap: Word;
        gameSpeed: TGbvmWord;
        skyCeilingColor: Word;
        alternateSkyColor: Word;
        { Bit 0 the portrait flag, bit 1 the monster-picture flag, bit 2 set for music off (clear in older saves). }
        settings: Word;
        { Cleared on a fresh script entry. }
        entryWords: array[$4A00..$4A1F] of Word;
        scriptWords4A20: array[$4A20..$4A7B] of Word;
        { Bit 3 enables the camp icon. }
        nomadCampFlags: Word;
        scriptWords4A7D: array[$4A7D..$4A8B] of Word;
        { C_GBVM.BUCCANEERS_BASE_VISIBLE: set by the script when the heir of Bivant quest is offered; Wilds shows the
          Buccaneer Base from it }
        buccaneersBaseVisible: Word;
        scriptWords4A8D: array[$4A8D..$4A9E] of Word;
        { Zero enables the camp icon. }
        nomadCampGate: Word;
        { Bits 0 and 1 hide the keep and caves. }
        easternSitesGate: Word;
        scriptWord4AA1: Word;
        yarashPyramidLeft: Word;
        scriptWords4AA3: array[$4AA3..$4AB2] of Word;
        yarashMissionDone: Word;
        scriptWords4AB4: array[$4AB4..$4AD1] of Word;
        { Nonzero enables the camp icon. }
        nomadCampPresent: Word;
        scriptWords4AD3: array[$4AD3..$4AF9] of Word;
        savedWalls: TGbvmSavedWalls;
        scriptWords4B00: array[$4B00..$4CFF] of Word);
  end;
  TGbvmZone1 = array[$6B00..$6EFF] of Word;
  { the script strings (GameVars.gbStrings) }
  TGbStrings = array[1..GB_STRING_LAST] of String;
  PGbStrings = ^TGbStrings;
  { the base item types (CharHlp.baseItems) and the zeroed overflow entry after them }
  TBaseItems = array[0..BASE_ITEM_OVERFLOW] of TBaseItemRec;
  PBaseItems = ^TBaseItems;

  { Menu and spell-aim types. }
  { A routine MenuCore.MenuHorizontal calls on every pass of its key wait. }
  TIdleProc = procedure;
  { A menu command, passed to the menu that runs it: Shop.CounterMenu's Buy or Heal. }
  TMenuAction = procedure;
  { The cells a spell reaches, for the spell-aim preview: a blast around the aim cell, Lightning Bolt's path from it, or
    Stinking Cloud's 2x2 block with the aim cell at its upper left. }
  TAimShape = (AimBlast, AimBolt, AimCloud);

  { Border types. }
  TCgaBank = array[0..99] of array[0..79] of Byte;
  TTandyBank = array[0..49] of array[0..159] of Byte;

  { Camp types. }
  PZone0State = ^TGbvmZone0State;

  { CbtActs types. }
  PAttackPhaseView = ^TAttackPhaseView;
  { Target-selection result. }
  TAimTarget = record
    { the creature (nil = bare cell) }
    cr: Pointer;
    { Arena cell. }
    x: ShortInt;
    y: ShortInt;
    { reserved }
    pad: Byte;
  end;
  { Arena cells in the order something visits them, such as the cells a lightning bolt crosses. }
  TCellList = record
    count: Byte;
    x: array[1..64] of ShortInt;
    y: array[1..64] of ShortInt;
  end;
  { Fills cells with the path of bolt spell spell aimed at (x, y): CbtMap.boltTracer. }
  TCellTracer = procedure(spell: Byte; x, y: ShortInt; var cells: TCellList);
  { Arena slots (GameVars.arenaLoc) in order, such as the creatures an aimed area spell will catch. }
  TSlotList = record
    count: Byte;
    slot: array[1..ARENA_SLOTS] of Byte;
  end;
  { Shows who the spell being aimed will catch, given them nearest first: CbtMap.aimReport. }
  TAimReport = procedure(var caught: TSlotList);
  { TCharRecord view: armor class and attacks as arrays. Its pad skips to acCur, past 17 pointers (effectsAddr,
    itemsAddr, the 13 equipped and nextCharAddr, combatAddr), each PTR_GROWTH bigger in a 64-bit build (TRecLay). }
  TAttackPhaseView = record
    { skips to acCur }
    fill: array[0..272 + 17 * PTR_GROWTH] of Byte;
    { Current and rear armor class. }
    acCurArr: array[0..1] of Byte;
    curAtt: array[1..2] of Byte;
  end;

  { CbtMap types. }
  PArena = ^TArena;
  TArena = record
    { reserved }
    pad0: Byte;
    pad1: Byte;
    { Upper-left cell of the view. }
    ox: ShortInt;
    oy: ShortInt;
    { draw the cursor sprite }
    cursorOn: Boolean;
    { cursor icon size }
    cursorSize: Byte;
    { line-walk distance mode (Pathing.WalkLine) }
    distMode: Byte;
    { terrain-info indices }
    cells: array[0..ARENA_LAST_Y, 0..ARENA_LAST_X] of Byte;
  end;

  { CharHlp types. }
  PAcAdjust = ^TAcAdjust;
  PBoolean = ^Boolean;
  { the parts of armour class CharHlp.RecalcStats adds up, by the AC_ constants }
  TAcAdjust = array[AC_DEX..AC_ARMOR] of ShortInt;

  { Spell types. }
  { A spell's duration in minutes, as CharHlp.SpellDuration gives it: count dice of sides, plus add, all times mult
    (rounds 1, turns 10, hours 60); count 0 for one that rolls nothing, add then holding the whole figure }
  TDurDice = record
    count: Byte;
    sides: Byte;
    add: Word;
    mult: Byte;
  end;
  TSpellRec = record
    case Integer of
      0: (
        { C_SPELL.CLASS_CLERIC, CLASS_MAGE, CLASS_DRUID or CLASS_SPECIAL (an item's, or no spell) }
        castClass: Byte;
        { spell level }
        level: Byte;
        { base range, 255 = attack roll }
        rangeFixed: Byte;
        { range per caster level }
        rangeVar: Byte;
        { base duration }
        durFixed: Byte;
        { duration per caster level }
        durVar: Byte;
        { the low nibble is the area mode (C_SPELL.AREA_MODE_*): 0 the caster, 1..7 (mode and 3) + 1 creatures picked
          one at a time, 8..14 everything within radius (mode and 7) of the aim, 15 one creature or a bare square
          (CbtActs.SelectCombatTargets, CharHlp.SpellArea); no code reads the high nibble }
        area: Byte;
        { targeting mode }
        target: Byte;
        { what a save does: C_SPELL.SAVE_NONE, SAVE_NEGATES, SAVE_HALF or SAVE_SPECIAL (Magic.ResolveSpell) }
        saveResult: Byte;
        { saving-throw column 0..4 }
        saveType: Byte;
        { effect id added on a hit }
        effect: Byte;
        { 0 noncombat / 1 combat / 2 either }
        whenCast: Byte;
        { casting time }
        castTime: Byte;
        { 0..7, 0 = AI never casts }
        aiPriority: Byte;
        { 1 = offensive }
        offensive: Byte;
        { friendly-fire scan radius }
        aiRadius: Byte);
      1: (
        { Signed class and level view. }
        castClassSp: ShortInt;
        levelSp: ShortInt);
  end;

  { Combat types. }
  PZone1 = ^TGbvmZone1;

  { CombatSt types. }
  TPortSlot = record
    pictureId: Byte;
    pic: PImgBuf;
    { virtual disk pictureId was loaded from }
    disk: Byte;
  end;

  { DaxIo types. }
  PByteArr = ^TByteArr;
  TStr20 = string[20];
  TByteArr = array[0..65534] of ShortInt;

  { Video driver types (phase 6 of docs/refactor-plan.md). }
  { one 8-pixel cell row of a picture in a single colour, in the video mode's layout (its first 1 shl cellShift bytes) }
  TCellBytes = array[0..7] of Byte;
  TCellFillProc = procedure(color: Byte; var colorMap: TColorMap; var cell: TCellBytes);
  TVideoProc = procedure;
  TSetPaletteProc = procedure(registerIndex, color: Byte);
  TShowPicProc = procedure(screenX, screenY: Integer; pic: PImgBuf);
  { a game-font glyph in a character cell: its set pixels in fg (ink), its clear pixels in bg (paper) }
  TDrawGlyphProc = procedure(col, row, fg, bg, glyph: Byte);
  TClearRectProc = procedure(ulCol, ulRow, lrCol, lrRow: Byte);
  TWriteCharProc = procedure(col, row, attr, count, ch: Byte);
  { count pixels from src onto the fine screen from pixel (x, layout line y) rightwards }
  TPutPixelsProc = procedure(x, y: Word; var src; count: Word);
  { An 8-pixel cell row as DAX stores it: two pixels to a byte, the first in the high nibble. }
  TChunk = array[0..3] of Byte;
  TExpandChunkProc = procedure(var chunk: TChunk; mask: Byte; pic: PImgBuf; at: Word);
  TMirrorFrameProc = procedure(src, dst: PImgBuf);
  TRemapColourProc = procedure(pic, scratch: PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte;
                               isDithered: Boolean);
  TRecolorFrameProc = procedure(var toT: TColorTab; pic: PImgBuf);
  TPutPixelRowProc = procedure(pic: PImgBuf; at: Word; y: Byte; var px: TPixelRow);
  { Load a tune into a sound device's voices; tune 0 silences them. }
  TSoundPlay = procedure(tune: Word);
  { One sound device's driver (docs/refactor-plan.md, phase 7): SoundDrv reaches the device only through it. GameBoot
    installs one from POOL.CFG's sound letter (SndTdy, SndSpk, SndOpl, SndSb, SndNone; natively always SndDig) into
    GameVars.sound. }
  TSoundDriver = record
    { the device's name, for the settings screen }
    name: TStr20;
    { the sequencer's device value (a C_SOUND.MODE_ constant), which SetSoundDevice takes and soundMode holds while
      sound is on }
    mode: Byte;
    { load a tune into the device's voices }
    Play: TSoundPlay;
    { a step in the 3D map plays its footstep once, not twice as SSI's code does (Explore.MovePartyForward3D and
      EclVm.GameLoop): set for the recorded steps (the Sound Blaster, and SndDig natively), which sound wrong doubled,
      and clear for the speaker, the Tandy and the AdLib, whose double tick is kept (POR-0170) }
    singleStep: Boolean;
  end;
  { The video mode as the rest of the game sees it: the picture layout's numbers, what the mode can show, and its
    routines. GameBoot installs one (VidCga, VidEga, VidTdy or VidVga) into GameVars.video. }
  TVideoDriver = record
    { the mode's name, for the settings screen }
    name: TStr20;
    { the colours shown at once: 4 on CGA (each picture's colour map picks them), 16 on EGA, Tandy and VGA }
    colours: Byte;
    { palette registers SetPaletteRegister can program (EGA, VGA) }
    hasPalette: Boolean;
    { transparency by colour key (VGA): a transparent pixel holds PIC_KEY, and the mask, one bit a pixel, is kept but
      not used to draw; otherwise a transparent pixel is 0 under a set mask bit }
    keyed: Boolean;
    { The layout as shift counts, since the 8086 shifts in a few cycles where it multiplies or divides in a hundred: }
    { picture bytes in one cell row, 1 shl cellShift: 2 on CGA (2 bits a pixel), 4 on EGA (a byte a plane) and Tandy (4
      bits a pixel), 8 on VGA (a byte a pixel) }
    cellShift: Byte;
    { screen bytes one cell column takes on a scanline, 1 shl screenShift, the unit of the dirty spans' screen offsets:
      2 on CGA, 1 on EGA (each plane's byte at one address), 4 on Tandy, 8 on VGA }
    screenShift: Byte;
    { picture bytes one transparency-mask byte covers, 1 shl maskShift: 4 on EGA (a cell row's planes), 8 on VGA (a cell
      row's pixels), 1 on CGA and Tandy }
    maskShift: Byte;
    { a cell row filled with color: colorMap picks CGA's colour }
    CellFill: TCellFillProc;
    { the BIOS video mode (INT 10h AH=0) }
    biosMode: Byte;
    { paragraphs of conventional memory the screen takes at the top of RAM, which the heap must leave alone: Tandy's
      video memory is system RAM }
    ramVideoParas: Word;
    { set up the mode once the BIOS has set it (EGA's display pages) }
    Start: TVideoProc;
    { copy the view buffer's dirty spans (GameVars.span*) to the screen; Blit.FlushView then clears the spans }
    FlushSpans: TVideoProc;
    { draw a picture's first frame straight to the screen at a cell position (Blit.ShowPic) }
    ShowPic: TShowPicProc;
    { draw game-font glyph glyph at a text cell in a colour (TextRend.RenderChar) }
    DrawGlyph: TDrawGlyphProc;
    { clear a text-cell rectangle, already checked to lie on the 40 x 25 screen, to black (TextRend.ClearRect) }
    ClearRect: TClearRectProc;
    { clear the whole screen to black }
    ClearScreen: TVideoProc;
    { BIOS text output: count copies of ch in attr at a text cell (DaxIo.WriteChar) }
    WriteChar: TWriteCharProc;
    { The cold entries, in the mode's overlaid Pic unit (PicCga, PicEga, PicTdy, PicVga): }
    { store one DAX cell row (4 bits a pixel) at pic^.data[at] in pic's layout and, when pic has a mask, its mask bits
      (a bit a pixel, bit 7 the first, from VidOps.ComputeMask) at the mask byte for at (VidOps.ExpandPicFrames) }
    ExpandChunk: TExpandChunkProc;
    { a left-right reflection of src's first frame and mask into dst (Blit.MirrorPic, which copies the colour map) }
    MirrorFrame: TMirrorFrameProc;
    { one colour pair of Blit.RemapPic: fromC becomes toC in nFrames frames of pic from srcOff, written into scratch }
    RemapColour: TRemapColourProc;
    { every pixel of pic's first frame to the colour toT gives its own (VidOps.RecolorPic) }
    RecolorFrame: TRecolorFrameProc;
    { 8 pixel colours into scanline y of the one-cell-wide frame at pic^.data[at] (VidOps.PutPixelRow) }
    PutPixelRow: TPutPixelRowProc;
    { build the mode's per-row screen addresses (GameVars.bankRowSeg or fbRowOfs) }
    InitRowTables: TVideoProc;
    { give palette register registerIndex the colour color (Blit.SetPaletteRegister; EGA's registers, VGA's DAC) }
    SetPalette: TSetPaletteProc;
    { The screen is 640 x 400 or 640 x 480 (VidVesa, #1231): the entries above draw the 320 x 200 layout at 2 x 2, and
      these draw at the screen's own pixels, on 400 layout lines, its text on an 80 x 50 grid of 8 x 8 cells. Clear,
      and these nil, in the other modes. }
    fine: Boolean;
    { the fine grid's last row: 49 on the 640 x 400 layout, 59 where a strip of 10 rows lies under it (640 x 480
      squashed) }
    fineLastRow: Byte;
    { a glyph in a cell of the 80 x 50 grid, as DrawGlyph's }
    DrawFineGlyph: TDrawGlyphProc;
    { clear a rectangle of the 80 x 50 grid, already checked to lie on it, to black }
    ClearFineRect: TClearRectProc;
    { a run of pixels on one layout line of the screen (CbtMini's map) }
    PutPixels: TPutPixelsProc;
  end;

  { EclMenu types. }
  PEclRet = ^TEclRet;
  PZone2 = ^TZone2;
  PZone3 = ^TZone3;
  TEclRet = record
    { return GBVM address }
    addr: Word;
    { node below }
    next: PEclRet;
  end;
  TMonFlags = array[0..1] of Boolean;
  TZone2 = array[$9700..$98FF] of Word;
  { the script buffer (C_GBVM.SCRIPT_FIRST..SCRIPT_LAST) }
  TZone3 = array[C_GBVM.SCRIPT_FIRST..C_GBVM.SCRIPT_LAST] of Byte;

  { EffHndlr types. }
  TEffectHandler = procedure(creature: PCharRecord; effectData: Pointer;
                             removed: Boolean);

  { GameBoot types. }
  THeapEndW = record
    o: Word;
    s: Word;
  end;

  { MenuCore types. }
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

  { Money types. }
  TMoney = array[C_MONEY.COPPER..C_MONEY.JEWELRY] of LongInt;

  { Pathing types. }
  TPathReq = record
    { start / end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { Bresenham error term }
    err: Integer;
    { Abs(ex - sx) }
    adx: Integer;
    { Abs(ey - sy) }
    ady: Integer;
    { error bump on a diagonal step }
    incD: Integer;
    { error bump on a straight step }
    incS: Integer;
    { x step sign (-1/0/1) }
    stepX: ShortInt;
    { y step sign (-1/0/1) }
    stepY: ShortInt;
    { Current line position. }
    cx: Integer;
    cy: Integer;
    { doubled distance walked }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;

  { Portrait types. }
  TAnimFrame = record
    { how long the frame shows, in tenths of a second: the frame header's first four bytes, as in the file }
    time: LongInt;
    pic: PImgBuf;
  end;
  { A PIC or SPRIT animation (GameVars.animData, the ending's), as Portrait.LoadAnimation loads it. }
  TAnimRec = record
    { frames actually loaded }
    count: Byte;
    { the frame showing, 1-based; LoadAnimation starts it at 1 }
    current: Byte;
    frames: array[1..8] of TAnimFrame;
  end;
  TStr8 = String[8];

  { Magic types. }
  PCloudRec = ^TCloudRec;
  TCastUi = procedure(spell: Byte; b: Boolean; var sel: Boolean);
  TSpellProc = procedure;
  { A lingering cloud on the combat map, one node per casting on the GameVars.cloudHead list: a Stinking Cloud's 2x2
    block or a Cloudkill's 3x3 (#1193). Cell i (1..side * side) is CbtMap.CloudCell's; under keeps the ground beneath it
    and exists marks a cell the cloud could fill. }
  { a cloud's cells, 1..side * side, as TCloudRec holds them }
  TCloudCells = array[1..9] of Byte;
  TCloudRec = record
    caster: PCharRecord;
    next: PCloudRec;
    under: TCloudCells;
    exists: TCloudCells;
    { the aim cell }
    ulX: ShortInt;
    ulY: ShortInt;
    { the cloud's number, unique among its caster's clouds of either kind (FxEngine.FreeCloudNumber), matched against
      its Cast Stinking Cloud or Cast Cloudkill effect's strength div 16 }
    idx: Byte;
    { the terrain its cells show, C_TERR.STINKING_CLOUD or C_TERR.CLOUDKILL, and its side, C_SPELL.STINKING_CLOUD_SIDE
      or CLOUDKILL_SIDE }
    terrain: Byte;
    side: Byte;
  end;

  { TextRend types. }
  PFontArr = ^TFontArr;
  TCgaRow = array[0..39] of Word;
  TFontArr = array[0..176] of array[0..7] of Byte;
  TTdyRow = array[0..159] of Byte;

  { View3D types. }
  PGeoMap = ^TGeoMap;
  PWallSlices = ^TWallSlices;
  TGeoPlane = array[0..MAP_LAST, 0..MAP_LAST] of Byte;
  TGeoMap = record
    { N = high nibble, E = low }
    wallsNE: TGeoPlane;
    { S = high nibble, W = low }
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    { 2 bits per facing }
    barriers: TGeoPlane;
  end;
  { one WALLDEF block: a wall set's 5 wall types, 156 symbols each }
  TView3dWallDef = array[1..5, 0..155] of Byte;
  { the three wall-set slots' 15 wall types in a row: slot s holds wall types 5s - 4 .. 5s }
  TWallSlices = array[1..15, 0..155] of Byte;

{ True when square (x, y) lies on a 3D map, 0..MAP_LAST each way: the one bound Explored, ClueBook and MapNotes keep. }
function OnMap(x, y: Integer): Boolean;

implementation

function OnMap(x, y: Integer): Boolean;
begin
  OnMap := (x >= 0) and (x <= MAP_LAST) and (y >= 0) and (y <= MAP_LAST);
end;

end.
