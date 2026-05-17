extends CharacterBody2D

const NORMAL_ANIMATION_PREFIX := &"normal"

const BULLET_SCENE := preload("res://scene/bullet.tscn")
const ARMED_ANIMATION_PREFIX := &"armed"

const DEFAULT_FIRE_RATE_MULTIPLIER := 1.0
const SPIRAL_PHASE_STEP := PI / 12

const PLAYER_FORM_MODE_NORMAL := 0
const PLAYER_FORM_MODE_ARMED := 1
const SHOT_PATTERN_NORMAL := 0
const SHOT_PATTERN_SPIRAL := 1

# 角色动画节点
@onready var body_sprite: AnimatedSprite2D = $BodySprite2D
# 浮游炮动画节点aa
@onready var armed_effect_sprite:AnimatedSprite2D = $ArmedEffectSprite2D
# 射击冷却计时器
@onready var shooting_timer: Timer = $ShootingTimer

# 当前朝向后缀
var facing_suffix: StringName = &"right"
# 普通射速倍率
var rapid_fire_rate_multiplier: float = DEFAULT_FIRE_RATE_MULTIPLIER
# 强化射速倍率
var form_fire_rate_multiplier: float = DEFAULT_FIRE_RATE_MULTIPLIER
# 当前玩家形态
var current_form_mode: int = PLAYER_FORM_MODE_NORMAL
# 当前弹幕模式
var current_shot_pattern: int = SHOT_PATTERN_NORMAL
# 螺旋弹幕的相位
var spiral_phase: float = 0.0

# 参数设置
@export var move_speed: float = 120.0
@export var fire_interval: float = 0.18
@export var bullet_spawn_distance: float = 18.0



func _ready() -> void:
	shooting_timer.one_shot = true
	shooting_timer.wait_time = _get_effective_fire_interval()
	_update_animation()
	_update_armed_effect()

func _physics_process(delta: float) -> void:
	# 读取移动方向
	var move_input := Input.get_vector("move_left","move_right","move_up","move_down")
	# 读取射击方向
	var shoot_input:= Input.get_vector("shoot_left","shoot_right","shoot_up","shoot_down")
	
	velocity = move_input * move_speed
	move_and_slide()
	
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		_try_auto_spiral_shoot()
	elif shoot_input != Vector2.ZERO:
		_try_shoot(shoot_input)
	
	_update_facing(move_input,shoot_input)	
	_update_animation()
	_update_armed_effect()
	
func _update_animation() -> void:
	var animation_name := StringName("%s_%s" % [_get_animation_prefix(), facing_suffix])
	
	if not body_sprite.sprite_frames.has_animation(animation_name):
		var fallback_animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])
		if not body_sprite.sprite_frames.has_animation(fallback_animation_name):
			push_warning("Missing player animation: %s" % animation_name)
			return
		animation_name = fallback_animation_name
	
	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)

# 射击方向优先于移动方向
func _update_facing(move_input: Vector2, shoot_input: Vector2) -> void:
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		if move_input != Vector2.ZERO:
			facing_suffix = _vector_to_facing_suffix(move_input)
		return
	
	if shoot_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(shoot_input)
	elif move_input != Vector2.ZERO:
		facing_suffix = _vector_to_facing_suffix(move_input)
		
# 尝试发射子弹
func _try_shoot(shoot_input: Vector2) -> void:
	# 冷却结束发射下一颗子弹
	if not shooting_timer.is_stopped():
		return
	
	var shoot_direction := shoot_input.normalized()
	var has_spawn_bullet := _fire_bullets(shoot_direction)
	if has_spawn_bullet:
		shooting_timer.start(_get_effective_fire_interval())

# 发射子弹
func _fire_bullets(base_direction: Vector2) -> bool:
	if current_shot_pattern == SHOT_PATTERN_SPIRAL:
		# 螺旋发射前向后向两颗子弹
		var has_spawned_forward_bullet := _spawn_bullet(base_direction)
		var has_spawned_backward_bullet := _spawn_bullet(base_direction.rotated(PI)) 
		spiral_phase = wrapf(spiral_phase + SPIRAL_PHASE_STEP, 0.0, TAU)
		return has_spawned_forward_bullet or has_spawned_backward_bullet
	return _spawn_bullet(base_direction)

# 实例化一颗子弹
func  _spawn_bullet(shoot_direction: Vector2) -> bool:
	var bullet := BULLET_SCENE.instantiate() as Bullet
	if bullet == null:
		return false
	
	bullet.top_level = true	
	bullet.setup(shoot_direction)
	
	# 子弹挂载当前场景，而不是玩家
	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		return false
	
	spawn_parent.add_child(bullet)
	bullet.global_position = global_position + shoot_direction * bullet_spawn_distance
	return true
	
# 螺旋状态下旋转发射子弹
func _try_auto_spiral_shoot() -> void:
	if not shooting_timer.is_stopped():
		return
	
	var spiral_direction := Vector2.RIGHT.rotated(spiral_phase)
	var has_spawned_bullet := _fire_bullets(spiral_direction)
	if has_spawned_bullet:
		shooting_timer.start(_get_effective_fire_interval())

# 计算有效开火间隔,射速倍率越高，开火间隔越短
func _get_effective_fire_interval() -> float:
	return maxf(fire_interval / _get_effective_fire_rate_multiplier(), 0.01)

# 强化形态下优先使用自带射速倍率，否则退回普通倍率
func _get_effective_fire_rate_multiplier() -> float:
	if _has_active_form_override():
		return maxf(form_fire_rate_multiplier, 0.01)
	
	return maxf(rapid_fire_rate_multiplier, 0.01)

# 只要玩家处于特殊形式，视为强化生效
func _has_active_form_override() -> bool:
	if current_form_mode != PLAYER_FORM_MODE_NORMAL or current_shot_pattern != SHOT_PATTERN_NORMAL:
		return true
	
	return false
	

# 根据当前形态选择动画前缀
func _get_animation_prefix() -> StringName:
	if current_form_mode == PLAYER_FORM_MODE_ARMED:
		return ARMED_ANIMATION_PREFIX
		
	return NORMAL_ANIMATION_PREFIX

# 强化形态显示浮游炮动画
func _update_armed_effect() -> void:
	var is_armed := current_form_mode == PLAYER_FORM_MODE_ARMED
	
	if not is_armed:
		if armed_effect_sprite.visible:
			armed_effect_sprite.visible = false
		if armed_effect_sprite.is_playing():
			armed_effect_sprite.stop()
		return
	
	if not armed_effect_sprite.visible:
		armed_effect_sprite.visible = true
	if armed_effect_sprite.is_playing():
		return
	if armed_effect_sprite.sprite_frames == null:
		return
		
	if armed_effect_sprite.sprite_frames.has_animation("&default"):
		armed_effect_sprite.play("&default")
	




# 将二维vec映射为四方动画
func _vector_to_facing_suffix(direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y> 0.0 else &"up"
	
	
	
	







	
