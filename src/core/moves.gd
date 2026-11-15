class_name Moves
extends RefCounted
## Original move tables. Frame counts are at 60 fps physics.
##
## Move record fields:
##   dmg   - damage percent dealt
##   kb    - knockback base (velocity at 0 damage)
##   ks    - knockback scale per damage percent of the defender
##   ang   - launch angle in degrees, 0 = forward, +up, -down (spike)
##   st/ac/rc - startup / active / recovery frames
##   off/sz   - hitbox rectangle (offset is in facing-right space)
##   hs    - hitstop frames applied to both fighters on contact
##   ch    - chargeable heavy (hold to scale damage/knockback up to 1.45x)
##   pr    - spawns a projectile instead of a contact hitbox
##   arc   - visual swing sweep in radians (rig animation)

static func M(n: String, dmg: float, kb: float, ks: float, ang: float, st: int, ac: int,
		rc: int, off: Vector2, sz: Vector2, hs := 5, ch := false, pr := false, arc := 1.3) -> Dictionary:
	return {"n": n, "dmg": dmg, "kb": kb, "ks": ks, "ang": ang, "st": st, "ac": ac,
			"rc": rc, "off": off, "sz": sz, "hs": hs, "ch": ch, "pr": pr, "arc": arc}

# A handy ordering for iterating UI hints and tests.
const SLOTS := [
	"gl_n", "gl_s", "gl_u", "gl_d",
	"al_n", "al_s", "al_u", "al_d",
	"gh_n", "gh_s", "gh_u", "gh_d",
	"ah_n", "ah_s", "ah_d",
]

# ------------------------------------------------------------ unarmed (fists)

static func _unarmed() -> Dictionary:
	return {
		"gl_n": M("jab", 8.0, 5.0, 0.052, 20, 4, 3, 8, Vector2(52, -6), Vector2(78, 64), 4, false, false, 0.9),
		"gl_s": M("haymaker", 12.0, 7.0, 0.070, 12, 7, 3, 12, Vector2(62, 2), Vector2(92, 66), 7, false, false, 1.5),
		"gl_u": M("uppercut", 10.0, 8.0, 0.062, 80, 5, 3, 12, Vector2(40, -44), Vector2(76, 84), 6, false, false, 1.8),
		"gl_d": M("sweep", 9.0, 6.0, 0.055, 35, 6, 4, 13, Vector2(56, 34), Vector2(104, 44), 6, false, false, 1.4),
		"al_n": M("air jab", 8.0, 5.5, 0.055, 30, 4, 4, 9, Vector2(48, -8), Vector2(80, 70), 4),
		"al_s": M("cross", 11.0, 7.0, 0.070, 15, 6, 4, 13, Vector2(58, 0), Vector2(90, 64), 7),
		"al_u": M("flip kick", 10.0, 7.5, 0.062, 85, 5, 5, 13, Vector2(30, -50), Vector2(86, 80), 6, false, false, 2.2),
		"al_d": M("stomp", 9.0, 6.5, 0.058, -65, 6, 4, 14, Vector2(34, 48), Vector2(80, 60), 6),
		"gh_n": M("Rage Palm", 23.0, 14.0, 0.105, 25, 14, 4, 26, Vector2(70, -4), Vector2(120, 90), 12, true, false, 1.2),
		"gh_s": M("Bull Charge", 26.0, 15.0, 0.110, 8, 17, 5, 28, Vector2(92, 4), Vector2(150, 80), 13, true, false, 0.7),
		"gh_u": M("Sky Uppercut", 22.0, 15.0, 0.108, 82, 13, 4, 27, Vector2(40, -60), Vector2(110, 110), 12, true, false, 2.0),
		"gh_d": M("Quake Break", 24.0, 13.0, 0.104, 40, 15, 5, 27, Vector2(66, 42), Vector2(150, 60), 12, true, false, 1.1),
		"ah_n": M("Spiral Palm", 18.0, 12.0, 0.095, 28, 9, 5, 18, Vector2(64, -6), Vector2(110, 84), 9),
		"ah_s": M("Dive Hook", 20.0, 13.0, 0.100, 12, 10, 5, 20, Vector2(76, 6), Vector2(120, 80), 10),
		"ah_d": M("Meteor Fist", 19.0, 13.0, 0.102, -70, 10, 5, 19, Vector2(40, 56), Vector2(100, 70), 10),
	}

# ------------------------------------------------------------ skyhammer

static func _hammer() -> Dictionary:
	return {
		"gl_n": M("hammer tap", 11.0, 6.0, 0.058, 25, 6, 3, 11, Vector2(74, -8), Vector2(96, 80), 6, false, false, 1.6),
		"gl_s": M("level swing", 14.0, 8.0, 0.075, 10, 8, 3, 14, Vector2(88, 0), Vector2(120, 74), 8, false, false, 1.7),
		"gl_u": M("arch smash", 12.0, 9.0, 0.070, 82, 7, 3, 14, Vector2(44, -60), Vector2(100, 100), 8, false, false, 2.4),
		"gl_d": M("ground pound", 12.0, 7.0, 0.065, 38, 8, 4, 15, Vector2(70, 40), Vector2(130, 52), 8, false, false, 1.3),
		"al_n": M("spin swing", 12.0, 7.5, 0.065, 30, 6, 5, 12, Vector2(66, -10), Vector2(110, 90), 7, false, false, 2.6),
		"al_s": M("air club", 14.0, 8.5, 0.078, 12, 7, 4, 15, Vector2(84, 4), Vector2(116, 78), 9),
		"al_u": M("sky arc", 12.0, 8.5, 0.070, 85, 6, 5, 14, Vector2(36, -66), Vector2(100, 100), 8, false, false, 2.4),
		"al_d": M("crash down", 13.0, 8.0, 0.072, -70, 7, 5, 16, Vector2(48, 58), Vector2(110, 70), 9),
		"gh_n": M("Verdict Fall", 27.0, 16.0, 0.112, 28, 17, 5, 30, Vector2(84, -10), Vector2(140, 110), 14, true, false, 1.5),
		"gh_s": M("Wrecking Arc", 30.0, 17.0, 0.118, 6, 19, 5, 32, Vector2(104, 4), Vector2(170, 86), 15, true, false, 1.6),
		"gh_u": M("Anvil Rising", 26.0, 16.5, 0.110, 84, 16, 5, 30, Vector2(50, -74), Vector2(120, 130), 14, true, false, 2.4),
		"gh_d": M("Tremor Seal", 28.0, 15.0, 0.108, 42, 18, 6, 30, Vector2(80, 50), Vector2(180, 66), 14, true, false, 1.2),
		"ah_n": M("Hammer Wheel", 21.0, 13.0, 0.100, 26, 10, 5, 20, Vector2(76, -8), Vector2(130, 100), 10),
		"ah_s": M("Sky Mallet", 23.0, 14.0, 0.104, 10, 11, 5, 22, Vector2(96, 6), Vector2(140, 84), 11),
		"ah_d": M("Pile Driver", 22.0, 14.0, 0.106, -75, 11, 5, 21, Vector2(50, 66), Vector2(120, 80), 11),
	}

# ------------------------------------------------------------ emberfists

static func _gauntlets() -> Dictionary:
	return {
		"gl_n": M("cinder jab", 8.0, 5.0, 0.052, 22, 3, 3, 7, Vector2(50, -6), Vector2(74, 62), 4, false, false, 0.9),
		"gl_s": M("flurry rush", 13.0, 7.5, 0.072, 12, 8, 6, 13, Vector2(66, 2), Vector2(96, 66), 8, false, false, 1.2),
		"gl_u": M("flame upper", 10.0, 8.0, 0.064, 80, 5, 3, 11, Vector2(42, -48), Vector2(78, 88), 6, false, false, 1.9),
		"gl_d": M("ember sweep", 9.0, 6.0, 0.056, 35, 6, 4, 12, Vector2(58, 36), Vector2(104, 46), 6, false, false, 1.4),
		"al_n": M("twin strike", 9.0, 5.5, 0.055, 28, 4, 4, 9, Vector2(52, -8), Vector2(82, 72), 5),
		"al_s": M("burn cross", 12.0, 7.0, 0.070, 14, 6, 4, 12, Vector2(62, 0), Vector2(92, 66), 7),
		"al_u": M("rising nova", 11.0, 8.0, 0.066, 85, 5, 5, 13, Vector2(32, -52), Vector2(88, 84), 7, false, false, 2.2),
		"al_d": M("dive burner", 10.0, 6.5, 0.058, -68, 6, 4, 14, Vector2(36, 50), Vector2(84, 62), 7),
		"gh_n": M("Detonation Fist", 24.0, 14.5, 0.108, 26, 13, 4, 25, Vector2(76, -6), Vector2(124, 94), 12, true, false, 1.2),
		"gh_s": M("Comet Rush", 27.0, 15.5, 0.112, 8, 16, 6, 27, Vector2(98, 4), Vector2(150, 82), 13, true, false, 0.8),
		"gh_u": M("Volcano Palm", 23.0, 15.0, 0.110, 83, 12, 4, 26, Vector2(44, -64), Vector2(112, 114), 12, true, false, 2.1),
		"gh_d": M("Seismic Cataclysm", 25.0, 14.0, 0.106, 40, 14, 5, 26, Vector2(72, 44), Vector2(160, 64), 12, true, false, 1.1),
		"ah_n": M("Cyclone Punch", 18.0, 12.0, 0.096, 27, 8, 5, 17, Vector2(66, -8), Vector2(112, 88), 9),
		"ah_s": M("Blazing Hook", 20.0, 13.0, 0.100, 11, 9, 5, 19, Vector2(80, 6), Vector2(122, 82), 10),
		"ah_d": M("Falling Star", 19.0, 13.0, 0.102, -72, 9, 5, 18, Vector2(42, 58), Vector2(102, 72), 10),
	}

# ------------------------------------------------------------ twindaggers

static func _daggers() -> Dictionary:
	return {
		"gl_n": M("quick cut", 7.0, 4.5, 0.048, 22, 3, 3, 6, Vector2(46, -6), Vector2(70, 58), 3, false, false, 1.1),
		"gl_s": M("slip slash", 11.0, 6.5, 0.068, 14, 6, 3, 10, Vector2(60, 0), Vector2(88, 60), 6, false, false, 1.5),
		"gl_u": M("twin rise", 9.0, 7.5, 0.060, 80, 4, 3, 10, Vector2(38, -44), Vector2(72, 82), 5, false, false, 1.9),
		"gl_d": M("low rips", 9.0, 6.0, 0.056, 32, 5, 4, 11, Vector2(54, 34), Vector2(96, 44), 5, false, false, 1.3),
		"al_n": M("air clip", 7.0, 5.0, 0.050, 28, 3, 4, 7, Vector2(46, -8), Vector2(74, 64), 4),
		"al_s": M("dart slash", 10.0, 6.5, 0.066, 14, 5, 4, 10, Vector2(56, 0), Vector2(84, 62), 6),
		"al_u": M("wing cut", 9.0, 7.0, 0.060, 85, 4, 5, 11, Vector2(30, -48), Vector2(80, 76), 5, false, false, 2.2),
		"al_d": M("plunge", 10.0, 7.0, 0.062, -72, 5, 5, 12, Vector2(34, 50), Vector2(78, 62), 6),
		"gh_n": M("Thousand Cuts", 22.0, 13.5, 0.104, 24, 12, 8, 24, Vector2(66, -6), Vector2(116, 88), 11, true, false, 1.4),
		"gh_s": M("Shadow Rush", 25.0, 15.0, 0.110, 8, 14, 7, 26, Vector2(88, 4), Vector2(140, 76), 12, true, false, 0.9),
		"gh_u": M("Storm Fan", 21.0, 14.5, 0.106, 82, 11, 5, 25, Vector2(40, -58), Vector2(104, 108), 11, true, false, 2.3),
		"gh_d": M("Gravity Well", 23.0, 13.5, 0.102, 38, 13, 5, 25, Vector2(64, 42), Vector2(148, 60), 11, true, false, 1.1),
		"ah_n": M("Raptor Whirl", 17.0, 11.5, 0.094, 26, 8, 5, 16, Vector2(60, -8), Vector2(106, 84), 8),
		"ah_s": M("Nightfall Cross", 19.0, 12.5, 0.098, 10, 9, 5, 18, Vector2(74, 6), Vector2(116, 78), 9),
		"ah_d": M("Fang Drop", 18.0, 12.5, 0.100, -70, 9, 5, 17, Vector2(40, 56), Vector2(98, 70), 9),
	}

# ------------------------------------------------------------ longbow

static func _bow() -> Dictionary:
	return {
		"gl_n": M("quick arrow", 7.0, 4.5, 0.050, 12, 5, 2, 9, Vector2(40, -10), Vector2(30, 30), 3, false, true, 0.3),
		"gl_s": M("power shot", 10.0, 6.0, 0.058, 8, 9, 2, 13, Vector2(40, -10), Vector2(30, 30), 5, false, true, 0.3),
		"gl_u": M("sky arrow", 8.0, 5.0, 0.052, 78, 6, 2, 11, Vector2(10, -40), Vector2(30, 30), 4, false, true, 0.3),
		"gl_d": M("low arrow", 8.0, 5.0, 0.052, -8, 6, 2, 11, Vector2(40, 10), Vector2(30, 30), 4, false, true, 0.3),
		"al_n": M("air arrow", 7.0, 5.0, 0.050, 20, 5, 2, 9, Vector2(40, -10), Vector2(30, 30), 4, false, true, 0.3),
		"al_s": M("drive shot", 10.0, 6.0, 0.058, 6, 8, 2, 12, Vector2(40, -6), Vector2(30, 30), 5, false, true, 0.3),
		"al_u": M("rain arrow", 8.0, 5.0, 0.052, 80, 5, 2, 10, Vector2(10, -40), Vector2(30, 30), 4, false, true, 0.3),
		"al_d": M("dive arrow", 9.0, 6.0, 0.058, -30, 6, 2, 11, Vector2(40, 14), Vector2(30, 30), 5, false, true, 0.3),
		"gh_n": M("Piercing Volley", 22.0, 13.0, 0.104, 10, 14, 3, 24, Vector2(40, -10), Vector2(30, 30), 9, true, true, 0.4),
		"gh_s": M("Ballista Bolt", 26.0, 15.0, 0.112, 4, 17, 3, 27, Vector2(40, -8), Vector2(30, 30), 10, true, true, 0.4),
		"gh_u": M("Zenith Rain", 23.0, 14.0, 0.108, 84, 15, 3, 26, Vector2(10, -44), Vector2(30, 30), 10, true, true, 0.4),
		"gh_d": M("Anchor Kick", 24.0, 14.0, 0.106, 36, 13, 4, 26, Vector2(70, 40), Vector2(140, 56), 12, true, false, 1.2),
		"ah_n": M("Trick Arrow", 16.0, 11.0, 0.092, 16, 8, 3, 15, Vector2(40, -10), Vector2(30, 30), 6, false, true, 0.4),
		"ah_s": M("Hawk Shot", 18.0, 12.0, 0.096, 6, 9, 3, 17, Vector2(40, -8), Vector2(30, 30), 7, false, true, 0.4),
		"ah_d": M("Sky Diver", 17.0, 12.0, 0.096, -58, 9, 4, 16, Vector2(40, 14), Vector2(30, 30), 7, false, true, 0.4),
	}

# ------------------------------------------------------------ pike (spear)

static func _spear() -> Dictionary:
	return {
		"gl_n": M("pike jab", 9.0, 5.5, 0.054, 22, 5, 3, 9, Vector2(96, -6), Vector2(120, 56), 5, false, false, 0.35),
		"gl_s": M("long thrust", 12.0, 7.5, 0.072, 10, 7, 3, 12, Vector2(112, 0), Vector2(150, 60), 7, false, false, 0.3),
		"gl_u": M("sky pole", 10.0, 8.0, 0.062, 80, 5, 3, 12, Vector2(30, -70), Vector2(76, 120), 6, false, false, 1.6),
		"gl_d": M("ground rake", 10.0, 6.5, 0.058, 34, 6, 4, 13, Vector2(84, 36), Vector2(120, 46), 6, false, false, 1.0),
		"al_n": M("air jab", 8.0, 5.5, 0.052, 28, 4, 4, 9, Vector2(88, -8), Vector2(110, 64), 5),
		"al_s": M("skyward thrust", 11.0, 7.0, 0.068, 12, 6, 4, 12, Vector2(100, 2), Vector2(136, 60), 7),
		"al_u": M("pole vault", 10.0, 7.5, 0.062, 85, 5, 5, 13, Vector2(24, -72), Vector2(80, 120), 6, false, false, 1.8),
		"al_d": M("plunge pole", 10.0, 7.0, 0.062, -70, 6, 5, 14, Vector2(52, 62), Vector2(94, 72), 7),
		"gh_n": M("Impaler Rise", 24.0, 14.5, 0.108, 76, 14, 4, 26, Vector2(50, -66), Vector2(120, 130), 12, true, false, 1.5),
		"gh_s": M("Dragon Thrust", 27.0, 15.5, 0.112, 6, 17, 5, 29, Vector2(128, 4), Vector2(190, 78), 13, true, false, 0.3),
		"gh_u": M("Pillar Toss", 23.0, 15.0, 0.110, 84, 13, 4, 27, Vector2(36, -78), Vector2(110, 140), 12, true, false, 2.0),
		"gh_d": M("Tectonic Sweep", 25.0, 14.0, 0.106, 40, 15, 5, 27, Vector2(94, 44), Vector2(170, 62), 12, true, false, 1.1),
		"ah_n": M("Cirrus Lance", 18.0, 12.0, 0.096, 26, 9, 5, 18, Vector2(86, -8), Vector2(126, 88), 9),
		"ah_s": M("Falling Spike", 20.0, 13.0, 0.100, 8, 10, 5, 20, Vector2(104, 6), Vector2(150, 80), 10),
		"ah_d": M("Nail Dive", 19.0, 13.0, 0.102, -72, 10, 5, 19, Vector2(56, 70), Vector2(120, 80), 10),
	}

# ------------------------------------------------------------ longsword

static func _sword() -> Dictionary:
	return {
		"gl_n": M("blade cut", 9.0, 5.5, 0.054, 24, 5, 3, 9, Vector2(72, -8), Vector2(100, 68), 5, false, false, 1.5),
		"gl_s": M("heavy slash", 12.0, 7.5, 0.072, 12, 7, 3, 12, Vector2(84, 0), Vector2(118, 70), 7, false, false, 1.7),
		"gl_u": M("rising cut", 10.0, 8.0, 0.062, 80, 5, 3, 12, Vector2(46, -56), Vector2(90, 96), 6, false, false, 2.0),
		"gl_d": M("low sweep", 10.0, 6.5, 0.058, 34, 6, 4, 13, Vector2(70, 36), Vector2(116, 48), 6, false, false, 1.3),
		"al_n": M("air slash", 9.0, 5.5, 0.054, 28, 4, 4, 9, Vector2(70, -10), Vector2(104, 76), 5),
		"al_s": M("plunge cut", 11.0, 7.0, 0.068, 12, 6, 4, 12, Vector2(82, 2), Vector2(112, 70), 7),
		"al_u": M("moonrise", 10.0, 7.5, 0.062, 85, 5, 5, 13, Vector2(34, -60), Vector2(94, 100), 6, false, false, 2.2),
		"al_d": M("drop blade", 10.0, 7.0, 0.062, -70, 6, 5, 14, Vector2(46, 58), Vector2(96, 72), 7),
		"gh_n": M("Oathbreaker", 24.0, 14.5, 0.108, 26, 14, 4, 26, Vector2(80, -10), Vector2(130, 96), 12, true, false, 1.4),
		"gh_s": M("Cleaving Dawn", 27.0, 15.5, 0.112, 8, 17, 5, 28, Vector2(98, 4), Vector2(160, 80), 13, true, false, 1.6),
		"gh_u": M("Ascension Blade", 23.0, 15.0, 0.110, 82, 13, 4, 27, Vector2(46, -70), Vector2(116, 122), 12, true, false, 2.2),
		"gh_d": M("Ruinous Wave", 25.0, 14.0, 0.106, 40, 15, 5, 27, Vector2(78, 44), Vector2(162, 64), 12, true, false, 1.2),
		"ah_n": M("Whirl Steel", 18.0, 12.0, 0.096, 26, 9, 5, 18, Vector2(72, -10), Vector2(122, 92), 9),
		"ah_s": M("Nightedge", 20.0, 13.0, 0.100, 10, 10, 5, 20, Vector2(88, 6), Vector2(132, 82), 10),
		"ah_d": M("Grave Thrust", 19.0, 13.0, 0.102, -72, 10, 5, 19, Vector2(50, 62), Vector2(112, 78), 10),
	}

# ------------------------------------------------------------ rune staff

static func _orbstaff() -> Dictionary:
	return {
		"gl_n": M("orb poke", 9.0, 5.5, 0.054, 24, 5, 3, 9, Vector2(80, -8), Vector2(104, 66), 5, false, false, 1.0),
		"gl_s": M("staff sweep", 12.0, 7.0, 0.070, 12, 7, 3, 12, Vector2(90, 0), Vector2(126, 66), 7, false, false, 1.6),
		"gl_u": M("rune lift", 10.0, 8.0, 0.062, 80, 5, 3, 12, Vector2(40, -60), Vector2(96, 104), 6, false, false, 1.9),
		"gl_d": M("glyph lash", 10.0, 6.5, 0.058, 34, 6, 4, 13, Vector2(76, 36), Vector2(120, 48), 6, false, false, 1.2),
		"al_n": M("air glyph", 9.0, 5.5, 0.054, 28, 4, 4, 9, Vector2(74, -10), Vector2(108, 78), 5),
		"al_s": M("comet jab", 11.0, 7.0, 0.068, 12, 6, 4, 12, Vector2(88, 2), Vector2(118, 68), 7),
		"al_u": M("astral rise", 10.0, 7.5, 0.062, 85, 5, 5, 13, Vector2(32, -64), Vector2(98, 106), 6, false, false, 2.1),
		"al_d": M("fall rune", 10.0, 7.0, 0.062, -70, 6, 5, 14, Vector2(44, 60), Vector2(100, 74), 7),
		"gh_n": M("Void Bloom", 24.0, 14.5, 0.108, 28, 14, 4, 26, Vector2(84, -10), Vector2(134, 98), 12, true, false, 1.3),
		"gh_s": M("Eclipse Sweep", 27.0, 15.5, 0.112, 8, 17, 5, 28, Vector2(102, 4), Vector2(166, 80), 13, true, false, 1.5),
		"gh_u": M("Starfall Pillar", 23.0, 15.0, 0.110, 83, 13, 4, 27, Vector2(44, -74), Vector2(120, 128), 12, true, false, 2.3),
		"gh_d": M("Abyss Rite", 25.0, 14.0, 0.106, 40, 15, 5, 27, Vector2(82, 44), Vector2(168, 64), 12, true, false, 1.1),
		"ah_n": M("Orbit Strike", 18.0, 12.0, 0.096, 26, 9, 5, 18, Vector2(76, -10), Vector2(126, 94), 9),
		"ah_s": M("Dusk Lance", 20.0, 13.0, 0.100, 10, 10, 5, 20, Vector2(92, 6), Vector2(138, 82), 10),
		"ah_d": M("Meteor Rite", 19.0, 13.0, 0.102, -72, 10, 5, 19, Vector2(50, 64), Vector2(116, 78), 10),
	}

static var _tables := {}

static func get_move(weapon: String, id: String) -> Dictionary:
	if _tables.is_empty():
		_tables = {
			"unarmed": _unarmed(), "hammer": _hammer(), "gauntlets": _gauntlets(),
			"daggers": _daggers(), "bow": _bow(), "spear": _spear(),
			"sword": _sword(), "orbstaff": _orbstaff(),
		}
	var t: Dictionary = _tables.get(weapon, _unarmed())
	return t.get(id, _unarmed()["gl_n"])

# Weapon throw: thrown weapon becomes a spinning projectile.
static func throw_params(weapon: String) -> Dictionary:
	return {"dmg": 12.0, "kb": 9.0, "ks": 0.07, "ang": 15.0, "speed": 1150.0, "sfx": "throw"}

# Charge scaling for chargeable heavies.
const CHARGE_FRAMES := 45
const CHARGE_MAX := 1.45
