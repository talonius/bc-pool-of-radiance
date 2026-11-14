{ Implements the in-game Companion Tools. When enabled, F6 opens the tools from
  the map and camp menus outside combat. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit CompTool;

interface

{ The Tools screen, on the whole area's map (explored squares, events, notes and the Clue Book's keys marked) in a 3D
  area (#691, #856): Map, a cursor on it to read the keys and write the player's notes on squares, and Character, the
  character editor, until Exit or Escape.
  Nothing happens with the setting off. The caller redraws its screen afterwards. }
procedure ToolsMenu;

implementation

uses Crt, Types, C_AREA, C_DIR, C_KEYS, C_MSG, GameDefs, GameVars, TextRend, Border, MenuCore, Blit, View3D, AreaName,
  Explored, EvtKind, CharEdit, MapNotes, ClueBook, StrUtil;

const
  { the map's top-left character cell; a square is one 8x8 symbol }
  MAP_COL = 2;
  MAP_ROW = 3;
  { the legend's column, right of the map: its longest line, CGA's 'Magenta: Player Note' (20 characters), ends on
    column 38, inside the frame on column 39 }
  LEGEND_COL = 19;
  { the Map tool's lines below the map: the cursor's square and the Clue Book's key there, then the player's note }
  KEY_ROW = 20;
  PLAYER_ROW = KEY_ROW + 1;
  NOTE_COL = MAP_COL + 6;
  { how ShowSymbol marks a square's walls: not at all, the Clue Book's key, the player's note (which shows over a key) }
  MARK_NONE = 0;
  MARK_CLUE = 1;
  MARK_NOTE = 2;
  { symbol set 4 (GameDefs.symSetFirst[4] = 256): the party's arrows by facing div 2, then the sixteen wall
    combinations, 260 + N + E * 2 + S * 4 + W * 8, as View3D.DrawAutoMap draws them }
  SYM_SET = 4;
  SYM_ARROW = 256;
  SYM_WALLS = 260;
  { the square colour of each event kind, EvtKind's KIND_EVENT to KIND_EXIT, and its legend }
  KIND_COLOURS: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Byte = (Blue, Cyan, Red, Brown, Green, Magenta,
                                                                         LightBlue);
  { CGA's: its three colours besides black, shared by kinds alike (people, danger, places) }
  KIND_COLOURS_CGA: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Byte = (Cyan, Cyan, Magenta, White, White,
                                                                             Magenta, White);
  KIND_NAMES: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of string[8] = ('event', 'message', 'trap', 'treasure',
                                                                           'service', 'fight', 'exit');

{ The walls' colour of a square with the player's note: yellow, or light magenta in CGA's four colours. }
function NoteColour: Byte;
begin
  if GameVars.video.colours >= 16 then
    NoteColour := Yellow
  else
    NoteColour := LightMagenta;
end;

{ Draw symbol at (col, row), straight to the screen, a step darker when dim, on a square of colour fill unless fill is
  DarkGray (the symbols' own); in CGA's four colours, which draw both greys alike, a square not dim has white walls
  instead. A square marked MARK_NOTE has walls in NoteColour, one marked MARK_CLUE light cyan walls, and the cursor's
  square black walls on white. }
procedure ShowSymbol(col, row: ShortInt; symbol: Word; dim: Boolean; fill: Byte; mark: Byte; cursor: Boolean);
var
  symbols: Types.PImgBuf;
  glyph: Types.PImgBuf;
  fromT: Types.TColorTab;
  toT: Types.TColorTab;
  c: Byte;
  remap: Boolean;
begin
  symbols := GameVars.symbolSetPtrs[SYM_SET];
  glyph := GameVars.sym8x8Buf;
  if (symbols = nil) or (glyph = nil) then Exit;
  Move(symbols^.data[(symbol - GameDefs.symSetFirst[SYM_SET]) * symbols^.imgSize], glyph^.data, symbols^.imgSize);
  { the set's colour map, which CGA's remap translates the tables' colours through }
  glyph^.map := symbols^.map;
  for c := 0 to 15 do begin
    fromT[c] := c;
    toT[c] := c;
  end;
  if GameVars.video.colours >= 16 then begin
    { the symbols draw light grey and white walls on a dark grey square: dimmed, the walls go dark grey and the square
      black }
    if dim then begin
      toT[DarkGray] := Black;
      toT[LightGray] := DarkGray;
      toT[White] := DarkGray;
    end;
  end else if not dim then
    { CGA draws both greys in one of its colours, so they look alike: there a visited square's light grey walls are
      white instead }
    toT[LightGray] := White;
  if fill <> DarkGray then
    toT[DarkGray] := fill;
  if mark <> MARK_NONE then begin
    if mark = MARK_CLUE then
      toT[LightGray] := LightCyan
    else
      toT[LightGray] := NoteColour;
    toT[White] := toT[LightGray];
  end;
  if cursor then begin
    toT[DarkGray] := White;
    toT[LightGray] := Black;
    toT[White] := Black;
  end;
  remap := False;
  for c := 0 to 15 do
    if toT[c] <> c then
      remap := True;
  if remap then
    Blit.RemapPic(fromT, toT, 0, False, glyph);
  Blit.ShowPic(col, row, glyph);
end;

{ The square colour of event kind in the current video mode. }
function KindColour(kind: Byte): Byte;
begin
  if GameVars.video.colours >= 16 then
    KindColour := KIND_COLOURS[kind]
  else
    KindColour := KIND_COLOURS_CGA[kind];
end;

{ True when the Clue Book's keys show: the Companion Tools' Clue Book Notes setting is on. }
function CluesShown: Boolean;
begin
  CluesShown := GameVars.clueNotesOn <> 0;
end;

{ Square (mx, my) of the current 3D area on the map: its walls (secret ones too, as the map data holds them), dimmed
  unless visited, coloured by what its event does (EvtKind, prepared), its note or else its Clue Book key marked, and
  the cursor on it when cursor; the party's arrow on the party's square. }
procedure DrawSquare(mx, my: ShortInt; cursor: Boolean);
var
  sym: Word;
  kind: Byte;
  fill: Byte;
  mark: Byte;
  script: Byte;
  map: Byte;
begin
  script := GameVars.eclScriptId;
  map := GameVars.zone0^.mapId.lo;
  sym := SYM_WALLS;
  if View3D.GetWallType(mx, my, C_DIR.NORTH) > 0 then Inc(sym);
  if View3D.GetWallType(mx, my, C_DIR.EAST) > 0 then Inc(sym, 2);
  if View3D.GetWallType(mx, my, C_DIR.SOUTH) > 0 then Inc(sym, 4);
  if View3D.GetWallType(mx, my, C_DIR.WEST) > 0 then Inc(sym, 8);
  if (mx = GameVars.gMapX) and (my = GameVars.gMapY) then
    sym := SYM_ARROW + GameVars.gFacing div 2;
  kind := EvtKind.Kind(View3D.GetMapEvent(mx, my));
  fill := DarkGray;
  if kind <> EvtKind.KIND_NONE then
    fill := KindColour(kind);
  mark := MARK_NONE;
  if MapNotes.Note(script, map, mx, my) <> '' then
    mark := MARK_NOTE
  else if CompTool.CluesShown and ClueBook.Marked(map, mx, my) then
    mark := MARK_CLUE;
  ShowSymbol(MAP_COL + mx, MAP_ROW + my, sym, not Explored.Visited(script, map, mx, my), fill, mark, cursor);
end;

{ The whole current 3D area, square by square (DrawSquare), and a legend headed by the area's name: the marks, the
  party's square, and the kinds of event the area has, each beside a square of its colour. }
procedure DrawMap;
var
  mx: ShortInt;
  my: ShortInt;
  kind: Byte;
  used: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Boolean;
  row: Byte;
begin
  EvtKind.Prepare;
  FillChar(used, SizeOf(used), False);
  Border.ClearToFrame;
  for my := 0 to 15 do
    for mx := 0 to 15 do begin
      DrawSquare(mx, my, False);
      kind := EvtKind.Kind(View3D.GetMapEvent(mx, my));
      if kind <> EvtKind.KIND_NONE then
        used[kind] := True;
    end;
  TextRend.DisplayString(LEGEND_COL, MAP_ROW, White, AreaName.CurrentArea);
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 2, LightGreen, 'Bright: visited');
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 3, DarkGray, 'Dim: not visited');
  { named for the colour the map draws notes in }
  if NoteColour = Yellow then
    TextRend.DisplayString(LEGEND_COL, MAP_ROW + 4, Yellow, 'Yellow: Player Note')
  else
    TextRend.DisplayString(LEGEND_COL, MAP_ROW + 4, NoteColour, 'Magenta: Player Note');
  row := MAP_ROW + 5;
  if CompTool.CluesShown then begin
    TextRend.DisplayString(LEGEND_COL, row, LightCyan, 'Cyan: Clue Book');
    Inc(row);
  end;
  TextRend.DisplayString(LEGEND_COL, row, LightGreen, 'Party at ' + StrUtil.NumStr(GameVars.gMapX) + ',' +
                         StrUtil.NumStr(GameVars.gMapY));
  Inc(row, 2);
  for kind := EvtKind.KIND_EVENT to EvtKind.KIND_EXIT do
    if used[kind] then begin
      ShowSymbol(LEGEND_COL, row, SYM_WALLS, False, KindColour(kind), MARK_NONE, False);
      TextRend.DisplayString(LEGEND_COL + 2, row, LightGreen, KIND_NAMES[kind]);
      Inc(row);
    end;
end;

{ True in a 3D area; in the wilderness, which has its own map, it says so. }
function OnAreaMap: Boolean;
begin
  OnAreaMap := GameVars.gLocType = C_AREA.LOC_3D_MAP;
  if GameVars.gLocType <> C_AREA.LOC_3D_MAP then begin
    TextRend.DisplayAndPause(Yellow, 'The wilderness has its own map.');
    TextRend.ClearBottomLine;
  end;
end;

{ The Tools screen: the whole area's map in a 3D area, else the frame alone, and its title in the frame's top. }
procedure DrawTools;
begin
  if GameVars.gLocType = C_AREA.LOC_3D_MAP then
    DrawMap
  else begin
    Border.ClearToFrame;
  end;
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT, C_MSG.TEXT_RIGHT, C_MSG.TEXT_TOP, White, 'Companion Tools');
end;

{ The Map tool, on the Tools screen's map: a cursor, from the party's square, which the arrows move. Below the map show
  the square, the Clue Book's key on it (while the Clue Book Notes setting is on) and, under that, the player's note on
  it, which Write and Clear change; the key stays whatever the note says. }
procedure MapTool;
var
  ch: Char;
  ext: Boolean;
  cx: ShortInt;
  cy: ShortInt;
  nx: ShortInt;
  ny: ShortInt;
  script: Byte;
  map: Byte;
  text: MapNotes.TNoteText;
begin
  if not OnAreaMap then Exit;
  script := GameVars.eclScriptId;
  map := GameVars.zone0^.mapId.lo;
  cx := GameVars.gMapX;
  cy := GameVars.gMapY;
  repeat
    DrawSquare(cx, cy, True);
    TextRend.ClearRect(MAP_COL, KEY_ROW, C_MSG.TEXT_RIGHT - 1, PLAYER_ROW);
    TextRend.DisplayString(MAP_COL, KEY_ROW, LightGreen, StrUtil.NumStr(cx) + ',' + StrUtil.NumStr(cy) + ' ');
    if CompTool.CluesShown then
      TextRend.DisplayString(NOTE_COL, KEY_ROW, LightCyan, ClueBook.Note(map, cx, cy));
    TextRend.DisplayString(NOTE_COL, PLAYER_ROW, NoteColour, MapNotes.Note(script, map, cx, cy));
    MenuCore.arrowsToCaller := True;
    ch := MenuCore.MenuHorizontal('Map: ', 'Write Clear Exit', LightMagenta, LightGreen, White, True, False, ext);
    nx := cx;
    ny := cy;
    if ext then
      case ch of
        C_KEYS.LEFT: if cx > 0 then Dec(nx);
        C_KEYS.RIGHT: if cx < 15 then Inc(nx);
        C_KEYS.UP: if cy > 0 then Dec(ny);
        C_KEYS.DOWN: if cy < 15 then Inc(ny);
      end
    else
      case ch of
        'W': begin
               text := TextRend.ReadString('Note: ', LightGreen, MapNotes.NOTE_LEN);
               if text <> '' then
                 if not MapNotes.SetNote(script, map, cx, cy, text) then
                   TextRend.DisplayAndPause(Yellow, 'The notes are full.');
             end;
        'C': MapNotes.ClearNote(script, map, cx, cy);
      end;
    if (nx <> cx) or (ny <> cy) or not ext then begin
      DrawSquare(cx, cy, False);
      cx := nx;
      cy := ny;
    end;
  until (not ext) and (ch in [C_KEYS.NONE, 'E']);
  TextRend.ClearRect(MAP_COL, KEY_ROW, C_MSG.TEXT_RIGHT - 1, PLAYER_ROW);
  TextRend.ClearBottomLine;
end;

procedure ToolsMenu;
var
  ch: Char;
  ext: Boolean;
begin
  if GameVars.companionOn = 0 then Exit;
  DrawTools;
  repeat
    ch := MenuCore.MenuHorizontal('Tools: ', 'Map Character Exit', LightMagenta, LightGreen, White, False, False,
                                  ext);
    case ch of
      'M': MapTool;
      'C': begin
             CharEdit.EditMenu;
             DrawTools;
           end;
    end;
  until ch in [C_KEYS.NONE, 'E'];
  TextRend.ClearBottomLine;
end;

end.
