{ Startup configuration: initialize the overlay manager, find the combat log's store, read POOL.CFG (through CfgFile,
  running the set-up program POOLCFG first when there is none or it is damaged, #876), select the video mode and
  reserve graphics memory. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit GameBoot;

interface

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Types, C_OPT, CfgFile, GameVars, Crt, Dos,
  {$IFNDEF FPC}Overlay, {$ENDIF}Blit, SoundDrv, DaxIo, FileUtil, GameIo, CbtLog,
  {$IFNDEF FPC}VidCga, VidEga, VidTdy, VidVesa, {$ENDIF}VidVga,
  {$IFDEF FPC}SndDig{$ELSE}SndTdy, SndSpk, SndOpl, SndSb, SndNone{$ENDIF}
  {$IFDEF FPC}, Host, GameDirs, DataPick{$ENDIF};

var
  { POOL.CFG's video, sound and introduction letters, as START takes them (CfgFile.ReadPoolCfg) }
  cfgVideo: Char;
  cfgSound: Char;
  cfgIntro: Char;

const
  { graphics memory reserve: 16 KB in paragraphs }
  GFX_RESERVE_PARAS = 1024;
  OVERLAY_BUF_BYTES = 100352;

{ The native build has no overlays, no EMS and no HeapEnd to lower: its heap grows as it needs. }
{$IFNDEF FPC}
var
  heapEndW: Types.THeapEndW absolute HeapEnd;
  { the overlay manager's own read routine, which CountOvrRead calls }
  ovrRead: OvrReadFunc;

{ The overlay manager's read routine (OvrReadBuf), counting each overlay it loads in GameVars.ovrLoads (#612). }
function CountOvrRead(ovrSeg: Word): Integer;
begin
  Inc(GameVars.ovrLoads);
  CountOvrRead := ovrRead(ovrSeg);
end;

{ A POOL.CFG path made ready for file names to be appended (CfgFile.NormalizePath). A path that leaves no room for a
  file name within a DOS path stops the game with a message. Natively NativeFolders places the folders instead. }
function NormalizePath(path: String): String;
var
  full: String;
begin
  if not CfgFile.NormalizePath(path, full) then begin
    Blit.RestoreVideoMode;
    WriteLn('POOL.CFG: this path is too long for DOS:');
    WriteLn(full);
    Halt;
  end;
  NormalizePath := full;
end;
{$ENDIF}

{ Read POOL.CFG (CfgFile.ReadPoolCfg): its letters into cfgVideo, cfgSound and cfgIntro, and its paths, as written,
  into GameVars.gameDir and saveDirectory. A file that will not open stops the game with a message; natively, where
  nothing asks for a startup disk, the game goes on with CfgFile.PoolDefaults and a line on the error output (#894),
  and POOL.CFG is the writable folder's when it has one, else the data folder's (GameDirs.ReadName, #1064). }
procedure ReadConfig;
var
  c: CfgFile.TPoolCfg;
  notes: CfgFile.TCfgNotes;
begin
  if CfgFile.ReadPoolCfg({$IFDEF FPC}GameDirs.ReadName(C_OPT.CFG_NAME){$ELSE}C_OPT.CFG_NAME{$ENDIF}, c, notes) in
     [CfgFile.CFG_MISSING, CfgFile.CFG_UNREADABLE] then begin
{$IFDEF FPC}
    WriteLn(StdErr, 'POOL.CFG is missing or unreadable: playing with the defaults. Run poolcfg to set up the game.');
    CfgFile.PoolDefaults(c, '');
{$ELSE}
    WriteLn('Unable to read POOL.CFG. Run POOLCFG to set up the game.');
    Halt;
{$ENDIF}
  end;
  cfgVideo := c.video;
  cfgSound := c.sound;
  cfgIntro := c.intro;
  GameVars.gameDir := c.dataDir;
  GameVars.saveDirectory := c.saveDir;
end;

{$IFNDEF FPC}
{ With no POOL.CFG here, or one that is damaged (it would not open, or holds a value START does not know), run the
  set-up program POOLCFG.EXE when it is here, so the player sets the game up there and then, and START carries on with
  the file it wrote (#876). POOLCFG is given C_OPT.SETUP_FROM_START, so that for a damaged file it first says why it
  came up. Leaving it without saving (exit code 1) leaves START too, back to DOS. DOS gives a program all the memory
  there is, so START's memory block (DOS function 4Ah) is cut back to the top of the heap for the run, and given back
  whole afterwards. The heap is still empty this early (OvrSetBuf, below, needs it so), and the overlay buffer and the
  EMS the overlays and the combat log hold are kept. A program that does not run leaves WaitForFile to ask for
  POOL.CFG, and ReadConfig to read a damaged one as SSI's START did. }
procedure RunSetup;
var
  regs: Dos.Registers;
  paras: Word;
  c: CfgFile.TPoolCfg;
  notes: CfgFile.TCfgNotes;
begin
  if not FileUtil.Exists(C_OPT.SETUP_NAME) or
     (CfgFile.ReadPoolCfg(C_OPT.CFG_NAME, c, notes) = CfgFile.CFG_READ) then Exit;
  { PSP offset 2: the segment past START's memory block }
  paras := MemW[PrefixSeg:2] - PrefixSeg;
  regs.ah := $4A;
  regs.es := PrefixSeg;
  regs.bx := Seg(HeapPtr^) + (Ofs(HeapPtr^) + 15) shr 4 - PrefixSeg;
  MsDos(regs);
  if regs.flags and FCarry <> 0 then Exit;
  SwapVectors;
  Exec(C_OPT.SETUP_NAME, C_OPT.SETUP_FROM_START);
  SwapVectors;
  regs.ah := $4A;
  regs.es := PrefixSeg;
  regs.bx := paras;
  MsDos(regs);
  if regs.flags and FCarry <> 0 then begin
    WriteLn('Not enough memory to run game after ', C_OPT.SETUP_NAME, '.');
    Halt;
  end;
  if (Dos.DosError = 0) and (Dos.DosExitCode <> 0) then
    Halt;
end;
{$ENDIF}

{$IFDEF FPC}
{ POOL.CFG's folders are a DOS install's (C:\POOLRAD\ and C:\POOLRAD\SAVE\). Natively the game's data is the folder
  DataPick.FindGame found (GameDirs.dataFolder, the current one), and the saves are where CfgFile.NativeSaveFolder puts
  them: in the writable folder (GameDirs.writeFolder) unless POOL.CFG names another folder that is there (#1064), as
  POOLCFG shows them. NatFile turns the backslashes into the system's separator as each file is opened. }
procedure NativeFolders(var gameDir, saveDir: String);
begin
  saveDir := CfgFile.NativeSaveFolder(gameDir, saveDir, GameDirs.writeFolder);
  gameDir := GameDirs.dataFolder;
end;
{$ENDIF}

{ True when word is one of the program's arguments after the first. }
function SwitchGiven(word: string): Boolean;
var
  i: Integer;
begin
  SwitchGiven := False;
  for i := 2 to ParamCount do
    if ParamStr(i) = word then
      SwitchGiven := True;
end;

{ Game startup runs through this unit's initialization section. }
begin
  GameVars.stingArg := ParamStr(1) = 'STING';
  GameVars.norandArg := ParamStr(2) = 'NORAND';
  GameVars.adviseArg := GameVars.stingArg and GameBoot.SwitchGiven('ADVISE');
  GameVars.demoArg := (ParamStr(1) = 'DEMO') or GameBoot.SwitchGiven('DEMO');
{$IFDEF FPC}
  DataPick.FindGame;
  GameVars.ovrInEms := False;
{$ELSE}
  DaxIo.WaitForFile('game.ovr', 'Please insert overlay disk.');
  OvrInit('GAME.OVR');
  { Copy the overlays into EMS when there is enough of it, so they load from memory rather than disk; without an EMS
    driver, or with too little EMS, they keep loading from GAME.OVR. This comes before CountOvrRead hooks in, since
    OvrInitEMS installs its own reader for CountOvrRead to call. }
  OvrInitEMS;
  GameVars.ovrInEms := OvrResult = ovrOk;
  GameVars.ovrLoads := 0;
  ovrRead := OvrReadBuf;
  OvrReadBuf := CountOvrRead;
{$ENDIF}
  { the combat log's store (#841): under DOS an EMS page, taken after the overlays have taken theirs }
  CbtLog.Startup;
{$IFNDEF FPC}
  GameBoot.RunSetup;
  { a read-only POOL.CFG is there too (FileUtil.Exists) }
  DaxIo.WaitForFile(C_OPT.CFG_NAME, 'Run POOLCFG to set up the game, or insert the startup disk.');
{$ENDIF}
  CheckBreak := False;
  GameBoot.ReadConfig;
  { INT 10h AH=0Fh: get current video mode into AL }
  GameVars.interruptRegisters.ah := $F;
  Intr($10, GameVars.interruptRegisters);
  GameVars.savedVideoMode := GameVars.interruptRegisters.al;
  GameVars.curVideoMode := GameVars.savedVideoMode;
  { the video driver for POOL.CFG's mode: E for EGA, T for Tandy, V for VGA, H for VGA at 640 x 400 through VESA (#1231)
    when the card has it, and VGA when it does not, else CGA; natively VGA, which shows EGA's colours }
{$IFDEF FPC}
  VidVga.Install;
{$ELSE}
  case cfgVideo of
    C_OPT.VIDEO_EGA: VidEga.Install;
    C_OPT.VIDEO_TANDY: VidTdy.Install;
    C_OPT.VIDEO_VGA: VidVga.Install;
    C_OPT.VIDEO_VESA:
      if not VidVesa.Install then begin
        WriteLn('This display has no VESA mode 100h (640x400, 256 colours): the game runs in VGA, 320x200.');
        Delay(3000);
        VidVga.Install;
      end;
  else
    VidCga.Install;
  end;
  { Keep a screen that lives in system RAM (Tandy's) out of the heap: lower HeapEnd by it. The common code after the
    sound setting lowers HeapEnd by GFX_RESERVE_PARAS once more, so Tandy reserves twice as much. }
  if GameVars.video.ramVideoParas > 0 then
    HeapEnd := Ptr(heapEndW.s - GameVars.video.ramVideoParas, heapEndW.o);
{$ENDIF}
  Blit.SetVideoMode(GameVars.video.biosMode);
  GameVars.video.Start;
{$IFNDEF FPC}
  if OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then begin
    { CfgFile, overlaid, has read POOL.CFG: the buffer is emptied before it is resized }
    OvrClearBuf;
    OvrSetBuf(OVERLAY_BUF_BYTES);
    { probation (#612): an overlay called while it sits in the last third of the buffer is kept rather than dropped, so
      the units a stretch of play keeps calling stay loaded }
    OvrSetRetry(OvrGetBuf div 3);
  end else begin
    Blit.RestoreVideoMode;
    WriteLn('Not enough memory to run game.  You need ', OVERLAY_BUF_BYTES - OvrGetBuf, ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    Halt;
  end;
{$ENDIF}
  { the sound driver POOL.CFG names: T Tandy, P the speaker, A AdLib music and speaker effects, B a Sound Blaster's
    recorded effects with its AdLib music (each falling back to the next when its card does not answer), anything else
    none. S is silent, as SSI's data card has it and the Curse port reads it; it read as the Sound Blaster until #880.
    Natively Digital Audio (SndDig), the Tandy's music and the Sound Blaster's recorded effects, whatever the letter, as
    the picture is VGA whatever the first line: the file is the DOS install's, and a DOS POOLCFG's no sound (S) left
    the native game silent (#1097). The Music and Sound settings turn it off. }
{$IFDEF FPC}
  SndDig.Install;
{$ELSE}
  case cfgSound of
    C_OPT.SOUND_TANDY: SndTdy.Install;
    C_OPT.SOUND_SPEAKER: SndSpk.Install;
    C_OPT.SOUND_ADLIB: SndOpl.Install;
    C_OPT.SOUND_BLASTER: SndSb.Install;
  else
    SndNone.Install;
  end;
{$ENDIF}
  GameVars.soundMode := GameVars.sound.mode;
{$IFNDEF FPC}
  { lower HeapEnd by GFX_RESERVE_PARAS (16 KB) }
  HeapEnd := Ptr(heapEndW.s - GFX_RESERVE_PARAS, heapEndW.o);
{$ENDIF}
  SoundDrv.SoundSuspend;
{$IFDEF FPC}
  NativeFolders(GameVars.gameDir, GameVars.saveDirectory);
{$ELSE}
  GameVars.gameDir := NormalizePath(GameVars.gameDir);
  GameVars.saveDirectory := NormalizePath(GameVars.saveDirectory);
{$ENDIF}
  GameVars.fullIntro := cfgIntro = C_OPT.INTRO_FULL;
end.
