{ Implements the sage who lives behind New Phlan's east tavern (#868). She is
  the fortune teller from the Slums, and appears here after the Slums are
  cleared if the party spared her. The patched New Phlan script starts this
  encounter with PROG_SAGE.

  For a fee based on the monster's hit dice, the sage fills in the facts that
  the party has not yet learned about a creature in the Bestiary. }
{$O+,F+}
{$I COMPILER.INC}
unit Sage;

interface

{ Runs the sage's menu until the player chooses Leave. Asking about a creature
  opens the Bestiary, quotes a fee, and reveals the remaining information after
  payment. The calling script has already displayed the sage's portrait. }
procedure SageMenu;

implementation

uses Crt, Types, C_DATA, DiskRec, GameVars, DaxIo, DataArc, EclMenu, SaveLoad, Bestiary, BeastFil, BeastMnu, Money,
  MoneyCal, MenuCore, TextRend, CharDisp, StrUtil, UiColor;

const
  { MenuHorizontalCS returns the zero-based index of the selected item. }
  MENU = '~Ask ~Leave';
  CHOICE_ASK = 0;
  CHOICE_LEAVE = 1;

{ Searches a DAX archive for the first creature record with the requested name. Reserved blocks and blocks too small to
  contain a character record are ignored. Returns the block ID in id. Missing or unreadable archives simply return False
  without showing an insert-disk prompt. }
function FindNamed(archive: Types.TStr20; var wanted: Types.TStr40; var id: Byte): Boolean;
var
  f1: file;
  f2: file;
  hdrSize: Word;
  e: DataArc.TDirEntry;
  n: Word;
  data: Types.PByteArr;
  found: Boolean;
  ended: Boolean;
  suppressed: Boolean;
  s: string[Types.NAME_LEN];
begin
  found := False;
  suppressed := GameVars.suppressDiskPrompt;
  GameVars.suppressDiskPrompt := True;
  if DaxIo.OpenDax({$IFDEF FPC}DaxIo.FolderOf(archive){$ELSE}GameVars.gameDir{$ENDIF} + archive, '.DAX', hdrSize, f1,
                   f2) then begin
    ended := False;
    while not found and not ended do begin
      BlockRead(f2, e, SizeOf(e), n);
      ended := (n < SizeOf(e)) or (FilePos(f2) >= hdrSize);
      if (n = SizeOf(e)) and (e.id < C_DATA.SOURCES_BLOCK) and (e.rawSize >= DiskRec.CHAR_DISK_BYTES) then begin
        if DaxIo.ReadBlock(f1, hdrSize, e.offset, e.packedSize, e.rawSize, data) then begin
          { A creature record begins with its string[NAME_LEN] name. }
          if Byte(data^[0]) <= Types.NAME_LEN then begin
            Move(data^[0], s, SizeOf(s));
            found := s = wanted;
          end;
          FreeMem(data, e.rawSize);
          if found then
            id := e.id;
        end;
      end;
    end;
    DaxIo.CloseDax(f1, f2);
  end;
  GameVars.suppressDiskPrompt := suppressed;
  FindNamed := found;
end;

{ Finds the source disk and block ID for a monster record. When the merged MONCHA archive is available, search it first 
  so names changed by data patches are recognized, then map the result back to its original disk and block. Otherwise 
  search MON1CHA through MON8CHA in order. }
function FindRecord(var name: Types.TStr40; var disk, id: Byte): Boolean;
var
  m: Byte;
  found: Boolean;
begin
  found := False;
  disk := 1;
  if DaxIo.FamilyUsable(C_DATA.FAMILY_MONCHA) then begin
    if Sage.FindNamed(DataArc.MergedName(C_DATA.FAMILY_MONCHA), name, m) then
      { Find the source block that was remapped to merged block m. }
      while not found and (disk <= Types.LAST_DISK) do begin
        id := 0;
        repeat
          found := (DaxIo.RemapId(C_DATA.FAMILY_MONCHA, disk, id) = m) and
                   DataArc.HasBlock(GameVars.gameDir + DataArc.SourceFile(C_DATA.FAMILY_MONCHA, disk), id);
          if not found then
            Inc(id);
        until found or (id = C_DATA.SOURCES_BLOCK);
        if not found then
          Inc(disk);
      end;
  end else
    while not found and (disk <= Types.LAST_DISK) do begin
      found := Sage.FindNamed(DataArc.SourceName(C_DATA.FAMILY_MONCHA, disk), name, id);
      if not found then
        Inc(disk);
    end;
  FindRecord := found;
end;

{ Loads the creature template named by the Bestiary entry, using the same path as the LOAD MONSTER script command. Returns 
  nil when no matching monster record exists. The caller owns the result and must free it with SaveLoad.FreeCreature. }
function LoadKind(var b: Bestiary.TBeast): Types.PCharRecord;
var
  disk: Byte;
  id: Byte;
  saved: Byte;
  creature: Types.PCharRecord;
  items: Types.PItemRec;
  effects: Types.PEffectRec;
  name: Types.TStr40;
begin
  creature := nil;
  name := b.name;
  if Sage.FindRecord(name, disk, id) then begin
    saved := GameVars.diskIndex;
    GameVars.diskIndex := disk;
    EclMenu.InitCreature(id, creature, items, effects);
    GameVars.diskIndex := saved;
  end;
  LoadKind := creature;
end;

{ Displays the sage's dialogue in the message window. }
procedure Say(s: string);
begin
  CharDisp.MessageText(s, LightGreen, True);
end;

{ Restores the exploration interface and the sage's portrait after the Bestiary screen closes. }
procedure Redraw;
begin
  TextRend.ClearRect(0, 0, 39, 24);
  CharDisp.DisplayNoncombatInterface;
  EclMenu.DisplayPortrait(CharDisp.portraitHeadId, CharDisp.portraitBodyId);
end;

{ Handles one consultation and returns the sage's next line of dialogue. }
function Consult(b: Bestiary.PBeast): string;
var
  creature: Types.PCharRecord;
  t: Bestiary.TBeast;
  fee: Word;
begin
  creature := Sage.LoadKind(b^);
  if creature = nil then
    Consult := '''' + b^.name + '? I HAVE NOT HEARD OF ANY SUCH CREATURE.'''
  else begin
    t := b^;
    if not BeastFil.Tell(t, creature) then begin
      { There is nothing new to reveal, but Tell may have marked the entry as complete. }
      if t.known[0] <> b^.known[0] then begin
        b^ := t;
        Bestiary.dirty := True;
      end;
      Consult := '''YOU KNOW AS MUCH AS I DO ABOUT ' + b^.name + '.''';
    end else begin
      fee := MoneyCal.SageFee(creature^.levelHighest);
      Sage.Say('''' + b^.name + '? FOR ' + StrUtil.Count(fee, 'GOLD PIECE', 'GOLD PIECES') +
               ' I WILL TELL YOU ALL I KNOW.''');
      if MenuCore.YesNoMenu('pay the sage ', LightMagenta, White, LightGreen) <> 'Y' then
        Consult := '''AS YOU WISH.'''
      else if not Money.PayGold(GameVars.curChar, fee) then
        Consult := '''COME BACK WHEN YOU HAVE THE GOLD.'''
      else begin
        b^ := t;
        Bestiary.dirty := True;
        Sage.Say('SHE TAKES A TOME DOWN FROM A SHELF FILLED WITH MANY OTHERS, AND READS ALOUD.');
        CharDisp.MessageWait;
        BeastMnu.ShowEntry(b^);
        Sage.Redraw;
        Consult := '''IS THERE ANOTHER THAT STANDS AGAINST YOU?''';
      end;
    end;
    SaveLoad.FreeCreature(creature);
  end;
end;

procedure SageMenu;
var
  answer: string;
  b: Bestiary.PBeast;
  choice: Byte;
begin
  answer := 'THE SAGE LOOKS UP FROM THE ANCIENT TOME SHE IS STUDYING. ' +
            '''KNOWLEDGE IS A WEAPON. NAME YOUR FOE, AND I CAN SHARPEN YOUR BLADE.''';
  repeat
    Sage.Say(answer);
    choice := EclMenu.MenuHorizontalCharacterSelect('', MENU, promptColor, optionColor, commandColor, True, False);
    if choice = CHOICE_ASK then begin
      b := BeastMnu.PickBeast('Ask about: ');
      Sage.Redraw;
      if b = nil then
        answer := '''IS THERE SOMETHING YOU WOULD ASK ABOUT?'''
      else
        answer := Sage.Consult(b);
    end;
  until choice = CHOICE_LEAVE;
  CharDisp.ClearMessageWindow;
end;

end.
