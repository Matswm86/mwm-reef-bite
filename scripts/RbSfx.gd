class_name RbSfx
extends Node

## Sound effects (GDD 9): soft underwater set, own synthesis
## (tools/render_sfx.py), files in res://assets/sfx/. One fixed pool of
## players, no allocation per event; each play picks a random variant and a
## +-4% pitch spread. Eat sounds step up one pentatonic note per meal within
## 1.5 s (max 5 steps) and are rate-limited to 6 per second. The ambience bed
## loops on its own player. Players stay on "Master" (MWM Play routes
## streams outside a "music" path to its Sfx bus).

signal stinger_started(seconds: float)

const POOL: int = 12
const DIR := "res://assets/sfx/"
const PENTA: Array[float] = [1.0, 1.1225, 1.2599, 1.4983, 1.6818, 2.0]
## key -> [files, pitch spread, level dB] (GDD 9 levels; files peak -3 dBFS).
const SOUNDS: Dictionary = {
	"tap": [["rb_tap_1", "rb_tap_2", "rb_tap_3"], 0.04, -6.0],
	"touch": [["rb_touch"], 0.04, -16.0],
	"eat": [["rb_eat_1", "rb_eat_2", "rb_eat_3"], 0.04, -4.0],
	"grow": [["rb_grow"], 0.0, -3.0],
	"tink": [["rb_tink"], 0.04, -18.0],
	"boink": [["rb_boink"], 0.04, -12.0],
	"swish": [["rb_swish"], 0.04, -14.0],
	"gulp": [["rb_gulp"], 0.04, -8.0],
	"burp": [["rb_burp"], 0.04, -6.0],
	"bubble_pop": [["rb_bubble_pop"], 0.04, -8.0],
	"bobler": [["rb_bobler"], 0.0, -10.0],
	"rewind": [["rb_rewind"], 0.0, -6.0],
	"shell": [["rb_shell"], 0.04, -12.0],
	"pearl": [["rb_pearl"], 0.0, -4.0],
	"bobla_on": [["rb_bobla_on"], 0.04, -6.0],
	"bonk": [["rb_bonk"], 0.04, -6.0],
	"kelp": [["rb_kelp"], 0.04, -16.0],
	"win": [["rb_win"], 0.0, -2.0],
	"star": [["rb_star"], 0.0, -6.0],
	"intro": [["rb_intro"], 0.0, -12.0],
	"hint": [["rb_hint"], 0.0, -16.0],
}
const AMBIENCE := "rb_ambience"
const AMBIENCE_DB: float = -24.0
const WIN_DUCK_S: float = 3.0
## Level of every effect before the player's slider: with the default
## slider (0.7, -3.1 dB) the loudest events peak near -12 dBFS (GDD 9).
const BASE_DB: float = -6.0

var enabled: bool = true
var volume: float = 1.0
## Count of plays per key (tests read it).
var played: Dictionary = {}
var _streams: Dictionary = {}
var _spread: Dictionary = {}
var _level: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer
var _clock: float = 0.0
var _eat_times: Array[float] = []
var _eat_step: int = 0
var _last_eat: float = -99.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for i: int in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for key: String in SOUNDS:
		var entry: Array = SOUNDS[key]
		var list: Array[AudioStream] = []
		for file: String in entry[0]:
			var s: AudioStream = load(DIR + file + ".ogg") as AudioStream
			if s != null:
				list.append(s)
			else:
				push_warning("RbSfx: missing " + file)
		_streams[key] = list
		_spread[key] = float(entry[1])
		_level[key] = float(entry[2])
	_ambience = AudioStreamPlayer.new()
	var amb: AudioStreamOggVorbis = load(DIR + AMBIENCE + ".ogg") as AudioStreamOggVorbis
	if amb != null:
		amb.loop = true
		_ambience.stream = amb
	add_child(_ambience)


func _process(delta: float) -> void:
	_clock += delta


func loaded_count() -> int:
	var n: int = 0
	for key: String in _streams:
		n += (_streams[key] as Array).size()
	return n + (1 if _ambience.stream != null else 0)


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not enabled or volume <= 0.01 or not _streams.has(name):
		return
	var list: Array[AudioStream] = _streams[name]
	if list.is_empty():
		return
	played[name] = int(played.get(name, 0)) + 1
	var spread: float = _spread[name]
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[_rng.randi() % list.size()]
	p.pitch_scale = clampf(pitch * (1.0 + _rng.randf_range(-spread, spread)), 0.25, 4.0)
	p.volume_db = vol_db + float(_level[name]) + BASE_DB + linear_to_db(volume)
	p.play()
	if name == "win":
		stinger_started.emit(WIN_DUCK_S)


## Meal: one pentatonic step up per meal within EAT_PITCH_WINDOW s (max 5),
## at most EAT_SOUNDS_PER_S per second.
func eat() -> void:
	while not _eat_times.is_empty() and _clock - _eat_times[0] >= 1.0:
		_eat_times.pop_front()
	if _eat_times.size() >= RbBalance.EAT_SOUNDS_PER_S:
		return
	_eat_times.append(_clock)
	if _clock - _last_eat <= RbBalance.EAT_PITCH_WINDOW:
		_eat_step = mini(_eat_step + 1, RbBalance.EAT_PITCH_STEPS)
	else:
		_eat_step = 0
	_last_eat = _clock
	play("eat", PENTA[_eat_step])


## Pearl: one note up per pearl taken.
func pearl(n: int) -> void:
	play("pearl", PENTA[clampi(n - 1, 0, PENTA.size() - 1)])


## Grow chime: higher tiers start one note higher.
func grow(tier: int) -> void:
	play("grow", PENTA[clampi(tier - 3, 0, PENTA.size() - 1)])


func set_ambience(on: bool) -> void:
	if on and enabled and volume > 0.01 and _ambience.stream != null:
		_ambience.volume_db = AMBIENCE_DB + BASE_DB + linear_to_db(volume)
		if not _ambience.playing:
			_ambience.play()
	else:
		_ambience.stop()


func _exit_tree() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	_ambience.stop()
	_ambience.stream = null
	_streams.clear()
