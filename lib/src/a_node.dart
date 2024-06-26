class ANode {
  final int x;
  final int y;
  ANode? parent;
  final List<ANode> neighbors;
  late double _weight;

  /// distanse from current to start
  double g = 0;

  /// distanse from current to end
  double h = 0;

  /// total distance
  double get f => g + h;

  ANode(
      {required this.x,
      required this.y,
      required this.neighbors,
      this.parent,
      double weight = 1}) {
    _weight = weight;
  }

  void setWeight(double weight) {
    _weight = weight;
  }

  double get weight => _weight;

  @override
  bool operator ==(covariant ANode other) {
    if (identical(this, other)) return true;
    return other.x == x && other.y == y;
  }

  @override
  int get hashCode {
    return Object.hashAll([x, y]);
  }

  static final wrong = ANode(x: -1, y: -1, neighbors: []);
}
