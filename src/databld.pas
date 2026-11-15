{ Builds merged data archives at startup from the player's installed game. Each
  family combines its per-disk DAX files into one archive so runtime loading no
  longer depends on the active disk. Packed blocks are copied byte for byte. If
  the same block ID has different contents on two disks, later versions receive
  spare IDs recorded in the remap table.

  DataPat fixes are applied only when the target block still matches the known
  original bytes. Each merged archive records the size and CRC-32 of its source
  files, plus a version and checksum for the completed output. New archives are
  written to a temporary file, verified, and then renamed into place. The
  original game files are never modified. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit DataBld;

interface

{ Build every merged archive the game cannot use, then have DaxIo look at them afresh. Nothing is shown or written when
  every one is current. A family whose build fails is left without a merged archive, so the game reads its per-disk
  archives. Once the game folder cannot be written, whether before the first family or at a later write, the families
  not yet built wait for the next start. }
procedure BuildDataFiles;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, Dos, Types, C_DATA, GameVars, DataArc, DataPat, DaxIo, TextRend,
  BldShow, StrUtil, SaveMenu, FileUtil, BarArt{$IFDEF FPC}, NatFile{$ENDIF};

const
  { the most directory entries a family's per-disk archives may hold between them, plus the three reserved blocks }
  MAX_BLOCKS = 512;
  { the most collisions one family may have }
  MAX_REMAPS = C_DATA.FAMILY_REMAPS;
  { bytes moved per read when copying, comparing or checksumming }
  CHUNK_SIZE = 4096;
  { the most bytes one literal run of a packed block holds }
  RUN_SIZE = 127;
  { the largest block packed into memory: its literal runs must fit in one heap block }
  MAX_ENCODED = 64000;
  { the largest block DaxIo.LoadDax can read once packed into literal runs of RUN_SIZE bytes, each with its control
    byte, so no larger than C_DATA.PACKED_LIMIT: 35718 bytes pack to 35718 + 282 = 36000 }
  MAX_LOADABLE = C_DATA.PACKED_LIMIT * RUN_SIZE div (RUN_SIZE + 1);
  { the free space a merged archive is given beyond its per-disk archives together: its reserved blocks, a patched block
    packed larger than before, the disk's cluster rounding and the log }
  ROOM_MARGIN = 65536;
  { the most bytes the sources block holds }
  SOURCES_SIZE = Types.LAST_DISK * C_DATA.SOURCE_RECORD;
  { the version block: C_DATA.VERSION and a CRC-32, packed as one literal run }
  VERSION_RAW = 5;
  VERSION_PACKED = 6;
  LOG_NAME = 'DATABLD.LOG';

type
  { A block: packed bytes in the per-disk archive of disk at file position start, or, with disk 0, in memory at mem. }
  TBlock = record
    id: Byte;
    rawSize: Word;
    packedSize: Word;
    disk: Byte;
    start: LongInt;
    mem: Types.PByteArr;
  end;
  PBlockList = ^TBlockList;
  TBlockList = array[1..MAX_BLOCKS] of TBlock;
  TBytes = array[0..65534] of Byte;
  PBytes = ^TBytes;
  { A CRC-32 being computed, also seen as its low and high words. }
  TCrc = record
    case Byte of
      0: (value: LongInt);
      1: (lo: Word; hi: Word);
  end;
  { The CRC-32 table's low and high words. }
  TCrcTable = record
    lo: array[0..255] of Word;
    hi: array[0..255] of Word;
  end;
  PCrcTable = ^TCrcTable;
  TSources = array[0..SOURCES_SIZE - 1] of Byte;
  { why a family failed, for the log }
  TNote = String[80];

var
  logFile: Text;
  logOpen: Boolean;
  { the build's working memory, on the heap only while BuildDataFiles runs }
  crcTable: PCrcTable;
  bufA: PBytes;
  bufB: PBytes;
  { the per-disk archives' directory entries, in disk order, and the merged archive's blocks }
  sources: PBlockList;
  sourceCount: Word;
  blocks: PBlockList;
  blockCount: Word;
  { the sources block of the family being built: disk, size and CRC-32 of each per-disk archive }
  sourceList: TSources;
  sourceListLen: Word;
  { the collisions: a load of remapFrom on remapDisk reads remapTo, which is block remapBlock }
  remapCount: Byte;
  remapDisk: array[1..MAX_REMAPS] of Byte;
  remapFrom: array[1..MAX_REMAPS] of Byte;
  remapTo: array[1..MAX_REMAPS] of Byte;
  remapBlock: array[1..MAX_REMAPS] of Word;
  { the merged archive being worked on, for messages }
  archiveName: Types.TStr20;
  { why the family being built failed, for the log; empty while all is well }
  failNote: TNote;
  { the last DOS error a read or write met }
  lastError: Integer;
  { why the game folder could not be written, once it could not; the families after it are not tried }
  writeNote: TNote;
  { set when the build cannot start: not memory enough, or a fix table that does not add up; no family is tried }
  memNote: TNote;
  builtCount: Byte;
  keptCount: Byte;
  failedCount: Byte;
  n: Integer;

{ Write a line to DATABLD.LOG and push it to disk, so the log ends at the step that was running if the game stops. A log
  that cannot be written is given up; the build carries on. }
procedure LogLine(s: string);
begin
  if logOpen then begin
    WriteLn(logFile, s);
    Flush(logFile);
    if IOResult <> 0 then
      logOpen := False;
  end;
end;

{ Show s on the bottom line (its first 40 characters) and log it. }
procedure Progress(s: string);
begin
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Copy(s, 1, 40));
  DataBld.LogLine(s);
end;

{ Note why the family failed, unless an earlier step already has. }
procedure Fail(why: string);
begin
  if failNote = '' then
    failNote := why;
end;

{ Note that the game folder could not be written, and why, so the families after this one wait for the next start. }
procedure FailWriting(why: string);
begin
  DataBld.Fail(why);
  if writeNote = '' then
    writeNote := why;
end;

{ True when the last file operation succeeded; otherwise its DOS error goes to lastError. }
function IoOk: Boolean;
var
  err: Integer;
begin
  err := IOResult;
  if err <> 0 then
    lastError := err;
  IoOk := err = 0;
end;

{ True when a heap block of size bytes can be had; otherwise failNote says there is not enough memory. }
function Reserve(size: LongInt): Boolean;
var
  ok: Boolean;
begin
  ok := MaxAvail >= size + 8;
  if not ok then
    DataBld.Fail('not enough memory');
  Reserve := ok;
end;

{ Fill crcTable for the CRC-32 of zip and PNG (reflected polynomial $EDB88320). }
procedure InitCrcTable;
var
  i: Word;
  k: Byte;
  c: TCrc;
begin
  for i := 0 to 255 do begin
    c.value := i;
    for k := 1 to 8 do
      if c.value and 1 <> 0 then
        c.value := (c.value shr 1) xor $EDB88320
      else
        c.value := c.value shr 1;
    crcTable^.lo[i] := c.lo;
    crcTable^.hi[i] := c.hi;
  end;
end;

{ Add count bytes at buf to crc, which starts at -1; the CRC-32 is crc's bitwise not once every byte is in. Word
  arithmetic throughout: this loop is most of the build's time. }
procedure AddCrc(var crc: TCrc; var buf; count: Word);
var
  i: Word;
  idx: Byte;
  low16: Word;
  high16: Word;
  table: PCrcTable;
begin
  table := crcTable;
  low16 := crc.lo;
  high16 := crc.hi;
  i := 0;
  while i < count do begin
    idx := Byte(low16) xor TBytes(buf)[i];
    low16 := ((low16 shr 8) or (high16 shl 8)) xor table^.lo[idx];
    high16 := (high16 shr 8) xor table^.hi[idx];
    Inc(i);
  end;
  crc.lo := low16;
  crc.hi := high16;
end;

{ Read count bytes at position pos of the open file f into buf. False on a read error or a short read. }
function ReadAt(var f: file; pos: LongInt; var buf; count: Word): Boolean;
var
  got: Word;
begin
  Seek(f, pos);
  BlockRead(f, buf, count, got);
  ReadAt := DataBld.IoOk and (got = count);
end;

{ The CRC-32 of the first size bytes of the open file f. False on a read error or a file shorter than size. }
function CrcOfFile(var f: file; size: LongInt; var crc: LongInt): Boolean;
var
  c: TCrc;
  pos: LongInt;
  part: Word;
  ok: Boolean;
begin
  c.value := -1;
  pos := 0;
  ok := True;
  while ok and (pos < size) do begin
    part := CHUNK_SIZE;
    if size - pos < part then
      part := size - pos;
    ok := DataBld.ReadAt(f, pos, bufA^, part);
    DataBld.AddCrc(c, bufA^, part);
    BldShow.Advance(part);
    Inc(pos, part);
  end;
  crc := not c.value;
  CrcOfFile := ok;
end;

{ The path of the file called name in the game folder; natively a file DataBld writes is in the writable folder,
  which may be another (DaxIo.FolderOf, #1064). }
function GamePath(name: Types.TStr20): Types.TPathStr;
begin
{$IFDEF FPC}
  GamePath := DaxIo.FolderOf(name) + name;
{$ELSE}
  GamePath := GameVars.gameDir + name;
{$ENDIF}
end;

{ Remove a file from the game folder if it is there; an error is ignored. }
procedure RemoveFile(name: Types.TStr20);
var
  f: file;
begin
  Assign(f, DataBld.GamePath(name));
  Erase(f);
  n := IOResult;
end;

{ The merged archive's temporary copy, written until it is whole: <archiveName>.DAX in the TMP\ folder beside where it
  goes (FileUtil.TempName), as saves' copies are (#1084); it was <archiveName>.$$$ in the game folder (#1150). }
function TempPath: Types.TPathStr;
begin
  TempPath := FileUtil.TempName(DataBld.GamePath(archiveName + '.DAX'));
end;

{ The temporary copy's name for DATABLD.LOG. }
function TempLabel: Types.TStr20;
begin
  TempLabel := FileUtil.TEMP_FOLDER + archiveName + '.DAX';
end;

{ Remove the temporary copy if it is there; an error is ignored. }
procedure RemoveTemp;
var
  f: file;
begin
  Assign(f, DataBld.TempPath);
  Erase(f);
  n := IOResult;
end;

{ True when the family has something to build from or to remove: a per-disk archive, or a merged archive. }
function HasFiles(fam: Byte): Boolean;
var
  disk: Byte;
  found: Boolean;
begin
  found := DataArc.FileLength(DataBld.GamePath(DataArc.MergedName(fam) + '.DAX')) >= 0;
  for disk := 1 to Types.LAST_DISK do
    if not found then
      found := DataArc.FileLength(DataBld.GamePath(DataArc.SourceFile(fam, disk))) >= 0;
  HasFiles := found;
end;

{ True when the game folder's disk has room for the family's merged archive: its per-disk archives together and
  ROOM_MARGIN. Otherwise failNote says how much is needed, so a full disk costs no reading. A disk whose free space
  cannot be read is taken to have room; a write that still runs out of room fails as any other. }
function HasRoom(fam: Byte): Boolean;
var
  disk: Byte;
  size: LongInt;
  need: LongInt;
  free: LongInt;
begin
  need := ROOM_MARGIN;
  for disk := 1 to Types.LAST_DISK do begin
    size := DataArc.FileLength(DataBld.GamePath(DataArc.SourceFile(fam, disk)));
    if size > 0 then
      Inc(need, size);
  end;
  free := -1;
  if (Length(GameVars.gameDir) >= 2) and (GameVars.gameDir[2] = ':') and
      (UpCase(GameVars.gameDir[1]) in ['A'..'Z']) then
    free := DiskFree(Ord(UpCase(GameVars.gameDir[1])) - Ord('A') + 1);
  if (free >= 0) and (free < need) then
    DataBld.Fail('not enough room on the disk: ' + StrUtil.NumStr(need) + ' bytes wanted, ' + StrUtil.NumStr(free) +
                 ' free');
  HasRoom := (free < 0) or (free >= need);
end;

{ True when the temporary copy (TempPath) can be created, its TMP\ folder made first; it is left there, empty. False,
  with failNote and writeNote set, when it cannot, so a folder that cannot be written costs no reading. }
function CanWrite: Boolean;
var
  f: file;
  ok: Boolean;
begin
  lastError := 0;
  if not FileUtil.MakeTempFolder(DataBld.GamePath(archiveName + '.DAX')) then begin
    DataBld.FailWriting('making the ' + FileUtil.TEMP_FOLDER + ' folder');
    CanWrite := False;
    Exit;
  end;
  Assign(f, DataBld.TempPath);
  Rewrite(f, 1);
  ok := DataBld.IoOk;
  if ok then begin
    Close(f);
    ok := DataBld.IoOk;
  end;
  if not ok then
    DataBld.FailWriting('writing ' + DataBld.TempLabel + ': DOS error ' + StrUtil.NumStr(lastError));
  CanWrite := ok;
end;

{ Read the open per-disk archive f of disk: its directory into sources, and its disk, size and CRC-32 onto sourceList.
  False, with failNote set, when it cannot be read, is damaged (its directory or a block runs past its end) or its
  entries do not fit. }
function ReadSource(var f: file; fam, disk: Byte): Boolean;
var
  dirSize: Word;
  dataStart: LongInt;
  size: LongInt;
  crc: LongInt;
  i: Word;
  e: DataArc.TDirEntry;
  ok: Boolean;
begin
  lastError := 0;
  size := FileSize(f);
  ok := DataBld.IoOk and DataBld.ReadAt(f, 0, dirSize, SizeOf(dirSize));
  dataStart := SizeOf(dirSize) + LongInt(dirSize);
  ok := ok and (dirSize mod SizeOf(e) = 0) and (dataStart <= size);
  i := 1;
  while ok and (i <= dirSize div SizeOf(e)) do begin
    ok := DataBld.ReadAt(f, SizeOf(dirSize) + LongInt(i - 1) * SizeOf(e), e, SizeOf(e));
    ok := ok and (e.offset >= 0) and (dataStart + e.offset + e.packedSize <= size);
    if ok then
      if sourceCount + 3 >= MAX_BLOCKS then begin
        DataBld.Fail('too many blocks');
        ok := False;
      end else begin
        Inc(sourceCount);
        sources^[sourceCount].id := e.id;
        sources^[sourceCount].rawSize := e.rawSize;
        sources^[sourceCount].packedSize := e.packedSize;
        sources^[sourceCount].disk := disk;
        sources^[sourceCount].start := dataStart + e.offset;
        sources^[sourceCount].mem := nil;
      end;
    Inc(i);
  end;
  ok := ok and DataBld.CrcOfFile(f, size, crc);
  if ok and (sourceListLen + C_DATA.SOURCE_RECORD <= SOURCES_SIZE) then begin
    sourceList[sourceListLen] := disk;
    Move(size, sourceList[sourceListLen + 1], 4);
    Move(crc, sourceList[sourceListLen + 5], 4);
    Inc(sourceListLen, C_DATA.SOURCE_RECORD);
  end;
  if not ok then
    if lastError <> 0 then
      DataBld.Fail('reading ' + DataArc.SourceFile(fam, disk) + ': DOS error ' + StrUtil.NumStr(lastError))
    else
      DataBld.Fail(DataArc.SourceFile(fam, disk) + ' is damaged');
  ReadSource := ok;
end;

{ Read the family's per-disk archives that are present, disks 1 to Types.LAST_DISK. False, with failNote set, when one
  cannot be read or is damaged. }
function ReadSources(fam: Byte): Boolean;
var
  disk: Byte;
  f: file;
  ok: Boolean;
begin
  sourceCount := 0;
  sourceListLen := 0;
  ok := True;
  for disk := 1 to Types.LAST_DISK do
    if ok then begin
      Assign(f, DataBld.GamePath(DataArc.SourceFile(fam, disk)));
      Reset(f, 1);
      if IOResult = 0 then begin
        DataBld.Progress(archiveName + '.DAX: reading ' + DataArc.SourceFile(fam, disk));
        BldShow.Reading(fam, disk);
        ok := DataBld.ReadSource(f, fam, disk);
        Close(f);
        n := IOResult;
      end;
    end;
  ReadSources := ok;
end;

{ True when blocks a and b, both in per-disk archives of the family, unpack to the same size and hold the same packed
  bytes. A read error sets failNote. }
function SameBlock(fam: Byte; var a, b: TBlock): Boolean;
var
  fa: file;
  fb: file;
  left: Word;
  part: Word;
  posA: LongInt;
  posB: LongInt;
  i: Word;
  same: Boolean;
begin
  { the merged archive keeps one directory entry, rawSize included, for both }
  same := (a.packedSize = b.packedSize) and (a.rawSize = b.rawSize);
  if same then begin
    lastError := 0;
    Assign(fa, DataBld.GamePath(DataArc.SourceFile(fam, a.disk)));
    Reset(fa, 1);
    if DataBld.IoOk then begin
      Assign(fb, DataBld.GamePath(DataArc.SourceFile(fam, b.disk)));
      Reset(fb, 1);
      if DataBld.IoOk then begin
        left := a.packedSize;
        posA := a.start;
        posB := b.start;
        while same and (left > 0) do begin
          part := left;
          if part > CHUNK_SIZE then
            part := CHUNK_SIZE;
          if DataBld.ReadAt(fa, posA, bufA^, part) and DataBld.ReadAt(fb, posB, bufB^, part) then begin
            i := 0;
            while same and (i < part) do begin
              same := bufA^[i] = bufB^[i];
              Inc(i);
            end;
          end else
            same := False;
          Inc(posA, part);
          Inc(posB, part);
          Dec(left, part);
        end;
        Close(fb);
      end;
      Close(fa);
    end;
    n := IOResult;
    if lastError <> 0 then begin
      DataBld.Fail('comparing ' + DataArc.SourceFile(fam, b.disk) + ': DOS error ' + StrUtil.NumStr(lastError));
      same := False;
    end;
  end;
  SameBlock := same;
end;

{ Pack rawSize bytes at raw as literal runs of at most RUN_SIZE bytes, into a new buffer of packedSize bytes. Nil and 0
  when rawSize is 0, or, with failNote set, when rawSize is above MAX_ENCODED or the memory is not there. }
procedure EncodeRuns(var raw; rawSize: Word; var packedBuf: Types.PByteArr; var packedSize: Word);
var
  i: Word;
  o: Word;
  run: Word;
begin
  packedBuf := nil;
  packedSize := 0;
  if rawSize > MAX_ENCODED then
    DataBld.Fail('a block is too large to pack')
  else if rawSize > 0 then begin
    packedSize := rawSize + (rawSize + RUN_SIZE - 1) div RUN_SIZE;
    if DataBld.Reserve(packedSize) then
      GetMem(packedBuf, packedSize)
    else
      packedSize := 0;
  end;
  i := 0;
  o := 0;
  while (packedSize > 0) and (i < rawSize) do begin
    run := rawSize - i;
    if run > RUN_SIZE then
      run := RUN_SIZE;
    PBytes(packedBuf)^[o] := run - 1;
    Move(TBytes(raw)[i], PBytes(packedBuf)^[o + 1], run);
    Inc(o, run + 1);
    Inc(i, run);
  end;
end;

{ Add a block holding size bytes at raw, packed into memory, under blockId. }
procedure AddMemoryBlock(blockId: Byte; var raw; size: Word);
begin
  Inc(blockCount);
  blocks^[blockCount].id := blockId;
  blocks^[blockCount].rawSize := size;
  blocks^[blockCount].disk := 0;
  blocks^[blockCount].start := 0;
  DataBld.EncodeRuns(raw, size, blocks^[blockCount].mem, blocks^[blockCount].packedSize);
end;

{ True when the archive at path is whole, of version C_DATA.VERSION, and its bytes match the CRC-32 in its version
  block. }
function ArchiveSound(path: Types.TPathStr): Boolean;
var
  f: file;
  size: LongInt;
  crc: LongInt;
  version: array[0..VERSION_PACKED - 1] of Byte;
  stored: LongInt;
  ok: Boolean;
begin
  ok := False;
  if DataArc.ArchiveIntact(path) then begin
    Assign(f, path);
    Reset(f, 1);
    if DataBld.IoOk then begin
      size := FileSize(f);
      ok := DataBld.ReadAt(f, size - VERSION_PACKED, version, VERSION_PACKED) and (version[0] = VERSION_RAW - 1) and
            (version[1] = C_DATA.VERSION);
      if ok then begin
        Move(version[2], stored, 4);
        ok := DataBld.CrcOfFile(f, size - VERSION_PACKED, crc) and (crc = stored);
      end;
      Close(f);
      n := IOResult;
    end;
  end;
  ArchiveSound := ok;
end;

{ Fill blocks from sources: the first copy of an id keeps it; a later copy with other bytes goes to a spare id, and a
  remap entry says so. Several disks with the same other bytes share one spare id. False, with failNote set, on a read
  error or when the collisions or spare ids run out. }
function ChooseIds(fam: Byte): Boolean;
var
  used: array[0..255] of Boolean;
  taken: array[0..255] of Boolean;
  owner: array[0..255] of Word;
  i: Word;
  r: Word;
  hit: Word;
  spare: Word;
  id: Byte;
begin
  FillChar(used, SizeOf(used), 0);
  FillChar(taken, SizeOf(taken), 0);
  FillChar(owner, SizeOf(owner), 0);
  for i := 1 to sourceCount do
    used[sources^[i].id] := True;
  i := 1;
  while (i <= sourceCount) and (failNote = '') do begin
    id := sources^[i].id;
    if owner[id] = 0 then begin
      Inc(blockCount);
      blocks^[blockCount] := sources^[i];
      owner[id] := blockCount;
    end else if not DataBld.SameBlock(fam, blocks^[owner[id]], sources^[i]) and (failNote = '') then begin
      hit := 0;
      for r := 1 to remapCount do
        if (hit = 0) and (remapFrom[r] = id) and (failNote = '') then
          if DataBld.SameBlock(fam, blocks^[remapBlock[r]], sources^[i]) then
            hit := r;
      { an entry is a disk's (DaxIo.RemapId): sharing another disk's spare id (hit) still takes one }
      if remapCount = MAX_REMAPS then
        DataBld.Fail('too many collisions')
      else if failNote = '' then begin
        Inc(remapCount);
        remapDisk[remapCount] := sources^[i].disk;
        remapFrom[remapCount] := id;
        if hit > 0 then begin
          remapTo[remapCount] := remapTo[hit];
          remapBlock[remapCount] := remapBlock[hit];
        end else begin
          spare := 1;
          while (spare < C_DATA.PORT_BLOCK_FIRST) and (used[spare] or taken[spare]) do
            Inc(spare);
          if spare >= C_DATA.PORT_BLOCK_FIRST then
            DataBld.Fail('no spare block id left')
          else begin
            taken[spare] := True;
            Inc(blockCount);
            blocks^[blockCount] := sources^[i];
            blocks^[blockCount].id := spare;
            remapTo[remapCount] := spare;
            remapBlock[remapCount] := blockCount;
          end;
        end;
      end;
    end;
    Inc(i);
  end;
  ChooseIds := failNote = '';
end;

{ Append block b's packed bytes to dst, from memory or copied from its per-disk archive, adding them to crc. False on a
  read or write error. }
function CopyBlock(fam: Byte; var b: TBlock; var dst: file; var crc: TCrc): Boolean;
var
  src: file;
  left: Word;
  part: Word;
  pos: LongInt;
  ok: Boolean;
begin
  if b.disk = 0 then begin
    BlockWrite(dst, b.mem^, b.packedSize);
    DataBld.AddCrc(crc, b.mem^, b.packedSize);
    BldShow.Advance(b.packedSize);
    ok := DataBld.IoOk;
  end else begin
    Assign(src, DataBld.GamePath(DataArc.SourceFile(fam, b.disk)));
    Reset(src, 1);
    ok := DataBld.IoOk;
    if ok then begin
      left := b.packedSize;
      pos := b.start;
      while ok and (left > 0) do begin
        part := left;
        if part > CHUNK_SIZE then
          part := CHUNK_SIZE;
        ok := DataBld.ReadAt(src, pos, bufA^, part);
        if ok then begin
          BlockWrite(dst, bufA^, part);
          DataBld.AddCrc(crc, bufA^, part);
          BldShow.Advance(part);
          ok := DataBld.IoOk;
        end;
        Inc(pos, part);
        Dec(left, part);
      end;
      Close(src);
      n := IOResult;
    end;
  end;
  CopyBlock := ok;
end;

{ Write blocks to the temporary copy (TempPath): the directory, the blocks, then the version block (the last of
  blocks, its id and sizes set) holding C_DATA.VERSION and the CRC-32 of everything before it. False, with failNote and
  writeNote set, on an error. }
function WriteArchive(fam: Byte): Boolean;
var
  dst: file;
  dirSize: Word;
  e: DataArc.TDirEntry;
  nextOffset: LongInt;
  crc: TCrc;
  version: array[0..VERSION_PACKED - 1] of Byte;
  i: Word;
  ok: Boolean;
begin
  lastError := 0;
  Assign(dst, DataBld.TempPath);
  Rewrite(dst, 1);
  ok := DataBld.IoOk;
  if ok then begin
    crc.value := -1;
    dirSize := blockCount * SizeOf(e);
    BlockWrite(dst, dirSize, SizeOf(dirSize));
    DataBld.AddCrc(crc, dirSize, SizeOf(dirSize));
    nextOffset := 0;
    for i := 1 to blockCount do begin
      e.id := blocks^[i].id;
      e.offset := nextOffset;
      e.rawSize := blocks^[i].rawSize;
      e.packedSize := blocks^[i].packedSize;
      BlockWrite(dst, e, SizeOf(e));
      DataBld.AddCrc(crc, e, SizeOf(e));
      Inc(nextOffset, blocks^[i].packedSize);
    end;
    BldShow.Writing(nextOffset);
    ok := DataBld.IoOk;
    i := 1;
    while ok and (i < blockCount) do begin
      ok := DataBld.CopyBlock(fam, blocks^[i], dst, crc);
      Inc(i);
    end;
    if ok then begin
      version[0] := VERSION_RAW - 1;
      version[1] := C_DATA.VERSION;
      crc.value := not crc.value;
      Move(crc.value, version[2], 4);
      BlockWrite(dst, version, VERSION_PACKED);
      ok := DataBld.IoOk;
    end;
    Close(dst);
    ok := DataBld.IoOk and ok;
  end;
  if not ok then
    if lastError <> 0 then
      DataBld.FailWriting('writing ' + DataBld.TempLabel + ': DOS error ' + StrUtil.NumStr(lastError))
    else
      DataBld.FailWriting('writing ' + DataBld.TempLabel);
  WriteArchive := ok;
end;

{ '#38' for issue 38. }
function IssueName(issue: Word): Types.TStr20;
begin
  IssueName := '#' + StrUtil.NumStr(issue);
end;

{ The most bytes a block of the family may hold once fixed: a script must fit the script buffer after its two-byte
  leader, and any other block must still pack small enough for LoadDax (MAX_LOADABLE). }
function MaxRawSize(fam: Byte): Word;
begin
  if fam = C_DATA.FAMILY_ECL then
    MaxRawSize := 2 + SizeOf(Types.TZone3)
  else
    MaxRawSize := MAX_LOADABLE;
end;

{ True when parts a and b name the same block. }
function SameBlockPart(a, b: Word): Boolean;
begin
  SameBlockPart := (DataPat.parts^[a].family = DataPat.parts^[b].family) and
                   (DataPat.parts^[a].disk = DataPat.parts^[b].disk) and (DataPat.parts^[a].id = DataPat.parts^[b].id);
end;

{ True when part b belongs to the same fix as part a: the same issue and block. }
function SameFix(a, b: Word): Boolean;
begin
  SameFix := (DataPat.parts^[a].issue = DataPat.parts^[b].issue) and DataBld.SameBlockPart(a, b);
end;

{ The remap entry for a load of block id from disk, or 0. }
function RemapOf(disk, id: Byte): Word;
var
  r: Word;
  found: Word;
begin
  found := 0;
  for r := 1 to remapCount do
    if (remapDisk[r] = disk) and (remapFrom[r] = id) then
      found := r;
  RemapOf := found;
end;

{ The block a load of block id from disk reads in the merged archive, as its blocks index; 0 when the per-disk archive
  of disk has no block id. }
function ResolveBlock(disk, id: Byte): Word;
var
  i: Word;
  r: Word;
  found: Word;
  listed: Boolean;
begin
  found := 0;
  r := DataBld.RemapOf(disk, id);
  if r > 0 then
    found := remapBlock[r]
  else begin
    listed := False;
    for i := 1 to sourceCount do
      if (sources^[i].disk = disk) and (sources^[i].id = id) then
        listed := True;
    { the first disk's block keeps the id; a spare id is never one a per-disk archive uses }
    if listed then
      for i := 1 to blockCount do
        if blocks^[i].id = id then
          found := i;
  end;
  ResolveBlock := found;
end;

{ True when a disk other than disk also reads block target for block id. }
function BlockShared(disk, id: Byte; target: Word): Boolean;
var
  i: Word;
  shared: Boolean;
begin
  shared := False;
  for i := 1 to sourceCount do
    if not shared and (sources^[i].id = id) and (sources^[i].disk <> disk) then
      shared := DataBld.ResolveBlock(sources^[i].disk, id) = target;
  BlockShared := shared;
end;

{ Give disk its own copy of block target, its block id, under a spare id with a remap entry, so that fixing the copy
  changes nothing another disk reads. The copy's blocks index; 0, with why set, when the block is not in its per-disk
  archive or the spare ids, the remap entries or the room for blocks have run out. }
function SplitBlock(disk, id: Byte; target: Word; var why: TNote): Word;
var
  used: array[0..255] of Boolean;
  i: Word;
  r: Word;
  spare: Word;
begin
  SplitBlock := 0;
  FillChar(used, SizeOf(used), 0);
  for i := 1 to sourceCount do
    used[sources^[i].id] := True;
  for i := 1 to blockCount do
    used[blocks^[i].id] := True;
  spare := 1;
  while (spare < C_DATA.SOURCES_BLOCK) and used[spare] do
    Inc(spare);
  r := DataBld.RemapOf(disk, id);
  if blocks^[target].disk = 0 then
    why := 'the block is not in its archive'
  else if spare >= C_DATA.SOURCES_BLOCK then
    why := 'no spare block id left'
  else if (r = 0) and (remapCount = MAX_REMAPS) then
    why := 'too many collisions'
  else if blockCount + 3 >= MAX_BLOCKS then
    why := 'too many blocks'
  else begin
    Inc(blockCount);
    blocks^[blockCount] := blocks^[target];
    blocks^[blockCount].id := spare;
    if r = 0 then begin
      Inc(remapCount);
      r := remapCount;
      remapDisk[r] := disk;
      remapFrom[r] := id;
    end;
    remapTo[r] := spare;
    remapBlock[r] := blockCount;
    SplitBlock := blockCount;
  end;
end;

{ Make the fix whose first part is first, its bytes from patchBytes[pos] on, to the rawLen bytes at raw, building the
  result in spare; both buffers hold room bytes. True when every part found the block at its size with its original
  bytes and the result fits: raw and spare are then swapped, so raw holds the fixed block, and rawLen is its length.
  Otherwise raw is unchanged and why says what did not match. }
function ApplyFix(fam: Byte; first, pos: Word; var raw, spare: PBytes; room: Word; var rawLen: Word;
                  var why: TNote): Boolean;
var
  part: DataPat.TPatchPart;
  p: Word;
  q: Word;
  k: Word;
  len: Word;
  newLen: LongInt;
  t: PBytes;
  ok: Boolean;
begin
  Move(raw^, spare^, rawLen);
  len := rawLen;
  ok := True;
  p := first;
  q := pos;
  while ok and (p <= DataPat.PART_COUNT) and DataBld.SameFix(first, p) do begin
    part := DataPat.parts^[p];
    ok := (part.size = len) and (LongInt(part.offset) + part.origLen <= len) and
          (LongInt(q) + part.origLen + part.newLen <= DataPat.BYTE_COUNT);
    k := 0;
    while ok and (k < part.origLen) do begin
      ok := spare^[part.offset + k] = DataPat.patchBytes^[q + k];
      Inc(k);
    end;
    if not ok then
      why := 'the block differs'
    else begin
      newLen := LongInt(len) - part.origLen + part.newLen;
      ok := (newLen <= DataBld.MaxRawSize(fam)) and (newLen <= room);
      if not ok then
        why := 'the block would be too long'
      else begin
        Move(spare^[part.offset + part.origLen], spare^[part.offset + part.newLen], len - part.offset - part.origLen);
        Move(DataPat.patchBytes^[q + part.origLen], spare^[part.offset], part.newLen);
        len := newLen;
      end;
    end;
    Inc(q, part.origLen + part.newLen);
    Inc(p);
  end;
  if ok then begin
    t := raw;
    raw := spare;
    spare := t;
    rawLen := len;
  end;
  ApplyFix := ok;
end;

{ Make every fix to the block part first names, in table order, the first one's bytes from patchBytes[pos] on: the block
  is decoded, each fix made when its checks pass, and the result packed into memory. A block several disks read is first
  copied for the fixed disk. Each fix is logged by its issue number. False, with failNote set, on a read error or when
  the memory for the result is not there. }
{ Read block target's unpacked bytes (blocks^[target].rawSize of them) into raw, which holds at least that many: from
  its per-disk archive, or, a block already in memory (disk 0), from there. False, with failNote set, when the archive
  cannot be read. }
function ReadBlock(fam: Byte; target: Word; raw: PBytes): Boolean;
var
  packedBuf: PBytes;
  f: file;
  ok: Boolean;
begin
  with blocks^[target] do
    if disk = 0 then begin
      DaxIo.DecompressDax(mem, Types.PByteArr(raw), packedSize, rawSize);
      ok := True;
    end else begin
      GetMem(packedBuf, packedSize);
      lastError := 0;
      Assign(f, DataBld.GamePath(DataArc.SourceFile(fam, disk)));
      Reset(f, 1);
      ok := DataBld.IoOk;
      if ok then begin
        ok := DataBld.ReadAt(f, start, packedBuf^, packedSize);
        Close(f);
        n := IOResult;
      end;
      if ok then
        DaxIo.DecompressDax(Types.PByteArr(packedBuf), Types.PByteArr(raw), packedSize, rawSize)
      else
        DataBld.Fail('reading ' + DataArc.SourceFile(fam, disk) + ': DOS error ' + StrUtil.NumStr(lastError));
      FreeMem(packedBuf, packedSize);
    end;
  ReadBlock := ok;
end;

function PatchBlock(fam: Byte; first, pos: Word): Boolean;
var
  disk: Byte;
  id: Byte;
  target: Word;
  room: LongInt;
  rawLen: Word;
  p: Word;
  q: Word;
  raw: PBytes;
  spare: PBytes;
  note: TNote;
  why: TNote;
  ok: Boolean;
  fixed: Boolean;
  held: Boolean;
begin
  disk := DataPat.parts^[first].disk;
  id := DataPat.parts^[first].id;
  DataBld.Progress(archiveName + '.DAX: fixing ' + DataArc.SourceFile(fam, disk) + ' block ' + StrUtil.NumStr(id));
  BldShow.Fixing(fam, disk);
  ok := True;
  fixed := False;
  held := False;
  note := '';
  target := DataBld.ResolveBlock(disk, id);
  if target = 0 then
    note := 'the block is not there'
  else if DataBld.BlockShared(disk, id, target) then
    target := DataBld.SplitBlock(disk, id, target, note);
  room := 0;
  if target > 0 then begin
    { room for the block grown by every part that names it }
    room := blocks^[target].rawSize;
    for p := first to DataPat.PART_COUNT do
      if DataBld.SameBlockPart(first, p) then
        Inc(room, DataPat.parts^[p].newLen);
    if room > MAX_ENCODED then
      room := MAX_ENCODED;
    if (blocks^[target].disk = 0) or (blocks^[target].packedSize = 0) or (blocks^[target].rawSize = 0) or
        (blocks^[target].rawSize > MAX_ENCODED) then
      note := 'the block cannot be patched'
    else
      ok := DataBld.Reserve(LongInt(blocks^[target].packedSize) + 2 * room + 24);
  end;
  if ok and (note = '') then begin
    rawLen := blocks^[target].rawSize;
    GetMem(raw, room);
    GetMem(spare, room);
    held := True;
    ok := DataBld.ReadBlock(fam, target, raw);
  end;
  if ok then begin
    q := pos;
    for p := first to DataPat.PART_COUNT do begin
      if DataBld.SameBlockPart(first, p) and ((p = first) or not DataBld.SameFix(p - 1, p)) then
        if note <> '' then
          DataBld.LogLine(archiveName + '.DAX: ' + DataBld.IssueName(DataPat.parts^[p].issue) + ' skipped: ' + note)
        else if DataBld.ApplyFix(fam, p, q, raw, spare, room, rawLen, why) then begin
          fixed := True;
          DataBld.LogLine(archiveName + '.DAX: ' + DataBld.IssueName(DataPat.parts^[p].issue) + ' applied');
        end else
          DataBld.LogLine(archiveName + '.DAX: ' + DataBld.IssueName(DataPat.parts^[p].issue) + ' skipped: ' + why);
      Inc(q, DataPat.parts^[p].origLen + DataPat.parts^[p].newLen);
    end;
    if fixed then begin
      blocks^[target].disk := 0;
      blocks^[target].start := 0;
      blocks^[target].rawSize := rawLen;
      DataBld.EncodeRuns(raw^, rawLen, blocks^[target].mem, blocks^[target].packedSize);
      ok := failNote = '';
    end;
  end;
  if held then begin
    FreeMem(spare, room);
    FreeMem(raw, room);
  end;
  PatchBlock := ok;
end;

{ Make the family's fixes, block by block. False, with failNote set, on a read error or a shortage of memory. }
function ApplyPatches(fam: Byte): Boolean;
var
  p: Word;
  q: Word;
  pos: Word;
  ok: Boolean;
  firstOnBlock: Boolean;
begin
  ok := True;
  pos := 0;
  for p := 1 to DataPat.PART_COUNT do begin
    if ok and (DataPat.parts^[p].family = fam) then begin
      firstOnBlock := True;
      for q := 1 to p - 1 do
        if DataBld.SameBlockPart(q, p) then
          firstOnBlock := False;
      if firstOnBlock then
        ok := DataBld.PatchBlock(fam, p, pos);
    end;
    Inc(pos, DataPat.parts^[p].origLen + DataPat.parts^[p].newLen);
  end;
  ApplyPatches := ok;
end;

{ The 8X8D family's scroll bar block (C_DATA.SCROLL_BAR_BLOCK): BarArt's cells, made from symbol block 202 as the
  build has it. Without block 202 there is no bar block, which the log says; the game then draws its bars without the
  cells. False, with failNote set, only when 202 cannot be read or memory runs short. }
function AddScrollBar(fam: Byte): Boolean;
var
  target: Word;
  raw: PBytes;
  bar: BarArt.TBarBlock;
  len: Word;
  ok: Boolean;
begin
  ok := True;
  target := DataBld.ResolveBlock(1, 202);
  if target = 0 then
    DataBld.LogLine(archiveName + '.DAX: no scroll bar: block 202 is not there')
  else begin
    len := blocks^[target].rawSize;
    ok := DataBld.Reserve(LongInt(blocks^[target].packedSize) + len + 24);
    if ok then begin
      GetMem(raw, len);
      ok := DataBld.ReadBlock(fam, target, raw);
      if ok then
        if BarArt.MakeBlock(raw^, len, bar) then begin
          DataBld.AddMemoryBlock(C_DATA.SCROLL_BAR_BLOCK, bar, BarArt.BLOCK_BYTES);
          DataBld.LogLine(archiveName + '.DAX: scroll bar added (block ' + StrUtil.NumStr(C_DATA.SCROLL_BAR_BLOCK) +
                          ')');
        end else
          DataBld.LogLine(archiveName + '.DAX: no scroll bar: block 202 is too short');
      FreeMem(raw, len);
    end;
  end;
  AddScrollBar := ok;
end;

{ Build the family's merged archive from sources: choose ids, apply patches, add the port's blocks (AddScrollBar), the
  sources, remap and version blocks, write TMP\<name>.DAX, read it back and rename it to <name>.DAX. False, with
  failNote set, on any failure. }
function BuildArchive(fam: Byte): Boolean;
var
  table: array[0..3 * MAX_REMAPS - 1] of Byte;
  version: array[0..VERSION_RAW - 1] of Byte;
  r: Word;
  f: file;
  ok: Boolean;
begin
  ok := DataBld.ChooseIds(fam);
  if ok then
    ok := DataBld.ApplyPatches(fam);
  if ok and (fam = C_DATA.FAMILY_8X8D) then
    ok := DataBld.AddScrollBar(fam);
  if ok then begin
    DataBld.AddMemoryBlock(C_DATA.SOURCES_BLOCK, sourceList, sourceListLen);
    if remapCount > 0 then begin
      for r := 1 to remapCount do begin
        table[3 * (r - 1)] := remapDisk[r];
        table[3 * (r - 1) + 1] := remapFrom[r];
        table[3 * (r - 1) + 2] := remapTo[r];
      end;
      DataBld.AddMemoryBlock(C_DATA.REMAP_BLOCK, table, 3 * remapCount);
    end;
    { WriteArchive puts in the version and the CRC-32 }
    FillChar(version, SizeOf(version), 0);
    DataBld.AddMemoryBlock(C_DATA.VERSION_BLOCK, version, VERSION_RAW);
    ok := failNote = '';
  end;
  if ok then begin
    DataBld.Progress(archiveName + '.DAX: writing');
    ok := DataBld.WriteArchive(fam);
  end;
  if ok then begin
    DataBld.Progress(archiveName + '.DAX: checking');
    BldShow.Checking;
    ok := DataBld.ArchiveSound(DataBld.TempPath);
    if not ok then
      DataBld.Fail(DataBld.TempLabel + ' did not read back whole');
  end;
  if ok then begin
    DataBld.RemoveFile(archiveName + '.DAX');
    Assign(f, DataBld.TempPath);
    lastError := 0;
    Rename(f, DataBld.GamePath(archiveName + '.DAX'));
    ok := DataBld.IoOk;
    if not ok then
      DataBld.FailWriting('renaming ' + DataBld.TempLabel + ': DOS error ' + StrUtil.NumStr(lastError));
  end;
  BuildArchive := ok;
end;

{ Build the family's merged archive when the disk has room for it, unless the game folder could not be written for an
  earlier one or there was not memory enough to start. Every outcome is logged. A family that fails is left without a
  merged archive, so the game reads its per-disk archives. }
procedure UpdateFamily(fam: Byte);
var
  i: Word;
begin
  archiveName := DataArc.MergedName(fam);
  failNote := '';
  blockCount := 0;
  remapCount := 0;
  if writeNote <> '' then
    DataBld.Fail('not tried: ' + writeNote)
  else if memNote <> '' then
    DataBld.Fail('not tried: ' + memNote)
  else if DataBld.HasRoom(fam) and DataBld.CanWrite and DataBld.ReadSources(fam) then
    if sourceCount = 0 then begin
      DataBld.LogLine(archiveName + '.DAX skipped: no per-disk archives');
      DataBld.RemoveTemp;
      DataBld.RemoveFile(archiveName + '.DAX');
    end else begin
      for i := 1 to sourceCount do
        if sources^[i].id >= C_DATA.PORT_BLOCK_FIRST then
          DataBld.Fail('a per-disk archive uses block ' + StrUtil.NumStr(sources^[i].id));
      if failNote = '' then
        if DataBld.BuildArchive(fam) then begin
          DataBld.LogLine(archiveName + '.DAX built: ' + StrUtil.NumStr(blockCount) + ' blocks, ' +
                          StrUtil.NumStr(remapCount) + ' collisions');
          Inc(builtCount);
        end;
    end;
  if failNote <> '' then begin
    DataBld.LogLine(archiveName + '.DAX FAILED: ' + failNote);
    DataBld.RemoveTemp;
    DataBld.RemoveFile(archiveName + '.DAX');
    Inc(failedCount);
  end;
  for i := blockCount downto 1 do
    if (blocks^[i].disk = 0) and (blocks^[i].packedSize > 0) then
      FreeMem(blocks^[i].mem, blocks^[i].packedSize);
end;

procedure BuildDataFiles;
var
  stale: BldShow.TStaleList;
  anyStale: Boolean;
  fam: Byte;
  oldFileMode: Byte;
begin
  { the game's files are only read }
  oldFileMode := FileMode;
  FileMode := 0;
  { a quick save from before #1080 moves from slot Q to slot Z, which frees Q for the Load/Save menu's Quit }
  SaveMenu.MoveOldQuickSave;
  { GameInit2 looked at 8X8D.DAX before this, with the game folder unset }
  DaxIo.ResetArchiveCache;
  { the temporary copies' names before #1150, <name>.$$$ in the game folder, which a build cut short left there; to be
    dropped a release or two on }
  DataBld.RemoveFile('DATABLD.$$$');
  for fam := 1 to C_DATA.FAMILIES do
    DataBld.RemoveFile(DataArc.MergedName(fam) + '.$$$');
  anyStale := False;
  for fam := 1 to C_DATA.FAMILIES do begin
    stale[fam] := not DaxIo.FamilyUsable(fam) and DataBld.HasFiles(fam);
    if stale[fam] then
      anyStale := True;
  end;
  if anyStale then begin
    Assign(logFile, DataBld.GamePath(LOG_NAME));
    Rewrite(logFile);
    logOpen := IOResult = 0;
    { the game folder is tried once before any family: when it cannot be written, every family waits }
    writeNote := '';
    memNote := '';
    failNote := '';
    archiveName := 'DATABLD';
    if DataBld.CanWrite then
      DataBld.RemoveTemp;
    BldShow.Open(stale, writeNote = '');
    DataBld.Progress('Please wait, constructing data files...');
    DataBld.LogLine('Merged data archives, version ' + StrUtil.NumStr(C_DATA.VERSION));
    builtCount := 0;
    keptCount := 0;
    failedCount := 0;
    crcTable := nil;
    { kept apart from writeNote, which BldShow.Open was given above and which means the folder cannot be written }
    if MaxAvail < SizeOf(TCrcTable) + 2 * CHUNK_SIZE + 2 * SizeOf(TBlockList) + DataPat.TABLE_BYTES + 1024 then
      memNote := 'not enough memory'
    else begin
      GetMem(crcTable, SizeOf(TCrcTable));
      GetMem(bufA, CHUNK_SIZE);
      GetMem(bufB, CHUNK_SIZE);
      GetMem(sources, SizeOf(TBlockList));
      GetMem(blocks, SizeOf(TBlockList));
      DataBld.InitCrcTable;
      { the data fixes, on the heap only while the archives are built (#964) }
      if not DataPat.LoadTable then
        memNote := 'the data fixes do not add up';
    end;
    for fam := 1 to C_DATA.FAMILIES do
      if stale[fam] then begin
        BldShow.StartFamily(fam);
        DataBld.UpdateFamily(fam);
        BldShow.EndFamily(fam, failNote = '');
      end else if DataBld.HasFiles(fam) then begin
        DataBld.LogLine(DataArc.MergedName(fam) + '.DAX up to date');
        Inc(keptCount);
      end;
    if crcTable <> nil then begin
      DataPat.FreeTable;
      FreeMem(blocks, SizeOf(TBlockList));
      FreeMem(sources, SizeOf(TBlockList));
      FreeMem(bufB, CHUNK_SIZE);
      FreeMem(bufA, CHUNK_SIZE);
      FreeMem(crcTable, SizeOf(TCrcTable));
      crcTable := nil;
    end;
    DataBld.LogLine('Done: ' + StrUtil.NumStr(builtCount) + ' built, ' + StrUtil.NumStr(keptCount) +
                    ' up to date, ' + StrUtil.NumStr(failedCount) + ' failed.');
    if logOpen then
      Close(logFile);
    n := IOResult;
    logOpen := False;
    TextRend.ClearBottomLine;
    BldShow.Finish(failedCount > 0);
    DaxIo.ResetArchiveCache;
  end;
  FileMode := oldFileMode;
end;

end.
