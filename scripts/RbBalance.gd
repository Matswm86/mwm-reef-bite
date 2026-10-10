class_name RbBalance
extends RefCounted

## Every tunable number of MWM Reef Bite in one place (GDD section 7).
## Logic positions are px in the 1080 x 1920 design frame; the 3D world maps
## them onto the play plane (DESIGN 2: 1 px = 1 / 296.3 m).

const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
const PX_PER_M: float = 296.3

## Zones (GDD 3.2).
const HOME_SQUARE: float = 232.0
const POND := Rect2(0.0, 256.0, 1080.0, 1384.0)
const WRIST_Y: float = 1664.0
const HUD_RECT := Rect2(256.0, 40.0, 788.0, 184.0)

## Tiers (GDD 4.2): length px = 72 x 1.28^(t-1).
const TIER_MIN: int = 1
const TIER_MAX: int = 10
const TIER_BASE_LEN: float = 72.0
const TIER_STEP: float = 1.28
const BODY_R_K: float = 0.30
const PLAYER_START_TIER: int = 2
## Pearl levels have no tier goal; the player still grows, up to here (my call).
const PEARL_LEVEL_TIER_CAP: int = 6

## Player motion (GDD 4.1).
const PLAYER_SPEED_LETT: float = 380.0
const PLAYER_SPEED_VANLIG: float = 440.0
const STEER_TAU_LETT: float = 0.18
const STEER_TAU_VANLIG: float = 0.14
const ARRIVE_GAIN: float = 4.0
const FINGER_LIFT: float = 120.0
const LIFT_FADE_Y0: float = 1400.0
const LIFT_FADE_Y1: float = 1640.0
const TILT_MAX_DEG: float = 25.0
const FLIP_S: float = 0.12
## |vx| below this keeps the old facing, so a fish idling on the spot does
## not flicker left-right.
const FACE_DEADBAND: float = 18.0

## Eat / catch / bump (GDD 4.2).
const EAT_REACH_LETT: float = 36.0
const EAT_REACH_VANLIG: float = 18.0
const CATCH_SCALE_LETT: float = 0.70
const CATCH_SCALE_VANLIG: float = 0.75
const SAME_TIER_PUSH: float = 60.0
const SAME_TIER_PUSH_S: float = 0.15
const BUMP_COOLDOWN_S: float = 0.4
const SNAP_FACE_S: float = 0.08

## Cues (GDD 4.3).
const MOUTH_OPEN_RANGE: float = 260.0
const MOUTH_OPEN_CONE_DEG: float = 70.0
const MOUTH_OPEN_S: float = 0.12
const RING_FADE_IN: float = 420.0
const RING_FADE_OUT: float = 480.0
const RING_FADE_S: float = 0.25
const RING_MORPH_S: float = 0.25
const DANGER_FACE_RANGE: float = 300.0

## Growing (GDD 4.4).
const GROW_POP_S: float = 0.35
const GROW_OVERSHOOT: float = 0.06
const GROW_IMMUNITY: float = 0.6

## Spawning (GDD 4.5).
const SPAWN_INTERVAL: float = 0.35
const SPAWN_MARGIN_Y: float = 60.0
const START_CLEAR_R: float = 300.0
const SPAWN_EDIBLE_LETT: float = 0.70
const SPAWN_SAME_LETT: float = 0.10
const SPAWN_EDIBLE_VANLIG: float = 0.60
const SPAWN_SAME_VANLIG: float = 0.10
const BREATHER_EDIBLE_BONUS: float = 0.10
const BIG_STEP2_CHANCE: float = 1.0 / 3.0
const EDIBLE_TIER_WEIGHTS: Array[float] = [1.0, 2.0, 3.0]
const ANTI_STARVE_MIN_EDIBLE: int = 3
const FISH_BASE_SPEED: float = 70.0
const FISH_SPEED_PER_TIER: float = 12.0
const FISH_SPEED_RAND_LO: float = 0.75
const FISH_SPEED_RAND_HI: float = 1.25
const FISH_SPEED_MULT_LETT: float = 0.75
const FISH_SPEED_MULT_VANLIG: float = 1.0
const FISH_WAVE_V: float = 20.0
const FISH_WAVE_PERIOD: float = 4.0

## Behaviour, Vanlig only (GDD 4.6).
const CHASE_RADIUS: float = 220.0
const CHASE_SPEED_K: float = 0.5
const CHASE_TIME: float = 2.0
const FLEE_RADIUS: float = 200.0
const FLEE_MULT: float = 1.3
const FLEE_TIME: float = 1.0
const FLEE_COOLDOWN: float = 1.5

## Gentle catch (GDD 4.7).
const GULP_S: float = 0.2
const CATCH_BUBBLE_FLOAT: float = 1.4
const CATCH_IMMUNITY: float = 2.0
const SAFE_SPOT_CLEAR: float = 300.0
const BOBLER_VANLIG: int = 3
const RESTART_DIM_S: float = 0.6
const RESTART_SWIM_OFF_S: float = 0.8
const RESTART_LIFT_S: float = 0.4
const RESTART_DIM: float = 0.6

## Pearls (GDD 4.8).
const PEARL_DELAY: float = 1.5
const PEARL_FIRST: float = 1.0
const PEARL_MIN_FROM_PLAYER: float = 250.0
const PEARL_TAKE_EXTRA: float = 40.0
const PEARL_OPEN_S: float = 0.4

## Power-up Bobla (GDD 5.3).
const POWERUP_FIRST: float = 8.0
const POWERUP_EVERY: float = 20.0
const POWERUP_BUBBLE_PX: float = 110.0
const BOBLA_MAX_S: float = 15.0

## Kelp friend (GDD 5.2).
const KELP_SPEED_MULT: float = 0.7
const KELP_SIZE := Vector2(160.0, 520.0)

## Feel, hints and screens (GDD 3.3, 8.3, 9).
const AIM_RING_PX: float = 64.0
const AIM_FADE_IN_S: float = 0.06
const AIM_FADE_OUT_S: float = 0.3
const HINT_FIRST_S: float = 1.0
const HINT_LOOP_S: float = 2.4
const HINT_IDLE_LETT: float = 7.0
const HINT_IDLE_VANLIG: float = 12.0
const HINT_CATCHES: int = 3
const HINT_CATCH_WINDOW: float = 15.0
const HINT_SAFE_PATH: float = 150.0
const EAT_PITCH_WINDOW: float = 1.5
const EAT_PITCH_STEPS: int = 5
const EAT_SOUNDS_PER_S: int = 6
const MAX_FLASHES_PER_S: int = 3
const HOLDOVER_MS: int = 300
const CLEAR_SLOWMO: float = 0.4
const CLEAR_SLOWMO_S: float = 0.4
const CARD_DELAY_S: float = 1.4
const HOME_GUARD_S: float = 2.0
const HOME_GUARD_MIN_S: float = 0.3
const FREE_LEVELS: int = 3
## Uendelig is out of the slice; its unlock rule is kept for the save (GDD 6.5).
const ENDLESS_UNLOCK_LEVEL: int = 5


static func tier_len(tier: int) -> float:
	return TIER_BASE_LEN * pow(TIER_STEP, float(clampi(tier, TIER_MIN, TIER_MAX) - 1))


static func body_r(tier: int) -> float:
	return tier_len(tier) * BODY_R_K


## Food points needed to grow from tier t to t + 1 (GDD 4.4).
static func need(tier: int, easy: bool) -> int:
	return 3 + 2 * tier if easy else 3 + tier


static func player_speed(easy: bool) -> float:
	return PLAYER_SPEED_LETT if easy else PLAYER_SPEED_VANLIG


static func steer_tau(easy: bool) -> float:
	return STEER_TAU_LETT if easy else STEER_TAU_VANLIG


static func eat_reach(easy: bool) -> float:
	return EAT_REACH_LETT if easy else EAT_REACH_VANLIG


static func catch_scale(easy: bool) -> float:
	return CATCH_SCALE_LETT if easy else CATCH_SCALE_VANLIG


static func fish_speed_mult(easy: bool) -> float:
	return FISH_SPEED_MULT_LETT if easy else FISH_SPEED_MULT_VANLIG


static func hint_idle(easy: bool) -> float:
	return HINT_IDLE_LETT if easy else HINT_IDLE_VANLIG


## Aim point for a finger at `finger` (design px): lifted FINGER_LIFT above
## the fingertip, the lift fading to 0 between y 1400 and 1640, clamped
## inside the pond (GDD 3.3).
static func aim_from_finger(finger: Vector2) -> Vector2:
	var k: float = clampf((finger.y - LIFT_FADE_Y0) / (LIFT_FADE_Y1 - LIFT_FADE_Y0), 0.0, 1.0)
	var aim := Vector2(finger.x, finger.y - FINGER_LIFT * (1.0 - k))
	aim.x = clampf(aim.x, POND.position.x, POND.end.x)
	aim.y = clampf(aim.y, POND.position.y, POND.end.y)
	return aim


## Design px -> metres on the play plane (DESIGN 2).
static func to_world(p: Vector2, z: float = 0.0) -> Vector3:
	return Vector3((p.x - 540.0) / PX_PER_M, (960.0 - p.y) / PX_PER_M, z)
