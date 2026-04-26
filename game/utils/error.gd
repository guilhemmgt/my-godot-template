class_name Error

@warning_ignore("untyped_declaration")
static func push(...args) -> void:
	push_error("[ERROR]", args)
	printerr("[ERROR]", args)


static func out_of_bounds() -> void:
	push("Array index out of bounds.")
