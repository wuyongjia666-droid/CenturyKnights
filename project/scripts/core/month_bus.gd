class_name CKMonthBus
extends RefCounted
## Ordered month phases. Calendar keeps the historical steps on this bus
## so other streams can subscribe without editing the month body.

const PHASES: Array[String] = ["pre", "economy", "family", "court", "world", "post"]

static var _rows: Array = []

static func register(phase: String, cb: Callable, order: int = 0) -> void:
	if not PHASES.has(phase):
		push_error("unknown month phase %s" % phase)
		return
	for row in _rows:
		if row["cb"] == cb:
			row["phase"] = phase
			row["order"] = order
			return
	_rows.append({"phase": phase, "order": order, "cb": cb, "seq": _rows.size()})

static func unregister(cb: Callable) -> void:
	var kept: Array = []
	for row in _rows:
		if row["cb"] != cb:
			kept.append(row)
	_rows = kept

static func registry() -> Array:
	var out: Array = []
	for row in _ordered():
		var cb: Callable = row["cb"]
		var name := ""
		if cb.is_valid():
			name = str(cb.get_method())
		out.append({"phase": str(row["phase"]), "order": int(row["order"]), "name": name})
	return out

static func run(ctx: Dictionary) -> void:
	for row in _ordered():
		ctx["phase"] = str(row["phase"])
		var cb: Callable = row["cb"]
		if cb.is_valid():
			cb.call(ctx)

static func _ordered() -> Array:
	var out: Array = []
	for phase in PHASES:
		var bucket: Array = []
		for row in _rows:
			if str(row["phase"]) == phase:
				bucket.append(row)
		bucket.sort_custom(_by_order)
		out.append_array(bucket)
	return out

static func _by_order(a: Dictionary, b: Dictionary) -> bool:
	if int(a["order"]) == int(b["order"]):
		return int(a["seq"]) < int(b["seq"])
	return int(a["order"]) < int(b["order"])
