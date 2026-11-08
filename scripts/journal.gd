extends Node
## Ordered, unique journal IDs. GameState owns disk persistence.
## IDs are stable content keys, independent of story choices.

signal entry_added(id: String)
signal entries_changed

var _entries: Array[String] = []


func discover(id: String) -> void:
	if id.strip_edges().is_empty() or id in _entries:
		return
	_entries.append(id)
	entry_added.emit(id)
	entries_changed.emit()


func entries() -> Array[String]:
	return _entries.duplicate()


func has(id: String) -> bool:
	return id in _entries


## Call only after GameState has validated the complete save.
## Preserve unknown IDs for forward content compatibility and first-seen order.
func restore(ids: Array) -> void:
	var restored: Array[String] = []
	for id in ids:
		if typeof(id) == TYPE_STRING and not id.strip_edges().is_empty() and id not in restored:
			restored.append(id)
	_entries = restored
	entries_changed.emit()


func clear() -> void:
	restore([])
