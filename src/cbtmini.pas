{ The combat minimap (#1210): the whole 50 x 25 cell arena, 2 pixels a cell, in the bottom of the combat panel. Walls
  are blue and the creatures dots coloured by side, as their names are (CharDisp.NameColor). The Minimap setting and F3
  on the combat menu turn it on and off (GameVars.minimapOn). It is drawn while a party member's turn waits for a
  command, as it moves and as it aims, and the messages of an action write over it until the next of those. On the
  640 x 400 screen (#1231) it is 5 pixels a cell, below the creature's details, and the messages have rows of their
  own. }
{$O+,F+}
{$I COMPILER.INC}
unit CbtMini;

interface

uses Crt, Types, C_MSG;

const
  { the text cells the map is drawn in: columns 24 to 36 and rows 15 to 21 of the panel (23,1)-(38,21), below the
    creature's name, hit points, armor class, weapon and status (rows 1 to 11) }
  FIRST_COL = 24;
  LAST_COL = 36;
  FIRST_ROW = 15;
  LAST_ROW = 21;
  { pixels an arena cell takes each way, and the map's size in pixels: 100 x 50 }
  CELL_PX = 2;
  MAP_WIDTH = (Types.ARENA_LAST_X + 1) * CELL_PX;
  MAP_HEIGHT = (Types.ARENA_LAST_Y + 1) * CELL_PX;
  { the map's place in those cells' 104 x 56 pixels, centred }
  LEFT_PX = ((LAST_COL - FIRST_COL + 1) * 8 - MAP_WIDTH) div 2;
  TOP_PX = ((LAST_ROW - FIRST_ROW + 1) * 8 - MAP_HEIGHT) div 2;
  { the colours: the floor (and what is not on the arena) as Border.ClearBox leaves the panel; walls blue, which CGA
    shows as black, so CGA shows the creatures only; the party light cyan, enemies yellow and a creature out of action
    light red, as their names; the creature whose turn it is white, and the aim cursor light magenta }
  FLOOR_COLOR = Black;
  WALL_COLOR = Blue;
  PARTY_COLOR = LightCyan;
  ENEMY_COLOR = Yellow;
  DOWN_COLOR = LightRed;
  CURRENT_COLOR = White;
  CURSOR_COLOR = LightMagenta;
  { Show's cursor cell for none }
  NO_CURSOR = -1;
  { On the 640 x 400 screen (#1231) the map is FINE_CELL_PX pixels a cell, 250 x 125, as large as the panel's width
    allows, centred in the fine panel's map
    cells (C_MSG.FINE_LEFT to FINE_RIGHT, FINE_MAP_TOP to FINE_MAP_BOTTOM): FINE_LEFT_PX and FINE_TOP_PX in from their
    corner. }
  FINE_CELL_PX = 5;
  FINE_LEFT_PX = ((C_MSG.FINE_RIGHT - C_MSG.FINE_LEFT + 1) * 8 - (Types.ARENA_LAST_X + 1) * FINE_CELL_PX) div 2;
  FINE_TOP_PX = ((C_MSG.FINE_MAP_BOTTOM - C_MSG.FINE_MAP_TOP + 1) * 8 - (Types.ARENA_LAST_Y + 1) * FINE_CELL_PX) div 2;

type
  { a colour for each arena cell, [y, x] as TArena.cells }
  TMiniGrid = array[0..Types.ARENA_LAST_Y, 0..Types.ARENA_LAST_X] of Byte;
  PMiniGrid = ^TMiniGrid;

{ Fill grid from the arena: walls (terrain 0 is off the arena, and stays floor), then the creatures in play
  (GameVars.creatureArr and arenaLoc), those out of action first so the living stand over them, then current, then the
  aim cursor at (cursorX, cursorY) when it is on the arena (NO_CURSOR for none). }
procedure Build(var grid: TMiniGrid; current: Types.PCharRecord; cursorX, cursorY: ShortInt);

{ The colour of pixel (px, py) of the map's cells (0..103, 0..55): its arena cell's in grid, or the floor's in the
  margin round the map. }
function PixelColor(var grid: TMiniGrid; px, py: Byte): Byte;

{ Draw the map in the panel when the Minimap setting is on and the game is in combat beside the 7x7 view (the
  full-width one, #1211, has no panel), current being the creature whose turn it is and (cursorX, cursorY) the aim
  cursor's cell (NO_CURSOR for none); on the 640 x 400 screen, at FINE_CELL_PX pixels a cell (#1231). Its buffers are
  taken for the drawing only; without the memory for them nothing is drawn. }
procedure Show(current: Types.PCharRecord; cursorX, cursorY: ShortInt);

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}C_IFC, GameDefs, GameVars, Pathing, Blit, VidOps, CbtMap;

const
  { a terrain's movement cost that no creature can pay: a wall (Pathing's WALL_COST) }
  WALL_COST = 255;

{ Colour the footprint of the creature in slot i (Pathing.GetIconTileDelta) color. }
procedure PutCreature(var grid: TMiniGrid; i: Byte; color: Byte);
var
  k: Byte;
  dx: ShortInt;
  dy: ShortInt;
  x: ShortInt;
  y: ShortInt;
begin
  for k := 0 to 3 do
    if Pathing.GetIconTileDelta(GameVars.arenaLoc[i].size, k, dx, dy) then begin
      x := GameVars.arenaLoc[i].x + dx;
      y := GameVars.arenaLoc[i].y + dy;
      if Pathing.OnArena(x, y) then
        grid[y, x] := color;
    end;
end;

procedure Build(var grid: TMiniGrid; current: Types.PCharRecord; cursorX, cursorY: ShortInt);
var
  x: Byte;
  y: Byte;
  t: Byte;
  i: Byte;
  pass: Byte;
  p: Types.PCharRecord;
begin
  for y := 0 to Types.ARENA_LAST_Y do
    for x := 0 to Types.ARENA_LAST_X do begin
      t := GameVars.arenaPtr^.cells[y, x];
      if (t > 0) and (GameDefs.terrainInfo[t].cost = WALL_COST) then
        grid[y, x] := WALL_COLOR
      else
        grid[y, x] := FLOOR_COLOR;
    end;
  { the creatures out of action first (pass 0), then those in it (pass 1) }
  for pass := 0 to 1 do
    for i := 1 to Pathing.LastSlot do begin
      p := GameVars.creatureArr[i];
      if (GameVars.arenaLoc[i].size > 0) and (p <> nil) and (Ord(p^.enabled <> 0) = pass) then
        if p = current then
          CbtMini.PutCreature(grid, i, CURRENT_COLOR)
        else if p^.enabled = 0 then
          CbtMini.PutCreature(grid, i, DOWN_COLOR)
        else if p^.hostile = 1 then
          CbtMini.PutCreature(grid, i, ENEMY_COLOR)
        else
          CbtMini.PutCreature(grid, i, PARTY_COLOR);
    end;
  if Pathing.OnArena(cursorX, cursorY) then
    grid[cursorY, cursorX] := CURSOR_COLOR;
end;

function PixelColor(var grid: TMiniGrid; px, py: Byte): Byte;
begin
  if (px < LEFT_PX) or (px >= LEFT_PX + MAP_WIDTH) or (py < TOP_PX) or (py >= TOP_PX + MAP_HEIGHT) then
    PixelColor := FLOOR_COLOR
  else
    PixelColor := grid[(py - TOP_PX) div CELL_PX, (px - LEFT_PX) div CELL_PX];
end;

{ Draw the map from grid at the screen's own pixels, FINE_CELL_PX a cell, filling the fine panel's map cells (#1231): a
  scanline at a time, the margins black. }
procedure ShowFine(var grid: TMiniGrid);
var
  line: array[0..(C_MSG.FINE_RIGHT - C_MSG.FINE_LEFT + 1) * 8 - 1] of Byte;
  x: Byte;
  y: Integer;
  i: Byte;
  py: Word;
  top: Word;
begin
  top := C_MSG.FINE_MAP_TOP * 8;
  for y := -1 to Types.ARENA_LAST_Y + 1 do begin
    FillChar(line, SizeOf(line), FLOOR_COLOR);
    { row -1 is the margin above the map, and ARENA_LAST_Y + 1 the one below }
    if (y >= 0) and (y <= Types.ARENA_LAST_Y) then
      for x := 0 to Types.ARENA_LAST_X do
        FillChar(line[FINE_LEFT_PX + x * FINE_CELL_PX], FINE_CELL_PX, grid[y, x]);
    if y < 0 then
      for i := 0 to FINE_TOP_PX - 1 do
        GameVars.video.PutPixels(C_MSG.FINE_LEFT * 8, top + i, line, SizeOf(line))
    else if y > Types.ARENA_LAST_Y then
      for py := top + FINE_TOP_PX + (Types.ARENA_LAST_Y + 1) * FINE_CELL_PX to C_MSG.FINE_MAP_BOTTOM * 8 + 7 do
        GameVars.video.PutPixels(C_MSG.FINE_LEFT * 8, py, line, SizeOf(line))
    else
      for i := 0 to FINE_CELL_PX - 1 do
        GameVars.video.PutPixels(C_MSG.FINE_LEFT * 8, top + FINE_TOP_PX + y * FINE_CELL_PX + i, line, SizeOf(line));
  end;
end;

procedure Show(current: Types.PCharRecord; cursorX, cursorY: ShortInt);
var
  grid: PMiniGrid;
  cell: Types.PImgBuf;
  px: Types.TPixelRow;
  col: Byte;
  row: Byte;
  x: Byte;
  y: Byte;
begin
  { the full-width combat view has no panel to draw it in (#1211) }
  if (GameVars.minimapOn = 0) or (GameVars.ifcState <> C_IFC.IN_COMBAT) or (GameVars.arenaPtr = nil) or
     CbtMap.wideLayout then Exit;
  if GameVars.video.fine then begin
    if MaxAvail < SizeOf(TMiniGrid) + 1024 then Exit;
    GetMem(grid, SizeOf(TMiniGrid));
    CbtMini.Build(grid^, current, cursorX, cursorY);
    CbtMini.ShowFine(grid^);
    FreeMem(grid, SizeOf(TMiniGrid));
    Exit;
  end;
  { the grid, and one 8 x 8 cell in the video mode's layout (64 bytes on VGA) with its header and mask }
  if MaxAvail < SizeOf(TMiniGrid) + LongInt(Blit.FrameBytes(8, 1)) + 1024 then Exit;
  GetMem(grid, SizeOf(TMiniGrid));
  Blit.AllocPic(8, 1, 1, 0, cell);
  CbtMini.Build(grid^, current, cursorX, cursorY);
  { each text cell's 8 scanlines into the scratch cell, then the cell to the screen, as BldShow draws its cells }
  for row := FIRST_ROW to LAST_ROW do
    for col := FIRST_COL to LAST_COL do begin
      for y := 0 to 7 do begin
        for x := 0 to 7 do
          px[x] := CbtMini.PixelColor(grid^, (col - FIRST_COL) * 8 + x, (row - FIRST_ROW) * 8 + y);
        VidOps.PutPixelRow(cell, 0, y, px);
      end;
      Blit.ShowPic(col, row, cell);
    end;
  Blit.FreePic(cell);
  FreeMem(grid, SizeOf(TMiniGrid));
end;

end.
