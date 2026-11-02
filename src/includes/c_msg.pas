{ The text window's message area: its first and last column and its bottom and top row. }
{$I COMPILER.INC}
unit C_MSG;

interface

const
  TEXT_LEFT = 1;
  TEXT_TOP = 1;
  TEXT_RIGHT = 38;
  TEXT_BOTTOM = 22;
  MESSAGE_TOP = 17;
  { the combat message panel, right of the arena: from COMBAT_LEFT to TEXT_RIGHT, its messages from COMBAT_MESSAGE_TOP
    down to COMBAT_BOTTOM }
  COMBAT_LEFT = 23;
  COMBAT_MESSAGE_TOP = 10;
  COMBAT_BOTTOM = 21;
  { The combat panel on the 640 x 400 screen (#1231), in cells of its 80 x 50 grid inside the panel window's border,
    from FINE_LEFT to FINE_RIGHT: the creature's details from FINE_INFO_TOP to FINE_INFO_BOTTOM, the minimap from
    FINE_MAP_TOP to FINE_MAP_BOTTOM, and the messages, the newest last, from FINE_LOG_TOP to FINE_LOG_BOTTOM. }
  FINE_LEFT = 46;
  FINE_RIGHT = 77;
  FINE_INFO_TOP = 2;
  FINE_INFO_BOTTOM = 7;
  FINE_MAP_TOP = 9;
  FINE_MAP_BOTTOM = 24;
  FINE_LOG_TOP = 26;
  FINE_LOG_BOTTOM = 43;
  { the strip under the 640 x 400 layout on 640 x 480 squashed (CharDisp.DrawStrip), in fine rows: the party, as Gold
    Box Companion shows it, and where the party is }
  STRIP_TOP = 50;
  STRIP_BOTTOM = 59;
  { the bottom-line prompt that waits for Enter, SSI's 'PRESS <RETURN> TO CONTINUE' in the port's words }
  CONTINUE_PROMPT = 'press <enter>/<return> to continue';

implementation

end.
