{ Tests for MenuCore.ScrollThumb, the scroll bar's knob (docs/screen-mocks/scrollbar.txt): its length is the share of
  the list shown, rounded, on a track apart from the list; it touches the track's ends only at the list's ends. }
{$I COMPILER.INC}
program TScroll;

uses MenuCore, TestKit;

var
  first: Integer;
  size: Integer;

begin
  TestKit.Start('TSCROLL');
  { a box of 13 rows whose bar is as long, as the shop's old text bar was }
  MenuCore.ScrollThumb(10, 13, 13, 0, first, size);
  TestKit.Check((first = 0) and (size = 13), 'a list that fits: the whole track');
  MenuCore.ScrollThumb(26, 13, 13, 0, first, size);
  TestKit.Check((first = 0) and (size = 7), 'twice the box: half the track, 6.5 rounded, at the top');
  MenuCore.ScrollThumb(26, 13, 13, 13, first, size);
  TestKit.Check(first + size = 13, 'at the end: at the bottom');
  MenuCore.ScrollThumb(26, 13, 13, 12, first, size);
  TestKit.Check(first + size < 13, 'a line short of the end: off the bottom');
  MenuCore.ScrollThumb(26, 13, 13, 1, first, size);
  TestKit.Check(first > 0, 'a line past the start: off the top');
  MenuCore.ScrollThumb(1000, 13, 13, 500, first, size);
  TestKit.Check((size = 1) and (first > 0) and (first < 12), 'a long list: a one-row knob in the middle');

  { the mocks: the knob on the edge bar's track, the arrows taking two of the bar's rows }
  MenuCore.ScrollThumb(11, 7, 20, 0, first, size);
  TestKit.Check((first = 0) and (size = 13), 'Load/Save, 7 of 11 slots on 20 rows: 13 rows, at the top');
  MenuCore.ScrollThumb(11, 7, 20, 4, first, size);
  TestKit.Check(first + size = 20, 'Load/Save at its last slots: at the bottom');
  MenuCore.ScrollThumb(20, 13, 11, 0, first, size);
  TestKit.Check((first = 0) and (size = 7), 'the shop, 13 of 20 items on 11 rows: 7 rows');

  { the knob never fills the track while there is more }
  MenuCore.ScrollThumb(21, 20, 10, 0, first, size);
  TestKit.CheckEqualsL(9, size, '20 of 21 shown: a row short of the track, not all of it');
  MenuCore.ScrollThumb(21, 20, 10, 1, first, size);
  TestKit.CheckEqualsL(1, first, 'and the last line shown moves it to the bottom');
  MenuCore.ScrollThumb(5, 3, 1, 1, first, size);
  TestKit.Check((first = 0) and (size = 1), 'a one-row track: the knob is the track');
  TestKit.Done;
end.
