extends Node3D

# ==============================================================
# FALLING CUBE DEMONSTRATION
# --------------------------------------------------------------
# This single script creates:
#
# - A floor with visible geometry and collision
# - A physics-controlled falling cube
# - Lighting and an environment
# - A controllable 3D orbit camera
# - A small on-screen controls guide
#
# Camera controls:
#
# Right mouse drag  = orbit
# Middle mouse drag = pan
# Mouse wheel       = zoom
# W/A/S/D           = move target across the ground
# Q/E               = move target vertically
# Shift             = move faster
# F                 = focus on cube
# R                 = reset camera
# Escape            = release mouse
# ==============================================================


# --------------------------------------------------------------
# Scene object references
# --------------------------------------------------------------

var camera: Camera3D
var falling_cube: RigidBody3D


# --------------------------------------------------------------
# Orbit camera settings
# --------------------------------------------------------------

# The world-space point around which the camera rotates.
var camera_target := Vector3(0.0, 1.5, 0.0)

# Horizontal camera angle, measured in radians.
var camera_yaw := deg_to_rad(38.0)

# Vertical camera angle, measured in radians.
# A positive value places the camera above the target.
var camera_pitch := deg_to_rad(24.0)

# Current camera distance from the target.
var camera_distance := 11.0

# Default values used when R is pressed.
const DEFAULT_TARGET := Vector3(0.0, 1.5, 0.0)
const DEFAULT_YAW := 38.0
const DEFAULT_PITCH := 24.0
const DEFAULT_DISTANCE := 11.0

# Camera sensitivity values.
const ORBIT_SENSITIVITY := 0.006
const PAN_SENSITIVITY := 0.002
const ZOOM_STEP := 1.0

# Prevent the camera from flipping upside down.
const MIN_PITCH := deg_to_rad(-80.0)
const MAX_PITCH := deg_to_rad(80.0)

# Prevent zooming through the target or too far away.
const MIN_DISTANCE := 2.0
const MAX_DISTANCE := 30.0

# Keyboard camera movement speed.
const CAMERA_MOVE_SPEED := 5.0
const CAMERA_FAST_MULTIPLIER := 3.0


# --------------------------------------------------------------
# Input state
# --------------------------------------------------------------

var is_orbiting := false
var is_panning := false


func _ready() -> void:
	# Construct the entire demonstration scene.
	create_environment()
	create_light()
	create_floor()
	create_falling_cube()

	# Create the camera after the objects so that focusing and framing
	# have meaningful scene positions.
	create_camera()

	# Add the controls overlay last so that it renders above the scene.
	create_controls_overlay()


func _process(delta: float) -> void:
	# Process continuous keyboard movement once per rendered frame.
	update_keyboard_camera_movement(delta)


func _unhandled_input(event: InputEvent) -> void:
	# ----------------------------------------------------------
	# Mouse button input
	# ----------------------------------------------------------

	if event is InputEventMouseButton:
		# Explicitly cast the generic InputEvent.
		var mouse_button: InputEventMouseButton = event

		match mouse_button.button_index:
			MOUSE_BUTTON_RIGHT:
				is_orbiting = mouse_button.pressed
				update_mouse_mode()

			MOUSE_BUTTON_MIDDLE:
				is_panning = mouse_button.pressed
				update_mouse_mode()

			MOUSE_BUTTON_WHEEL_UP:
				if mouse_button.pressed:
					zoom_camera(-ZOOM_STEP)

			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse_button.pressed:
					zoom_camera(ZOOM_STEP)

	# ----------------------------------------------------------
	# Mouse movement input
	# ----------------------------------------------------------

	elif event is InputEventMouseMotion:
		# Explicit type annotations avoid the parser inference error.
		var mouse_event: InputEventMouseMotion = event
		var mouse_motion: Vector2 = mouse_event.screen_relative

		if is_orbiting:
			orbit_camera(mouse_motion)

		elif is_panning:
			pan_camera(mouse_motion)

	# ----------------------------------------------------------
	# Keyboard input
	# ----------------------------------------------------------

	elif event is InputEventKey:
		var key_event: InputEventKey = event

		if key_event.pressed and not key_event.echo:
			match key_event.keycode:
				KEY_ESCAPE:
					is_orbiting = false
					is_panning = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

				KEY_F:
					focus_on_cube()

				KEY_R:
					reset_camera()


func create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	add_child(world_environment)

	var environment := Environment.new()

	# Use a dark blue-grey background.
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.070, 0.105)

	# Ambient light prevents unlit surfaces from becoming fully black.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.60, 0.70)
	environment.ambient_light_energy = 0.65

	world_environment.environment = environment


func create_light() -> void:
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"

	# Position is irrelevant for directional lights.
	# Rotation controls the direction of the light.
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	light.light_energy = 1.4
	light.shadow_enabled = true

	add_child(light)


func create_floor() -> void:
	# StaticBody3D creates an immovable physics object.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"

	# The box is one metre thick, so placing its centre at Y = -0.5
	# makes its upper surface align with Y = 0.
	floor_body.position = Vector3(0.0, -0.5, 0.0)

	add_child(floor_body)

	# ----------------------------------------------------------
	# Visible floor mesh
	# ----------------------------------------------------------

	var floor_mesh_instance := MeshInstance3D.new()
	floor_mesh_instance.name = "FloorMesh"

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(12.0, 1.0, 12.0)
	floor_mesh_instance.mesh = floor_mesh

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.18, 0.48, 0.30)
	floor_material.roughness = 0.82

	floor_mesh_instance.material_override = floor_material
	floor_body.add_child(floor_mesh_instance)

	# ----------------------------------------------------------
	# Floor collision
	# ----------------------------------------------------------

	var floor_collision := CollisionShape3D.new()
	floor_collision.name = "FloorCollision"

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(12.0, 1.0, 12.0)

	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)


func create_falling_cube() -> void:
	# RigidBody3D objects are controlled by Godot's physics engine.
	falling_cube = RigidBody3D.new()
	falling_cube.name = "FallingCube"
	falling_cube.position = Vector3(0.0, 6.0, 0.0)
	falling_cube.rotation_degrees = Vector3(12.0, 0.0, 18.0)

	falling_cube.mass = 1.0
	falling_cube.linear_damp = 0.08
	falling_cube.angular_damp = 0.08

	add_child(falling_cube)

	# ----------------------------------------------------------
	# Visible cube mesh
	# ----------------------------------------------------------

	var cube_mesh_instance := MeshInstance3D.new()
	cube_mesh_instance.name = "CubeMesh"

	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3.ONE
	cube_mesh_instance.mesh = cube_mesh

	var cube_material := StandardMaterial3D.new()
	cube_material.albedo_color = Color(0.10, 0.48, 1.0)
	cube_material.metallic = 0.08
	cube_material.roughness = 0.30

	cube_mesh_instance.material_override = cube_material
	falling_cube.add_child(cube_mesh_instance)

	# ----------------------------------------------------------
	# Cube collision
	# ----------------------------------------------------------

	var cube_collision := CollisionShape3D.new()
	cube_collision.name = "CubeCollision"

	var cube_shape := BoxShape3D.new()
	cube_shape.size = Vector3.ONE

	cube_collision.shape = cube_shape
	falling_cube.add_child(cube_collision)

	# Add a small initial spin so that the physics motion is visible.
	falling_cube.angular_velocity = Vector3(0.6, 0.3, 0.8)


func create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "OrbitCamera"

	# A lower field of view avoids excessive wide-angle distortion.
	camera.fov = 60.0
	camera.near = 0.05
	camera.far = 100.0
	camera.current = true

	# IMPORTANT:
	# Add the camera to the Scene tree before calling look_at().
	# The previous version attempted to orient it before it entered
	# the tree, which could leave it with an incorrect orientation.
	add_child(camera)

	update_camera_transform()


func update_camera_transform() -> void:
	if camera == null:
		return

	# Convert spherical orbit coordinates into a Cartesian offset.
	#
	# yaw      = horizontal rotation around the Y axis
	# pitch    = vertical angle
	# distance = radius around the target

	var horizontal_distance := camera_distance * cos(camera_pitch)

	var offset := Vector3(
		sin(camera_yaw) * horizontal_distance,
		sin(camera_pitch) * camera_distance,
		cos(camera_yaw) * horizontal_distance
	)

	camera.global_position = camera_target + offset

	# Point the camera's forward direction towards the orbit target.
	camera.look_at(camera_target, Vector3.UP)


func orbit_camera(mouse_motion: Vector2) -> void:
	# Horizontal mouse movement rotates around the target.
	camera_yaw -= mouse_motion.x * ORBIT_SENSITIVITY

	# Vertical mouse movement modifies the elevation angle.
	camera_pitch += mouse_motion.y * ORBIT_SENSITIVITY

	# Prevent the camera from reaching or crossing the vertical poles.
	camera_pitch = clamp(
		camera_pitch,
		MIN_PITCH,
		MAX_PITCH
	)

	update_camera_transform()


func pan_camera(mouse_motion: Vector2) -> void:
	if camera == null:
		return

	# Camera-local right and up directions in world coordinates.
	var camera_right := camera.global_basis.x.normalized()
	var camera_up := camera.global_basis.y.normalized()

	# Increase panning distance when the camera is farther away.
	var scaled_sensitivity := PAN_SENSITIVITY * camera_distance

	camera_target += camera_right * -mouse_motion.x * scaled_sensitivity
	camera_target += camera_up * mouse_motion.y * scaled_sensitivity

	update_camera_transform()


func zoom_camera(amount: float) -> void:
	camera_distance += amount
	camera_distance = clamp(
		camera_distance,
		MIN_DISTANCE,
		MAX_DISTANCE
	)

	update_camera_transform()


func update_keyboard_camera_movement(delta: float) -> void:
	if camera == null:
		return

	var movement := Vector3.ZERO

	# Use the camera's horizontal directions so movement follows
	# the current view rather than fixed global compass directions.
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()

	if Input.is_key_pressed(KEY_W):
		movement += forward

	if Input.is_key_pressed(KEY_S):
		movement -= forward

	if Input.is_key_pressed(KEY_D):
		movement += right

	if Input.is_key_pressed(KEY_A):
		movement -= right

	if Input.is_key_pressed(KEY_E):
		movement += Vector3.UP

	if Input.is_key_pressed(KEY_Q):
		movement -= Vector3.UP

	if movement.is_zero_approx():
		return

	var current_speed := CAMERA_MOVE_SPEED

	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= CAMERA_FAST_MULTIPLIER

	camera_target += movement.normalized() * current_speed * delta
	update_camera_transform()


func update_mouse_mode() -> void:
	# Capture the pointer while actively controlling the camera.
	if is_orbiting or is_panning:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func focus_on_cube() -> void:
	if falling_cube == null:
		return

	# Focus on the cube's current physics position.
	camera_target = falling_cube.global_position
	camera_distance = 6.0

	update_camera_transform()


func reset_camera() -> void:
	camera_target = DEFAULT_TARGET
	camera_yaw = deg_to_rad(DEFAULT_YAW)
	camera_pitch = deg_to_rad(DEFAULT_PITCH)
	camera_distance = DEFAULT_DISTANCE

	update_camera_transform()


func create_controls_overlay() -> void:
	# CanvasLayer renders interface elements independently of the 3D camera.
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "ControlsOverlay"
	add_child(canvas_layer)

	var panel := PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.position = Vector2(16.0, 16.0)
	canvas_layer.add_child(panel)

	var label := Label.new()
	label.name = "ControlsLabel"
	label.text = (
		"CAMERA CONTROLS\n"
		+ "Right drag: orbit\n"
		+ "Middle drag: pan\n"
		+ "Wheel: zoom\n"
		+ "WASD + Q/E: move\n"
		+ "Shift: faster\n"
		+ "F: focus cube\n"
		+ "R: reset camera\n"
		+ "Esc: release mouse"
	)

	label.add_theme_font_size_override("font_size", 15)
	panel.add_child(label)
