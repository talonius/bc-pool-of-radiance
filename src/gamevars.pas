{ Global variables: every variable in the data segment, in link order. A new section starts wherever the data needs a
  word boundary. }
{$I COMPILER.INC}
unit GameVars;

interface

uses Types, Dos, C_ECL, C_EFFECT, C_SPELL, C_TILE{$IFDEF FPC}, Host{$ENDIF};

var
  { The video driver GameBoot installed for the video mode (Types.TVideoDriver). }
  video: Types.TVideoDriver;
  { the sound driver GameBoot installed }
  sound: Types.TSoundDriver;
  { Play session }
  { GameBoot writes 0/1, Intro tests zero }
  fullIntro: Boolean;
  { word bank }
  zone0: Types.PZone0State;
  { GBVM zone 1, indexed directly by GBVM address (the zone-1 GBVM_ constants) }
  { word bank }
  zone1: Types.PZone1;
  { word bank }
  zone2: Types.PZone2;
  { script bytes }
  zone3: Types.PZone3;
  { game speed, 0 = fastest 9 = slowest; a setting in POOLOPT.CFG, and SaveLoad writes it to the GBVM gameSpeed word }
  gameDelay: Byte;
  { Five GBVM addresses loaded from the ECL entry header. [1] runs before movement and after on-load; [2] search/Look;
    [3] pre-camp; [4] camp interruption; [5] on-load }
  { ECL entry GBVM addresses }
  scriptEntryAddrs: array[1..C_ECL.ENTRY_COUNT] of Word;
  { ECL instruction pointer into zone3 }
  eclIp: Word;
  { Interface state, one of the IFC_ constants of C_IFC and Ending }
  ifcState: Byte;
  { the Portraits setting, over the two below: zero shows neither (#835) }
  portraitsAll: Byte;
  { the Character Portraits setting: zero disables ViewChar's disk-3 portrait branch }
  portraitsOn: Byte;
  { the Monster Portraits setting: zero skips the close-up load when inEncMenu is nonzero }
  monsterPics: Byte;
  { the Music setting: zero makes SoundDrv.PlayMusic do nothing }
  musicOn: Byte;
  { the tunes the Music setting plays, C_SOUND.GROUP_TITLE_MUSIC and GROUP_BATTLE_MUSIC bits }
  musicGroups: Byte;
  { the sound effects the Sound setting plays of those turned on and off by kind, C_SOUND.GROUP_FOOTSTEPS.. bits }
  soundGroups: Byte;
  { the Sound setting: zero starts the game with sound off (soundMode disabled); GameIo.SetSound keeps it in step }
  soundOn: Byte;
  { the Auto Join setting: nonzero has a stackable item join its like as it comes into an inventory
    (CharHlp.AddToInventory, #1088) }
  autoJoinOn: Byte;
  { the Consolidate Coin setting: nonzero changes a character's purse into the fewest coins of its value whenever it
    picks coins up (Money.Consolidate, #1179) }
  consolidateOn: Byte;
  { the Journal setting: nonzero lists only the items the party has found (JrnlSeen), zero every item (#1090) }
  journalFoundOn: Byte;
  { the Non-Human Level Cap setting: nonzero applies the racial level limits (CharHlp.AtLevelCap), zero lets the
    demihumans train as far as the experience table goes (#1176). It starts zeroed, as off, until GameInit applies the
    settings' defaults; a test of the caps sets it. }
  nonHumanCapOn: Byte;
  { the Game Level Cap setting: nonzero stops each class at SSI's highest level, zero lets every class train to 9
    (ClassCal.MaxLevel, #1121) }
  levelCapOn: Byte;
  { the Train Anywhere setting: nonzero lets F4 open the training hall's menu outside combat (CharGen.TrainAnywhere,
    #1212) }
  trainAnywhereOn: Byte;
  { True while that menu runs: CharHlp.HallMask then trains every class, and the hall's own GBVM word
    (C_GBVM.TRAIN_CLASS_MASK) is left as the script set it }
  trainingAnywhere: Boolean;
  { nonzero: PostCbt and SaveLoad.LoadChar take the party's characters off Quick after each fight and on loading }
  quickEnds: Byte;
  { the Quick Mode Magic setting: CombatSt starts every fight with quickMagic set from it; Alt-M then turns quickMagic
    over for that fight only }
  quickMagicOn: Byte;
  { the Allow Gear Changes setting, under Quick Mode: zero keeps CombatAi.EquipWeaponAndShield from changing the
    weapon or shield of a creature that comes under the player (#1127) }
  gearChangesOn: Byte;
  { the Aim Cycles setting: nonzero (ENEMIES) has the aim menu's Next and Prev reach the other side only, or the
    creature's own side for a spell that is not offensive; zero (ALL) every creature, as SSI's did (#1137) }
  aimEnemiesOn: Byte;
  { the Retrieve Thrown setting: nonzero gives each single thrown weapon back to its thrower after the fight
    (PostCbt, CbtActs.ReturnThrown, #1118) }
  retrieveThrownOn: Byte;
  { the Minimap setting, which F3 on the combat menu turns over: nonzero draws the whole arena in the combat panel
    (CbtMini, #1210) }
  minimapOn: Byte;
  { the Wide View setting: nonzero gives each fight the full-width combat view, the creature and the messages on three
    lines under it (CombatSt.CombatStart, CbtMap.SetLayout, #1211) }
  wideCombatOn: Byte;
  { the Companion Tools setting: nonzero lets F6 open the Tools screen outside combat (phase 8) }
  companionOn: Byte;
  { the Clue Book Notes setting, under the Companion Tools: nonzero shows the Clue Book's map keys on their map (#856) }
  clueNotesOn: Byte;
  { the Auto Memorize setting: nonzero has Rest queue each caster's usual spells when it has none pending (#1119) }
  autoMemorizeOn: Byte;
  { the Fix settings (#1129): nonzero lets Fix use scrolls, potions, a paladin's cure and a paladin's laying on of
    hands for what the clerics' spells leave }
  fixScrollsOn: Byte;
  fixPotionsOn: Byte;
  fixCureOn: Byte;
  fixHealOn: Byte;
  { the Combat Log setting: nonzero keeps the fight's messages for F7 in combat, when CbtLog.Usable (#841) }
  combatLogOn: Byte;
  { the Log Lines setting: how many messages the combat log keeps, CbtLog.MIN_ENTRIES..MAX_ENTRIES }
  combatLogLines: Byte;
  { GameInit clears it; GameIo toggles it on STING Ctrl-D; nonzero enables PrintHpDebug }
  stingHpFlag: Byte;
  { Started as START STING: the debug keys and cheats are on. GameBoot sets it before anything reads a key. }
  stingArg: Boolean;
  { Started with NORAND as the second argument: the random numbers are seeded with 1. GameBoot sets it with stingArg. }
  norandArg: Boolean;
  { Started with ADVISE after STING: the startup advisory runs as it does without STING, which skips it (#1173), so a
    scenario can see it. GameBoot sets it with stingArg. }
  adviseArg: Boolean;
  { Started with DEMO: the first time, the start-up menu starts the demo (#1109) after a moment rather than its usual
    wait. GameBoot sets it, and Demo.Run clears it. }
  demoArg: Boolean;
  { The demo (#1109) is running: its script plays the game with a party of its own, and no menu waits for a key.
    demoAbort is set once it is to end, by a key (GameIo.DemoEnding); the key is left pending for Demo.Run to drain. }
  demoMode: Boolean;
  demoAbort: Boolean;
  { STING Ctrl-L (#612): the script trace log is open; each opcode's mnemonic goes to debugFile (debug.txt), and Ctrl-Z
    writes the creatures' effects there }
  debugTraceEnabled: Boolean;
  { overlay loads since the program started, counted by GameBoot's OvrReadBuf hook (#612) }
  ovrLoads: LongInt;
  { the overlays load from EMS (GameBoot's OvrInitEMS succeeded) rather than from GAME.OVR on disk }
  ovrInEms: Boolean;
  { set when GameIo has written over the bottom line (the STING Ctrl-Y pop-up); MenuCore.HorizontalMenu redraws its
    menu line and clears it }
  bottomLineTaken: Boolean;
  { main-menu load handoff; EclVm skips reload, EclMenu clears it }
  loadedSave: Byte;
  { Party location type, previous (as below) }
  locTypePrev: Byte;
  { Party location type, current }
  gLocType: Byte;
  partyDefeated: Boolean;
  { Delay in printing message to message window }
  msgDelayFlag: Byte;

var
  { Video registers, pages and modes; view and icon buffers, dirty spans and row tables }
  { Register record handed to Dos.Intr (Host.Intr natively) for BIOS video calls; every unit calling the BIOS uses this
    one record. }
  interruptRegisters: Registers;
  { Currently displayed EGA page number (always 0) }
  pageMain: Byte;
  { BIOS mode queried at init, then the mode active before the latest Blit.SetVideoMode call; RestoreVideoMode returns
    to it. }
  savedVideoMode: Byte;
  { BIOS mode queried at init, then the mode most recently requested through Blit.SetVideoMode. }
  curVideoMode: Byte;

var
  { Off-screen 168x168 view buffer that the compositors draw into and Blit.FlushView copies to the screen; GameInit
    allocates it. }
  viewBuffer: Types.PImgBuf;
  { Backdrop buffer that Blit.BlitTileClipped fills with the destination bytes it is about to cover (when the save flag
    is set), so CharHlp can restore the background afterwards. }
  saveUnder: Types.PImgBuf;
  { Dirty-span tables, one slot per view scanline (21 character rows x 8 = 168); GameInit initializes all four. }
  { Nonzero when that view scanline holds changes that Blit.FlushView still has to copy to the screen. }
  spanActive: array[0..167] of Byte;
  { Horizontal byte offset in video memory where the dirty span begins; the screen-side counterpart of spanFirstOfs. }
  spanScreenOfs: array[0..167] of Word;
  { Offset of the first dirty byte in the view buffer's image data. Reset to $FFFF when clean so any new span compares
    as earlier. }
  spanFirstOfs: array[0..167] of Word;
  { Offset of the last dirty byte (inclusive) in the view buffer's image data. Reset to 0 when clean so any new span
    compares as later. }
  spanLastOfs: array[0..167] of Word;
  { Video segment for each scanline in a banked mode, precomputed so row writes need no bank arithmetic: CGA's even and
    odd rows interleave between the B800 and BA00 banks, Tandy's rows go round its four banks from B800. }
  bankRowSeg: array[0..199] of Word;
  { Offset into the video segment for each scanline in EGA (rows 40 bytes apart) and VGA (320). }
  fbRowOfs: array[0..199] of Word;

var
  { Sound mode }
  { Active sound device, a C_SOUND.MODE_ value: the mode of the driver GameBoot installs for POOL.CFG's second line. }
  soundMode: Byte;
  { Disks, directories and the DAX buffer }
  { current resource disk; saved by SaveLoad }
  diskIndex: Byte;
  { Save directory from line 4 of POOL.CFG. }
  saveDirectory: Types.TPathStr;
  { POOL.CFG line 3, the game directory; gameDir[1] is its drive letter }
  gameDir: Types.TPathStr;
  { Flag for suppressing insert disk prompt }
  suppressDiskPrompt: Boolean;
  { Set by SaveLoad once a save completes; HeapErr and the Exit to DOS loop use it to tell whether a save succeeded. }
  recentlySaved: Byte;
  { Party pointers }
  { Current creature. }
  curChar: Types.PCharRecord;
  { Pointer to linked list of creatures }
  creatureList: Types.PCharRecord;
  { The current character before a script step, LOAD CHARACTER or a script switch; the scripts' EXIT and PROGRAM and
    EclVm.NewEclDone make it current again. SaveLoad.RemoveCreature moves it off the record it frees. }
  savedChar: Types.PCharRecord;
  { last missile item added to the treasure list in combat }
  lastMissileItem: Types.PItemRec;
  { Font and text cursor }
  { Pointer to font. Each entry in the font table is 8 bytes }
  gameFont: Types.PFontArr;
  { Text cursor shared by TextRend's message window and slow-text output }
  { Current char column. (Equivalent of WhereX.) }
  curCol: Byte;
  { Current char row. (Equivalent of WhereY.) }
  curRow: Byte;
  { Symbol sets and map tile sets }
  { the six 8x8 symbol-set images, by set id 0..5: Sym8x8.Load8x8Set loads an 8X8D picture into a slot and Put8x8Sym
    draws from it; set 5 is the scroll bar's (Sym8x8.LoadScrollBar), nil when the archive has none }
  symbolSetPtrs: array[0..5] of Types.PImgBuf;
  { Pointer to current 8x8 symbol image buffer }
  sym8x8Buf: Types.PImgBuf;
  { 2D map tile set image buffer 1 }
  mapTilePtr: Types.PImgBuf;
  { Icon images }
  { Animation images for creature, death and cursor icons. }
  iconAnimation: array[0..C_TILE.ICON_LAST, 0..1] of Types.PImgBuf;
  { Combat arena }
  { next registration slot, inclusive scan limit }
  arenaCount: Byte;
  { icon location and size per slot }
  arenaLoc: array[1..Types.ARENA_SLOTS] of Types.TArenaLoc;
  { creature per slot }
  creatureArr: array[1..Types.ARENA_SLOTS] of Types.PCharRecord;
  { corpses on the arena }
  downed: array[1..Types.DOWNED_SLOTS] of Types.TDownedRec;
  { append and scan limit; cleared entries leave holes }
  downedCount: Byte;
  { allocated combat viewport, borrowed by renderers }
  arenaPtr: Types.PArena;
  { Pathing's potential-target count }
  targetCount: Byte;
  { sorted by distance and facing }
  targetList: Types.TTargetList;

var
  { Treasure }
  { copper through jewelry }
  treasureMoney: Types.TMoney;
  { consumers use PItemRec views }
  treasureItems: Types.PItemRec;
  { Combatants per side }
  { combat ends when a side is empty }
  teamCount: array[0..1] of Byte;
  { Effect resolution }
  { effect ID, cleared when immune }
  pendingEffectId: Byte;
  { damage before hit-point subtraction }
  pendingDamage: Byte;
  { C_EFFECT.ELEM_*: 1 fire, 2 cold, 4 electricity, 8 magic, 16 acid; 32 poison, 64 disease, 128 blood drain }
  elementMask: Byte;
  { current attack *or* current movement times 2 }
  currentAttackCurrent: Byte;
  { spell being cast }
  spellId: Byte;
  { dice count of the current damage roll; Burning Hands, which rolls none, sets it to 1. The fire protections and the
    mummy's fire vulnerability work per die. }
  gDamageDice: Byte;
  { 1 while calculating movement }
  currentCreatureCalculatingFlag: Byte;
  { Effect lock. }
  effectLock: Byte;
  { the spell affects multiple targets }
  gMultiTarget: Byte;
  { redraw the inventory menu }
  invRedraw: Byte;
  { the attack roll as effects modify it; signed, as penalties can take it below 0 }
  gAttackRoll: ShortInt;
  { an effect (Blink, Displacement, an avoided missile) forced the attack to miss }
  forcedMiss: Boolean;
  { current morale }
  combatMorale: Byte;
  { creature this one is interacting with }
  combatTarget: Types.PCharRecord;

var
  { Effect dispatch }
  { effect handlers, indexed by effect id }
  effectFns: array[C_EFFECT.BLESS..C_EFFECT.LAST_ID] of Types.TEffectHandler;
  { 3D view }
  { four 256-byte GEO planes; View3D/Explore views }
  map3d: Types.PGeoMap;
  { Map position, wall cache, animation and portrait cache }
  { automap shown in place of the 3D view }
  automapOn: Boolean;
  { Current map column; signed for edge and wrap checks. }
  gMapX: ShortInt;
  { Current map row. }
  gMapY: ShortInt;
  { Current party facing direction. }
  gFacing: Byte;
  { Wall at the current square in the facing direction. }
  wallAhead: Byte;
  { Event byte at the party's square; bit 7 is a flag, not a wall }
  eventAtCell: Byte;
  wallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { the picture animation showing (PIC or SPRIT) }
  animData: Types.TAnimRec;
  { HEAD and BODY image caches. }
  portraits: array[1..2] of Types.TPortSlot;
  { Menu state }
  { Zero-based position of the first visible list entry. }
  verticalMenuTop: Integer;
  { Current horizontal menu choice, starting at 1. }
  horizChoice: Byte;

var
  { Spell casting and targeting }
  { the cast-target menu: Magic.NoncombatCastTargetMenu, or CbtActs.SelectCombatTargets in combat }
  castTargetMenu: Types.TCastUi;
  { Spell handlers indexed by spell ID. }
  spellFns: array[1..C_SPELL.TABLE_LAST] of Types.TSpellProc;
  { Number of targeted creatures }
  spellTargetCount: Byte;
  { Selected target creatures. }
  spellTargets: array[1..Types.ARENA_SLOTS] of Types.PCharRecord;
  { Remembered noncombat spell target, initially the caster. }
  castTarget: Types.PCharRecord;
  { the clouds on the combat map, Stinking Clouds' and Cloudkills' (Types.TCloudRec) }
  cloudHead: Types.PCloudRec;
  usingItem: Boolean;

var
  { Rest and healing }
  { Suppress the window border. }
  suppressDrawingBorderFlag: Byte;

var
  { Combat round }
  { Combat round counter, 0-indexed }
  roundCounter: Byte;
  { Potential-target creature indices. }
  combatTargetSlots: array[1..Types.ARENA_SLOTS] of Byte;
  { quick combat magic; toggled by Alt-M }
  quickMagic: Boolean;
  { The combat moving-icon sheet: CombatSt allocates it, CharHlp copies icon facings in and draws from it, Combat frees
    it }
  moveIconSheet: Types.PImgBuf;
  { ECL color selectors }
  { Script-controlled wall color; script writes request a view redraw. }
  wallColorSel: Byte;
  { Script-controlled ceiling and floor color; writes request a view redraw. }
  ceilFloorColorSel: Byte;
  { ECL interpreter }
  { Top ECL return-stack node. }
  scriptReturnStack: Types.PEclRet;
  { Previous ECL return-stack node. }
  prevScriptReturnStack: Types.PEclRet;
  { Current ECL opcode }
  curOpcode: Byte;
  { ECL variables and strings }
  { Decoded ECL variable types. }
  varTypes: array[1..64] of Byte;
  { High bytes of decoded ECL variables. }
  varHi: array[1..64] of Byte;
  { Low bytes of decoded ECL variables. }
  varLo: array[1..64] of Byte;
  { Script string buffers, on the heap; GameInit2 allocates and clears them. }
  gbStrings: Types.PGbStrings;
  { ECL monster and post-combat state }
  { With dumpCr6B00, ECL LOAD CHARACTER with bit 7 removes the creature; set when a script writes 0 to
    C_GBVM.CHAR_ENABLED (EclVars.SpecialWriteZ1) }
  dumpCr6C00: Boolean;
  { With dumpCr6C00, ECL LOAD CHARACTER with bit 7 removes the creature; set when a script writes 0 to C_GBVM.CHAR_DUMP
    (EclVars.SpecialWriteZ1) }
  dumpCr6B00: Boolean;
  duelFlag: Boolean;

var
  { ECL flags }
  { ECL script ID }
  eclScriptId: Byte;
  { ECL currently displaying graphics flag }
  eclGraphics: Boolean;
  { ECL displaying monster sprite flag }
  sprShown: Boolean;
  { Set when a script changes a view color selector; MapView then applies them }
  picRegionW: Boolean;
  { Currently in ECL opcode 29 ENCOUNTER MENU flag. It stays the last variable: the initialization clears from video
    through it. }
  inEncMenu: Byte;

implementation

{ Every variable here starts at zero, as the game and the tests take them to. Turbo Pascal clears no variable: each
  starts with whatever its memory held, which another program run before may have dirtied (#826). Its variables lie in
  one block in the order declared, video first and inEncMenu last, so one FillChar clears them all. Free Pascal clears
  its variables itself. }
begin
{$IFNDEF FPC}
  FillChar(video, Ofs(inEncMenu) - Ofs(video) + SizeOf(inEncMenu), 0);
{$ENDIF}
end.
