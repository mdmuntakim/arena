class_name Data
extends RefCounted
## Ringfall - original fighters, weapons and stages.
## Everything here is original: names, stats, palettes and move tables.

# ---------------------------------------------------------------- fighters

# speed: multiplier on walk/run/dash/air speed.
# weight: divides knockback (heavy = survives longer).
# power: multiplies damage dealt.
# defense: scales incoming damage.
const CHARACTERS := {
	"bram": {
		"name": "Bram, the Bulwark",
		"desc": "Siege veteran. Slow, heavy, brutal sigs.",
		"speed": 0.82, "weight": 1.28, "power": 1.16, "defense": 1.06,
		"jump": 0.92,
		"weapons": ["hammer", "gauntlets"],
		"skin": Color8(224, 172, 138),
		"primary": Color8(58, 76, 118),   # steel blue
		"secondary": Color8(212, 168, 67), # gold trim
		"hair": Color8(52, 38, 28),
		"aura": Color(1.0, 0.85, 0.45),
	},
	"sera": {
		"name": "Sera Volt",
		"desc": "Stormblade acrobat. Blistering speed.",
		"speed": 1.22, "weight": 0.86, "power": 0.96, "defense": 0.98,
		"jump": 1.12,
		"weapons": ["daggers", "bow"],
		"skin": Color8(242, 202, 168),
		"primary": Color8(26, 148, 148),  # teal
		"secondary": Color8(126, 232, 222),
		"hair": Color8(238, 240, 246),
		"aura": Color(0.5, 1.0, 0.9),
	},
	"kaz": {
		"name": "Kaz Longarm",
		"desc": "Pikewall duelist. Range wins fights.",
		"speed": 1.0, "weight": 1.0, "power": 1.0, "defense": 1.0,
		"jump": 1.0,
		"weapons": ["spear", "sword"],
		"skin": Color8(206, 158, 122),
		"primary": Color8(158, 44, 52),   # crimson
		"secondary": Color8(34, 32, 38),
		"hair": Color8(24, 22, 26),
		"aura": Color(1.0, 0.5, 0.45),
	},
	"nyx": {
		"name": "Nyx Emberborn",
		"desc": "Runecaster knight. Medium, tricky sigs.",
		"speed": 0.95, "weight": 0.95, "power": 1.1, "defense": 0.94,
		"jump": 1.02,
		"weapons": ["orbstaff", "sword"],
		"skin": Color8(230, 190, 160),
		"primary": Color8(104, 62, 158),  # purple
		"secondary": Color8(255, 126, 64), # ember trim
		"hair": Color8(36, 24, 44),
		"aura": Color(0.75, 0.55, 1.0),
	},
}
const CHARACTER_IDS := ["bram", "sera", "kaz", "nyx"]

# ---------------------------------------------------------------- weapons

const WEAPONS := {
	"unarmed": {"name": "Fists", "color": Color8(200, 170, 140), "reach": 0.85},
	"hammer": {"name": "Skyhammer", "color": Color8(150, 150, 158), "reach": 1.05},
	"gauntlets": {"name": "Emberfists", "color": Color8(226, 118, 60), "reach": 0.8},
	"daggers": {"name": "Twindaggers", "color": Color8(190, 210, 225), "reach": 0.75},
	"bow": {"name": "Longbow", "color": Color8(160, 120, 70), "reach": 1.0},
	"spear": {"name": "Pike", "color": Color8(180, 150, 90), "reach": 1.35},
	"sword": {"name": "Longsword", "color": Color8(210, 215, 225), "reach": 1.0},
	"orbstaff": {"name": "Rune Staff", "color": Color8(150, 110, 220), "reach": 1.1},
}

# ---------------------------------------------------------------- stages

const STAGES := {
	"sunspire": {
		"name": "Sunspire Keep",
		"desc": "Day-lit citadel battlements.",
		"tex": "stage1",
		"night": false,
		"sky": Color8(116, 176, 222),
		"sky_bottom": Color8(252, 214, 156),
		"ground": Color8(168, 148, 118),
		"accent": Color8(212, 168, 67),
		"main": Rect2(-700, 380, 1400, 300),
		"edges": [],
		"soft": [Rect2(-620, -60, 380, 26), Rect2(240, -60, 380, 26), Rect2(-190, -300, 380, 26)],
		"spawns": [Vector2(-420, 180), Vector2(420, 180)],
		"weapon_spawns": [Vector2(0, 200), Vector2(-560, -140), Vector2(560, -140)],
		"music": "music_stage1",
	},
	"frostbridge": {
		"name": "Frostbridge Crossing",
		"desc": "Night. Ice span over a frozen gorge.",
		"tex": "stage2",
		"night": true,
		"sky": Color8(14, 24, 52),
		"sky_bottom": Color8(58, 84, 128),
		"ground": Color8(148, 186, 210),
		"accent": Color8(120, 200, 235),
		"main": Rect2(-820, 380, 1640, 300),
		"edges": [],
		"soft": [Rect2(-520, -80, 300, 26), Rect2(220, -80, 300, 26), Rect2(-140, -320, 280, 26)],
		"spawns": [Vector2(-500, 180), Vector2(500, 180)],
		"weapon_spawns": [Vector2(0, 200), Vector2(-620, -160), Vector2(620, -160)],
		"music": "music_stage2",
	},
	"emberhollow": {
		"name": "Ember Hollow",
		"desc": "Dusk caldera hanging over magma.",
		"tex": "stage3",
		"night": false,
		"sky": Color8(58, 20, 40),
		"sky_bottom": Color8(232, 102, 52),
		"ground": Color8(74, 44, 48),
		"accent": Color8(255, 126, 64),
		"main": Rect2(-640, 400, 1180, 280),
		"edges": [Rect2(-760, 400, 130, 280), Rect2(630, 400, 130, 280)],
		"soft": [Rect2(-470, -40, 300, 26), Rect2(170, -40, 300, 26)],
		"spawns": [Vector2(-380, 220), Vector2(380, 220)],
		"weapon_spawns": [Vector2(0, 240), Vector2(-520, -120), Vector2(520, -120)],
		"music": "music_stage3",
	},
}
const STAGE_IDS := ["sunspire", "frostbridge", "emberhollow"]

# Blast zone: everything outside this rect is a KO.
const BLAST_MARGIN := Vector2(760, 560)

static func stage_size(id: String) -> Vector2:
	var s: Rect2 = STAGES[id]["main"]
	return s.size + Vector2(160, 0)

# ---------------------------------------------------------------- misc

const STOCKS := 3
const MATCH_TIME := 300.0        # seconds shown on the HUD clock
const RESPAWN_INVULN := 1.6      # seconds
const AIR_DODGE_COOLDOWN := 0.75
const MAX_DAMAGE := 999.0
