"""Thin declarations only; arithmetic belongs to manufacturing services."""

from korkem_manufacturing.api import calculations as api

from korkem_ai.korkem_ai.tools.registry import Risk, ToolSpec, register

DIMENSION = {
	"type": "number",
	"exclusiveMinimum": 0,
	"maximum": 1000000,
	"description": "Millimetres (mm), not centimetres or metres.",
}
PIECES = {"type": "integer", "minimum": 1, "maximum": 1000000}
BASE = {"width_mm": DIMENSION, "height_mm": DIMENSION, "quantity": PIECES}


def _declare(name, description, extra=None):
	properties = {**BASE, **(extra or {})}
	register(
		ToolSpec(
			name="manufacturing." + name,
			description=description,
			input_schema={
				"type": "object",
				"properties": properties,
				"required": list(properties),
				"additionalProperties": False,
			},
			risk=Risk.READ,
			handler=getattr(api, name),
			audit_category="calculation",
		)
	)


_declare(
	"calculate_facade_area",
	"Calculate exact total facade area in m² from width_mm, height_mm and pieces. Use for Russian, Kazakh and mixed requests; never calculate mentally.",
)
_declare(
	"calculate_panel_area",
	"Calculate exact rectangular panel area in m² from explicit millimetres and pieces.",
)
_declare(
	"calculate_edge_length",
	"Calculate edging length in metres. Ask which sides are edged; do not assume all four.",
	{
		"width_edges": {"type": "integer", "minimum": 0, "maximum": 2},
		"height_edges": {"type": "integer", "minimum": 0, "maximum": 2},
	},
)
_declare(
	"calculate_material_quantity",
	"Geometric sheet quantity lower bound, NOT a cutting plan or stock reservation. Ask for sheet dimensions and explicit waste percentage; never invent these.",
	{
		"sheet_width_mm": DIMENSION,
		"sheet_height_mm": DIMENSION,
		"waste_percent": {
			"type": "number",
			"minimum": 0,
			"maximum": 100,
			"description": "Explicit allowance added to net area (%), not the fraction of input discarded.",
		},
	},
)
