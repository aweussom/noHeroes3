class_name Pathfinder
extends RefCounted
## Grid pathfinding over a MapModel's passability. Pure logic (no rendering) — wraps Godot's
## AStarGrid2D so we don't hand-roll A*. Built once per map; rebuild if the map changes.
##
## Costs follow HoMM3's convention: a straight step is 100, a diagonal step ~141 (≈100·√2).
## Movement points are spent in these units, so Hero.movement_points reads on the same scale.

const STEP_STRAIGHT := 100
const STEP_DIAGONAL := 141

var _astar := AStarGrid2D.new()

func _init(model: MapModel) -> void:
	_astar.region = Rect2i(0, 0, model.width, model.height)
	_astar.cell_size = Vector2.ONE
	# Allow diagonals, but not squeezing between two blocked corners.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_astar.update()
	for y in model.height:
		for x in model.width:
			if not model.is_passable(x, y):
				_astar.set_point_solid(Vector2i(x, y), true)

## Full path of cells from `from` to `to`, inclusive of both ends. Empty if unreachable.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _astar.get_id_path(from, to)

## How far along `path` (from find_path) the hero can actually afford with `points` movement.
## Returns { "cells": Array[Vector2i] of steps to walk (excludes the start), "cost": int }.
func reachable_prefix(path: Array[Vector2i], points: int) -> Dictionary:
	var cells: Array[Vector2i] = []
	var cost := 0
	for i in range(1, path.size()):
		var step := _step_cost(path[i - 1], path[i])
		if cost + step > points:
			break
		cost += step
		cells.append(path[i])
	return {"cells": cells, "cost": cost}

func _step_cost(a: Vector2i, b: Vector2i) -> int:
	var d := b - a
	return STEP_DIAGONAL if (d.x != 0 and d.y != 0) else STEP_STRAIGHT
