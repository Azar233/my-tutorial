extends CharacterBody2D

const NORMAL_ANIMATION_PREFIX := &"normal"

const BULLET_SCENE := preload("res://scene/bullet.tscn")
const ARMED_ANIMATION_PREFIX := &"armed"

const DEFAULT_FIRE_RATE_MULTIPLIER := 1.0
const SPIRAL_PHASE_STEP := PI / 12

const PLAYER_FORM_MODE_NORMAL := 0
const PLAYER_FORM_MODE_ARMED := 1
const SHOT_PATTERN_NORMAL := 0
const SHOT_PATTERN_ARMED := 1


@onready var body_sprite: AnimatedSprite2D = $BodySprite2D
@onready var armed_effect_sprite:AnimatableBody2D = $ArmedEffectSprite2D
@onready var shooting_timer: Timer = $ShootingTimer

var facing_suffix: StringName = &"right"

@export var move_speed: float = 120.0

@export var fire_interval: float = 0.18

@export var bullet_spawn_distance: float = 18.0



func _ready() -> void:
	_update_animation()

func _physics_process(delta: float) -> void:
	var move_input := Input.get_vector("move_left","move_right","move_up","move_down")
	velocity = move_input * move_speed
	move_and_slide()
	if move_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(move_input)
	_update_animation()
	
func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])
	
	if not body_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Missing player animation: %s" % animation_name)
		return
	
	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)

func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y> 0.0 else &"up"
	
	
	
	
	
