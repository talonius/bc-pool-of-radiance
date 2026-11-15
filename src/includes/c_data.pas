{ Constants for the merged archives built by DataBld: family indexes, archive
  version, size limits, and reserved block IDs. DataBld and DataPat are the
  authoritative users of this format. }
{$I COMPILER.INC}
unit C_DATA;

interface

const
  { data families, each merged into one archive (DataArc's family table) }
  FAMILIES = 14;
  { places in that table: scripts, maps, placed items, monsters and monsters' items }
  FAMILY_ECL = 1;
  FAMILY_GEO = 2;
  FAMILY_8X8D = 8;
  FAMILY_ITEM = 9;
  FAMILY_MONCHA = 10;
  FAMILY_MONITM = 11;
  { The archive layout and the data patches DataBld applies (DataPat). DaxIo.FamilyUsable rejects an archive holding
    another version, so raising it makes the next start rebuild every family's archive, with the patches as they are
    now. }
  VERSION = 47;
  { Reserved block ids, the last blocks of a merged archive; the remap block is there only when some ids collided. The
    sources block lists, per per-disk archive read, its disk, file size and CRC-32; the remap block holds the collisions
    as triples (disk, original id, merged id); the version block holds VERSION and the CRC-32 of every byte of the file
    before that block's data. }
  SOURCES_BLOCK = 253;
  { Block ids for data the port adds, PORT_BLOCK_FIRST up to the reserved blocks: no spare id is chosen from them, and a
    per-disk archive that uses one is not merged. Pool's archives use no id above 249. }
  PORT_BLOCK_FIRST = 250;
  { the scroll bar's cells in the 8X8D archive (BarArt, docs/screen-mocks/scrollbar.txt) }
  SCROLL_BAR_BLOCK = 250;
  REMAP_BLOCK = 254;
  VERSION_BLOCK = 255;
  { the most collisions one family may have: DataBld builds no more into a merged archive's remap block, and DaxIo keeps
    that many for every family }
  FAMILY_REMAPS = 16;
  { the largest packed block DaxIo.LoadDax reads: a directory entry with a larger one ends the game ('tempsize'), as
    SSI's did; DataBld keeps every block it packs within it }
  PACKED_LIMIT = 36000;
  { the sources block's bytes per per-disk archive: disk, then file size and CRC-32 (4 bytes each, low byte first) }
  SOURCE_RECORD = 9;

implementation

end.
