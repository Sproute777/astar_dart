import 'dart:math';

import 'package:flutter/foundation.dart';

import '../astar_dart.dart';
import 'astar_grid.dart';

class AStarSquareGrid extends AstarGrid {
  final int _rows;
  final int _columns;
  late Point<int> _start;
  late Point<int> _end;
  late final Array2d<Barrier> _barriers;
  late final Array2d<int> _grounds;

  late DiagonalMovement _diagonalMovement;
  final List<ANode> _doneList = [];
  final List<ANode> _waitList = [];

  late Array2d<ANode> _grid;

  AStarSquareGrid({
    required int rows,
    required int columns,
    DiagonalMovement diagonalMovement = DiagonalMovement.euclidean,
  })  : _rows = rows,
        _columns = columns,
        _diagonalMovement = diagonalMovement {
    _grounds = Array2d<int>(rows, columns, defaultValue: 1);
    _barriers = Array2d<Barrier>(rows, columns, defaultValue: Barrier.pass);
    _grid = Array2d(rows, columns, defaultValue: ANode.wrong);
  }
  void setDiagonalMovement(DiagonalMovement diagonalMovement) {
    _diagonalMovement = diagonalMovement;
  }

  void setBarrier(BarrierPoint point) {
    assert(point.x <= _rows, "Point can't be bigger than Array2d rows");
    assert(point.y <= _columns, "Point can't be bigger than Array2d column");
    _barriers[point.x][point.y] = point.barrier;
  }

  void setBarriers(List<BarrierPoint> points) {
    for (final point in points) {
      assert(point.x <= _rows, "Point can't be bigger than Array2d rows");
      assert(point.y <= _columns, "Point can't be bigger than Array2d columns");

      _barriers[point.x][point.y] = point.barrier;
    }
  }

  void setPoint(WeightedPoint point) {
    assert(point.x <= _rows, "Point can't be bigger than Array2d rows");
    assert(point.y <= _columns, "Point can't be bigger than Array2d columns");
    _grounds[point.x][point.y] = point.weight;
  }

  void setPoints(List<WeightedPoint> points) {
    for (final point in points) {
      assert(point.x <= _rows, "Point can't be bigger than Array2d rows");
      assert(point.y <= _columns, "Point can't be bigger than Array2d columns");
      _grounds[point.x][point.y] = point.weight;
    }
  }

  void calculateGrid() {
    _createGrid(rows: _rows, columns: _columns);
  }

  /// return full path without Start position
  @override
  List<ANode> findPath(
      {void Function(List<Point<int>>)? doneList,
      required Point<int> start,
      required Point<int> end}) {
    _start = start;
    _end = end;
    _doneList.clear();
    _waitList.clear();

    if (_barriers[_end.x][_end.y].isBlock) {
      return [];
    }
    if (_isNeighbors(start, end)) {
      return [];
    }

    ANode startANode = _grid[_start.x][_start.y];

    ANode endANode = _grid[_end.x][_end.y];
    _addNeighbors();
    ANode? winner = _getANodeWinner(
      startANode,
      endANode,
    );

    List<ANode> path = [_grid[_end.x][_end.y]];
    if (winner?.parent != null) {
      ANode tileAux = winner!.parent!;
      for (int i = 0; i < winner.g - 1; i++) {
        if (tileAux.x == _start.x && tileAux.y == _start.y) {
          break;
        }
        path.add(tileAux);
        tileAux = tileAux.parent!;
      }
    }
    doneList?.call(_doneList.map((e) => Point(e.x, e.y)).toList());

    if (winner == null && !_isNeighbors(_start, _end)) {
      path.clear();
    }

    return path.reversed.toList();
  }

  void _createGrid({
    required int rows,
    required int columns,
  }) {
    for (int x = 0; x < rows; x++) {
      for (int y = 0; y < columns; y++) {
        _grid[x][y] = ANode(
          x: x,
          y: y,
          neighbors: [],
          weight: _grounds[x][y].toDouble(),
        );
      }
    }
  }

  /// find steps area , useful for Turn Based Game
  /// example 3 steps
  /// ```
  ///          3
  ///       3  2  3
  ///    3  2  1  2  3
  /// 3  2  1  🧍‍♂️ 1  2  3
  ///    3  2  1  2  3
  ///       3  2  3
  ///          3
  /// ```
  List<Point<int>> findSteps({required int steps, required Point<int> start}) {
    _addNeighbors();

    ANode startANode = _grid[start.x][start.y];
    final List<ANode> totalArea = [startANode];
    final List<ANode> waitArea = [];

    final List<ANode> currentArea = [...startANode.neighbors];
    if (currentArea.isEmpty) {
      return totalArea.map((tile) => Point(tile.x, tile.y)).toList();
    }
    for (var element in startANode.neighbors) {
      element.parent = startANode;
      element.g = element.weight + startANode.weight;
    }
    for (var i = 1; i < steps + 2; i++) {
      if (currentArea.isEmpty) continue;
      for (var currentANode in currentArea) {
        if (currentANode.g <= i) {
          totalArea.add(currentANode);
          for (var n in currentANode.neighbors) {
            if (totalArea.contains(n)) continue;
            if (n.parent == null) {
              n.parent = currentANode;
              n.g = n.weight + currentANode.g;
            }
            waitArea.add(n);
          }
        } else {
          waitArea.add(currentANode);
        }
      }
      currentArea.clear();
      currentArea.addAll(waitArea);
      waitArea.clear();
    }
    return totalArea.map((tile) => Point(tile.x, tile.y)).toList();
  }

  /// MIT
  /// https://github.com/RafaelBarbosatec/a_star/blob/main/lib/a_star_algorithm.dart
  /// Method recursive that execute the A* algorithm
  ANode? _getANodeWinner(ANode current, ANode end) {
    _waitList.remove(current);
    if (end == current) return current;
    for (final n in current.neighbors) {
      if (n.parent == null) {
        _analiseDistance(n, end, parent: current);
      }
      if (!_doneList.contains(n)) {
        _waitList.add(n);
      }
    }
    _doneList.add(current);
    _waitList.sort((a, b) => a.f.compareTo(b.f));

    for (final element in _waitList) {
      if (!_doneList.contains(element)) {
        final result = _getANodeWinner(element, end);
        return result;
      }
    }

    return null;
  }

  void _analiseDistance(ANode current, ANode end, {required ANode parent}) {
    current.parent = parent;
    current.g = parent.g + current.weight;
    current.h = _distance(current, end);
  }

  /// Calculates the distance between two tiles.
  double _distance(ANode current, ANode target) {
    int toX = current.x - target.x;
    int toY = current.y - target.y;
    return Point(toX, toY).magnitude * 2;
  }

  /// MIT
  /// https://github.com/RafaelBarbosatec/a_star/blob/main/lib/a_star_algorithm.dart
  /// Example:
  /// [(1,2),(1,3),(1,4),(1,5)] = [(1,2),(1,5)]
  static List<Point<int>> resumePath(Iterable<Point<int>> path) {
    List<Point<int>> newPath =
        _resumeDirection(path, TypeResumeDirection.axisX);
    newPath = _resumeDirection(newPath, TypeResumeDirection.axisY);
    newPath = _resumeDirection(newPath, TypeResumeDirection.bottomLeft);
    newPath = _resumeDirection(newPath, TypeResumeDirection.bottomRight);
    newPath = _resumeDirection(newPath, TypeResumeDirection.topLeft);
    newPath = _resumeDirection(newPath, TypeResumeDirection.topRight);
    return newPath;
  }

  /// MIT
  /// https://github.com/RafaelBarbosatec/a_star/blob/main/lib/a_star_algorithm.dart
  static List<Point<int>> _resumeDirection(
    Iterable<Point<int>> path,
    TypeResumeDirection type,
  ) {
    List<Point<int>> newPath = [];
    List<List<Point<int>>> listPoint = [];
    int indexList = -1;
    int currentX = 0;
    int currentY = 0;

    for (var element in path) {
      final dxDiagonal = element.x;
      final dyDiagonal = element.y;

      switch (type) {
        case TypeResumeDirection.axisX:
          if (element.x == currentX && listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
        case TypeResumeDirection.axisY:
          if (element.y == currentY && listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
        case TypeResumeDirection.topLeft:
          final nextDxDiagonal = (currentX - 1);
          final nextDyDiagonal = (currentY - 1);
          if (dxDiagonal == nextDxDiagonal &&
              dyDiagonal == nextDyDiagonal &&
              listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
        case TypeResumeDirection.bottomLeft:
          final nextDxDiagonal = (currentX - 1);
          final nextDyDiagonal = (currentY + 1);
          if (dxDiagonal == nextDxDiagonal &&
              dyDiagonal == nextDyDiagonal &&
              listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
        case TypeResumeDirection.topRight:
          final nextDxDiagonal = (currentX + 1).floor();
          final nextDyDiagonal = (currentY - 1).floor();
          if (dxDiagonal == nextDxDiagonal &&
              dyDiagonal == nextDyDiagonal &&
              listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
        case TypeResumeDirection.bottomRight:
          final nextDxDiagonal = (currentX + 1);
          final nextDyDiagonal = (currentY + 1);
          if (dxDiagonal == nextDxDiagonal &&
              dyDiagonal == nextDyDiagonal &&
              listPoint.isNotEmpty) {
            listPoint[indexList].add(element);
          } else {
            listPoint.add([element]);
            indexList++;
          }
          break;
      }

      currentX = element.x;
      currentY = element.y;
    }

    // for in faster than forEach
    for (final element in listPoint) {
      if (element.length > 1) {
        newPath.add(element.first);
        newPath.add(element.last);
      } else {
        newPath.add(element.first);
      }
    }

    return newPath;
  }

  bool _isNeighbors(Point<int> start, Point<int> end) {
    if (_diagonalMovement == DiagonalMovement.euclidean) {
      if (start.x + 1 == end.x ||
          start.x - 1 == end.x ||
          start.y + 1 == end.y ||
          start.y - 1 == end.y) {
        return true;
      }
    }
    if (_diagonalMovement == DiagonalMovement.manhattan) {
      if ((start.x + 1 == end.x || start.x - 1 == end.x) && start.y == end.y ||
          (start.y + 1 == end.y || start.y - 1 == end.y) && start.x == end.x) {
        return true;
      }
    }
    return false;
  }

  /// Adds neighbors to cells
  void _addNeighbors() {
    for (var row in _grid.array) {
      for (ANode tile in row) {
        _chainNeigbors(tile);
      }
    }
  }

  void _chainNeigbors(
    ANode tile,
  ) {
    final x = tile.x;
    final y = tile.y;

    /// adds in top
    if (y > 0) {
      final t = _grid[x][y - 1];
      if (!_barriers[t.x][t.y].isBlock) {
        tile.neighbors.add(t);
      }
    }

    /// adds in bottom
    if (y < (_grid.first.length - 1)) {
      final t = _grid[x][y + 1];
      if (!_barriers[t.x][t.y].isBlock) {
        tile.neighbors.add(t);
      }
    }

    /// adds in left
    if (x > 0) {
      final t = _grid[x - 1][y];
      if (!_barriers[t.x][t.y].isBlock) {
        tile.neighbors.add(t);
      }
    }

    /// adds in right
    if (x < (_grid.length - 1)) {
      final t = _grid[x + 1][y];
      if (!_barriers[t.x][t.y].isBlock) {
        tile.neighbors.add(t);
      }
    }

    if (_diagonalMovement == DiagonalMovement.euclidean) {
      /// adds in top-left
      if (y > 0 && x > 0) {
        final t = _grid[x - 1][y - 1];
        if (!_barriers[t.x][t.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in top-right
      if (y > 0 && x < (_grid.length - 1)) {
        final t = _grid[x + 1][y - 1];
        if (!_barriers[t.x][t.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in bottom-left
      if (x > 0 && y < (_grid.first.length - 1)) {
        final t = _grid[x - 1][y + 1];
        if (!_barriers[t.x][t.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in bottom-right
      if (x < (_grid.length - 1) && y < (_grid.first.length - 1)) {
        final t = _grid[x + 1][y + 1];
        if (!_barriers[t.x][t.y].isBlock) {
          tile.neighbors.add(t);
        }
      }
    }
  }

  @visibleForTesting
  Array2d<ANode> get grid => _grid;
}

/// MIT
/// https://github.com/RafaelBarbosatec/a_star/blob/main/lib/a_star_algorithm.dart
enum TypeResumeDirection {
  axisX,
  axisY,
  topLeft,
  bottomLeft,
  topRight,
  bottomRight,
}
