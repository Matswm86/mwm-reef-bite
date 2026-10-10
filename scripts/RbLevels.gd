class_name RbLevels
extends RefCounted

## Level table for the world 1 vertical slice (GDD 6.3 rows 1-5, layouts
## 6.4). Each level: goal "grow" (target = tier to reach) or "pearls"
## (target = pearl count); per setting {target, fish_max, bobler}
## (bobler 0 = unlimited); kelp patch centres; power-ups; scripted events.

const WORLD_NAMES: Array[String] = ["Tareskogen"]

const LEVELS: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Første munnfull",
		"goal": "grow",
		"lett": {"target": 3, "fish_max": 7, "bobler": 0},
		"vanlig": {"target": 4, "fish_max": 8, "bobler": 0},
		"world_speed": 1.0,
		"no_big": true,
		"start_fish": [Vector2(300, 700), Vector2(780, 900), Vector2(420, 1250)],
		"player_start": Vector2(540, 950),
		"kelp": [],
		"bobla_at": [],
		"breather": false,
		"onboarding": true,
	},
	{
		"id": 2,
		"name": "Større fisker",
		"goal": "grow",
		"lett": {"target": 4, "fish_max": 7, "bobler": 0},
		"vanlig": {"target": 5, "fish_max": 9, "bobler": 0},
		"world_speed": 1.0,
		"scripted_big": {"t": 4.0, "y": 600.0, "speed_k": 0.5},
		"kelp": [],
		"bobla_at": [],
		"breather": false,
	},
	{
		"id": 3,
		"name": "Bobla",
		"goal": "grow",
		"lett": {"target": 4, "fish_max": 7, "bobler": 0},
		"vanlig": {"target": 5, "fish_max": 9, "bobler": 0},
		"world_speed": 1.0,
		"kelp": [],
		"bobla_at": [Vector2(540, 700)],
		"breather": false,
	},
	{
		"id": 4,
		"name": "Gjemmeleken",
		"goal": "pearls",
		"lett": {"target": 4, "fish_max": 7, "bobler": 0},
		"vanlig": {"target": 6, "fish_max": 9, "bobler": 0},
		"world_speed": 1.0,
		"kelp": [Vector2(180, 1150), Vector2(540, 700), Vector2(900, 1150)],
		"bobla_at": [],
		"breather": false,
	},
	{
		"id": 5,
		"name": "Solstriper",
		"goal": "grow",
		"lett": {"target": 4, "fish_max": 7, "bobler": 0},
		"vanlig": {"target": 5, "fish_max": 8, "bobler": 0},
		"world_speed": 1.0,
		"kelp": [Vector2(180, 950), Vector2(900, 950)],
		"bobla_at": [],
		"breather": true,
	},
]


static func count() -> int:
	return LEVELS.size()


static func has_level(id: int) -> bool:
	return id >= 1 and id <= LEVELS.size()


static func get_level(id: int) -> Dictionary:
	return LEVELS[clampi(id, 1, LEVELS.size()) - 1]


## Per-setting block {target, fish_max, bobler} of a level.
static func setting(id: int, easy: bool) -> Dictionary:
	return get_level(id)["lett" if easy else "vanlig"]
