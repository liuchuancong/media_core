/// Grid shape of the wall.
///
/// A wall is a fixed grid whose capacity is what the device can decode, not what
/// the viewer would like: each cell is a live decoder, and a phone that is asked
/// for nine of them does not show nine streams, it shows nine stalls. The
/// capacities below are the ones the reference implementation settled on after
/// watching devices fail, and they are per-platform defaults rather than
/// constants so a host can lower them further.
enum MultiviewLayout {
  /// One cell: a normal player, kept so a wall can shrink without a special case.
  single,

  /// Two cells side by side.
  dual,

  /// Four cells in a 2x2 grid.
  quad,

  /// Nine cells in a 3x3 grid.
  nine,

  /// One large cell with the others along the bottom.
  focus;

  /// How many cells this layout shows.
  int get capacity => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad => 4,
    MultiviewLayout.nine => 9,
    MultiviewLayout.focus => 5,
  };

  /// Columns in the grid, or `1` for [MultiviewLayout.focus] — a focus layout is
  /// not a grid, and pretending it has one makes aspect math wrong.
  int get columns => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 2,
    MultiviewLayout.quad => 2,
    MultiviewLayout.nine => 3,
    MultiviewLayout.focus => 1,
  };

  /// Rows in the grid, or `1` for [MultiviewLayout.focus].
  int get rows => switch (this) {
    MultiviewLayout.single => 1,
    MultiviewLayout.dual => 1,
    MultiviewLayout.quad => 2,
    MultiviewLayout.nine => 3,
    MultiviewLayout.focus => 1,
  };

  /// Whether the layout has one promoted cell and the rest in a rail.
  bool get hasFocusedCell => this == MultiviewLayout.focus;

  /// Whether [cellCount] fits.
  bool accepts(int cellCount) => cellCount <= capacity;
}
