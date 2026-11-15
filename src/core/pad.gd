class_name PadState
extends RefCounted
## Per-player input state, filled by the touch pad, the keyboard fallback or a
## physical gamepad. The fighter consumes and clears the "just" flags every
## physics tick, so a pressed button is never lost and never fires twice.

var move := Vector2.ZERO          # stick vector, x: -1..1 (right), y: -1..1 (down)
var jump_held := false
var light_held := false
var heavy_held := false
var dodge_held := false
var dash_held := false
var pickup_held := false
var taunt_held := false
var pause_held := false

var jump_just := false
var light_just := false
var heavy_just := false
var dodge_just := false
var dash_just := false
var pickup_just := false
var taunt_just := false
var pause_just := false

func clear_just() -> void:
	jump_just = false
	light_just = false
	heavy_just = false
	dodge_just = false
	dash_just = false
	pickup_just = false
	taunt_just = false
	pause_just = false

func reset() -> void:
	move = Vector2.ZERO
	jump_held = false; light_held = false; heavy_held = false
	dodge_held = false; dash_held = false; pickup_held = false
	taunt_held = false; pause_held = false
	clear_just()
