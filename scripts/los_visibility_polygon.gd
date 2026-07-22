class_name LOSVisibilityPolygon
extends RefCounted

## Active-edge rotational sweep adapted from byronknoll/visibility-polygon-js
## and the CC0 Godot port at kratocz/godot-visibility-polygon.

const EPSILON: float = 0.00001


class Endpoint:
	var segment_index: int
	var endpoint_index: int
	var angle: float

	func _init(new_segment_index: int, new_endpoint_index: int, new_angle: float) -> void:
		segment_index = new_segment_index
		endpoint_index = new_endpoint_index
		angle = new_angle


static func compute(
		observer: Vector2,
		input_segments: Array[PackedVector2Array],
		map_bounds: Rect2
) -> PackedVector2Array:
	if map_bounds.size.x <= EPSILON or map_bounds.size.y <= EPSILON:
		return PackedVector2Array()
	if not map_bounds.grow(EPSILON).has_point(observer):
		return PackedVector2Array()
	var segments: Array[PackedVector2Array] = _copy_valid_segments(input_segments)
	_append_map_bounds(segments, map_bounds)
	segments = _break_intersections(segments)
	if segments.size() < 4:
		return PackedVector2Array()
	return _sweep(observer, segments)


static func _copy_valid_segments(
		input_segments: Array[PackedVector2Array]
) -> Array[PackedVector2Array]:
	var output: Array[PackedVector2Array] = []
	for segment: PackedVector2Array in input_segments:
		if segment.size() != 2:
			continue
		if segment[0].distance_squared_to(segment[1]) <= EPSILON * EPSILON:
			continue
		_append_unique_segment(output, segment[0], segment[1])
	return output


static func _append_map_bounds(segments: Array[PackedVector2Array], bounds: Rect2) -> void:
	var top_left: Vector2 = bounds.position
	var top_right: Vector2 = Vector2(bounds.end.x, bounds.position.y)
	var bottom_right: Vector2 = bounds.end
	var bottom_left: Vector2 = Vector2(bounds.position.x, bounds.end.y)
	_append_unique_segment(segments, top_left, top_right)
	_append_unique_segment(segments, top_right, bottom_right)
	_append_unique_segment(segments, bottom_right, bottom_left)
	_append_unique_segment(segments, bottom_left, top_left)


static func _break_intersections(
		segments: Array[PackedVector2Array]
) -> Array[PackedVector2Array]:
	var output: Array[PackedVector2Array] = []
	for index: int in range(segments.size()):
		var start: Vector2 = segments[index][0]
		var end: Vector2 = segments[index][1]
		var points: Array[Vector2] = [start, end]
		for other_index: int in range(segments.size()):
			if index == other_index:
				continue
			var intersection: Variant = Geometry2D.segment_intersects_segment(
				start,
				end,
				segments[other_index][0],
				segments[other_index][1]
			)
			if intersection is Vector2:
				_append_unique_point(points, intersection as Vector2)
		var sorted_points: Array[Vector2] = _sort_points_along_segment(points, start)
		for point_index: int in range(1, sorted_points.size()):
			_append_unique_segment(
				output,
				sorted_points[point_index - 1],
				sorted_points[point_index]
			)
	return output


static func _sort_points_along_segment(
		points: Array[Vector2],
		start: Vector2
) -> Array[Vector2]:
	var sorted: Array[Vector2] = []
	for point: Vector2 in points:
		var insert_at: int = sorted.size()
		var distance: float = start.distance_squared_to(point)
		for index: int in range(sorted.size()):
			if distance < start.distance_squared_to(sorted[index]):
				insert_at = index
				break
		sorted.insert(insert_at, point)
	return sorted


static func _append_unique_point(points: Array[Vector2], point: Vector2) -> void:
	for existing: Vector2 in points:
		if existing.distance_squared_to(point) <= EPSILON * EPSILON:
			return
	points.append(point)


static func _append_unique_segment(
		segments: Array[PackedVector2Array],
		start: Vector2,
		end: Vector2
) -> void:
	if start.distance_squared_to(end) <= EPSILON * EPSILON:
		return
	for existing: PackedVector2Array in segments:
		if (
			(existing[0].is_equal_approx(start) and existing[1].is_equal_approx(end))
			or (existing[0].is_equal_approx(end) and existing[1].is_equal_approx(start))
		):
			return
	segments.append(PackedVector2Array([start, end]))


static func _sweep(
		observer: Vector2,
		segments: Array[PackedVector2Array]
) -> PackedVector2Array:
	var sorted_endpoints: Array[Endpoint] = _sort_endpoints(observer, segments)
	var segment_heap_positions: Array[int] = []
	segment_heap_positions.resize(segments.size())
	segment_heap_positions.fill(-1)
	var heap: Array[int] = []
	var initial_destination: Vector2 = observer + Vector2.RIGHT
	for segment_index: int in range(segments.size()):
		var first_angle: float = _angle_degrees(segments[segment_index][0], observer)
		var second_angle: float = _angle_degrees(segments[segment_index][1], observer)
		var active: bool = false
		if (
			first_angle > -180.0
			and first_angle <= 0.0
			and second_angle <= 180.0
			and second_angle >= 0.0
			and second_angle - first_angle > 180.0
		):
			active = true
		if (
			second_angle > -180.0
			and second_angle <= 0.0
			and first_angle <= 180.0
			and first_angle >= 0.0
			and first_angle - second_angle > 180.0
		):
			active = true
		if active:
			_insert_segment(
				segment_index,
				heap,
				observer,
				segments,
				initial_destination,
				segment_heap_positions
			)
	if heap.is_empty():
		return PackedVector2Array()

	var polygon: PackedVector2Array = PackedVector2Array()
	var endpoint_cursor: int = 0
	while endpoint_cursor < sorted_endpoints.size():
		var extend: bool = false
		var shorten: bool = false
		var group_start: int = endpoint_cursor
		var endpoint: Endpoint = sorted_endpoints[endpoint_cursor]
		var vertex: Vector2 = segments[endpoint.segment_index][endpoint.endpoint_index]
		var old_segment: int = heap[0]
		while true:
			endpoint = sorted_endpoints[endpoint_cursor]
			vertex = segments[endpoint.segment_index][endpoint.endpoint_index]
			var heap_position: int = segment_heap_positions[endpoint.segment_index]
			if heap_position != -1:
				if endpoint.segment_index == old_segment:
					extend = true
				_remove_segment(
					heap_position,
					heap,
					observer,
					segments,
					vertex,
					segment_heap_positions
				)
			else:
				_insert_segment(
					endpoint.segment_index,
					heap,
					observer,
					segments,
					vertex,
					segment_heap_positions
				)
				if not heap.is_empty() and heap[0] != old_segment:
					shorten = true
			endpoint_cursor += 1
			if endpoint_cursor >= sorted_endpoints.size():
				break
			if (
				sorted_endpoints[endpoint_cursor].angle
				>= sorted_endpoints[group_start].angle + EPSILON
			):
				break
		if heap.is_empty():
			return PackedVector2Array()
		if extend:
			_append_unique_polygon_point(polygon, vertex)
			var extended_intersection: Vector2 = _intersect_lines(
				segments[heap[0]][0], segments[heap[0]][1], observer, vertex
			)
			if _is_finite_point(extended_intersection) and not _equal(extended_intersection, vertex):
				_append_unique_polygon_point(polygon, extended_intersection)
		elif shorten:
			var old_intersection: Vector2 = _intersect_lines(
				segments[old_segment][0], segments[old_segment][1], observer, vertex
			)
			var new_intersection: Vector2 = _intersect_lines(
				segments[heap[0]][0], segments[heap[0]][1], observer, vertex
			)
			if _is_finite_point(old_intersection):
				_append_unique_polygon_point(polygon, old_intersection)
			if _is_finite_point(new_intersection):
				_append_unique_polygon_point(polygon, new_intersection)
	return polygon


static func _sort_endpoints(
		observer: Vector2,
		segments: Array[PackedVector2Array]
) -> Array[Endpoint]:
	var endpoints: Array[Endpoint] = []
	for segment_index: int in range(segments.size()):
		for endpoint_index: int in range(2):
			endpoints.append(Endpoint.new(
				segment_index,
				endpoint_index,
				_angle_degrees(segments[segment_index][endpoint_index], observer)
			))
	endpoints.sort_custom(_endpoint_less)
	return endpoints


static func _endpoint_less(first: Endpoint, second: Endpoint) -> bool:
	if not is_equal_approx(first.angle, second.angle):
		return first.angle < second.angle
	if first.segment_index != second.segment_index:
		return first.segment_index < second.segment_index
	return first.endpoint_index < second.endpoint_index


static func _segment_less_than(
		first_index: int,
		second_index: int,
		observer: Vector2,
		segments: Array[PackedVector2Array],
		destination: Vector2
) -> bool:
	var first_intersection: Vector2 = _intersect_lines(
		segments[first_index][0], segments[first_index][1], observer, destination
	)
	var second_intersection: Vector2 = _intersect_lines(
		segments[second_index][0], segments[second_index][1], observer, destination
	)
	if not _equal(first_intersection, second_intersection):
		return (
			first_intersection.distance_squared_to(observer)
			< second_intersection.distance_squared_to(observer)
		)
	var first_end: int = 1 if _equal(first_intersection, segments[first_index][0]) else 0
	var second_end: int = 1 if _equal(second_intersection, segments[second_index][0]) else 0
	var first_angle: float = _angle_between(
		segments[first_index][first_end], first_intersection, observer
	)
	var second_angle: float = _angle_between(
		segments[second_index][second_end], second_intersection, observer
	)
	if first_angle < 180.0:
		if second_angle > 180.0:
			return true
		return second_angle < first_angle
	return first_angle < second_angle


static func _insert_segment(
		segment_index: int,
		heap: Array[int],
		observer: Vector2,
		segments: Array[PackedVector2Array],
		destination: Vector2,
		segment_heap_positions: Array[int]
) -> void:
	var intersection: Vector2 = _intersect_lines(
		segments[segment_index][0], segments[segment_index][1], observer, destination
	)
	if not _is_finite_point(intersection):
		return
	var current: int = heap.size()
	heap.append(segment_index)
	segment_heap_positions[segment_index] = current
	while current > 0:
		var parent: int = floori(float(current - 1) / 2.0)
		if not _segment_less_than(
			heap[current], heap[parent], observer, segments, destination
		):
			break
		_swap_heap_entries(heap, segment_heap_positions, current, parent)
		current = parent


static func _remove_segment(
		heap_index: int,
		heap: Array[int],
		observer: Vector2,
		segments: Array[PackedVector2Array],
		destination: Vector2,
		segment_heap_positions: Array[int]
) -> void:
	segment_heap_positions[heap[heap_index]] = -1
	if heap_index == heap.size() - 1:
		heap.pop_back()
		return
	heap[heap_index] = heap.pop_back()
	segment_heap_positions[heap[heap_index]] = heap_index
	var current: int = heap_index
	var parent: int = floori(float(current - 1) / 2.0)
	if (
		current != 0
		and _segment_less_than(heap[current], heap[parent], observer, segments, destination)
	):
		while current > 0:
			parent = floori(float(current - 1) / 2.0)
			if not _segment_less_than(
				heap[current], heap[parent], observer, segments, destination
			):
				break
			_swap_heap_entries(heap, segment_heap_positions, current, parent)
			current = parent
	else:
		while true:
			var left: int = 2 * current + 1
			var right: int = left + 1
			if (
				left < heap.size()
				and _segment_less_than(heap[left], heap[current], observer, segments, destination)
				and (
					right == heap.size()
					or _segment_less_than(heap[left], heap[right], observer, segments, destination)
				)
			):
				_swap_heap_entries(heap, segment_heap_positions, current, left)
				current = left
			elif (
				right < heap.size()
				and _segment_less_than(heap[right], heap[current], observer, segments, destination)
			):
				_swap_heap_entries(heap, segment_heap_positions, current, right)
				current = right
			else:
				break


static func _swap_heap_entries(
		heap: Array[int],
		segment_heap_positions: Array[int],
		first: int,
		second: int
) -> void:
	var temporary: int = heap[first]
	heap[first] = heap[second]
	heap[second] = temporary
	segment_heap_positions[heap[first]] = first
	segment_heap_positions[heap[second]] = second


static func _append_unique_polygon_point(
		polygon: PackedVector2Array,
		point: Vector2
) -> void:
	if not polygon.is_empty() and _equal(polygon[polygon.size() - 1], point):
		return
	polygon.append(point)


static func _angle_degrees(point: Vector2, observer: Vector2) -> float:
	return rad_to_deg(atan2(observer.y - point.y, observer.x - point.x))


static func _angle_between(first: Vector2, center: Vector2, last: Vector2) -> float:
	var angle: float = _angle_degrees(first, center) - _angle_degrees(center, last)
	if angle < 0.0:
		angle += 360.0
	if angle > 360.0:
		angle -= 360.0
	return angle


static func _equal(first: Vector2, second: Vector2) -> bool:
	return absf(first.x - second.x) < EPSILON and absf(first.y - second.y) < EPSILON


static func _is_finite_point(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y)


static func _intersect_lines(
		first_start: Vector2,
		first_end: Vector2,
		second_start: Vector2,
		second_end: Vector2
) -> Vector2:
	var second_delta_x: float = second_end.x - second_start.x
	var second_delta_y: float = second_end.y - second_start.y
	var first_delta_x: float = first_end.x - first_start.x
	var first_delta_y: float = first_end.y - first_start.y
	var denominator: float = second_delta_y * first_delta_x - second_delta_x * first_delta_y
	if is_zero_approx(denominator):
		return Vector2(INF, INF)
	var first_ratio: float = (
		second_delta_x * (first_start.y - second_start.y)
		- second_delta_y * (first_start.x - second_start.x)
	) / denominator
	return Vector2(
		first_start.x + first_ratio * first_delta_x,
		first_start.y + first_ratio * first_delta_y
	)
