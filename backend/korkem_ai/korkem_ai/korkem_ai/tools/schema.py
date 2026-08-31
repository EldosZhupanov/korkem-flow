# Copyright (c) 2026, KORKEM and contributors
# For license information, please see license.txt
"""A small JSON Schema validator, for tool arguments only.

`jsonschema` is not in this bench's environment, and adding a dependency to
validate a dialect this narrow would be the wrong trade. What tool arguments
actually use is a closed set — object, a handful of scalar types, `required`,
`enum`, `items`, and numeric bounds — and an explicit validator over that is
something a reviewer can read end to end, which matters more here than
generality: this function is the boundary between a language model and a
factory's database.

Deliberately **strict**. An unknown property is an error rather than an
ignorable extra, because a model that invents `delete: true` on a search tool
should be told no, not quietly obeyed on the parameters it did get right.

Returns a list of human-readable problems. Empty means valid. It never raises
on a malformed *schema* — that would turn our own bug into the model's error —
except where the schema is so wrong there is nothing to check against.
"""

from __future__ import annotations

_TYPE_CHECKS = {
	"object": lambda value: isinstance(value, dict),
	"array": lambda value: isinstance(value, list),
	"string": lambda value: isinstance(value, str),
	# `bool` is a subclass of `int` in Python, and `True` is not a number here.
	"integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
	"number": lambda value: isinstance(value, (int, float)) and not isinstance(value, bool),
	"boolean": lambda value: isinstance(value, bool),
	"null": lambda value: value is None,
}


def validate(value, schema: dict, path: str = "") -> list[str]:
	"""Check `value` against `schema`. Returns the problems found."""
	problems: list[str] = []
	where = path or "arguments"

	expected = schema.get("type")
	if expected:
		check = _TYPE_CHECKS.get(expected)
		if check and not check(value):
			return [f"{where} must be {expected}, got {type(value).__name__}"]

	if "enum" in schema and value not in schema["enum"]:
		allowed = ", ".join(repr(option) for option in schema["enum"])
		return [f"{where} must be one of: {allowed}"]

	if isinstance(value, dict):
		problems += _validate_object(value, schema, where)
	elif isinstance(value, list):
		problems += _validate_array(value, schema, where)
	elif isinstance(value, (int, float)) and not isinstance(value, bool):
		problems += _validate_number(value, schema, where)

	return problems


def _validate_object(value: dict, schema: dict, where: str) -> list[str]:
	problems: list[str] = []
	properties = schema.get("properties", {})

	for name in schema.get("required", []):
		if name not in value:
			problems.append(f"{where}.{name} is required")

	# Strict by default: only an explicit `additionalProperties: true` allows
	# extras. A model inventing arguments is a signal, not noise.
	allow_extra = schema.get("additionalProperties", False) is True
	if properties and not allow_extra:
		for name in value:
			if name not in properties:
				known = ", ".join(sorted(properties)) or "none"
				problems.append(f"{where}.{name} is not a known argument (expected: {known})")

	for name, subschema in properties.items():
		if name in value and isinstance(subschema, dict):
			problems += validate(value[name], subschema, f"{where}.{name}")

	return problems


def _validate_array(value: list, schema: dict, where: str) -> list[str]:
	problems: list[str] = []
	items = schema.get("items")
	if isinstance(items, dict):
		for index, item in enumerate(value):
			problems += validate(item, items, f"{where}[{index}]")

	if "maxItems" in schema and len(value) > schema["maxItems"]:
		problems.append(f"{where} may have at most {schema['maxItems']} items")

	return problems


def _validate_number(value, schema: dict, where: str) -> list[str]:
	problems: list[str] = []
	if "minimum" in schema and value < schema["minimum"]:
		problems.append(f"{where} must be at least {schema['minimum']}")
	if "maximum" in schema and value > schema["maximum"]:
		problems.append(f"{where} must be at most {schema['maximum']}")
	return problems
