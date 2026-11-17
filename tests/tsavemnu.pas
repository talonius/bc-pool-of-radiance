{ Tests for SaveMenu.MoveOldQuickSave (#1080): a quick save from before #1080, in slot Q, moves whole to slot Z, the
  quick save's slot now, its savgam files, vault copy and members' files with it, and a move ended part way, run
  again, keeps the files it had already moved (#1085); nothing moves while slot Z holds a save, or when slot Q holds
  none. }
{$I COMPILER.INC}
program TSaveMnu;

uses GameVars, FileUtil, SaveMenu, TestKit;

{ the files the tests make; each holds its own name }
const
  FILE_COUNT = 5;
  SUFFIXES: array[1..FILE_COUNT] of string[12] = ('savgam?.dat', 'savgam?.inf', 'savgam?.sts', 'vault?.dat',
                                                  'CHRDAT?1.sav');

{ Suffix i with its ? made letter. }
function Named(i: Byte; letter: Char): FileUtil.TSetName;
var
  name: FileUtil.TSetName;
begin
  name := SUFFIXES[i];
  name[Pos('?', name)] := letter;
  Named := name;
end;

{ Write file name holding text. }
procedure Make(name: FileUtil.TSetName; text: FileUtil.TSetName);
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, '');
  TestKit.Check(FileUtil.WriteToSet(s, name, text, SizeOf(text)) and FileUtil.CommitSet(s), name + ' is written');
end;

{ What file name holds, or '' when it does not read. }
function Held(name: FileUtil.TSetName): FileUtil.TSetName;
var
  text: FileUtil.TSetName;
begin
  Held := '';
  if FileUtil.ReadRecord(name, text, SizeOf(text)) then
    Held := text;
end;

{ Erase every file the tests make, in slots Q and Z. }
procedure Clear;
var
  i: Byte;
begin
  for i := 1 to FILE_COUNT do begin
    FileUtil.DeleteFile(Named(i, 'Q'));
    FileUtil.DeleteFile(Named(i, 'Z'));
  end;
end;

var
  i: Byte;

begin
  TestKit.Start('TSAVEMNU');
  GameVars.saveDirectory := '';
  Clear;

  { a quick save in slot Q moves whole to slot Z }
  for i := 1 to FILE_COUNT do
    Make(Named(i, 'Q'), Named(i, 'Q'));
  SaveMenu.MoveOldQuickSave;
  for i := 1 to FILE_COUNT do begin
    TestKit.Check(not FileUtil.Exists(Named(i, 'Q')), Named(i, 'Q') + ' is gone');
    TestKit.CheckEqualsS(Named(i, 'Q'), Held(Named(i, 'Z')), Named(i, 'Z') + ' holds what Q''s held');
  end;

  { a move ended part way, with the .sts and the member's file already in Z and the rest, the .dat with them, still in
    Q, is run again: every file is in Z, the two moved before as they were (#1085) }
  Clear;
  for i := 1 to FILE_COUNT do
    if (i = 3) or (i = 5) then
      Make(Named(i, 'Z'), Named(i, 'Q'))
    else
      Make(Named(i, 'Q'), Named(i, 'Q'));
  SaveMenu.MoveOldQuickSave;
  for i := 1 to FILE_COUNT do begin
    TestKit.Check(not FileUtil.Exists(Named(i, 'Q')), 'after a rerun ' + Named(i, 'Q') + ' is gone');
    TestKit.CheckEqualsS(Named(i, 'Q'), Held(Named(i, 'Z')), 'and ' + Named(i, 'Z') + ' holds what Q''s held');
  end;

  { nothing moves while slot Z holds a save }
  Clear;
  Make(Named(1, 'Q'), 'OLD');
  Make(Named(2, 'Q'), 'OLD INF');
  Make(Named(1, 'Z'), 'NEW');
  SaveMenu.MoveOldQuickSave;
  TestKit.CheckEqualsS('OLD', Held(Named(1, 'Q')), 'Q''s save stays');
  TestKit.CheckEqualsS('OLD INF', Held(Named(2, 'Q')), 'Q''s .inf stays');
  TestKit.CheckEqualsS('NEW', Held(Named(1, 'Z')), 'Z''s save stays');
  TestKit.Check(not FileUtil.Exists(Named(2, 'Z')), 'no .inf comes to Z');

  { with no save in slot Q, slot Z's files stay }
  Clear;
  Make(Named(2, 'Q'), 'ORPHAN');
  Make(Named(3, 'Z'), 'Z STS');
  SaveMenu.MoveOldQuickSave;
  TestKit.CheckEqualsS('ORPHAN', Held(Named(2, 'Q')), 'Q''s .inf without a save stays');
  TestKit.CheckEqualsS('Z STS', Held(Named(3, 'Z')), 'Z''s .sts stays');

  Clear;

  { the time a slot was saved, as Load/Save shows it }
  TestKit.CheckEqualsS('8:57 PM', SaveMenu.ClockText(20, 57), 'evening: 12-hour, PM');
  TestKit.CheckEqualsS('12:04 PM', SaveMenu.ClockText(12, 4), 'noon is 12 PM');
  TestKit.CheckEqualsS('12:30 AM', SaveMenu.ClockText(0, 30), 'midnight is 12 AM');
  TestKit.CheckEqualsS('9:05 AM', SaveMenu.ClockText(9, 5), 'the minutes two digits');
  TestKit.CheckEqualsS('11:59 PM', SaveMenu.ClockText(23, 59), 'the longest, 8 characters');
  TestKit.Done;
end.
