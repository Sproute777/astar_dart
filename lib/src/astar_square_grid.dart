import 'dart:math';

import 'package:astar_dart/src/tile.dart';

import '../astar_dart.dart';
import 'astar_grid.dart';

class AStarSquareGrid extends AstarGrid {
  final int _rows;
  final int _columns;
  late Point<int> _start;
  late Point<int> _end;
  late final Array2d<Barrier> _barriers;
  late final Array2d<int> _grounds;

  final DiagonalMovement diagonalMovement;
  final List<Tile> _doneList = [];
  final List<Tile> _waitList = [];

  late Array2d<Tile> _grid;

  AStarSquareGrid({
    required int rows,
    required int columns,
    this.diagonalMovement = DiagonalMovement.euclidean,
  })  : _rows = rows,
        _columns = columns {
    _grounds = Array2d<int>(rows, columns, defaultValue: 1);
    _barriers = Array2d<Barrier>(rows, columns, defaultValue: Barrier.pass);
  }

  void setBarrier(BarrierPoint point) {
    _barriers[point.x][point.y] = point.barrier;
  }

  void setBarriers(List<BarrierPoint> points) {
    for (final point in points) {
      // assert(point.x <= _rows, "Point can't be bigger than Array2d width");
      // assert(point.y <= _columns, "Point can't be bigger than Array2d height");
      _barriers[point.x][point.y] = point.barrier;
    }
  }

  void setPoints(List<WeightedPoint> points) {
    for (final point in points) {
      // assert(point.x <= _rows, "Point can't be bigger than Array2d width");
      // assert(point.y <= _columns, "Point can't be bigger than Array2d height");
      _grounds[point.x][point.y] = point.weight;
    }
  }

  void calculateGrid() {
    _grid = _createGridWithBarriers(rows: _rows, columns: _columns);
  }

  void setPoint(WeightedPoint point) {
    _grounds[point.x][point.y] = point.weight;
  }

  @override
  Iterable<Point<int>> findThePath(
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

    Tile startTile = _grid[_start.x][_start.y];

    Tile endTile = _grid[_end.x][_end.y];
    _addNeighbors();
    Tile? winner = _getTileWinner(
      startTile,
      endTile,
    );

    List<Point<int>> path = [_end];
    if (winner?.parent != null) {
      Tile tileAux = winner!.parent!;
      for (int i = 0; i < winner.g - 1; i++) {
        if (tileAux.x == _start.x && tileAux.y == _start.y) {
          break;
        }
        path.add(Point(tileAux.x, tileAux.y));
        tileAux = tileAux.parent!;
      }
    }
    doneList?.call(_doneList.map((e) => Point(e.x, e.y)).toList());

    if (winner == null && !_isNeighbors(_start, _end)) {
      path.clear();
    }
    path.add(_start);

    return path.reversed;
  }

  /// Method that create the grid using barriers
  Array2d<Tile> _createGridWithBarriers({
    required int rows,
    required int columns,
  }) {
    final initGrid = Array2d(rows, columns, defaultValue: Tile.wrong);
    List.generate(rows, (x) {
      List.generate(columns, (y) {
        initGrid[x][y] = Tile(
          x: x,
          y: y,
          neighbors: [],
          weight: _grounds[x][y].toDouble(),
        );
      });
    });
    return initGrid;
  }

  /// find steps area , useful for Turn Based Game
  List<Point<int>> findSteps({required int steps, required Point<int> start}) {
    _addNeighbors();

    Tile startTile = _grid[start.x][start.y];
    final List<Tile> totalArea = [startTile];
    final List<Tile> waitArea = [];

    final List<Tile> currentArea = [...startTile.neighbors];
    if (currentArea.isEmpty) {
      return totalArea.map((tile) => Point(tile.x, tile.y)).toList();
    }
    for (var element in startTile.neighbors) {
      element.parent = startTile;
      element.g = element.weight + startTile.weight;
    }
    for (var i = 1; i < steps + 2; i++) {
      if (currentArea.isEmpty) continue;
      for (var currentTile in currentArea) {
        if (currentTile.g <= i) {
          totalArea.add(currentTile);
          for (var n in currentTile.neighbors) {
            if (totalArea.contains(n)) continue;
            if (n.parent == null) {
              n.parent = currentTile;
              n.g = n.weight + currentTile.g;
            }
            waitArea.add(n);
          }
        } else {
          waitArea.add(currentTile);
        }
      }
      currentArea.clear();
      currentArea.addAll(waitArea);
      waitArea.clear();
    }
    return totalArea.map((tile) => Point(tile.x, tile.y)).toList();
  }

  /// Method recursive that execute the A* algorithm
  Tile? _getTileWinner(Tile current, Tile end) {
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
        final result = _getTileWinner(element, end);
        if (result != null) {
          return result;
        }
      }
    }

    return null;
  }

  /// Calculates the distance g and h
  void _analiseDistance(Tile current, Tile end, {required Tile parent}) {
    current.parent = parent;
    current.g = parent.g + current.weight;
    current.h = _distance(current, end);
  }

  /// Calculates the distance between two tiles.
  double _distance(Tile current, Tile target) {
    int toX = current.x - target.x;
    int toY = current.y - target.y;
    return Point(toX, toY).magnitude * 2;
  }


  /// Resume path
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
    for (var element in listPoint) {
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
    bool isNeighbor = false;
    if (start.x + 1 == end.x) {
      isNeighbor = true;
    }

    if (start.x - 1 == end.x) {
      isNeighbor = true;
    }

    if (start.y + 1 == end.y) {
      isNeighbor = true;
    }

    if (start.y - 1 == end.y) {
      isNeighbor = true;
    }

    return isNeighbor;
  }

  /// Adds neighbors to cells
  void _addNeighbors() {
    for (var row in _grid.array) {
      for (Tile tile in row) {
        _chainNeigbors(tile);
      }
    }
  }

  void _chainNeigbors(
    Tile tile,
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

    if (diagonalMovement == DiagonalMovement.euclidean) {
      /// adds in top-left
      if (y > 0 && x > 0) {
        final top = _grid[x][y - 1];
        final left = _grid[x - 1][y];
        final t = _grid[x - 1][y - 1];
        if (!_barriers[t.x][t.y].isBlock &&
            !_barriers[left.x][left.y].isBlock &&
            !_barriers[top.x][top.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in top-right
      if (y > 0 && x < (_grid.length - 1)) {
        final top = _grid[x][y - 1];
        final right = _grid[x + 1][y];
        final t = _grid[x + 1][y - 1];
        if (!_barriers[t.x][t.y].isBlock &&
            !_barriers[top.x][top.y].isBlock &&
            !_barriers[right.x][right.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in bottom-left
      if (x > 0 && y < (_grid.first.length - 1)) {
        final bottom = _grid[x][y + 1];
        final left = _grid[x - 1][y];
        final t = _grid[x - 1][y + 1];
        if (!_barriers[t.x][t.y].isBlock &&
            !_barriers[bottom.x][bottom.y].isBlock &&
            !_barriers[left.x][left.y].isBlock) {
          tile.neighbors.add(t);
        }
      }

      /// adds in bottom-right
      if (x < (_grid.length - 1) && y < (_grid.first.length - 1)) {
        final bottom = _grid[x][y + 1];
        final right = _grid[x + 1][y];
        final t = _grid[x + 1][y + 1];
        if (!_barriers[t.x][t.y].isBlock &&
            !_barriers[bottom.x][bottom.y].isBlock &&
            !_barriers[right.x][right.y].isBlock) {
          tile.neighbors.add(t);
        }
      }
    }
  }
}

enum TypeResumeDirection {
  axisX,
  axisY,
  topLeft,
  bottomLeft,
  topRight,
  bottomRight,
}